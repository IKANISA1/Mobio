import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Glass-morphism card matching transito's `.glass-card`.
/// Semi-transparent + blur, used for headers and bottom nav.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final BorderRadius? customBorderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 40,
    this.customBorderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final br = customBorderRadius ?? BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ext.surfaceContainerLowest.withValues(
              alpha: ext.glassCardBgAlpha,
            ),
            borderRadius: br,
            border: Border.all(
              color: Colors.white.withValues(
                alpha: ext.glassCardBorderWhiteAlpha,
              ),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: ext.glassCardGradientWhiteAlpha),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
