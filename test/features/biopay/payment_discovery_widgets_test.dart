import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/payment_composer_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_library_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_link_arrival_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_methods_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_nfc_link_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_provider_routes_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/l10n/platform_localization_fallbacks.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

/// Explicit review exports retain normal product fonts and DPR. They neither
/// read nor accept a baseline; default test runs keep the real comparator.
class _OrdinaryDiscoveryReviewExporter extends GoldenFileComparator {
  _OrdinaryDiscoveryReviewExporter(this.directory);

  final Directory directory;

  @override
  Future<bool> compare(Uint8List bytes, Uri golden) async {
    await directory.create(recursive: true);
    await File(
      '${directory.path}/${golden.pathSegments.last}',
    ).writeAsBytes(bytes, flush: true);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      throw UnsupportedError('Review exports do not update baselines.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final reviewDirectory =
      Platform.environment['MOBIO_DISCOVERY_GOLDEN_REVIEW_DIR'];
  final previousComparator = goldenFileComparator;
  if (reviewDirectory?.isNotEmpty ?? false) {
    goldenFileComparator = _OrdinaryDiscoveryReviewExporter(
      Directory(reviewDirectory!),
    );
  }
  tearDownAll(() => goldenFileComparator = previousComparator);
  const writer = MethodChannel('rw.mobi.app/biopay_nfc_writer');
  const kit = MethodChannel('flutter_nfc_kit/method');
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(writer, (_) async => null);
    messenger.setMockMethodCallHandler(kit, (_) async => null);
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(writer, null);
    messenger.setMockMethodCallHandler(kit, null);
  });
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final lucide = FontLoader('packages/lucide_icons/Lucide')
      ..addFont(rootBundle.load('packages/lucide_icons/assets/lucide.ttf'));
    await lucide.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    // The widget-test engine disables automatic font-asset loading.
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final fonts =
        manifest.singleWhere((entry) => entry['family'] == 'Inter')['fonts']
            as List<dynamic>;
    final inter = FontLoader('Inter');
    for (final font in fonts) {
      inter.addFont(rootBundle.load(font['asset'] as String));
    }
    await inter.load();
  });
  Future<void> open(
    WidgetTester tester,
    Widget screen,
    PaymentDiscoveryFixture service, {
    String language = 'en',
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/task',
      routes: [
        GoRoute(path: '/task', builder: (_, _) => screen),
        GoRoute(
          path: '/biopay',
          builder: (_, _) => const Scaffold(body: Text('BioPay home')),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentDiscoveryServiceProvider.overrideWithValue(service)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.darkTheme,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...rwPlatformLocalizationDelegates,
            ...AppLocalizations.localizationsDelegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final cases = <String, Widget>{
    'recipient': const PaymentComposerScreen(),
    'methods': const PaymentMethodsScreen(),
    'method_editor': const PaymentMethodEditor(),
    'requests': const PaymentLibraryScreen(),
    'activity': const PaymentLibraryScreen(section: 'activity'),
    'recents': const PaymentLibraryScreen(section: 'recents'),
    'templates': const PaymentLibraryScreen(section: 'templates'),
    'nfc_links': const PaymentNfcLinkScreen(),
    'request_editor': PaymentRequestEditor(now: () => DateTime.utc(2026, 9, 8)),
    'public_link': const PaymentLinkArrivalScreen(
      token: '0123456789abcdef0123456789abcdef0123456789abcdef',
    ),
  };
  for (final language in ['en', 'fr', 'rw']) {
    for (final e in cases.entries) {
      testWidgets('${e.key} supports $language at 320px and 200 percent text', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await open(
            tester,
            e.value,
            PaymentDiscoveryFixture(),
            language: language,
            size: const Size(320, 740),
            scale: 2,
          );
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          final task = tester.widget<PaymentTaskScaffold>(
            find.byType(PaymentTaskScaffold).first,
          );
          expect(task.title, isNotEmpty);
          if (find.byType(Scrollable).evaluate().isNotEmpty) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -1500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          semantics.dispose();
        }
      });
    }
  }
  testWidgets(
    'recipient choice, quote, review and explicit handoff remain separate',
    (tester) async {
      final service = PaymentDiscoveryFixture();
      final l = lookupAppLocalizations(const Locale('en'));
      await open(
        tester,
        const PaymentComposerScreen(entry: '+250788000002'),
        service,
      );
      await tester.enterText(find.byType(TextField).first, '1000');
      await tester.tap(find.widgetWithText(PaymentAction, l.bpCompare));
      await tester.pumpAndSettle();
      expect(service.opens, 0);
      await tester.scrollUntilVisible(
        find.text(l.bpReview).hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l.bpReview));
      await tester.pumpAndSettle();
      expect(
        find.text('0012345678', findRichText: true),
        findsNothing,
      ); // full endpoint includes provider label
      expect(find.textContaining('0012345678'), findsOneWidget);
      expect(service.opens, 0);
      await expectLater(
        find.byType(PaymentTaskScaffold),
        matchesGoldenFile('goldens/discovery_review_390x844.png'),
      );
      await tester.scrollUntilVisible(
        find.text(l.bpChange).hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l.bpChange).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(l.bpReview), findsOneWidget);
      expect(service.calls.where((x) => x == 'prepare'), isEmpty);
      await tester.scrollUntilVisible(
        find.text(l.bpReview).hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l.bpReview).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaymentAction, l.bpOpenMomo));
      await tester.pumpAndSettle();
      expect(service.opens, 1);
      expect(service.calls.where((x) => x == 'prepare').length, 1);
      expect(find.text('Payment confirmed'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.opens, 1);
    },
  );
  testWidgets(
    'review Change and handoff remain reachable at 320px and 200 percent text',
    (tester) async {
      final service = PaymentDiscoveryFixture();
      final l = lookupAppLocalizations(const Locale('en'));
      Future<void> reveal(Finder target) async {
        // Scroll from the content gutter rather than selecting text by dragging
        // from the centre of an enlarged amount field.
        for (
          var attempt = 0;
          attempt < 40 && target.hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          final viewport = tester.getRect(find.byType(Scrollable).first);
          await tester.dragFrom(
            Offset(viewport.left + 8, viewport.center.dy),
            const Offset(0, -150),
          );
          await tester.pumpAndSettle();
        }
        expect(target.hitTestable(), findsOneWidget);
      }

      await open(
        tester,
        const PaymentComposerScreen(entry: '+250788000002'),
        service,
        size: const Size(320, 740),
        scale: 2,
      );
      await tester.enterText(find.byType(TextField).first, '1000');
      await reveal(find.widgetWithText(PaymentAction, l.bpCompare));
      await tester.tap(
        find.widgetWithText(PaymentAction, l.bpCompare).hitTestable(),
      );
      await tester.pumpAndSettle();
      await reveal(find.text(l.bpReview));
      await tester.tap(find.text(l.bpReview).hitTestable());
      await tester.pumpAndSettle();
      await reveal(find.text(l.bpChange));
      await tester.tap(find.text(l.bpChange).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(l.bpReview), findsOneWidget);
      expect(service.calls.where((x) => x == 'prepare'), isEmpty);
      await reveal(find.text(l.bpReview));
      await tester.tap(find.text(l.bpReview).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PaymentAction, l.bpOpenMomo).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.opens, 1);
      expect(service.calls.where((x) => x == 'prepare').length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.opens, 1);
    },
  );
  testWidgets(
    'contact cancel keeps the draft and a selected nickname stays private',
    (tester) async {
      final service = PaymentDiscoveryFixture();
      await open(tester, const PaymentComposerScreen(), service);
      await tester.enterText(find.byType(TextField).first, '0788000002');
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l.bpContacts));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '0788000002',
      );
      service.contact = {'phone': '0788000003', 'name': 'Unverified nickname'};
      await tester.tap(find.text(l.bpContacts));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '+250788000003',
      );
      expect(find.text('Unverified nickname'), findsNothing);
      expect(service.calls.where((x) => x == 'resolve'), isEmpty);
    },
  );
  testWidgets('offline draft save keeps entries and does not leave the task', (
    tester,
  ) async {
    final service = PaymentDiscoveryFixture()..failAction = 'save_draft';
    await open(tester, const PaymentComposerScreen(), service);
    await tester.enterText(find.byType(TextField).first, '0788000002');
    final l = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.byTooltip(l.bpBack));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l.bpSave));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentComposerScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '0788000002',
    );
    expect(find.text(l.bpSaved), findsNothing);
  });
  testWidgets('keyboard leaves the main action reachable', (tester) async {
    await open(
      tester,
      const PaymentComposerScreen(),
      PaymentDiscoveryFixture(),
    );
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('en'));
    expect(
      tester.getRect(find.widgetWithText(PaymentAction, l.bpContinue)).bottom,
      lessThanOrEqualTo(544),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'desktop public arrival offers safe phone continuation without an attempt',
    (tester) async {
      final service = PaymentDiscoveryFixture()..deviceFamily = 'web';
      await open(
        tester,
        const PaymentLinkArrivalScreen(
          token: '0123456789abcdef0123456789abcdef0123456789abcdef',
        ),
        service,
        size: const Size(1280, 900),
      );
      expect(service.calls, isEmpty);
      await expectLater(
        find.byType(PaymentTaskScaffold),
        matchesGoldenFile('goldens/discovery_public_link_1280x900.png'),
      );
    },
  );
  testWidgets('admin evidence workspace adapts at desktop width', (
    tester,
  ) async {
    await open(
      tester,
      const PaymentProviderRoutesScreen(),
      PaymentDiscoveryFixture(),
      size: const Size(1280, 900),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PaymentProviderRoutesScreen),
      matchesGoldenFile('goldens/discovery_admin_routes_1280x900.png'),
    );
  });
  for (final name in ['recipient', 'methods', 'requests', 'request_editor']) {
    testWidgets('$name design capture', (tester) async {
      await open(tester, cases[name]!, PaymentDiscoveryFixture());
      await expectLater(
        find.byType(PaymentTaskScaffold),
        matchesGoldenFile('goldens/discovery_${name}_390x844.png'),
      );
    });
  }
}
