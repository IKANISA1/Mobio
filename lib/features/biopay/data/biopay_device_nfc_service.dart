import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/domain/payment_payload.dart';

const bioPayDeviceNfcAid = 'F04D4F42494F00';
const bioPayDeviceNfcSelectApdu = '00A4040007${bioPayDeviceNfcAid}00';

class BioPayDeviceNfcService {
  const BioPayDeviceNfcService();

  static const _channel = MethodChannel('rw.mobi.app/biopay_device_nfc');
  // Native HCE writes remain ordered even after a caller's deadline expires.
  // Otherwise a late start can resurrect an advertisement after stop/new start.
  static Future<void>? _nativeMutationTail;

  Future<Object?> _mutate(
    String method, {
    Map<String, Object?>? arguments,
    bool Function()? canDispatch,
  }) {
    Future<Object?> dispatch() {
      if (canDispatch != null && !canDispatch()) {
        throw const StaleAccountWork();
      }
      return _channel.invokeMethod<Object?>(method, arguments);
    }

    final predecessor = _nativeMutationTail;
    final work = predecessor == null
        ? Future<Object?>.sync(dispatch)
        : predecessor.then((_) => dispatch());
    final tail = work.then<void>((_) {}, onError: (Object _) {});
    _nativeMutationTail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_nativeMutationTail, tail)) _nativeMutationTail = null;
      }),
    );
    return work;
  }

  Future<BioPayDeviceNfcStatus> startPaymentRequest(
    BioPayUssdPaymentRequest request, {
    bool Function()? canDispatch,
  }) async {
    final payload = buildDeviceNfcPaymentPayload(request);
    var awaitingDispatch = true;
    try {
      final raw = await RequestDeadline.mutation(
        _mutate(
          'start',
          arguments: {
            'payload': payload,
            'token': request.token,
            'expiresAt': request.expiresAt?.toIso8601String(),
          },
          canDispatch: () => awaitingDispatch && (canDispatch?.call() ?? true),
        ),
        operation: 'start_device_nfc_advertisement',
        operationId: request.id,
        timeout: const Duration(seconds: 6),
      );
      return _mutationStatus(
        raw,
        operation: 'start_device_nfc_advertisement',
        operationId: request.id,
        request: request,
      );
    } finally {
      // A start that never reached native code must not run after its caller
      // has stopped waiting. Already dispatched work retains its real tail.
      awaitingDispatch = false;
    }
  }

  Future<BioPayDeviceNfcStatus> stop({bool Function()? canDispatch}) async {
    final raw = await RequestDeadline.mutation(
      _mutate('stop', canDispatch: canDispatch),
      operation: 'stop_device_nfc_advertisement',
      timeout: const Duration(seconds: 6),
    );
    return _mutationStatus(raw, operation: 'stop_device_nfc_advertisement');
  }

  BioPayDeviceNfcStatus _mutationStatus(
    Object? raw, {
    required String operation,
    String? operationId,
    BioPayUssdPaymentRequest? request,
  }) {
    MutationOutcomeUnknownException unconfirmed() =>
        MutationOutcomeUnknownException(
          operation: operation,
          operationId: operationId,
        );
    if (raw is! Map || raw['supported'] is! bool || raw['enabled'] is! bool) {
      throw unconfirmed();
    }
    if (raw['enabled'] == true) {
      final rawExpiry = raw['expiresAt'];
      final expiry = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
      final requestedExpiry = request?.expiresAt;
      // Native policy caps expiry to five minutes and truncates to milliseconds.
      // A shorter valid lifetime is legitimate; a different token or extended
      // lifetime cannot acknowledge this original advertisement.
      final usable =
          request != null &&
          raw['supported'] == true &&
          raw['token'] == request.token &&
          request.token.isNotEmpty &&
          expiry != null &&
          expiry.isAfter(DateTime.now()) &&
          requestedExpiry != null &&
          expiry.millisecondsSinceEpoch <=
              requestedExpiry.millisecondsSinceEpoch;
      if (!usable) throw unconfirmed();
    }
    return BioPayDeviceNfcStatus.fromMap(raw);
  }

  Future<BioPayDeviceNfcStatus> status() async {
    final raw = await RequestDeadline.read(
      _channel.invokeMapMethod<String, Object?>('status'),
      timeout: const Duration(seconds: 5),
    );
    return BioPayDeviceNfcStatus.fromMap(raw);
  }
}

String buildDeviceNfcPaymentPayload(BioPayUssdPaymentRequest request) {
  return bioPayUssdTelPayload(request.dialerCode);
}

String? deviceNfcPayloadFromApduResponse(String response) {
  final value = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (!value.endsWith('9000') || value.length <= 4) return null;
  final payloadHex = value.substring(0, value.length - 4);
  if (payloadHex.length.isOdd) return null;
  final bytes = <int>[];
  for (var i = 0; i < payloadHex.length; i += 2) {
    final byte = int.tryParse(payloadHex.substring(i, i + 2), radix: 16);
    if (byte == null) return null;
    bytes.add(byte);
  }
  return utf8.decode(bytes, allowMalformed: true).trim();
}

String deviceNfcTokenFromApduResponse(String response) {
  return bioPayTokenFromPayload(deviceNfcPayloadFromApduResponse(response));
}

class BioPayDeviceNfcStatus {
  const BioPayDeviceNfcStatus({
    required this.supported,
    required this.enabled,
    this.token,
    this.expiresAt,
    this.reason,
  });

  final bool supported;
  final bool enabled;
  final String? token;
  final DateTime? expiresAt;
  final String? reason;

  bool get canAdvertise =>
      supported &&
      enabled &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());

  static BioPayDeviceNfcStatus fromMap(Map<Object?, Object?>? raw) {
    if (raw == null) {
      return const BioPayDeviceNfcStatus(
        supported: false,
        enabled: false,
        reason: 'Device NFC bridge unavailable.',
      );
    }
    return BioPayDeviceNfcStatus(
      supported: raw['supported'] == true,
      enabled: raw['enabled'] == true,
      token: raw['token']?.toString(),
      expiresAt: DateTime.tryParse(raw['expiresAt']?.toString() ?? ''),
      reason: raw['reason']?.toString(),
    );
  }
}
