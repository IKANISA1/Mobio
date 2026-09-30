import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/driver_plus_service.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:mobi_app/features/profile/data/subscription_plan_service.dart';
import 'package:mobi_app/features/profile/data/wallet_service.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/features/profile/presentation/driver_plus_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/profile.dart';
import 'package:mobi_shared_types/models/subscription_plan_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profiles extends Fake implements ProfileService {
  int reads = 0;
  Future<Profile?> Function() read = () async => const Profile(
    id: 'user',
    role: 'driver',
    vehicleType: 'cab',
    isDriver: true,
  );
  @override
  Future<Profile?> getMyProfile() {
    reads++;
    return read();
  }
}

class _Plus extends Fake implements DriverPlusService {
  final requests = <Completer<DriverSubscriptionPaymentRequest>>[];
  final keys = <String>[];
  int statusReads = 0;
  int launches = 0;
  int records = 0;
  @override
  Future<DriverPlusStatus> getStatus({String? driverId}) async {
    statusReads++;
    return const DriverPlusStatus(
      driverId: 'user',
      vehicleTypeId: 'cab',
      requiresPlus: true,
      isFreeForever: false,
      hasActiveSubscription: false,
      canReceiveNewRequest: true,
      canReply: false,
      canReadMessages: true,
      canShowWhatsapp: false,
      upgradeRequired: true,
      usedToday: 0,
      usedTotal: 0,
      remainingToday: 1,
      remainingTotal: 1,
    );
  }

  @override
  Future<DriverSubscriptionPaymentRequest> startSubscription({
    required String planId,
    required String paymentMethod,
    required String clientRequestId,
  }) {
    keys.add(clientRequestId);
    final result = Completer<DriverSubscriptionPaymentRequest>();
    requests.add(result);
    return result.future;
  }

  @override
  Future<bool> launchUssd(String ussdCode) async {
    launches++;
    return true;
  }

  @override
  Future<void> recordDialerOpened(String requestId) async {
    records++;
  }
}

class _Plans extends Fake implements SubscriptionPlanService {
  @override
  Future<List<SubscriptionPlanModel>> getAvailablePlans(
    String vehicleTypeId,
    String countryId,
  ) async => const [
    SubscriptionPlanModel(
      id: 'daily',
      vehicleTypeId: 'cab',
      countryId: 'RW',
      intervalDays: 1,
      price: 1000,
    ),
  ];
}

class _Wallet extends Fake implements WalletService {
  @override
  Future<WalletSummary> getSummary() async => const WalletSummary(
    profileId: 'user',
    balanceTokens: 2000,
    rwfEquivalent: 2000,
    lifetimeEarnedTokens: 2000,
    lifetimeSentTokens: 0,
    lifetimeReceivedTokens: 0,
    successfulReferrals: 0,
  );
}

DriverSubscriptionPaymentRequest _request({String status = 'pending'}) =>
    DriverSubscriptionPaymentRequest(
      id: 'request',
      status: status,
      paymentMethod: 'momo_ussd',
      referenceCode: 'reference',
      amountTokens: 1000,
      amountRwf: 1000,
      currency: 'RWF',
      momoPayCode: '123456',
      ussdCode: '*182#',
      expiresAt: DateTime(2030),
    );

void main() {
  late _Profiles profiles;
  late _Plus plus;
  var generation = 0;
  AccountSnapshot capture() =>
      AccountSnapshot('user', 'session-$generation', generation);
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileServiceProvider.overrideWithValue(profiles),
          driverPlusServiceProvider.overrideWithValue(plus),
          subscriptionPlanServiceProvider.overrideWithValue(_Plans()),
          walletServiceProvider.overrideWithValue(_Wallet()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: DriverPlusScreen.test(
            onBack: () {},
            captureAccount: capture,
            isCurrent: (snapshot) => snapshot.generation == generation,
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pump();
  }

  setUp(() {
    generation = 0;
    profiles = _Profiles();
    plus = _Plus();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  for (final kind in ['toolbar', 'pull', 'retry']) {
    testWidgets('retained Driver Plus $kind cannot read a replaced session', (
      tester,
    ) async {
      if (kind == 'retry') {
        profiles.read = () async => throw StateError('load failed');
      }
      await pump(tester);
      await tester.pumpAndSettle();
      Future<void> Function() old;
      if (kind == 'pull') {
        old = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh;
      } else {
        final callback = kind == 'toolbar'
            ? tester
                  .widget<IconButton>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is IconButton && widget.tooltip == 'Refresh',
                    ),
                  )
                  .onPressed!
            : tester
                  .widget<MobiErrorState>(find.byType(MobiErrorState))
                  .onRetry!;
        old = () async {
          callback();
        };
      }
      profiles.read = () async => const Profile(
        id: 'user',
        role: 'driver',
        vehicleType: 'cab',
        isDriver: true,
      );
      generation++;
      AccountContext.changes.value++;
      await tester.pumpAndSettle();
      final reads = profiles.reads;
      await old();
      await tester.pumpAndSettle();
      expect(profiles.reads, reads);
    });
  }
  testWidgets('current Driver Plus refresh remains functional', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    final before = profiles.reads;
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Refresh',
      ),
    );
    await tester.pumpAndSettle();
    expect(profiles.reads, before + 1);
    expect(plus.statusReads, 2);
  });
  testWidgets(
    'late profile cannot start a follow-up read under a new session',
    (tester) async {
      final oldProfile = Completer<Profile?>();
      profiles.read = () => oldProfile.future;
      await pump(tester);
      generation++;
      profiles.read = () async => const Profile(
        id: 'user',
        role: 'driver',
        vehicleType: 'bus',
        isDriver: true,
      );
      AccountContext.changes.value++;
      await tester.pump();
      oldProfile.complete(
        const Profile(
          id: 'user',
          role: 'driver',
          vehicleType: 'cab',
          isDriver: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(plus.statusReads, 1);
      expect(find.text('BUS'), findsOneWidget);
      expect(find.text('CAB'), findsNothing);
    },
  );

  testWidgets(
    'late subscription response retains its key and cannot launch after re-login',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay with MoMo'));
      await tester.pumpAndSettle();
      expect(plus.requests, hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      final oldKey = prefs.getString(
        'mobio.pending.driver-plus:user:session-0:daily:momo_ussd',
      );
      expect(oldKey, plus.keys.single);
      generation++;
      AccountContext.changes.value++;
      await tester.pumpAndSettle();
      plus.requests.first.complete(_request(status: 'failed'));
      await tester.pumpAndSettle();
      expect(plus.launches, 0);
      expect(plus.records, 0);
      expect(
        prefs.getString(
          'mobio.pending.driver-plus:user:session-0:daily:momo_ussd',
        ),
        oldKey,
      );
      await tester.tap(find.text('Pay with MoMo'));
      await tester.pumpAndSettle();
      expect(plus.requests, hasLength(2));
      expect(plus.keys.last, isNot(oldKey));
      expect(
        prefs.getString(
          'mobio.pending.driver-plus:user:session-1:daily:momo_ussd',
        ),
        plus.keys.last,
      );
      plus.requests.last.complete(_request());
      await tester.pumpAndSettle();
      expect(plus.launches, 1);
      expect(plus.records, 1);
    },
  );
}
