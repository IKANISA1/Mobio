import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/application/admin_dashboard_provider.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_app/features/notifications/data/notification_service.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

AdminDashboardStats stats(int users) => AdminDashboardStats(
  totalUsers: users,
  activeDrivers: 1,
  activePassengers: 1,
  totalTrips: 1,
  activeTrips: 1,
  cancelledTrips: 0,
);

class _Admin extends Fake implements AdminService {
  final writes = <String>[];
  Completer<AdminPlatformSettings>? firstWrite;
  Completer<AdminDashboardStats>? firstLoad;
  int reads = 0;
  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    reads++;
    return reads == 1 && firstLoad != null ? firstLoad!.future : stats(200);
  }

  @override
  Future<List<AdminWhatsappNumberItem>> listWhatsappAdminNumbers() async => [];
  @override
  Future<List<AdminAccessAttemptItem>> listAdminAccessAttempts({
    int limit = 20,
  }) async => [];
  @override
  Future<List<AdminNotificationItem>> listAdminNotifications({
    int limit = 12,
  }) async => [];
  @override
  Future<AdminPlatformSettings> getPlatformSettings() async =>
      const AdminPlatformSettings(
        insuranceAgentWhatsappE164: '+250788123456',
        tokenRedemptionAdminMemberId: '123456',
      );
  @override
  Future<List<AdminTokenRedemptionItem>> listTokenRedemptions({
    String status = 'pending',
    int limit = 8,
  }) async => [];
  @override
  Future<AdminPlatformSettings> updatePlatformSetting({
    required String key,
    required String value,
  }) async {
    writes.add(key);
    return writes.length == 1 && firstWrite != null
        ? firstWrite!.future
        : const AdminPlatformSettings();
  }
}

class _Notifications extends Fake implements NotificationService {
  @override
  Stream<AppNotification> get onNotification => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Admin admin;
  late ProviderContainer container;
  var generation = 0;
  var owner = 'owner-a';
  setUp(() {
    generation = 0;
    owner = 'owner-a';
    admin = _Admin();
    container = ProviderContainer(
      overrides: [
        adminServiceProvider.overrideWithValue(admin),
        notificationServiceProvider.overrideWithValue(_Notifications()),
        adminDashboardProvider.overrideWith(
          () => AdminDashboardController.test(
            captureAccount: () =>
                AccountSnapshot(owner, 'session-$generation', generation),
          ),
        ),
      ],
    )..listen(adminDashboardProvider, (_, _) {});
    addTearDown(container.dispose);
  });
  void replace({bool switchOwner = false}) {
    generation++;
    if (switchOwner) owner = 'owner-b';
    AccountContext.changes.value++;
  }

  test(
    'same-owner replacement stops platform second write and old refresh',
    () async {
      await container.read(adminDashboardProvider.future);
      admin.firstWrite = Completer();
      final controller = container.read(adminDashboardProvider.notifier);
      final save = controller.savePlatformSettings(
        insuranceAgentWhatsappE164: '+250788123456',
        tokenRedemptionAdminMemberId: '123456',
      );
      await Future<void>.delayed(Duration.zero);
      expect(admin.writes, ['insurance_agent_whatsapp_e164']);
      replace();
      admin.firstWrite!.complete(const AdminPlatformSettings());
      await save;
      await container.read(adminDashboardProvider.future);
      expect(admin.writes, ['insurance_agent_whatsapp_e164']);
      expect(admin.reads, 2);
    },
  );
  test('A-to-B late dashboard cannot restore private A rows', () async {
    admin.firstLoad = Completer();
    final old = container.read(adminDashboardProvider.future);
    final observed = old.then<void>((_) {}, onError: (Object _) {});
    await Future<void>.delayed(Duration.zero);
    replace(switchOwner: true);
    expect(container.read(adminDashboardProvider).value?.stats, isNull);
    final next = await container.read(adminDashboardProvider.future);
    expect(next.stats?.totalUsers, 200);
    admin.firstLoad!.complete(stats(111));
    await observed;
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(adminDashboardProvider).value?.stats?.totalUsers,
      200,
    );
  });
  testWidgets('root settings sheet masks fields and rejects retained save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: AdminDashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final edit = find.widgetWithText(AdminActionChip, 'Edit').first;
    tester.widget<AdminActionChip>(edit).onTap!();
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Redemption admin wallet ID',
      ),
      findsOneWidget,
    );
    final save = tester
        .widget<AdminActionChip>(find.widgetWithText(AdminActionChip, 'Save'))
        .onTap!;
    replace();
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Redemption admin wallet ID',
      ),
      findsNothing,
    );
    save();
    await tester.pumpAndSettle();
    expect(admin.writes, isEmpty);
    expect(find.text('Platform settings updated.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
