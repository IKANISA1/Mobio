import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

enum MobiBottomSheetTone { inherited, neutral }

enum MobiBottomSheetHeader { standard, dismissibleTask }

/// Shows a standardized bottom sheet with consistent handle, padding,
/// max-height, and drag-to-dismiss.
///
/// Usage:
/// ```dart
/// MobiBottomSheet.show(
///   context: context,
///   title: 'Actions',
///   builder: (ctx) => Column(...),
/// );
/// ```
class MobiBottomSheet {
  MobiBottomSheet._();

  /// Show a modal bottom sheet with consistent Mobio styling.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = true,
    bool includeViewInsets = true,
    double? maxHeightFraction,
    MobiBottomSheetTone tone = MobiBottomSheetTone.inherited,
    MobiBottomSheetHeader header = MobiBottomSheetHeader.standard,
    String closeLabel = 'Close',
  }) {
    Widget content(BuildContext sheetContext) => _MobiBottomSheetContent(
      title: title,
      header: header,
      closeLabel: closeLabel,
      includeViewInsets: includeViewInsets,
      child: builder(sheetContext),
    );

    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * (maxHeightFraction ?? 0.85),
      ),
      builder: (ctx) => tone == MobiBottomSheetTone.neutral
          ? Theme(
              data: _neutralTheme(Theme.of(ctx)),
              child: Builder(builder: content),
            )
          : content(ctx),
    );
  }

  /// LIVE-044's raised Countries sheet uses neutral body/search/group surfaces.
  /// These are rendered sRGB adapters, not exported native tokens. Light mode
  /// keeps neutral tonal hierarchy through a provisional semantic adapter;
  /// exact native Light values remain source-unverified.
  /// Only colour roles change; the caller's fonts and component metrics remain.
  static ThemeData _neutralTheme(ThemeData parent) {
    final neutral = parent.brightness == Brightness.dark
        ? AppTheme.darkTheme
        : AppTheme.lightTheme;
    final dark = parent.brightness == Brightness.dark;
    final body = dark
        ? const Color(0xFF1C1C1E)
        : neutral.colorScheme.surfaceContainerLowest;
    final search = dark
        ? const Color(0xFF0F0F12)
        : neutral.colorScheme.surfaceContainerLow;
    final group = dark
        ? const Color(0xFF242527)
        : neutral.colorScheme.surfaceContainerLow;
    final cs = neutral.colorScheme.copyWith(
      surface: body,
      surfaceContainerLowest: body,
      surfaceContainerLow: search,
      surfaceContainer: group,
    );
    final ext = neutral.extension<MobiThemeExtension>()!.copyWith(
      surfaceContainerLowest: body,
      surfaceContainerLow: search,
      surfaceContainer: group,
      backgroundGradientTop: body,
      backgroundGradientMid: body,
      backgroundGradientBottom: body,
    );
    return parent.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: body,
      extensions: [
        for (final extension in parent.extensions.values)
          if (extension is! MobiThemeExtension) extension,
        ext,
      ],
      textTheme: parent.textTheme
          .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface)
          .copyWith(
            bodySmall: parent.textTheme.bodySmall?.copyWith(
              color: neutral.textTheme.bodySmall?.color,
            ),
            labelMedium: parent.textTheme.labelMedium?.copyWith(
              color: neutral.textTheme.labelMedium?.color,
            ),
            labelSmall: parent.textTheme.labelSmall?.copyWith(
              color: neutral.textTheme.labelSmall?.color,
            ),
          ),
      iconTheme: parent.iconTheme.copyWith(color: cs.onSurfaceVariant),
      inputDecorationTheme: parent.inputDecorationTheme.copyWith(
        fillColor: search,
        hintStyle: parent.inputDecorationTheme.hintStyle?.copyWith(
          color: cs.onSurfaceVariant,
        ),
        labelStyle: parent.inputDecorationTheme.labelStyle?.copyWith(
          color: cs.onSurfaceVariant,
        ),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        enabledBorder: parent.inputDecorationTheme.enabledBorder?.copyWith(
          borderSide: parent.inputDecorationTheme.enabledBorder!.borderSide
              .copyWith(color: cs.outlineVariant),
        ),
        focusedBorder: parent.inputDecorationTheme.focusedBorder?.copyWith(
          borderSide: parent.inputDecorationTheme.focusedBorder!.borderSide
              .copyWith(color: cs.primary),
        ),
      ),
      bottomSheetTheme: parent.bottomSheetTheme.copyWith(
        backgroundColor: body,
        modalBackgroundColor: body,
      ),
      listTileTheme: parent.listTileTheme.copyWith(
        textColor: cs.onSurface,
        iconColor: cs.onSurfaceVariant,
        selectedColor: cs.primary,
        selectedTileColor: cs.surfaceContainerHighest,
      ),
    );
  }
}

class _MobiBottomSheetContent extends StatelessWidget {
  final String? title;
  final MobiBottomSheetHeader header;
  final String closeLabel;
  final Widget child;
  final bool includeViewInsets;

  const _MobiBottomSheetContent({
    this.title,
    required this.header,
    required this.closeLabel,
    required this.child,
    required this.includeViewInsets,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: includeViewInsets ? MediaQuery.viewInsetsOf(context).bottom : 0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ext.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.hero),
          ),
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withValues(
                alpha: ext.surfacePanelBorderAlpha,
              ),
            ),
          ),
        ),
        // Keep row ink effects above the sheet's opaque background decoration.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (header == MobiBottomSheetHeader.dismissibleTask)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.outlined(
                      tooltip: closeLabel,
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(48),
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        backgroundColor: ext.surfaceContainerLow,
                        foregroundColor: cs.onSurface,
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      icon: Icon(Icons.close, semanticLabel: closeLabel),
                    ),
                  ),
                )
              else
                // Existing sheets retain their original drag-handle header.
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

              // Title
              if (title != null) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    // LIVE-044 comparison: reduce the opted-in title gap by
                    // four logical pixels; this is a measured target adapter.
                    header == MobiBottomSheetHeader.dismissibleTask
                        ? AppSpacing.sm
                        : AppSpacing.lg,
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                  ),
                  child: Semantics(
                    header: header == MobiBottomSheetHeader.dismissibleTask,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title!,
                        // Existing display typography is a target adapter;
                        // LIVE-044 does not establish native font/point tokens.
                        style:
                            (header == MobiBottomSheetHeader.dismissibleTask
                                    ? AppTypography.displayMd
                                    : AppTypography.titleLg)
                                .copyWith(color: cs.onSurface),
                      ),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: AppSpacing.md),

              // Content
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.paddingOf(context).bottom + AppSpacing.md,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
