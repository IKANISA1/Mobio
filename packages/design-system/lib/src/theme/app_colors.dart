import 'package:flutter/material.dart';

/// MOBI visual tokens.
///
/// Mobio logo colours remain brand identifiers. Product neutrals follow the
/// selected September 2026 Dark Glow reference. Native geometry/colours are
/// measured adapters; the historical public kit supplies named neutral roles.
class AppColors {
  AppColors._();

  // Current public SSO web colour definitions (WEB-STATE-002, 2026-09-05).
  // Native semantic use is an explicit adapter, not a native token export.
  // Logo masters retain their pixels; no UI role derives from their palette.
  static const primary = Color(0xFF6FA0FF);
  static const primaryLight = Color(0xFF315FD6); // light contrast adapter
  static const primaryDim = Color(0xFF5E5CE6);
  static const primaryFixed = Color(0xFFE3ECFC);
  static const primaryFixedDim = Color(0xFFC8D2E6);
  static const inversePrimary = primary;
  static const surfaceTint = primary;
  static const secondary = Color(0xFFBF5AF2);
  static const secondaryDim = Color(0xFF805CFF);
  static const secondaryFixed = Color(0xFFF1E5FC);
  static const secondaryFixedDim = Color(0xFFDDC8EE);
  static const onSecondary = Color(0xFF191C1F);
  static const onSecondaryFixed = Color(0xFF28133A);
  static const onSecondaryFixedVariant = Color(0xFF65407C);
  static const tertiary = Color(0xFF1AC097);
  static const tertiaryDim = Color(0xFF13D1A3);
  static const tertiaryFixed = Color(0xFFDFF6EF);
  static const tertiaryFixedDim = Color(0xFFBCEBDD);
  static const onTertiary = Color(0xFF002B22);
  static const onTertiaryFixed = onTertiary;
  static const onTertiaryFixedVariant = Color(0xFF075F4A);
  static const error = Color(0xFFFF5363);
  static const errorDim = Color(0xFFBA263B); // light contrast adapter
  static const onError = Color(0xFF191C1F);
  static const redAccent = error;
  static const success = tertiary;
  static const onSuccess = onTertiary;
  static const warning = Color(0xFFFF9F0A);
  static const onWarning = Color(0xFF191C1F);
  static const info = primary;
  static const infoDim = Color(0xFF0A84FF);
  static const infoContainer = Color(0xFF122B4B);
  static const onInfo = Color(0xFF000D19);
  static const onInfoContainer = Color(0xFFE3ECFC);
  static const aqua = Color(0xFF0CD9E6);
  static const aquaDim = Color(0xFF13D1A3);
  static const aquaContainer = Color(0xFF082A35);
  static const onAqua = Color(0xFF000D19);
  static const onAquaContainer = Color(0xFFDAF8FA);
  static const caution = warning;
  static const cautionDim = Color(0xFF9A5A00); // light contrast adapter
  static const cautionContainer = Color(0xFF332207);
  static const onCaution = onWarning;
  static const onCautionContainer = Color(0xFFFFE9C4);
  static const violetDepth = Color(0xFF16133A);
  static const blueDepth = Color(0xFF00043C);
  static const plumDepth = Color(0xFF302B7D);
  static const roseDepth = Color(0xFF28133A);
  static const mintDepth = Color(0xFF021920);
  static const orangeDepth = Color(0xFF330E0C);

  // ═══ Dark palette ═══
  static const dark = _DarkPalette();

  // ═══ Light palette ═══
  static const light = _LightPalette();
}

/// Dark mode surface/text tokens.
class _DarkPalette {
  const _DarkPalette();

  Color get background => const Color(0xFF000000);
  Color get surface => const Color(0xFF000000);
  Color get surfaceDim => const Color(0xFF000000);
  Color get surfaceBright => const Color(0xFF29292B);
  Color get surfaceContainerLowest => const Color(0xFF101012);
  Color get surfaceContainerLow => const Color(0xFF161618);
  Color get surfaceContainer => const Color(0xFF161618);
  Color get surfaceContainerHigh => const Color(0xFF222224);
  Color get surfaceContainerHighest => const Color(0xFF303033);
  Color get surfaceVariant => const Color(0xFF29292B);
  Color get onSurface => const Color(0xFFF4F4F4);
  Color get onSurfaceVariant => const Color(0xFFA1A1A3);
  Color get onSurfaceTertiary => const Color(0xFF909093);
  Color get onSurfaceDisabled => const Color(0xFF646467);
  Color get onBackground => const Color(0xFFF4F4F4);
  Color get inverseSurface => const Color(0xFFF4F4F4);
  Color get inverseOnSurface => const Color(0xFF090A12);
  Color get outline => const Color(0xFF555558);
  Color get outlineVariant => const Color(0xFF303033);
  Color get outlineStrong => const Color(0xFF707074);
  Color get outlineSubtle => const Color(0xFF29292C);
  Color get onPrimary => const Color(0xFF000D19);
  Color get primaryContainer => const Color(0xFF122B4B);
  Color get onPrimaryContainer => const Color(0xFFE3ECFC);
  Color get onPrimaryFixed => const Color(0xFF000D19);
  Color get onPrimaryFixedVariant => const Color(0xFF315FD6);
  Color get secondaryContainer => const Color(0xFF28133A);
  Color get onSecondaryContainer => const Color(0xFFF1E5FC);
  Color get errorContainer => const Color(0xFF330E0C);
  Color get onErrorContainer => const Color(0xFFFFDDE1);
  Color get tertiaryContainer => const Color(0xFF072D26);
  Color get onTertiaryContainer => const Color(0xFFDFF6EF);

  Color get gradientTop => const Color(0xFF3453FC);
  Color get gradientMid => const Color(0xFF03108D);
  Color get gradientBottom => background;
}

/// Light mode surface/text tokens.
class _LightPalette {
  const _LightPalette();

  Color get background => const Color(0xFFF4F4F4);
  Color get surface => const Color(0xFFF4F4F4);
  Color get surfaceDim => const Color(0xFFE2E2E2);
  Color get surfaceBright => const Color(0xFFFFFFFF);
  Color get surfaceContainerLowest => const Color(0xFFFFFFFF);
  Color get surfaceContainerLow => const Color(0xFFF7F7F7);
  Color get surfaceContainer => const Color(0xFFFFFFFF);
  Color get surfaceContainerHigh => const Color(0xFFEBEBEB);
  Color get surfaceContainerHighest => const Color(0xFFE2E2E2);
  Color get surfaceVariant => const Color(0xFFEDEDED);
  Color get onSurface => const Color(0xFF191C1F);
  Color get onSurfaceVariant => const Color(0xFF626265);
  Color get onSurfaceTertiary => const Color(0xFF717173);
  Color get onSurfaceDisabled => const Color(0xFF929296);
  Color get onBackground => const Color(0xFF191C1F);
  Color get inverseSurface => const Color(0xFF090A12);
  Color get inverseOnSurface => const Color(0xFFF4F4F4);
  Color get outline => const Color(0xFF8D8D91);
  Color get outlineVariant => const Color(0xFFC9C9CD);
  Color get outlineStrong => const Color(0xFF717173);
  Color get outlineSubtle => const Color(0xFFE2E2E7);
  Color get onPrimary => const Color(0xFFFFFFFF);
  Color get primaryContainer => const Color(0xFFE3ECFC);
  Color get onPrimaryContainer => const Color(0xFF122B4B);
  Color get onPrimaryFixed => const Color(0xFF000D19);
  Color get onPrimaryFixedVariant => const Color(0xFF315FD6);
  Color get secondaryContainer => const Color(0xFFF1E5FC);
  Color get onSecondaryContainer => const Color(0xFF28133A);
  Color get errorContainer => const Color(0xFFFFE5E8);
  Color get onErrorContainer => const Color(0xFF7C1928);
  Color get tertiaryContainer => const Color(0xFFDFF6EF);
  Color get onTertiaryContainer => const Color(0xFF075F4A);

  Color get gradientTop => const Color(0xFFDCE5FF);
  Color get gradientMid => const Color(0xFFE3ECFC);
  Color get gradientBottom => background;
}
