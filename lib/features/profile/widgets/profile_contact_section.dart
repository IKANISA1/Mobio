import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/country.dart';

class ProfileContactSection extends StatelessWidget {
  const ProfileContactSection({
    super.key,
    required this.whatsAppController,
    required this.selectedCountry,
  });

  final TextEditingController whatsAppController;
  final Country selectedCountry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final verifiedNumber = whatsAppController.text.trim();

    return Row(
      children: [
        _buildCountrySurface(context, cs, ext),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            label: 'Authenticated WhatsApp number',
            value: verifiedNumber,
            readOnly: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ext.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: ext.borderSubtle.withValues(
                    alpha: ext.surfacePanelBorderAlpha,
                  ),
                ),
              ),
              child: TextField(
                controller: whatsAppController,
                readOnly: true,
                canRequestFocus: false,
                enableInteractiveSelection: false,
                showCursor: false,
                keyboardType: TextInputType.none,
                style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: verifiedNumber.isEmpty
                      ? 'Verified WhatsApp'
                      : null,
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
        ),
      ],
    );
  }

  Widget _buildCountrySurface(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    return Material(
      color: Colors.transparent,
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
    );
  }
}
