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
    } on Object catch (_) {
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
}
