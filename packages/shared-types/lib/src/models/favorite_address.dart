import 'package:mobi_shared_types/models/place.dart';

class FavoriteAddress {
  const FavoriteAddress({
    required this.id,
    required this.profileId,
    required this.label,
    required this.addressType,
    required this.formattedAddress,
    this.placeId,
    this.latitude,
    this.longitude,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String profileId;
  final String label;
  final String addressType;
  final String formattedAddress;
  final String? placeId;
  final double? latitude;
  final double? longitude;
  final int sortOrder;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  factory FavoriteAddress.fromJson(Map<String, dynamic> json) {
    return FavoriteAddress(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      addressType: json['address_type'] as String? ?? 'other',
      formattedAddress: json['formatted_address'] as String? ?? '',
      placeId: json['place_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  PlaceDetails toPlaceDetails() {
    return PlaceDetails(
      placeId: placeId ?? id,
      formattedAddress: formattedAddress,
      latitude: latitude ?? 0,
      longitude: longitude ?? 0,
    );
  }
}
