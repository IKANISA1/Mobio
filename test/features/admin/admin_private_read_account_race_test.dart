import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/admin_audit_log_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_operational_health_screen.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

const audit = AdminAuditLogItem(
  id: 'audit-a',
  adminName: 'Private actor A',
  action: 'update_role',
  targetType: 'profile',
  targetId: 'private-target-A',
  details: {'private': 'A evidence'},
  createdAt: '2026-09-30T10:00:00Z',
);
const health = AdminOperationalHealthEventItem(
  id: 'health-a',
  service: 'private-service-A',
  component: 'private-component-A',
  status: 'error',
  severity: 'critical',
  message: 'Private A failure',
  userName: 'Private A user',
  ingestOrigin: 'edge',
  createdAt: '2026-09-30T10:00:00Z',
);

class _Admin extends Fake implements AdminService {
  Completer<List<AdminAuditLogItem>>? auditReply;
  Completer<List<AdminOperationalHealthEventItem>>? healthReply;
  int audits = 0, healthReads = 0;
  @override
  Future<List<AdminAuditLogItem>> listAuditLogs({
    String? action,
    String? targetType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    audits++;
    return auditReply?.future ?? [audit];
  }

  @override
  Future<List<AdminOperationalHealthEventItem>> listOperationalHealthEvents({
    String? status,
    String? severity,
    String? service,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    healthReads++;
    return healthReply?.future ?? [health];
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> mount(WidgetTester tester, _Admin service, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminServiceProvider.overrideWithValue(service)],
        child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  for (final isAudit in [true, false]) {
    testWidgets(
      '${isAudit ? 'audit' : 'health'} late private read ignores replaced generation',
      (tester) async {
        final service = _Admin();
        if (isAudit) {
          service.auditReply = Completer();
        } else {
          service.healthReply = Completer();
        }
        await mount(
          tester,
          service,
          isAudit
              ? AdminAuditLogScreen(onBack: () {})
              : AdminOperationalHealthScreen(onBack: () {}),
        );
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh;
        AccountContext.changes.value++;
        if (isAudit) {
          service.auditReply!.complete([audit]);
        } else {
          service.healthReply!.complete([health]);
        }
        await tester.pumpAndSettle();
        expect(find.text('Private actor A'), findsNothing);
        expect(find.text('Private A failure'), findsNothing);
        await refresh();
        await tester.pumpAndSettle();
        expect(isAudit ? service.audits : service.healthReads, 1);
        expect(find.text('Admin session locked'), findsWidgets);
      },
    );
  }
  testWidgets('open root audit detail masks cached payload on replacement', (
    tester,
  ) async {
    final service = _Admin();
    await mount(tester, service, AdminAuditLogScreen(onBack: () {}));
    await tester.pumpAndSettle();
    final open = tester
        .widget<AdminActionChip>(
          find.widgetWithText(AdminActionChip, 'Details').first,
        )
        .onTap!;
    open();
    await tester.pumpAndSettle();
    expect(find.textContaining('A evidence'), findsWidgets);
    AccountContext.changes.value++;
    await tester.pumpAndSettle();
    expect(find.textContaining('A evidence'), findsNothing);
    expect(find.text('Private actor A'), findsNothing);
    open();
    await tester.pumpAndSettle();
    expect(find.textContaining('A evidence'), findsNothing);
    expect(service.audits, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
