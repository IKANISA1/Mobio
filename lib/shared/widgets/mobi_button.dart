import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

enum MobiButtonVariant { primary, whatsapp, ghost, danger, success }

class MobiButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final MobiButtonVariant variant;
  final bool isLoading;
  final double? width;
  final EdgeInsetsGeometry? padding;

  const MobiButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = MobiButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(context);
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final isEnabled = !isLoading && onPressed != null;

    return Semantics(
      button: true,
      enabled: isEnabled,
      child: SizedBox(
        width: width,
        child: Opacity(
          opacity: isEnabled || isLoading ? 1 : 0.62,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              splashColor: colors.fg.withValues(alpha: 0.08),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    padding ??
                    const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: variant == MobiButtonVariant.ghost
                      ? null
                      : ext.clayButtonShadow,
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.fg,
                          ),
                        )
                      : DefaultTextStyle(
                          style: AppTypography.titleMd.copyWith(
                            color: colors.fg,
                          ),
                          child: child,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ButtonColors _getColors(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    switch (variant) {
      case MobiButtonVariant.primary:
        return _ButtonColors(
          bg: cs.primary,
          fg: cs.onPrimary,
          border: cs.primary.withValues(alpha: 0.18),
        );
      case MobiButtonVariant.whatsapp:
        return const _ButtonColors(
          bg: AppColors.whatsappGreen,
          fg: Colors.white,
          border: Color(0x1FFFFFFF),
        );
      case MobiButtonVariant.ghost:
        return _ButtonColors(
          bg: ext.surfaceContainerLowest,
          fg: cs.onSurface,
          border: cs.outlineVariant.withValues(alpha: 0.6),
        );
      case MobiButtonVariant.danger:
        return _ButtonColors(
          bg: cs.error,
          fg: cs.onError,
          border: cs.error.withValues(alpha: 0.18),
        );
      case MobiButtonVariant.success:
        return _ButtonColors(
          bg: AppColors.surfaceTint,
          fg: cs.onPrimary,
          border: cs.primary.withValues(alpha: 0.18),
        );
    }
  }
}

class _ButtonColors {
  final Color bg;
  final Color fg;
  final Color border;
  const _ButtonColors({
    required this.bg,
    required this.fg,
    required this.border,
  });
}
