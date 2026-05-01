import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

class BiopayStepSurface extends StatelessWidget {
  const BiopayStepSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: ext.clayCardShadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            ext.surfaceContainerLowest.withValues(alpha: 0.96),
            cs.surface.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: child,
    );
  }
}
