import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_app/shared/widgets/otp_code_field.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';

class WhatsAppLoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<AppRole> onSuccess;
  final AppRole initialRole;

  const WhatsAppLoginScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
    this.initialRole = AppRole.passenger,
  });

  @override
  ConsumerState<WhatsAppLoginScreen> createState() =>
      _WhatsAppLoginScreenState();
}

class _WhatsAppLoginScreenState extends ConsumerState<WhatsAppLoginScreen> {
  static const _defaultResendCooldown = 60;

  final _otpController = TextEditingController();

  late AppRole _role;
  String _number = '';
  String _countryCode = '+250';
  String? _error;
  String? _statusMessage;
  int? _attemptsRemaining;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _otpRequested = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  bool get _isBusy => _sendingCode || _verifyingCode;

  bool get _canSendCode => !_isBusy && _number.trim().length >= 6;

  bool get _canVerifyCode => !_isBusy && _otpController.text.trim().length == 6;

  String get _fullPhone => '$_countryCode${_number.trim()}';

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole == AppRole.driver
        ? AppRole.driver
        : AppRole.passenger;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool isResend = false}) async {
    if (!_canSendCode) {
      return;
    }

    setState(() {
      _sendingCode = true;
      _error = null;
      _statusMessage = null;
      _attemptsRemaining = null;
    });

    final result = await ref
        .read(whatsappLoginServiceProvider)
        .sendLoginOtp(phone: _fullPhone, role: _role);
    if (!mounted) {
      return;
    }

    if (result.success) {
      _startResendCooldown(result.retryAfterSeconds ?? _defaultResendCooldown);
      setState(() {
        _sendingCode = false;
        _otpRequested = true;
        _statusMessage =
            result.message ??
            (isResend
                ? 'A fresh verification code was sent to WhatsApp.'
                : 'Verification code sent to WhatsApp.');
      });
      return;
    }

    _startResendCooldown(result.retryAfterSeconds ?? 0);
    setState(() {
      _sendingCode = false;
      _error = result.message ?? 'Unable to send verification code.';
    });
  }

  Future<void> _verifyCode() async {
    if (!_canVerifyCode) {
      return;
    }

    setState(() {
      _verifyingCode = true;
      _error = null;
      _statusMessage = null;
      _attemptsRemaining = null;
    });

    final result = await ref
        .read(whatsappLoginServiceProvider)
        .verifyLoginOtp(
          phone: _fullPhone,
          code: _otpController.text,
          role: _role,
          countryCode: _countryCode,
        );
    if (!mounted) {
      return;
    }

    if (result.success) {
      widget.onSuccess(result.role ?? _role);
      return;
    }

    final message = result.message ?? 'Verification failed.';
    final attemptsRemaining = result.attemptsRemaining;
    final forceReset =
        attemptsRemaining == 0 ||
        message.toLowerCase().contains('request a new one');

    setState(() {
      _verifyingCode = false;
      _error = message;
      _attemptsRemaining = attemptsRemaining;
      if (forceReset) {
        _otpRequested = false;
        _otpController.clear();
      }
    });
  }

  void _resetOtpFlow() {
    _resendTimer?.cancel();
    setState(() {
      _otpRequested = false;
      _error = null;
      _statusMessage = null;
      _attemptsRemaining = null;
      _resendCooldown = 0;
      _otpController.clear();
    });
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    if (seconds <= 0) {
      setState(() => _resendCooldown = 0);
      return;
    }

    setState(() => _resendCooldown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
        return;
      }

      setState(() => _resendCooldown -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final ctaLabel = _otpRequested ? 'Verify code' : 'Send code';

    return Scaffold(
      backgroundColor: ext.surfaceContainerLow,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClayCard(
                    borderRadius: AppRadii.xl,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Back',
                          icon: const Icon(LucideIcons.chevronLeft),
                          onPressed: widget.onBack,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                LucideIcons.messageCircle,
                                size: 28,
                                color: cs.primary,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'WhatsApp login',
                                style: AppTypography.headlineLg.copyWith(
                                  color: cs.onSurface,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ClayCard(
                    borderRadius: AppRadii.xl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _otpRequested ? 'Enter OTP' : 'Account type',
                          style: AppTypography.headlineSm.copyWith(
                            color: cs.onSurface,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        MobiToggle(
                          labels: const ['Passenger', 'Driver'],
                          selectedIndex: _role == AppRole.passenger ? 0 : 1,
                          onChanged: _otpRequested || _isBusy
                              ? (_) {}
                              : (index) => setState(() {
                                  _role = index == 0
                                      ? AppRole.passenger
                                      : AppRole.driver;
                                }),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        WhatsAppInput(
                          value: _number,
                          onChanged: (value) => setState(() => _number = value),
                          countryCode: _countryCode,
                          onCountryCodeChanged: (value) =>
                              setState(() => _countryCode = value),
                          label: 'WhatsApp',
                          enabled: !_otpRequested && !_isBusy,
                        ),
                        if (_otpRequested) ...[
                          const SizedBox(height: AppSpacing.md),
                          MobiOtpCodeField(
                            controller: _otpController,
                            enabled: !_isBusy,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        MobiStateBanner(
                          icon: _otpRequested
                              ? LucideIcons.badgeCheck
                              : LucideIcons.lock,
                          title: _otpRequested
                              ? 'Code required'
                              : 'Verified WhatsApp required',
                          subtitle: _otpRequested
                              ? 'Codes expire after 5 minutes.'
                              : 'Trip scheduling, chat, and profile data use this verified identity.',
                          tone: _otpRequested
                              ? MobiStateBannerTone.positive
                              : MobiStateBannerTone.info,
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          MobiStateBanner(
                            icon: LucideIcons.messageSquare,
                            title: 'Status',
                            subtitle: _statusMessage,
                            tone: MobiStateBannerTone.info,
                          ),
                        ],
                        if (_attemptsRemaining != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          MobiStateBanner(
                            icon: LucideIcons.alertTriangle,
                            title: 'Attempts remaining',
                            subtitle:
                                '$_attemptsRemaining verification attempt${_attemptsRemaining == 1 ? '' : 's'} left.',
                            tone: MobiStateBannerTone.warning,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          MobiStateBanner(
                            icon: LucideIcons.alertTriangle,
                            title: 'Sign-in failed',
                            subtitle: _error,
                            tone: MobiStateBannerTone.danger,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  MobiButton(
                    onPressed: _otpRequested
                        ? (_canVerifyCode ? _verifyCode : null)
                        : (_canSendCode ? _sendCode : null),
                    isLoading: _isBusy,
                    variant: MobiButtonVariant.whatsapp,
                    width: double.infinity,
                    child: Text(
                      ctaLabel,
                      style: AppTypography.titleMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_otpRequested) ...[
                    const SizedBox(height: AppSpacing.sm),
                    MobiButton(
                      onPressed: _resendCooldown > 0 || _isBusy
                          ? null
                          : () => _sendCode(isResend: true),
                      variant: MobiButtonVariant.ghost,
                      width: double.infinity,
                      child: Text(
                        _resendCooldown > 0
                            ? 'Resend in ${_resendCooldown}s'
                            : 'Resend code',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MobiButton(
                      onPressed: _isBusy ? null : _resetOtpFlow,
                      variant: MobiButtonVariant.ghost,
                      width: double.infinity,
                      child: const Text('Use a different number'),
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
