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

  /// Resolve the Lucide icon from `iconName`.
  IconData get icon {
    switch (iconName) {
      case 'zap':
        return LucideIcons.zap;
      case 'car':
        return LucideIcons.car;
      case 'truck':
        return LucideIcons.truck;
      case 'layout-grid':
        return LucideIcons.layoutGrid;
      case 'shield':
        return LucideIcons.shield;
      case 'package':
        return LucideIcons.package;
      default:
        return LucideIcons.car;
    }
  }

  /// Hardcoded fallback list for offline use.
  static const List<VehicleTypeModel> fallbackTypes = [
    VehicleTypeModel(
      id: 'moto',
      label: 'Moto Taxi',
      iconName: 'zap',
      sortOrder: 1,
    ),
    VehicleTypeModel(id: 'cab', label: 'Cab', iconName: 'car', sortOrder: 2),
    VehicleTypeModel(
      id: 'trike',
      label: 'Trike',
      iconName: 'truck',
      sortOrder: 3,
    ),
    VehicleTypeModel(
      id: 'truck',
      label: 'Truck',
      iconName: 'layout-grid',
      sortOrder: 4,
    ),
    VehicleTypeModel(
      id: 'private',
      label: 'Others',
      iconName: 'package',
      sortOrder: 5,
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
