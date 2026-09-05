import 'dart:convert';

import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';

String buildBioPayQrPayload(BioPayUssdPaymentRequest request) {
  return bioPayUssdTelPayload(request.dialerCode);
}

String bioPayUssdTelPayload(String ussdCode) {
  final encoded = ussdCode.trim().replaceAll('#', Uri.encodeComponent('#'));
  return 'tel:$encoded';
}

String bioPayUssdCodeFromPayload(String? rawValue) {
  final raw = rawValue?.trim();
  if (raw == null || raw.isEmpty) return '';
  if (raw.startsWith('*182') && raw.endsWith('#')) return raw;

  final uri = Uri.tryParse(raw);
  if (uri?.scheme.toLowerCase() != 'tel') return '';
  final code = Uri.decodeComponent(uri!.path).trim();
  if (!code.startsWith('*182') || !code.endsWith('#')) return '';
  return code;
}

String bioPayTokenFromPayload(String? rawValue) {
  final raw = rawValue?.trim();
  if (raw == null || raw.isEmpty) return '';
  if (raw.startsWith('*182')) return '';

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      for (final key in const ['token', 'biopay_token', 'payment_token']) {
        final value = decoded[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return '';
    }
  } on FormatException {
    // Older QR/NFC payloads may be a bare token.
  }

  final uri = Uri.tryParse(raw);
  final token = uri?.queryParameters['token']?.trim();
  if (token != null && token.isNotEmpty) return token;
  if (uri != null && uri.hasScheme) return '';

  return raw;
}
