import 'package:flutter/material.dart';

/// MOBI visual tokens.
///
/// Brand nodes come from the four-color logo direction. The app shell uses a
/// dark, immersive material system inspired by the Revolut reference while
/// retaining MOBI-owned product semantics.
class AppColors {
  AppColors._();

  // ─── Primary (mode-independent) ───
  static const brandPeriwinkle = Color(0xFF8885F0);
  static const brandDustyRose = Color(0xFFD38B96);
  static const brandOrangeRed = Color(0xFFFF5E43);
  static const brandMintGreen = Color(0xFF3CD070);

  static const primary = brandPeriwinkle;
  static const primaryDim = Color(0xFF6E6BE0);
  static const primaryFixed = Color(0xFFE8E7FF);
  static const primaryFixedDim = Color(0xFFC9C8FF);
  static const inversePrimary = Color(0xFFC7C5FF);
  static const surfaceTint = brandPeriwinkle;

  // ─── Secondary (mode-independent) ───
  static const secondary = brandDustyRose;
  static const secondaryDim = Color(0xFFB87480);
  static const secondaryFixed = Color(0xFFFFE6EA);
  static const secondaryFixedDim = Color(0xFFF5C8D0);
  static const onSecondary = Color(0xFF14070A);
  static const onSecondaryFixed = Color(0xFF3E171D);
  static const onSecondaryFixedVariant = Color(0xFF7D3D48);

  // ─── Tertiary (mode-independent) ───
  static const tertiary = brandMintGreen;
  static const tertiaryDim = Color(0xFF2AB45E);
  static const tertiaryFixed = Color(0xFFDDFBE8);
  static const tertiaryFixedDim = Color(0xFFBFF5D2);
  static const onTertiary = Color(0xFF031508);
  static const onTertiaryFixed = Color(0xFF063815);
  static const onTertiaryFixedVariant = Color(0xFF146733);

  // ─── Error (mode-independent) ───
  static const error = brandOrangeRed;
  static const errorDim = Color(0xFFD84831);
  static const onError = Color(0xFF1C0703);

  // ─── WhatsApp ───
  static const whatsappGreen = Color(0xFF25D366);
  static const whatsappDark = Color(0xFF128C7E);

  // ─── System (mode-independent) ───
  static const redAccent = brandOrangeRed;
  static const success = brandMintGreen;
  static const onSuccess = Color(0xFF031508);
  static const warning = Color(0xFFFFB14A);
  static const onWarning = Color(0xFF1C1000);

  // ─── Support semantics (mode-independent) ───
  static const info = Color(0xFF4D8DFF);
  static const infoDim = Color(0xFF2E69D8);
  static const infoContainer = Color(0xFF0F274F);
  static const onInfo = Color(0xFF061226);
  static const onInfoContainer = Color(0xFFD8E7FF);

  static const aqua = Color(0xFF5DE2E7);
  static const aquaDim = Color(0xFF33B7C0);
  static const aquaContainer = Color(0xFF0B3439);
  static const onAqua = Color(0xFF041415);
  static const onAquaContainer = Color(0xFFD7FAFC);

  static const caution = Color(0xFFFFB84D);
  static const cautionDim = Color(0xFFD98F25);
  static const cautionContainer = Color(0xFF3A2608);
  static const onCaution = Color(0xFF1B1000);
  static const onCautionContainer = Color(0xFFFFE7BD);

  static const violetDepth = Color(0xFF18124A);
  static const blueDepth = Color(0xFF10164B);
  static const plumDepth = Color(0xFF2A1639);
  static const roseDepth = Color(0xFF39202D);
  static const mintDepth = Color(0xFF0F3421);
  static const orangeDepth = Color(0xFF3E1510);

  // ═══ Dark palette ═══
  static const dark = _DarkPalette();

  // ═══ Light palette ═══
  static const light = _LightPalette();
}

/// Dark mode surface/text tokens.
class _DarkPalette {
  const _DarkPalette();

  Color get background => const Color(0xFF02030A);
  Color get surface => const Color(0xFF02030A);
  Color get surfaceDim => const Color(0xFF000105);
  Color get surfaceBright => const Color(0xFF111338);
  Color get surfaceContainerLowest => const Color(0xFF070812);
  Color get surfaceContainerLow => const Color(0xFF101120);
  Color get surfaceContainer => const Color(0xFF151627);
  Color get surfaceContainerHigh => const Color(0xFF1D1F33);
  Color get surfaceContainerHighest => const Color(0xFF272A42);
  Color get surfaceVariant => const Color(0xFF22243A);
  Color get onSurface => const Color(0xFFF7F7FF);
  Color get onSurfaceVariant => const Color(0xFFB9BBCD);
  Color get onSurfaceTertiary => const Color(0xFF8B8EA5);
  Color get onSurfaceDisabled => const Color(0xFF5E6278);
  Color get onBackground => const Color(0xFFF7F7FF);
  Color get inverseSurface => const Color(0xFFF7F7FF);
  Color get inverseOnSurface => const Color(0xFF090A12);
  Color get outline => const Color(0xFF5B5E78);
  Color get outlineVariant => const Color(0xFF35374E);
  Color get outlineStrong => const Color(0xFF686B86);
  Color get outlineSubtle => const Color(0xFF383B55);
  Color get onPrimary => const Color(0xFFFFFFFF);
  Color get primaryContainer => const Color(0xFF242155);
  Color get onPrimaryContainer => const Color(0xFFE7E6FF);
  Color get onPrimaryFixed => const Color(0xFF191547);
  Color get onPrimaryFixedVariant => const Color(0xFF4F4BD0);
  Color get secondaryContainer => const Color(0xFF372028);
  Color get onSecondaryContainer => const Color(0xFFFFE6EA);
  Color get errorContainer => const Color(0xFF3E1510);
  Color get onErrorContainer => const Color(0xFFFFD8D0);
  Color get tertiaryContainer => const Color(0xFF10351E);
  Color get onTertiaryContainer => const Color(0xFFDDFBE8);

  Color get gradientTop => AppColors.brandPeriwinkle;
  Color get gradientMid => AppColors.blueDepth;
  Color get gradientBottom => background;
}

/// Light mode surface/text tokens.
class _LightPalette {
  const _LightPalette();

  Color get background => const Color(0xFFF7F7FF);
  Color get surface => const Color(0xFFF7F7FF);
  Color get surfaceDim => const Color(0xFFE3E2F8);
  Color get surfaceBright => const Color(0xFFFFFFFF);
  Color get surfaceContainerLowest => const Color(0xFFFFFFFF);
  Color get surfaceContainerLow => const Color(0xFFF0EFFF);
  Color get surfaceContainer => const Color(0xFFE7E6FB);
  Color get surfaceContainerHigh => const Color(0xFFDEDCF5);
  Color get surfaceContainerHighest => const Color(0xFFD5D3EF);
  Color get surfaceVariant => const Color(0xFFE2E0F6);
  Color get onSurface => const Color(0xFF11121E);
  Color get onSurfaceVariant => const Color(0xFF62657D);
  Color get onSurfaceTertiary => const Color(0xFF777992);
  Color get onSurfaceDisabled => const Color(0xFFA0A1B6);
  Color get onBackground => const Color(0xFF11121E);
  Color get inverseSurface => const Color(0xFF090A12);
  Color get inverseOnSurface => const Color(0xFFF7F7FF);
  Color get outline => const Color(0xFFA8A9C1);
  Color get outlineVariant => const Color(0xFFD2D2E6);
  Color get outlineStrong => const Color(0xFF8D8FA8);
  Color get outlineSubtle => const Color(0xFFE2E2F0);
  Color get onPrimary => const Color(0xFFFFFFFF);
  Color get primaryContainer => const Color(0xFFE8E7FF);
  Color get onPrimaryContainer => const Color(0xFF242155);
  Color get onPrimaryFixed => const Color(0xFF191547);
  Color get onPrimaryFixedVariant => const Color(0xFF4F4BD0);
  Color get secondaryContainer => const Color(0xFFFFE6EA);
  Color get onSecondaryContainer => const Color(0xFF3E171D);
  Color get errorContainer => const Color(0xFFFFDFD8);
  Color get onErrorContainer => const Color(0xFF5A160E);
  Color get tertiaryContainer => const Color(0xFFDDFBE8);
  Color get onTertiaryContainer => const Color(0xFF063815);

  Color get gradientTop => const Color(0xFFC7C5FF);
  Color get gradientMid => const Color(0xFFE8E7FF);
  Color get gradientBottom => background;
}
