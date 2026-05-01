import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';

/// Release-safe fallback for uncaught widget build errors.
///
/// This avoids the default red error UI while still giving users a clear,
/// non-technical recovery message.
class MobiFatalErrorView extends StatelessWidget {
  const MobiFatalErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Semantics(
                container: true,
                liveRegion: true,
                label: 'Something went wrong',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      child: Icon(
                        LucideIcons.alertTriangle,
                        color: cs.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Something went wrong',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLg.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Close and reopen Mobio. If this keeps happening, contact support.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
