import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/ev_chargers/application/ev_charger_providers.dart';
import 'package:mobi_app/features/ev_chargers/data/ev_charger_service.dart';
import 'package:mobi_app/features/ev_chargers/domain/ev_charger.dart';
import 'package:mobi_app/features/ev_chargers/presentation/ev_charger_locator_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final launches = <Map<Object?, Object?>>[];
  var launchSucceeds = true;
  var launchThrows = false;

  setUp(() {
    launches.clear();
    launchSucceeds = true;
    launchThrows = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'launch') return false;
          launches.add(call.arguments as Map<Object?, Object?>);
          if (launchThrows) throw PlatformException(code: 'unavailable');
          return launchSucceeds;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpLocator(
    WidgetTester tester, {
    String? phone = '0788 000 001',
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          evChargerServiceProvider.overrideWithValue(_Chargers(phone)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: EvChargerLocatorScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'charger actions use its coordinates and normalized WhatsApp contact',
    (tester) async {
      await pumpLocator(tester);
      expect(find.text('CCS2 • Type 2'), findsNothing);
      expect(find.text('60 kW'), findsNothing);
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);

      await tester.ensureVisible(find.text('Open in Google Maps'));
      await tester.tap(find.text('Open in Google Maps'));
      await tester.pumpAndSettle();
      final maps = Uri.parse(launches.single['url']! as String);
      expect(maps.host, 'www.google.com');
      expect(maps.queryParameters['destination'], '-1.9536,30.0927');
      expect(launches.single['useWebView'], isFalse);

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      final chat = Uri.parse(launches.last['url']! as String);
      expect(chat.host, 'wa.me');
      expect(chat.path, '/250788000001');
      expect(chat.queryParameters['text'], contains('Test EV Hub'));
      expect(launches.last['useWebView'], isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final phone in [null, '', '6420', 'invalid0788000001']) {
    testWidgets('Chat is disabled without a usable operator number ($phone)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpLocator(tester, phone: phone);
        final chat = find.bySemanticsLabel('Chat with Test EV Hub on WhatsApp');
        await tester.ensureVisible(chat);
        await tester.pumpAndSettle();
        final data = tester.getSemantics(chat).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        expect(data.hint, 'No WhatsApp number available');
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();
        expect(launches, isEmpty);
        expect(find.text('Open in Google Maps'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final throws in [false, true]) {
    testWidgets(
      'WhatsApp launch failure stays on the charger list (throws=$throws)',
      (tester) async {
        await pumpLocator(tester);
        launchSucceeds = false;
        launchThrows = throws;
        await tester.ensureVisible(find.text('Chat'));
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();
        expect(find.text('Unable to open WhatsApp right now.'), findsOneWidget);
        expect(find.text('Test EV Hub'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'charger actions stay named and usable at $size ${scale}x text',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpLocator(tester, size: size, textScale: scale);
          final maps = find.bySemanticsLabel(
            'Open in Google Maps, Test EV Hub',
          );
          final chat = find.bySemanticsLabel(
            'Chat with Test EV Hub on WhatsApp',
          );
          for (final action in [maps, chat]) {
            await tester.ensureVisible(action);
            await tester.pumpAndSettle();
            final node = tester.getSemantics(action);
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            expect(tester.takeException(), isNull);
          }
          final mapsRect = tester.getRect(maps);
          final chatRect = tester.getRect(chat);
          if (scale == 1) {
            expect(mapsRect.top, chatRect.top);
            expect(mapsRect.right, lessThan(chatRect.left));
          } else {
            expect(mapsRect.bottom, lessThan(chatRect.top));
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

class _Chargers extends EvChargerService {
  _Chargers(this.phone);

  final String? phone;

  @override
  Future<List<EvCharger>> findNearestChargers({
    required double latitude,
    required double longitude,
    double radiusKm = 30,
    int limit = 5,
  }) async => [
    EvCharger(
      id: 'test-ev-hub',
      name: 'Test EV Hub',
      address: 'Test location',
      latitude: -1.9536,
      longitude: 30.0927,
      connectorTypes: const ['CCS2', 'Type 2'],
      isActive: true,
      phone: phone,
      powerKw: 60,
      distanceKm: 1.2,
    ),
  ];
}
