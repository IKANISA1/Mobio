import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_qr_export.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
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
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final data = await ref
          .read(paymentDiscoveryServiceProvider)
          .call('workspace', {});
      if (mounted) setState(() => _workspace = data);
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mutate(String action, Map<String, dynamic> data) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      await ref.read(paymentDiscoveryServiceProvider).call(action, data);
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && !_error) await _load();
  }

  Future<void> _create({Map<String, dynamic>? template}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentRequestEditor(template: template),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _addRecent([Map<String, dynamic>? existing]) async {
    final l = paymentCopy(context);
    final phone = TextEditingController(text: existing?['lookup'] as String?);
    final nickname = TextEditingController(
      text: existing?['nickname'] as String?,
    );
    final selected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(l.bpCancel),
          ),
          TextButton(
            onPressed: () {
              if (normalizeRwandaPhone(phone.text) != null &&
                  nickname.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l.bpSave),
          ),
        ],
      ),
    );
    final input = {
      'favorite': existing?['favorite'] == true,
      'lookup': normalizeRwandaPhone(phone.text),
      'nickname': nickname.text.trim(),
    };
    phone.dispose();
    nickname.dispose();
    if (selected == true && mounted) await _mutate('save_recent', input);
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
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
      onBack: () => context.canPop() ? context.pop() : context.go('/biopay'),
      action: _section == 'requests' || _section == 'templates'
          ? PaymentAction(
              label: l.bpCreateRequest,
              onPressed: _busy ? null : _create,
            )
          : _section == 'recents'
          ? PaymentAction(label: l.bpSave, onPressed: _busy ? null : _addRecent)
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
                  onSelected: (_) => setState(() => _section = e.key),
                ),
              )
              .toList(),
        ),
        if (_error) ...[
          PaymentError(l.bpRefreshRequired),
          PaymentAction(label: l.bpRefresh, onPressed: _load),
        ],
        if (!_busy && rows.isEmpty) Text(l.bpEmpty),
        for (final row in rows)
          if (_section == 'requests')
            _request(row)
          else if (_section == 'activity')
            _activity(row)
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
                    onPressed: () => _create(
                      template: Map<String, dynamic>.from(row['data'] as Map),
                    ),
                    child: Text(l.bpUseTemplate),
                  ),
                  TextButton(
                    onPressed: () =>
                        _mutate('remove_template', {'id': row['id']}),
                    child: Text(l.bpRemove),
                  ),
                ],
              ),
            )
          else
            _recent(row),
      ],
    );
  }

  Widget _request(Map<String, dynamic> row) {
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
                methods: workspaceMethods(_workspace),
              ),
              child: Text(l.bpViewAsPayer),
            ),
          if (active)
            TextButton(
              onPressed: () => _mutate('revoke_link', {
                'id': row['id'],
                'version': row['version'],
              }),
              child: Text(l.bpRevoke),
            ),
          TextButton(
            onPressed: () => _mutate('save_template', {
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
            child: Text(l.bpSaveTemplate),
          ),
        ],
      ),
    );
  }

  Widget _recent(Map<String, dynamic> row) {
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
              onPressed: () => _mutate('save_recent', {
                ...row,
                'favorite': row['favorite'] != true,
              }),
            ),
          ),
          TextButton(
            onPressed: () => context.push(
              Uri(
                path: '/biopay/send',
                queryParameters: {'entry': row['lookup'] as String},
              ).toString(),
            ),
            child: Text(l.bpPayAgain),
          ),
          TextButton(
            onPressed: () => _addRecent(row),
            child: Text(l.bpNickname),
          ),
          TextButton(
            onPressed: () => _mutate('remove_recent', {'id': row['id']}),
            child: Text(l.bpRemove),
          ),
        ],
      ),
    );
  }

  Future<void> _payAgain(String id) async {
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final service = ref.read(paymentDiscoveryServiceProvider);
      final draft = await service.call('pay_again', {'id': id});
      await service.rememberDraft(
        draft['owner_id'] as String,
        draft['id'] as String,
      );
      if (mounted) await context.push('/biopay/send?resume=true');
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _activity(Map<String, dynamic> row) {
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
          Text('${(row['amount_minor'] as num).toInt() ~/ 100} RWF'),
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
                  : () => _mutate('acknowledge', {'id': row['id']}),
              child: Text(l.bpAcknowledge),
            ),
          if (row['discovery_quote_id'] != null &&
              row['payer_id'] ==
                  ref.read(paymentDiscoveryServiceProvider).ownerId)
            TextButton(
              onPressed: _busy ? null : () => _payAgain(row['id'] as String),
              child: Text(l.bpPayAgain),
            ),
          TextButton(
            onPressed: () => showPaymentSupport(
              context,
              attemptId: row['id'] as String,
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
  @override
  void initState() {
    super.initState();
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
    _label.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final workspace = await ref
          .read(paymentDiscoveryServiceProvider)
          .call('workspace', {});
      if (!mounted) return;
      setState(() {
        _methods = workspaceMethods(
          workspace,
        ).where((x) => x.canReceive).toList();
        _selected.removeWhere((id) => !_methods.any((m) => m.id == id));
      });
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy) return;
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
      if (!mounted) return;
      await showPaymentLink(context, link, methods: _methods);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    return PaymentTaskScaffold(
      title: l.bpCreateRequest,
      busy: _busy,
      onBack: () => Navigator.pop(context),
      action: PaymentAction(
        label: l.bpCreateRequest,
        onPressed: _busy ? null : _create,
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
          onChanged: (v) => setState(() {
            _scope = v!;
            _selected.clear();
          }),
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
            onChanged: (v) => setState(() {
              if (_scope == 'method') _selected.clear();
              if (v == true) {
                _selected.add(m.id);
              } else {
                _selected.remove(m.id);
              }
            }),
          ),
        if (_methods.isEmpty)
          PaymentAction(
            label: l.bpAddMethod,
            onPressed: () => context.push('/profile/payment-methods').then((_) {
              if (mounted) unawaited(_load());
            }),
          ),
        if (_scope == 'request') ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.bpAnyAmount),
            value: _any,
            onChanged: (v) => setState(() => _any = v),
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
          onChanged: (v) => setState(() => _purpose = v!),
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
            final now = widget.now();
            final value = await showDatePicker(
              context: context,
              initialDate: _expires,
              firstDate: now,
              lastDate: now.add(const Duration(days: 89)),
            );
            if (value != null && mounted) {
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
}) async {
  final l = paymentCopy(context);
  final url = bioPayShareUri(link['token'] as String).toString();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ConstrainedBox(
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
            onPressed: () => Clipboard.setData(ClipboardData(text: url)),
            secondary: true,
          ),
          const SizedBox(height: 12),
          PaymentAction(
            label: l.bpSaveQr,
            secondary: true,
            onPressed: () async {
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
                final saved = await saveBioPayQrPng(
                  png.buffer.asUint8List(),
                  fileName: 'mobio-request-qr.png',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(saved ? l.bpSaved : l.bpNotSaved)),
                  );
                }
              } on Object {
                if (context.mounted) {
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
                final box = context.findRenderObject() as RenderBox?;
                unawaited(
                  SharePlus.instance.share(
                    ShareParams(
                      text: url,
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
