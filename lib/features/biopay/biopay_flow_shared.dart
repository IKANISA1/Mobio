// ignore_for_file: use_key_in_widget_constructors

import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/utils/money_formatting.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:mobi_app/features/biopay/biopay_style.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BioPayCameraFrame extends StatelessWidget {
  const BioPayCameraFrame({
    required this.controller,
    this.capturedCount = 0,
    this.totalSteps = 0,
    this.currentStepId = 'straight_1',
    this.showFaceGuide = false,
  });

  final CameraController controller;
  final int capturedCount;
  final int totalSteps;
  final String currentStepId;
  final bool showFaceGuide;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(color: cs.surfaceContainerHighest),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _FittedCameraPreview(controller: controller),
              if (showFaceGuide) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.34),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
                BioPayFaceOvalGuide(
                  capturedCount: capturedCount,
                  totalSteps: totalSteps,
                  currentStepId: currentStepId,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FittedCameraPreview extends StatelessWidget {
  const _FittedCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final cameraAspectRatio = controller.value.aspectRatio;
    if (cameraAspectRatio <= 0) return CameraPreview(controller);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _cameraPreviewCoverScale(
          viewport: Size(constraints.maxWidth, constraints.maxHeight),
          cameraAspectRatio: cameraAspectRatio,
          orientation: MediaQuery.orientationOf(context),
        );
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}

double _cameraPreviewCoverScale({
  required Size viewport,
  required double cameraAspectRatio,
  required Orientation orientation,
}) {
  if (viewport.width <= 0 || viewport.height <= 0 || cameraAspectRatio <= 0) {
    return 1;
  }
  final viewportAspectRatio = viewport.width / viewport.height;
  final previewAspectRatio = orientation == Orientation.portrait
      ? 1 / cameraAspectRatio
      : cameraAspectRatio;
  final scale = previewAspectRatio > viewportAspectRatio
      ? previewAspectRatio / viewportAspectRatio
      : viewportAspectRatio / previewAspectRatio;
  return math.max(1, scale);
}

class BioPayFaceOvalGuide extends StatelessWidget {
  const BioPayFaceOvalGuide({
    required this.capturedCount,
    required this.totalSteps,
    required this.currentStepId,
  });

  final int capturedCount;
  final int totalSteps;
  final String currentStepId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BioPayFaceGuidePainter(
          capturedCount: capturedCount,
          totalSteps: totalSteps,
          currentStepId: currentStepId,
        ),
      ),
    );
  }
}

class _BioPayFaceGuidePainter extends CustomPainter {
  const _BioPayFaceGuidePainter({
    required this.capturedCount,
    required this.totalSteps,
    required this.currentStepId,
  });

  final int capturedCount;
  final int totalSteps;
  final String currentStepId;

  @override
  void paint(Canvas canvas, Size size) {
    final guideWidth = math.min(size.width * 0.72, 280.0);
    final guideHeight = math.min(size.height * 0.58, guideWidth * 1.28);
    final guideRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: guideWidth,
      height: guideHeight,
    );
    final ringRect = guideRect.inflate(8);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.88);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.10);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF22C55E);

    canvas
      ..drawOval(ringRect, glowPaint)
      ..drawOval(guideRect, basePaint);

    final segments = math.max(1, totalSteps);
    final sweep = (math.pi * 2 / segments) - 0.18;
    for (var i = 0; i < segments; i += 1) {
      if (i >= capturedCount) continue;
      canvas.drawArc(
        ringRect,
        -math.pi / 2 + (math.pi * 2 / segments * i),
        sweep,
        false,
        progressPaint,
      );
    }

    final cuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.28);
    final cueOffset = currentStepId == 'turn_pose' ? guideWidth * 0.10 : 0.0;
    final center = guideRect.center.translate(cueOffset, -guideHeight * 0.04);
    canvas
      ..drawCircle(center, 3.5, cuePaint)
      ..drawLine(center.translate(0, 12), center.translate(0, 36), cuePaint);
  }

  @override
  bool shouldRepaint(covariant _BioPayFaceGuidePainter oldDelegate) {
    return oldDelegate.capturedCount != capturedCount ||
        oldDelegate.totalSteps != totalSteps ||
        oldDelegate.currentStepId != currentStepId;
  }
}

class BioPayPoseCueStrip extends StatelessWidget {
  const BioPayPoseCueStrip({
    required this.capturedCount,
    required this.totalSteps,
    required this.currentStepId,
    this.hasError = false,
  });

  final int capturedCount;
  final int totalSteps;
  final String currentStepId;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    const stepIds = ['straight_1', 'turn_pose', 'straight_2'];
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: hasError
                ? cs.error.withValues(alpha: 0.54)
                : cs.outlineVariant.withValues(alpha: 0.52),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < totalSteps; i += 1) ...[
                _PoseCueDot(
                  id: stepIds[i],
                  completed: i < capturedCount,
                  active: stepIds[i] == currentStepId,
                  hasError: hasError,
                ),
                if (i != totalSteps - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PoseCueDot extends StatelessWidget {
  const _PoseCueDot({
    required this.id,
    required this.completed,
    required this.active,
    required this.hasError,
  });

  final String id;
  final bool completed;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = completed
        ? const Color(0xFF22C55E)
        : active && hasError
        ? cs.error
        : active
        ? cs.onSurface
        : cs.onSurfaceVariant.withValues(alpha: 0.50);
    final icon = completed
        ? LucideIcons.check
        : id == 'turn_pose'
        ? LucideIcons.rotateCw
        : LucideIcons.scanFace;

    return SizedBox.square(
      dimension: active ? 38 : 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: completed ? 1 : 0.12),
          border: Border.all(color: color, width: active ? 1.8 : 1.2),
        ),
        child: Icon(
          icon,
          color: completed ? Colors.white : color,
          size: active ? 19 : 17,
        ),
      ),
    );
  }
}

class BioPayFaceEnrollmentStandby extends StatelessWidget {
  const BioPayFaceEnrollmentStandby({
    required this.iconColor,
    this.label,
    this.height = 260,
    this.guideSize = const Size(156, 212),
  });

  final Color iconColor;
  final String? label;
  final double height;
  final Size guideSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: guideSize.width,
                height: guideSize.height,
                child: CustomPaint(
                  painter: _BioPayStandbyOvalPainter(color: iconColor),
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  label!,
                  style: AppTypography.labelLg.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BioPayStandbyOvalPainter extends CustomPainter {
  const _BioPayStandbyOvalPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final ovalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.30);
    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas
      ..drawOval(rect, ovalPaint)
      ..drawLine(
        Offset(size.width * 0.14, size.height * 0.62),
        Offset(size.width * 0.86, size.height * 0.62),
        accentPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _BioPayStandbyOvalPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class BioPayFaceEnrollmentStatusPanel extends StatelessWidget {
  const BioPayFaceEnrollmentStatusPanel({
    required this.title,
    required this.body,
    required this.capturedCount,
    required this.totalSteps,
    required this.sessionReady,
  });

  final String title;
  final String body;
  final int capturedCount;
  final int totalSteps;
  final bool sessionReady;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: bioPayBlue.withValues(alpha: 0.07),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              sessionReady ? LucideIcons.scanFace : LucideIcons.camera,
              color: sessionReady
                  ? bioPayBlue
                  : Colors.white.withValues(alpha: 0.58),
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLg.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${capturedCount.clamp(0, totalSteps)}/$totalSteps',
                        style: AppTypography.labelLg.copyWith(
                          color: bioPayBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BioPayFlowScreen extends StatelessWidget {
  const BioPayFlowScreen({
    required this.title,
    required this.primaryLabel,
    required this.onBack,
    required this.child,
    this.onPrimary,
    this.isPrimaryLoading = false,
  });

  final String title;
  final String primaryLabel;
  final VoidCallback onBack;
  final Widget child;
  final VoidCallback? onPrimary;
  final bool isPrimaryLoading;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: bioPayLightTheme(context),
      child: Scaffold(
        backgroundColor: bioPayCanvas,
        body: BioPayLightCanvas(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BioPayBackAvatar(onTap: onBack),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMd.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 42),
                  child,
                  if (primaryLabel.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    MobiButton(
                      onPressed: onPrimary,
                      isLoading: isPrimaryLoading,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 19,
                      ),
                      child: Text(primaryLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BioPayBackAvatar extends StatelessWidget {
  const BioPayBackAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Tooltip(
        message: 'Back',
        child: SizedBox.square(
          dimension: 42,
          child: Material(
            color: bioPayChrome,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
            ),
            elevation: 8,
            shadowColor: bioPayBlue.withValues(alpha: 0.10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: const Icon(
                LucideIcons.chevronLeft,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool canRunExternalAction(BioPayUssdPaymentRequest? request) {
  return request?.status == BioPayRequestStatus.readyToDial ||
      request?.status == BioPayRequestStatus.dialerOpened;
}

int amountMinorFromController(TextEditingController controller) {
  final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
  final amountMajor = int.tryParse(digits);
  if (amountMajor == null || amountMajor <= 0) {
    throw const FormatException('amount_required');
  }
  return amountMajor * 100;
}

int optionalAmountMinorFromController(TextEditingController controller) {
  final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  final amountMajor = int.tryParse(digits);
  if (amountMajor == null || amountMajor < 0) {
    throw const FormatException('amount_invalid');
  }
  return amountMajor * 100;
}

String momoReceiverDisplay(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('250') && digits.length == 12) {
    return '0${digits.substring(3)}';
  }
  if (digits.startsWith('0')) return digits;
  if (digits.length == 9) return '0$digits';
  return digits;
}

String momoPayCodeDisplay(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String momoReceiverForRequest(String value, {required bool usesCode}) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (usesCode) return digits;

  final normalized = PhoneNumberNormalizer.normalizeForCountry(
    phone: digits,
    countryCode: '+250',
  );
  if (!PhoneNumberNormalizer.isValidCanonical(normalized)) return '';
  return momoReceiverDisplay(normalized);
}

String buildBioPayQrPayload(BioPayUssdPaymentRequest request) {
  return jsonEncode({
    'type': 'mobio_biopay_request',
    'token': request.token,
    'payee_label': request.payeeLabel,
    'amount_minor': request.amountMinor,
    'currency': request.currency,
    'reference': request.reference,
  });
}

String bioPayTokenFromPayload(String? rawValue) {
  final raw = rawValue?.trim();
  if (raw == null || raw.isEmpty) return '';

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      for (final key in const ['token', 'biopay_token', 'payment_token']) {
        final value = decoded[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return '';
    }
  } on FormatException {
    // Older QR/NFC payloads may be a bare token.
  }

  final uri = Uri.tryParse(raw);
  final token = uri?.queryParameters['token']?.trim();
  if (token != null && token.isNotEmpty) return token;

  return raw;
}

String externalActionLabel(BioPayUssdPaymentRequest request) {
  return switch (request.status) {
    BioPayRequestStatus.readyToDial => 'Dial USSD',
    BioPayRequestStatus.dialerOpened => 'I finished USSD',
    BioPayRequestStatus.userMarkedPaid => 'Waiting confirmation',
    BioPayRequestStatus.confirmed => 'Confirmed',
    BioPayRequestStatus.expired => 'Expired',
    BioPayRequestStatus.cancelled => 'Cancelled',
    BioPayRequestStatus.failed => 'Failed',
    BioPayRequestStatus.draft => 'Prepare request',
  };
}

String requestStatusLabel(BioPayRequestStatus status) {
  return switch (status) {
    BioPayRequestStatus.readyToDial => 'Ready to dial',
    BioPayRequestStatus.dialerOpened => 'Dialer opened',
    BioPayRequestStatus.userMarkedPaid => 'User marked paid',
    BioPayRequestStatus.confirmed => 'Externally confirmed',
    BioPayRequestStatus.expired => 'Expired',
    BioPayRequestStatus.cancelled => 'Cancelled',
    BioPayRequestStatus.failed => 'Failed',
    BioPayRequestStatus.draft => 'Draft',
  };
}

String dateLabel(DateTime? value) {
  if (value == null) return 'Not recorded';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

IconData channelIcon(BioPayRequestChannel channel) {
  return switch (channel) {
    BioPayRequestChannel.qr => LucideIcons.qrCode,
    BioPayRequestChannel.nfc => LucideIcons.nfc,
    BioPayRequestChannel.face => LucideIcons.scanFace,
  };
}

class BioPayReceiverField extends StatelessWidget {
  const BioPayReceiverField({
    required this.controller,
    required this.usesCode,
    this.enabled = true,
    this.onModeChanged,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool usesCode;
  final bool enabled;
  final ValueChanged<bool>? onModeChanged;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: bioPayBlue.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  _QrReceiverModeButton(
                    label: 'Number',
                    selected: !usesCode,
                    enabled: enabled,
                    onTap: () => onModeChanged?.call(false),
                  ),
                  _QrReceiverModeButton(
                    label: 'Code',
                    selected: usesCode,
                    enabled: enabled,
                    onTap: () => onModeChanged?.call(true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            SizedBox(
              height: 80,
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onChanged,
                style: AppTypography.displayMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  hintText: usesCode ? 'MoMo Pay code' : 'MoMo number',
                  hintStyle: AppTypography.titleLg.copyWith(
                    color: Colors.white.withValues(alpha: 0.36),
                    fontWeight: FontWeight.w800,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrReceiverModeButton extends StatelessWidget {
  const _QrReceiverModeButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : null,
            gradient: selected
                ? const LinearGradient(colors: [bioPayInk, Color(0xFF1D2939)])
                : null,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.titleMd.copyWith(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class BioPayReceiveAmountField extends StatefulWidget {
  const BioPayReceiveAmountField({
    required this.controller,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<BioPayReceiveAmountField> createState() =>
      BioPayReceiveAmountFieldState();
}

class BioPayReceiveAmountFieldState extends State<BioPayReceiveAmountField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleInputStateChanged);
    _focusNode.addListener(_handleInputStateChanged);
  }

  @override
  void didUpdateWidget(covariant BioPayReceiveAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleInputStateChanged);
      widget.controller.addListener(_handleInputStateChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleInputStateChanged);
    _focusNode
      ..removeListener(_handleInputStateChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showPlaceholder =
        widget.controller.text.isEmpty && !_focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.12), height: 32),
        Text(
          'AMOUNT',
          style: AppTypography.labelLg.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                inputFormatters: const [GroupedWholeNumberTextInputFormatter()],
                onChanged: widget.onChanged,
                style: AppTypography.displayMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  prefixText: widget.controller.text.isEmpty ? null : 'RWF ',
                  prefixStyle: AppTypography.displayMd.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  filled: true,
                  fillColor: bioPayDarkPanel.withValues(alpha: 0.74),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: bioPayBlue, width: 1.4),
                  ),
                ),
              ),
              if (showPlaceholder)
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'RWF ',
                        style: AppTypography.displayMd.copyWith(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        '0.00',
                        style: AppTypography.displayMd.copyWith(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class BioPayResolvedPaymentPreview extends StatelessWidget {
  const BioPayResolvedPaymentPreview({required this.request});

  final BioPayUssdPaymentRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BioPayDetailRow(label: 'Payee', value: request.payeeLabel),
        BioPayDetailRow(label: 'Amount', value: request.amountLabel),
        BioPayDetailRow(label: 'Reference', value: request.reference),
        BioPayDetailRow(
          label: 'Status',
          value: requestStatusLabel(request.status),
        ),
        const BioPayDetailRow(label: 'Confirmation', value: 'External'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(LucideIcons.phoneCall, size: 18, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Tap Dial USSD to open the phone dialer',
                style: AppTypography.bodyMd.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BioPayQrPreview extends StatelessWidget {
  const BioPayQrPreview({required this.request, this.boundaryKey});

  final BioPayUssdPaymentRequest request;
  final Key? boundaryKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RepaintBoundary(
          key: boundaryKey,
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: bioPayBlue.withValues(alpha: 0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Center(
                child: QrImageView(
                  data: buildBioPayQrPayload(request),
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: bioPayInk,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: bioPayInk,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BioPayQrActions extends StatelessWidget {
  const BioPayQrActions({
    required this.onSave,
    required this.onShare,
    this.isSaving = false,
    this.isSharing = false,
  });

  final VoidCallback onSave;
  final VoidCallback onShare;
  final bool isSaving;
  final bool isSharing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BioPayQrActionButton(
            icon: LucideIcons.download,
            label: 'Save',
            isLoading: isSaving,
            onTap: onSave,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _BioPayQrActionButton(
            icon: LucideIcons.share2,
            label: 'Share',
            isLoading: isSharing,
            onTap: onShare,
          ),
        ),
      ],
    );
  }
}

class _BioPayQrActionButton extends StatelessWidget {
  const _BioPayQrActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isLoading,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      enabled: !isLoading,
      child: Tooltip(
        message: label,
        child: Material(
          color: bioPayDarkPanel.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  else
                    Icon(icon, size: 19, color: cs.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BioPayQrScannerSurface extends StatefulWidget {
  const BioPayQrScannerSurface({required this.onDetect, this.error});

  final ValueChanged<String> onDetect;
  final String? error;

  @override
  State<BioPayQrScannerSurface> createState() => BioPayQrScannerSurfaceState();
}

class BioPayQrScannerSurfaceState extends State<BioPayQrScannerSurface> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      cameraResolution: const Size(1920, 1080),
      autoZoom: true,
      initialZoom: 0.18,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  fit: BoxFit.cover,
                  tapToFocus: true,
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (value != null) widget.onDetect(value);
                  },
                  errorBuilder: (context, error) => DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: Center(
                      child: Icon(
                        LucideIcons.scanLine,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                    ),
                  ),
                ),
                const _QrScannerCornerGuide(),
                Positioned(
                  right: 14,
                  top: 14,
                  child: IconButton.filledTonal(
                    tooltip: 'Torch',
                    onPressed: _controller.toggleTorch,
                    icon: const Icon(LucideIcons.flashlight),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          BioPayInlineError(message: widget.error!),
        ],
      ],
    );
  }
}

class _QrScannerCornerGuide extends StatelessWidget {
  const _QrScannerCornerGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _QrScannerCornerPainter()),
    );
  }
}

class _QrScannerCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.58;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFCC00);
    const length = 34.0;

    canvas
      ..drawLine(rect.topLeft, rect.topLeft.translate(length, 0), paint)
      ..drawLine(rect.topLeft, rect.topLeft.translate(0, length), paint)
      ..drawLine(rect.topRight, rect.topRight.translate(-length, 0), paint)
      ..drawLine(rect.topRight, rect.topRight.translate(0, length), paint)
      ..drawLine(rect.bottomLeft, rect.bottomLeft.translate(length, 0), paint)
      ..drawLine(rect.bottomLeft, rect.bottomLeft.translate(0, -length), paint)
      ..drawLine(
        rect.bottomRight,
        rect.bottomRight.translate(-length, 0),
        paint,
      )
      ..drawLine(
        rect.bottomRight,
        rect.bottomRight.translate(0, -length),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BioPayInlineError extends StatelessWidget {
  const BioPayInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(LucideIcons.alertTriangle, color: cs.error, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodyMd.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class BioPayDetailRow extends StatelessWidget {
  const BioPayDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMd.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.titleMd.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
