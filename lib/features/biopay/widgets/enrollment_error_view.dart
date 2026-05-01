import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/widgets/biopay_step_surface.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

class EnrollmentErrorView extends StatelessWidget {
  const EnrollmentErrorView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    required this.onBack,
    required this.isSessionComplete,
  });

  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final bool isSessionComplete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        BiopayStepSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  LucideIcons.alertTriangle,
                  color: Theme.of(context).colorScheme.error,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: AppTypography.headlineMd.copyWith(letterSpacing: -1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage ?? 'Please try again.',
                style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              MobiButton(
                width: double.infinity,
                onPressed: onRetry,
                child: Text(
                  isSessionComplete ? 'RETRY' : 'TRY AGAIN',
                  style: AppTypography.labelMd.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MobiButton(
                width: double.infinity,
                variant: MobiButtonVariant.ghost,
                onPressed: onBack,
                child: Text(
                  'GO BACK',
                  style: AppTypography.labelMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
