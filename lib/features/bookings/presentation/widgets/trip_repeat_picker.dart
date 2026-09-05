import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class TripRepeatPicker extends StatelessWidget {
  const TripRepeatPicker({
    super.key,
    required this.isRecurring,
    required this.recurringDays,
    required this.onToggleRecurring,
    required this.onToggleDay,
  });

  final bool isRecurring;
  final List<int> recurringDays;
  final VoidCallback onToggleRecurring;
  final ValueChanged<int> onToggleDay;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobiSectionHeader(
          title: 'Repeat',
          icon: LucideIcons.refreshCw,
          caption: isRecurring ? 'Weekly' : 'One trip',
        ),
        const SizedBox(height: AppSpacing.md),
        ClayCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isRecurring
                          ? cs.primaryContainer
                          : ext.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.refreshCw,
                      size: 24,
                      color: isRecurring ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly',
                          style: AppTypography.labelMd.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRecurring ? 'On' : 'Off',
                          style: AppTypography.titleMd,
                        ),
                      ],
                    ),
                  ),
                  _buildToggleSwitch(cs, ext),
                ],
              ),
              if (isRecurring) ...[
                const SizedBox(height: 16),
                Divider(color: ext.surfaceContainer, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    7,
                    (idx) => _buildDayBubble(context, idx, cs, ext),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleSwitch(ColorScheme cs, MobiThemeExtension ext) {
    return Semantics(
      label: 'Toggle recurring trip',
      toggled: isRecurring,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          onToggleRecurring();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 24,
          decoration: BoxDecoration(
            color: isRecurring ? cs.primary : ext.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: isRecurring
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ext.surfaceContainerLowest,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayBubble(
    BuildContext context,
    int idx,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    final isSelected = recurringDays.contains(idx);
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return Semantics(
      label: '${dayNames[idx]}${isSelected ? ", selected" : ""}',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.selectionClick();
          onToggleDay(idx);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : ext.surfaceContainer,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              _dayLabels[idx],
              style: AppTypography.labelSm.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
