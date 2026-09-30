import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/application/admin_dashboard_provider.dart';
import 'package:mobi_app/features/admin/application/admin_dashboard_state.dart';
import 'package:mobi_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

class _Dashboard extends AdminDashboardController {
  @override
  Future<AdminDashboardState> build() async =>
      const AdminDashboardState(isLoading: false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [900.0, 1440.0]) {
    for (final action in [
      (label: 'Users', index: 0, kind: 'toolbar'),
      (label: 'Users', index: 1, kind: 'quick action'),
      (label: 'Trips', index: 0, kind: 'quick action'),
      (label: 'Health', index: 0, kind: 'toolbar'),
    ]) {
      final label = action.label;
      for (final stale in [false, true]) {
        testWidgets(
          '${stale ? 'retained' : 'current'} admin $label ${action.kind} at width $width ${stale ? 'cannot use a new generation' : 'remains usable'}',
          (tester) async {
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      const Scaffold(body: AdminDashboardScreen()),
                ),
                GoRoute(
                  path: '/admin/users',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Destination users')),
                ),
                GoRoute(
                  path: '/admin/trips',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Destination trips')),
                ),
                GoRoute(
                  path: '/admin/health',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Destination health')),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.binding.setSurfaceSize(Size(width, 1100));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  adminDashboardProvider.overrideWith(_Dashboard.new),
                ],
                child: MaterialApp.router(
                  theme: AppTheme.darkTheme,
                  routerConfig: router,
                ),
              ),
            );
            await tester.pumpAndSettle();
            final callback = tester
                .widget<AdminActionChip>(
                  find.widgetWithText(AdminActionChip, label).at(action.index),
                )
                .onTap!;
            if (stale) {
              AccountContext.changes.value++;
              await tester.pumpAndSettle();
            }
            callback();
            await tester.pumpAndSettle();
            expect(
              find.text('Destination ${label.toLowerCase()}'),
              stale ? findsNothing : findsOneWidget,
            );
            if (stale) {
              expect(router.routeInformationProvider.value.uri.path, '/');
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
