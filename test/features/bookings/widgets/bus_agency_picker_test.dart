import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_provider.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/bookings/domain/transport_agency_catalog.dart';
import 'package:mobi_app/features/bookings/presentation/schedule_trip_screen.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/place.dart';
import 'package:mobi_shared_types/models/trip.dart';

void main() {
  Future<void> pumpScheduler(
    WidgetTester tester,
    _ScheduleFixture controller, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboardInset = 0,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [scheduleTripProvider.overrideWith(() => controller)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: child!,
          ),
          home: ScheduleTripScreen(
            mode: 'passenger',
            onModeChanged: (_) {},
            onBack: () {},
            editingTripId: controller.initial.editingTrip?.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPicker(WidgetTester tester, String value) async {
    await tester.ensureVisible(find.text(value));
    await tester.tap(find.text(value));
    await tester.pumpAndSettle();
  }

  Finder sheetText(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  for (final editing in [false, true]) {
    testWidgets(
      'Any saves the agency preference and route/time when editing=$editing',
      (tester) async {
        final fixture = _ScheduleFixture(editing: editing);
        await pumpScheduler(tester, fixture);
        await openPicker(tester, editing ? 'Ritco' : 'Select agency');
        expect(
          tester.getTopLeft(sheetText('Any')).dy,
          lessThan(tester.getTopLeft(sheetText('Ritco')).dy),
        );
        await tester.tap(sheetText('Any'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(fixture.state.requireValue.normalizedBusAgencyName, 'Any');
        expect(fixture.state.requireValue.canSubmit(DateTime.now()), isTrue);

        final submit = find.widgetWithText(
          MobiButton,
          editing ? 'Save changes' : 'Schedule',
        );
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(
          fixture.submittedNote,
          editing ? 'Bus agency: Any\nWindow seat' : 'Bus agency: Any',
        );
        final saved = fixture.submittedState!;
        expect(saved.originDetails, fixture.initial.originDetails);
        expect(saved.destDetails, fixture.initial.destDetails);
        expect(saved.selectedDateTime, fixture.initial.selectedDateTime);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Any stays available during search and can change back to a named agency',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final fixture = _ScheduleFixture();
        await pumpScheduler(tester, fixture);
        await openPicker(tester, 'Select agency');
        final search = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        );
        expect(tester.getSemantics(search).label, 'Search agencies');
        await tester.enterText(search, 'No matching agency');
        await tester.pumpAndSettle();
        expect(tester.getSemantics(search).label, 'Search agencies');
        expect(sheetText('Any'), findsOneWidget);
        expect(sheetText('Ritco'), findsNothing);
        await tester.tap(sheetText('Any'));
        await tester.pumpAndSettle();
        await openPicker(tester, 'Any');
        final choice = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.bySemanticsLabel('Any'),
        );
        expect(choice, findsOneWidget);
        expect(tester.getSemantics(choice).flagsCollection.isButton, isTrue);
        expect(
          tester.getSemantics(choice).flagsCollection.isSelected,
          Tristate.isTrue,
        );
        await tester.tap(sheetText('Ritco'));
        await tester.pumpAndSettle();
        expect(fixture.state.requireValue.normalizedBusAgencyName, 'Ritco');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Any works without a loaded agency catalog', (tester) async {
    final fixture = _ScheduleFixture(agencies: const []);
    await pumpScheduler(tester, fixture);
    await openPicker(tester, 'Select agency');
    await tester.tap(sheetText('Any'));
    await tester.pumpAndSettle();
    expect(fixture.state.requireValue.canSubmit(DateTime.now()), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full catalog supports long names and the last agency', (
    tester,
  ) async {
    final fixture = _ScheduleFixture(agencies: rwandaTransportAgencyNames);
    await pumpScheduler(tester, fixture, size: const Size(320, 640), scale: 2);
    await openPicker(tester, 'Select agency');
    final search = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'gicumbi');
    await tester.pumpAndSettle();
    expect(sheetText('GICUMBI TRANSPORT COOPERATIVE'), findsOneWidget);
    expect(sheetText('Any'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(search, 'yahoo');
    await tester.pumpAndSettle();
    await tester.tap(sheetText('YAHOO CAR EXPRESS'));
    await tester.pumpAndSettle();
    expect(
      fixture.state.requireValue.normalizedBusAgencyName,
      'YAHOO CAR EXPRESS',
    );
    expect(fixture.state.requireValue.canSubmit(DateTime.now()), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'agency choices fit narrow 200 percent text with the keyboard visible',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpScheduler(
          tester,
          _ScheduleFixture(),
          size: const Size(320, 640),
          scale: 2,
          keyboardInset: 200,
        );
        await openPicker(tester, 'Select agency');
        final choice = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.bySemanticsLabel('Any'),
        );
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester.takeException(), isNull);
        await tester.tap(sheetText('Any'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );
}

class _ScheduleFixture extends ScheduleTripController {
  _ScheduleFixture({
    bool editing = false,
    List<String> agencies = const ['Ritco', 'Volcano Express'],
  }) : initial = ScheduleTripState(
         vehicleTypes: VehicleTypeModel.fallbackTypes,
         transportAgencyNames: agencies,
         vehicleId: 'bus',
         busAgencyName: editing ? 'Ritco' : '',
         selectedRole: 'passenger',
         date: DateTime(2030, 6, 12),
         time: const TimeOfDay(hour: 9, minute: 30),
         originDetails: const PlaceDetails(
           placeId: 'pickup',
           formattedAddress: 'Kigali Heights',
           latitude: -1.95,
           longitude: 30.09,
         ),
         destDetails: const PlaceDetails(
           placeId: 'dropoff',
           formattedAddress: 'Kigali Arena',
           latitude: -1.94,
           longitude: 30.1,
         ),
         editingTrip: editing
             ? Trip.fromJson({
                 'id': 'test-trip',
                 'author_id': 'test-author',
                 'origin': 'Kigali Heights',
                 'destination': 'Kigali Arena',
                 'note': 'Bus agency: Ritco\nWindow seat',
               })
             : null,
       );

  final ScheduleTripState initial;
  String? submittedNote;
  ScheduleTripState? submittedState;

  @override
  Future<ScheduleTripState> build() async => initial;

  @override
  Future<Trip?> submitTrip({required String note}) async {
    submittedNote = note;
    submittedState = state.requireValue;
    return null;
  }
}
