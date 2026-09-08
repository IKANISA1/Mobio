import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    dynamic result;
    try {
      result = await client!.rpc<dynamic>(
        'rpc_biopay_discovery',
        params: {'p_action': action, 'p_data': data},
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
    if (ownerId != account) throw StateError('The signed-in account changed.');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> adminCall(
    String action,
    Map<String, dynamic> data,
  ) async {
    final account = client?.auth.currentUser?.id;
    if (account == null || client == null) {
      throw StateError('Admin connection required.');
    }
    final response = await client!.rpc<dynamic>(
      'rpc_admin_biopay_routes',
      params: {'p_action': action, 'p_data': data},
    );
    if (account != client!.auth.currentUser?.id) {
      throw StateError('Account changed.');
    }
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> previewLink(String token) async {
    if (client == null) throw StateError('Connect to preview this request.');
    final result = await client!.rpc<dynamic>(
      'rpc_biopay_link_preview',
      params: {'p_token': token},
    );
    return Map<String, dynamic>.from(result as Map);
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
