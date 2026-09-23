import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/bookings/data/public_transport_service.dart';
import 'package:mobi_app/features/bookings/domain/transport_agency_catalog.dart';
import 'package:mobi_shared_types/models/trip.dart';

void main() {
  test('preview and managed catalog contain the same 43 agencies', () {
    final sql = File(
      'supabase/migrations/20260920120000_expand_transport_agency_catalog.sql',
    ).readAsStringSync();
    final seededNames = RegExp(
      r"^  \('([^']+)', (?:null|'[^']+')\)[,;]$",
      multiLine: true,
    ).allMatches(sql).map((match) => match.group(1)!);

    expect(rwandaTransportAgencyNames, hasLength(43));
    expect(rwandaTransportAgencyNames.toSet(), hasLength(43));
    expect(seededNames, unorderedEquals(rwandaTransportAgencyNames));
    expect(
      PublicTransportService.fallbackAgencyNames,
      rwandaTransportAgencyNames,
    );
    expect(rwandaTransportAgencyNames, isNot(contains(anyBusAgencyOption)));
    final choices = normalizedBusAgencyNames(rwandaTransportAgencyNames);
    expect(choices, hasLength(44));
    expect(choices.first, anyBusAgencyOption);
  });

  for (final entry in {
    'Volcano Express': 'VOLCANO',
    'Trinity Express': 'TRINITY TRANSPORTERS',
    'Kigali Bus Services': 'KIGALI BUS SERVICES',
  }.entries) {
    test('editing a saved ${entry.key} preference keeps its agency', () {
      final trip = Trip.fromJson({
        'id': 'saved-trip',
        'author_id': 'saved-author',
        'origin': 'Kigali',
        'destination': 'Musanze',
        'vehicle_type': 'bus',
        'note': 'Bus agency: ${entry.key}\nWindow seat',
      });
      final state = ScheduleTripState.fromTrip(
        trip,
        transportAgencyNames: rwandaTransportAgencyNames,
      );
      expect(state.normalizedBusAgencyName, entry.value);
    });
  }
}
