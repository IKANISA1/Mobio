import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

class MobiOtpCodeField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String label;

  const MobiOtpCodeField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.enabled,
    this.label = 'Verification code',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ext.clayCardShadow,
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            style: AppTypography.titleMd.copyWith(
              fontSize: 24,
              color: cs.onSurface,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: '123456',
              hintStyle: AppTypography.titleMd.copyWith(
                fontSize: 24,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
