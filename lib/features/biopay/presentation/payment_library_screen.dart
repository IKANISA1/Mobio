import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/async/external_action.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_qr_export.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery_response.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';
import 'package:mobi_app/features/biopay/presentation/payment_composer_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class PaymentLibraryScreen extends ConsumerStatefulWidget {
  const PaymentLibraryScreen({super.key, this.section = 'requests'});
  final String section;
  @override
  ConsumerState<PaymentLibraryScreen> createState() =>
      _PaymentLibraryScreenState();
}

class _PaymentLibraryScreenState extends ConsumerState<PaymentLibraryScreen> {
  Map<String, dynamic> _workspace = {};
  bool _busy = false, _error = false;
  late String _section = widget.section;
  AccountSnapshot? _viewAccount;
  int _revision = 0;
  bool _current(AccountSnapshot? account) =>
      mounted &&
      account != null &&
      identical(account, _viewAccount) &&
      ref.read(paymentDiscoveryServiceProvider).isCurrent(account);
  AccountActionToken _origin() => AccountActionToken.capture(
    captureAccount: () {
      try {
        return ref.read(paymentDiscoveryServiceProvider).captureAccount();
      } on Object {
        return null;
      }
    },
  );

  void _accountChanged() {
    if (_viewAccount != null && _current(_viewAccount)) return;
    _revision++;
    _viewAccount = null;
    setState(() {
      _workspace = {};
      _busy = false;
      _error = true;
    });
  }

  @override
  void dispose() {
    _revision++;
    AccountContext.changes.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AccountContext.changes.addListener(_accountChanged);
    unawaited(_load());
  }

  Future<void> _load({
    AccountSnapshot? originAccount,
    AccountActionToken? origin,
  }) async {
    if (!mounted ||
        (origin != null && !origin.isCurrent) ||
        (originAccount != null && !_current(originAccount))) {
      return;
    }
    final revision = ++_revision;
    AccountSnapshot? account;
    bool current() =>
        revision == _revision &&
        _current(account) &&
        (origin?.isCurrent ?? true);
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final service = ref.read(paymentDiscoveryServiceProvider);
      account = service.captureAccount();
      _viewAccount = account;
      final data = await service.call('workspace', {});
      if (!current()) return;
      PaymentDiscoveryResponse.validate('workspace', data, {}, account.userId);
      setState(() => _workspace = data);
    } on Object {
      if (mounted && revision == _revision) setState(() => _error = true);
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _mutate(
    AccountSnapshot? account,
    String action,
    Map<String, dynamic> data,
  ) async {
    if (_busy || !_current(account)) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      await ref.read(paymentDiscoveryServiceProvider).call(action, data);
    } on Object {
      if (mounted && revision == _revision) setState(() => _error = true);
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
    if (_current(account) && revision == _revision && !_error) {
      await _load(originAccount: account);
    }
  }

  Future<void> _create(
    AccountSnapshot? account, {
    Map<String, dynamic>? template,
  }) async {
    if (!_current(account)) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentRequestEditor(template: template),
      ),
    );
    if (_current(account)) await _load(originAccount: account);
  }

  Future<void> _addRecent(
    AccountSnapshot? account, [
    Map<String, dynamic>? existing,
  ]) async {
    if (!_current(account)) return;
    final l = paymentCopy(context);
    final phone = TextEditingController(text: existing?['lookup'] as String?);
    final nickname = TextEditingController(
      text: existing?['nickname'] as String?,
    );
    final selected = await showDialog<bool>(
      context: context,
      builder: (context) => PaymentAccountView(
        isCurrent: () => _current(account),
        child: AlertDialog(
          title: Text(l.bpRecents),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: l.bpPhone),
                ),
                TextField(
                  controller: nickname,
                  maxLength: 60,
                  decoration: InputDecoration(labelText: l.bpNickname),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_current(account)) Navigator.pop(context);
              },
              child: Text(l.bpCancel),
            ),
            TextButton(
              onPressed: () {
                if (!_current(account)) return;
                if (normalizeRwandaPhone(phone.text) != null &&
                    nickname.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(l.bpSave),
            ),
          ],
        ),
      ),
    );
    final input = {
      'favorite': existing?['favorite'] == true,
      'lookup': normalizeRwandaPhone(phone.text),
      'nickname': nickname.text.trim(),
    };
    phone.dispose();
    nickname.dispose();
    if (selected == true && _current(account)) {
      await _mutate(account, 'save_recent', input);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final account = _viewAccount;
    final origin = _origin();
    bool current() => origin.isCurrent && _current(account);

    final sections = {
      'requests': l.bpRequests,
      'activity': l.bpActivity,
      'recents': l.bpRecents,
      'templates': l.bpTemplates,
    };
    final rows =
        (_workspace[_section == 'requests' ? 'links' : _section] as List? ??
                const [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
    return PaymentTaskScaffold(
      title: sections[_section]!,
      busy: _busy,
      onBack: () {
        if (!origin.isCurrent) return;
        context.canPop() ? context.pop() : context.go('/biopay');
      },
      action: _section == 'requests' || _section == 'templates'
          ? PaymentAction(
              label: l.bpCreateRequest,
              onPressed: _busy
                  ? null
                  : () {
                      if (current()) unawaited(_create(account));
                    },
            )
          : _section == 'recents'
          ? PaymentAction(
              label: l.bpSave,
              onPressed: _busy
                  ? null
                  : () {
                      if (current()) unawaited(_addRecent(account));
                    },
            )
          : null,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sections.entries
              .map(
                (e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _section == e.key,
                  onSelected: (_) {
                    if (origin.isCurrent) setState(() => _section = e.key);
                  },
                ),
              )
              .toList(),
        ),
        if (_error) ...[
          PaymentError(l.bpRefreshRequired),
          PaymentAction(
            label: l.bpRefresh,
            onPressed: () => _load(originAccount: account, origin: origin),
          ),
        ],
        if (!_busy && !_error && rows.isEmpty) Text(l.bpEmpty),
        for (final row in rows)
          if (_section == 'requests')
            _request(row, account, origin)
          else if (_section == 'activity')
            _activity(row, account, origin)
          else if (_section == 'templates')
            PaymentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    row['label'] as String,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () {
                      if (!current()) return;
                      unawaited(
                        _create(
                          account,
                          template: Map<String, dynamic>.from(
                            row['data'] as Map,
                          ),
                        ),
                      );
                    },
                    child: Text(l.bpUseTemplate),
                  ),
                  TextButton(
                    onPressed: () {
                      if (current()) {
                        unawaited(
                          _mutate(account, 'remove_template', {
                            'id': row['id'],
                          }),
                        );
                      }
                    },
                    child: Text(l.bpRemove),
                  ),
                ],
              ),
            )
          else
            _recent(row, account, origin),
      ],
    );
  }

  Widget _request(
    Map<String, dynamic> row,
    AccountSnapshot? account,
    AccountActionToken origin,
  ) {
    bool current() => origin.isCurrent && _current(account);
    final l = paymentCopy(context);
    final revoked = row['revoked_at'] != null;
    final expiry = DateTime.parse(row['expires_at'] as String);
    final versions = row['method_versions'] as Map;
    final methods = workspaceMethods(_workspace);
    final detailsCurrent = (row['method_ids'] as List).every(
      (id) => methods.any(
        (m) => m.id == id && m.canReceive && m.version == versions[id],
      ),
    );
    final active = !revoked && detailsCurrent && expiry.isAfter(DateTime.now());
    return PaymentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            row['label'] as String,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            row['amount_rwf'] == null
                ? l.bpAnyAmount
                : '${row['amount_rwf']} RWF',
          ),
          Text(
            revoked
                ? l.bpRevoked
                : !detailsCurrent
                ? l.bpDetailsChanged
                : active
                ? l.bpActive
                : l.bpExpired,
          ),
          Text(
            '${l.bpExpiry}: ${MaterialLocalizations.of(context).formatMediumDate(expiry.toLocal())}',
          ),
          if (active)
            TextButton(
              onPressed: () => showPaymentLink(
                context,
                row,
                methods: methods,
                isCurrent: current,
              ),
              child: Text(l.bpViewAsPayer),
            ),
          if (active)
            TextButton(
              onPressed: () {
                if (!current()) return;
                unawaited(
                  _mutate(account, 'revoke_link', {
                    'id': row['id'],
                    'version': row['version'],
                  }),
                );
              },
              child: Text(l.bpRevoke),
            ),
          TextButton(
            onPressed: () {
              if (!current()) return;
              unawaited(
                _mutate(account, 'save_template', {
                  'label': row['label'],
                  'data': {
                    'label': row['label'],
                    'scope': row['scope'],
                    'method_ids': row['method_ids'],
                    'amount_rwf': row['amount_rwf'],
                    'purpose': row['purpose'],
                    'reference': row['reference'],
                  },
                }),
              );
            },
            child: Text(l.bpSaveTemplate),
          ),
        ],
      ),
    );
  }

  Widget _recent(
    Map<String, dynamic> row,
    AccountSnapshot? account,
    AccountActionToken origin,
  ) {
    bool current() => origin.isCurrent && _current(account);
    final l = paymentCopy(context);
    return PaymentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(row['nickname'] as String),
            subtitle: Text(row['lookup'] as String),
            trailing: IconButton(
              tooltip: l.bpFavorite,
              icon: Icon(
                row['favorite'] == true ? Icons.star : Icons.star_border,
              ),
              onPressed: () {
                if (!current()) return;
                unawaited(
                  _mutate(account, 'save_recent', {
                    ...row,
                    'favorite': row['favorite'] != true,
                  }),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () {
              if (!current()) return;
              context.push(
                Uri(
                  path: '/biopay/send',
                  queryParameters: {'entry': row['lookup'] as String},
                ).toString(),
              );
            },
            child: Text(l.bpPayAgain),
          ),
          TextButton(
            onPressed: () {
              if (current()) unawaited(_addRecent(account, row));
            },
            child: Text(l.bpNickname),
          ),
          TextButton(
            onPressed: () {
              if (current()) {
                unawaited(_mutate(account, 'remove_recent', {'id': row['id']}));
              }
            },
            child: Text(l.bpRemove),
          ),
        ],
      ),
    );
  }

  Future<void> _payAgain(AccountSnapshot? account, String id) async {
    if (_busy || !_current(account)) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final service = ref.read(paymentDiscoveryServiceProvider);
      final draft = await service.call('pay_again', {'id': id});
      if (!_current(account) || revision != _revision) return;
      await service.rememberDraft(
        draft['owner_id'] as String,
        draft['id'] as String,
      );
      if (mounted && _current(account) && revision == _revision) {
        await context.push('/biopay/send?resume=true');
      }
    } on Object {
      if (mounted && revision == _revision) setState(() => _error = true);
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Widget _activity(
    Map<String, dynamic> row,
    AccountSnapshot? account,
    AccountActionToken origin,
  ) {
    bool current() => origin.isCurrent && _current(account);
    final l = paymentCopy(context);
    final evidence =
        PaymentEvidence.values
            .where((x) => x.name == row['evidence_kind'])
            .firstOrNull ??
        PaymentEvidence.outcomeUnknown;
    final snapshot = row['reviewed_snapshot'] as Map<String, dynamic>?;
    return PaymentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            row['payee_label'] as String,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            formatHistoricalAmountMinor(
              row['amount_minor'] as int,
              row['currency'] as String,
            ),
          ),
          Text(paymentEvidenceLabel(l, evidence)),
          Text('${DateTime.parse(row['updated_at'] as String).toLocal()}'),
          if (snapshot?['source'] case final Map<String, dynamic> source)
            Text(source['label'] as String? ?? ''),
          if (row['discovery_quote_id'] != null &&
              row['payee_id'] ==
                  ref.read(paymentDiscoveryServiceProvider).ownerId &&
              ![
                PaymentEvidence.receiverAcknowledged,
                PaymentEvidence.operatorReviewed,
                PaymentEvidence.providerConfirmed,
              ].contains(evidence))
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (current()) {
                        unawaited(
                          _mutate(account, 'acknowledge', {'id': row['id']}),
                        );
                      }
                    },
              child: Text(l.bpAcknowledge),
            ),
          if (row['discovery_quote_id'] != null &&
              row['payer_id'] ==
                  ref.read(paymentDiscoveryServiceProvider).ownerId)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (current()) {
                        unawaited(_payAgain(account, row['id'] as String));
                      }
                    },
              child: Text(l.bpPayAgain),
            ),
          TextButton(
            onPressed: () => showPaymentSupport(
              context,
              attemptId: row['id'] as String,
              isCurrent: current,
              evidence: paymentEvidenceLabel(l, evidence),
            ),
            child: Text(l.bpSupport),
          ),
        ],
      ),
    );
  }
}

class PaymentRequestEditor extends ConsumerStatefulWidget {
  const PaymentRequestEditor({
    super.key,
    this.template,
    this.now = DateTime.now,
  });
  final Map<String, dynamic>? template;
  final DateTime Function() now;
  @override
  ConsumerState<PaymentRequestEditor> createState() =>
      _PaymentRequestEditorState();
}

class _PaymentRequestEditorState extends ConsumerState<PaymentRequestEditor> {
  List<PaymentMethod> _methods = const [];
  final _label = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _selected = <String>{};
  String _scope = 'request';
  PaymentPurpose _purpose = PaymentPurpose.transfer;
  bool _any = false, _busy = false, _error = false;
  late final DateTime _startedAt = widget.now();
  late DateTime _expires = _startedAt.add(const Duration(days: 7));
  AccountSnapshot? _viewAccount;
  int _revision = 0;
  bool _current(AccountSnapshot? account) =>
      mounted &&
      account != null &&
      identical(account, _viewAccount) &&
      ref.read(paymentDiscoveryServiceProvider).isCurrent(account);
  AccountActionToken _origin() => AccountActionToken.capture(
    captureAccount: () {
      try {
        return ref.read(paymentDiscoveryServiceProvider).captureAccount();
      } on Object {
        return null;
      }
    },
  );

  void _accountChanged() {
    if (_viewAccount == null || _current(_viewAccount)) return;
    _revision++;
    _label.clear();
    _amount.clear();
    _reference.clear();
    setState(() {
      _methods = const [];
      _selected.clear();
      _busy = false;
      _error = true;
    });
  }

  @override
  void initState() {
    super.initState();
    AccountContext.changes.addListener(_accountChanged);
    final t = widget.template;
    if (t != null) {
      _label.text = t['label'] as String? ?? '';
      _amount.text = t['amount_rwf']?.toString() ?? '';
      _reference.text = t['reference'] as String? ?? '';
      _scope = t['scope'] as String? ?? 'request';
      _purpose = PaymentPurpose.values.byName(
        t['purpose'] as String? ?? 'transfer',
      );
      _any = t['amount_rwf'] == null;
      _selected.addAll((t['method_ids'] as List? ?? const []).cast<String>());
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _revision++;
    AccountContext.changes.removeListener(_accountChanged);
    _label.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load({
    AccountSnapshot? originAccount,
    AccountActionToken? origin,
  }) async {
    if (!mounted ||
        (origin != null && !origin.isCurrent) ||
        (originAccount != null && !_current(originAccount))) {
      return;
    }
    final revision = ++_revision;
    AccountSnapshot? account;
    bool current() =>
        revision == _revision &&
        _current(account) &&
        (origin?.isCurrent ?? true);
    setState(() => _busy = true);
    try {
      final service = ref.read(paymentDiscoveryServiceProvider);
      account = service.captureAccount();
      if (_viewAccount != null && !_current(_viewAccount)) return;
      _viewAccount = account;
      final workspace = await service.call('workspace', {});
      if (!current()) return;
      PaymentDiscoveryResponse.validate(
        'workspace',
        workspace,
        {},
        account.userId,
      );
      setState(() {
        _methods = workspaceMethods(
          workspace,
        ).where((x) => x.canReceive).toList();
        _selected.removeWhere((id) => !_methods.any((m) => m.id == id));
      });
    } on Object {
      if (mounted && revision == _revision) setState(() => _error = true);
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _create(AccountSnapshot? account) async {
    if (_busy || !_current(account)) return;
    final revision = ++_revision;
    final amount = _scope == 'request' && !_any ? parseRwf(_amount.text) : null;
    if (_selected.isEmpty ||
        (_scope == 'method' && _selected.length != 1) ||
        (_scope == 'request' && !_any && amount == null) ||
        _label.text.trim().isEmpty) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final link = await ref
          .read(paymentDiscoveryServiceProvider)
          .call('create_link', {
            'scope': _scope,
            'method_ids': _selected.toList(),
            'label': _label.text.trim(),
            'amount_rwf': amount,
            'purpose': _purpose.name,
            'reference': _reference.text.trim(),
            'expires_at': _expires.toUtc().toIso8601String(),
          });
      if (!mounted || !_current(account) || revision != _revision) return;
      await showPaymentLink(
        context,
        link,
        methods: _methods,
        isCurrent: () => _current(account),
      );
      if (mounted && _current(account) && revision == _revision) {
        safePop(context, fallback: '/biopay');
      }
    } on Object {
      if (mounted && revision == _revision) setState(() => _error = true);
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final account = _viewAccount;
    final origin = _origin();
    bool current() => origin.isCurrent && _current(account);
    void back() {
      if (origin.isCurrent) safePop(context, fallback: '/biopay');
    }

    if (_viewAccount != null && !_current(_viewAccount)) {
      return PaymentTaskScaffold(
        title: l.bpCreateRequest,
        onBack: back,
        children: [PaymentError(l.bpSignIn)],
      );
    }
    return PaymentTaskScaffold(
      title: l.bpCreateRequest,
      busy: _busy,
      onBack: back,
      action: PaymentAction(
        label: l.bpCreateRequest,
        onPressed: _busy
            ? null
            : () {
                if (current()) unawaited(_create(account));
              },
      ),
      children: [
        if (_error) PaymentError(l.bpCheckFields),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _scope,
          decoration: InputDecoration(labelText: l.bpScope),
          items: [
            DropdownMenuItem(value: 'profile', child: Text(l.bpProfileScope)),
            DropdownMenuItem(value: 'method', child: Text(l.bpMethodScope)),
            DropdownMenuItem(value: 'request', child: Text(l.bpRequestScope)),
          ],
          onChanged: (v) {
            if (!current()) return;
            setState(() {
              _scope = v!;
              _selected.clear();
            });
          },
        ),
        TextField(
          controller: _label,
          maxLength: 60,
          decoration: InputDecoration(labelText: l.bpLabel),
        ),
        for (final m in _methods)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(m.label),
            subtitle: Text(
              '${paymentProviders[m.provider]} · ${m.maskedIdentifier}',
            ),
            value: _selected.contains(m.id),
            onChanged: (v) {
              if (!current()) return;
              setState(() {
                if (_scope == 'method') _selected.clear();
                if (v == true) {
                  _selected.add(m.id);
                } else {
                  _selected.remove(m.id);
                }
              });
            },
          ),
        if (_methods.isEmpty && !_busy && !_error)
          PaymentAction(
            label: l.bpAddMethod,
            onPressed: () {
              if (!current()) return;
              context.push('/profile/payment-methods').then((_) {
                if (current()) {
                  unawaited(_load(originAccount: account, origin: origin));
                }
              });
            },
          ),
        if (_scope == 'request') ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.bpAnyAmount),
            value: _any,
            onChanged: (v) {
              if (current()) setState(() => _any = v);
            },
          ),
          if (!_any)
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: InputDecoration(labelText: l.bpAmount),
            ),
        ],
        DropdownButtonFormField<PaymentPurpose>(
          isExpanded: true,
          initialValue: _purpose,
          decoration: InputDecoration(labelText: l.bpPurpose),
          items: [
            DropdownMenuItem(
              value: PaymentPurpose.transfer,
              child: Text(l.bpTransfer),
            ),
            DropdownMenuItem(
              value: PaymentPurpose.merchant,
              child: Text(l.bpMerchant),
            ),
          ],
          onChanged: (v) {
            if (current()) setState(() => _purpose = v!);
          },
        ),
        TextField(
          controller: _reference,
          maxLength: 80,
          decoration: InputDecoration(labelText: l.bpReference),
        ),
        ListTile(
          title: Text(l.bpExpiry),
          subtitle: Text(
            MaterialLocalizations.of(context).formatMediumDate(_expires),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            if (!current()) return;
            final now = widget.now();
            final value = await showDatePicker(
              context: context,
              initialDate: _expires,
              firstDate: now,
              lastDate: now.add(const Duration(days: 89)),
            );
            if (value != null && current()) {
              setState(
                () => _expires = DateTime(
                  value.year,
                  value.month,
                  value.day,
                  23,
                  59,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

Future<void> showPaymentLink(
  BuildContext context,
  Map<String, dynamic> link, {
  List<PaymentMethod> methods = const [],
  bool Function()? isCurrent,
}) async {
  bool current() => context.mounted && (isCurrent?.call() ?? true);
  if (!current()) return;
  final l = paymentCopy(context);
  final url = bioPayShareUri(link['token'] as String).toString();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ValueListenableBuilder<int>(
      valueListenable: AccountContext.changes,
      builder: (context, value, child) => !current()
          ? const Material(
              child: Center(child: Text('Account changed. Close this view.')),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .9,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    link['label'] as String,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Semantics(
                      label: l.bpRequestScope,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: QrImageView(
                          data: url,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    link['amount_rwf'] == null
                        ? l.bpAnyAmount
                        : '${link['amount_rwf']} RWF',
                  ),
                  Text(l.bpBearerScope),
                  for (final method in methods.where(
                    (m) => (link['method_ids'] as List).contains(m.id),
                  ))
                    PaymentDetail(
                      paymentProviders[method.provider] ?? method.provider,
                      method.identifier,
                    ),
                  SelectableText(url),
                  const SizedBox(height: 16),
                  PaymentAction(
                    label: l.bpCopy,
                    onPressed: () {
                      if (!current()) return;
                      ExternalAction.start(
                        Clipboard.setData(ClipboardData(text: url)),
                        operation: 'copy_to_clipboard',
                      );
                    },
                    secondary: true,
                  ),
                  const SizedBox(height: 12),
                  PaymentAction(
                    label: l.bpSaveQr,
                    secondary: true,
                    onPressed: () async {
                      if (!current()) return;
                      try {
                        final qr = await QrPainter(
                          data: url,
                          version: QrVersions.auto,
                          gapless: false,
                        ).toImage(1024);
                        final recorder = ui.PictureRecorder();
                        Canvas(recorder)
                          ..drawColor(Colors.white, BlendMode.src)
                          ..drawImage(qr, const Offset(80, 80), Paint());
                        final picture = recorder.endRecording();
                        final export = await picture.toImage(1184, 1184);
                        final png = await export.toByteData(
                          format: ui.ImageByteFormat.png,
                        );
                        export.dispose();
                        picture.dispose();
                        qr.dispose();
                        if (png == null) throw StateError('QR unavailable');
                        if (!current()) return;
                        final saved = await saveBioPayQrPng(
                          png.buffer.asUint8List(),
                          fileName: 'mobio-request-qr.png',
                        );
                        if (context.mounted && current()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(saved ? l.bpSaved : l.bpNotSaved),
                            ),
                          );
                        }
                      } on Object {
                        if (context.mounted && current()) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l.bpNotSaved)));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) => PaymentAction(
                      label: l.bpShare,
                      onPressed: () {
                        if (!current()) return;
                        final box = context.findRenderObject() as RenderBox?;
                        ExternalAction.start(
                          SharePlus.instance.share(
                            ShareParams(
                              text: url,
                              sharePositionOrigin: box == null
                                  ? null
                                  : box.localToGlobal(Offset.zero) & box.size,
                            ),
                          ),
                          operation: 'share_payment_link',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
