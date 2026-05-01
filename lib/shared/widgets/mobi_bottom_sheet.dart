import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

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
    double? maxHeightFraction,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height *
            (maxHeightFraction ?? 0.85),
      ),
      builder: (ctx) => _MobiBottomSheetContent(
        title: title,
        child: builder(ctx),
      ),
    );
  }
}

class _MobiBottomSheetContent extends StatelessWidget {
  final String? title;
  final Widget child;

  const _MobiBottomSheetContent({
    this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.lg,
                AppSpacing.screenPadding,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title!,
                  style: AppTypography.titleLg.copyWith(
                    color: cs.onSurface,
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
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
