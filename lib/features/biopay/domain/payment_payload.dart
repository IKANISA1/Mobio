import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';

String buildBioPayQrPayload(BioPayUssdPaymentRequest request) {
  return bioPayShareUri(request.token).toString();
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
  if (rawValue == null) return '';
  return parsePaymentEntry(rawValue)?.token ?? '';
}
