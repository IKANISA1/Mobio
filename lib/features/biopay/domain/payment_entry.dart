import 'dart:convert';

import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';

const bioPayPublicHost = 'mobio.ikanisa.com';

class PaymentEntry {
  const PaymentEntry({
    this.token,
    this.manual,
    this.amount,
    this.legacy = false,
  });
  final String? token;
  final PaymentMethod? manual;
  final int? amount;
  final bool legacy;
}

Uri bioPayShareUri(String token) {
  if (!_tokenPattern.hasMatch(token)) {
    throw const FormatException('Invalid link token');
  }
  return Uri.https(bioPayPublicHost, '/biopay/pay/$token');
}

final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{24,128}$');

/// One parser for camera, gallery, clipboard, NFC and incoming links.
/// Legacy USSD is decoded into unverified input, never an executable action.
PaymentEntry? parsePaymentEntry(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.length > 4096) return null;
  if (_tokenPattern.hasMatch(value)) {
    return PaymentEntry(token: value, legacy: value.length != 48);
  }
  final uri = Uri.tryParse(value);
  if (uri != null &&
      uri.scheme == 'https' &&
      uri.host == bioPayPublicHost &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.hasFragment) {
    if (uri.pathSegments.length == 3 &&
        uri.pathSegments[0] == 'biopay' &&
        uri.pathSegments[1] == 'pay' &&
        _tokenPattern.hasMatch(uri.pathSegments[2]) &&
        uri.query.isEmpty) {
      final token = uri.pathSegments[2];
      return PaymentEntry(token: token, legacy: token.length != 48);
    }
    if (uri.path == '/biopay/nfc' && uri.queryParameters['receiver'] != null) {
      final type = uri.queryParameters['type'];
      final rawReceiver = uri.queryParameters['receiver']!;
      if (type == 'momo_number' || type == 'momo_pay_code') {
        return _manualEntry(type == 'momo_number', rawReceiver, null);
      }
    }
  }
  if (value.startsWith('{')) {
    try {
      final object = jsonDecode(value);
      if (object is Map) {
        final token =
            object['token'] ??
            object['biopay_token'] ??
            object['payment_token'];
        if (token is String && _tokenPattern.hasMatch(token)) {
          return PaymentEntry(token: token, legacy: true);
        }
      }
    } on FormatException {
      return null;
    }
  }
  String code = value;
  if (uri?.scheme == 'tel') {
    try {
      code = Uri.decodeComponent(value.substring(4));
    } on ArgumentError {
      return null;
    }
  }
  final match = RegExp(
    r'^\*182\*(1\*1|8\*1)\*([0-9]+)(?:\*([0-9]+))?#$',
  ).firstMatch(code);
  if (match == null) return null;
  return _manualEntry(match[1] == '1*1', match[2]!, match[3]);
}

PaymentEntry? _manualEntry(bool phone, String receiver, String? amount) {
  final identifier = phone ? normalizeRwandaPhone(receiver) : receiver;
  if (identifier == null ||
      (!phone && !RegExp(r'^[0-9]{3,20}$').hasMatch(identifier))) {
    return null;
  }
  final francs = amount == null ? null : parseRwf(amount);
  if (amount != null && francs == null) return null;
  return PaymentEntry(
    manual: PaymentMethod(
      id: 'manual',
      version: 0,
      ownerId: '',
      provider: 'mtn_rw',
      kind: phone
          ? PaymentMethodKind.mobileWallet
          : PaymentMethodKind.merchantCode,
      identifier: identifier,
      label: 'Entered receiving details',
    ),
    amount: francs,
    legacy: true,
  );
}
