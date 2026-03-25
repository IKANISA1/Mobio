import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/models/vehicle_type.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Returns the icon for a vehicle type, matching transito getVehicleIcon.
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

/// Vehicle type filter chip list matching transito.
/// Uses scale + opacity feedback on press for instant responsiveness.
class VehicleFilterChips extends StatelessWidget {
  final VehicleType selected;
  final ValueChanged<VehicleType> onSelected;

  const VehicleFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const _types = [
    (VehicleType.moto, 'Moto', LucideIcons.zap),
    (VehicleType.cab, 'Cab', LucideIcons.car),
    (VehicleType.trike, 'Trike', LucideIcons.truck),
    (VehicleType.truck, 'Truck', LucideIcons.layoutGrid),
    (VehicleType.private_, 'Private', LucideIcons.shield),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _types.map((entry) {
          final (type, label, icon) = entry;
          final isSelected = selected == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TappableChip(
              isSelected: isSelected,
              onTap: () => onSelected(type),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? cs.onSecondaryContainer
                        : cs.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? cs.onSecondaryContainer
                          : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
                : ext.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(100),
            boxShadow: widget.isSelected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
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
