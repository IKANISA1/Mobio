import 'package:flutter/material.dart';

/// All color tokens from the transito design system (index.css).
/// Mode-independent brand colors at root level.
/// Mode-dependent surface/text colors in nested [dark] and [light] classes.
class AppColors {
  AppColors._();

  // ─── Primary (mode-independent) ───
  static const primary = Color(0xFF006D2F);
  static const primaryDim = Color(0xFF006028);
  static const primaryFixed = Color(0xFF66FF8E);
  static const primaryFixedDim = Color(0xFF50F17F);
  static const inversePrimary = Color(0xFF5DFD8A);
  static const surfaceTint = Color(0xFF006D2F);

  // ─── Secondary (mode-independent) ───
  static const secondary = Color(0xFF545F77);
  static const secondaryDim = Color(0xFF48536A);
  static const secondaryFixed = Color(0xFFD7E2FF);
  static const secondaryFixedDim = Color(0xFFC9D4F0);
  static const onSecondary = Color(0xFFF9F8FF);
  static const onSecondaryFixed = Color(0xFF353F56);
  static const onSecondaryFixedVariant = Color(0xFF515C73);

  // ─── Tertiary (mode-independent) ───
  static const tertiary = Color(0xFF48617E);
  static const tertiaryDim = Color(0xFF3C5572);
  static const tertiaryFixed = Color(0xFFC2DCFF);
  static const tertiaryFixedDim = Color(0xFFB4CEF0);
  static const onTertiary = Color(0xFFF7F9FF);
  static const onTertiaryFixed = Color(0xFF223C57);
  static const onTertiaryFixedVariant = Color(0xFF3F5875);

  // ─── Error (mode-independent) ───
  static const error = Color(0xFF9F403D);
  static const errorDim = Color(0xFF4E0309);
  static const onError = Color(0xFFFFF7F6);

  // ─── WhatsApp ───
  static const whatsappGreen = Color(0xFF25D366);
  static const whatsappDark = Color(0xFF128C7E);

  // ─── System (mode-independent) ───
  static const redAccent = Color(0xFFEF5350);
  static const success = Color(0xFF4CAF50);
  static const onSuccess = Color(0xFFFFFFFF);
  static const warning = Color(0xFFFF9800);
  static const onWarning = Color(0xFFFFFFFF);

  // ─── BioPay brand accent ───
  static const bioPayGreen = Color(0xFF00C853);

  // ═══ Dark palette ═══
  static const dark = _DarkPalette();

  // ═══ Light palette ═══
  static const light = _LightPalette();
}

/// Dark mode surface/text tokens (from transito `.dark` CSS overrides).
class _DarkPalette {
  const _DarkPalette();

  Color get background => const Color(0xFF0C0F10);
  Color get surface => const Color(0xFF0C0F10);
  Color get surfaceDim => const Color(0xFF0C0F10);
  Color get surfaceBright => const Color(0xFF1A1C1E);
  Color get surfaceContainerLowest => const Color(0xFF080A0B);
  Color get surfaceContainerLow => const Color(0xFF141618);
  Color get surfaceContainer => const Color(0xFF1A1C1E);
  Color get surfaceContainerHigh => const Color(0xFF212426);
  Color get surfaceContainerHighest => const Color(0xFF2B2E30);
  Color get surfaceVariant => const Color(0xFF2B2E30);
  Color get onSurface => const Color(0xFFF8F9FA);
  Color get onSurfaceVariant => const Color(0xFFABB3B7);
  Color get onBackground => const Color(0xFFF8F9FA);
  Color get inverseSurface => const Color(0xFF0C0F10);
  Color get inverseOnSurface => const Color(0xFF9B9D9E);
  Color get outline => const Color(0xFF586064);
  Color get outlineVariant => const Color(0xFF44474A);
  Color get onPrimary => const Color(0xFFE4FFE2);
  Color get primaryContainer => const Color(0xFF005221);
  Color get onPrimaryContainer => const Color(0xFF66FF8E);
  Color get onPrimaryFixed => const Color(0xFF004A1E);
  Color get onPrimaryFixedVariant => const Color(0xFF006A2E);
  Color get secondaryContainer => const Color(0xFF353F56);
  Color get onSecondaryContainer => const Color(0xFFD7E2FF);
  Color get errorContainer => const Color(0xFF4E0309);
  Color get onErrorContainer => const Color(0xFFFE8983);
  Color get tertiaryContainer => const Color(0xFF3C5572);
  Color get onTertiaryContainer => const Color(0xFFC2DCFF);
}

/// Light mode surface/text tokens (from transito CSS root defaults).
class _LightPalette {
  const _LightPalette();

  Color get background => const Color(0xFFF8F9FA);
  Color get surface => const Color(0xFFF8F9FA);
  Color get surfaceDim => const Color(0xFFD1DCE0);
  Color get surfaceBright => const Color(0xFFF8F9FA);
  Color get surfaceContainerLowest => const Color(0xFFFFFFFF);
  Color get surfaceContainerLow => const Color(0xFFF1F4F6);
  Color get surfaceContainer => const Color(0xFFEAEFF1);
  Color get surfaceContainerHigh => const Color(0xFFE3E9EC);
  Color get surfaceContainerHighest => const Color(0xFFDBE4E7);
  Color get surfaceVariant => const Color(0xFFDBE4E7);
  Color get onSurface => const Color(0xFF2B3437);
  Color get onSurfaceVariant => const Color(0xFF586064);
  Color get onBackground => const Color(0xFF2B3437);
  Color get inverseSurface => const Color(0xFF0C0F10);
  Color get inverseOnSurface => const Color(0xFF9B9D9E);
  Color get outline => const Color(0xFF737C7F);
  Color get outlineVariant => const Color(0xFFABB3B7);
  Color get onPrimary => const Color(0xFFE4FFE2);
  Color get primaryContainer => const Color(0xFF66FF8E);
  Color get onPrimaryContainer => const Color(0xFF005F28);
  Color get onPrimaryFixed => const Color(0xFF004A1E);
  Color get onPrimaryFixedVariant => const Color(0xFF006A2E);
  Color get secondaryContainer => const Color(0xFFD7E2FF);
  Color get onSecondaryContainer => const Color(0xFF475269);
  Color get errorContainer => const Color(0xFFFE8983);
  Color get onErrorContainer => const Color(0xFF752121);
  Color get tertiaryContainer => const Color(0xFFC2DCFF);
  Color get onTertiaryContainer => const Color(0xFF354E6B);
}
