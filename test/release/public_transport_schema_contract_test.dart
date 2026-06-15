import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public transport schema contract', () {
    const migrationPath =
        'supabase/migrations/20260608093000_public_transport_booking_foundation.sql';
    const busOnboardingMigrationPath =
        'supabase/migrations/20260612100000_bus_driver_profile_onboarding.sql';
    const driverVehicleMigrationPath =
        'supabase/migrations/20260612203130_driver_vehicle_records.sql';
    const rentalsVehicleMigrationPath =
        'supabase/migrations/20260614153000_rentals_vehicle_type_onboarding.sql';
    const agencyAdminMigrationPath =
        'supabase/migrations/20260615090000_transport_agency_admin_management.sql';
    const editProfileProviderPath =
        'lib/features/profile/providers/edit_profile_provider.dart';
    const publicTransportServicePath =
        'lib/core/services/public_transport_service.dart';
    const appRouterPath = 'lib/core/router/app_router.dart';
    const adminUiPath = 'lib/features/admin/widgets/admin_ui.dart';
    const adminAgencyScreenPath =
        'lib/features/admin/admin_transport_agencies_screen.dart';

    test('adds required booking-specific tables', () {
      final migration = File(migrationPath).readAsStringSync();

      for (final table in [
        'transport_agencies',
        'agency_buses',
        'transport_routes',
        'route_stops',
        'bus_schedules',
        'bus_seat_inventory',
        'bus_bookings',
        'bus_booking_payments',
        'bus_tracking_sources',
        'bus_location_events',
      ]) {
        expect(migration, contains('create table if not exists public.$table'));
        expect(
          migration,
          contains('alter table public.$table enable row level security'),
        );
      }
    });

    test('adds required public transport RPCs', () {
      final migration = File(migrationPath).readAsStringSync();

      for (final rpc in [
        'rpc_search_bus_schedules',
        'rpc_hold_bus_seats',
        'rpc_confirm_bus_booking',
        'rpc_cancel_bus_booking',
        'rpc_get_bus_payment_status',
        'rpc_ingest_bus_location',
      ]) {
        expect(migration, contains('create or replace function public.$rpc'));
        expect(migration, contains('grant execute on function public.$rpc'));
      }
    });

    test('keeps expansion separate from removed legacy tables', () {
      final migration = File(migrationPath).readAsStringSync();

      for (final legacy in [
        'payment_intents',
        'payment_events',
        'qr_payment_sessions',
        'nfc_payment_sessions',
        'ride_requests',
        'trip_requests',
        'biopay_wallets',
        'transactions',
      ]) {
        expect(
          migration,
          isNot(contains('create table if not exists public.$legacy')),
        );
      }
    });

    test('defines agency, booking, and tracking permissions', () {
      final migration = File(migrationPath).readAsStringSync();

      expect(migration, contains('transport.agencies.manage'));
      expect(migration, contains('transport.bookings.manage'));
      expect(migration, contains('transport.tracking.ingest'));
    });

    test('bus agency picker and admin management are Supabase-backed', () {
      final migration = File(migrationPath).readAsStringSync();
      final agencyAdminMigration = File(
        agencyAdminMigrationPath,
      ).readAsStringSync();
      final publicTransportService = File(
        publicTransportServicePath,
      ).readAsStringSync();
      final appRouter = File(appRouterPath).readAsStringSync();
      final adminUi = File(adminUiPath).readAsStringSync();
      final adminAgencyScreen = File(adminAgencyScreenPath).readAsStringSync();

      expect(
        migration,
        contains('create table if not exists public.transport_agencies'),
      );
      expect(migration, contains('transport_agencies_read_active_or_admin'));
      expect(publicTransportService, contains("from('transport_agencies')"));
      expect(publicTransportService, contains('getAgencies'));
      expect(publicTransportService, contains('getAgencyNames'));
      expect(
        publicTransportService,
        contains('rpc_admin_upsert_transport_agency'),
      );
      expect(
        publicTransportService,
        contains('rpc_admin_set_transport_agency_active'),
      );
      expect(
        publicTransportService,
        contains('rpc_admin_remove_transport_agency'),
      );
      expect(
        agencyAdminMigration,
        contains('transport.agencies.manage permission required'),
      );
      expect(
        agencyAdminMigration,
        contains(
          'create or replace function public.rpc_admin_upsert_transport_agency',
        ),
      );
      expect(
        agencyAdminMigration,
        contains(
          'create or replace function public.rpc_admin_set_transport_agency_active',
        ),
      );
      expect(
        agencyAdminMigration,
        contains(
          'create or replace function public.rpc_admin_remove_transport_agency',
        ),
      );
      expect(agencyAdminMigration, contains('admin_audit_log'));
      expect(
        agencyAdminMigration,
        contains(
          'grant execute on function public.rpc_admin_upsert_transport_agency',
        ),
      );
      expect(appRouter, contains("path: '/admin/agencies'"));
      expect(adminUi, contains('AdminWorkspaceTab.agencies'));
      expect(adminAgencyScreen, contains('AdminTransportAgenciesScreen'));
      expect(adminAgencyScreen, contains('Add agency'));
      expect(adminAgencyScreen, contains('Edit agency'));
      expect(adminAgencyScreen, contains('Remove'));
      expect(
        adminAgencyScreen,
        contains('Loaded from Supabase transport_agencies.'),
      );
    });

    test('adds bus driver onboarding profile fields and RPC payloads', () {
      final migration = File(busOnboardingMigrationPath).readAsStringSync();

      expect(migration, contains('bus_agency_name text'));
      expect(migration, contains('bus_passenger_capacity integer'));
      expect(migration, contains('profiles_bus_passenger_capacity_check'));
      expect(migration, contains("v_vehicle_type <> 'bus'"));
      expect(migration, contains('p_bus_agency_name text default null'));
      expect(
        migration,
        contains('p_bus_passenger_capacity integer default null'),
      );
      expect(migration, contains('BUS_DRIVER_DETAILS_REQUIRED'));
      expect(
        migration,
        contains(
          'Bus drivers must provide agency name and passenger capacity.',
        ),
      );
      expect(migration, contains("when p_vehicle_type = 'bus'"));
      expect(migration, contains('public.rpc_get_public_profile'));
    });

    test('persists driver onboarding vehicle records', () {
      final migration = File(driverVehicleMigrationPath).readAsStringSync();

      expect(migration, contains('create table if not exists public.vehicles'));
      expect(migration, contains('owner_id uuid not null'));
      expect(migration, contains('vehicle_type_id text not null'));
      expect(migration, contains('plate_number text not null'));
      expect(migration, contains('idx_vehicles_one_active_per_owner'));
      expect(migration, contains('where is_active'));
      expect(
        migration,
        contains('alter table public.vehicles enable row level security'),
      );
      expect(migration, contains('vehicles_select_owner_or_admin'));
      expect(
        migration,
        contains('public.fn_upsert_active_vehicle(uuid, text, text)'),
      );
      expect(migration, contains('VEHICLE_PLATE_REQUIRED'));
      expect(migration, contains('VEHICLE_TYPE_UNAVAILABLE'));
      expect(migration, contains('public.rpc_enable_driver_mode'));
      expect(migration, contains('public.rpc_disable_driver_mode'));
      expect(migration, contains('set\n    is_active = false'));
    });

    test('adds rentals vehicle type and onboarding rental model contract', () {
      final migration = File(rentalsVehicleMigrationPath).readAsStringSync();

      expect(
        migration,
        contains(
          "alter type public.vehicle_type_enum add value if not exists 'rentals'",
        ),
      );
      expect(migration, contains("values ('rentals', 'Rentals'"));
      expect(migration, contains('rental_vehicle_model text'));
      expect(migration, contains('profiles_rental_vehicle_model_check'));
      expect(migration, contains('vehicles_rental_vehicle_model_check'));
      for (final model in ['SUV', 'Sedan', 'Truck', 'Van', 'Bus']) {
        expect(migration, contains("'$model'"));
      }
      expect(migration, contains('p_rental_vehicle_model text default null'));
      expect(migration, contains('RENTAL_VEHICLE_MODEL_REQUIRED'));
      expect(
        migration,
        contains('Rental owners must choose SUV, Sedan, Truck, Van, or Bus.'),
      );
      expect(
        migration,
        contains("values ('rentals', false, 0, 0, 0, true, true)"),
      );
    });

    test('requires a vehicle plate before saving a driver profile', () {
      final provider = File(editProfileProviderPath).readAsStringSync();

      expect(provider, contains('s.isDriver && normalizedPlate.isEmpty'));
      expect(provider, contains('Enter the vehicle plate number.'));
    });

    test('does not let passengers self-confirm paid bookings', () {
      final migration = File(migrationPath).readAsStringSync();

      expect(
        migration,
        contains(
          'Payment confirmation requires agency or service authorization.',
        ),
      );
      expect(migration, isNot(contains('and passenger_id = v_user_id')));
    });
  });
}
