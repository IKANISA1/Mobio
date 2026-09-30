import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentDiscoveryException implements Exception {
  const PaymentDiscoveryException(this.reason);
  final String reason;
}

abstract interface class PaymentDiscoveryGateway {
  String? get ownerId;
  String get deviceFamily;
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> data);
  Future<void> rememberDraft(String ownerId, String draftId);
  Future<String?> rememberedDraft(String ownerId);
}

class PaymentDiscoveryService implements PaymentDiscoveryGateway {
  PaymentDiscoveryService(this.client);

  final SupabaseClient? client;
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
    final account = ownerId;
    if (account == null || client == null) {
      throw StateError('Verified sign-in required.');
    }
    final sessionId = AccountContext.sessionId(client!.auth.currentSession);
    dynamic result;
    try {
      final request = client!.rpc<dynamic>(
        'rpc_biopay_discovery',
        params: {'p_action': action, 'p_data': data},
      );
      result = const {'workspace', 'sharing', 'resolve'}.contains(action)
          ? await RequestDeadline.read(request)
          : await RequestDeadline.mutation(
              request,
              operation: 'rpc_biopay_discovery:$action',
              operationId: (data['id'] ?? data['quote_id'])?.toString(),
            );
    } on PostgrestException catch (error) {
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
    }
    if (ownerId != account ||
        AccountContext.sessionId(client!.auth.currentSession) != sessionId) {
      throw const StaleAccountWork();
    }
    if (result is! Map) throw const FormatException('Invalid BioPay response');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> adminCall(
    String action,
    Map<String, dynamic> data,
  ) async {
    final account = client?.auth.currentUser?.id;
    if (account == null || client == null) {
      throw StateError('Admin connection required.');
    }
    final sessionId = AccountContext.sessionId(client!.auth.currentSession);
    final request = client!.rpc<dynamic>(
      'rpc_admin_biopay_routes',
      params: {'p_action': action, 'p_data': data},
    );
    final response = action == 'list'
        ? await RequestDeadline.read(request)
        : await RequestDeadline.mutation(
            request,
            operation: 'rpc_admin_biopay_routes:$action',
            operationId: data['id']?.toString(),
          );
    if (account != client!.auth.currentUser?.id ||
        AccountContext.sessionId(client!.auth.currentSession) != sessionId) {
      throw const StaleAccountWork();
    }
    if (response is! Map) {
      throw const FormatException('Invalid BioPay admin response');
    }
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> previewLink(String token) async {
    if (client == null) throw StateError('Connect to preview this request.');
    final result = await RequestDeadline.read(
      client!.rpc<dynamic>(
        'rpc_biopay_link_preview',
        params: {'p_token': token},
      ),
    );
    if (result is! Map)
      throw const FormatException('Invalid BioPay link preview');
    return Map<String, dynamic>.from(result);
  }

  // Only an opaque draft ID is stored on disk. Receiving details and bearer
  // tokens remain in the authenticated backend, never SharedPreferences.
  @override
  Future<void> rememberDraft(String ownerId, String draftId) async {
    if (this.ownerId != ownerId) throw StateError('Account changed.');
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString('biopay.draft.$ownerId', draftId)) {
      throw StateError('Draft shortcut could not be saved.');
    }
  }

  @override
  Future<String?> rememberedDraft(String ownerId) async =>
      (await SharedPreferences.getInstance()).getString(
        'biopay.draft.$ownerId',
      );

  Future<Map<String, String>?> pickPhone() async {
    if (kIsWeb) return null;
    final result = await deviceChannel.invokeMapMethod<String, String>(
      'pickPhone',
    );
    return result;
  }

  Future<String?> pickQrImage() async {
    if (kIsWeb) return null;
    return deviceChannel.invokeMethod<String>('pickQrImage');
  }

  Future<bool> openReviewedInstruction(Map<String, dynamic> prepared) async {
    // Only Android has a validated user-controlled dial-intent adapter.
    // iOS/desktop/web present copyable instructions in the reviewed task.
    if (deviceFamily != 'android' || prepared['mode'] != 'dial') return false;
    final instruction = prepared['instruction'] as String? ?? '';
    if (!RegExp(r'^\*[0-9*]+#$').hasMatch(instruction)) return false;
    final result = await const MethodChannel('rw.mobi.app/biopay_ussd_dialer')
        .invokeMapMethod<Object?, Object?>('launchUssd', {
          'uri': 'tel:${instruction.replaceAll('#', '%23')}',
        });
    return result?['launched'] == true;
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

List<PaymentMethod> workspaceMethods(Map<String, dynamic> workspace) =>
    (workspace['methods'] as List? ?? const [])
        .map((x) => PaymentMethod.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
