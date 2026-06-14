import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Dynamic vehicle type model — maps to `public.vehicle_types` Supabase table.
///
/// Replaces the hardcoded [VehicleType] enum for UI purposes while maintaining
/// backward compatibility with the enum for Trip serialization.
class VehicleTypeModel {
  final String id;
  final String label;
  final String iconName;
  final String imageUrl;
  final int sortOrder;
  final bool isActive;
  final List<String> countryIds;

  const VehicleTypeModel({
    required this.id,
    required this.label,
    this.iconName = '',
    this.imageUrl = '',
    this.sortOrder = 0,
    this.isActive = true,
    this.countryIds = const [],
  });

  factory VehicleTypeModel.fromJson(
    Map<String, dynamic> json, {
    List<String>? countries,
  }) {
    return VehicleTypeModel(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      countryIds: countries ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon_name': iconName,
    'image_url': imageUrl,
    'sort_order': sortOrder,
    'is_active': isActive,
  };

  /// Whether this vehicle type has a remote image URL.
  bool get hasImage => imageUrl.isNotEmpty;

  /// Local asset path for fallback image.
  String get localAssetPath => 'assets/vehicles/$id.png';

  static const Map<String, int> _displayRank = {
    'moto': 1,
    'bus': 2,
    'cab': 3,
    'truck': 4,
    'trike': 5,
    'private': 6,
    'private_': 6,
    'rentals': 7,
  };

  int get displayRank => _displayRank[id] ?? (1000 + sortOrder);

  static int compareDisplayOrder(VehicleTypeModel a, VehicleTypeModel b) {
    final rankComparison = a.displayRank.compareTo(b.displayRank);
    if (rankComparison != 0) return rankComparison;

    final sortComparison = a.sortOrder.compareTo(b.sortOrder);
    if (sortComparison != 0) return sortComparison;

    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  static List<VehicleTypeModel> ordered(Iterable<VehicleTypeModel> types) {
    return types.toList()..sort(compareDisplayOrder);
  }

  /// Resolve the Lucide icon from `iconName`.
  IconData get icon {
    switch (iconName) {
      case 'bike':
        return LucideIcons.bike;
      case 'zap':
        return LucideIcons.bike;
      case 'car':
        return LucideIcons.car;
      case 'bus':
        return LucideIcons.bus;
      case 'truck':
        return LucideIcons.truck;
      case 'layout-grid':
        return LucideIcons.layoutGrid;
      case 'shield':
        return LucideIcons.shield;
      case 'package':
        return LucideIcons.package;
      case 'key-round':
        return LucideIcons.keyRound;
      default:
        return LucideIcons.car;
    }
  }

  /// Hardcoded fallback list for offline use.
  static const List<VehicleTypeModel> fallbackTypes = [
    VehicleTypeModel(
      id: 'moto',
      label: 'Moto Taxi',
      iconName: 'bike',
      sortOrder: 1,
    ),
    VehicleTypeModel(id: 'bus', label: 'Bus', iconName: 'bus', sortOrder: 2),
    VehicleTypeModel(id: 'cab', label: 'Cab', iconName: 'car', sortOrder: 3),
    VehicleTypeModel(
      id: 'truck',
      label: 'Truck',
      iconName: 'layout-grid',
      sortOrder: 4,
    ),
    VehicleTypeModel(
      id: 'trike',
      label: 'Trike',
      iconName: 'truck',
      sortOrder: 5,
    ),
    VehicleTypeModel(
      id: 'private',
      label: 'Others',
      iconName: 'package',
      sortOrder: 6,
    ),
    VehicleTypeModel(
      id: 'rentals',
      label: 'Rentals',
      iconName: 'key-round',
      sortOrder: 7,
    ),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleTypeModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VehicleTypeModel(id: $id, label: $label)';
}
