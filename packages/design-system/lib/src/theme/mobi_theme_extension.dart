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
  final Color textTertiary;
  final Color textDisabled;
  final Color borderStrong;
  final Color borderSubtle;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color aqua;
  final Color aquaContainer;
  final Color onAquaContainer;
  final Color caution;
  final Color cautionContainer;
  final Color onCautionContainer;
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
  final double blackChromeAlpha;
  final double navChromeAlpha;
  final double hairlineAlpha;
  final double scrimAlpha;
  final double pressedWhiteAlpha;
  final double disabledAlpha;
  final Color backgroundGradientTop;
  final Color backgroundGradientMid;
  final Color backgroundGradientBottom;

  const MobiThemeExtension({
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceBright,
    required this.surfaceDim,
    required this.textTertiary,
    required this.textDisabled,
    required this.borderStrong,
    required this.borderSubtle,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.aqua,
    required this.aquaContainer,
    required this.onAquaContainer,
    required this.caution,
    required this.cautionContainer,
    required this.onCautionContainer,
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
    required this.blackChromeAlpha,
    required this.navChromeAlpha,
    required this.hairlineAlpha,
    required this.scrimAlpha,
    required this.pressedWhiteAlpha,
    required this.disabledAlpha,
    required this.backgroundGradientTop,
    required this.backgroundGradientMid,
    required this.backgroundGradientBottom,
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
    Color? textTertiary,
    Color? textDisabled,
    Color? borderStrong,
    Color? borderSubtle,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? aqua,
    Color? aquaContainer,
    Color? onAquaContainer,
    Color? caution,
    Color? cautionContainer,
    Color? onCautionContainer,
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
    double? blackChromeAlpha,
    double? navChromeAlpha,
    double? hairlineAlpha,
    double? scrimAlpha,
    double? pressedWhiteAlpha,
    double? disabledAlpha,
    Color? backgroundGradientTop,
    Color? backgroundGradientMid,
    Color? backgroundGradientBottom,
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
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      borderStrong: borderStrong ?? this.borderStrong,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      aqua: aqua ?? this.aqua,
      aquaContainer: aquaContainer ?? this.aquaContainer,
      onAquaContainer: onAquaContainer ?? this.onAquaContainer,
      caution: caution ?? this.caution,
      cautionContainer: cautionContainer ?? this.cautionContainer,
      onCautionContainer: onCautionContainer ?? this.onCautionContainer,
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
      blackChromeAlpha: blackChromeAlpha ?? this.blackChromeAlpha,
      navChromeAlpha: navChromeAlpha ?? this.navChromeAlpha,
      hairlineAlpha: hairlineAlpha ?? this.hairlineAlpha,
      scrimAlpha: scrimAlpha ?? this.scrimAlpha,
      pressedWhiteAlpha: pressedWhiteAlpha ?? this.pressedWhiteAlpha,
      disabledAlpha: disabledAlpha ?? this.disabledAlpha,
      backgroundGradientTop:
          backgroundGradientTop ?? this.backgroundGradientTop,
      backgroundGradientMid:
          backgroundGradientMid ?? this.backgroundGradientMid,
      backgroundGradientBottom:
          backgroundGradientBottom ?? this.backgroundGradientBottom,
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
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      aqua: Color.lerp(aqua, other.aqua, t)!,
      aquaContainer: Color.lerp(aquaContainer, other.aquaContainer, t)!,
      onAquaContainer: Color.lerp(onAquaContainer, other.onAquaContainer, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      cautionContainer: Color.lerp(
        cautionContainer,
        other.cautionContainer,
        t,
      )!,
      onCautionContainer: Color.lerp(
        onCautionContainer,
        other.onCautionContainer,
        t,
      )!,
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
      blackChromeAlpha:
          blackChromeAlpha + (other.blackChromeAlpha - blackChromeAlpha) * t,
      navChromeAlpha:
          navChromeAlpha + (other.navChromeAlpha - navChromeAlpha) * t,
      hairlineAlpha: hairlineAlpha + (other.hairlineAlpha - hairlineAlpha) * t,
      scrimAlpha: scrimAlpha + (other.scrimAlpha - scrimAlpha) * t,
      pressedWhiteAlpha:
          pressedWhiteAlpha + (other.pressedWhiteAlpha - pressedWhiteAlpha) * t,
      disabledAlpha: disabledAlpha + (other.disabledAlpha - disabledAlpha) * t,
      backgroundGradientTop: Color.lerp(
        backgroundGradientTop,
        other.backgroundGradientTop,
        t,
      )!,
      backgroundGradientMid: Color.lerp(
        backgroundGradientMid,
        other.backgroundGradientMid,
        t,
      )!,
      backgroundGradientBottom: Color.lerp(
        backgroundGradientBottom,
        other.backgroundGradientBottom,
        t,
      )!,
    );
  }
}
