import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/app_colors.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class AppTheme {
  AppTheme._();

  // ═══ Dark Theme ═══
  static ThemeData get darkTheme {
    const d = AppColors.dark;
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return _referenceControls(
      ThemeData(
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
          surfaceContainerLowest: d.surfaceContainerLowest,
          surfaceContainerLow: d.surfaceContainerLow,
          surfaceContainer: d.surfaceContainer,
          surfaceContainerHigh: d.surfaceContainerHigh,
          surfaceContainerHighest: d.surfaceContainerHighest,
          surfaceBright: d.surfaceBright,
          surfaceDim: d.surfaceDim,
          onInverseSurface: d.inverseOnSurface,
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
            textTertiary: d.onSurfaceTertiary,
            textDisabled: d.onSurfaceDisabled,
            borderStrong: d.outlineStrong,
            borderSubtle: d.outlineSubtle,
            info: AppColors.info,
            infoContainer: AppColors.infoContainer,
            onInfoContainer: AppColors.onInfoContainer,
            aqua: AppColors.aqua,
            aquaContainer: AppColors.aquaContainer,
            onAquaContainer: AppColors.onAquaContainer,
            caution: AppColors.caution,
            cautionContainer: AppColors.cautionContainer,
            onCautionContainer: AppColors.onCautionContainer,
            surfacePanelAlpha: 0.82,
            surfacePanelBorderAlpha: 0.08,
            surfacePanelShadowAlpha: 0.08,
            cardBorderAlpha: 0.06,
            controlTrackAlpha: 0.88,
            controlShadowAlpha: 0.12,
            blackChromeAlpha: 0.72,
            navChromeAlpha: 0.88,
            hairlineAlpha: 0.12,
            scrimAlpha: 0.72,
            pressedWhiteAlpha: 0.08,
            disabledAlpha: 0.38,
            backgroundGradientTop: d.gradientTop,
            backgroundGradientMid: d.gradientMid,
            backgroundGradientBottom: d.gradientBottom,
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
      ),
    );
  }

  // ═══ Light Theme ═══
  static ThemeData get lightTheme {
    const l = AppColors.light;
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    return _referenceControls(
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: l.background,
        colorScheme: ColorScheme.light(
          primary: AppColors.primaryLight,
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
          error: AppColors.errorDim,
          onError: Colors.white,
          errorContainer: l.errorContainer,
          onErrorContainer: l.onErrorContainer,
          surface: l.surface,
          surfaceContainerLowest: l.surfaceContainerLowest,
          surfaceContainerLow: l.surfaceContainerLow,
          surfaceContainer: l.surfaceContainer,
          surfaceContainerHigh: l.surfaceContainerHigh,
          surfaceContainerHighest: l.surfaceContainerHighest,
          surfaceBright: l.surfaceBright,
          surfaceDim: l.surfaceDim,
          onInverseSurface: l.inverseOnSurface,
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
            textTertiary: l.onSurfaceTertiary,
            textDisabled: l.onSurfaceDisabled,
            borderStrong: l.outlineStrong,
            borderSubtle: l.outlineSubtle,
            info: AppColors.infoDim,
            infoContainer: const Color(0xFFD8E7FF),
            onInfoContainer: AppColors.onInfo,
            aqua: AppColors.aquaDim,
            aquaContainer: const Color(0xFFD7FAFC),
            onAquaContainer: AppColors.onAqua,
            caution: AppColors.cautionDim,
            cautionContainer: const Color(0xFFFFE7BD),
            onCautionContainer: AppColors.onCaution,
            surfacePanelAlpha: 0.9,
            surfacePanelBorderAlpha: 0.54,
            surfacePanelShadowAlpha: 0.06,
            cardBorderAlpha: 0.36,
            controlTrackAlpha: 1,
            controlShadowAlpha: 0.05,
            blackChromeAlpha: 0.8,
            navChromeAlpha: 0.9,
            hairlineAlpha: 0.16,
            scrimAlpha: 0.54,
            pressedWhiteAlpha: 0.12,
            disabledAlpha: 0.38,
            backgroundGradientTop: l.gradientTop,
            backgroundGradientMid: l.gradientMid,
            backgroundGradientBottom: l.gradientBottom,
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
      ),
    );
  }

  /// Explicit component adapters prevent framework defaults from becoming a
  /// second visual system. Native values beyond the inspected Dark Glow
  /// captures remain target adaptations; light mode retains the same roles.
  static ThemeData _referenceControls(ThemeData theme) {
    final cs = theme.colorScheme;
    final ext = theme.extension<MobiThemeExtension>()!;
    const pill = StadiumBorder();
    final panelShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.xxl),
    );
    Color foreground(Set<WidgetState> states) =>
        states.contains(WidgetState.disabled)
        ? ext.textDisabled
        : cs.onInverseSurface;
    Color background(Set<WidgetState> states) =>
        states.contains(WidgetState.disabled)
        ? cs.surfaceContainerHighest
        : cs.onSurface;
    Color accent(Set<WidgetState> states) =>
        states.contains(WidgetState.disabled) ? ext.textDisabled : cs.primary;
    final action = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      ),
      shape: const WidgetStatePropertyAll(pill),
      textStyle: WidgetStatePropertyAll(AppTypography.titleMd),
      backgroundColor: WidgetStateProperty.resolveWith(background),
      foregroundColor: WidgetStateProperty.resolveWith(foreground),
      elevation: const WidgetStatePropertyAll(0),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        return cs.onInverseSurface.withValues(alpha: ext.pressedWhiteAlpha);
      }),
    );
    final textAction = ButtonStyle(
      shape: const WidgetStatePropertyAll(pill),
      textStyle: WidgetStatePropertyAll(AppTypography.titleMd),
      foregroundColor: WidgetStateProperty.resolveWith(accent),
      overlayColor: WidgetStatePropertyAll(
        cs.primary.withValues(alpha: ext.pressedWhiteAlpha),
      ),
    );
    return theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(style: action),
      elevatedButtonTheme: ElevatedButtonThemeData(style: action),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: action.copyWith(
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ext.textDisabled
                : cs.onSurface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: textAction),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: panelShape,
        elevation: 0,
        titleTextStyle: AppTypography.headlineMd.copyWith(color: cs.onSurface),
        contentTextStyle: AppTypography.bodyMd.copyWith(
          color: cs.onSurfaceVariant,
        ),
        barrierColor: Colors.black.withValues(alpha: ext.scrimAlpha),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        textStyle: AppTypography.bodyMd.copyWith(color: cs.onSurface),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.bodyMd.copyWith(
            color: states.contains(WidgetState.disabled)
                ? ext.textDisabled
                : cs.onSurface,
          ),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(panelShape),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? cs.surfaceContainerHighest
              : states.contains(WidgetState.selected)
              ? cs.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(cs.onPrimary),
        side: BorderSide(color: cs.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? ext.textDisabled
              : states.contains(WidgetState.selected)
              ? cs.primary
              : cs.onSurfaceVariant,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? cs.surfaceContainerHighest
              : states.contains(WidgetState.selected)
              ? cs.primary
              : cs.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerLow,
        selectedColor: cs.surfaceContainerHighest,
        disabledColor: cs.surfaceContainerLow,
        shape: pill,
        side: BorderSide.none,
        labelStyle: AppTypography.labelLg.copyWith(color: cs.onSurface),
        secondaryLabelStyle: AppTypography.labelLg.copyWith(
          color: cs.onSurface,
        ),
        checkmarkColor: cs.onSurface,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: panelShape,
        headerBackgroundColor: cs.surfaceContainerLow,
        headerForegroundColor: cs.onSurface,
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? ext.textDisabled
              : states.contains(WidgetState.selected)
              ? cs.onPrimary
              : cs.onSurface,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.primary
              : Colors.transparent,
        ),
        cancelButtonStyle: textAction,
        confirmButtonStyle: textAction,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: cs.surfaceContainerLow,
        shape: panelShape,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.primaryContainer
              : cs.surfaceContainerHighest,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.onPrimaryContainer
              : cs.onSurface,
        ),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.primaryContainer
              : cs.surfaceContainerHigh,
        ),
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.onPrimaryContainer
              : cs.onSurface,
        ),
        dialBackgroundColor: cs.surfaceContainerHigh,
        dialHandColor: cs.primary,
        dialTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.onPrimary
              : cs.onSurface,
        ),
        entryModeIconColor: cs.onSurfaceVariant,
        helpTextStyle: AppTypography.labelMd.copyWith(
          color: cs.onSurfaceVariant,
        ),
        cancelButtonStyle: textAction,
        confirmButtonStyle: textAction,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: AppTypography.bodySm.copyWith(color: cs.onSurface),
      ),
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color onSurface,
    Color onSurfaceVariant,
  ) {
    return base.apply(fontFamily: 'Inter').copyWith(
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
