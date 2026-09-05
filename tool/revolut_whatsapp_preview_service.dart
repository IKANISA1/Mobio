import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';

/// Only imported by the separate visual proof entrypoint; never sends messages.
/// The preview code is 123456. It never creates or restores an account session.
class PreviewWhatsAppLoginService implements WhatsAppLoginService {
  @override
  Future<WhatsAppLoginResult> sendLoginOtp({
    required String phone,
    required String countryCode,
    required AppRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const WhatsAppLoginResult(success: true, retryAfterSeconds: 10);
  }

  @override
  Future<WhatsAppLoginResult> verifyLoginOtp({
    required String phone,
    required String code,
    required String countryCode,
    required AppRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    // Keep the preview on the form; successful authentication is covered by
    // widget tests and must not imply a real signed-in session in the gallery.
    return const WhatsAppLoginResult(
      success: false,
      message: 'Preview only. Live WhatsApp verification is unavailable here.',
      attemptsRemaining: 3,
    );
  }
}
