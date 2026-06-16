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
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final isEnabled = !isLoading && onPressed != null;
    final isInactive = !isEnabled && !isLoading;
    final backgroundColor = isInactive
        ? cs.onSurface.withValues(alpha: 0.10)
        : colors.bg;
    final foregroundColor = isInactive
        ? cs.onSurfaceVariant.withValues(alpha: 0.46)
        : colors.fg;
    final borderColor = isInactive
        ? cs.onSurfaceVariant.withValues(alpha: 0.22)
        : colors.border;

    return Semantics(
      button: true,
      enabled: isEnabled,
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            splashColor: isEnabled
                ? colors.fg.withValues(alpha: ext.pressedWhiteAlpha)
                : Colors.transparent,
            highlightColor: isEnabled ? null : Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                boxShadow: isEnabled && variant != MobiButtonVariant.ghost
                    ? ext.clayButtonShadow
                    : null,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: foregroundColor,
                        ),
                      )
                    : IconTheme(
                        data: IconThemeData(color: foregroundColor),
                        child: DefaultTextStyle(
                          style: AppTypography.titleMd.copyWith(
                            color: foregroundColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          child: isInactive
                              ? ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    foregroundColor,
                                    BlendMode.srcIn,
                                  ),
                                  child: child,
                                )
                              : child,
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
          bg: cs.onSurface,
          fg: cs.onInverseSurface,
          border: Colors.white.withValues(alpha: ext.surfacePanelBorderAlpha),
        );
      case MobiButtonVariant.whatsapp:
        return const _ButtonColors(
          bg: AppColors.whatsappGreen,
          fg: Colors.white,
          border: Color(0x1FFFFFFF),
        );
      case MobiButtonVariant.ghost:
        return _ButtonColors(
          bg: ext.surfaceContainerHigh.withValues(alpha: 0.72),
          fg: cs.onSurface,
          border: Colors.white.withValues(alpha: ext.cardBorderAlpha),
        );
      case MobiButtonVariant.danger:
        return _ButtonColors(
          bg: cs.error,
          fg: cs.onError,
          border: cs.error.withValues(alpha: 0.18),
        );
      case MobiButtonVariant.success:
        return _ButtonColors(
          bg: AppColors.brandMintGreen,
          fg: AppColors.onSuccess,
          border: AppColors.brandMintGreen.withValues(alpha: 0.24),
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
