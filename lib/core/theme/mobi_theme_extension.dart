import 'package:flutter/material.dart';

/// ThemeExtension carrying custom tokens not available in standard [ColorScheme].
///
/// These non-MD3 tokens change between light and dark modes.
/// Access via: `Theme.of(context).extension<MobiThemeExtension>()!`
class MobiThemeExtension extends ThemeExtension<MobiThemeExtension> {
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceBright;
  final Color surfaceDim;
  final List<BoxShadow> clayCardShadow;
  final List<BoxShadow> clayButtonShadow;
  final double clayCardGradientWhiteAlpha;
  final double glassCardBgAlpha;
  final double glassCardBorderWhiteAlpha;
  final double glassCardGradientWhiteAlpha;

  const MobiThemeExtension({
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceBright,
    required this.surfaceDim,
    required this.clayCardShadow,
    required this.clayButtonShadow,
    required this.clayCardGradientWhiteAlpha,
    required this.glassCardBgAlpha,
    required this.glassCardBorderWhiteAlpha,
    required this.glassCardGradientWhiteAlpha,
  });

  @override
  MobiThemeExtension copyWith({
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? surfaceBright,
    Color? surfaceDim,
    List<BoxShadow>? clayCardShadow,
    List<BoxShadow>? clayButtonShadow,
    double? clayCardGradientWhiteAlpha,
    double? glassCardBgAlpha,
    double? glassCardBorderWhiteAlpha,
    double? glassCardGradientWhiteAlpha,
  }) {
    return MobiThemeExtension(
      surfaceContainerLowest: surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      clayCardShadow: clayCardShadow ?? this.clayCardShadow,
      clayButtonShadow: clayButtonShadow ?? this.clayButtonShadow,
      clayCardGradientWhiteAlpha: clayCardGradientWhiteAlpha ?? this.clayCardGradientWhiteAlpha,
      glassCardBgAlpha: glassCardBgAlpha ?? this.glassCardBgAlpha,
      glassCardBorderWhiteAlpha: glassCardBorderWhiteAlpha ?? this.glassCardBorderWhiteAlpha,
      glassCardGradientWhiteAlpha: glassCardGradientWhiteAlpha ?? this.glassCardGradientWhiteAlpha,
    );
  }

  @override
  MobiThemeExtension lerp(covariant ThemeExtension<MobiThemeExtension>? other, double t) {
    if (other is! MobiThemeExtension) return this;
    return MobiThemeExtension(
      surfaceContainerLowest: Color.lerp(surfaceContainerLowest, other.surfaceContainerLowest, t)!,
      surfaceContainerLow: Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh: Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceContainerHighest: Color.lerp(surfaceContainerHighest, other.surfaceContainerHighest, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      clayCardShadow: t < 0.5 ? clayCardShadow : other.clayCardShadow,
      clayButtonShadow: t < 0.5 ? clayButtonShadow : other.clayButtonShadow,
      clayCardGradientWhiteAlpha: clayCardGradientWhiteAlpha + (other.clayCardGradientWhiteAlpha - clayCardGradientWhiteAlpha) * t,
      glassCardBgAlpha: glassCardBgAlpha + (other.glassCardBgAlpha - glassCardBgAlpha) * t,
      glassCardBorderWhiteAlpha: glassCardBorderWhiteAlpha + (other.glassCardBorderWhiteAlpha - glassCardBorderWhiteAlpha) * t,
      glassCardGradientWhiteAlpha: glassCardGradientWhiteAlpha + (other.glassCardGradientWhiteAlpha - glassCardGradientWhiteAlpha) * t,
    );
  }
}
