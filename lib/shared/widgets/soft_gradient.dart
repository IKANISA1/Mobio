import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

enum SoftGradientTone { shell, nearby, profile, success, alert }

/// Full-screen immersive background layer.
class SoftGradient extends StatelessWidget {
  final Widget child;
  final SoftGradientTone tone;

  const SoftGradient({
    super.key,
    required this.child,
    this.tone = SoftGradientTone.shell,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final colors = _colorsFor(ext);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.42, 1],
              colors: colors,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: ext.scrimAlpha * 0.38),
                Colors.black.withValues(alpha: ext.scrimAlpha),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }

  List<Color> _colorsFor(MobiThemeExtension ext) {
    return switch (tone) {
      SoftGradientTone.shell => [
        ext.backgroundGradientTop,
        ext.backgroundGradientMid,
        ext.backgroundGradientBottom,
      ],
      SoftGradientTone.nearby => [
        AppColors.aqua,
        AppColors.aquaContainer,
        ext.backgroundGradientBottom,
      ],
      SoftGradientTone.profile => [
        AppColors.brandDustyRose,
        AppColors.roseDepth,
        ext.backgroundGradientBottom,
      ],
      SoftGradientTone.success => [
        AppColors.brandMintGreen,
        AppColors.mintDepth,
        ext.backgroundGradientBottom,
      ],
      SoftGradientTone.alert => [
        AppColors.brandOrangeRed,
        AppColors.orangeDepth,
        ext.backgroundGradientBottom,
      ],
    };
  }
}
