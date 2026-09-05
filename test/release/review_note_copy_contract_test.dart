import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scheduled empty states keep coordination copy out of cards', () {
    final homeScreen = File(
      'lib/features/home/presentation/home_screen.dart',
    ).readAsStringSync();
    final bookingsScreen = File(
      'lib/features/bookings/presentation/bookings_screen.dart',
    ).readAsStringSync();
    final tripDetailsScreen = File(
      'lib/features/bookings/presentation/trip_details_screen.dart',
    ).readAsStringSync();

    expect(homeScreen, contains("title: 'No scheduled trips yet'"));
    expect(bookingsScreen, contains("'No scheduled trips yet'"));
    expect(homeScreen, isNot(contains('Coordinate pick up')));
    expect(bookingsScreen, isNot(contains('Coordinate pick up')));
    expect(
      tripDetailsScreen,
      contains(
        'Coordinate pick up, timing, luggage, fare, and seats, directly via chat',
      ),
    );
  });
}
