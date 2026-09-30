import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_service.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';
import 'package:mobi_app/features/biopay/presentation/payment_composer_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';

class PaymentNfcLinkScreen extends ConsumerStatefulWidget {
  const PaymentNfcLinkScreen({
    super.key,
    this.nfcService = const BioPayNfcService(),
  });
  final BioPayNfcService nfcService;
  @override
  ConsumerState<PaymentNfcLinkScreen> createState() =>
      _PaymentNfcLinkScreenState();
}

class _PaymentNfcLinkScreenState extends ConsumerState<PaymentNfcLinkScreen> {
  BioPayNfcService get _nfc => widget.nfcService;
  late final BioPayNfcForegroundSuspendedNotifier _foreground;
  AccountSnapshot? _viewAccount;
  int _revision = 0;
  int? _suspension;
  bool _accountLost = false;
  List<Map<String, dynamic>> _links = const [];
  Map<String, dynamic>? _selected;
  bool _busy = false, _error = false, _written = false, _locked = false;

  bool _current(AccountSnapshot? account, int revision) =>
      mounted &&
      !_accountLost &&
      revision == _revision &&
      account != null &&
      ref.read(paymentDiscoveryServiceProvider).isCurrent(account);

  @override
  void initState() {
    super.initState();
    _foreground = ref.read(bioPayNfcForegroundSuspendedProvider.notifier);
    AccountContext.changes.addListener(_accountChanged);
    unawaited(_load());
  }

  void _accountChanged() {
    if (_accountLost ||
        _viewAccount == null ||
        ref.read(paymentDiscoveryServiceProvider).isCurrent(_viewAccount!)) {
      return;
    }
    _revision++;
    _accountLost = true;
    setState(() {
      _links = const [];
      _selected = null;
      _busy = false;
      _written = false;
      _locked = false;
      _error = true;
    });
    unawaited(_cancelAndRelease(_suspension));
  }

  int _suspendForeground() {
    final lease = _foreground.acquireSuspension();
    _suspension = lease;
    return lease;
  }

  void _releaseForeground(int? lease) {
    if (lease == null) return;
    if (_suspension == lease) _suspension = null;
    _foreground.releaseSuspension(lease);
  }

  Future<void> _cancelAndRelease(int? lease) async {
    if (lease == null || !_foreground.ownsSuspension(lease)) return;
    try {
      await _nfc.cancelActiveSession();
    } finally {
      _releaseForeground(lease);
    }
  }

  Future<void> _load() async {
    if (_accountLost) return;
    final revision = ++_revision;
    AccountSnapshot? account;
    try {
      final service = ref.read(paymentDiscoveryServiceProvider);
      account = service.captureAccount();
      _viewAccount = account;
      final workspace = await service.call('workspace', {});
      if (!_current(account, revision)) return;
      setState(() {
        _selected = null;
        _written = false;
        _locked = false;
        _links = (workspace['links'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .where(
              (x) =>
                  x['revoked_at'] == null &&
                  DateTime.parse(
                    x['expires_at'] as String,
                  ).isAfter(DateTime.now()),
            )
            .toList();
      });
    } on Object {
      if (mounted && revision == _revision) setState(() => _error = true);
    }
  }

  Future<void> _write() async {
    final link = _selected;
    final account = _viewAccount;
    if (_busy || link == null || !_current(account, _revision)) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _error = false;
      _written = false;
      _locked = false;
    });
    final lease = _suspendForeground();
    try {
      final preview = await ref
          .read(paymentDiscoveryServiceProvider)
          .previewLink(link['token'] as String);
      if (!_current(account, revision) || !_foreground.ownsSuspension(lease)) {
        return;
      }
      if (preview['available'] != true) throw StateError('Link unavailable.');
      final result = await _nfc.writeCard(
        BioPayNfcCardPayload.paymentLink(link['token'] as String),
        onStep: (_) {
          if (!_current(account, revision) ||
              !_foreground.ownsSuspension(lease)) {
            throw const StaleAccountWork();
          }
        },
      );
      if (_current(account, revision) && _foreground.ownsSuspension(lease)) {
        setState(() => _written = result.verified);
      }
    } on Object {
      if (_current(account, revision)) setState(() => _error = true);
    } finally {
      if (_current(account, revision)) {
        await _cancelAndRelease(lease);
        if (_current(account, revision)) setState(() => _busy = false);
      }
    }
  }

  Future<void> _lock() async {
    final link = _selected;
    final account = _viewAccount;
    final revision = _revision;
    if (!_written || link == null || _busy || !_current(account, revision)) {
      return;
    }
    final l = paymentCopy(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PaymentAccountView(
        isCurrent: () => _current(account, revision),
        child: AlertDialog(
          title: Text(l.bpNfcLock),
          content: Text(l.bpNfcLockNotice),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.bpCancel),
            ),
            TextButton(
              onPressed: () {
                if (_current(account, revision)) Navigator.pop(context, true);
              },
              child: Text(l.bpNfcLock),
            ),
          ],
        ),
      ),
    );
    if (!_current(account, revision) ||
        confirmed != true ||
        !identical(link, _selected)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = false;
    });
    final lease = _suspendForeground();
    try {
      await _nfc.lockVerifiedCard(
        BioPayNfcCardPayload.paymentLink(link['token'] as String),
        onStep: (_) {
          if (!_current(account, revision) ||
              !_foreground.ownsSuspension(lease)) {
            throw const StaleAccountWork();
          }
        },
      );
      if (_current(account, revision) && _foreground.ownsSuspension(lease)) {
        setState(() => _locked = true);
      }
    } on Object {
      if (_current(account, revision)) setState(() => _error = true);
    } finally {
      if (_current(account, revision)) {
        await _cancelAndRelease(lease);
        if (_current(account, revision)) setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    AccountContext.changes.removeListener(_accountChanged);
    unawaited(_cancelAndRelease(_suspension));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final account = _viewAccount;
    final revision = _revision;
    return PaymentTaskScaffold(
      title: l.bpNfcWrite,
      busy: _busy,
      onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
      action: PaymentAction(
        label: _busy ? l.bpNfcHold : l.bpNfcWrite,
        onPressed: _busy || _selected == null || !_current(account, revision)
            ? null
            : _write,
      ),
      children: [
        Text(l.bpNfcScoped),
        if (_error) PaymentError(_accountLost ? l.bpSignIn : l.bpNfcRecovery),
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
                : () {
                    if (!_current(account, revision)) return;
                    setState(() {
                      _selected = link;
                      _written = false;
                      _locked = false;
                    });
                  },
          ),
        PaymentAction(
          label: l.bpRequests,
          secondary: true,
          onPressed: _busy || !_current(account, revision)
              ? null
              : () async {
                  await context.push('/biopay/requests');
                  if (_current(account, revision)) await _load();
                },
        ),
      ],
    );
  }
}
