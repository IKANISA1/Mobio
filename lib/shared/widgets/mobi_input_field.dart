import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

/// Token-consistent text input field wrapper.
///
/// Enforces Mobio design system styling for all form inputs across the app.
/// Supports prefix/suffix icons, label, hint, error display, and
/// optional read-only tappable mode for picker-style inputs.
class MobiInputField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;

  const MobiInputField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.onTap,
    this.readOnly = false,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              label!,
              style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onTap: onTap,
          inputFormatters: inputFormatters,
          style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodySm.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            errorText: errorText,
            errorStyle: AppTypography.labelSm.copyWith(color: cs.error),
            filled: true,
            fillColor: ext.surfaceContainerLow,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: Icon(
                      prefixIcon,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : null,
            prefixIconConstraints: prefixIcon != null
                ? const BoxConstraints(minWidth: 48)
                : null,
            suffixIcon: suffixIcon != null
                ? GestureDetector(
                    onTap: onSuffixTap,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Icon(
                        suffixIcon,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: suffixIcon != null
                ? const BoxConstraints(minWidth: 44)
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              borderSide: BorderSide(color: cs.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              borderSide: BorderSide(color: cs.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              borderSide: BorderSide(color: cs.error),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
