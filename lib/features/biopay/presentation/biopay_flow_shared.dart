import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/core/utils/money_formatting.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/domain/payment_payload.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_style.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_colors.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BioPayCameraFrame extends StatelessWidget {
  const BioPayCameraFrame({
    super.key,
    required this.controller,
    this.showFaceGuide = false,
    this.height,
  });

  final CameraController controller;
  final bool showFaceGuide;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final frame = ClipRRect(
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
              const BioPayFaceOvalGuide(),
            ],
          ],
        ),
      ),
    );

    final fixedHeight = height;
    if (fixedHeight != null) {
      return SizedBox(
        width: double.infinity,
        height: fixedHeight,
        child: frame,
      );
    }

    return AspectRatio(aspectRatio: 3 / 4, child: frame);
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
  const BioPayFaceOvalGuide({super.key});
  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: CustomPaint(painter: _BioPayFaceGuidePainter()),
  );
}

class _BioPayFaceGuidePainter extends CustomPainter {
  const _BioPayFaceGuidePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final width = math.min(size.width * 0.72, 280.0);
    final height = math.min(size.height * 0.58, width * 1.28);
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: width,
      height: height,
    );
    canvas
      ..drawOval(
        oval.inflate(8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..color = Colors.white.withValues(alpha: 0.10),
      )
      ..drawOval(
        oval,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = Colors.white.withValues(alpha: 0.88),
      );
  }

  @override
  bool shouldRepaint(covariant _BioPayFaceGuidePainter oldDelegate) => false;
}

class BioPayFaceEnrollmentStandby extends StatelessWidget {
  const BioPayFaceEnrollmentStandby({
    super.key,
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
                    fontWeight: FontWeight.w600,
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

class BioPayFlowScreen extends StatelessWidget {
  const BioPayFlowScreen({
    super.key,
    required this.title,
    required this.primaryLabel,
    required this.onBack,
    required this.child,
    this.onPrimary,
    this.isPrimaryLoading = false,
    this.headerSpacing = 42,
  });

  final String title;
  final String primaryLabel;
  final VoidCallback onBack;
  final Widget child;
  final VoidCallback? onPrimary;
  final bool isPrimaryLoading;
  final double headerSpacing;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: bioPayLightTheme(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: BioPayLightCanvas(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BioPayBackAvatar(onTap: onBack),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.start,
                            style: AppTypography.headlineLg.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: headerSpacing),
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
  const BioPayBackAvatar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Tooltip(
        excludeFromSemantics: true,
        message: 'Back',
        child: SizedBox.square(
          dimension: 48,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Icon(
                LucideIcons.chevronLeft,
                color: Theme.of(context).colorScheme.onSurface,
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

bool isValidMomoPayCode(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 5 && digits.length <= 6;
}

bool isValidMomoReceiver(String value, {required bool usesCode}) {
  return momoReceiverForRequest(value, usesCode: usesCode).isNotEmpty;
}

String momoReceiverForRequest(String value, {required bool usesCode}) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (usesCode) return isValidMomoPayCode(digits) ? digits : '';

  final validation = PhoneNumberNormalizer.validateForCountry(
    phone: digits,
    countryCode: '+250',
  );
  if (!validation.isValid) return '';
  return momoReceiverDisplay(validation.normalized);
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
    super.key,
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
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Semantics(
                label: usesCode ? 'MoMo Pay code' : 'MoMo number',
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: onChanged,
                  style: AppTypography.displayMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: usesCode ? 'MoMo Pay code' : 'MoMo number',
                    hintStyle: AppTypography.titleLg.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w600,
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
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : null,
            gradient: selected
                ? const LinearGradient(colors: [bioPayInk, Color(0xFF28333D)])
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class BioPayReceiveAmountField extends StatefulWidget {
  const BioPayReceiveAmountField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.showLabel = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool showLabel;
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
        if (widget.showLabel) ...[
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 32,
          ),
          Text(
            'AMOUNT',
            style: AppTypography.labelLg.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Semantics(
                label: 'Amount in Rwandan francs',
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  inputFormatters: const [
                    GroupedWholeNumberTextInputFormatter(),
                  ],
                  onChanged: widget.onChanged,
                  style: AppTypography.displayMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    prefixText: widget.controller.text.isEmpty ? null : 'RWF ',
                    prefixStyle: AppTypography.displayMd.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w600,
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
                      borderSide: const BorderSide(
                        color: bioPayBlue,
                        width: 1.4,
                      ),
                    ),
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
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        '0.00',
                        style: AppTypography.displayMd.copyWith(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w600,
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
  const BioPayResolvedPaymentPreview({super.key, required this.request});

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
  const BioPayQrPreview({super.key, required this.request, this.boundaryKey});

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
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final logoBadgeWidth = (constraints.maxWidth * 0.15).clamp(
                      42.0,
                      54.0,
                    );
                    final logoBadgeHeight = logoBadgeWidth * 0.72;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(
                          data: buildBioPayQrPayload(request),
                          backgroundColor: Colors.transparent,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        IgnorePointer(
                          child: Container(
                            key: const ValueKey('biopayQrLogoBadge'),
                            width: logoBadgeWidth,
                            height: logoBadgeHeight,
                            padding: EdgeInsets.symmetric(
                              horizontal: logoBadgeWidth * 0.04,
                              vertical: logoBadgeHeight * 0.06,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                logoBadgeHeight * 0.24,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.96),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'icon/mobi_logo_transparent.png',
                              key: const ValueKey('biopayQrLogoImage'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
    super.key,
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
        excludeFromSemantics: true,
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
                        fontWeight: FontWeight.w600,
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

class BioPayQrScannerSurface extends ConsumerStatefulWidget {
  const BioPayQrScannerSurface({
    super.key,
    required this.onDetect,
    this.error,
    this.isResolving = false,
    this.handoffComplete = false,
    this.scanRevision = 0,
    this.onRetry,
  });

  final ValueChanged<String> onDetect;
  final String? error;
  final bool isResolving;
  final bool handoffComplete;
  final int scanRevision;
  final VoidCallback? onRetry;

  @override
  ConsumerState<BioPayQrScannerSurface> createState() =>
      BioPayQrScannerSurfaceState();
}

class BioPayQrScannerSurfaceState extends ConsumerState<BioPayQrScannerSurface>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  Future<void> _cameraOperation = Future.value();
  bool _cameraActive = true;
  bool _openingSettings = false;
  String? _cameraActionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      cameraResolution: const Size(1920, 1080),
      autoZoom: true,
      initialZoom: 0.18,
      autoStart: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_updateCamera());
    });
  }

  @override
  void didUpdateWidget(covariant BioPayQrScannerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scanRevision != oldWidget.scanRevision) {
      unawaited(_restartCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _cameraActive = state == AppLifecycleState.resumed;
    unawaited(_updateCamera());
  }

  // Serialize stop/start, including permission-dialog and Settings transitions.
  // Read the latest lifecycle state when each queued operation executes.
  Future<void> _updateCamera({bool restart = false}) {
    _cameraOperation = _cameraOperation
        .then((_) async {
          if (!mounted) return;
          if (restart || !_cameraActive) await _controller.stop();
          if (!mounted) return;
          if (_cameraActive) await _controller.start();
        })
        .catchError((Object error) {
          if (mounted) {
            setState(
              () => _cameraActionError = 'Camera could not restart. Try again.',
            );
          }
        });
    return _cameraOperation;
  }

  Future<void> _restartCamera() {
    if (!mounted) return Future.value();
    setState(() => _cameraActionError = null);
    return _updateCamera(restart: true);
  }

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    setState(() {
      _openingSettings = true;
      _cameraActionError = null;
    });
    try {
      final opened = await ref
          .read(appPermissionServiceProvider)
          .openAppPermissionSettings();
      if (!opened && mounted) {
        setState(
          () => _cameraActionError =
              'Open device Settings and allow camera access for Mobio.',
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _cameraActionError =
              'Open device Settings and allow camera access for Mobio.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraOperation.then((_) => _controller.dispose()));
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
            child: MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              tapToFocus: true,
              onDetect: (capture) {
                final value = capture.barcodes.firstOrNull?.rawValue;
                if (value != null) widget.onDetect(value);
              },
              errorBuilder: (context, error) => _BioPayCameraRecovery(
                error: error,
                onRetry: _restartCamera,
                onOpenSettings: kIsWeb || _openingSettings
                    ? null
                    : _openSettings,
              ),
              overlayBuilder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
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
        ),
        if (_cameraActionError != null) ...[
          const SizedBox(height: AppSpacing.md),
          BioPayInlineError(message: _cameraActionError!),
          TextButton(
            onPressed: _restartCamera,
            child: const Text('Retry camera'),
          ),
        ],
        if (widget.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          BioPayInlineError(message: widget.error!),
        ],
        if (widget.isResolving) ...[
          const SizedBox(height: AppSpacing.md),
          const Center(child: Text('Reading QR…')),
        ],
        if (widget.handoffComplete) ...[
          const SizedBox(height: AppSpacing.md),
          const Center(child: Text('USSD dialer opened.')),
        ],
        if (!widget.isResolving &&
            (widget.error != null || widget.handoffComplete) &&
            widget.onRetry != null) ...[
          const SizedBox(height: AppSpacing.md),
          MobiButton(
            onPressed: widget.onRetry,
            child: const Text('Scan again'),
          ),
        ],
      ],
    );
  }
}

class _BioPayCameraRecovery extends StatelessWidget {
  const _BioPayCameraRecovery({
    required this.error,
    required this.onRetry,
    this.onOpenSettings,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;
    final title = denied
        ? 'Camera access needed'
        : unsupported
        ? 'No camera available'
        : 'Camera unavailable';
    final message = denied
        ? kIsWeb
              ? 'Allow camera access in your browser settings, then retry.'
              : 'Allow camera access in Settings to scan QR codes.'
        : unsupported
        ? 'Use a device with a camera to scan QR codes.'
        : 'Close any other camera app, then retry.';
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.camera,
                color: Theme.of(context).colorScheme.onSurface,
                size: 36,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.titleMd,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySm,
              ),
              const SizedBox(height: AppSpacing.md),
              if (denied && !kIsWeb) ...[
                MobiButton(
                  onPressed: onOpenSettings,
                  child: const Text('Open Settings'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextButton(onPressed: onRetry, child: const Text('Retry camera')),
            ],
          ),
        ),
      ),
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
      ..color = AppColors.warning;
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
  const BioPayInlineError({super.key, required this.message});

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
  const BioPayDetailRow({super.key, required this.label, required this.value});

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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.titleMd.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
