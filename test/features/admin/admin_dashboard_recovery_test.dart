import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/admin/application/admin_dashboard_provider.dart';
import 'package:mobi_app/features/admin/application/admin_dashboard_state.dart';
import 'package:mobi_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

class _UnavailableDashboard extends AdminDashboardController {
  int retries = 0;

  @override
  Future<AdminDashboardState> build() async {
    throw StateError('Private backend implementation details');
  }

  @override
  Future<void> refresh() async {
    retries++;
  }
}

void main() {
  testWidgets('dashboard failure gives a safe message and working retry', (
    tester,
  ) async {
    final controller = _UnavailableDashboard();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminDashboardProvider.overrideWith(() => controller)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: AdminDashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Unable to load operations. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Private backend'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(controller.retries, 1);
  });
}
