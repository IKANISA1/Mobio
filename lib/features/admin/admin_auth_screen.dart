import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin access screen — checks phone against admin allowlist.
/// No OTP. If approved → instant access. If not → contact admin popup.
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
  String _number = '';
  String _countryCode = '+250';
  bool _loading = false;
  String? _error;
  AdminService get _adminService => ref.read(adminServiceProvider);


  Future<void> _checkAccess() async {
    if (_number.length < 6) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final fullPhone = '$_countryCode$_number';
    final isAdmin = await _adminService.checkAdminAccess(fullPhone);

    if (!mounted) return;
    setState(() => _loading = false);

    if (isAdmin) {
      widget.onSuccess();
    } else {
      _showContactAdminDialog();
    }
  }

  void _showContactAdminDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.shieldOff, size: 28, color: cs.error),
                ),
                const SizedBox(height: 20),
                Text(
                  'Access Denied',
                  style: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This number is not registered as an admin. Contact the platform admin to request access.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                MobiButton(
                  width: double.infinity,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openWhatsApp();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.messageCircle,
                        size: 18,
                        color: cs.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Contact Admin',
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Go Back',
                    style: AppTypography.labelLg.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openWhatsApp() async {
    const adminNumber = '+250795588248';
    final message = Uri.encodeComponent(
      'Hello, I would like to request admin access to Mobio.',
    );
    final uri = Uri.parse(
      'https://wa.me/${adminNumber.replaceAll('+', '')}?text=$message',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
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
              TappableIconButton(
                icon: LucideIcons.chevronLeft,
                onTap: widget.onBack,
              ),

              const SizedBox(height: 40),

              Text(
                'Admin Access',
                style: AppTypography.headlineLg.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter the approved WhatsApp number.',
                style: AppTypography.bodySm.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 36),

              WhatsAppInput(
                value: _number,
                onChanged: (v) => setState(() => _number = v),
                countryCode: _countryCode,
                onCountryCodeChanged: (v) => setState(() => _countryCode = v),
                label: 'WhatsApp number',
              ),

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

              MobiButton(
                onPressed: _loading || _number.length < 6 ? null : _checkAccess,
                isLoading: _loading,
                width: double.infinity,
                child: Text(
                  _loading ? '' : 'Continue',
                  style: AppTypography.titleMd.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
