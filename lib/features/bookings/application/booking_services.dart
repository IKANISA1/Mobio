import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/bookings/data/public_transport_service.dart';
import 'package:mobi_app/features/bookings/data/trip_service.dart';

final tripServiceProvider = Provider(
  (ref) => TripService(supabase: ref.read(supabaseClientProvider)),
);

final publicTransportServiceProvider = Provider(
  (ref) => PublicTransportService(
    supabase: SupabaseConfig.isConfigured
        ? ref.read(supabaseClientProvider)
        : null,
  ),
);
