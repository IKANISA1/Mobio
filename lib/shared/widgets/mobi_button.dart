import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_shadows.dart';
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
    return Semantics(
      button: true,
      enabled: !isLoading && onPressed != null,
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(100),
            splashColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                gradient: colors.gradient,
                color: colors.gradient == null ? colors.bg : null,
                borderRadius: BorderRadius.circular(100),
                boxShadow: AppShadows.premium,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
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
                        style: AppTypography.titleMd.copyWith(color: colors.fg),
                        child: child,
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, AppColors.primaryDim],
          ),
        );
      case MobiButtonVariant.whatsapp:
        return const _ButtonColors(
          bg: AppColors.whatsappGreen,
          fg: Colors.white,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.whatsappGreen, AppColors.whatsappDark],
          ),
        );
      case MobiButtonVariant.ghost:
        return _ButtonColors(
          bg: ext.surfaceContainerHigh,
          fg: cs.onSurface,
        );
      case MobiButtonVariant.danger:
        return _ButtonColors(
          bg: cs.error,
          fg: cs.onError,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.error, AppColors.errorDim],
          ),
        );
      case MobiButtonVariant.success:
        return _ButtonColors(
          bg: AppColors.surfaceTint,
          fg: cs.onPrimary,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceTint, AppColors.primaryDim],
          ),
        );
    }
  }
}

class _ButtonColors {
  final Color bg;
  final Color fg;
  final Gradient? gradient;
  const _ButtonColors({required this.bg, required this.fg, this.gradient});
}
