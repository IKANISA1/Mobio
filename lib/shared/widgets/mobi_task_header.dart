import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

/// Focused-task anatomy adapted from the external skill's LIVE-058.
/// The 48 logical-unit hit region and existing Inter display role are product
/// accessibility/typography adapters, not recovered source-native tokens.
class MobiTaskHeader extends StatelessWidget {
  const MobiTaskHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.backLabel = 'Back',
    this.trailing,
    this.showTitle = true,
    this.backSurfaceColor,
  });

  final String title;
  final VoidCallback onBack;
  final String backLabel;
  final Widget? trailing;
  final bool showTitle;
  final Color? backSurfaceColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: backLabel,
                onPressed: onBack,
                style: IconButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  backgroundColor: backSurfaceColor ?? Colors.transparent,
                  minimumSize: const Size(48, 48),
                  maximumSize: const Size(48, 48),
                  side: BorderSide(color: cs.outlineVariant),
                  shape: const CircleBorder(),
                ),
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          if (showTitle) ...[
            const SizedBox(height: 12),
            MobiTaskHeading(title: title),
          ],
        ],
      ),
    );
  }
}

/// Wraps complete task titles, including enlarged and localized text.
class MobiTaskHeading extends StatelessWidget {
  const MobiTaskHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: AppTypography.displayMd.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}
