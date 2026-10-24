import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_service.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_write_card_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_nfc_link_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

const diagnostics = BioPayNfcTagDiagnostics(
  tagId: 'fixture',
  standard: 'fixture',
  type: 'fixture',
  ndefAvailable: true,
  ndefWritable: true,
  ndefCanMakeReadOnly: true,
  ndefCapacity: 1024,
);
BioPayNfcWriteResult written(BioPayNfcCardPayload payload) =>
    BioPayNfcWriteResult(
      expected: payload,
      readBack: payload,
      verified: true,
      diagnostics: diagnostics,
    );

class _Nfc extends Fake implements BioPayNfcService {
  int writes = 0, locks = 0, cancels = 0;
  Completer<BioPayNfcWriteResult>? pendingWrite;
  Completer<void>? pendingCancel;
  BioPayNfcCardPayload? payload;
  @override
  Future<void> cancelActiveSession() async {
    cancels++;
    await pendingCancel?.future;
  }

  @override
  Future<void> finishWithError(String error) async {}
  @override
  Future<BioPayNfcWriteResult> writeCard(
    BioPayNfcCardPayload payload, {
    ValueChangedStep? onStep,
  }) async {
    writes++;
    this.payload = payload;
    onStep?.call(BioPayNfcOperationStep.writing);
    return pendingWrite?.future ?? written(payload);
  }

  @override
  Future<BioPayNfcLockResult> lockVerifiedCard(
    BioPayNfcCardPayload expected, {
    ValueChangedStep? onStep,
  }) async {
    locks++;
    onStep?.call(BioPayNfcOperationStep.locking);
    return BioPayNfcLockResult(payload: expected, diagnostics: diagnostics);
  }
}

class _Gateway extends PaymentDiscoveryFixture {
  Completer<Map<String, dynamic>>? pendingWorkspace, pendingPreview;
  @override
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> data) {
    if (action == 'workspace' && pendingWorkspace != null) {
      calls.add(action);
      return pendingWorkspace!.future;
    }
    return super.call(action, data);
  }

  @override
  Future<Map<String, dynamic>> previewLink(String token) async =>
      pendingPreview?.future ?? super.previewLink(token);
}

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester,
    Widget child,
    _Gateway gateway,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [paymentDiscoveryServiceProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.darkTheme, home: child),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  void replace(_Gateway gateway) {
    gateway.generation++;
    AccountContext.changes.value++;
  }

  Future<void> selectLink(WidgetTester tester) async {
    await tester.tap(find.text('Lunch request'));
    await tester.pump();
  }

  testWidgets('background cancels explicit NFC and resume never retries it', (
    tester,
  ) async {
    final gateway = _Gateway();
    final nfc = _Nfc()..pendingWrite = Completer();
    await mount(tester, PaymentNfcLinkScreen(nfcService: nfc), gateway);
    await selectLink(tester);
    await tester.tap(find.text('Write NFC card').last);
    await tester.pump();
    expect(nfc.writes, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(nfc.cancels, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    nfc.pendingWrite!.complete(written(nfc.payload!));
    await tester.pumpAndSettle();
    expect(nfc.writes, 1);
    expect(nfc.locks, 0);
    expect(find.text('Card written and read back successfully'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late NFC-link workspace cannot reveal the old account links', (
    tester,
  ) async {
    final gateway = _Gateway()..pendingWorkspace = Completer();
    final nfc = _Nfc();
    await mount(tester, PaymentNfcLinkScreen(nfcService: nfc), gateway);
    replace(gateway);
    gateway.pendingWorkspace!.complete(gateway.workspace);
    await tester.pumpAndSettle();
    expect(find.text('Lunch request'), findsNothing);
    expect(nfc.writes, 0);
  });
  testWidgets(
    'session replacement during public preview cannot write a private saved link',
    (tester) async {
      final gateway = _Gateway()..pendingPreview = Completer();
      final nfc = _Nfc();
      await mount(tester, PaymentNfcLinkScreen(nfcService: nfc), gateway);
      await selectLink(tester);
      await tester.tap(find.text('Write NFC card').last);
      await tester.pump();
      replace(gateway);
      gateway.pendingPreview!.complete({'available': true});
      await tester.pumpAndSettle();
      expect(nfc.writes, 0);
      expect(find.text('Lunch request'), findsNothing);
      expect(
        find.text('Card written and read back successfully'),
        findsNothing,
      );
    },
  );
  testWidgets('old NFC write cleanup cannot resume a newer suspension lease', (
    tester,
  ) async {
    final gateway = _Gateway();
    final nfc = _Nfc()..pendingWrite = Completer();
    final container = await mount(
      tester,
      PaymentNfcLinkScreen(nfcService: nfc),
      gateway,
    );
    await selectLink(tester);
    await tester.tap(find.text('Write NFC card').last);
    await tester.pump();
    expect(nfc.writes, 1);
    replace(gateway);
    await tester.pump();
    final foreground = container.read(
      bioPayNfcForegroundSuspendedProvider.notifier,
    );
    final newerLease = foreground.acquireSuspension();
    nfc.pendingWrite!.complete(written(nfc.payload!));
    await tester.pumpAndSettle();
    expect(container.read(bioPayNfcForegroundSuspendedProvider), isTrue);
    expect(foreground.ownsSuspension(newerLease), isTrue);
    expect(find.text('Card written and read back successfully'), findsNothing);
    expect(nfc.locks, 0);
  });
  testWidgets(
    'NFC-link lock confirmation cannot lock after session replacement',
    (tester) async {
      final gateway = _Gateway(), nfc = _Nfc();
      await mount(tester, PaymentNfcLinkScreen(nfcService: nfc), gateway);
      await selectLink(tester);
      await tester.tap(find.text('Write NFC card').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make card read-only').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      replace(gateway);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(nfc.locks, 0);
      expect(find.text('Card is read-only'), findsNothing);
    },
  );
  Future<void> openRawWriter(
    WidgetTester tester,
    _Gateway gateway,
    BioPayNfcService nfc,
  ) async {
    await mount(
      tester,
      BioPayNfcWriteCardScreen.test(
        onBack: () {},
        nfcService: nfc,
        captureAccount: gateway.captureAccount,
        isCurrent: gateway.isCurrent,
      ),
      gateway,
    );
    await tester.enterText(find.byType(TextField), '0788123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(MobiButton, 'Write NFC'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'raw receiver confirmation hides on session replacement without writing',
    (tester) async {
      final gateway = _Gateway(), nfc = _Nfc();
      await openRawWriter(tester, gateway, nfc);
      expect(find.text('Write'), findsOneWidget);
      replace(gateway);
      await tester.pumpAndSettle();
      expect(find.text('Write'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(nfc.writes, 0);
    },
  );
  testWidgets(
    'session replacement during cancellation prevents native raw write dispatch',
    (tester) async {
      final gateway = _Gateway(), nfc = _Nfc()..pendingCancel = Completer();
      await openRawWriter(tester, gateway, nfc);
      await tester.tap(find.text('Write'));
      await tester.pump();
      replace(gateway);
      nfc.pendingCancel!.complete();
      await tester.pumpAndSettle();
      expect(nfc.writes, 0);
      expect(find.text('Card written and verified'), findsNothing);
    },
  );
  testWidgets(
    'raw writer ignores late completion and cannot release a newer lease',
    (tester) async {
      final gateway = _Gateway(), nfc = _Nfc()..pendingWrite = Completer();
      await openRawWriter(tester, gateway, nfc);
      await tester.tap(find.text('Write'));
      await tester.pump();
      expect(nfc.writes, 1);
      replace(gateway);
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BioPayNfcWriteCardScreen)),
      );
      final foreground = container.read(
        bioPayNfcForegroundSuspendedProvider.notifier,
      );
      final newerLease = foreground.acquireSuspension();
      nfc.pendingWrite!.complete(written(nfc.payload!));
      await tester.pumpAndSettle();
      expect(foreground.ownsSuspension(newerLease), isTrue);
      expect(find.text('Card written and verified'), findsNothing);
      expect(find.text('Lock Card'), findsNothing);
    },
  );
  testWidgets(
    'native availability reply after session replacement cannot dispatch a card write',
    (tester) async {
      const kit = MethodChannel('flutter_nfc_kit/method');
      const writer = MethodChannel('rw.mobi.app/biopay_nfc_writer');
      final messenger = tester.binding.defaultBinaryMessenger;
      final availability = Completer<String>();
      var availabilityChecks = 0, writes = 0;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger
        ..setMockMethodCallHandler(kit, (call) async {
          if (call.method == 'getNFCAvailability') {
            availabilityChecks++;
            return availability.future;
          }
          return null;
        })
        ..setMockMethodCallHandler(writer, (call) async {
          if (call.method == 'writeCard') writes++;
          return null;
        });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger
          ..setMockMethodCallHandler(kit, null)
          ..setMockMethodCallHandler(writer, null);
      });
      final gateway = _Gateway();
      await openRawWriter(tester, gateway, const BioPayNfcService());
      await tester.tap(find.text('Write'));
      await tester.pump();
      expect(availabilityChecks, 1);
      replace(gateway);
      availability.complete('available');
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Card written and verified'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('raw card lock confirmation cannot dispatch for a new session', (
    tester,
  ) async {
    final gateway = _Gateway(), nfc = _Nfc();
    await openRawWriter(tester, gateway, nfc);
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lock Card'));
    await tester.tap(find.text('Lock Card'));
    await tester.pumpAndSettle();
    expect(find.text('Lock'), findsOneWidget);
    replace(gateway);
    await tester.pumpAndSettle();
    expect(find.text('Lock'), findsNothing);
    expect(nfc.locks, 0);
  });
  testWidgets('return from requests cannot reload the prior account NFC view', (
    tester,
  ) async {
    final gateway = _Gateway(), nfc = _Nfc();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => PaymentNfcLinkScreen(nfcService: nfc),
        ),
        GoRoute(
          path: '/biopay/requests',
          builder: (_, _) => const Scaffold(body: Text('Requests destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [paymentDiscoveryServiceProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await selectLink(tester);
    await tester.tap(find.text('Payment requests'));
    await tester.pumpAndSettle();
    expect(find.text('Requests destination'), findsOneWidget);
    replace(gateway);
    router.pop();
    await tester.pumpAndSettle();
    expect(gateway.calls, ['workspace']);
    expect(find.text('Lunch request'), findsNothing);
    expect(nfc.writes, 0);
  });
}
