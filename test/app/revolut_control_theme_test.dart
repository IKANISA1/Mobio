import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/location/location_providers.dart';
import 'package:mobi_app/core/location/places_service.dart';
import 'package:mobi_app/shared/widgets/place_autocomplete_field.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/place.dart';

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  return lighter > darker
      ? (lighter + 0.05) / (darker + 0.05)
      : (darker + 0.05) / (lighter + 0.05);
}

Color _materialBehind(WidgetTester tester, Finder text) => tester
    .widget<Material>(
      find.ancestor(of: text, matching: find.byType(Material)).first,
    )
    .color!;

Future<void> _pumpControls(
  WidgetTester tester,
  ThemeData theme,
  Widget Function(BuildContext context) builder, {
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          alwaysUse24HourFormat: false,
        ),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: builder)),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    final name = brightness.name;
    ThemeData getTheme() => brightness == Brightness.dark
        ? AppTheme.darkTheme
        : AppTheme.lightTheme;

    testWidgets('$name time picker visibly selects a period and commits it', (
      tester,
    ) async {
      TimeOfDay? result;
      await _pumpControls(tester, getTheme(), (context) {
        return TextButton(
          onPressed: () async {
            result = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 3, minute: 15),
            );
          },
          child: const Text('Choose time'),
        );
      }, textScale: 2);

      await tester.tap(find.text('Choose time'));
      await tester.pumpAndSettle();
      final am = find.text('AM');
      final pm = find.text('PM');
      final initialAmBackground = _materialBehind(tester, am);
      final initialPmBackground = _materialBehind(tester, pm);
      expect(initialAmBackground, isNot(initialPmBackground));
      expect(
        _contrast(tester.widget<Text>(am).style!.color!, initialAmBackground),
        greaterThanOrEqualTo(4.5),
      );

      await tester.tap(pm);
      await tester.pumpAndSettle();
      expect(_materialBehind(tester, pm), initialAmBackground);
      expect(_materialBehind(tester, am), initialPmBackground);
      expect(
        _contrast(
          tester.widget<Text>(pm).style!.color!,
          _materialBehind(tester, pm),
        ),
        greaterThanOrEqualTo(4.5),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, const TimeOfDay(hour: 15, minute: 15));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name date picker keeps unavailable dates inert', (
      tester,
    ) async {
      DateTime? result;
      await _pumpControls(tester, getTheme(), (context) {
        return TextButton(
          onPressed: () async {
            result = await showDatePicker(
              context: context,
              initialDate: DateTime(2026, 9, 15),
              firstDate: DateTime(2026, 9, 1),
              lastDate: DateTime(2026, 9, 30),
              currentDate: DateTime(2026, 9, 10),
              selectableDayPredicate: (date) => date.day >= 15,
            );
          },
          child: const Text('Choose date'),
        );
      }, textScale: 2);

      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 9, 15));

      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 9, 16));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name dialog actions remain reachable at enlarged text', (
      tester,
    ) async {
      var invoked = 0;
      String? result;
      await _pumpControls(tester, getTheme(), (context) {
        return TextButton(
          onPressed: () async {
            result = await showDialog<String>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Cancel scheduled trip?'),
                content: const Text(
                  'Passengers will no longer be able to contact you from this post.',
                ),
                actions: [
                  const FilledButton(
                    onPressed: null,
                    child: Text('Unavailable'),
                  ),
                  TextButton(
                    onPressed: () {
                      invoked++;
                      Navigator.pop(dialogContext, 'cancelled');
                    },
                    child: const Text('Cancel trip'),
                  ),
                ],
              ),
            );
          },
          child: const Text('Review trip'),
        );
      }, textScale: 2);
      await tester.tap(find.text('Review trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unavailable'));
      await tester.pumpAndSettle();
      expect(invoked, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel trip'));
      await tester.pumpAndSettle();
      expect(invoked, 1);
      expect(result, 'cancelled');

      await tester.tap(find.text('Review trip'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isNull);
      expect(invoked, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name place search clears a selected address and recovers', (
      tester,
    ) async {
      final service = _ControlPlaces();
      final selections = <PlaceDetails?>[];
      final semantics = tester.ensureSemantics();
      try {
        await _pumpControls(tester, getTheme(), (context) {
          final cs = Theme.of(context).colorScheme;
          return ProviderScope(
            overrides: [placesServiceProvider.overrideWithValue(service)],
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PlaceAutocompleteField(
                  label: 'Departure',
                  placeholder: 'Search Rwanda places',
                  initialValue: 'Kigali, Rwanda',
                  icon: Icons.search,
                  iconBg: cs.surfaceContainerHigh,
                  iconColor: cs.onSurface,
                  onPlaceSelected: selections.add,
                ),
              ),
            ),
          );
        }, textScale: 2);
        expect(find.bySemanticsLabel(RegExp('Departure')), findsWidgets);
        await tester.tap(find.byTooltip('Clear location'));
        await tester.pumpAndSettle();
        expect(selections, isNotEmpty);
        expect(selections, everyElement(isNull));
        expect(find.byTooltip('Clear location'), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );

        await tester.enterText(find.byType(TextField), 'Unknown');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('No places found'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Kigali');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kigali centre'));
        await tester.pumpAndSettle();
        expect(selections.last?.placeId, 'centre');
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Kigali centre, Rwanda',
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}

class _ControlPlaces implements PlacesService {
  static const centre = PlaceDetails(
    placeId: 'centre',
    formattedAddress: 'Kigali centre, Rwanda',
    latitude: -1.9441,
    longitude: 30.0619,
  );

  @override
  Future<List<PlacePrediction>> getAutocompletePredictions(
    String input, {
    double? nearLat,
    double? nearLng,
    String? sessionToken,
  }) async => input == 'Kigali'
      ? const [
          PlacePrediction(
            placeId: 'centre',
            description: 'Kigali centre, Rwanda',
            primaryText: 'Kigali centre',
          ),
        ]
      : [];

  @override
  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    String? sessionToken,
  }) async => centre;

  @override
  Future<PlaceDetails?> geocodeAddress(String address) async => centre;

  @override
  Future<PlaceDetails?> reverseGeocode(double lat, double lng) async => centre;
}
