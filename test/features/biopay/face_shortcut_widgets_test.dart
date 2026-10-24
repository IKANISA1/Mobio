import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/account_context.dart';
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
  int starts = 0, captures = 0, stops = 0;
  Completer<Uint8List>? pendingCapture;
  @override
  CameraController? get controller => null;
  @override
  bool get isReady => ready;
  @override
  Future<void> start({required bool front}) async {
    starts++;
    ready = true;
  }

  @override
  Future<Uint8List> capture() async {
    captures++;
    return pendingCapture?.future ?? Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> stop() async {
    stops++;
    ready = false;
  }
}

class FaceFixture extends BioPayFaceService {
  int generation = 0;
  @override
  AccountSnapshot captureAccount() =>
      AccountSnapshot(account!, 'fixture', generation);
  @override
  bool isCurrent(AccountSnapshot snapshot) =>
      snapshot.userId == account && snapshot.generation == generation;

  String? account = '11111111-1111-4111-8111-111111111111';
  bool statusUnavailable = false;
  BioPayEnrollmentStatus status = const BioPayEnrollmentStatus(
    status: 'not_started',
  );
  final actions = <String>[];
  Object? actionError;
  final methodUpdates = <String>[];
  final pending = Completer<PreparedFaceUssdShortcut>();
  int scans = 0, enrolls = 0, handoffs = 0;
  int preparations = 0;
  Object? prepareError;
  Completer<PreparedFaceUssdShortcut>? pendingPreparation;
  Completer<String>? pendingEnrollment;
  Completer<BioPayEnrollmentStatus>? pendingStatus;
  String? selected;
  bool? consent;
  @override
  String? get ownerId => account;
  @override
  Future<BioPayEnrollmentStatus> enrollmentStatus() async {
    if (statusUnavailable) throw const FaceServiceException('TIMEOUT');
    return pendingStatus?.future ?? status;
  }

  @override
  Future<void> setEnrollmentAction(String action) async {
    actions.add(action);
    if (actionError != null) throw actionError!;
  }

  @override
  Future<void> changeMethod(String id) async => methodUpdates.add(id);

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
  Future<PreparedFaceUssdShortcut> prepareHandoff(String requestId) async {
    preparations++;
    if (prepareError != null) throw prepareError!;
    return pendingPreparation?.future ?? await pending.future;
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
    return pendingEnrollment?.future ?? 'active';
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
        'can_send': false,
        'phone_discoverable': false,
        'preferred': false,
        'active': true,
        'version': 1,
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
  bool settle = true,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> scan(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(MobiButton, 'Open camera'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MobiButton, 'Scan recipient'));
  await tester.pump();
}

Future<void> _tapVisibleControl(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target.hitTestable());
}

void main() {
  testWidgets(
    'retained scan button cannot start capture in a replaced session',
    (tester) async {
      final face = FaceFixture(), camera = CaptureFixture();
      await mount(tester, face, camera, GatewayFixture());
      final oldCallback = tester
          .widget<MobiButton>(find.widgetWithText(MobiButton, 'Open camera'))
          .onPressed!;
      face.generation++;
      AccountContext.changes.value++;
      await tester.pumpAndSettle();
      oldCallback();
      await tester.pumpAndSettle();
      expect(camera.starts, 0);
      expect(face.scans, 0);
    },
  );
  testWidgets('retained enrollment controls cannot populate a new session', (
    tester,
  ) async {
    final face = FaceFixture(), camera = CaptureFixture();
    await mount(tester, face, camera, GatewayFixture(), enroll: true);
    final consentCallback = tester
        .widget<CheckboxListTile>(find.byType(CheckboxListTile))
        .onChanged!;
    final methodCallback = tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!;
    face.generation++;
    AccountContext.changes.value++;
    await tester.pumpAndSettle();
    consentCallback(true);
    methodCallback('44444444-4444-4444-8444-444444444444');
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      isNull,
    );
    expect(face.methodUpdates, isEmpty);
    expect(face.enrolls, 0);
  });
  testWidgets(
    'retained enrollment action cannot mutate the replacement session',
    (tester) async {
      final face = FaceFixture()
        ..status = const BioPayEnrollmentStatus(
          status: 'active',
          hasFace: true,
        );
      await mount(
        tester,
        face,
        CaptureFixture(),
        GatewayFixture(),
        enroll: true,
      );
      final oldCallback = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Pause face lookup'),
          )
          .onPressed!;
      face.generation++;
      AccountContext.changes.value++;
      await tester.pumpAndSettle();
      oldCallback();
      await tester.pumpAndSettle();
      expect(face.actions, isEmpty);
    },
  );
  test('unconfirmed Face status is unavailable, not unenrolled', () {
    expect(const BioPayEnrollmentStatus().label, 'Unavailable');
    expect(() => BioPayEnrollmentStatus.fromJson({}), throwsFormatException);
    expect(
      BioPayEnrollmentStatus.fromJson({
        'status': 'not_started',
        'has_face': false,
        'receiving_method_id': null,
        'pending_vector_id': null,
      }).label,
      'Set up',
    );
  });

  testWidgets('loading status does not claim absent enrollment', (
    tester,
  ) async {
    final face = FaceFixture()..pendingStatus = Completer();
    await mount(
      tester,
      face,
      CaptureFixture(),
      GatewayFixture(),
      enroll: true,
      settle: false,
    );
    expect(find.text('Please wait…'), findsOneWidget);
    expect(find.text('Set up'), findsNothing);
    expect(
      find.text('Face lookup is unavailable. Try again or use a number or QR.'),
      findsNothing,
    );
    face.pendingStatus!.complete(
      const BioPayEnrollmentStatus(status: 'not_started'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Please wait…'), findsNothing);
  });
  for (final prior in ['active', 'paused']) {
    testWidgets(
      'confirmed $prior cache permits truthful recovery during outage',
      (tester) async {
        final face = FaceFixture()
          ..status = BioPayEnrollmentStatus(
            status: prior,
            hasFace: true,
            receivingMethodId: '44444444-4444-4444-8444-444444444444',
          );
        final camera = CaptureFixture();
        await mount(tester, face, camera, GatewayFixture(), enroll: true);
        face.statusUnavailable = true;
        // A confirmed action refreshes status; failure cannot invent enrollment
        // absence or hide the already-confirmed recovery controls.
        await _tapVisibleControl(
          tester,
          find.text(
            prior == 'paused' ? 'Resume face lookup' : 'Pause face lookup',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Face lookup is unavailable. Try again or use a number or QR.',
          ),
          findsWidgets,
        );
        expect(find.text('Remove my face'), findsOneWidget);
        expect(
          find.text(
            prior == 'paused' ? 'Pause face lookup' : 'Resume face lookup',
          ),
          findsOneWidget,
        );
        expect(face.actions.single, prior == 'paused' ? 'resume' : 'pause');
        final captureButton = tester.widget<MobiButton>(
          find.widgetWithText(MobiButton, 'Update face'),
        );
        expect(captureButton.onPressed, isNull);
        expect(camera.starts, 0);
        await tester.tap(find.text('Remove my face'));
        await tester.pumpAndSettle();
        expect(face.actions.last, 'remove');
        expect(find.text('Remove my face'), findsNothing);
        expect(find.text('Pause face lookup'), findsNothing);
        expect(find.text('Resume face lookup'), findsNothing);
        face.generation++;
        AccountContext.changes.value++;
        await tester.pumpAndSettle();
        expect(find.text('Remove my face'), findsNothing);
        expect(find.text('Pause face lookup'), findsNothing);
        expect(find.text('Resume face lookup'), findsNothing);
      },
    );
  }
  testWidgets(
    'confirmed first enrollment retains recovery when its refresh is unavailable',
    (tester) async {
      final enrollment = Completer<String>();
      final face = FaceFixture()..pendingEnrollment = enrollment;
      final camera = CaptureFixture();
      await mount(tester, face, camera, GatewayFixture(), enroll: true);
      expect(find.text('Remove my face'), findsNothing);
      expect(find.text('Pause face lookup'), findsNothing);
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
      await tester.pump();
      expect(face.enrolls, 1);
      face.statusUnavailable = true;
      enrollment.complete('active');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Face lookup is unavailable. Try again or use a number or QR.',
        ),
        findsWidgets,
      );
      expect(find.text('Face setup saved'), findsNothing);
      expect(find.text('Pause face lookup'), findsOneWidget);
      expect(find.text('Remove my face'), findsOneWidget);
      expect(
        tester
            .widget<MobiButton>(find.widgetWithText(MobiButton, 'Update face'))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Pause face lookup'));
      await tester.tap(find.text('Pause face lookup'));
      await tester.pumpAndSettle();
      expect(face.actions, ['pause']);
      expect(find.text('Resume face lookup'), findsOneWidget);
      await tester.ensureVisible(find.text('Remove my face'));
      await tester.tap(find.text('Remove my face'));
      await tester.pumpAndSettle();
      expect(face.actions, ['pause', 'remove']);
      expect(find.text('Remove my face'), findsNothing);
      expect(find.text('Resume face lookup'), findsNothing);
    },
  );
  testWidgets(
    'confirmed outage recovery cache clears on same-owner replacement',
    (tester) async {
      final face = FaceFixture()
        ..status = const BioPayEnrollmentStatus(
          status: 'active',
          hasFace: true,
          receivingMethodId: '44444444-4444-4444-8444-444444444444',
        );
      await mount(
        tester,
        face,
        CaptureFixture(),
        GatewayFixture(),
        enroll: true,
      );
      face.statusUnavailable = true;
      await _tapVisibleControl(tester, find.text('Pause face lookup'));
      await tester.pumpAndSettle();
      final oldRemove = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Remove my face'))
          .onPressed!;
      expect(find.text('Resume face lookup'), findsOneWidget);
      face.generation++;
      AccountContext.changes.value++;
      await tester.pumpAndSettle();
      expect(find.text('Resume face lookup'), findsNothing);
      expect(find.text('Remove my face'), findsNothing);
      oldRemove();
      await tester.pumpAndSettle();
      expect(face.actions, ['pause']);
    },
  );
  for (final prior in ['not_started', 'active']) {
    testWidgets(
      'unknown enrollment from $prior blocks fresh capture until status refresh',
      (tester) async {
        final enrollment = Completer<String>();
        final face = FaceFixture()
          ..pendingEnrollment = enrollment
          ..status = BioPayEnrollmentStatus(
            status: prior,
            hasFace: prior == 'active',
            receivingMethodId: prior == 'active'
                ? '44444444-4444-4444-8444-444444444444'
                : null,
          );
        final camera = CaptureFixture();
        await mount(tester, face, camera, GatewayFixture(), enroll: true);
        if (prior == 'not_started') {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Receiving B · •••• 7816').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        final open = find.widgetWithText(
          MobiButton,
          prior == 'active' ? 'Update face' : 'Open camera',
        );
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MobiButton, 'Capture once'));
        await tester.pump();
        expect(face.enrolls, 1);
        enrollment.completeError(
          const FaceServiceException(
            'OUTCOME_UNKNOWN',
            operation: 'biopay_face:enroll',
            operationId: 'original-enrollment',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Face lookup is unavailable. Try again or use a number or QR.',
          ),
          findsWidgets,
        );
        expect(find.text('Face setup saved'), findsNothing);
        final blocked = find.widgetWithText(
          MobiButton,
          prior == 'active' ? 'Update face' : 'Open camera',
        );
        expect(tester.widget<MobiButton>(blocked).onPressed, isNull);
        await tester.ensureVisible(blocked);
        await tester.tap(blocked);
        await tester.pumpAndSettle();
        expect(face.enrolls, 1);
        expect(camera.starts, 1);
        expect(
          find.text('Remove my face'),
          prior == 'active' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Pause face lookup'),
          prior == 'active' ? findsOneWidget : findsNothing,
        );
        if (prior == 'active') {
          face.statusUnavailable = true;
          await tester.ensureVisible(find.text('Pause face lookup'));
          await tester.tap(find.text('Pause face lookup'));
          await tester.pumpAndSettle();
          expect(face.actions, ['pause']);
          expect(face.enrolls, 1);
          expect(find.text('Resume face lookup'), findsOneWidget);
          expect(tester.widget<MobiButton>(blocked).onPressed, isNull);
          face
            ..status = const BioPayEnrollmentStatus(
              status: 'paused',
              hasFace: true,
              receivingMethodId: '44444444-4444-4444-8444-444444444444',
            )
            ..statusUnavailable = false;
        }
        // A confirmed status read permits an explicit fresh capture. No new
        // mutation is dispatched merely by refreshing or enabling its button.
        await tester.ensureVisible(find.text('Check setup status'));
        await tester.tap(find.text('Check setup status'));
        await tester.pumpAndSettle();
        expect(face.enrolls, 1);
        if (prior == 'not_started') {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Receiving B · •••• 7816').last);
          await tester.pumpAndSettle();
        }
        expect(tester.widget<MobiButton>(blocked).onPressed, isNotNull);
      },
    );
  }
  testWidgets(
    'unknown management outcome cannot advance confirmed cache or claim ready',
    (tester) async {
      final face = FaceFixture()
        ..status = const BioPayEnrollmentStatus(
          status: 'active',
          hasFace: true,
          receivingMethodId: '44444444-4444-4444-8444-444444444444',
        );
      await mount(
        tester,
        face,
        CaptureFixture(),
        GatewayFixture(),
        enroll: true,
      );
      face.actionError = const FaceServiceException('OUTCOME_UNKNOWN');
      await _tapVisibleControl(tester, find.text('Pause face lookup'));
      await tester.pumpAndSettle();
      expect(face.actions, ['pause']);
      expect(
        find.text(
          'Face lookup is unavailable. Try again or use a number or QR.',
        ),
        findsWidgets,
      );
      expect(find.text('Resume face lookup'), findsNothing);
      expect(find.text('Pause face lookup'), findsOneWidget);
      expect(find.text('Remove my face'), findsOneWidget);
      expect(
        tester
            .widget<MobiButton>(find.widgetWithText(MobiButton, 'Update face'))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'Face status outage disables enrollment until a confirmed refresh',
    (tester) async {
      final face = FaceFixture()..statusUnavailable = true;
      await mount(
        tester,
        face,
        CaptureFixture(),
        GatewayFixture(),
        enroll: true,
      );
      expect(
        find.text(
          'Face lookup is unavailable. Try again or use a number or QR.',
        ),
        findsWidgets,
      );
      expect(
        tester
            .widget<MobiButton>(find.widgetWithText(MobiButton, 'Open camera'))
            .onPressed,
        isNull,
      );
      face.statusUnavailable = false;
      await _tapVisibleControl(tester, find.text('Check setup status'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Face lookup is unavailable. Try again or use a number or QR.',
        ),
        findsNothing,
      );
      expect(face.enrolls, 0);
    },
  );

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
      expect(face.preparations, 1);
      expect(face.handoffs, 1);
      expect(find.text('Review'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gateway.launches, 1);
    },
  );
  for (final code in [
    'RECIPIENT_UNAVAILABLE',
    'ADMIN_REAUTHENTICATION_REQUIRED',
  ]) {
    testWidgets('pre-launch $code rejection cannot open the dialer', (
      tester,
    ) async {
      final face = FaceFixture()..prepareError = FaceServiceException(code);
      final gateway = GatewayFixture();
      await mount(tester, face, CaptureFixture(), gateway);
      await scan(tester);
      face.pending.complete(shortcut());
      await tester.pumpAndSettle();
      expect(face.preparations, 1);
      expect(gateway.launches, 0);
      expect(face.handoffs, 0);
      if (code == 'ADMIN_REAUTHENTICATION_REQUIRED') {
        expect(
          find.widgetWithText(TextButton, 'Sign in again to continue.'),
          findsOneWidget,
        );
      }
    });
  }
  for (final reason in ['leave', 'background', 'account', 'generation']) {
    testWidgets('$reason during preparation prevents external handoff', (
      tester,
    ) async {
      final face = FaceFixture()
        ..pendingPreparation = Completer<PreparedFaceUssdShortcut>();
      final gateway = GatewayFixture();
      await mount(tester, face, CaptureFixture(), gateway);
      await scan(tester);
      face.pending.complete(shortcut());
      await tester.pump();
      await tester.pump();
      expect(face.preparations, 1);
      expect(gateway.launches, 0);
      if (reason == 'leave') await tester.pumpWidget(const SizedBox());
      if (reason == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
      }
      if (reason == 'account') face.account = 'another-user';
      if (reason == 'generation') {
        face.generation++;
        AccountContext.changes.value++;
      }
      face.pendingPreparation!.complete(shortcut());
      await tester.pumpAndSettle();
      expect(gateway.launches, 0);
      expect(face.handoffs, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }
  for (final changed in [
    'recipient',
    'method_version',
    'route_version',
    'provider',
    'code',
    'expired',
  ]) {
    testWidgets(
      'changed $changed preparation cannot launch the original route',
      (tester) async {
        final face = FaceFixture()
          ..pendingPreparation = Completer<PreparedFaceUssdShortcut>();
        final gateway = GatewayFixture();
        await mount(tester, face, CaptureFixture(), gateway);
        await scan(tester);
        final original = shortcut();
        face.pending.complete(original);
        await tester.pump();
        await tester.pump();
        face.pendingPreparation!.complete(
          PreparedFaceUssdShortcut(
            requestId: original.requestId,
            payeeId: changed == 'recipient'
                ? '66666666-6666-4666-8666-666666666666'
                : original.payeeId,
            receivingMethodId: original.receivingMethodId,
            receivingMethodVersion:
                original.receivingMethodVersion +
                (changed == 'method_version' ? 1 : 0),
            provider: changed == 'provider' ? 'airtel_rw' : original.provider,
            routeId: original.routeId,
            routeVersion:
                original.routeVersion + (changed == 'route_version' ? 1 : 0),
            ussdCode: changed == 'code'
                ? '*182*1*1*0700000000#'
                : original.ussdCode,
            expiresAt: changed == 'expired'
                ? DateTime.now().subtract(const Duration(seconds: 1))
                : original.expiresAt,
          ),
        );
        await tester.pumpAndSettle();
        expect(face.preparations, 1);
        expect(gateway.launches, 0);
        expect(face.handoffs, 0);
      },
    );
  }
  testWidgets('freshness recovery opens Admin OTP without repeating the scan', (
    tester,
  ) async {
    final face = FaceFixture()
      ..prepareError = const FaceServiceException(
        'ADMIN_REAUTHENTICATION_REQUIRED',
      );
    final camera = CaptureFixture(), gateway = GatewayFixture();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BioPayFaceScanScreen(onBack: () {}),
        ),
        GoRoute(
          path: '/admin-auth',
          builder: (_, _) => const Scaffold(body: Text('Admin OTP')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await mount(tester, face, camera, gateway, router: router);
    await scan(tester);
    face.pending.complete(shortcut());
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Sign in again to continue.'),
    );
    await tester.tap(
      find.widgetWithText(TextButton, 'Sign in again to continue.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Admin OTP'), findsOneWidget);
    expect(face.scans, 1);
    expect(gateway.launches, 0);
    expect(camera.ready, isFalse);
  });
  for (final reason in ['leave', 'background', 'account', 'generation']) {
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
      if (reason == 'generation') {
        face.generation++;
        AccountContext.changes.value++;
      }
      face.pending.complete(shortcut());
      await tester.pumpAndSettle();
      expect(gateway.launches, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }
  testWidgets(
    'same-owner session replacement during camera capture cannot resolve',
    (tester) async {
      final face = FaceFixture(),
          camera = CaptureFixture(),
          gateway = GatewayFixture();
      camera.pendingCapture = Completer<Uint8List>();
      await mount(tester, face, camera, gateway);
      await scan(tester);
      expect(camera.captures, 1);
      face.generation++;
      AccountContext.changes.value++;
      final bytes = Uint8List.fromList([8, 7, 6]);
      camera.pendingCapture!.complete(bytes);
      await tester.pumpAndSettle();
      expect(face.scans, 0);
      expect(gateway.launches, 0);
      expect(bytes, everyElement(0));
      expect(camera.ready, isFalse);
    },
  );
  testWidgets(
    'same-owner session replacement discards a pending enrollment reply',
    (tester) async {
      final face = FaceFixture(),
          camera = CaptureFixture(),
          gateway = GatewayFixture();
      face.pendingEnrollment = Completer<String>();
      await mount(tester, face, camera, gateway, enroll: true);
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
      await tester.pump();
      expect(face.enrolls, 1);
      face.generation++;
      AccountContext.changes.value++;
      face.pendingEnrollment!.complete('active');
      await tester.pumpAndSettle();
      expect(find.text('Face setup saved'), findsNothing);
      expect(find.text('Pause face lookup'), findsNothing);
      expect(find.text('Remove my face'), findsNothing);
      expect(find.text('Receiving B · •••• 7816'), findsNothing);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(gateway.launches, 0);
    },
  );
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
