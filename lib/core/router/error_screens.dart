import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

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
                          Text(
                            'Unable to start Mobio',
                            style: AppTypography.headlineLg.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'This build is missing Supabase configuration.',
                            style: AppTypography.bodyLg.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Provide both dart-define values before device UAT:\n'
                            'SUPABASE_URL\n'
                            'SUPABASE_ANON_KEY',
                            style: AppTypography.bodyMd.copyWith(
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '404',
                  style: AppTypography.heroNumber.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Page not found',
                  style: AppTypography.titleLg.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 24),
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
    );
  }
}
