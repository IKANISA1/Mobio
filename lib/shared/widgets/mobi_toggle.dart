import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

/// Segmented toggle for MOBI Passenger/Driver and Mine/Nearby controls.
///
/// Set [selectedIndex] to `-1` (or any out-of-range value) to show
/// no segment selected — useful for "user must choose" flows.
class MobiToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const MobiToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: cs.outlineVariant.withValues(
            alpha: ext.surfacePanelBorderAlpha,
          ),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: Semantics(
              selected: isSelected,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                onTap: () => onChanged(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.onSurface.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: isSelected
                          ? Border.all(
                              color: cs.outlineVariant.withValues(
                                alpha: ext.cardBorderAlpha,
                              ),
                            )
                          : null,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: AppTypography.labelLg.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
