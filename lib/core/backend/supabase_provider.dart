import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Supabase client is unavailable because Supabase is not configured.',
    );
  }
  return Supabase.instance.client;
});
