import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/features/admin/application/admin_users_provider.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';
import 'package:mobi_app/features/admin/presentation/admin_users_screen.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_bulk_actions.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

class _OutcomeController extends AdminUsersController {
  _OutcomeController(this.outcome);

  final AdminRoleUpdateResult outcome;

  @override
  AdminUsersState build() => const AdminUsersState(
    selectedIds: {'100001', '100002', '100003'},
    isLoading: false,
  );

  @override
  Future<AdminRoleUpdateResult> applyRoleToSelected(String role) async =>
      outcome;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final (outcome, message) in [
    (
      const AdminRoleUpdateResult(
        updatedCount: 1,
        failedIds: {'100002'},
        skippedCount: 1,
      ),
      'Updated 1 user. 1 failed. 1 skipped.',
    ),
    (
      const AdminRoleUpdateResult(
        updatedCount: 0,
        failedIds: {},
        skippedCount: 3,
      ),
      'No users updated. 3 skipped.',
    ),
  ]) {
    testWidgets('directory reports actual bulk outcome: $message', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminUsersProvider.overrideWith(() => _OutcomeController(outcome)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AdminUsersScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final actions = tester.widget<AdminUserBulkActions>(
        find.byType(AdminUserBulkActions),
      );
      actions.onApplyRole('driver');
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.text('Updated 3 users.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
