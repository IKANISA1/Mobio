import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/services/otp_service.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Clean, minimalist WhatsApp OTP sign-in screen.
class AdminAuthScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const AdminAuthScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  String _step = 'phone'; // 'phone' | 'otp'
  String _number = '';
  String _countryCode = '+250';
  String _fullPhone = '';
  bool _loading = false;
  String? _error;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  // OTP
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocuses = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocuses) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldown = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  Future<void> _sendOtp() async {
    if (_number.length < 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _fullPhone = '$_countryCode$_number';

    final result = await OtpService.sendOtp(_fullPhone);
    if (!mounted) return;

    setState(() => _loading = false);

    if (result.success) {
      setState(() => _step = 'otp');
      _startCooldown(60);
      Future.delayed(const Duration(milliseconds: 100), () {
        _otpFocuses[0].requestFocus();
      });
    } else {
      if (result.retryAfterSeconds != null) {
        _startCooldown(result.retryAfterSeconds!);
      }
      setState(() => _error = result.message);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpValue;
    if (code.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await OtpService.verifyOtp(_fullPhone, code);
    if (!mounted) return;

    setState(() => _loading = false);

    if (result.success) {
      widget.onSuccess();
    } else {
      setState(() => _error = result.message);
      // Clear OTP fields on failure
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocuses[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              TappableIconButton(
                icon: LucideIcons.chevronLeft,
                onTap: _step == 'otp'
                    ? () => setState(() {
                          _step = 'phone';
                          _error = null;
                          for (final c in _otpControllers) {
                            c.clear();
                          }
                        })
                    : widget.onBack,
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                _step == 'phone' ? 'Sign in' : 'Enter code',
                style: AppTypography.headlineLg.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                _step == 'phone'
                    ? 'We\'ll send a code to your WhatsApp'
                    : 'Sent to $_fullPhone',
                style: AppTypography.bodySm.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 36),

              // Phone or OTP input
              if (_step == 'phone') _buildPhoneInput() else _buildOtpInput(),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: AppTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],

              const Spacer(),

              // Action button
              _buildActionButton(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return WhatsAppInput(
      value: _number,
      onChanged: (v) => setState(() => _number = v),
      countryCode: _countryCode,
      onCountryCodeChanged: (v) => setState(() => _countryCode = v),
      label: 'Phone number',
    );
  }

  Widget _buildOtpInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return Container(
          width: 46,
          height: 56,
          margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
          child: TextField(
            controller: _otpControllers[i],
            focusNode: _otpFocuses[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: AppTypography.headlineMd.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Theme.of(context).extension<MobiThemeExtension>()!.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) {
                _otpFocuses[i + 1].requestFocus();
              }
              if (v.isEmpty && i > 0) {
                _otpFocuses[i - 1].requestFocus();
              }
              // Auto-verify when all 6 digits entered
              if (_otpValue.length == 6) {
                _verifyOtp();
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildActionButton() {
    final isPhone = _step == 'phone';
    final enabled = isPhone ? _number.length >= 6 : _otpValue.length == 6;
    final hasCooldown = isPhone && _cooldown > 0;

    return MobiButton(
      onPressed: _loading || !enabled || hasCooldown
          ? null
          : (isPhone ? _sendOtp : _verifyOtp),
      isLoading: _loading,
      width: double.infinity,
      child: Text(
        _loading
            ? ''
            : (hasCooldown
                ? 'Resend in ${_cooldown}s'
                : (isPhone ? 'Continue' : 'Verify')),
        style: AppTypography.titleMd.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
