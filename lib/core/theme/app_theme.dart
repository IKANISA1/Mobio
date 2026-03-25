import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_shadows.dart';
import 'mobi_theme_extension.dart';

class AppTheme {
  AppTheme._();

  // ═══ Dark Theme ═══
  static ThemeData get darkTheme {
    final d = AppColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: d.background,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: d.onPrimary,
        primaryContainer: d.primaryContainer,
        onPrimaryContainer: d.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: d.secondaryContainer,
        onSecondaryContainer: d.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: d.tertiaryContainer,
        onTertiaryContainer: d.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: d.errorContainer,
        onErrorContainer: d.onErrorContainer,
        surface: d.surface,
        onSurface: d.onSurface,
        onSurfaceVariant: d.onSurfaceVariant,
        outline: d.outline,
        outlineVariant: d.outlineVariant,
        inverseSurface: d.inverseSurface,
        inversePrimary: AppColors.inversePrimary,
      ),
      extensions: [
        MobiThemeExtension(
          surfaceContainerLowest: d.surfaceContainerLowest,
          surfaceContainerLow: d.surfaceContainerLow,
          surfaceContainer: d.surfaceContainer,
          surfaceContainerHigh: d.surfaceContainerHigh,
          surfaceContainerHighest: d.surfaceContainerHighest,
          surfaceBright: d.surfaceBright,
          surfaceDim: d.surfaceDim,
          clayCardShadow: AppShadows.clayCard,
          clayButtonShadow: AppShadows.clayButton,
          clayCardGradientWhiteAlpha: 0.03,
          glassCardBgAlpha: 0.4,
          glassCardBorderWhiteAlpha: 0.05,
          glassCardGradientWhiteAlpha: 0.02,
        ),
      ],
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }

  // ═══ Light Theme ═══
  static ThemeData get lightTheme {
    final l = AppColors.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: l.background,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: l.onPrimary,
        primaryContainer: l.primaryContainer,
        onPrimaryContainer: l.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: l.secondaryContainer,
        onSecondaryContainer: l.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: l.tertiaryContainer,
        onTertiaryContainer: l.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: l.errorContainer,
        onErrorContainer: l.onErrorContainer,
        surface: l.surface,
        onSurface: l.onSurface,
        onSurfaceVariant: l.onSurfaceVariant,
        outline: l.outline,
        outlineVariant: l.outlineVariant,
        inverseSurface: l.inverseSurface,
        inversePrimary: AppColors.inversePrimary,
      ),
      extensions: [
        MobiThemeExtension(
          surfaceContainerLowest: l.surfaceContainerLowest,
          surfaceContainerLow: l.surfaceContainerLow,
          surfaceContainer: l.surfaceContainer,
          surfaceContainerHigh: l.surfaceContainerHigh,
          surfaceContainerHighest: l.surfaceContainerHighest,
          surfaceBright: l.surfaceBright,
          surfaceDim: l.surfaceDim,
          clayCardShadow: AppShadows.lightClayCard,
          clayButtonShadow: AppShadows.lightClayButton,
          clayCardGradientWhiteAlpha: 0.4,
          glassCardBgAlpha: 0.6,
          glassCardBorderWhiteAlpha: 0.2,
          glassCardGradientWhiteAlpha: 0.1,
        ),
      ],
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
