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
  final double surfacePanelAlpha;
  final double surfacePanelBorderAlpha;
  final double surfacePanelShadowAlpha;
  final double cardBorderAlpha;
  final double controlTrackAlpha;
  final double controlShadowAlpha;

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
    required this.surfacePanelAlpha,
    required this.surfacePanelBorderAlpha,
    required this.surfacePanelShadowAlpha,
    required this.cardBorderAlpha,
    required this.controlTrackAlpha,
    required this.controlShadowAlpha,
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
    double? surfacePanelAlpha,
    double? surfacePanelBorderAlpha,
    double? surfacePanelShadowAlpha,
    double? cardBorderAlpha,
    double? controlTrackAlpha,
    double? controlShadowAlpha,
  }) {
    return MobiThemeExtension(
      surfaceContainerLowest:
          surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      clayCardShadow: clayCardShadow ?? this.clayCardShadow,
      clayButtonShadow: clayButtonShadow ?? this.clayButtonShadow,
      clayCardGradientWhiteAlpha:
          clayCardGradientWhiteAlpha ?? this.clayCardGradientWhiteAlpha,
      glassCardBgAlpha: glassCardBgAlpha ?? this.glassCardBgAlpha,
      glassCardBorderWhiteAlpha:
          glassCardBorderWhiteAlpha ?? this.glassCardBorderWhiteAlpha,
      glassCardGradientWhiteAlpha:
          glassCardGradientWhiteAlpha ?? this.glassCardGradientWhiteAlpha,
      surfacePanelAlpha: surfacePanelAlpha ?? this.surfacePanelAlpha,
      surfacePanelBorderAlpha:
          surfacePanelBorderAlpha ?? this.surfacePanelBorderAlpha,
      surfacePanelShadowAlpha:
          surfacePanelShadowAlpha ?? this.surfacePanelShadowAlpha,
      cardBorderAlpha: cardBorderAlpha ?? this.cardBorderAlpha,
      controlTrackAlpha: controlTrackAlpha ?? this.controlTrackAlpha,
      controlShadowAlpha: controlShadowAlpha ?? this.controlShadowAlpha,
    );
  }

  @override
  MobiThemeExtension lerp(
    covariant ThemeExtension<MobiThemeExtension>? other,
    double t,
  ) {
    if (other is! MobiThemeExtension) return this;
    return MobiThemeExtension(
      surfaceContainerLowest: Color.lerp(
        surfaceContainerLowest,
        other.surfaceContainerLowest,
        t,
      )!,
      surfaceContainerLow: Color.lerp(
        surfaceContainerLow,
        other.surfaceContainerLow,
        t,
      )!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      )!,
      surfaceContainerHighest: Color.lerp(
        surfaceContainerHighest,
        other.surfaceContainerHighest,
        t,
      )!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      clayCardShadow: t < 0.5 ? clayCardShadow : other.clayCardShadow,
      clayButtonShadow: t < 0.5 ? clayButtonShadow : other.clayButtonShadow,
      clayCardGradientWhiteAlpha:
          clayCardGradientWhiteAlpha +
          (other.clayCardGradientWhiteAlpha - clayCardGradientWhiteAlpha) * t,
      glassCardBgAlpha:
          glassCardBgAlpha + (other.glassCardBgAlpha - glassCardBgAlpha) * t,
      glassCardBorderWhiteAlpha:
          glassCardBorderWhiteAlpha +
          (other.glassCardBorderWhiteAlpha - glassCardBorderWhiteAlpha) * t,
      glassCardGradientWhiteAlpha:
          glassCardGradientWhiteAlpha +
          (other.glassCardGradientWhiteAlpha - glassCardGradientWhiteAlpha) * t,
      surfacePanelAlpha:
          surfacePanelAlpha + (other.surfacePanelAlpha - surfacePanelAlpha) * t,
      surfacePanelBorderAlpha:
          surfacePanelBorderAlpha +
          (other.surfacePanelBorderAlpha - surfacePanelBorderAlpha) * t,
      surfacePanelShadowAlpha:
          surfacePanelShadowAlpha +
          (other.surfacePanelShadowAlpha - surfacePanelShadowAlpha) * t,
      cardBorderAlpha:
          cardBorderAlpha + (other.cardBorderAlpha - cardBorderAlpha) * t,
      controlTrackAlpha:
          controlTrackAlpha + (other.controlTrackAlpha - controlTrackAlpha) * t,
      controlShadowAlpha:
          controlShadowAlpha +
          (other.controlShadowAlpha - controlShadowAlpha) * t,
    );
  }
}
