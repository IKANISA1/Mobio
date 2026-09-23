import 'package:flutter/material.dart';

/// A tappable icon button with proper 48×48dp minimum touch target,
/// ink ripple feedback, and opacity animation on press.
///
/// Use this for all icon-only tap targets (back arrows, action icons, etc.)
/// to ensure Material touch-target compliance and instant user feedback.
class TappableIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final double touchTargetSize;
  final String? semanticLabel;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? borderRadius;

  const TappableIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 24,
    this.color,
    this.touchTargetSize = 48,
    this.semanticLabel,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        iconColor ?? color ?? Theme.of(context).colorScheme.primary;
    final resolvedRadius = borderRadius ?? touchTargetSize / 2;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel ?? 'Icon button',
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: SizedBox(
          width: touchTargetSize,
          height: touchTargetSize,
          child: Material(
            color: backgroundColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(resolvedRadius),
            child: InkWell(
              onTap: onTap == null
                  ? null
                  : () {
                      Feedback.forTap(context);
                      onTap!();
                    },
              borderRadius: BorderRadius.circular(resolvedRadius),
              splashColor: resolvedColor.withValues(alpha: 0.15),
              highlightColor: resolvedColor.withValues(alpha: 0.08),
              child: Center(
                child: Icon(icon, size: size, color: resolvedColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
