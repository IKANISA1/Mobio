import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scheduling production hardening contract', () {
    const migrationPath =
        'supabase/migrations/20260613143000_scheduling_rpc_production_hardening.sql';

    test('keeps user trip mutations behind validated audited RPCs', () {
      final service = File(
        'lib/core/services/trip_service.dart',
      ).readAsStringSync();
      final migration = File(migrationPath).readAsStringSync();

      expect(service, contains("'rpc_create_trip'"));
      expect(service, contains("'rpc_update_trip'"));
      expect(service, contains("'rpc_cancel_trip'"));
      expect(service, isNot(contains(".from('trips').update")));

      for (final rpc in [
        'rpc_create_trip',
        'rpc_update_trip',
        'rpc_cancel_trip',
      ]) {
        expect(migration, contains('create or replace function public.$rpc'));
        expect(migration, contains('grant execute on function public.$rpc'));
      }

      expect(migration, contains('public._normalize_trip_schedule_payload'));
      expect(migration, contains('public.trip_audit_events'));
      expect(migration, contains("'trip.created'"));
      expect(migration, contains("'trip.updated'"));
      expect(migration, contains("'trip.cancelled'"));
      expect(migration, contains('drop policy if exists trips_update_own'));
      expect(migration, contains('drop policy if exists trips_delete_own'));
      expect(migration, contains('create policy trips_update_rpc_only'));
    });

    test(
      'validates schedule timing recurrence route and duplicate contracts',
      () {
        final migration = File(migrationPath).readAsStringSync();
        final state = File(
          'lib/features/bookings/models/schedule_trip_state.dart',
        ).readAsStringSync();
        final provider = File(
          'lib/features/bookings/providers/schedule_trip_provider.dart',
        ).readAsStringSync();
        final service = File(
          'lib/core/services/trip_service.dart',
        ).readAsStringSync();

        expect(migration, contains('Departure time must be in the future.'));
        expect(migration, contains('Recurring days must be between 0 and 6.'));
        expect(
          migration,
          contains('Recurring days must not contain duplicates.'),
        );
        expect(
          migration,
          contains('Recurring trips can be scheduled up to 180 days ahead.'),
        );
        expect(migration, contains('idx_trips_author_client_request'));
        expect(migration, contains('client_request_id'));
        expect(migration, contains('origin_place_id'));
        expect(migration, contains('destination_place_id'));
        expect(migration, contains('recurrence_end_date'));
        expect(migration, contains('recurrence_skip_dates'));
        expect(
          migration,
          contains('Skipped repeat dates must stay inside the repeat window.'),
        );

        expect(state, contains('clientRequestId'));
        expect(state, contains('Choose a pickup from the location results.'));
        expect(
          state,
          contains('Choose a destination from the location results.'),
        );
        expect(provider, contains('originPlaceId: s.originDetails!.placeId'));
        expect(
          provider,
          contains('destinationPlaceId: s.destDetails!.placeId'),
        );
        expect(provider, contains('clientRequestId: s.clientRequestId'));
        expect(service, contains('expandTripsForScheduleWindow'));
        expect(service, contains('recurrence_end_date.gte'));
        expect(service, contains('recurrenceSkipDates.contains'));
        expect(migration, contains('public._trip_occurs_on'));
        expect(
          migration,
          contains('create or replace function public.rpc_suggest_trip_pools'),
        );
      },
    );

    test('surfaces degraded scheduling states instead of silent failures', () {
      final bookings = File(
        'lib/features/bookings/bookings_screen.dart',
      ).readAsStringSync();
      final provider = File(
        'lib/features/bookings/providers/schedule_trip_provider.dart',
      ).readAsStringSync();
      final scheduleScreen = File(
        'lib/features/bookings/schedule_trip_screen.dart',
      ).readAsStringSync();
      final placeField = File(
        'lib/shared/widgets/place_autocomplete_field.dart',
      ).readAsStringSync();

      expect(bookings, contains('_authRequired'));
      expect(bookings, contains('Sign in to manage trips'));
      expect(bookings, contains('/login?redirect=/bookings'));
      expect(provider, contains('poolSuggestionMessage'));
      expect(
        provider,
        contains('Trip scheduled, but matching suggestions are unavailable.'),
      );
      expect(scheduleScreen, contains('poolSuggestionMessage'));
      expect(
        placeField,
        contains('Select that location again to confirm the route.'),
      );
      expect(
        placeField,
        isNot(contains('latitude: 0,\n              longitude: 0')),
      );
    });
  });
}
