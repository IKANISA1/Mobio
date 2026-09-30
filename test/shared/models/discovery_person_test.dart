import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/models/discovery_person.dart';

void main() {
  test('discovery chat retains peer identity without a scheduled-trip ID', () {
    final person = DiscoveryPerson(
      peerId: 'internal-peer-id',
      memberId: '004321',
      vehicleTypeId: 'moto',
      distanceKm: 1.2,
    );
    expect(person.displayLabel, '004321');
    expect(person.chatUri.queryParameters, {'peerId': 'internal-peer-id'});
  });

  test('missing public member ID never substitutes the internal ID', () {
    final person = DiscoveryPerson(
      peerId: 'internal-peer-id',
      memberId: null,
      vehicleTypeId: 'cab',
      distanceKm: 0,
    );
    expect(person.displayLabel, 'Driver');
  });

  test('invalid public member ID is rejected', () {
    expect(
      () => DiscoveryPerson(
        peerId: 'internal-peer-id',
        memberId: 'abc123',
        vehicleTypeId: 'cab',
        distanceKm: 0,
      ),
      throwsFormatException,
    );
  });
}
