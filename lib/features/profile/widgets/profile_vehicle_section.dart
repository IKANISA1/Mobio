import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';

class ProfileVehicleSection extends StatelessWidget {
  const ProfileVehicleSection({
    super.key,
    required this.vehicleTypes,
    required this.selectedVehicleId,
    required this.onVehicleTypeChanged,
    required this.plateController,
  });

  final List<VehicleTypeModel> vehicleTypes;
  final String selectedVehicleId;
  final ValueChanged<String> onVehicleTypeChanged;
  final TextEditingController plateController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MobiSectionHeader(
          title: 'Vehicle',
          caption: 'Type and plate',
          icon: LucideIcons.car,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildVehicleGrid(context, cs, ext),
        const SizedBox(height: AppSpacing.lg),
        _buildPlateCard(context, cs, ext),
      ],
    );
  }

  Widget _buildVehicleGrid(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    if (vehicleTypes.isEmpty) return const SizedBox(height: 80);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Row(
        children: vehicleTypes.map((vt) {
          final isSelected = selectedVehicleId == vt.id;
          return Expanded(
            child: _TappableSelector(
              onTap: () => onVehicleTypeChanged(vt.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AspectRatio(
                  aspectRatio: 0.8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primaryContainer
                          : ext.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? cs.primary.withValues(alpha: 0.45)
                            : ext.borderSubtle.withValues(
                                alpha: ext.cardBorderAlpha,
                              ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          vt.localAssetPath,
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            vt.icon,
                            size: 20,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          vt.label,
                          style: AppTypography.labelSm.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlateCard(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Number plate',
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInputSurface(
            ext: ext,
            child: TextField(
              controller: plateController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                LengthLimitingTextInputFormatter(16),
              ],
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'RAA 123 A',
                hintStyle: AppTypography.titleMd.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSurface({
    required MobiThemeExtension ext,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ext.borderSubtle.withValues(
            alpha: ext.surfacePanelBorderAlpha,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _TappableSelector extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _TappableSelector({required this.onTap, required this.child});

  @override
  State<_TappableSelector> createState() => _TappableSelectorState();
}

class _TappableSelectorState extends State<_TappableSelector> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}
