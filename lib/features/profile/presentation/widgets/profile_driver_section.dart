import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class ProfileDriverSection extends StatelessWidget {
  const ProfileDriverSection({
    super.key,
    required this.isDriver,
    required this.onToggle,
  });

  final bool isDriver;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobiSectionHeader(
          title: 'Driver',
          caption: isDriver ? 'On' : 'Off',
          icon: LucideIcons.car,
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(32),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                color: ext.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: ext.surfaceContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(LucideIcons.car, size: 24, color: cs.onSurface),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Driver mode',
                      style: AppTypography.titleLg.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  _buildToggleSwitch(cs, ext),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleSwitch(ColorScheme cs, MobiThemeExtension ext) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50,
      height: 28,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDriver ? cs.primary : ext.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
