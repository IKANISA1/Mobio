import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_device_nfc_service.dart';
import 'package:mobi_app/features/biopay/data/biopay_ussd_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_screen.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/profile.dart';

class _Profile extends Fake implements ProfileService {
  Completer<Profile?>? pending;
  @override
  Future<Profile?> getMyProfile() async =>
      pending?.future ??
      const Profile(id: 'owner-a', momoNumber: '+250788123456');
}

class _Requests extends BioPayUssdService {
  int creates = 0;
  Completer<BioPayUssdPaymentRequest>? pending;
  BioPayUssdPaymentRequest get request =>
      createPreviewRequest(channel: BioPayRequestChannel.nfc);
  @override
  Future<BioPayUssdPaymentRequest> createPaymentRequest({
    required BioPayRequestChannel channel,
    required int amountMinor,
    required String payeeLabel,
    String providerCode = 'mtn_rw',
    String? payeePhone,
  }) async {
    creates++;
    return pending?.future ?? request;
  }
}

class _Native extends BioPayDeviceNfcService {
  int starts = 0, stops = 0;
  Completer<BioPayDeviceNfcStatus>? pendingStart, pendingStop;
  bool Function()? startDispatch, stopDispatch;
  BioPayDeviceNfcStatus get active => BioPayDeviceNfcStatus(
    supported: true,
    enabled: true,
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
  );
  @override
  Future<BioPayDeviceNfcStatus> startPaymentRequest(
    BioPayUssdPaymentRequest request, {
    bool Function()? canDispatch,
  }) async {
    startDispatch = canDispatch;
    expect(canDispatch?.call(), isTrue);
    starts++;
    return pendingStart?.future ?? active;
  }

  @override
  Future<BioPayDeviceNfcStatus> stop({bool Function()? canDispatch}) async {
    stopDispatch = canDispatch;
    stops++;
    return pendingStop?.future ??
        const BioPayDeviceNfcStatus(supported: true, enabled: false);
  }
}

void main() {
  late _Profile profile;
  late _Requests requests;
  late _Native native;
  late ProviderContainer container;
  var generation = 0;
  var owner = 'owner-a';
  setUp(() {
    generation = 0;
    owner = 'owner-a';
    profile = _Profile();
    requests = _Requests();
    native = _Native();
    container = ProviderContainer(
      overrides: [
        profileServiceProvider.overrideWithValue(profile),
        biopayUssdServiceProvider.overrideWithValue(requests),
      ],
    );
    addTearDown(container.dispose);
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayNfcScreen.test(
            onBack: () {},
            deviceNfcService: native,
            captureAccount: () =>
                AccountSnapshot(owner, 'session-$generation', generation),
            isCurrent: (snapshot) =>
                snapshot.userId == owner && snapshot.generation == generation,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  void replace({bool switchOwner = false}) {
    generation++;
    if (switchOwner) owner = 'owner-b';
    AccountContext.changes.value++;
  }

  Future<void> activate(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(MobiButton, 'Activate Device NFC'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('late A profile cannot hydrate a replaced account form', (
    tester,
  ) async {
    profile.pending = Completer();
    await mount(tester);
    replace(switchOwner: true);
    profile.pending!.complete(
      const Profile(id: 'owner-a', momoNumber: '+250788123456'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('788123456'), findsNothing);
    expect(requests.creates, 0);
  });
  testWidgets('same-owner replacement rejects a retained activate callback', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    final activate = tester
        .widget<MobiButton>(
          find.widgetWithText(MobiButton, 'Activate Device NFC'),
        )
        .onPressed!;
    replace();
    await tester.pumpAndSettle();
    activate();
    await tester.pumpAndSettle();
    expect(requests.creates, 0);
    expect(native.starts, 0);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets(
    'held request reply cannot start native NFC under a new session',
    (tester) async {
      requests.pending = Completer();
      await mount(tester);
      await tester.pumpAndSettle();
      await activate(tester);
      expect(requests.creates, 1);
      replace();
      requests.pending!.complete(requests.request);
      await tester.pumpAndSettle();
      expect(native.starts, 0);
      expect(find.text('Listening'), findsNothing);
    },
  );
  testWidgets('late native start cannot show A receipt or resume newer lease', (
    tester,
  ) async {
    native
      ..pendingStart = Completer()
      ..pendingStop = Completer();
    await mount(tester);
    await tester.pumpAndSettle();
    await activate(tester);
    expect(native.starts, 1);
    replace(switchOwner: true);
    await tester.pump();
    expect(native.stops, 1);
    final foreground = container.read(
      bioPayNfcForegroundSuspendedProvider.notifier,
    );
    final newer = foreground.acquireSuspension();
    expect(native.startDispatch!.call(), isFalse);
    expect(native.stopDispatch!.call(), isFalse);
    native.pendingStart!.complete(native.active);
    native.pendingStop!.complete(
      const BioPayDeviceNfcStatus(supported: true, enabled: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Listening'), findsNothing);
    expect(foreground.ownsSuspension(newer), isTrue);
    expect(container.read(bioPayNfcForegroundSuspendedProvider), isTrue);
  });
  testWidgets('current activation reaches native and clears on invalidation', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    await activate(tester);
    expect(native.starts, 1);
    expect(find.text('Listening'), findsOneWidget);
    replace();
    await tester.pumpAndSettle();
    expect(find.text('Listening'), findsNothing);
    expect(native.stops, 1);
    expect(container.read(bioPayNfcForegroundSuspendedProvider), isFalse);
  });
}
