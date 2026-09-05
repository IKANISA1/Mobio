import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

void main() {
  testWidgets('AdminPaginationBar reports range and changes page', (
    tester,
  ) async {
    int? nextPage;
    int? rowsPerPage;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AdminPaginationBar(
            totalItems: 60,
            page: 0,
            rowsPerPage: 25,
            onPageChanged: (page) => nextPage = page,
            onRowsPerPageChanged: (rows) => rowsPerPage = rows,
          ),
        ),
      ),
    );

    expect(find.text('1-25 of 60'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Previous page'), findsOneWidget);
    expect(find.bySemanticsLabel('Next page'), findsOneWidget);
    semantics.dispose();

    await tester.tap(find.byIcon(LucideIcons.chevronRight));
    await tester.pump();

    expect(nextPage, 1);

    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50').last);
    await tester.pumpAndSettle();

    expect(rowsPerPage, 50);
  });

  testWidgets('AdminSearchField clears campaign search text', (tester) async {
    final controller = TextEditingController(text: 'promo');
    addTearDown(controller.dispose);
    String? changed;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AdminSearchField(
            controller: controller,
            hintText: 'Search title, organization, actor, campaign ID',
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );

    expect(find.text('promo'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(changed, isEmpty);
  });

  testWidgets('AdminSortMenu emits selected sort value', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AdminSortMenu(
            value: 'newest',
            options: const [
              AdminSortOption(
                value: 'newest',
                label: 'Newest',
                icon: LucideIcons.clock,
              ),
              AdminSortOption(
                value: 'status',
                label: 'Status',
                icon: LucideIcons.activity,
              ),
            ],
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Status').last);
    await tester.pumpAndSettle();

    expect(selected, 'status');
  });

  test('AdminUsersState stores operational table controls', () {
    const state = AdminUsersState();

    final updated = state.copyWith(sortKey: 'newest', page: 2, rowsPerPage: 50);

    expect(updated.sortKey, 'newest');
    expect(updated.page, 2);
    expect(updated.rowsPerPage, 50);
  });

  test('AdminOperationalHealthEventItem parses backend rows', () {
    final item = AdminOperationalHealthEventItem.fromJson({
      'id': 'event-1',
      'service': 'edge',
      'component': 'verify-otp',
      'status': 'error',
      'severity': 'critical',
      'issue_code': 'otp_delivery_failed',
      'message': 'Delivery failed',
      'function_name': 'verify-otp',
      'user_name': 'Ops Admin',
      'metadata': {'retryable': true},
      'ingest_origin': 'system',
      'created_at': '2026-05-06T10:00:00Z',
    });

    expect(item.isError, isTrue);
    expect(item.service, 'edge');
    expect(item.metadata['retryable'], isTrue);
  });

  testWidgets('AdminWorkspaceFrame exposes Reports and Health tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AdminWorkspaceFrame(
            title: 'Reports',
            subtitle: 'Chat safety and user blocks.',
            currentTab: AdminWorkspaceTab.reports,
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text('Reports'), findsWidgets);
    expect(find.byIcon(LucideIcons.flag), findsWidgets);
    expect(find.text('Health'), findsWidgets);
    expect(find.byIcon(LucideIcons.activity), findsWidgets);
  });
}
