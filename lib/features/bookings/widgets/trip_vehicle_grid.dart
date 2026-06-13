import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/vehicle_type_icon.dart';

class TripVehicleGrid extends StatelessWidget {
  const TripVehicleGrid({
    super.key,
    required this.vehicleTypes,
    required this.selectedVehicleId,
    required this.onSelected,
  });

  final List<VehicleTypeModel> vehicleTypes;
  final String selectedVehicleId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (vehicleTypes.isEmpty) return const SizedBox(height: 80);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth < 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MobiSectionHeader(title: 'Vehicle', icon: LucideIcons.car),
            const SizedBox(height: AppSpacing.sm),
            if (useGrid)
              GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.25,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: vehicleTypes
                    .map((vt) => _buildVehicleItem(context, vt))
                    .toList(),
              )
            else
              Row(
                children: vehicleTypes
                    .map(
                      (vt) => Expanded(child: _buildVehicleItem(context, vt)),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVehicleItem(BuildContext context, VehicleTypeModel vt) {
    final isSelected = selectedVehicleId == vt.id;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Semantics(
      label: '${vt.label} vehicle type${isSelected ? ", selected" : ""}',
      child: Tooltip(
        message: vt.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(vt.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryFixed
                      : ext.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VehicleTypeIcon(
                      vehicleType: vt,
                      size: 24,
                      color: isSelected
                          ? cs.onPrimaryFixed
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        vt.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? cs.onPrimaryFixed
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
