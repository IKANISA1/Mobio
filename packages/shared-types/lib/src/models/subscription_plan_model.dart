/// Typed model for `subscription_plans` table.
/// Represents platform access tiers for drivers based on vehicle type and country.
class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.id,
    required this.vehicleTypeId,
    required this.countryId,
    this.intervalDays = 30,
    this.price = 0,
    this.currency = 'RWF',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String vehicleTypeId;
  final String countryId;
  final int intervalDays;
  final double price;
  final String currency;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id'] as String? ?? '',
      vehicleTypeId: json['vehicle_type_id'] as String? ?? '',
      countryId: json['country_id'] as String? ?? '',
      intervalDays: json['interval_days'] as int? ?? 30,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'RWF',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_type_id': vehicleTypeId,
    'country_id': countryId,
    'interval_days': intervalDays,
    'price': price,
    'currency': currency,
    'is_active': isActive,
  };

  /// Display name for the interval based on days.
  String get intervalLabel {
    if (intervalDays == 1) return 'Daily';
    if (intervalDays == 7) return 'Weekly';
    if (intervalDays == 30) return 'Monthly';
    if (intervalDays == 365) return 'Yearly';
    return '$intervalDays Days';
  }

  SubscriptionPlanModel copyWith({
    int? intervalDays,
    double? price,
    String? currency,
    bool? isActive,
  }) {
    return SubscriptionPlanModel(
      id: id,
      vehicleTypeId: vehicleTypeId,
      countryId: countryId,
      intervalDays: intervalDays ?? this.intervalDays,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionPlanModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
