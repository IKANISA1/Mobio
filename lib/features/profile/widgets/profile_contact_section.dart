import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';

class ProfileContactSection extends StatelessWidget {
  const ProfileContactSection({
    super.key,
    required this.whatsAppController,
    required this.selectedCountry,
    required this.onCountryTap,
  });

  final TextEditingController whatsAppController;
  final Country selectedCountry;
  final VoidCallback onCountryTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MobiSectionHeader(
          title: 'Contact',
          caption: 'WhatsApp',
          icon: LucideIcons.messageCircle,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _buildCountryButton(context, cs, ext),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputSurface(
                ext: ext,
                child: TextField(
                  controller: whatsAppController,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: selectedCountry.phonePlaceholder,
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountryButton(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCountryTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selectedCountry.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                selectedCountry.dialingCode,
                style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              ),
            ],
          ),
        ),
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
