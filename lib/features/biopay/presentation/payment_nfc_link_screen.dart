import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_service.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';

class PaymentNfcLinkScreen extends ConsumerStatefulWidget {
  const PaymentNfcLinkScreen({super.key});
  @override
  ConsumerState<PaymentNfcLinkScreen> createState() =>
      _PaymentNfcLinkScreenState();
}

class _PaymentNfcLinkScreenState extends ConsumerState<PaymentNfcLinkScreen> {
  final _nfc = const BioPayNfcService();
  late final BioPayNfcForegroundSuspendedNotifier _foreground;
  bool _suspendedForeground = false;
  List<Map<String, dynamic>> _links = const [];
  Map<String, dynamic>? _selected;
  bool _busy = false, _error = false, _written = false, _locked = false;
  @override
  void initState() {
    super.initState();
    _foreground = ref.read(bioPayNfcForegroundSuspendedProvider.notifier);
    unawaited(_load());
  }

  void _suspendForeground() {
    _suspendedForeground = true;
    _foreground.setSuspended(true);
  }

  void _resumeForeground() {
    if (!_suspendedForeground) return;
    _suspendedForeground = false;
    _foreground.setSuspended(false);
  }

  Future<void> _load() async {
    try {
      final workspace = await ref
          .read(paymentDiscoveryServiceProvider)
          .call('workspace', {});
      if (!mounted) return;
      setState(
        () => _links = (workspace['links'] as List? ?? const [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .where(
              (x) =>
                  x['revoked_at'] == null &&
                  DateTime.parse(
                    x['expires_at'] as String,
                  ).isAfter(DateTime.now()),
            )
            .toList(),
      );
    } on Object {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _write() async {
    final link = _selected;
    if (_busy || link == null) return;
    setState(() {
      _busy = true;
      _error = false;
      _written = false;
      _locked = false;
    });
    _suspendForeground();
    try {
      final preview = await ref
          .read(paymentDiscoveryServiceProvider)
          .previewLink(link['token'] as String);
      if (preview['available'] != true) throw StateError('Link unavailable.');
      final result = await _nfc.writeCard(
        BioPayNfcCardPayload.paymentLink(link['token'] as String),
      );
      if (mounted) setState(() => _written = result.verified);
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      await _nfc.cancelActiveSession();
      if (mounted) {
        _resumeForeground();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _lock() async {
    final link = _selected;
    if (!_written || link == null || _busy) return;
    final l = paymentCopy(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.bpNfcLock),
        content: Text(l.bpNfcLockNotice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.bpCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.bpNfcLock),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    _suspendForeground();
    try {
      await _nfc.lockVerifiedCard(
        BioPayNfcCardPayload.paymentLink(link['token'] as String),
      );
      if (mounted) setState(() => _locked = true);
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      await _nfc.cancelActiveSession();
      if (mounted) {
        _resumeForeground();
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_cancelAndResumeForeground());
    super.dispose();
  }

  Future<void> _cancelAndResumeForeground() async {
    try {
      await _nfc.cancelActiveSession();
    } finally {
      // Defer the provider notification until the route has finished disposal.
      _resumeForeground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    return PaymentTaskScaffold(
      title: l.bpNfcWrite,
      busy: _busy,
      onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
      action: PaymentAction(
        label: _busy ? l.bpNfcHold : l.bpNfcWrite,
        onPressed: _busy || _selected == null ? null : _write,
      ),
      children: [
        Text(l.bpNfcScoped),
        if (_error) PaymentError(l.bpNfcRecovery),
        if (_written) Semantics(liveRegion: true, child: Text(l.bpNfcVerified)),
        if (_locked) Text(l.bpNfcLocked),
        if (_written && !_locked)
          PaymentAction(
            label: l.bpNfcLock,
            secondary: true,
            onPressed: _busy ? null : _lock,
          ),
        for (final link in _links)
          ListTile(
            title: Text(link['label'] as String),
            subtitle: Text(
              '${l.bpExpiry}: ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(link['expires_at'] as String).toLocal())}',
            ),
            selected: _selected?['id'] == link['id'],
            trailing: _selected?['id'] == link['id']
                ? const Icon(Icons.check_circle)
                : null,
            onTap: _busy
                ? null
                : () => setState(() {
                    _selected = link;
                    _written = false;
                    _locked = false;
                  }),
          ),
        PaymentAction(
          label: l.bpRequests,
          secondary: true,
          onPressed: _busy
              ? null
              : () async {
                  await context.push('/biopay/requests');
                  if (mounted) await _load();
                },
        ),
      ],
    );
  }
}
