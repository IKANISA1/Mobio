import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_ussd_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_scan_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../test/helpers/mobile_scanner_test_channel.dart';

void main() {
  setUp(installMobileScannerTestChannel);
  tearDown(uninstallMobileScannerTestChannel);

  Future<void> open(
    WidgetTester tester,
    _ReviewService service, {
    AppPermissionService? permissions,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          biopayUssdServiceProvider.overrideWithValue(service),
          if (permissions != null)
            appPermissionServiceProvider.overrideWithValue(permissions),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayScanScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void detect(WidgetTester tester, String value) {
    tester
        .widget<BioPayQrScannerSurface>(find.byType(BioPayQrScannerSurface))
        .onDetect(value);
  }

  testWidgets('valid QR can be scanned after an unrelated QR', (tester) async {
    final service = _ReviewService();
    await open(tester, service);
    detect(tester, 'https://example.invalid/unrelated');
    await tester.pumpAndSettle();
    detect(tester, 'valid-review-token');
    await tester.pumpAndSettle();
    expect(
      service.calls,
      1,
      reason: 'An unrelated QR must not disable all subsequent detection.',
    );
    expect(find.byType(BioPayResolvedPaymentPreview), findsOneWidget);
  });

  testWidgets('another QR can resolve after a lookup failure', (tester) async {
    final service = _ReviewService()..failFirst = true;
    await open(tester, service);
    detect(tester, 'unavailable-review-token');
    await tester.pumpAndSettle();
    expect(find.text('QR request unavailable.'), findsOneWidget);
    detect(tester, 'valid-review-token');
    await tester.pumpAndSettle();
    expect(
      service.calls,
      2,
      reason: 'A failed request must not permanently lock scan handling.',
    );
    expect(find.byType(BioPayResolvedPaymentPreview), findsOneWidget);
  });
  testWidgets('scan again restarts detection and retries the same token', (
    tester,
  ) async {
    final camera = _CameraChannel()..install();
    final service = _ReviewService()..failFirst = true;
    await open(tester, service);
    expect(
      tester
          .widget<MobileScanner>(find.byType(MobileScanner))
          .controller!
          .value
          .isRunning,
      isTrue,
    );
    detect(tester, 'same-review-token');
    await tester.pumpAndSettle();
    expect(find.text('QR request unavailable.'), findsOneWidget);
    final startsBefore = camera.starts;
    await tester.ensureVisible(find.text('Scan again'));
    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    expect(camera.starts, greaterThan(startsBefore));
    expect(
      tester
          .widget<MobileScanner>(find.byType(MobileScanner))
          .controller!
          .value
          .isRunning,
      isTrue,
    );
    expect(find.text('QR request unavailable.'), findsNothing);
    detect(tester, 'same-review-token');
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.byType(BioPayResolvedPaymentPreview), findsOneWidget);
  });

  testWidgets('duplicate detections do not reopen the dialer', (tester) async {
    final pending = Completer<bool>();
    final service = _ReviewService()..dialerResult = pending.future;
    await open(tester, service);
    const qr = 'tel:*182*1*1*250788000000*100%23';
    detect(tester, qr);
    detect(tester, qr);
    await tester.pump();
    expect(service.dialerCalls, 1);
    expect(find.text('Reading QR…'), findsOneWidget);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('USSD dialer opened.'), findsOneWidget);
    detect(tester, qr);
    expect(service.dialerCalls, 1);
    await tester.ensureVisible(find.text('Scan again'));
    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    detect(tester, qr);
    await tester.pumpAndSettle();
    expect(service.dialerCalls, 2);
  });

  testWidgets('failed dialer handoff permits another detection', (
    tester,
  ) async {
    final service = _ReviewService()..dialerResult = Future.value(false);
    await open(tester, service);
    const qr = 'tel:*182*1*1*250788000000*100%23';
    detect(tester, qr);
    await tester.pumpAndSettle();
    expect(find.text('USSD dialer unavailable.'), findsOneWidget);
    service.dialerResult = Future.value(true);
    detect(tester, qr);
    await tester.pumpAndSettle();
    expect(service.dialerCalls, 2);
    expect(find.text('USSD dialer opened.'), findsOneWidget);
  });

  testWidgets('malformed QR cannot crash or lock subsequent detection', (
    tester,
  ) async {
    final service = _ReviewService();
    await open(tester, service);
    detect(tester, 'tel:%E0%A4%A');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    detect(tester, 'valid-review-token');
    await tester.pumpAndSettle();
    expect(find.byType(BioPayResolvedPaymentPreview), findsOneWidget);
  });

  testWidgets('camera denial explains recovery and opens Settings', (
    tester,
  ) async {
    var opened = 0;
    await open(
      tester,
      _ReviewService(),
      permissions: AppPermissionService(
        openSettings: () async {
          opened++;
          return true;
        },
      ),
    );
    expect(find.text('Camera access needed'), findsOneWidget);
    expect(
      find.text('Allow camera access in Settings to scan QR codes.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Torch'), findsNothing);
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('Retry camera'), findsOneWidget);
  });

  testWidgets('camera resumes after permission changes in Settings', (
    tester,
  ) async {
    final camera = _CameraChannel()
      ..authorized = false
      ..install();
    await open(tester, _ReviewService());
    expect(find.text('Camera access needed'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    camera.authorized = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Camera access needed'), findsNothing);
    expect(camera.starts, 1);
    expect(
      tester
          .widget<MobileScanner>(find.byType(MobileScanner))
          .controller!
          .value
          .isRunning,
      isTrue,
    );
    expect(find.byTooltip('Torch'), findsOneWidget);
  });

  testWidgets('missing camera has an explanation and working retry', (
    tester,
  ) async {
    final camera = _CameraChannel()
      ..unavailable = true
      ..install();
    await open(tester, _ReviewService());
    expect(find.text('No camera available'), findsOneWidget);
    expect(find.text('Open Settings'), findsNothing);
    camera.unavailable = false;
    await tester.tap(find.text('Retry camera'));
    await tester.pumpAndSettle();
    expect(find.text('No camera available'), findsNothing);
    expect(camera.starts, 2);
  });

  testWidgets('denied camera recovery fits narrow enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: BioPayScanScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open Settings'));
    expect(tester.takeException(), isNull);
    expect(find.text('Camera access needed'), findsOneWidget);
  });
}

class _ReviewService extends BioPayUssdService {
  int calls = 0;
  bool failFirst = false;
  int dialerCalls = 0;
  Future<bool> dialerResult = Future.value(true);
  @override
  Future<bool> launchUssdCode(String ussdCode) {
    dialerCalls++;
    return dialerResult;
  }

  @override
  BioPayUssdPaymentRequest resolvePreviewToken(String token) {
    calls++;
    if (failFirst && calls == 1) throw StateError('simulated_lookup_failure');
    return super.resolvePreviewToken(token);
  }
}

class _CameraChannel {
  bool authorized = true;
  bool unavailable = false;
  int starts = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          (call) async {
            switch (call.method) {
              case 'state':
                return authorized ? 1 : 2;
              case 'request':
                return authorized;
              case 'getSupportedLenses':
                return <int>[];
              case 'start':
                starts++;
                if (unavailable) {
                  throw PlatformException(
                    code: 'MOBILE_SCANNER_NO_CAMERA_ERROR',
                  );
                }
                return <String, Object?>{
                  'textureId': 17,
                  'cameraDirection': 1,
                  'numberOfCameras': 1,
                  'currentTorchState': 0,
                  'handlesCropAndRotation': true,
                  'naturalDeviceOrientation': 'PORTRAIT_UP',
                  'sensorOrientation': 90,
                  'size': {'width': 1920.0, 'height': 1080.0},
                };
              default:
                return null;
            }
          },
        );
  }
}
