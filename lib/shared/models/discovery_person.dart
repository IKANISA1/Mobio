import 'package:mobi_app/core/utils/mobio_member_id.dart';
import 'package:mobi_shared_types/models/vehicle_type.dart';

/// A discovery peer is a person, with no scheduled-trip identity or dates.
class DiscoveryPerson {
  DiscoveryPerson({
    required this.peerId,
    required this.memberId,
    required this.vehicleTypeId,
    required this.distanceKm,
  }) {
    if (peerId.trim().isEmpty ||
        (memberId != null && !isValidMobioMemberId(memberId)) ||
        vehicleTypeId.trim().isEmpty ||
        (distanceKm != null && (!distanceKm!.isFinite || distanceKm! < 0))) {
      throw const FormatException('Invalid discovery person');
    }
  }

  final String peerId;
  final String? memberId;
  final String vehicleTypeId;
  final double? distanceKm;

  String get displayLabel => displayMobioMemberId(memberId) ?? 'Driver';
  VehicleType get vehicleType => VehicleType.fromString(vehicleTypeId);
  Uri get chatUri => Uri(path: '/chat', queryParameters: {'peerId': peerId});
}
