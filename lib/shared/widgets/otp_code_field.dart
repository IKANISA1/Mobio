import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
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
    final digits = controller.text.replaceAll(RegExp(r'\D'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Semantics(
          textField: true,
          label: label,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: List.generate(6, (index) {
                  final isFilled = index < digits.length;
                  final isFocused = enabled && index == digits.length;

                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 64,
                      margin: EdgeInsets.only(
                        right: index == 5 ? 0 : AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: ext.surfaceContainerLowest.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: isFocused || isFilled
                              ? cs.onSurface.withValues(alpha: 0.42)
                              : ext.borderSubtle.withValues(
                                  alpha: ext.surfacePanelBorderAlpha,
                                ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isFilled ? digits[index] : '',
                          style: AppTypography.titleLg.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  cursorColor: Colors.transparent,
                  showCursor: false,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                    height: 1,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
