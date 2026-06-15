import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Revolut visual coverage contract', () {
    test('covers route surfaces still referenced by the route matrix', () {
      final goldenTest = File(
        'test/features/preview/revolut_reference_golden_test.dart',
      ).readAsStringSync();
      final routeMatrix = File(
        'docs/reports/route-screen-matrix-2026-06-15.md',
      ).readAsStringSync();

      for (final requiredSurface in const [
        "name: 'login'",
        'WhatsAppLoginScreen(',
        "name: 'trip_details'",
        'TripDetailsScreen(',
        "name: 'trip_edit'",
        'editingTripId:',
        "name: 'edit_profile'",
        'EditProfileScreen(onBack:',
        "name: 'profile_setup'",
        'EditProfileScreen(isFirstRun: true',
        "name: 'admin_auth'",
        'AdminAuthScreen(',
        "name: 'admin_users'",
        'AdminUsersScreen.new',
        "name: 'admin_trips'",
        'AdminTripsScreen(',
        "name: 'admin_audit_actual'",
        'AdminAuditLogScreen(',
        "name: 'biopay_scan'",
        'BioPayScanScreen(',
        "name: 'config_error'",
        'ConfigErrorScreen.new',
      ]) {
        expect(goldenTest, contains(requiredSurface));
      }

      for (final matrixEvidence in const [
        '/login',
        'Login/auth contracts plus Revolut mobile goldens',
        '/trip/:id',
        'Trip details Revolut mobile goldens',
        '/trip/:id/edit',
        'Trip edit Revolut mobile goldens',
        '/edit-profile',
        'Edit profile Revolut mobile goldens',
        '/profile/setup',
        'Profile setup Revolut mobile goldens',
        '/admin-auth',
        'Admin auth mobile and desktop Revolut goldens',
        '/admin/users',
        'Actual admin users mobile and desktop Revolut goldens',
        '/admin/trips',
        'Actual admin trips mobile and desktop Revolut goldens',
        '/admin/audit',
        'Actual admin audit mobile and desktop Revolut goldens',
        '/biopay/scan',
        'BioPay scan Revolut mobile goldens',
        '/config-error',
        'Config error contracts plus Revolut mobile goldens',
      ]) {
        expect(routeMatrix, contains(matrixEvidence));
      }
    });

    test('has checked-in baselines for the expanded route evidence set', () {
      for (final path in const [
        'test/features/preview/goldens/revolut/login_390x844.png',
        'test/features/preview/goldens/revolut/login_430x932.png',
        'test/features/preview/goldens/revolut/admin_users_390x844.png',
        'test/features/preview/goldens/revolut/admin_users_430x932.png',
        'test/features/preview/goldens/revolut/admin_trips_390x844.png',
        'test/features/preview/goldens/revolut/admin_trips_430x932.png',
        'test/features/preview/goldens/revolut/admin_desktop/admin_users_768x1024.png',
        'test/features/preview/goldens/revolut/admin_desktop/admin_users_1280x900.png',
        'test/features/preview/goldens/revolut/admin_desktop/admin_users_1440x1000.png',
        'test/features/preview/goldens/revolut/admin_desktop/admin_trips_768x1024.png',
        'test/features/preview/goldens/revolut/admin_desktop/admin_trips_1280x900.png',
        'test/features/preview/goldens/revolut/admin_desktop/admin_trips_1440x1000.png',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });
  });
}
