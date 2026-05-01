import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/payments/models/payment_intent.dart';
import 'package:mobi_app/features/payments/models/payment_session_resolution.dart';
import 'package:mobi_app/features/payments/models/ussd_payment_instruction.dart';

class PaymentService {
  const PaymentService();

  static const _externalUssdOnlyMessage =
      'MOBI does not support in-app payments. Pay outside the app with USSD, then wait for manual confirmation.';

  UssdPaymentInstruction? instructionFromPayload(String payload) {
    final ussdString = _extractUssdString(payload);
    if (ussdString == null) return null;

    return UssdPaymentInstruction(ussdString: ussdString);
  }

  Future<PaymentIntent> createIntent({
    required String payeeId,
    String? tripId,
    required double amount,
    required String currency,
    required String paymentMethod,
  }) async {
    throw const UnsupportedFlowException(
      message: _externalUssdOnlyMessage,
      debugMessage: 'createIntent is disabled: external USSD only.',
    );
  }

  Future<PaymentIntent> verifyStatus(String intentId) async {
    throw const UnsupportedFlowException(
      message: _externalUssdOnlyMessage,
      debugMessage: 'verifyStatus is disabled: external USSD only.',
    );
  }

  Future<PaymentSessionResolution?> resolveQrSession(
    String sessionToken,
  ) async {
    throw const UnsupportedFlowException(
      message: _externalUssdOnlyMessage,
      debugMessage:
          'resolveQrSession is disabled: QR payloads must carry USSD.',
    );
  }

  Future<PaymentSessionResolution?> resolveNfcSession(
    String ndefPayload,
  ) async {
    throw const UnsupportedFlowException(
      message: _externalUssdOnlyMessage,
      debugMessage:
          'resolveNfcSession is disabled: NFC payloads must carry USSD.',
    );
  }

  Stream<PaymentIntent> watchIntent(String intentId) {
    return Stream<PaymentIntent>.error(
      const UnsupportedFlowException(
        message: _externalUssdOnlyMessage,
        debugMessage: 'watchIntent is disabled: external USSD only.',
      ),
    );
  }

  String? _extractUssdString(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme.toLowerCase() == 'tel') {
      return _normalizeDialableUssd(uri.path);
    }

    if (uri != null && uri.queryParameters.containsKey('ussd')) {
      return _normalizeDialableUssd(uri.queryParameters['ussd'] ?? '');
    }

    return _normalizeDialableUssd(trimmed);
  }

  String? _normalizeDialableUssd(String candidate) {
    final decoded = _decodePayload(candidate);
    final normalized = UssdPaymentInstruction.normalizeUssd(decoded);
    if (normalized.startsWith('*') && normalized.endsWith('#')) {
      return normalized;
    }

    return null;
  }

  String _decodePayload(String candidate) {
    try {
      return Uri.decodeFull(candidate);
    } on FormatException {
      return candidate;
    }
  }
}
