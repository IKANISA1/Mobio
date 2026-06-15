import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mobi_app/features/biopay/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';

const bioPayDeviceNfcAid = 'F04D4F42494F00';
const bioPayDeviceNfcSelectApdu = '00A4040007${bioPayDeviceNfcAid}00';

class BioPayDeviceNfcService {
  const BioPayDeviceNfcService();

  static const _channel = MethodChannel('rw.mobi.app/biopay_device_nfc');

  Future<BioPayDeviceNfcStatus> startPaymentRequest(
    BioPayUssdPaymentRequest request,
  ) async {
    final payload = buildDeviceNfcPaymentPayload(request);
    final raw = await _channel.invokeMapMethod<String, Object?>('start', {
      'payload': payload,
      'token': request.token,
      'expiresAt': request.expiresAt?.toIso8601String(),
    });
    return BioPayDeviceNfcStatus.fromMap(raw);
  }

  Future<BioPayDeviceNfcStatus> stop() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('stop');
    return BioPayDeviceNfcStatus.fromMap(raw);
  }

  Future<BioPayDeviceNfcStatus> status() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('status');
    return BioPayDeviceNfcStatus.fromMap(raw);
  }
}

String buildDeviceNfcPaymentPayload(BioPayUssdPaymentRequest request) {
  return Uri(
    scheme: 'https',
    host: bioPayNfcAppLinkHost,
    path: bioPayNfcAppLinkPath,
    queryParameters: {'token': request.token},
  ).toString();
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

  bool get canAdvertise => supported && enabled;

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
