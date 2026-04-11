import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Readability-first foreground surface that preserves the current MOBI system.
///
/// Use this for headers, section chrome, and other UI that should never sit
/// directly on top of the moving promo background.
class MobiSurfacePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  const MobiSurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppRadii.xxl,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            color ??
            ext.surfaceContainerLowest.withValues(alpha: ext.surfacePanelAlpha),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(
            alpha: ext.surfacePanelBorderAlpha,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: ext.surfacePanelShadowAlpha),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
