import 'package:flutter/material.dart';

/// All color tokens from the transito design system (index.css).
/// Mode-independent brand colors at root level.
/// Mode-dependent surface/text colors in nested [dark] and [light] classes.
class AppColors {
  AppColors._();

  // ─── Primary (mode-independent) ───
  static const primary = Color(0xFF006D2F);
  static const primaryDim = Color(0xFF005726);
  static const primaryFixed = Color(0xFFDDF6E5);
  static const primaryFixedDim = Color(0xFFC8ECCE);
  static const inversePrimary = Color(0xFF81D39D);
  static const surfaceTint = Color(0xFF006D2F);

  // ─── Secondary (mode-independent) ───
  static const secondary = Color(0xFF4E5C59);
  static const secondaryDim = Color(0xFF3E4B48);
  static const secondaryFixed = Color(0xFFE4ECE9);
  static const secondaryFixedDim = Color(0xFFD3DDDA);
  static const onSecondary = Color(0xFFFFFFFF);
  static const onSecondaryFixed = Color(0xFF21302C);
  static const onSecondaryFixedVariant = Color(0xFF475754);

  // ─── Tertiary (mode-independent) ───
  static const tertiary = Color(0xFF3D5C79);
  static const tertiaryDim = Color(0xFF314C65);
  static const tertiaryFixed = Color(0xFFD9E8F6);
  static const tertiaryFixedDim = Color(0xFFC5D8EA);
  static const onTertiary = Color(0xFFFFFFFF);
  static const onTertiaryFixed = Color(0xFF1D3447);
  static const onTertiaryFixedVariant = Color(0xFF3A5670);

  // ─── Error (mode-independent) ───
  static const error = Color(0xFFB2463F);
  static const errorDim = Color(0xFF7D2B26);
  static const onError = Color(0xFFFFFFFF);

  // ─── WhatsApp ───
  static const whatsappGreen = Color(0xFF25D366);
  static const whatsappDark = Color(0xFF128C7E);

  // ─── System (mode-independent) ───
  static const redAccent = Color(0xFFEF5350);
  static const success = Color(0xFF4CAF50);
  static const onSuccess = Color(0xFFFFFFFF);
  static const warning = Color(0xFFFF9800);
  static const onWarning = Color(0xFFFFFFFF);

  // ═══ Dark palette ═══
  static const dark = _DarkPalette();

  // ═══ Light palette ═══
  static const light = _LightPalette();
}

/// Dark mode surface/text tokens (from transito `.dark` CSS overrides).
class _DarkPalette {
  const _DarkPalette();

  Color get background => const Color(0xFF0F1113);
  Color get surface => const Color(0xFF0F1113);
  Color get surfaceDim => const Color(0xFF0B0D0F);
  Color get surfaceBright => const Color(0xFF171A1C);
  Color get surfaceContainerLowest => const Color(0xFF14171A);
  Color get surfaceContainerLow => const Color(0xFF191D20);
  Color get surfaceContainer => const Color(0xFF1F2427);
  Color get surfaceContainerHigh => const Color(0xFF252B2F);
  Color get surfaceContainerHighest => const Color(0xFF2D3438);
  Color get surfaceVariant => const Color(0xFF252B2F);
  Color get onSurface => const Color(0xFFF4F6F5);
  Color get onSurfaceVariant => const Color(0xFF9FA8A4);
  Color get onBackground => const Color(0xFFF4F6F5);
  Color get inverseSurface => const Color(0xFFF4F6F5);
  Color get inverseOnSurface => const Color(0xFF1E2326);
  Color get outline => const Color(0xFF434C49);
  Color get outlineVariant => const Color(0xFF313836);
  Color get onPrimary => const Color(0xFFF5FFF6);
  Color get primaryContainer => const Color(0xFF123921);
  Color get onPrimaryContainer => const Color(0xFF8DDEAA);
  Color get onPrimaryFixed => const Color(0xFF004A1E);
  Color get onPrimaryFixedVariant => const Color(0xFF006A2E);
  Color get secondaryContainer => const Color(0xFF24312E);
  Color get onSecondaryContainer => const Color(0xFFD8E3DF);
  Color get errorContainer => const Color(0xFF41201D);
  Color get onErrorContainer => const Color(0xFFF2B0AC);
  Color get tertiaryContainer => const Color(0xFF23374A);
  Color get onTertiaryContainer => const Color(0xFFD5E6F7);
}

/// Light mode surface/text tokens (from transito CSS root defaults).
class _LightPalette {
  const _LightPalette();

  Color get background => const Color(0xFFF6F7F5);
  Color get surface => const Color(0xFFF6F7F5);
  Color get surfaceDim => const Color(0xFFE5EAE6);
  Color get surfaceBright => const Color(0xFFFFFFFF);
  Color get surfaceContainerLowest => const Color(0xFFFFFFFF);
  Color get surfaceContainerLow => const Color(0xFFF0F3F0);
  Color get surfaceContainer => const Color(0xFFE9EEEA);
  Color get surfaceContainerHigh => const Color(0xFFE2E8E3);
  Color get surfaceContainerHighest => const Color(0xFFDBE2DC);
  Color get surfaceVariant => const Color(0xFFE2E8E3);
  Color get onSurface => const Color(0xFF171B18);
  Color get onSurfaceVariant => const Color(0xFF65706B);
  Color get onBackground => const Color(0xFF171B18);
  Color get inverseSurface => const Color(0xFF1E2320);
  Color get inverseOnSurface => const Color(0xFFF2F4F2);
  Color get outline => const Color(0xFFB4BDB7);
  Color get outlineVariant => const Color(0xFFD4DBD6);
  Color get onPrimary => const Color(0xFFFFFFFF);
  Color get primaryContainer => const Color(0xFFDFF2E4);
  Color get onPrimaryContainer => const Color(0xFF114E2A);
  Color get onPrimaryFixed => const Color(0xFF004A1E);
  Color get onPrimaryFixedVariant => const Color(0xFF006A2E);
  Color get secondaryContainer => const Color(0xFFE3ECE8);
  Color get onSecondaryContainer => const Color(0xFF31413D);
  Color get errorContainer => const Color(0xFFF5DFDD);
  Color get onErrorContainer => const Color(0xFF7B2B26);
  Color get tertiaryContainer => const Color(0xFFDDE7F1);
  Color get onTertiaryContainer => const Color(0xFF264259);
}
