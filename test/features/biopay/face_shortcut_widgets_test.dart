import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/data/face_capture.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/face_shortcut.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_enroll_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_scan_screen.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/l10n/platform_localization_fallbacks.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/scrolled_tap_target_guideline.dart';
import 'face_shortcut_test.dart' show shortcut;

class CaptureFixture implements FaceCapture {
  bool ready = false;
  int captures = 0, stops = 0;
  @override
  CameraController? get controller => null;
  @override
  bool get isReady => ready;
  @override
  Future<void> start({required bool front}) async {
    ready = true;
  }

  @override
  Future<Uint8List> capture() async {
    captures++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> stop() async {
    stops++;
    ready = false;
  }
}

class FaceFixture extends BioPayFaceService {
  String? account = '11111111-1111-4111-8111-111111111111';
  final pending = Completer<PreparedFaceUssdShortcut>();
  int scans = 0, enrolls = 0, handoffs = 0;
  String? selected;
  bool? consent;
  @override
  String? get ownerId => account;
  @override
  Future<BioPayEnrollmentStatus> enrollmentStatus() async =>
      const BioPayEnrollmentStatus();
  @override
  Future<PreparedFaceUssdShortcut> resolveShortcut({
    required List<int> imageBytes,
    required String idempotencyKey,
  }) {
    scans++;
    return pending.future;
  }

  @override
  Future<void> recordHandoff(String requestId) async {
    handoffs++;
  }

  @override
  Future<String> enrollFace({
    required List<int> imageBytes,
    required String methodId,
    required String idempotencyKey,
    required bool consent,
  }) async {
    enrolls++;
    selected = methodId;
    this.consent = consent;
    return 'active';
  }
}

class GatewayFixture extends PaymentDiscoveryService {
  GatewayFixture({this.family = 'android'}) : super(null);
  final String family;
  int launches = 0;
  String? code;
  @override
  String get deviceFamily => family;
  @override
  Future<bool> openReviewedInstruction(Map<String, dynamic> data) async {
    launches++;
    code = data['instruction'] as String;
    return true;
  }

  @override
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> data,
  ) async => {
    'methods': [
      {
        'id': '44444444-4444-4444-8444-444444444444',
        'owner_id': '11111111-1111-4111-8111-111111111111',
        'provider': 'mtn_rw',
        'kind': 'mobileWallet',
        'identifier': '+250788767816',
        'label': 'Receiving B',
        'can_receive': true,
        'active': true,
      },
    ],
  };
}

Future<void> mount(
  WidgetTester tester,
  FaceFixture service,
  CaptureFixture camera,
  GatewayFixture gateway, {
  bool enroll = false,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
  GoRouter? router,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        biopayFaceServiceProvider.overrideWithValue(service),
        faceCaptureFactoryProvider.overrideWithValue(() => camera),
        paymentDiscoveryServiceProvider.overrideWithValue(gateway),
      ],
      child: router != null
          ? MaterialApp.router(
              theme: AppTheme.darkTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            )
          : MaterialApp(
              theme: AppTheme.darkTheme,
              locale: locale,
              localizationsDelegates: const [
                ...rwPlatformLocalizationDelegates,
                ...AppLocalizations.localizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: enroll
                  ? BioPayFaceEnrollScreen(onBack: () {})
                  : BioPayFaceScanScreen(onBack: () {}),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> scan(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(MobiButton, 'Open camera'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MobiButton, 'Scan recipient'));
  await tester.pump();
}

void main() {
  for (final enroll in [false, true]) {
    for (final locale in ['en', 'fr', 'rw']) {
      testWidgets(
        'face ${enroll ? 'enrollment' : 'scan'}: $locale narrow screen at 200% text',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await mount(
              tester,
              FaceFixture(),
              CaptureFixture(),
              GatewayFixture(),
              enroll: enroll,
              locale: Locale(locale),
              size: const Size(320, 640),
              textScale: 2,
            );
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(ScrolledTapTargetGuideline()),
            );
            await tester.drag(
              find.byType(SingleChildScrollView).first,
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(ScrolledTapTargetGuideline()),
            );
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  testWidgets(
    'one capture opens receiving route once with no amount or review',
    (tester) async {
      final face = FaceFixture(),
          camera = CaptureFixture(),
          gateway = GatewayFixture();
      await mount(tester, face, camera, gateway);
      await scan(tester);
      face.pending.complete(shortcut());
      await tester.pumpAndSettle();
      expect(face.enrolls, 0);
      expect(camera.captures, 1);
      expect(camera.stops, greaterThan(0));
      expect(gateway.launches, 1);
      expect(gateway.code, '*182*1*1*0788767816#');
      expect(face.handoffs, 1);
      expect(find.text('Review'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gateway.launches, 1);
    },
  );
  for (final reason in ['leave', 'background', 'account']) {
    testWidgets('$reason while resolving cannot open dialer', (tester) async {
      final face = FaceFixture(),
          camera = CaptureFixture(),
          gateway = GatewayFixture();
      await mount(tester, face, camera, gateway);
      await scan(tester);
      if (reason == 'leave') await tester.pumpWidget(const SizedBox());
      if (reason == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
      }
      if (reason == 'account') face.account = 'another-user';
      face.pending.complete(shortcut());
      await tester.pumpAndSettle();
      expect(gateway.launches, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }
  testWidgets('no match offers manual and QR, never payer enrollment', (
    tester,
  ) async {
    final face = FaceFixture(),
        camera = CaptureFixture(),
        gateway = GatewayFixture();
    await mount(tester, face, camera, gateway);
    await scan(tester);
    face.pending.completeError(const FaceServiceException('NO_MATCH'));
    await tester.pumpAndSettle();
    expect(find.text('Use a number'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Register my face'), findsNothing);
    expect(gateway.launches, 0);
    expect(camera.ready, isFalse);
  });
  for (final entry in {
    'Use a number': '/biopay/send',
    'Scan QR': '/biopay/scan',
    'Add or edit receiving numbers': '/profile/payment-methods',
  }.entries) {
    testWidgets('${entry.key} stops capture before opening its route', (
      tester,
    ) async {
      final face = FaceFixture(),
          camera = CaptureFixture(),
          gateway = GatewayFixture();
      final enrollment = entry.value.startsWith('/profile');
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => enrollment
                ? BioPayFaceEnrollScreen(onBack: () {})
                : BioPayFaceScanScreen(onBack: () {}),
          ),
          GoRoute(
            path: entry.value,
            builder: (_, _) {
              expect(camera.ready, isFalse);
              expect(camera.stops, greaterThan(0));
              return const Scaffold(body: Text('Alternative destination'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await mount(tester, face, camera, gateway, router: router);
      if (!enrollment) {
        await scan(tester);
        face.pending.completeError(const FaceServiceException('NO_MATCH'));
        await tester.pumpAndSettle();
      }
      // Covers changing journey while an initialized preview is still owned.
      camera.ready = true;
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text('Alternative destination'), findsOneWidget);
      expect(gateway.launches, 0);
      router.pop();
      await tester.pumpAndSettle();
      expect(camera.ready, isFalse);
    });
  }
  for (final family in ['ios', 'web', 'desktop']) {
    testWidgets(
      '$family gives copyable instructions, never false native success',
      (tester) async {
        final face = FaceFixture(),
            camera = CaptureFixture(),
            gateway = GatewayFixture(family: family);
        await mount(tester, face, camera, gateway);
        await scan(tester);
        face.pending.complete(shortcut());
        await tester.pumpAndSettle();
        expect(gateway.launches, 0);
        expect(find.text('Copy USSD code'), findsOneWidget);
        expect(face.handoffs, 0);
      },
    );
  }
  testWidgets(
    'enrollment requires explicit receiving choice and opt-in, then one capture',
    (tester) async {
      final face = FaceFixture(),
          camera = CaptureFixture(),
          gateway = GatewayFixture();
      await mount(tester, face, camera, gateway, enroll: true);
      expect(
        tester
            .widget<MobiButton>(find.widgetWithText(MobiButton, 'Open camera'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Receiving B · •••• 7816').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(MobiButton, 'Open camera'),
      );
      await tester.tap(find.widgetWithText(MobiButton, 'Open camera'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MobiButton, 'Capture once'));
      await tester.pumpAndSettle();
      expect(camera.captures, 1);
      expect(face.enrolls, 1);
      expect(face.selected, '44444444-4444-4444-8444-444444444444');
      expect(face.consent, true);
    },
  );
  for (final locale in ['fr', 'rw']) {
    testWidgets('$locale has translated task and recovery copy', (
      tester,
    ) async {
      final face = FaceFixture(),
          camera = CaptureFixture(),
          gateway = GatewayFixture();
      await mount(tester, face, camera, gateway, locale: Locale(locale));
      expect(find.text('Scan to pay'), findsNothing);
      expect(find.text('Open camera'), findsNothing);
    });
  }
}
