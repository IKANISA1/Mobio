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
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final mobileTileAspectRatio = textScale >= 1.8
            ? 0.72
            : textScale >= 1.4
            ? 0.82
            : 1.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MobiSectionHeader(title: 'Vehicle', icon: LucideIcons.car),
            const SizedBox(height: AppSpacing.sm),
            if (useGrid)
              GridView.count(
                crossAxisCount: 3,
                childAspectRatio: mobileTileAspectRatio,
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
    final palette = _paletteForVehicleType(vt.id, ext);
    final foregroundColor = isSelected
        ? Colors.white
        : Color.lerp(cs.onSurface, palette.accent, 0.32)!;
    final labelColor = isSelected
        ? Colors.white
        : Color.lerp(cs.onSurfaceVariant, palette.accent, 0.28)!;

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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? palette.accent.withValues(alpha: 0.72)
                        : palette.accent.withValues(alpha: 0.22),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? [
                            palette.accent,
                            Color.lerp(palette.accent, palette.depth, 0.46)!,
                            Color.lerp(palette.depth, Colors.black, 0.12)!,
                          ]
                        : [
                            Color.lerp(
                              ext.surfaceContainerHigh,
                              palette.accent,
                              0.18,
                            )!,
                            Color.lerp(
                              ext.surfaceContainer,
                              palette.depth,
                              0.62,
                            )!,
                            Color.lerp(
                              ext.surfaceContainerLowest,
                              palette.depth,
                              0.42,
                            )!,
                          ],
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: palette.depth.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 14,
                      right: 14,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(
                            alpha: isSelected ? 0.72 : 0.36,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const SizedBox(height: 3),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(
                                  alpha: isSelected ? 0.18 : 0.16,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: isSelected ? 0.18 : 0.08,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: VehicleTypeIcon(
                                  vehicleType: vt,
                                  size: 22,
                                  color: foregroundColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              vt.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w800,
                                color: labelColor,
                              ),
                            ),
                          ],
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

class _VehicleCardPalette {
  const _VehicleCardPalette({required this.accent, required this.depth});

  final Color accent;
  final Color depth;
}

_VehicleCardPalette _paletteForVehicleType(
  String vehicleTypeId,
  MobiThemeExtension ext,
) {
  switch (vehicleTypeId) {
    case 'moto':
      return const _VehicleCardPalette(
        accent: AppColors.aqua,
        depth: AppColors.aquaContainer,
      );
    case 'bus':
      return const _VehicleCardPalette(
        accent: AppColors.brandPeriwinkle,
        depth: AppColors.violetDepth,
      );
    case 'cab':
      return const _VehicleCardPalette(
        accent: AppColors.caution,
        depth: AppColors.cautionContainer,
      );
    case 'truck':
      return const _VehicleCardPalette(
        accent: AppColors.brandOrangeRed,
        depth: AppColors.orangeDepth,
      );
    case 'trike':
      return const _VehicleCardPalette(
        accent: AppColors.brandMintGreen,
        depth: AppColors.mintDepth,
      );
    case 'private':
    case 'private_':
      return const _VehicleCardPalette(
        accent: AppColors.brandDustyRose,
        depth: AppColors.roseDepth,
      );
    case 'rentals':
      return const _VehicleCardPalette(
        accent: AppColors.info,
        depth: AppColors.infoContainer,
      );
    default:
      return _VehicleCardPalette(accent: ext.aqua, depth: ext.aquaContainer);
  }
}
