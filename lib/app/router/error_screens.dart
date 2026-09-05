import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Config error screen
// ─────────────────────────────────────────────────────────────────────────────

/// Shown when the app is built without required Supabase environment variables.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SoftGradient(
        tone: SoftGradientTone.alert,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panelWidth = math.min(
                420.0,
                math.max(0.0, constraints.maxWidth - 48),
              );

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: SizedBox(
                    width: panelWidth,
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: ext.surfaceContainer.withValues(
                          alpha: ext.surfacePanelAlpha,
                        ),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: cs.error.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.shieldAlert,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Unable to start Mobio',
                            style: AppTypography.headlineLg.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'This build is missing release configuration.',
                            style: AppTypography.bodyLg.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const _ConfigValuePill(label: 'SUPABASE_URL'),
                          const SizedBox(height: AppSpacing.xs),
                          const _ConfigValuePill(label: 'SUPABASE_ANON_KEY'),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Add both dart-define values before device UAT.',
                            style: AppTypography.labelMd.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConfigValuePill extends StatelessWidget {
  const _ConfigValuePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.keyRound, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 404 Not Found screen
// ─────────────────────────────────────────────────────────────────────────────

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SoftGradient(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: MobiSurfacePanel(
                padding: const EdgeInsets.all(AppSpacing.xl),
                borderRadius: AppRadii.hero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.map,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '404',
                      style: AppTypography.heroNumber.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Page not found',
                      style: AppTypography.titleLg.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    MobiButton(
                      variant: MobiButtonVariant.ghost,
                      onPressed: () => context.go('/'),
                      child: const Text('Back to Home'),
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
