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
        // ── Layer 1: Radial gradient background ──
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.5,
              colors: [ext.surfaceContainerLow, cs.surface],
            ),
          ),
        ),

        // ── Layer 2: Content ──
        child,
      ],
    );
  }
}
