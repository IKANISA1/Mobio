import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/domain/payment_payload.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';

class BioPayScanScreen extends ConsumerStatefulWidget {
  const BioPayScanScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<BioPayScanScreen> createState() => _BioPayScanScreenState();
}

class _BioPayScanScreenState extends ConsumerState<BioPayScanScreen> {
  BioPayUssdPaymentRequest? _request;
  bool _resolving = false;
  bool _externalActionBusy = false;
  bool _handledScan = false;
  int _scanRevision = 0;
  String? _error;

  void _retryScan() {
    if (_resolving || _request != null) return;
    setState(() {
      _handledScan = false;
      _error = null;
      _scanRevision++;
    });
  }

  Future<void> _resolve(String token) async {
    if (_resolving || _handledScan || _request != null) return;
    setState(() {
      _resolving = true;
      _error = null;
    });
    var isDirectUssd = false;
    try {
      final ussdCode = bioPayUssdCodeFromPayload(token);
      isDirectUssd = ussdCode.isNotEmpty;
      if (isDirectUssd) {
        final opened = await ref
            .read(biopayUssdServiceProvider)
            .launchUssdCode(ussdCode);
        if (!mounted) return;
        setState(() {
          // A successful handoff stays latched until an explicit new scan.
          // Failed/invalid scans remain eligible for the next detection.
          _handledScan = opened;
          if (!opened) _error = 'USSD dialer unavailable.';
        });
        return;
      }

      final resolvedToken = bioPayTokenFromPayload(token);
      if (resolvedToken.isEmpty) {
        setState(() => _error = 'Not a Mobio QR code. Try another code.');
        return;
      }
      final service = ref.read(biopayUssdServiceProvider);
      final request = SupabaseConfig.isConfigured
          ? await service.resolveRequest(resolvedToken)
          : service.resolvePreviewToken(resolvedToken);
      if (!mounted) return;
      setState(() {
        _request = request;
        _handledScan = true;
      });
    } on Object {
      if (!mounted) return;
      setState(
        () => _error = isDirectUssd
            ? 'USSD dialer unavailable.'
            : 'QR request unavailable.',
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _runExternalPaymentStep() async {
    final request = _request;
    if (request == null) return;
    setState(() {
      _externalActionBusy = true;
      _error = null;
    });
    try {
      final service = ref.read(biopayUssdServiceProvider);
      final updated = switch (request.status) {
        BioPayRequestStatus.readyToDial => await service.openUssdDialer(
          request,
        ),
        BioPayRequestStatus.dialerOpened => await service.markUserPaid(request),
        _ => request,
      };
      if (!mounted) return;
      if (updated == null) {
        setState(() => _error = 'USSD dialer unavailable.');
        return;
      }
      setState(() => _request = updated);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = 'External payment status unavailable.');
    } finally {
      if (mounted) setState(() => _externalActionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BioPayFlowScreen(
      title: 'Scan',
      primaryLabel: _request == null ? '' : externalActionLabel(_request!),
      isPrimaryLoading: _resolving || _externalActionBusy,
      onBack: widget.onBack,
      onPrimary: _request == null
          ? null
          : canRunExternalAction(_request)
          ? _runExternalPaymentStep
          : null,
      child: _request == null
          ? BioPayQrScannerSurface(
              onDetect: _resolve,
              error: _error,
              isResolving: _resolving,
              handoffComplete: _handledScan,
              scanRevision: _scanRevision,
              onRetry: _retryScan,
            )
          : BioPayResolvedPaymentPreview(request: _request!),
    );
  }
}
