import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('report and block production contract', () {
    late final String migration;
    late final String assertions;
    late final String chatService;
    late final String chatScreen;
    late final String adminService;
    late final String adminRouter;
    late final String adminUi;
    late final String adminReportsScreen;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260501133000_user_reports_blocks.sql',
      ).readAsStringSync();
      assertions = File(
        'supabase/tests/backend_security_assertions.sql',
      ).readAsStringSync();
      chatService = File(
        'lib/core/services/chat_service.dart',
      ).readAsStringSync();
      chatScreen = File(
        'lib/features/chat/chat_screen.dart',
      ).readAsStringSync();
      adminService = File(
        'lib/core/services/admin_service.dart',
      ).readAsStringSync();
      adminRouter = File('lib/core/router/app_router.dart').readAsStringSync();
      adminUi = File(
        'lib/features/admin/widgets/admin_ui.dart',
      ).readAsStringSync();
      adminReportsScreen = File(
        'lib/features/admin/admin_reports_screen.dart',
      ).readAsStringSync();
    });

    test('migration creates scoped report and block tables', () {
      expect(
        migration,
        contains('create table if not exists public.user_blocks'),
      );
      expect(
        migration,
        contains('create table if not exists public.user_reports'),
      );
      expect(migration, contains('organization_id uuid not null'));
      expect(migration, contains('constraint user_blocks_no_self_block'));
      expect(migration, contains('constraint user_reports_no_self_report'));
    });

    test('clients use RPCs instead of direct report/block writes', () {
      expect(migration, contains('revoke all on public.user_blocks'));
      expect(migration, contains('revoke all on public.user_reports'));
      expect(migration, contains('rpc_block_user'));
      expect(migration, contains('rpc_unblock_user'));
      expect(migration, contains('rpc_report_user'));
      expect(migration, contains('rpc_is_user_blocked'));
      expect(migration, contains('rpc_admin_review_user_report'));
    });

    test('chat creation and message insert are block-aware', () {
      expect(migration, contains('rpc_get_or_create_chat_conversation'));
      expect(migration, contains('message = \'USER_BLOCKED\''));
      expect(migration, contains('create policy chat_messages_insert_sender'));
      expect(migration, contains('from public.user_blocks block_row'));
    });

    test('linked backend assertions cover report/block invariants', () {
      expect(assertions, contains('report/block foundation table missing'));
      expect(
        assertions,
        contains('report/block client direct write grant still exists'),
      );
      expect(assertions, contains('report/block RPC missing'));
      expect(
        assertions,
        contains('chat conversation RPC does not enforce user blocks'),
      );
      expect(
        assertions,
        contains('chat insert policy does not enforce user blocks'),
      );
    });

    test(
      'Flutter chat exposes report and block actions through ChatService',
      () {
        expect(chatService, contains('Future<void> blockUser'));
        expect(chatService, contains('Future<void> unblockUser'));
        expect(chatService, contains('Future<void> reportUser'));
        expect(chatService, contains('Future<bool> isPeerBlocked'));
        expect(chatScreen, contains('Report user'));
        expect(chatScreen, contains('Block user'));
        expect(chatScreen, contains('Messaging is unavailable'));
      },
    );

    test('admin report moderation is visible in the active workspace', () {
      expect(
        adminService,
        contains('Future<List<AdminUserReportItem>> listUserReports'),
      );
      expect(adminService, contains('Future<void> reviewUserReport'));
      expect(adminRouter, contains("path: '/admin/reports'"));
      expect(adminRouter, contains('AdminReportsScreen'));
      expect(adminUi, contains('AdminWorkspaceTab.reports'));
      expect(adminUi, contains("route: '/admin/reports'"));
      expect(adminReportsScreen, contains('listUserReports'));
      expect(adminReportsScreen, contains('reviewUserReport'));
      expect(adminReportsScreen, contains('AdminWorkspaceTab.reports'));
      expect(adminReportsScreen, contains('Reviewing'));
      expect(adminReportsScreen, contains('Resolve'));
      expect(adminReportsScreen, contains('Dismiss'));
    });
  });
}
