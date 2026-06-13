import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';

class ProfileMomoSection extends StatelessWidget {
  const ProfileMomoSection({
    super.key,
    required this.momoNumberController,
    required this.momoPayCodeController,
  });

  final TextEditingController momoNumberController;
  final TextEditingController momoPayCodeController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MobiSectionHeader(title: 'MoMo', icon: LucideIcons.wallet),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
            ),
          ),
          child: Column(
            children: [
              _MomoInputSurface(
                controller: momoNumberController,
                label: 'MoMo number',
                hintText: '07XXXXXXXX',
                icon: LucideIcons.smartphone,
                cs: cs,
                ext: ext,
              ),
              const SizedBox(height: AppSpacing.md),
              _MomoInputSurface(
                controller: momoPayCodeController,
                label: 'MoMo Pay code',
                hintText: 'Code',
                icon: LucideIcons.badgeDollarSign,
                cs: cs,
                ext: ext,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MomoInputSurface extends StatelessWidget {
  const _MomoInputSurface({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.cs,
    required this.ext,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final ColorScheme cs;
  final MobiThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      style: AppTypography.titleMd.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: ext.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: ext.borderSubtle.withValues(
              alpha: ext.surfacePanelBorderAlpha,
            ),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: ext.borderSubtle.withValues(
              alpha: ext.surfacePanelBorderAlpha,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}
