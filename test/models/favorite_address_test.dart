import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';

void main() {
  group('FavoriteAddress', () {
    test('fromJson parses saved place payload', () {
      final address = FavoriteAddress.fromJson({
        'id': 'fav-1',
        'profile_id': 'user-1',
        'label': 'School',
        'address_type': 'school',
        'formatted_address': 'Kigali Parents School',
        'place_id': 'place-1',
        'latitude': -1.92,
        'longitude': 30.08,
        'sort_order': 2,
        'is_active': true,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:30:00Z',
      });

      expect(address.id, 'fav-1');
      expect(address.profileId, 'user-1');
      expect(address.label, 'School');
      expect(address.addressType, 'school');
      expect(address.formattedAddress, 'Kigali Parents School');
      expect(address.placeId, 'place-1');
      expect(address.latitude, -1.92);
      expect(address.longitude, 30.08);
      expect(address.sortOrder, 2);
      expect(address.isActive, true);
      expect(address.createdAt, '2026-05-01T08:00:00Z');
      expect(address.updatedAt, '2026-05-01T08:30:00Z');
    });

    test('toPlaceDetails preserves saved coordinates and label', () {
      const address = FavoriteAddress(
        id: 'fav-1',
        profileId: 'user-1',
        label: 'Home',
        addressType: 'home',
        formattedAddress: 'KG 1 Ave',
        latitude: -1.95,
        longitude: 30.06,
      );

      final place = address.toPlaceDetails();

      expect(place.placeId, 'fav-1');
      expect(place.formattedAddress, 'KG 1 Ave');
      expect(place.latitude, -1.95);
      expect(place.longitude, 30.06);
    });

    test('fromJson applies defaults for sparse payloads', () {
      final address = FavoriteAddress.fromJson({});

      expect(address.id, '');
      expect(address.profileId, '');
      expect(address.addressType, 'other');
      expect(address.formattedAddress, '');
      expect(address.sortOrder, 0);
      expect(address.isActive, true);
    });
  });
}
