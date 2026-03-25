import 'package:url_launcher/url_launcher.dart';

/// Launches MoMo USSD payment strings on the device.
///
/// This service constructs and launches `tel:` URIs for Rwanda MTN MoMo
/// payment strings. The actual payment happens natively outside the app
/// via the USSD dialer — no payment API integration.
class UssdLauncherService {
  /// Launch a USSD payment string (e.g., `*182*1*1*0788123456#`).
  ///
  /// The device dialer will open with the USSD pre-filled.
  /// Returns true if the launch was successful.
  Future<bool> launchUssdPayment(String ussdString) async {
    final normalized = _normalizeUssdForLaunch(ussdString);
    final uri = Uri.parse('tel:$normalized');

    try {
      final canOpen = await canLaunchUrl(uri);
      if (!canOpen) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Normalize a USSD string for `tel:` URI scheme.
  ///
  /// Ensures: no spaces, `#` → `%23`, proper `tel:` encoding.
  String _normalizeUssdForLaunch(String ussd) {
    var cleaned = ussd.trim().replaceAll(' ', '');
    // Android/iOS tel: scheme requires # to be URL-encoded
    cleaned = cleaned.replaceAll('#', '%23');
    return cleaned;
  }

  /// Build the full USSD string for a MoMo P2P payment.
  ///
  /// Format: `*182*1*1*{localPhone}#`
  /// [recipientPhone] can be in any recognized format:
  /// - `+250788123456`
  /// - `0788123456`
  /// - `788123456`
  static String buildMoMoUssd(String recipientPhone) {
    final digits = recipientPhone.replaceAll(RegExp(r'\D'), '');
    String localPhone;

    if (digits.startsWith('250') && digits.length == 12) {
      localPhone = '0${digits.substring(3)}';
    } else if (digits.startsWith('0') && digits.length == 10) {
      localPhone = digits;
    } else if (digits.length == 9) {
      localPhone = '0$digits';
    } else {
      localPhone = digits;
    }

    return '*182*1*1*$localPhone#';
  }
}
