import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/admin/models/admin_users_state.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';

void main() {
  testWidgets('AdminPaginationBar reports range and changes page', (
    tester,
  ) async {
    int? nextPage;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AdminPaginationBar(
            totalItems: 60,
            page: 0,
            rowsPerPage: 25,
            onPageChanged: (page) => nextPage = page,
          ),
        ),
      ),
    );

    expect(find.text('1-25 of 60'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.chevronRight));
    await tester.pump();

    expect(nextPage, 1);
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
}
