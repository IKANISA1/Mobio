import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EV charger locator contract', () {
    const migrationPath =
        'supabase/migrations/20260615133000_ev_charger_locator.sql';
    const modelPath = 'lib/models/ev_charger.dart';
    const servicePath = 'lib/core/services/ev_charger_service.dart';
    const screenPath =
        'lib/features/ev_chargers/ev_charger_locator_screen.dart';
    const adminScreenPath = 'lib/features/admin/admin_ev_chargers_screen.dart';
    const routerPath = 'lib/core/router/app_router.dart';
    const wrappersPath = 'lib/core/router/screen_wrappers.dart';
    const homePath = 'lib/features/home/home_screen.dart';
    const adminUiPath = 'lib/features/admin/widgets/admin_ui.dart';
    const mapsPath = 'lib/core/services/google_maps_deep_link_service.dart';
    const providersPath = 'lib/core/providers/service_providers.dart';
    const placesServicePath = 'lib/core/services/places_service.dart';
    const mapsGatewayPath = 'supabase/functions/maps-gateway/index.ts';

    test('Supabase migration defines managed EV charger catalog and RPCs', () {
      final migration = File(migrationPath).readAsStringSync();

      expect(
        migration,
        contains('create table if not exists public.ev_chargers'),
      );
      expect(migration, contains('ev_chargers.manage'));
      expect(migration, contains('ev_chargers_read_active_or_admin'));
      expect(migration, contains('rpc_find_nearest_ev_chargers'));
      expect(migration, contains('p_radius_km double precision default 30'));
      expect(
        migration,
        contains('limit least(greatest(coalesce(p_limit, 5), 1), 5)'),
      );
      expect(migration, contains('rpc_admin_upsert_ev_charger'));
      expect(migration, contains('rpc_admin_set_ev_charger_active'));
      expect(migration, contains('admin_audit_log'));
    });

    test('Flutter app exposes EV charger locator from home and route', () {
      final model = File(modelPath).readAsStringSync();
      final service = File(servicePath).readAsStringSync();
      final screen = File(screenPath).readAsStringSync();
      final router = File(routerPath).readAsStringSync();
      final wrappers = File(wrappersPath).readAsStringSync();
      final home = File(homePath).readAsStringSync();
      final maps = File(mapsPath).readAsStringSync();
      final providers = File(providersPath).readAsStringSync();
      final placesService = File(placesServicePath).readAsStringSync();
      final mapsGateway = File(mapsGatewayPath).readAsStringSync();

      expect(model, contains('class EvCharger'));
      expect(service, contains('rpc_find_nearest_ev_chargers'));
      expect(service, contains('radiusKm = 30'));
      expect(service, contains('limit = 5'));
      expect(providers, contains('evChargerServiceProvider'));
      expect(screen, contains('EvChargerLocatorScreen'));
      expect(screen, contains('Find nearby EV Chargers'));
      expect(screen, contains('Find EV chargers'));
      expect(screen, contains('Open on Google Maps'));
      expect(screen, contains('geocodeAddress'));
      expect(screen, contains('_addressController.text.trim().length >= 3'));
      expect(placesService, contains('getAutocompletePredictions'));
      expect(placesService, contains('getPlaceDetails'));
      expect(placesService, contains('geocodeAddress'));
      expect(mapsGateway, contains('"autocomplete"'));
      expect(mapsGateway, contains('"place_details"'));
      expect(mapsGateway, contains('"geocode"'));
      expect(mapsGateway, contains('maps/api/geocode/json'));
      expect(mapsGateway, contains('places:autocomplete'));
      expect(mapsGateway, contains('GOOGLE_MAPS_SERVER_API_KEY'));
      expect(maps, contains('openEvChargerLocations'));
      expect(router, contains("path: '/ev-chargers'"));
      expect(wrappers, contains('EvChargerLocatorScreenWrapper'));
      expect(home, contains("label: 'EV Charger'"));
      expect(home, contains('onEvChargers'));
      expect(home, isNot(contains("label: 'Trips',\n")));
    });

    test('admin panel manages EV chargers', () {
      final service = File(servicePath).readAsStringSync();
      final adminScreen = File(adminScreenPath).readAsStringSync();
      final router = File(routerPath).readAsStringSync();
      final adminUi = File(adminUiPath).readAsStringSync();

      expect(service, contains('rpc_admin_upsert_ev_charger'));
      expect(service, contains('rpc_admin_set_ev_charger_active'));
      expect(adminScreen, contains('AdminEvChargersScreen'));
      expect(adminScreen, contains('Add EV charger'));
      expect(adminScreen, contains('currentTab: AdminWorkspaceTab.evChargers'));
      expect(router, contains("path: '/admin/ev-chargers'"));
      expect(adminUi, contains('AdminWorkspaceTab.evChargers'));
      expect(adminUi, contains("route: '/admin/ev-chargers'"));
    });
  });
}
