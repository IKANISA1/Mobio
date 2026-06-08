import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mobile UI readiness contract', () {
    late final String appShell;
    late final String router;
    late final String scheduleScreen;
    late final String scheduleProvider;
    late final String profileConsent;
    late final String editProfileScreen;
    late final String nearbyScreen;
    late final String permissionDialog;
    late final String chatScreen;
    late final String chatModerationSheet;
    late final String adminReports;
    late final String adminAudit;

    setUpAll(() {
      appShell = File('lib/app.dart').readAsStringSync();
      router = File('lib/core/router/app_router.dart').readAsStringSync();
      scheduleScreen = File(
        'lib/features/bookings/schedule_trip_screen.dart',
      ).readAsStringSync();
      scheduleProvider = File(
        'lib/features/bookings/providers/schedule_trip_provider.dart',
      ).readAsStringSync();
      profileConsent = File(
        'lib/features/profile/widgets/profile_notification_consent_section.dart',
      ).readAsStringSync();
      editProfileScreen = File(
        'lib/features/profile/edit_profile_screen.dart',
      ).readAsStringSync();
      nearbyScreen = File(
        'lib/features/nearby/nearby_screen.dart',
      ).readAsStringSync();
      permissionDialog = File(
        'lib/shared/widgets/permission_access_dialog.dart',
      ).readAsStringSync();
      chatScreen = File(
        'lib/features/chat/chat_screen.dart',
      ).readAsStringSync();
      chatModerationSheet = File(
        'lib/features/chat/widgets/chat_moderation_sheet.dart',
      ).readAsStringSync();
      adminReports = File(
        'lib/features/admin/admin_reports_screen.dart',
      ).readAsStringSync();
      adminAudit = File(
        'lib/features/admin/admin_audit_log_screen.dart',
      ).readAsStringSync();
    });

    test('shell adapts navigation for tablet and large-width layouts', () {
      expect(appShell, contains('MediaQuery.sizeOf(context).width >= 720'));
      expect(appShell, contains('NavigationRail'));
      expect(appShell, contains('MobiNavigationRail'));
      expect(appShell, contains('selectedIndex: currentIndex'));
      expect(appShell, contains('widget.navigationShell.currentIndex'));
    });

    test('scheduled trip edit is a first-class owned-trip route', () {
      expect(router, contains("path: '/trip/:id/edit'"));
      expect(router, contains('EditTripScreenWrapper'));
      expect(scheduleProvider, contains('setEditTrip'));
      expect(scheduleProvider, contains('editingTripId'));
      expect(scheduleProvider, contains('updateTrip'));
      expect(scheduleScreen, contains('editingTripId'));
      expect(scheduleScreen, contains('Save changes'));
    });

    test('location and notification permissions use education-first UI', () {
      expect(
        permissionDialog,
        contains('PermissionAccessDialogConfig.location'),
      );
      expect(
        permissionDialog,
        contains('PermissionAccessDialogConfig.notifications'),
      );
      expect(scheduleScreen, contains('_handleCurrentLocation'));
      expect(scheduleScreen, contains('ensureLocationAccess'));
      expect(nearbyScreen, contains('_requestLocationAndReload'));
      expect(nearbyScreen, contains('PermissionAccessDialogConfig.location'));
      expect(profileConsent, contains('_savePromotionalPush'));
      expect(
        profileConsent,
        contains('PermissionAccessDialogConfig.notifications'),
      );
      expect(profileConsent, contains('registerToken'));
    });

    test('first-run profile setup is a dedicated wizard route', () {
      expect(router, contains("path: '/profile/setup'"));
      expect(router, contains('isFirstRun: true'));
      expect(editProfileScreen, contains('Set up profile'));
      expect(editProfileScreen, contains('Complete your profile'));
      expect(editProfileScreen, contains('Profile setup complete.'));
    });

    test('chat report and block flows use shared Mobio modal surfaces', () {
      expect(chatScreen, contains('showChatReportSheet'));
      expect(chatScreen, contains('MobiConfirmDialog.show'));
      expect(chatModerationSheet, contains('ChatReportDraft'));
      expect(chatModerationSheet, contains('showModalBottomSheet'));
      expect(chatModerationSheet, contains('Unsafe behavior'));
      expect(chatModerationSheet, contains('Route mismatch'));
    });

    test('admin report and audit rows expose detail drill-in surfaces', () {
      expect(adminReports, contains('_showReportDetailSheet'));
      expect(adminReports, contains('Report details'));
      expect(adminReports, contains("label: 'Details'"));
      expect(adminReports, contains('SelectableText'));
      expect(adminAudit, contains('_showAuditDetailSheet'));
      expect(adminAudit, contains('Audit event'));
      expect(adminAudit, contains('JsonEncoder.withIndent'));
      expect(adminAudit, contains("label: 'Details'"));
      expect(adminAudit, contains('SelectableText'));
    });

    test('route accessibility and release evidence matrix is tracked', () {
      final matrix = File(
        'docs/release/mobile_route_accessibility_golden_integration_matrix_2026-06-08.md',
      ).readAsStringSync();

      for (final route in const [
        '/login',
        '/',
        '/nearby',
        '/bookings',
        '/schedule',
        '/trip/:id',
        '/trip/:id/edit',
        '/chat',
        '/profile',
        '/profile/setup',
        '/edit-profile',
        '/admin',
        '/admin/reports',
        '/admin/audit',
        '/admin/health',
        '/config-error',
      ]) {
        expect(matrix, contains(route));
      }

      for (final evidence in const [
        'Accessibility',
        'Golden',
        'Integration',
        'Android evidence',
        'iOS evidence',
      ]) {
        expect(matrix, contains(evidence));
      }
    });
  });
}
