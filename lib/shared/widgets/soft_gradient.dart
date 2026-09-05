import 'package:flutter/material.dart';

enum SoftGradientTone { neutral, shell, nearby, profile, success, alert }

/// Page canvas. Glow belongs to overviews; tasks and settings stay neutral.
/// The blue stops are measured adapters for September 2026 Dark · Glow.
class SoftGradient extends StatelessWidget {
  final Widget child;
  final SoftGradientTone tone;
  const SoftGradient({
    super.key,
    required this.child,
    this.tone = SoftGradientTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glow = tone == SoftGradientTone.shell;
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        gradient: glow
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.22, 0.56, 1],
                colors: dark
                    ? const [
                        Color(0xFF567EFF),
                        Color(0xFF1625DC),
                        Color(0xFF050543),
                        Color(0xFF000000),
                      ]
                    : const [
                        Color(0xFFCEDCFF),
                        Color(0xFFEDF1FF),
                        Color(0xFFF4F4F4),
                        Color(0xFFF4F4F4),
                      ],
              )
            : null,
      ),
      child: SizedBox.expand(child: child),
    );
  }
}
