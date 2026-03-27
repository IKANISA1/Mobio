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

  const TappableIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 24,
    this.color,
    this.touchTargetSize = 48,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: semanticLabel ?? 'Icon button',
      excludeSemantics: true,
      child: SizedBox(
        width: touchTargetSize,
        height: touchTargetSize,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(touchTargetSize / 2),
            splashColor: resolvedColor.withValues(alpha: 0.15),
            highlightColor: resolvedColor.withValues(alpha: 0.08),
            child: Center(
              child: Icon(
                icon,
                size: size,
                color: resolvedColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
