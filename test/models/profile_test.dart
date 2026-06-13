import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/models/profile.dart';

void main() {
  group('Profile model', () {
    final sampleJson = <String, dynamic>{
      'id': 'abc-123',
      'member_id': 'M00042',
      'name': 'Jean Bosco',
      'display_name': 'JB',
      'phone': '+250780000000',
      'whatsapp': '+250780000000',
      'momo_number': '0780000000',
      'momo_pay_code': '123456',
      'role': 'driver',
      'country_code': '+250',
      'vehicle_type': 'bus',
      'vehicle_number_plate': 'RAA 123 B',
      'bus_agency_name': 'Volcano Express',
      'bus_passenger_capacity': 58,
      'is_driver': true,
      'avatar_url': null,
      'created_at': '2024-01-15T10:00:00Z',
    };

    test('fromJson parses all fields', () {
      final profile = Profile.fromJson(sampleJson);

      expect(profile.id, 'abc-123');
      expect(profile.memberId, 'M00042');
      expect(profile.name, 'Jean Bosco');
      expect(profile.displayName, 'JB');
      expect(profile.phone, '+250780000000');
      expect(profile.whatsapp, '+250780000000');
      expect(profile.momoNumber, '0780000000');
      expect(profile.momoPayCode, '123456');
      expect(profile.role, 'driver');
      expect(profile.countryCode, '+250');
      expect(profile.vehicleType, 'bus');
      expect(profile.vehicleNumberPlate, 'RAA 123 B');
      expect(profile.busAgencyName, 'Volcano Express');
      expect(profile.busPassengerCapacity, 58);
      expect(profile.isDriver, isTrue);
      expect(profile.avatarUrl, isNull);
      expect(profile.createdAt, '2024-01-15T10:00:00Z');
    });

    test('fromJson handles missing optional fields', () {
      final profile = Profile.fromJson({'id': 'minimal-id'});

      expect(profile.id, 'minimal-id');
      expect(profile.memberId, isNull);
      expect(profile.name, isNull);
      expect(profile.role, 'passenger');
      expect(profile.isDriver, isFalse);
      expect(profile.countryCode, isNull);
    });

    test('isAdmin returns true only for admin role', () {
      final admin = Profile.fromJson({'id': '1', 'role': 'admin'});
      final passenger = Profile.fromJson({'id': '2', 'role': 'passenger'});
      final driver = Profile.fromJson({'id': '3', 'role': 'driver'});

      expect(admin.isAdmin, isTrue);
      expect(passenger.isAdmin, isFalse);
      expect(driver.isAdmin, isFalse);
    });

    test('toJson roundtrips correctly', () {
      final profile = Profile.fromJson(sampleJson);
      final json = profile.toJson();

      expect(json['id'], 'abc-123');
      expect(json['member_id'], 'M00042');
      expect(json['role'], 'driver');
      expect(json['momo_number'], '0780000000');
      expect(json['momo_pay_code'], '123456');
      expect(json['is_driver'], isTrue);
      expect(json['vehicle_type'], 'bus');
      expect(json['bus_agency_name'], 'Volcano Express');
      expect(json['bus_passenger_capacity'], 58);
    });

    test('toString provides useful debug output', () {
      final profile = Profile.fromJson(sampleJson);
      expect(profile.toString(), contains('abc-123'));
      expect(profile.toString(), contains('driver'));
    });
  });
}
