import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

import '../../helpers/design_capture_fonts.dart';
import '../../helpers/payment_discovery_fixture.dart';
import '../../helpers/ui_source_manifest.dart';

// Current production widget evidence. This harness never reads, accepts or
// updates historical goldens, and does not certify visual fidelity.
const _token = '0123456789abcdef0123456789abcdef0123456789abcdef';
const _captureBoundary = ValueKey('current-payment-full-viewport');

class _PaymentCaptureComparator extends GoldenFileComparator {
  _PaymentCaptureComparator(this.directory);
  final Directory directory;
  final List<Map<String, dynamic>> captures = [];
  Map<String, dynamic>? pending;

  @override
  Future<bool> compare(Uint8List bytes, Uri golden) async {
    final metadata = pending;
    if (metadata == null || !golden.path.endsWith('.png')) {
      throw StateError('A capture needs explicit route/state metadata.');
    }
    final file = File('${directory.path}/${golden.pathSegments.last}');
    await file.writeAsBytes(bytes, flush: true);
    final header = ByteData.sublistView(bytes);
    captures.add({
      ...metadata,
      'path': file.absolute.path,
      'sha256': sha256.convert(bytes).toString(),
      'png_width': header.getUint32(16),
      'png_height': header.getUint32(20),
      'visual_comparison_performed': false,
      'visual_acceptance': 'unverified',
    });
    pending = null;
    return true; // File export only; this is not a baseline comparison.
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      throw UnsupportedError('Historical golden updates are prohibited.');
}

class _CurrentPaymentFixture extends PaymentDiscoveryFixture {
  bool empty = false;
  bool linkAvailable = true;
  bool previewFails = false;
  final adminCalls = <String>[];

  @override
  Map<String, dynamic> get workspace => empty
      ? {
          'methods': [],
          'drafts': [],
          'links': [],
          'recents': [],
          'templates': [],
          'activity': [],
        }
      : super.workspace;

  @override
  Future<Map<String, dynamic>> previewLink(String token) async {
    if (previewFails) throw StateError('Synthetic preview failure');
    return {'available': linkAvailable, ...link};
  }

  @override
  Future<Map<String, dynamic>> adminCall(
    String action,
    Map<String, dynamic> data,
  ) async {
    adminCalls.add(action);
    return {
      'routes': [
        {
          'id': 'fixture-tested-route',
          'source_provider': 'mtn_rw',
          'destination_provider': 'bpr_rw',
          'rail': 'eKash',
          'state': 'tested',
          'adapter_version': 1,
          'fee_certainty': 'capped',
          'fee_rwf': 20,
          'fee_all_in': true,
          'min_rwf': 100,
          'max_rwf': 500000,
          'device_families': ['android'],
          'instruction_template': '*182# (synthetic fixture)',
          'evidence_url': 'https://example.invalid/provider-evidence',
          'test_evidence_url': 'https://example.invalid/device-trial',
          'tariff_evidence_url': 'https://example.invalid/tariff',
        },
        {
          'id': 'fixture-draft-route',
          'source_provider': 'airtel_rw',
          'destination_provider': 'mtn_rw',
          'rail': 'provider',
          'state': 'draft',
          'adapter_version': 1,
          'fee_certainty': 'unknown',
          'fee_all_in': false,
          'min_rwf': 100,
          'max_rwf': 100000,
          'device_families': ['android', 'ios'],
        },
      ],
      'evidence': [
        {
          'name': 'MTN MoMo',
          'published_root': '*182#',
          'source_url': 'https://example.invalid/evidence',
        },
      ],
    };
  }
}

class _CaptureCase {
  const _CaptureCase({
    required this.name,
    required this.widgetClass,
    required this.route,
    required this.builder,
    required this.state,
    required this.assertVisible,
    this.prepare,
  });
  final String name, widgetClass, route, state;
  final Widget Function(_CurrentPaymentFixture) builder;
  final String assertVisible;
  final void Function(_CurrentPaymentFixture)? prepare;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Directory(
    Platform.environment['MOBIO_CURRENT_PAYMENT_CAPTURE_DIR'] ??
        'build/qa/design-review/current-payment-20260930',
  );
  final exporter = _PaymentCaptureComparator(directory);
  final previousComparator = goldenFileComparator;
  goldenFileComparator = exporter;
  late Map<String, dynamic> sourceBefore;
  late UiSourceManifest sourceBinding;
  final l = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await directory.create(recursive: true);
    sourceBinding = UiSourceManifest.fromEnvironment();
    sourceBefore = sourceBinding.fingerprint();
    await loadDesignCaptureFonts();
    enableDesignCaptureTypographyFallbacks();
  });

  tearDownAll(() async {
    goldenFileComparator = previousComparator;
    try {
      restoreDesignCaptureTypographyFallbacks();
      final sourceAfter = sourceBinding.fingerprint(
        requireManifestHashes: false,
      );
      final sameSources =
          sourceBefore['source_sha256'] == sourceAfter['source_sha256'];
      final manifest = {
        'schema_version': 1,
        'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source_sha256': sourceBefore['source_sha256'],
        'source_before': sourceBefore,
        'source_after': sourceAfter,
        'source_unchanged_during_capture': sameSources,
        'harness':
            'test/features/preview/current_payment_route_capture_test.dart',
        'harness_sha256': sha256
            .convert(
              await File(
                'test/features/preview/current_payment_route_capture_test.dart',
              ).readAsBytes(),
            )
            .toString(),
        'capture_method': 'Flutter widget test; PNG export only comparator',
        'golden_baselines_read_or_updated': false,
        'visual_comparison_performed': false,
        'visual_acceptance': 'unverified',
        'fixture': 'PaymentDiscoveryFixture, synthetic local-only data',
        'capture_font_provenance': designCaptureFontProvenance,
        'capture_typography_fallback_provenance':
            designCaptureTypographyFallbackProvenance,
        'logo_decode_provenance': designCaptureLogoDecodeProvenance,
        'logo_paint_provenance': designCaptureLogoPaintProvenance,
        'font_sources': [
          'assets/google_fonts/Inter-Regular.ttf',
          'assets/google_fonts/Inter-500.ttf',
          'assets/google_fonts/Inter-600.ttf',
          'assets/google_fonts/Inter-700.ttf',
          'packages/lucide_icons/assets/lucide.ttf',
          'fonts/MaterialIcons-Regular.otf',
        ],
        'limitations': [
          'The current production widget classes are mounted directly in a test GoRouter.',
          'Production router redirects, auth/admin guards, DeferredRouteLoader, app shell and bootstrap are bypassed.',
          'The payment gateway and its account snapshot are synthetic. No Supabase configuration, provider network, WhatsApp authentication or server authorization is exercised.',
          'Admin AccountActionToken runs with no configured real session. Its same-null test behavior is not authenticated admin verification.',
          'Flutter widget-test rendering uses device pixel ratio 1, zero system safe-area padding and English at text scale 1.',
          ...designCaptureFontLimitations,
          'Desktop captures set gateway.deviceFamily to web while the test engine itself is not a browser.',
          'NFC method channels are test stubs. Card hardware, scanning, writing, lock and installed lifecycle are unverified.',
          'Synthetic external handoff increments a fixture counter and never opens a real dialer or provider.',
          'Viewport images show the settled visible region. Offscreen content and uncaptured states are unverified.',
          'No Revolut source image or visual comparator is used by this export harness.',
          'The existing Mobio logo ImageProvider is decoded before mounting; its mounted RenderImage and actual painted region are checked. This is local capture identity evidence, not installed rendering verification.',
        ],
        'capture_count': exporter.captures.length,
        'captures': exporter.captures,
      };
      await File('${directory.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      expect(sameSources, isTrue, reason: 'UI source changed during capture.');
    } finally {
      restoreDesignCaptureTypographyFallbacks();
    }
  });

  const writer = MethodChannel('rw.mobi.app/biopay_nfc_writer');
  const kit = MethodChannel('flutter_nfc_kit/method');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(writer, (_) async => null)
      ..setMockMethodCallHandler(kit, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(writer, null)
      ..setMockMethodCallHandler(kit, null);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget screen,
    _CurrentPaymentFixture service,
    Size size,
    Brightness brightness,
  ) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await preloadDesignCaptureLogo(tester);
    final router = GoRouter(
      initialLocation: '/task',
      routes: [
        GoRoute(path: '/task', builder: (_, _) => screen),
        for (final path in ['/biopay', '/profile', '/profile/payment-methods'])
          GoRoute(
            path: path,
            builder: (_, _) =>
                const Scaffold(body: Text('Harness destination')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureBoundary,
        child: ProviderScope(
          overrides: [
            paymentDiscoveryServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: designCaptureTheme(
              brightness == Brightness.dark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme,
            ),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              ...rwPlatformLocalizationDelegates,
              ...AppLocalizations.localizationsDelegates,
            ],
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Fonts are loaded from the same bundled Inter assets used by production.
    await settleDesignCaptureFonts(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(Scaffold).first)),
      size,
    );
  }

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    required String widgetClass,
    required String route,
    required String state,
    required Size size,
    required Brightness brightness,
    required _CurrentPaymentFixture service,
    required List<String> checks,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settleDesignCaptureFonts(tester);
    final logoPaints = await verifyDesignCaptureLogoPaints(
      tester,
      capture:
          '${name}_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}',
      requireVisibleLogo:
          name == 'provider_routes_populated' && size.width >= 1000,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(_captureBoundary)), size);
    final mediaContext = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.sizeOf(mediaContext), size);
    expect(MediaQuery.devicePixelRatioOf(mediaContext), 1);
    exporter.pending = {
      'name': name,
      'widget_class': widgetClass,
      'mapped_current_route': route,
      'fixture_state': state,
      'theme': brightness.name,
      'viewport': {'width': size.width.toInt(), 'height': size.height.toInt()},
      'effective_media_query_size': {
        'width': MediaQuery.sizeOf(mediaContext).width.toInt(),
        'height': MediaQuery.sizeOf(mediaContext).height.toInt(),
      },
      'device_pixel_ratio': MediaQuery.devicePixelRatioOf(mediaContext),
      'device_family_fixture': service.deviceFamily,
      'text_scale': 1,
      'locale': 'en',
      'visible_state_checks': checks,
      'gateway_calls': List<String>.from(service.calls),
      'admin_gateway_calls': List<String>.from(service.adminCalls),
      'synthetic_handoff_count': service.opens,
      'logo_paint_checks': logoPaints,
      'source_sha256': sourceBefore['source_sha256'],
    };
    await expectLater(
      find.byKey(_captureBoundary),
      matchesGoldenFile(
        '${name}_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
      ),
    );
  }

  final cases = [
    _CaptureCase(
      name: 'composer_recipient',
      widgetClass: 'PaymentComposerScreen',
      route: '/biopay/send',
      builder: (_) => const PaymentComposerScreen(),
      state: 'recipient entry, synthetic saved recent',
      assertVisible: l.bpPhone,
    ),
    _CaptureCase(
      name: 'methods_populated',
      widgetClass: 'PaymentMethodsScreen',
      route: '/profile/payment-methods',
      builder: (_) => const PaymentMethodsScreen(),
      state: 'one own MoMo method with sending/receiving/preferred roles',
      assertVisible: 'My MoMo',
    ),
    _CaptureCase(
      name: 'method_editor_new',
      widgetClass: 'PaymentMethodEditor',
      route: '/profile/payment-methods > Navigator editor',
      builder: (_) => const PaymentMethodEditor(),
      state: 'new receiving method, default MTN, empty form',
      assertVisible: l.bpAddMethod,
    ),
    _CaptureCase(
      name: 'request_editor_template',
      widgetClass: 'PaymentRequestEditor',
      route: '/biopay/request-payment (also /biopay/qr)',
      builder: (s) => PaymentRequestEditor(
        template: s.link,
        now: () => DateTime.utc(2026, 9, 30),
      ),
      state: 'request form from synthetic Lunch request template',
      assertVisible: l.bpCreateRequest,
    ),
    for (final section in ['requests', 'activity', 'recents', 'templates'])
      _CaptureCase(
        name: 'library_$section',
        widgetClass: 'PaymentLibraryScreen',
        route: '/biopay/$section',
        builder: (_) => PaymentLibraryScreen(section: section),
        state: 'populated $section section, one synthetic row',
        assertVisible: switch (section) {
          'requests' => 'Lunch request',
          'activity' => 'Shared receiving details',
          'recents' => 'My contact label',
          _ => 'Lunch',
        },
      ),
    _CaptureCase(
      name: 'nfc_link_ready',
      widgetClass: 'PaymentNfcLinkScreen',
      route: '/biopay/nfc/write-card',
      builder: (_) => const PaymentNfcLinkScreen(),
      state: 'available synthetic request, not selected or written',
      assertVisible: 'Lunch request',
    ),
    _CaptureCase(
      name: 'public_link_available',
      widgetClass: 'PaymentLinkArrivalScreen',
      route: '/biopay/pay/:token',
      builder: (_) => const PaymentLinkArrivalScreen(token: _token),
      state: 'available synthetic Lunch request; desktop includes phone QR',
      assertVisible: 'Lunch request',
    ),
    _CaptureCase(
      name: 'provider_routes_populated',
      widgetClass: 'PaymentProviderRoutesScreen',
      route: '/admin/biopay/routes',
      builder: (_) => const PaymentProviderRoutesScreen(),
      state: 'synthetic tested MTN-to-BPR and draft Airtel-to-MTN adapters',
      assertVisible: 'MTN MoMo → BPR Bank',
    ),
    _CaptureCase(
      name: 'methods_error',
      widgetClass: 'PaymentMethodsScreen',
      route: '/profile/payment-methods',
      builder: (_) => const PaymentMethodsScreen(),
      state: 'synthetic workspace failure, settled error and refresh',
      prepare: (s) => s.failAction = 'workspace',
      assertVisible: l.bpRefreshRequired,
    ),
    _CaptureCase(
      name: 'library_requests_empty',
      widgetClass: 'PaymentLibraryScreen',
      route: '/biopay/requests',
      builder: (_) => const PaymentLibraryScreen(),
      state: 'empty synthetic workspace, settled empty state',
      prepare: (s) => s.empty = true,
      assertVisible: l.bpEmpty,
    ),
    _CaptureCase(
      name: 'public_link_unavailable',
      widgetClass: 'PaymentLinkArrivalScreen',
      route: '/biopay/pay/:token',
      builder: (_) => const PaymentLinkArrivalScreen(token: _token),
      state: 'unavailable synthetic public request, manual fallback',
      prepare: (s) => s.linkAvailable = false,
      assertVisible: l.bpLinkUnavailable,
    ),
  ];

  for (final brightness in [Brightness.dark, Brightness.light]) {
    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      final suffix =
          '${brightness.name} ${size.width.toInt()}x${size.height.toInt()}';
      _CurrentPaymentFixture fixture() =>
          _CurrentPaymentFixture()
            ..deviceFamily = size.width >= 1000 ? 'web' : 'android';

      for (final c in cases) {
        testWidgets('${c.name} exports current production widget $suffix', (
          tester,
        ) async {
          final service = fixture();
          c.prepare?.call(service);
          await mount(tester, c.builder(service), service, size, brightness);
          final visibleText = find.text(c.assertVisible);
          expect(visibleText, findsWidgets);
          final viewport = Offset.zero & size;
          expect(
            List.generate(
              visibleText.evaluate().length,
              (i) => tester.getRect(visibleText.at(i)),
            ).any((rect) => rect.overlaps(viewport)),
            isTrue,
            reason: 'Expected state text must intersect the captured viewport.',
          );
          if (c.name == 'provider_routes_populated') {
            expect(service.adminCalls, ['list']);
          }
          await capture(
            tester,
            name: c.name,
            widgetClass: c.widgetClass,
            route: c.route,
            state: c.state,
            size: size,
            brightness: brightness,
            service: service,
            checks: [
              'Settled without framework exception',
              'Visible: ${c.assertVisible}',
            ],
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }

      testWidgets('composer options, review and outcome exports $suffix', (
        tester,
      ) async {
        final service = fixture();
        await mount(
          tester,
          const PaymentComposerScreen(entry: '+250788000002'),
          service,
          size,
          brightness,
        );
        expect(find.byType(TextField), findsWidgets);
        await tester.enterText(find.byType(TextField).first, '1000');
        await tester.tap(find.widgetWithText(PaymentAction, l.bpCompare));
        await tester.pumpAndSettle();
        expect(service.calls, contains('quote'));
        expect(service.opens, 0);
        await capture(
          tester,
          name: 'composer_options',
          widgetClass: 'PaymentComposerScreen',
          route: '/biopay/send?entry=+250788000002',
          state: 'compared synthetic quote, capped all-in fee, no handoff',
          size: size,
          brightness: brightness,
          service: service,
          checks: ['Synthetic quote called', 'No external handoff'],
        );
        await tester.scrollUntilVisible(
          find.text(l.bpReview).hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(l.bpReview));
        await tester.pumpAndSettle();
        expect(find.textContaining('0012345678'), findsOneWidget);
        expect(service.opens, 0);
        await capture(
          tester,
          name: 'composer_review',
          widgetClass: 'PaymentComposerScreen',
          route: '/biopay/send',
          state: 'review of source/destination and 1000 RWF synthetic quote',
          size: size,
          brightness: brightness,
          service: service,
          checks: ['Destination identifier visible', 'No external handoff'],
        );
        final action = service.deviceFamily == 'android'
            ? l.bpOpenMomo
            : l.bpOpenProvider;
        await tester.tap(find.widgetWithText(PaymentAction, action));
        await tester.pumpAndSettle();
        expect(service.opens, 1);
        expect(find.text('Payment confirmed'), findsNothing);
        await capture(
          tester,
          name: 'composer_outcome',
          widgetClass: 'PaymentComposerScreen',
          route: '/biopay/send',
          state: 'synthetic handoff opened, outcome remains unconfirmed',
          size: size,
          brightness: brightness,
          service: service,
          checks: [
            'Exactly one synthetic handoff',
            'No fabricated payment confirmation',
          ],
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });

      testWidgets('methods actual editor and sharing sheet exports $suffix', (
        tester,
      ) async {
        final service = fixture();
        await mount(
          tester,
          const PaymentMethodsScreen(),
          service,
          size,
          brightness,
        );
        await tester.tap(find.text('My MoMo'));
        await tester.pumpAndSettle();
        expect(find.byType(PaymentMethodEditor), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'My MoMo',
        );
        await capture(
          tester,
          name: 'method_editor_existing',
          widgetClass: 'PaymentMethodEditor',
          route: '/profile/payment-methods > Navigator editor',
          state:
              'existing source method editor opened from actual list callback',
          size: size,
          brightness: brightness,
          service: service,
          checks: [
            'Production list callback opened editor',
            'Original method label preserved',
          ],
        );
        await tester.tap(find.byTooltip(l.bpBack));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.bpViewAsPayer));
        await tester.pumpAndSettle();
        expect(find.text(l.bpSharing), findsOneWidget);
        expect(service.calls, contains('sharing'));
        await capture(
          tester,
          name: 'method_sharing_sheet',
          widgetClass: 'PaymentMethodsScreen modal bottom sheet',
          route: '/profile/payment-methods > sharing sheet',
          state:
              'actual view-as-payer sheet, synthetic private endpoint, no grants',
          size: size,
          brightness: brightness,
          service: service,
          checks: [
            'Sharing service called',
            'Sharing heading visible',
            'Full viewport includes sheet and scrim',
          ],
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });

      testWidgets('request expiry dialog exports $suffix', (tester) async {
        final service = fixture();
        await mount(
          tester,
          PaymentRequestEditor(
            template: service.link,
            now: () => DateTime.utc(2026, 9, 30),
          ),
          service,
          size,
          brightness,
        );
        await tester.scrollUntilVisible(
          find.text(l.bpExpiry).hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(l.bpExpiry));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await capture(
          tester,
          name: 'request_expiry_dialog',
          widgetClass: 'PaymentRequestEditor + DatePickerDialog',
          route: '/biopay/request-payment > expiry dialog',
          state: 'actual expiry picker opened from production request form',
          size: size,
          brightness: brightness,
          service: service,
          checks: [
            'DatePickerDialog visible',
            'Full viewport includes dialog and scrim',
          ],
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });

      testWidgets('NFC selected request exports $suffix', (tester) async {
        final service = fixture();
        await mount(
          tester,
          const PaymentNfcLinkScreen(),
          service,
          size,
          brightness,
        );
        await tester.tap(find.text('Lunch request'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(
          tester
              .widget<PaymentAction>(
                find.widgetWithText(PaymentAction, l.bpNfcWrite),
              )
              .onPressed,
          isNotNull,
        );
        await capture(
          tester,
          name: 'nfc_link_selected',
          widgetClass: 'PaymentNfcLinkScreen',
          route: '/biopay/nfc/write-card',
          state:
              'actual request selection, write action enabled, hardware untouched',
          size: size,
          brightness: brightness,
          service: service,
          checks: [
            'Selected check icon visible',
            'Write action enabled',
            'No NFC hardware operation',
          ],
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
