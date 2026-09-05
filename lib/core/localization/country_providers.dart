import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/core/localization/country_service.dart';

final countryServiceProvider = Provider(
  (ref) => CountryService(supabase: ref.read(supabaseClientProvider)),
);
