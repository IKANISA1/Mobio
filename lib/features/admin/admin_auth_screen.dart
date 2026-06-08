import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/services/otp_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/otp_code_field.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin access screen — approved WhatsApp number plus OTP verification only.
class AdminAuthScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const AdminAuthScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  ConsumerState<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends ConsumerState<AdminAuthScreen> {
  static const _defaultResendCooldown = 60;
  static const _supportWhatsapp = String.fromEnvironment(
    'ADMIN_SUPPORT_WHATSAPP',
  );

  final _otpController = TextEditingController();

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

  bool get _hasSupportWhatsapp => _supportWhatsapp.trim().isNotEmpty;

  String get _maskedPhone {
    final trimmed = _fullPhone.trim();
    if (trimmed.length <= 4) {
      return trimmed;
    }

    return '${trimmed.substring(0, trimmed.length - 4)}${'•' * 4}';
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

    final result = await OtpService.sendOtp(_fullPhone);
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

    final message = result.message ?? 'Unable to send verification code.';
    final showContactAdmin = _looksLikeAllowlistDenial(message);
    _startResendCooldown(result.retryAfterSeconds ?? 0);
    setState(() {
      _sendingCode = false;
      _error = message;
    });

    if (showContactAdmin) {
      _showContactAdminDialog();
    }
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

    final result = await OtpService.verifyOtp(_fullPhone, _otpController.text);
    if (!mounted) {
      return;
    }

    if (result.success) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _verifyingCode = false;
          _error = 'Unable to restore the admin session.';
        });
        return;
      }

      AdminSessionGuard.grant(userId);
      widget.onSuccess();
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

  bool _looksLikeAllowlistDenial(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('not approved') ||
        normalized.contains('allowlist') ||
        normalized.contains('contact admin');
  }

  void _showContactAdminDialog() {
    if (!_hasSupportWhatsapp) {
      setState(() {
        _statusMessage =
            'Ask an existing platform admin to add this WhatsApp number to the allowlist.';
      });
      return;
    }

    MobiConfirmDialog.show(
      context: context,
      title: 'Access denied',
      body:
          'This number is not on the admin allowlist. Open WhatsApp and request access?',
      confirmLabel: 'WhatsApp',
    ).then((confirmed) {
      if (confirmed) {
        _openWhatsApp();
      }
    });
  }

  Future<void> _openWhatsApp() async {
    if (!_hasSupportWhatsapp) {
      _showSnackBar('Admin support contact is not configured.');
      return;
    }

    final message = Uri.encodeComponent(
      'Hello, I would like to request admin access to Mobio.',
    );
    final uri = Uri.parse(
      'https://wa.me/${_supportWhatsapp.replaceAll('+', '')}?text=$message',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (_) {
      if (mounted) _showSnackBar('Could not open WhatsApp.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final ctaLabel = _otpRequested ? 'Verify code' : 'Send code';

    return Scaffold(
      backgroundColor: ext.surfaceContainerLow,
      body: SoftGradient(
        child: SafeArea(
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
                    AdminPanel(
                      radius: AdminLayoutTokens.headerRadius,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminIconButton(
                            icon: LucideIcons.chevronLeft,
                            onPressed: widget.onBack,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const MobiStatusBadge(
                                  label: 'Admin',
                                  icon: LucideIcons.shieldCheck,
                                  tone: MobiStatusBadgeTone.brand,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Admin access',
                                  style: AppTypography.headlineLg.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AdminPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminSectionHeader(
                            title: _otpRequested ? 'Verify OTP' : 'Sign in',
                            subtitle: _otpRequested
                                ? 'Enter the 6-digit code sent to $_maskedPhone.'
                                : 'Use an allowlisted WhatsApp number to receive a login code.',
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
                                : LucideIcons.shield,
                            title: _otpRequested
                                ? 'Code required'
                                : 'Restricted access',
                            subtitle: _otpRequested
                                ? 'Codes expire after 5 minutes and protect admin sessions.'
                                : 'Only allowlisted admin numbers can request a code.',
                            tone: _otpRequested
                                ? MobiStateBannerTone.positive
                                : MobiStateBannerTone.neutral,
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
                                  '$_attemptsRemaining verification attempt${_attemptsRemaining == 1 ? '' : 's'} left before you need a new code.',
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
                    const SizedBox(height: AppSpacing.lg),
                    AdminPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminSectionHeader(
                            title: 'Need access?',
                            subtitle:
                                'Request allowlist approval or resend a code.',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (!_hasSupportWhatsapp) ...[
                            const MobiStateBanner(
                              icon: LucideIcons.alertTriangle,
                              title: 'Allowlist required',
                              subtitle:
                                  'Ask an existing platform admin to add your WhatsApp number.',
                              tone: MobiStateBannerTone.neutral,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              if (_hasSupportWhatsapp)
                                AdminActionChip(
                                  label: 'WhatsApp admin',
                                  icon: LucideIcons.messageCircle,
                                  tone: MobiStatusBadgeTone.info,
                                  onTap: _openWhatsApp,
                                ),
                              if (_otpRequested)
                                AdminActionChip(
                                  label: _resendCooldown > 0
                                      ? 'Resend in ${_resendCooldown}s'
                                      : 'Resend code',
                                  icon: LucideIcons.refreshCcw,
                                  tone: MobiStatusBadgeTone.brand,
                                  onTap: _resendCooldown > 0 || _isBusy
                                      ? null
                                      : () => _sendCode(isResend: true),
                                  isBusy: _sendingCode,
                                ),
                              if (_otpRequested)
                                AdminActionChip(
                                  label: 'Change number',
                                  icon: LucideIcons.pencil,
                                  tone: MobiStatusBadgeTone.neutral,
                                  onTap: _isBusy ? null : _resetOtpFlow,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    MobiButton(
                      onPressed: _otpRequested
                          ? (_canVerifyCode ? _verifyCode : null)
                          : (_canSendCode ? _sendCode : null),
                      isLoading: _isBusy,
                      width: double.infinity,
                      child: Text(
                        ctaLabel,
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_otpRequested) ...[
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
      ),
    );
  }
}
