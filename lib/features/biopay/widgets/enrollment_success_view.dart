import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';
import 'package:mobi_app/features/biopay/widgets/management_code_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

class EnrollmentSuccessView extends StatelessWidget {
  const EnrollmentSuccessView({
    super.key,
    required this.isReEnrollment,
    required this.result,
    required this.onDone,
    required this.onCopyManagementCode,
  });

  final bool isReEnrollment;
  final EnrollmentResult? result;
  final VoidCallback onDone;
  final ValueChanged<String> onCopyManagementCode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        _buildStepSurface(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SuccessCelebration()),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  isReEnrollment ? 'Face updated' : 'You\'re all set',
                  style: AppTypography.headlineLg,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  isReEnrollment
                      ? 'Your face data has been refreshed.'
                      : 'Your BioPay profile is ready.',
                  style: AppTypography.bodyMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              if (result != null) ...[
                _infoRow(context, 'BioPay ID', result!.biopayId ?? '—'),
                if (!isReEnrollment && result!.ussdString != null)
                  _infoRow(context, 'MoMo', result!.ussdString!),
                if (!isReEnrollment &&
                    (result!.managementCode?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 14),
                  ManagementCodeCard(
                    code: result!.managementCode!,
                    onCopy: () => onCopyManagementCode(result!.managementCode!),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              MobiButton(
                width: double.infinity,
                onPressed: onDone,
                child: Text(
                  'DONE',
                  style: AppTypography.labelMd.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepSurface(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: ext.clayCardShadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            ext.surfaceContainerLowest.withValues(alpha: 0.96),
            cs.surface.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMd)),
        ],
      ),
    );
  }
}

class SuccessCelebration extends StatelessWidget {
  const SuccessCelebration({super.key});

  static const _particles =
      <({double left, double top, double size, Color color})>[
        (left: 12, top: 28, size: 12, color: AppColors.warning),
        (left: 46, top: 12, size: 8, color: AppColors.bioPayGreen),
        (left: 128, top: 18, size: 10, color: AppColors.secondaryFixed),
        (left: 168, top: 34, size: 12, color: AppColors.warning),
        (left: 24, top: 112, size: 10, color: AppColors.bioPayGreen),
        (left: 148, top: 108, size: 8, color: AppColors.secondaryFixed),
      ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final particle in _particles)
            Positioned(
              left: particle.left,
              top: particle.top,
              child: Animate(
                effects: const [
                  FadeEffect(duration: Duration(milliseconds: 180)),
                  MoveEffect(
                    begin: Offset(0, 12),
                    end: Offset(0, -14),
                    duration: Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                  ),
                  ScaleEffect(
                    begin: Offset(0.2, 0.2),
                    end: Offset(1, 1),
                    duration: Duration(milliseconds: 520),
                    curve: Curves.easeOutBack,
                  ),
                ],
                child: Container(
                  width: particle.size,
                  height: particle.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: particle.color.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          Animate(
            effects: const [
              FadeEffect(duration: Duration(milliseconds: 260)),
              ScaleEffect(
                begin: Offset(0.82, 0.82),
                end: Offset(1, 1),
                duration: Duration(milliseconds: 460),
                curve: Curves.easeOutBack,
              ),
            ],
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.bioPayGreen.withValues(alpha: 0.96),
                    AppColors.primary.withValues(alpha: 0.94),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bioPayGreen.withValues(alpha: 0.26),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
