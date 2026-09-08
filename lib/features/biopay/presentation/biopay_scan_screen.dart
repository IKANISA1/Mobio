import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_flow_shared.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BioPayScanScreen extends ConsumerStatefulWidget {
  const BioPayScanScreen({super.key, required this.onBack, this.onEntry});
  final VoidCallback onBack;
  final Future<void> Function(String)? onEntry;
  @override
  ConsumerState<BioPayScanScreen> createState() => _BioPayScanScreenState();
}

class _BioPayScanScreenState extends ConsumerState<BioPayScanScreen> {
  bool _busy = false, _error = false;
  int _revision = 0;
  Future<void> _resolve(String raw) async {
    if (_busy) return;
    if (parsePaymentEntry(raw) == null) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      if (widget.onEntry != null) {
        await widget.onEntry!(raw);
      } else {
        await context.push(
          Uri(path: '/biopay/send', queryParameters: {'entry': raw}).toString(),
        );
      }
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _revision++;
        });
      }
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted) await _resolve(data?.text ?? '');
  }

  Future<void> _gallery() async {
    if (_busy) return;
    try {
      final path = await ref
          .read(paymentDiscoveryServiceProvider)
          .pickQrImage();
      if (!mounted || path == null) return;
      final scanner = MobileScannerController(autoStart: false);
      try {
        final capture = await scanner.analyzeImage(path);
        final values =
            capture?.barcodes
                .map((b) => b.rawValue)
                .whereType<String>()
                .where((v) => parsePaymentEntry(v) != null)
                .toSet()
                .toList() ??
            const <String>[];
        if (values.length != 1) {
          if (mounted) setState(() => _error = true);
          return;
        }
        if (mounted) await _resolve(values.single);
      } finally {
        await scanner.dispose();
      }
    } on Object {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    return PaymentTaskScaffold(
      title: l.bpScan,
      onBack: widget.onBack,
      busy: _busy,
      children: [
        BioPayQrScannerSurface(
          onDetect: (v) => unawaited(_resolve(v)),
          isResolving: _busy,
          scanRevision: _revision,
          error: _error ? l.bpInvalidQr : null,
          onRetry: () => setState(() {
            _error = false;
            _revision++;
          }),
        ),
        PaymentAction(
          label: l.bpManual,
          secondary: true,
          onPressed: _busy ? null : () => context.push('/biopay/send'),
        ),
        PaymentAction(
          label: l.bpPaste,
          secondary: true,
          onPressed: _busy ? null : _paste,
        ),
        PaymentAction(
          label: l.bpGallery,
          secondary: true,
          onPressed: _busy ? null : _gallery,
        ),
      ],
    );
  }
}
