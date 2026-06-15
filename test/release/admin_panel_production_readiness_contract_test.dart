import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('admin panel production readiness contract', () {
    test('serves the admin PWA on real path URLs', () {
      final main = File('lib/main.dart').readAsStringSync();
      final preparePwa = File(
        'scripts/web/prepare_pwa_bundles.sh',
      ).readAsStringSync();
      final router = File('lib/core/router/app_router.dart').readAsStringSync();

      expect(
        main,
        contains("import 'package:flutter_web_plugins/url_strategy.dart';"),
      );
      expect(main, contains('usePathUrlStrategy();'));
      expect(main, contains("host == 'mobioadmin.ikanisa.com'"));
      expect(main, contains("path.startsWith('/admin')"));
      expect(main, contains("return 'Mobio Admin';"));
      expect(preparePwa, contains('start_url="/admin-auth"'));
      expect(preparePwa, contains(r'site_dir="$output_root/site"'));
      expect(preparePwa, contains(r'cat > "$site_dir/_worker.js"'));
      expect(
        preparePwa,
        contains(r'Response.redirect(`${url.origin}/admin-auth`, 302)'),
      );
      expect(
        preparePwa,
        contains(
          'const response = await serveAsset(env, request, "/__admin_shell");',
        ),
      );
      expect(
        preparePwa,
        contains('headers.set("content-type", "text/html; charset=utf-8");'),
      );
      expect(preparePwa, contains('mobioadmin.ikanisa.com'));
      expect(router, contains("path: '/admin-auth'"));
      expect(router, contains("path: '/admin'"));
      expect(router, contains("path: '/admin/vehicle-types'"));
      expect(router, contains("path: '/admin/subscriptions'"));
      expect(router, contains("path: '/admin/reports'"));
      expect(router, contains("path: '/admin/audit'"));
    });

    test('uses the Dart 3.12 capable Flutter SDK in the admin PWA workflow', () {
      final workflow = File(
        '.github/workflows/cloudflare-pwa.yml',
      ).readAsStringSync();
      final preparePwa = File(
        'scripts/web/prepare_pwa_bundles.sh',
      ).readAsStringSync();
      final verifyPwa = File(
        'scripts/web/verify_pwa_bundles.sh',
      ).readAsStringSync();

      expect(workflow, contains("flutter-version: '3.44.0'"));
      expect(workflow, isNot(contains("flutter-version: '3.38.9'")));
      expect(workflow, contains('Run admin PWA readiness contracts'));
      expect(
        workflow,
        contains(
          'test/release/admin_panel_production_readiness_contract_test.dart',
        ),
      );
      expect(workflow, contains('Verify generated PWA bundles'));
      expect(
        workflow,
        contains('./scripts/web/verify_pwa_bundles.sh build/pwa'),
      );
      expect(workflow, contains('Deploy combined Pages site'));
      expect(workflow, contains('pages deploy build/pwa/site'));
      expect(workflow, isNot(contains('Deploy admin PWA')));
      expect(
        preparePwa,
        contains(
          r'"$repo_root/scripts/web/verify_pwa_bundles.sh" "$output_root"',
        ),
      );
      expect(preparePwa, contains('Prepared combined Pages bundle'));
      expect(verifyPwa, contains('Admin manifest start_url mismatch'));
      expect(
        verifyPwa,
        contains('Admin custom-domain landing redirect missing'),
      );
      expect(
        verifyPwa,
        contains('Redirects must delegate route control to the Pages worker'),
      );
      expect(verifyPwa, contains('Pages worker missing'));
      expect(
        verifyPwa,
        contains(
          'Admin permissions policy must deny camera, geolocation, microphone, and payment',
        ),
      );
    });

    test('keeps admin catalog writes behind audited RPCs', () {
      final service = File(
        'lib/core/services/vehicle_type_service.dart',
      ).readAsStringSync();
      final migration = File(
        'supabase/migrations/20260612120000_admin_catalog_rpc_audit_hardening.sql',
      ).readAsStringSync();

      for (final rpc in [
        'rpc_admin_update_vehicle_type',
        'rpc_admin_set_vehicle_type_active',
        'rpc_admin_set_vehicle_type_countries',
      ]) {
        expect(service, contains(rpc));
        expect(migration, contains('create or replace function public.$rpc'));
        expect(migration, contains('grant execute on function public.$rpc'));
      }

      expect(service, isNot(contains(".from('vehicle_types').update")));
      expect(
        service,
        isNot(contains(".from('vehicle_type_countries').delete")),
      );
      expect(
        service,
        isNot(contains(".from('vehicle_type_countries').insert")),
      );
      expect(
        migration,
        contains("public.has_platform_permission('platform.config.manage')"),
      );
      expect(migration, contains('public.admin_audit_log'));
      expect(migration, contains("'source', 'rpc_admin_update_vehicle_type'"));
      expect(
        migration,
        contains("'source', 'rpc_admin_set_vehicle_type_countries'"),
      );
    });

    test('keeps admin subscription-plan writes behind audited RPCs', () {
      final service = File(
        'lib/core/services/subscription_plan_service.dart',
      ).readAsStringSync();
      final migration = File(
        'supabase/migrations/20260612120000_admin_catalog_rpc_audit_hardening.sql',
      ).readAsStringSync();

      for (final rpc in [
        'rpc_admin_upsert_subscription_plan',
        'rpc_admin_set_subscription_plan_active',
        'rpc_admin_delete_subscription_plan',
      ]) {
        expect(service, contains(rpc));
        expect(migration, contains('create or replace function public.$rpc'));
        expect(migration, contains('grant execute on function public.$rpc'));
      }

      expect(service, isNot(contains(".from('subscription_plans').upsert")));
      expect(service, isNot(contains(".from('subscription_plans').update")));
      expect(service, isNot(contains(".from('subscription_plans').delete")));
      expect(
        migration,
        contains("public.has_platform_permission('platform.config.manage')"),
      );
      expect(migration, contains('public.admin_audit_log'));
      expect(
        migration,
        contains("'source', 'rpc_admin_upsert_subscription_plan'"),
      );
      expect(
        migration,
        contains("'source', 'rpc_admin_set_subscription_plan_active'"),
      );
      expect(
        migration,
        contains("'source', 'rpc_admin_delete_subscription_plan'"),
      );
    });

    test('admin workspaces use backend pagination for scalable queues', () {
      final usersProvider = File(
        'lib/features/admin/providers/admin_users_provider.dart',
      ).readAsStringSync();
      final usersState = File(
        'lib/features/admin/models/admin_users_state.dart',
      ).readAsStringSync();
      final usersScreen = File(
        'lib/features/admin/admin_users_screen.dart',
      ).readAsStringSync();
      final reports = File(
        'lib/features/admin/admin_reports_screen.dart',
      ).readAsStringSync();
      final audit = File(
        'lib/features/admin/admin_audit_log_screen.dart',
      ).readAsStringSync();
      final health = File(
        'lib/features/admin/admin_operational_health_screen.dart',
      ).readAsStringSync();
      final trips = File(
        'lib/features/admin/admin_trips_screen.dart',
      ).readAsStringSync();
      final tripService = File(
        'lib/core/services/admin/admin_trip_service.dart',
      ).readAsStringSync();
      final tripMigration = File(
        'supabase/migrations/20260615123000_admin_trip_search_pagination.sql',
      ).readAsStringSync();

      for (final source in [reports, audit, health, trips]) {
        expect(source, contains('limit: _rowsPerPage + 1'));
        expect(source, contains('offset: _page * _rowsPerPage'));
        expect(source, isNot(contains('limit: 100')));
        expect(source, isNot(contains('limit: 120')));
        expect(source, isNot(contains('limit: 200')));
      }

      expect(usersProvider, contains('offset: safePage * safeRowsPerPage'));
      expect(usersProvider, contains('limit: safeRowsPerPage + 1'));
      expect(usersState, contains('hasNextPage'));
      expect(usersState, contains('paginationTotal'));
      expect(usersScreen, isNot(contains('_pageUsers')));
      expect(reports, isNot(contains('_pagedReports')));
      expect(audit, contains("action: _actionFilter == 'all' ? null"));
      expect(audit, contains("targetType: _targetFilter == 'all' ? null"));
      expect(health, contains("status: _statusFilter == 'all' ? null"));
      expect(health, contains("severity: _severityFilter == 'all' ? null"));
      expect(health, contains("service: _serviceFilter == 'all' ? null"));
      expect(trips, contains('search: _searchQuery'));
      expect(trips, isNot(contains('Reasonable cap for live moderating')));
      expect(tripService, contains("'p_search': search"));
      expect(tripMigration, contains('p_search text default null'));
      expect(
        tripMigration,
        contains(
          'drop function if exists public.rpc_admin_list_trips(text, text, integer, integer)',
        ),
      );
      expect(tripMigration, contains('p.member_id ilike'));
    });

    test('keeps active admin workspace aligned with design.md', () {
      final design = File('design.md').readAsStringSync();
      final adminUi = File(
        'lib/features/admin/widgets/admin_ui.dart',
      ).readAsStringSync();
      final reports = File(
        'lib/features/admin/admin_reports_screen.dart',
      ).readAsStringSync();
      final audit = File(
        'lib/features/admin/admin_audit_log_screen.dart',
      ).readAsStringSync();

      expect(design, contains('reduce headline intensity'));
      expect(design, contains('use the same chip and spacing language'));
      expect(adminUi, contains('style: AppTypography.titleLg.copyWith'));
      expect(adminUi, contains('style: AppTypography.titleMd.copyWith'));
      expect(adminUi, contains('fontWeight: FontWeight.w700'));
      expect(adminUi, contains('AdminFilterChip'));
      expect(adminUi, isNot(contains("label: 'Finance'")));
      expect(adminUi, isNot(contains("route: '/admin/finance'")));
      expect(reports, contains('_showReportDetailSheet'));
      expect(reports, contains('SelectableText'));
      expect(audit, contains('_showAuditDetailSheet'));
      expect(audit, contains('JsonEncoder.withIndent'));
    });
  });
}
