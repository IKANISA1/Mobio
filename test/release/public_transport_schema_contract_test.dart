import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public transport schema contract', () {
    const migrationPath =
        'supabase/migrations/20260608093000_public_transport_booking_foundation.sql';

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
