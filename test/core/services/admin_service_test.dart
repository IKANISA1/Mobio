import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/services/admin_service.dart';

void main() {
  group('AdminDashboardStats', () {
    test('fromJson parses valid data', () {
      final json = <String, dynamic>{
        'total_users': 150,
        'active_drivers': 42,
        'active_passengers': 108,
        'total_trips': 500,
        'active_trips': 23,
        'cancelled_trips': 15,
        'completed_trips': 462,
      };

      final stats = AdminDashboardStats.fromJson(json);

      expect(stats.totalUsers, 150);
      expect(stats.activeDrivers, 42);
      expect(stats.activePassengers, 108);
      expect(stats.totalTrips, 500);
      expect(stats.activeTrips, 23);
      expect(stats.cancelledTrips, 15);
      expect(stats.completedTrips, 462);
    });

    test('fromJson handles null input', () {
      final stats = AdminDashboardStats.fromJson(null);

      expect(stats.totalUsers, 0);
      expect(stats.activeDrivers, 0);
      expect(stats.activePassengers, 0);
      expect(stats.totalTrips, 0);
      expect(stats.activeTrips, 0);
      expect(stats.cancelledTrips, 0);
      expect(stats.completedTrips, 0);
    });

    test('fromJson handles missing keys', () {
      final stats = AdminDashboardStats.fromJson(<String, dynamic>{});

      expect(stats.totalUsers, 0);
      expect(stats.totalTrips, 0);
    });

    test('fromJson coerces numeric strings gracefully', () {
      final json = <String, dynamic>{
        'total_users': 5.0, // double
        'active_drivers': 3, // int
        'active_passengers': null, // null -> 0
      };

      final stats = AdminDashboardStats.fromJson(json);
      expect(stats.totalUsers, 5);
      expect(stats.activeDrivers, 3);
      expect(stats.activePassengers, 0);
    });
  });

  group('AdminUserListItem', () {
    test('fromJson parses complete user data', () {
      final json = <String, dynamic>{
        'id': 'user-1',
        'display_name': 'Jean Bosco',
        'name': 'jbosco',
        'phone': '+250788123456',
        'role': 'admin',
        'is_driver': true,
        'vehicle_type': 'cab',
        'member_id': '482013',
        'has_face_id': true,
        'is_online': true,
        'created_at': '2026-01-15T10:00:00Z',
      };

      final user = AdminUserListItem.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.name, 'Jean Bosco'); // display_name takes priority
      expect(user.phone, '+250788123456');
      expect(user.role, 'admin');
      expect(user.isDriver, true);
      expect(user.vehicleType, 'cab');
      expect(user.memberId, '482013');
      expect(user.hasFaceId, true);
      expect(user.isOnline, true);
      expect(user.createdAt, '2026-01-15T10:00:00Z');
    });

    test('fromJson falls back to name when display_name is empty', () {
      final json = <String, dynamic>{
        'id': 'user-fb',
        'display_name': '',
        'name': 'Fallback Name',
        'phone': '+250781000001',
        'role': 'passenger',
        'is_driver': false,
        'has_face_id': false,
        'is_online': false,
      };

      final user = AdminUserListItem.fromJson(json);
      expect(user.name, 'Fallback Name');
    });

    test('fromJson uses "Unnamed member" when both names are empty', () {
      final json = <String, dynamic>{
        'id': 'user-none',
        'display_name': '',
        'name': '',
        'phone': '+250781000002',
        'role': 'passenger',
        'is_driver': false,
        'has_face_id': false,
        'is_online': false,
      };

      final user = AdminUserListItem.fromJson(json);
      expect(user.name, 'Unnamed member');
    });

    test('fromJson handles minimal data with defaults', () {
      final json = <String, dynamic>{
        'id': 'user-2',
        'name': 'Test User',
        'phone': '+250781000000',
        'role': 'passenger',
        'is_driver': false,
        'has_face_id': false,
        'is_online': false,
      };

      final user = AdminUserListItem.fromJson(json);

      expect(user.id, 'user-2');
      expect(user.isDriver, false);
      expect(user.vehicleType, isNull);
      expect(user.memberId, isNull);
      expect(user.createdAt, isNull);
    });
  });
}
