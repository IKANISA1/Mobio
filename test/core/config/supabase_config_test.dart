import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/config/supabase_config.dart';

void main() {
  test('missing Supabase config enters local UI preview in debug tests', () {
    expect(SupabaseConfig.isConfigured, isFalse);
    expect(SupabaseConfig.isLocalUiPreview, isTrue);
    expect(SupabaseConfig.shouldShowConfigError, isFalse);
  });
}
