import 'package:flutter/foundation.dart';

/// Supabase configuration.
///
/// This app requires values injected at build time via `--dart-define`.
///
/// Build command:
/// ```
/// flutter build appbundle \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key \
///   --dart-define=PRIVACY_POLICY_URL=https://example.com/privacy \
///   --dart-define=ACCOUNT_DELETION_URL=https://example.com/account-deletion
/// ```
class SupabaseConfig {
  const SupabaseConfig._();

  /// Supabase project URL.
  static const url = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon key.
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Public privacy policy URL for Play review and in-app access.
  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://mobio.ikanisa.com/privacy-policy',
  );

  /// Public terms URL for in-app access.
  static const termsAndConditionsUrl = String.fromEnvironment(
    'TERMS_AND_CONDITIONS_URL',
    defaultValue: 'https://mobio.ikanisa.com/terms-and-conditions',
  );

  /// Public account deletion instructions URL for Play review and in-app access.
  static const accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
    defaultValue: 'https://mobio.ikanisa.com/account-deletion',
  );

  /// Public Google Play listing URL.
  static const playStoreUrl = String.fromEnvironment(
    'PLAY_STORE_URL',
    defaultValue: 'https://play.google.com/store/apps/details?id=rw.mobi.app',
  );

  /// Public App Store discovery URL. Override with the exact listing URL.
  static const appStoreUrl = String.fromEnvironment(
    'APP_STORE_URL',
    defaultValue: 'https://apps.apple.com/search?term=Mobio',
  );

  /// Public support WhatsApp number without a leading plus sign.
  static const supportWhatsAppNumber = String.fromEnvironment(
    'SUPPORT_WHATSAPP_NUMBER',
    defaultValue: '250795588248',
  );

  /// Edge functions base URL derived from project URL.
  static String get functionsBaseUrl => '$url/functions/v1';

  /// Enables local UI QA when backend dart-defines are intentionally absent.
  ///
  /// This is ignored in release builds so production still fails closed.
  static const localUiPreviewEnabled = bool.fromEnvironment(
    'MOBI_LOCAL_UI_PREVIEW',
    defaultValue: true,
  );

  /// Forces deterministic UI preview data for screenshot proof targets.
  ///
  /// Ignored in release builds so production still follows the fail-closed
  /// Supabase configuration rule.
  static const visualProofModeEnabled = bool.fromEnvironment(
    'MOBI_VISUAL_PROOF',
  );

  static bool get isVisualProofMode => !kReleaseMode && visualProofModeEnabled;

  /// Validate that configuration is present (call at app startup).
  static bool get isConfigured =>
      !isVisualProofMode && url.isNotEmpty && anonKey.isNotEmpty;

  static bool get canRunWithoutBackend =>
      !kReleaseMode && localUiPreviewEnabled;

  static bool get isLocalUiPreview =>
      (!isConfigured || isVisualProofMode) && canRunWithoutBackend;

  static bool get shouldShowConfigError =>
      !isConfigured && !canRunWithoutBackend;

  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.isNotEmpty;

  static bool get hasAccountDeletionUrl => accountDeletionUrl.isNotEmpty;
}
