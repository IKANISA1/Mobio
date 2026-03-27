import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({
    super.key,
    required this.onBack,
    this.onEnroll,
    this.onPrivacyCenter,
  });

  final VoidCallback onBack;
  final VoidCallback? onEnroll;
  final VoidCallback? onPrivacyCenter;

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  void _startFlow() {
    widget.onEnroll?.call();
  }

  @override
  Widget build(BuildContext context) {
    const title = 'FACE REGISTRATION';
    const headline = 'Ready to Start?';
    const subtitle = 'Position your face in the circle to begin registration.';
    const buttonLabel = 'START REGISTRATION';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onBack,
                      borderRadius: BorderRadius.circular(28),
                      child: Ink(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .extension<MobiThemeExtension>()!
                              .surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.x,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.titleMd.copyWith(letterSpacing: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: [
                    const Expanded(
                      child: Center(child: _RegistrationHero(isLoading: false)),
                    ),

                    Text(
                      headline,
                      style: AppTypography.headlineLg,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        subtitle,
                        style: AppTypography.bodyLg.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _startFlow,
                          borderRadius: BorderRadius.circular(999),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Center(
                              child: Text(
                                buttonLabel,
                                style: AppTypography.labelLg.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onPrivacyCenter,
                      child: Text(
                        'VIEW PRIVACY & DATA',
                        style: AppTypography.labelMd.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationHero extends StatelessWidget {
  const _RegistrationHero({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 330,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CustomPaint(
            size: Size.square(330),
            painter: _RegistrationHaloPainter(),
          ),
          Icon(
            Icons.account_circle_outlined,
            size: 212,
            color: Colors.white.withValues(alpha: 0.14),
          ),
          Positioned(
            bottom: 66,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.badge_outlined,
                size: 46,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          if (isLoading)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RegistrationHaloPainter extends CustomPainter {
  const _RegistrationHaloPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.width / 2 - 10;
    final midRadius = size.width * 0.34;
    final dottedRadius = size.width * 0.42;

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: 0.24);
    canvas.drawCircle(center, outerRadius, outerPaint);

    final midPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(center, midRadius, midPaint);

    final dashedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = AppColors.primary.withValues(alpha: 0.65);

    const dashCount = 56;
    const dashSweep = (2 * math.pi) / dashCount * 0.46;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (2 * math.pi / dashCount) * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: dottedRadius),
        startAngle,
        dashSweep,
        false,
        dashedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
