import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/vehicle_type.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';

/// Returns the icon for a [VehicleType] enum value.
IconData getVehicleIcon(VehicleType type) {
  switch (type) {
    case VehicleType.moto:
      return LucideIcons.zap;
    case VehicleType.cab:
      return LucideIcons.car;
    case VehicleType.trike:
      return LucideIcons.truck;
    case VehicleType.truck:
      return LucideIcons.layoutGrid;
    case VehicleType.private_:
      return LucideIcons.shield;
  }
}

/// Returns the icon for a vehicle type ID string.
///
/// Used for backward compatibility where only a string ID is available.
IconData getVehicleIconFromId(String id) {
  switch (id) {
    case 'moto':
      return LucideIcons.zap;
    case 'cab':
      return LucideIcons.car;
    case 'trike':
      return LucideIcons.truck;
    case 'truck':
      return LucideIcons.layoutGrid;
    case 'private':
    case 'private_':
      return LucideIcons.shield;
    default:
      return LucideIcons.car;
  }
}

/// DB-driven vehicle type filter chip list.
///
/// Renders chips with vehicle images (local asset fallback) and labels
/// from the dynamic [VehicleTypeModel] list fetched from Supabase.
class VehicleFilterChips extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;
  final List<VehicleTypeModel> vehicleTypes;

  const VehicleFilterChips({
    super.key,
    required this.selectedId,
    required this.onSelected,
    required this.vehicleTypes,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicleTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: vehicleTypes.map((vt) {
          final isSelected = selectedId == vt.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              selected: isSelected,
              button: true,
              label: '${vt.label} vehicle filter',
              child: _TappableChip(
                isSelected: isSelected,
                onTap: () => onSelected(vt.id),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _VehicleImage(vehicleType: vt, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      vt.label,
                      style: AppTypography.chipText.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Renders a vehicle image: network URL → local asset → Lucide icon fallback.
class _VehicleImage extends StatelessWidget {
  final VehicleTypeModel vehicleType;
  final double size;

  const _VehicleImage({required this.vehicleType, this.size = 24});

  @override
  Widget build(BuildContext context) {
    // Try local asset (always bundled)
    return Image.asset(
      vehicleType.localAssetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, e, s) => Icon(
        vehicleType.icon,
        size: size * 0.7,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// Chip with scale + opacity tap feedback.
class _TappableChip extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _TappableChip({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  State<_TappableChip> createState() => _TappableChipState();
}

class _TappableChipState extends State<_TappableChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.05);
          final opacity = 1.0 - (_controller.value * 0.2);
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: opacity, child: child),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? cs.secondaryContainer
                : ext.surfaceContainerLowest.withValues(
                    alpha: ext.surfacePanelAlpha,
                  ),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isSelected
                  ? cs.secondary.withValues(alpha: 0.16)
                  : cs.outlineVariant.withValues(alpha: ext.cardBorderAlpha),
            ),
            boxShadow: widget.isSelected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: ext.controlShadowAlpha * 0.7,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
