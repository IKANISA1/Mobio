import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery_response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentDiscoveryException implements Exception {
  const PaymentDiscoveryException(this.reason);
  final String reason;
}

abstract interface class PaymentDiscoveryGateway {
  String? get ownerId;
  AccountSnapshot captureAccount();
  bool isCurrent(AccountSnapshot account);
  String get deviceFamily;
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> data);
  Future<void> rememberDraft(String ownerId, String draftId);
  Future<String?> rememberedDraft(String ownerId);
}

class PaymentDiscoveryService implements PaymentDiscoveryGateway {
  PaymentDiscoveryService(
    this.client, {
    AccountSnapshot Function()? captureAccount,
    bool Function(AccountSnapshot)? isCurrent,
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;

  final SupabaseClient? client;
  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;

  @override
  AccountSnapshot captureAccount() {
    final account = _captureOverride?.call() ?? AccountContext.capture();
    _requireCurrent(account);
    return account;
  }

  @override
  bool isCurrent(AccountSnapshot account) =>
      ownerId == account.userId &&
      (_isCurrentOverride?.call(account) ?? AccountContext.isCurrent(account));

  void _requireCurrent(AccountSnapshot account) {
    if (!isCurrent(account)) throw const StaleAccountWork();
  }

  static const deviceChannel = MethodChannel('rw.mobi.app/biopay_discovery');

  @override
  String? get ownerId => client?.auth.currentUser?.isAnonymous == false
      ? client?.auth.currentUser?.id
      : null;

  @override
  String get deviceFamily => kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          _ => 'desktop',
        };

  @override
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> data,
  ) async {
    if (!PaymentDiscoveryResponse.actions.contains(action)) {
      throw ArgumentError.value(action, 'action', 'Unsupported BioPay action');
    }
    if (ownerId == null || client == null) {
      throw StateError('Verified sign-in required.');
    }
    final account = captureAccount();
    dynamic result;
    try {
      final request = client!.rpc<dynamic>(
        'rpc_biopay_discovery',
        params: {'p_action': action, 'p_data': data},
      );
      result = PaymentDiscoveryResponse.reads.contains(action)
          ? await RequestDeadline.read(request)
          : await RequestDeadline.mutation(
              request,
              operation: 'rpc_biopay_discovery:$action',
              operationId: (data['id'] ?? data['quote_id'])?.toString(),
            );
    } on PostgrestException catch (error) {
      _requireCurrent(account);
      final message = error.message;
      throw PaymentDiscoveryException(
        message.contains('Receiving details changed')
            ? 'recipientChanged'
            : message.contains('Saved source changed')
            ? 'sourceChanged'
            : message.contains('Fee evidence changed')
            ? 'feeChanged'
            : message.contains('Provider instructions or sharing changed') ||
                  message.contains('Payment option unavailable')
            ? 'routeChanged'
            : 'refreshRequired',
      );
    } on Object {
      _requireCurrent(account);
      rethrow;
    }
    _requireCurrent(account);
    try {
      final row = PaymentWire.object(result);
      PaymentDiscoveryResponse.validate(action, row, data, account.userId);
      return row;
    } on FormatException catch (error, stackTrace) {
      if (PaymentDiscoveryResponse.reads.contains(action)) rethrow;
      throw MutationOutcomeUnknownException(
        operation: 'rpc_biopay_discovery:$action',
        operationId:
            (data['id'] ?? data['quote_id'] ?? data['method_id']) as String?,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, dynamic>> adminCall(
    String action,
    Map<String, dynamic> data,
  ) async {
    if (ownerId == null || client == null) {
      throw StateError('Admin connection required.');
    }
    final account = captureAccount();
    final request = client!.rpc<dynamic>(
      'rpc_admin_biopay_routes',
      params: {'p_action': action, 'p_data': data},
    );
    dynamic response;
    try {
      response = action == 'list'
          ? await RequestDeadline.read(request)
          : await RequestDeadline.mutation(
              request,
              operation: 'rpc_admin_biopay_routes:$action',
              operationId: data['id']?.toString(),
            );
    } on Object {
      _requireCurrent(account);
      rethrow;
    }
    _requireCurrent(account);
    try {
      final row = PaymentWire.object(response);
      PaymentDiscoveryResponse.admin(action, row, data);
      return row;
    } on FormatException catch (error, stackTrace) {
      if (action == 'list') rethrow;
      throw MutationOutcomeUnknownException(
        operation: 'rpc_admin_biopay_routes:$action',
        operationId: data['id'] as String?,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, dynamic>> previewLink(String token) async {
    if (client == null) throw StateError('Connect to preview this request.');
    final result = await RequestDeadline.read(
      client!.rpc<dynamic>(
        'rpc_biopay_link_preview',
        params: {'p_token': token},
      ),
    );
    final row = PaymentWire.object(result);
    PaymentDiscoveryResponse.preview(row);
    return row;
  }

  // Only an opaque draft ID is stored on disk. Receiving details and bearer
  // tokens remain in the authenticated backend, never SharedPreferences.
  @override
  Future<void> rememberDraft(String ownerId, String draftId) async {
    final account = captureAccount();
    if (account.userId != ownerId) throw const StaleAccountWork();
    final preferences = await SharedPreferences.getInstance();
    _requireCurrent(account);
    if (!await preferences.setString(
      'biopay.draft.${account.identity}',
      draftId,
    )) {
      throw StateError('Draft shortcut could not be saved.');
    }
    _requireCurrent(account);
  }

  @override
  Future<String?> rememberedDraft(String ownerId) async {
    final account = captureAccount();
    if (account.userId != ownerId) throw const StaleAccountWork();
    final preferences = await SharedPreferences.getInstance();
    _requireCurrent(account);
    return preferences.getString('biopay.draft.${account.identity}');
  }

  Future<Map<String, String>?> pickPhone() async {
    if (kIsWeb) return null;
    final result = await RequestDeadline.read(
      deviceChannel.invokeMapMethod<String, String>('pickPhone'),
      timeout: const Duration(seconds: 20),
    );
    return result;
  }

  Future<String?> pickQrImage() async {
    if (kIsWeb) return null;
    return RequestDeadline.read(
      deviceChannel.invokeMethod<String>('pickQrImage'),
      timeout: const Duration(seconds: 20),
    );
  }

  Future<bool> openReviewedInstruction(Map<String, dynamic> prepared) async {
    // Only Android has a validated user-controlled dial-intent adapter.
    // iOS/desktop/web present copyable instructions in the reviewed task.
    if (deviceFamily != 'android' || prepared['mode'] != 'dial') return false;
    final instruction = prepared['instruction'] as String? ?? '';
    if (!RegExp(r'^\*[0-9*]+#$').hasMatch(instruction)) return false;
    final account = captureAccount();
    final result = await RequestDeadline.mutation(
      const MethodChannel(
        'rw.mobi.app/biopay_ussd_dialer',
      ).invokeMapMethod<Object?, Object?>('launchUssd', {
        'uri': 'tel:${instruction.replaceAll('#', '%23')}',
      }),
      operation: 'open_reviewed_ussd_instruction',
      timeout: const Duration(seconds: 10),
    );
    _requireCurrent(account);
    if (result == null || result['launched'] is! bool) {
      throw MutationOutcomeUnknownException(
        operation: 'open_reviewed_ussd_instruction',
      );
    }
    return result['launched'] as bool;
  }
}

String newBioPayUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final h = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

List<PaymentMethod> workspaceMethods(Map<String, dynamic> workspace) {
  final methods = workspace['methods'];
  if (methods is! List)
    throw const FormatException('Invalid BioPay methods list');
  return methods
      .map((row) {
        if (row is! Map || row.keys.any((key) => key is! String)) {
          throw const FormatException('Invalid BioPay method row');
        }
        return PaymentMethod.fromJson(Map<String, dynamic>.from(row));
      })
      .toList(growable: false);
}
