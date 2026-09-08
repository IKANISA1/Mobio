import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_style.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class BioPayPaymentLinkScreen extends ConsumerStatefulWidget {
  const BioPayPaymentLinkScreen({
    super.key,
    required this.token,
    required this.onBack,
  });

  final String token;
  final VoidCallback onBack;

  @override
  ConsumerState<BioPayPaymentLinkScreen> createState() =>
      _BioPayPaymentLinkScreenState();
}

class _BioPayPaymentLinkScreenState
    extends ConsumerState<BioPayPaymentLinkScreen> {
  BioPayUssdPaymentRequest? _request;
  bool _loading = true;
  bool _dialing = false;
  bool _autoDialAttempted = false;
  String? _error;

  bool get _shouldAutoLaunchDialer => false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(biopayUssdServiceProvider);
      final request = SupabaseConfig.isConfigured
          ? await service.resolveRequest(widget.token)
          : service.resolvePreviewToken(widget.token);
      if (!mounted) return;
      setState(() {
        _request = request;
        _loading = false;
      });
      if (_shouldAutoLaunchDialer) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_autoDialAttempted) {
            unawaited(_openDialer(auto: true));
          }
        });
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Payment request unavailable or expired.';
      });
    }
  }

  Future<void> _openDialer({bool auto = false}) async {
    final request = _request;
    if (request == null || _dialing) return;
    if (auto) _autoDialAttempted = true;

    setState(() {
      _dialing = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(biopayUssdServiceProvider)
          .openUssdDialer(request);
      if (!mounted) return;
      if (updated == null) {
        setState(() {
          _error = _shouldAutoLaunchDialer
              ? 'Tap Open MoMo USSD if the dialer did not open.'
              : 'USSD dialer unavailable.';
        });
        return;
      }
      setState(() => _request = updated);
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = _shouldAutoLaunchDialer
            ? 'Tap Open MoMo USSD if the dialer did not open.'
            : 'USSD dialer unavailable.';
      });
    } finally {
      if (mounted) setState(() => _dialing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return BioPayFlowScreen(
      title: 'MoMo USSD Request',
      primaryLabel: '',
      onBack: widget.onBack,
      headerSpacing: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const _PaymentLinkStatusCard(
              icon: LucideIcons.loader2,
              title: 'Preparing MoMo USSD',
              body: 'Opening MoMo USSD outside Mobio.',
            )
          else if (request == null)
            _PaymentLinkStatusCard(
              icon: LucideIcons.alertTriangle,
              title: 'MoMo USSD request unavailable',
              body: _error ?? 'Ask the receiver to send a new link.',
            )
          else ...[
            _PaymentLinkStatusCard(
              icon: LucideIcons.badgeDollarSign,
              title: 'Mobio payment request',
              body: _shouldAutoLaunchDialer
                  ? 'Mobio is launching MoMo USSD outside the app.'
                  : 'Tap the button to open MoMo USSD outside the app.',
            ),
            const SizedBox(height: AppSpacing.md),
            BioPayResolvedPaymentPreview(request: request),
            const SizedBox(height: AppSpacing.md),
            MobiButton(
              onPressed: _dialing ? null : _openDialer,
              isLoading: _dialing,
              child: Text(
                _shouldAutoLaunchDialer ? 'Open again' : 'Open MoMo USSD',
              ),
            ),
          ],
          if (_error != null && request != null) ...[
            const SizedBox(height: AppSpacing.md),
            BioPayInlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _PaymentLinkStatusCard extends StatelessWidget {
  const _PaymentLinkStatusCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bioPayDarkPanel.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BioPayIconBox(
              icon: icon,
              color: bioPayBlue,
              background: Colors.white,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    style: AppTypography.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                      height: 1.25,
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
