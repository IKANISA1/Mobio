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
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');

  /// Public account deletion instructions URL for Play review and in-app access.
  static const accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
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

  /// Validate that configuration is present (call at app startup).
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static bool get canRunWithoutBackend =>
      !kReleaseMode && localUiPreviewEnabled;

  static bool get isLocalUiPreview => !isConfigured && canRunWithoutBackend;

  static bool get shouldShowConfigError =>
      !isConfigured && !canRunWithoutBackend;

  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.isNotEmpty;

  static bool get hasAccountDeletionUrl => accountDeletionUrl.isNotEmpty;
}
