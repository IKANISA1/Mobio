import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

/// Minimal confirmation dialog with consistent Mobio styling.
///
/// Usage:
/// ```dart
/// final confirmed = await MobiConfirmDialog.show(
///   context: context,
///   title: 'Cancel Trip',
///   body: 'Are you sure?',
///   confirmLabel: 'Yes',
///   isDestructive: true,
/// );
/// ```
class MobiConfirmDialog {
  MobiConfirmDialog._();

  /// Shows a confirmation dialog and returns `true` if the user confirms.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    String? body,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _MobiConfirmDialogContent(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }
}

class _MobiConfirmDialogContent extends StatelessWidget {
  final String title;
  final String? body;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  const _MobiConfirmDialogContent({
    required this.title,
    this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final confirmColor = isDestructive ? cs.error : cs.primary;

    return Dialog(
      backgroundColor: ext.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleLg.copyWith(color: cs.onSurface),
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                body!,
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: ext.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, false),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Center(
                          child: Text(
                            cancelLabel,
                            style: AppTypography.labelLg.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Material(
                    color: confirmColor,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, true),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      splashColor: Colors.white.withValues(
                        alpha: ext.pressedWhiteAlpha,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Center(
                          child: Text(
                            confirmLabel,
                            style: AppTypography.labelLg.copyWith(
                              color: isDestructive ? cs.onError : cs.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
