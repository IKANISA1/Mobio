import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/features/biopay/biopay_screen.dart';
import 'package:mobi_app/features/bookings/bookings_screen.dart';
import 'package:mobi_app/features/bookings/schedule_trip_screen.dart';
import 'package:mobi_app/features/chat/chat_screen.dart';
import 'package:mobi_app/features/home/home_screen.dart';
import 'package:mobi_app/features/nearby/nearby_screen.dart';
import 'package:mobi_app/features/profile/profile_screen.dart';

import '../../helpers/mobile_scanner_test_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    installMobileScannerTestChannel();
    final loader = FontLoader('packages/lucide_icons/Lucide')
      ..addFont(rootBundle.load('packages/lucide_icons/assets/lucide.ttf'));
    await loader.load();
  });

  tearDownAll(uninstallMobileScannerTestChannel);

  const compact = Size(390, 844);
  const large = Size(430, 932);

  final cases = <_GoldenCase>[
    _GoldenCase(
      name: 'home',
      builder: () => HomeScreen(
        mode: 'passenger',
        onModeChanged: (_) {},
        onChat: (_) {},
        onViewNearby: () {},
        onViewBookings: () {},
        onSchedule: () {},
      ),
    ),
    _GoldenCase(
      name: 'bookings',
      builder: () => BookingsScreen(
        mode: 'passenger',
        onModeChanged: (_) {},
        onSchedule: () {},
        onTripDetails: (_) {},
      ),
    ),
    _GoldenCase(
      name: 'schedule',
      builder: () => ScheduleTripScreen(
        mode: 'passenger',
        onModeChanged: (_) {},
        onBack: () {},
      ),
    ),
    _GoldenCase(
      name: 'profile',
      builder: () => ProfileScreen(
        isDarkMode: true,
        onDarkModeChanged: (_) {},
        onEditProfile: () {},
        onAdminGateway: () {},
      ),
    ),
    _GoldenCase(
      name: 'chat',
      builder: () => TripChatScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'nearby',
      builder: () => NearbyScreen(onChat: (_) {}, onTripDetails: (_) {}),
    ),
    _GoldenCase(
      name: 'biopay_home',
      builder: () =>
          BioPayScreen(onQr: () {}, onScan: () {}, onFace: () {}, onNfc: () {}),
    ),
    _GoldenCase(
      name: 'biopay_qr',
      builder: () => BioPayQrScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_scan',
      builder: () => BioPayScanScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_face_scan',
      builder: () => BioPayFaceScanScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_face_enroll',
      builder: () => BioPayFaceEnrollScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_nfc',
      builder: () => BioPayNfcScreen(onBack: () {}),
    ),
    const _GoldenCase(name: 'admin', builder: _adminPreview),
  ];

  for (final size in [compact, large]) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}';

    group('Revolut-reference golden $suffix', () {
      for (final item in cases) {
        testWidgets(item.name, (tester) async {
          await _pumpGolden(tester, size, item.builder());

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/revolut/${item.name}_$suffix.png'),
          );
        });
      }
    });
  }
}

Future<void> _pumpGolden(WidgetTester tester, Size size, Widget child) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: true,
            textScaler: TextScaler.noScaling,
          ),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _adminPreview() {
  return AdminWorkspaceFrame(
    title: 'Operations',
    subtitle: 'Live platform controls',
    currentTab: AdminWorkspaceTab.overview,
    actions: const [
      AdminActionChip(icon: LucideIcons.refreshCw, label: 'Refresh'),
    ],
    child: ListView(
      padding: AdminLayoutTokens.pagePadding,
      children: const [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AdminMetricCard(
              label: 'Open reports',
              value: '12',
              icon: LucideIcons.flag,
            ),
            AdminMetricCard(
              label: 'Active trips',
              value: '48',
              icon: LucideIcons.navigation,
            ),
            AdminMetricCard(
              label: 'Live users',
              value: '214',
              icon: LucideIcons.users,
            ),
          ],
        ),
        SizedBox(height: 20),
        AdminEmptyState(
          icon: LucideIcons.shieldCheck,
          title: 'No critical alerts',
          message: 'Ops review is clear.',
        ),
      ],
    ),
  );
}

class _GoldenCase {
  final String name;
  final Widget Function() builder;

  const _GoldenCase({required this.name, required this.builder});
}
