import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Matches transito's `.soft-gradient` CSS class.
/// A radial gradient background: `surfaceContainerLow → background`.
class SoftGradient extends StatelessWidget {
  final Widget child;

  const SoftGradient({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            ext.surfaceContainerLow,
            cs.surface,
          ],
        ),
      ),
      child: child,
    );
  }
}
