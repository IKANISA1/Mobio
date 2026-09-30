import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:mobi_app/features/profile/presentation/profile_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_feature_tile.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/profile.dart';

class _Profiles extends Fake implements ProfileService {
  int reads = 0;
  Future<Profile?> Function() read = () async =>
      const Profile(id: 'owner', memberId: '004321');
  @override
  Future<Profile?> getMyProfile() {
    reads++;
    return read();
  }
}

class _Face extends Fake implements BioPayFaceService {
  int reads = 0;
  @override
  Future<BioPayEnrollmentStatus> enrollmentStatus() async {
    reads++;
    return const BioPayEnrollmentStatus(status: 'not_started');
  }
}

void main() {
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  late _Profiles profiles;
  late _Face face;
  late Map<String, int> calls;
  late List<String> launches;
  var generation = 0;
  Future<bool> Function(String) launch = (_) async => true;
  Future<void> Function()? enroll;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    generation = 0;
    profiles = _Profiles();
    face = _Face();
    calls = {};
    launches = [];
    enroll = null;
    launch = (_) async => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
          if (call.method != 'launch') return true;
          final url = (call.arguments as Map)['url'] as String;
          launches.add(url);
          return launch(url);
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null);
  });

  void record(String action) =>
      calls.update(action, (count) => count + 1, ifAbsent: () => 1);
  Future<void> mount(
    WidgetTester tester, {
    bool admin = false,
    bool nativeShare = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileServiceProvider.overrideWithValue(profiles),
          biopayFaceServiceProvider.overrideWithValue(face),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ProfileScreen.test(
              isDarkMode: true,
              onDarkModeChanged: (_) => record('theme'),
              onEditProfile: () => record('edit'),
              onWallet: () => record('wallet'),
              onMobioPlus: () => record('plus'),
              onBioPayEnroll: () async {
                record('enroll');
                await enroll?.call();
              },
              onNfcWriteCard: () => record('nfc'),
              onInviteAndEarn: nativeShare ? null : () => record('invite'),
              onSignOut: () async => record('signout'),
              onAdminGateway: () => record('admin'),
              onExitAdmin: admin ? () => record('exitAdmin') : null,
              captureAccount: () =>
                  AccountSnapshot('owner', 'session-$generation', generation),
              isCurrent: (account) => account.generation == generation,
            ),
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

  VoidCallback row(WidgetTester tester, String title) => tester
      .widget<InkWell>(
        find
            .ancestor(of: find.text(title), matching: find.byType(InkWell))
            .first,
      )
      .onTap!;
  VoidCallback tile(WidgetTester tester, String title) => tester
      .widget<MobiFeatureTile>(find.widgetWithText(MobiFeatureTile, title))
      .onTap!;
  void replaceAccount() {
    generation++;
    AccountContext.changes.value++;
  }

  testWidgets('retained Profile actions cannot acquire a replacement session', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    final callbacks = [
      row(tester, 'Edit Profile'),
      row(tester, 'Wallet'),
      row(tester, 'Mobio Plus'),
      row(tester, 'Register my face'),
      row(tester, 'Write NFC Card'),
      tile(tester, 'Theme'),
      tile(tester, 'Invite and Earn'),
      tile(tester, 'Sign out'),
      tile(tester, 'Request account deletion'),
      tile(tester, 'Support'),
      tile(tester, 'Privacy Policy'),
      tile(tester, 'Terms and Conditions'),
      tester.widget<TappableIconButton>(find.byType(TappableIconButton)).onTap!,
    ];
    replaceAccount();
    await tester.pumpAndSettle();
    for (final callback in callbacks) {
      callback();
    }
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(launches, isEmpty);
    expect(profiles.reads, 2);
    expect(face.reads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current Profile actions remain usable after replacement', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    replaceAccount();
    await tester.pumpAndSettle();
    for (final title in [
      'Edit Profile',
      'Wallet',
      'Mobio Plus',
      'Write NFC Card',
    ]) {
      row(tester, title)();
    }
    for (final title in ['Theme', 'Invite and Earn', 'Sign out']) {
      tile(tester, title)();
    }
    await tester.pumpAndSettle();
    expect(calls, {
      'edit': 1,
      'wallet': 1,
      'plus': 1,
      'nfc': 1,
      'theme': 1,
      'invite': 1,
      'signout': 1,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained Exit Admin cannot sign out a replacement session', (
    tester,
  ) async {
    await mount(tester, admin: true);
    await tester.pumpAndSettle();
    final oldExit = tile(tester, 'Exit Admin');
    replaceAccount();
    await tester.pumpAndSettle();
    oldExit();
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    tile(tester, 'Exit Admin')();
    await tester.pumpAndSettle();
    expect(calls, {'exitAdmin': 1});
  });

  testWidgets(
    'late Profile response cannot start a Face read in a new account',
    (tester) async {
      final oldRead = Completer<Profile?>();
      profiles.read = () => oldRead.future;
      await mount(tester);
      expect(face.reads, 0);
      profiles.read = () async =>
          const Profile(id: 'owner', memberId: '009876');
      replaceAccount();
      await tester.pumpAndSettle();
      expect(face.reads, 1);
      expect(find.text('009876'), findsWidgets);
      oldRead.complete(const Profile(id: 'owner', memberId: '004321'));
      await tester.pumpAndSettle();
      expect(face.reads, 1);
      expect(find.text('004321'), findsNothing);
      expect(find.text('009876'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late enrollment navigation cannot refresh a replacement Profile',
    (tester) async {
      final returned = Completer<void>();
      enroll = () => returned.future;
      await mount(tester);
      await tester.pumpAndSettle();
      row(tester, 'Register my face')();
      await tester.pump();
      expect(calls, {'enroll': 1});
      replaceAccount();
      await tester.pumpAndSettle();
      expect(profiles.reads, 2);
      returned.complete();
      await tester.pumpAndSettle();
      expect(profiles.reads, 2);
      expect(face.reads, 2);
    },
  );

  testWidgets('current enrollment return refreshes its Profile once', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    row(tester, 'Register my face')();
    await tester.pumpAndSettle();
    expect(calls, {'enroll': 1});
    expect(profiles.reads, 2);
    expect(face.reads, 2);
  });

  testWidgets(
    'late external launch cannot open fallback after account change',
    (tester) async {
      final firstLaunch = Completer<bool>();
      launch = (_) => firstLaunch.future;
      await mount(tester, nativeShare: true);
      await tester.pumpAndSettle();
      tile(tester, 'Invite and Earn')();
      await tester.pump();
      expect(launches, hasLength(1));
      expect(launches.single, startsWith('market:'));
      replaceAccount();
      await tester.pumpAndSettle();
      firstLaunch.complete(false);
      await tester.pumpAndSettle();
      expect(launches, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('current external launch can use its supported fallback', (
    tester,
  ) async {
    launch = (url) async => !url.startsWith('market:');
    await mount(tester, nativeShare: true);
    await tester.pumpAndSettle();
    tile(tester, 'Invite and Earn')();
    await tester.pumpAndSettle();
    expect(launches, hasLength(2));
    expect(launches.first, startsWith('market:'));
    expect(launches.last, startsWith('https:'));
    expect(find.byType(SnackBar), findsNothing);
  });
}
