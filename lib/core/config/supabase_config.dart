/// Supabase configuration.
///
/// This app prefers values injected at build time via `--dart-define`, but it
/// also carries the linked MOBI project configuration as a fallback so debug
/// device builds remain usable for UAT.
///
/// Build command:
/// ```
/// flutter build appbundle \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key
/// ```
class SupabaseConfig {
  const SupabaseConfig._();

  static const _fallbackUrl = 'https://paysnhuxngsvzdpwlosv.supabase.co';
  static const _fallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBheXNuaHV4bmdzdnpkcHdsb3N2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMTA2NDYsImV4cCI6MjA3NTU4NjY0Nn0.EPgKO4rBjtyAFW55k0qUGd4MBLtbr76aH_wjfGGTkXU';

  /// Supabase project URL.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _fallbackUrl,
  );

  /// Supabase anon key.
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _fallbackAnonKey,
  );

  /// Edge functions base URL derived from project URL.
  static String get functionsBaseUrl => '$url/functions/v1';

  /// Validate that configuration is present (call at app startup).
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
