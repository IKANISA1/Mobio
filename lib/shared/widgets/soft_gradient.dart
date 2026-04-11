import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Full-screen background layer using a classic radial gradient.
///
/// Provides a consistent, clean surface behind app content.
/// Cards and containers sit on top with their own opaque backgrounds.
class SoftGradient extends StatelessWidget {
  final Widget child;

  const SoftGradient({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ext.surfaceBright, cs.surface],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
