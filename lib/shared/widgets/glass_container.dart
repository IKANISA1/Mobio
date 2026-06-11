import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Floating translucent panel for persistent chrome such as bottom navigation.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final BorderRadius? customBorderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadii.hero,
    this.customBorderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final br = customBorderRadius ?? BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
              width: 1.1,
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
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.sm),
            child: child,
          ),
        ),
      ),
    );
  }
}
