/// Typed profile model for the `profiles` table.
///
/// Replaces raw `Map<String, dynamic>` access across the codebase.
/// Uses manual serialization (no freezed/code-gen) to keep it simple
/// and avoid adding build_runner dependencies for a single model.
class Profile {
  const Profile({
    required this.id,
    this.memberId,
    this.name,
    this.displayName,
    this.phone,
    this.whatsapp,
    this.role = 'passenger',
    this.countryCode,
    this.vehicleType,
    this.vehicleNumberPlate,
    this.isDriver = false,
    this.avatarUrl,
    this.biopayHandleType,
    this.biopayHandleValue,
    this.createdAt,
  });

  final String id;
  final String? memberId;
  final String? name;
  final String? displayName;
  final String? phone;
  final String? whatsapp;
  final String role;
  final String? countryCode;
  final String? vehicleType;
  final String? vehicleNumberPlate;
  final bool isDriver;
  final String? avatarUrl;
  final String? biopayHandleType;
  final String? biopayHandleValue;
  final String? createdAt;

  bool get isAdmin => role == 'admin';

  /// Parse from a Supabase row (`Map<String, dynamic>`).
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      memberId: json['member_id'] as String?,
      name: json['name'] as String?,
      displayName: json['display_name'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      role: json['role'] as String? ?? 'passenger',
      countryCode: json['country_code'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehicleNumberPlate: json['vehicle_number_plate'] as String?,
      isDriver: json['is_driver'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String?,
      biopayHandleType: json['biopay_handle_type'] as String?,
      biopayHandleValue: json['biopay_handle_value'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  /// Convenience: convert back to a map (e.g. for display/debug).
  Map<String, dynamic> toJson() => {
        'id': id,
        'member_id': memberId,
        'name': name,
        'display_name': displayName,
        'phone': phone,
        'whatsapp': whatsapp,
        'role': role,
        'country_code': countryCode,
        'vehicle_type': vehicleType,
        'vehicle_number_plate': vehicleNumberPlate,
        'is_driver': isDriver,
        'avatar_url': avatarUrl,
        'biopay_handle_type': biopayHandleType,
        'biopay_handle_value': biopayHandleValue,
        'created_at': createdAt,
      };

  @override
  String toString() => 'Profile(id: $id, role: $role)';
}
