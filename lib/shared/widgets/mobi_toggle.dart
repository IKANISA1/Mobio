import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

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
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: ext.surfaceContainerHighest.withValues(
          alpha: ext.controlTrackAlpha,
        ),
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
              label: labels[index],
              child: GestureDetector(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: isSelected
                        ? Border.all(
                            color: cs.outlineVariant.withValues(
                              alpha: ext.cardBorderAlpha,
                            ),
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: ext.controlShadowAlpha,
                              ),
                              blurRadius: 12,
                              spreadRadius: -8,
                              offset: const Offset(0, 6),
                            ),
                          ]
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
                          fontWeight: FontWeight.w700,
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
          );
        }),
      ),
    );
  }
}
