import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/whatsapp_login_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
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

  String get _fullPhone => WhatsAppLoginService.normalizePhoneForCountry(
    phone: _number,
    countryCode: _countryCode,
  );

  String get _maskedPhone {
    final digits = _fullPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 5) {
      return _countryCode;
    }
    return '$_countryCode ...${digits.substring(digits.length - 3)}';
  }

  bool get _canSendCode =>
      !_isBusy && WhatsAppLoginService.isValidCanonicalPhone(_fullPhone);

  bool get _canVerifyCode => !_isBusy && _otpController.text.trim().length == 6;

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
        .sendLoginOtp(
          phone: _fullPhone,
          countryCode: _countryCode,
          role: _role,
        );
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
      backgroundColor: AppColors.dark.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ext.backgroundGradientTop,
              ext.backgroundGradientMid,
              ext.backgroundGradientBottom,
            ],
            stops: const [0, 0.34, 0.82],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 110, 20, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 560,
                          minHeight: constraints.maxHeight - 138,
                        ),
                        child: Column(
                          children: [
                            _LoginHero(
                              icon: _otpRequested
                                  ? LucideIcons.keyRound
                                  : LucideIcons.messageCircle,
                              title: _otpRequested
                                  ? 'Enter code'
                                  : 'WhatsApp login',
                            ),
                            const SizedBox(height: 74),
                            _RevolutAuthPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _otpRequested ? 'Verification' : 'Account',
                                    style: AppTypography.headlineSm.copyWith(
                                      color: cs.onSurface,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  if (_otpRequested) ...[
                                    _PhoneAnchor(
                                      value: _maskedPhone,
                                      role: _role == AppRole.driver
                                          ? 'Driver'
                                          : 'Passenger',
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    MobiOtpCodeField(
                                      controller: _otpController,
                                      enabled: !_isBusy,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ] else ...[
                                    MobiToggle(
                                      labels: const ['Passenger', 'Driver'],
                                      selectedIndex: _role == AppRole.passenger
                                          ? 0
                                          : 1,
                                      onChanged: _isBusy
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
                                      onChanged: (value) =>
                                          setState(() => _number = value),
                                      countryCode: _countryCode,
                                      onCountryCodeChanged: (value) =>
                                          setState(() => _countryCode = value),
                                      label: 'WhatsApp',
                                      enabled: !_isBusy,
                                    ),
                                  ],
                                  if (_shouldShowNotice) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    _buildNotice(context),
                                  ],
                                  const SizedBox(height: AppSpacing.lg),
                                  MobiButton(
                                    onPressed: _otpRequested
                                        ? (_canVerifyCode ? _verifyCode : null)
                                        : (_canSendCode ? _sendCode : null),
                                    isLoading: _isBusy,
                                    variant: MobiButtonVariant.primary,
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: 18,
                                    ),
                                    child: Text(ctaLabel),
                                  ),
                                  if (_otpRequested) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: MobiButton(
                                            onPressed:
                                                _resendCooldown > 0 || _isBusy
                                                ? null
                                                : () =>
                                                      _sendCode(isResend: true),
                                            variant: MobiButtonVariant.ghost,
                                            width: double.infinity,
                                            child: Text(
                                              _resendCooldown > 0
                                                  ? 'Resend ${_resendCooldown}s'
                                                  : 'Resend',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: MobiButton(
                                            onPressed: _isBusy
                                                ? null
                                                : _resetOtpFlow,
                                            variant: MobiButtonVariant.ghost,
                                            width: double.infinity,
                                            child: const Text('Change'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      _ChromeCircleButton(
                        tooltip: 'Back',
                        icon: LucideIcons.chevronLeft,
                        onPressed: widget.onBack,
                      ),
                      const Spacer(),
                      const _ChromeCircleButton(
                        tooltip: 'WhatsApp login',
                        icon: LucideIcons.messageCircle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotice(BuildContext context) {
    if (_error != null) {
      return _LoginNotice(
        icon: LucideIcons.alertTriangle,
        title: 'Sign-in failed',
        subtitle: _error,
        accent: AppColors.brandOrangeRed,
      );
    }

    if (_attemptsRemaining != null) {
      return _LoginNotice(
        icon: LucideIcons.alertTriangle,
        title: 'Attempts remaining',
        subtitle: '$_attemptsRemaining left.',
        accent: AppColors.caution,
      );
    }

    if (_statusMessage != null) {
      return const _LoginNotice(
        icon: LucideIcons.badgeCheck,
        title: 'Code sent',
        subtitle: null,
        accent: AppColors.brandMintGreen,
      );
    }

    return _LoginNotice(
      icon: _otpRequested ? LucideIcons.timer : LucideIcons.lock,
      title: _otpRequested ? 'Code required' : 'WhatsApp',
      subtitle: null,
      accent: _otpRequested ? AppColors.brandMintGreen : AppColors.info,
    );
  }

  bool get _shouldShowNotice =>
      _otpRequested ||
      _error != null ||
      _attemptsRemaining != null ||
      _statusMessage != null;
}

class _ChromeCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ChromeCircleButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 58,
        child: Material(
          color: Colors.black.withValues(alpha: ext.blackChromeAlpha),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icon, color: cs.onSurface, size: 26),
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  final IconData icon;
  final String title;

  const _LoginHero({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 42),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.displayMd.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _RevolutAuthPanel extends StatelessWidget {
  final Widget child;

  const _RevolutAuthPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerHigh.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadii.hero),
        border: Border.all(
          color: Colors.white.withValues(alpha: ext.surfacePanelBorderAlpha),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: ext.surfacePanelShadowAlpha),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: child,
      ),
    );
  }
}

class _PhoneAnchor extends StatelessWidget {
  final String value;
  final String role;

  const _PhoneAnchor({required this.value, required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(
          color: ext.borderSubtle.withValues(
            alpha: ext.surfacePanelBorderAlpha,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 16,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.brandMintGreen.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.messageCircle,
                color: AppColors.brandMintGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMd.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              role,
              style: AppTypography.labelLg.copyWith(
                color: cs.onSurface.withValues(alpha: 0.58),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;

  const _LoginNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(
          color: Colors.white.withValues(alpha: ext.hairlineAlpha),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 23),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMd.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.72),
                        height: 1.18,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
