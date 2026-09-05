import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/ev_chargers/data/ev_charger_service.dart';

final evChargerServiceProvider = Provider(
  (ref) => EvChargerService(
    supabase: SupabaseConfig.isConfigured
        ? ref.read(supabaseClientProvider)
        : null,
  ),
);
