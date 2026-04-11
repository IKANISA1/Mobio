import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_shadows.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

class AppTheme {
  AppTheme._();

  // ═══ Dark Theme ═══
  static ThemeData get darkTheme {
    const d = AppColors.dark;
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
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
          clayCardGradientWhiteAlpha: 0.015,
          glassCardBgAlpha: 0.78,
          glassCardBorderWhiteAlpha: 0.08,
          glassCardGradientWhiteAlpha: 0.015,
          surfacePanelAlpha: 0.92,
          surfacePanelBorderAlpha: 0.32,
          surfacePanelShadowAlpha: 0.12,
          cardBorderAlpha: 0.26,
          controlTrackAlpha: 0.88,
          controlShadowAlpha: 0.12,
        ),
      ],
      textTheme: _textTheme(base.textTheme, d.onSurface, d.onSurfaceVariant),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: d.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        baseColor: d.surfaceContainerLow,
        hintColor: d.onSurfaceVariant,
        borderColor: d.outlineVariant,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: d.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: d.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.hero),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: d.surfaceContainerHigh,
        contentTextStyle: AppTypography.bodySm.copyWith(color: d.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        iconColor: d.onSurfaceVariant,
      ),
      splashFactory: InkRipple.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }

  // ═══ Light Theme ═══
  static ThemeData get lightTheme {
    const l = AppColors.light;
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
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
          clayCardGradientWhiteAlpha: 0.28,
          glassCardBgAlpha: 0.9,
          glassCardBorderWhiteAlpha: 0.28,
          glassCardGradientWhiteAlpha: 0.06,
          surfacePanelAlpha: 0.98,
          surfacePanelBorderAlpha: 0.78,
          surfacePanelShadowAlpha: 0.04,
          cardBorderAlpha: 0.46,
          controlTrackAlpha: 1,
          controlShadowAlpha: 0.05,
        ),
      ],
      textTheme: _textTheme(base.textTheme, l.onSurface, l.onSurfaceVariant),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: l.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        baseColor: l.surfaceContainerLowest,
        hintColor: l.onSurfaceVariant,
        borderColor: l.outlineVariant,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: l.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: l.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.hero),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: l.surfaceContainerHighest,
        contentTextStyle: AppTypography.bodySm.copyWith(color: l.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        iconColor: l.onSurfaceVariant,
      ),
      splashFactory: InkRipple.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color onSurface,
    Color onSurfaceVariant,
  ) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: AppTypography.displayLg.copyWith(color: onSurface),
      displayMedium: AppTypography.displayMd.copyWith(color: onSurface),
      headlineLarge: AppTypography.headlineLg.copyWith(color: onSurface),
      headlineMedium: AppTypography.headlineMd.copyWith(color: onSurface),
      titleLarge: AppTypography.titleLg.copyWith(color: onSurface),
      titleMedium: AppTypography.titleMd.copyWith(color: onSurface),
      bodyLarge: AppTypography.bodyLg.copyWith(color: onSurface),
      bodyMedium: AppTypography.bodyMd.copyWith(color: onSurface),
      bodySmall: AppTypography.bodySm.copyWith(color: onSurfaceVariant),
      labelLarge: AppTypography.labelLg.copyWith(color: onSurface),
      labelMedium: AppTypography.labelMd.copyWith(color: onSurfaceVariant),
      labelSmall: AppTypography.labelSm.copyWith(color: onSurfaceVariant),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required Color baseColor,
    required Color hintColor,
    required Color borderColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: baseColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      hintStyle: AppTypography.bodySm.copyWith(color: hintColor),
      labelStyle: AppTypography.labelMd.copyWith(color: hintColor),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
