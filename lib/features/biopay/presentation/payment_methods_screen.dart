import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});
  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  List<PaymentMethod> _methods = const [];
  bool _busy = false;
  bool _error = false;
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
      final workspace = await ref
          .read(paymentDiscoveryServiceProvider)
          .call('workspace', {});
      if (mounted) setState(() => _methods = workspaceMethods(workspace));
    } on Object {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([PaymentMethod? method]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PaymentMethodEditor(method: method)),
    );
    if (mounted) await _load();
  }

  Future<void> _sharing(PaymentMethod method) async {
    final l = paymentCopy(context);
    try {
      final info = await ref.read(paymentDiscoveryServiceProvider).call(
        'sharing',
        {'id': method.id},
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l.bpViewAsPayer,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              PaymentDetail(
                l.bpProvider,
                paymentProviders[method.provider] ?? method.provider,
              ),
              PaymentDetail(l.bpIdentifier, method.identifier),
              Text(
                method.phoneDiscoverable
                    ? l.bpDiscoverable
                    : l.bpPrivateDefault,
              ),
              const SizedBox(height: 24),
              Text(l.bpSharing, style: Theme.of(context).textTheme.titleLarge),
              for (final grant in info['grants'] as List? ?? const [])
                ListTile(
                  title: Text(grant['member_id'] as String? ?? l.bpShared),
                  trailing: IconButton(
                    tooltip: l.bpRemove,
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _grant(
                        method,
                        memberId: grant['member_id'] as String?,
                        remove: true,
                      );
                    },
                  ),
                ),
              for (final link in info['links'] as List? ?? const [])
                ListTile(
                  title: Text(link['label'] as String),
                  subtitle: Text(
                    link['revoked_at'] == null
                        ? '${l.bpExpiry} ${link['expires_at']}'
                        : l.bpRevoked,
                  ),
                ),
              PaymentAction(
                label: l.bpGrant,
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(_grant(method));
                },
              ),
            ],
          ),
        ),
      );
    } on Object {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _grant(
    PaymentMethod method, {
    String? memberId,
    bool remove = false,
  }) async {
    final l = paymentCopy(context);
    final input = TextEditingController(text: memberId);
    String? value = memberId;
    if (!remove) {
      value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.bpGrant),
          content: TextField(
            controller: input,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(labelText: l.bpGrantee),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.bpCancel),
            ),
            TextButton(
              onPressed: () {
                if (RegExp(r'^[0-9]{6}$').hasMatch(input.text)) {
                  Navigator.pop(context, input.text);
                }
              },
              child: Text(l.bpShare),
            ),
          ],
        ),
      );
    }
    input.dispose();
    if (value == null || !mounted) return;
    try {
      await ref.read(paymentDiscoveryServiceProvider).call('grant', {
        'method_id': method.id,
        'version': method.version,
        'member_id': value,
        'remove': remove,
      });
      if (mounted) await _load();
    } on Object {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    return PaymentTaskScaffold(
      title: l.bpMethods,
      busy: _busy,
      onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
      action: PaymentAction(
        label: l.bpAddMethod,
        onPressed: _busy ? null : _edit,
      ),
      children: [
        Text(l.bpPrivateDefault),
        if (_error) ...[
          PaymentError(l.bpRefreshRequired),
          PaymentAction(label: l.bpRefresh, onPressed: _load),
        ],
        for (final method in _methods)
          PaymentPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(method.label),
                  subtitle: Text(
                    '${paymentProviders[method.provider] ?? method.provider} · ${method.maskedIdentifier}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _edit(method),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (method.canSend)
                      Chip(
                        shape: const StadiumBorder(),
                        label: Text(l.bpSendRole),
                      ),
                    if (method.canReceive)
                      Chip(
                        shape: const StadiumBorder(),
                        label: Text(l.bpReceiveRole),
                      ),
                    if (method.preferred)
                      Chip(
                        shape: const StadiumBorder(),
                        label: Text(l.bpPreferred),
                      ),
                  ],
                ),
                if (method.canReceive)
                  TextButton(
                    onPressed: () => _sharing(method),
                    child: Text(l.bpViewAsPayer),
                  ),
              ],
            ),
          ),
        if (!_busy && _methods.isEmpty) Text(l.bpEmpty),
      ],
    );
  }
}

class PaymentMethodEditor extends ConsumerStatefulWidget {
  const PaymentMethodEditor({super.key, this.method});
  final PaymentMethod? method;
  @override
  ConsumerState<PaymentMethodEditor> createState() =>
      _PaymentMethodEditorState();
}

class _PaymentMethodEditorState extends ConsumerState<PaymentMethodEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _identifier;
  late final TextEditingController _login;
  late final TextEditingController _sim;
  late String _provider;
  late PaymentMethodKind _kind;
  late bool _send, _receive, _discoverable, _preferred;
  bool _busy = false, _error = false;
  @override
  void initState() {
    super.initState();
    final m = widget.method;
    _label = TextEditingController(text: m?.label);
    _identifier = TextEditingController(text: m?.identifier);
    _login = TextEditingController(text: m?.loginPhone);
    _sim = TextEditingController(text: m?.simLabel);
    _provider = m?.provider ?? 'mtn_rw';
    _kind = m?.kind ?? PaymentMethodKind.mobileWallet;
    _send = m?.canSend ?? false;
    _receive = m?.canReceive ?? true;
    _discoverable = m?.phoneDiscoverable ?? false;
    _preferred = m?.preferred ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _identifier.dispose();
    _login.dispose();
    _sim.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    if (_busy || (!remove && !_form.currentState!.validate())) return;
    final service = ref.read(paymentDiscoveryServiceProvider);
    final method = PaymentMethod(
      id: widget.method?.id ?? '',
      ownerId: service.ownerId ?? '',
      provider: _provider,
      kind: _kind,
      identifier: _kind == PaymentMethodKind.mobileWallet
          ? normalizeRwandaPhone(_identifier.text) ?? ''
          : _identifier.text.trim(),
      label: _label.text.trim(),
      loginPhone: _login.text.trim().isEmpty
          ? null
          : normalizeRwandaPhone(_login.text),
      simLabel: _sim.text.trim(),
      canSend: _send,
      canReceive: _receive,
      phoneDiscoverable: _discoverable,
      preferred: _preferred,
      version: widget.method?.version ?? 1,
    );
    if (!remove && method.validationError != null) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      await service.call(
        remove ? 'remove_method' : 'save_method',
        method.toJson(),
      );
      if (mounted) safePop(context, fallback: '/profile/payment-methods');
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
      title: widget.method == null ? l.bpAddMethod : l.bpMethods,
      onBack: () => safePop(context, fallback: '/profile/payment-methods'),
      busy: _busy,
      action: PaymentAction(label: l.bpSave, onPressed: _busy ? null : _save),
      children: [
        if (_error) PaymentError(l.bpCheckFields),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _label,
                maxLength: 60,
                decoration: InputDecoration(labelText: l.bpLabel),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.bpCheckFields : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _provider,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.bpProvider),
                items: paymentProviders.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _provider = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PaymentMethodKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.bpMethodKind),
                items: PaymentMethodKind.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(paymentKindLabel(l, v)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _kind = v!;
                  if (_kind == PaymentMethodKind.merchantCode) {
                    _send = false;
                    _preferred = false;
                    _receive = true;
                  }
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _identifier,
                maxLength: 40,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l.bpIdentifier),
                validator: (v) =>
                    v == null || v.isEmpty ? l.bpCheckFields : null,
              ),
              if (_kind == PaymentMethodKind.bankAccount ||
                  _kind == PaymentMethodKind.bankAlias)
                TextFormField(
                  controller: _login,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: l.bpLoginPhone),
                  validator: (v) =>
                      v != null &&
                          v.isNotEmpty &&
                          normalizeRwandaPhone(v) == null
                      ? l.bpCheckFields
                      : null,
                ),
              TextFormField(
                controller: _sim,
                maxLength: 40,
                decoration: InputDecoration(labelText: l.bpSim),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.bpSendRole),
                value: _send,
                onChanged: _kind == PaymentMethodKind.merchantCode
                    ? null
                    : (v) => setState(() {
                        _send = v;
                        if (!v) _preferred = false;
                      }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.bpReceiveRole),
                value: _receive,
                onChanged: (v) => setState(() {
                  _receive = v;
                  if (!v) _discoverable = false;
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.bpDiscoverable),
                value: _discoverable,
                onChanged: !_receive
                    ? null
                    : (v) => setState(() => _discoverable = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.bpPreferred),
                value: _preferred,
                onChanged: !_send
                    ? null
                    : (v) => setState(() => _preferred = v),
              ),
            ],
          ),
        ),
        if (widget.method != null)
          TextButton(
            onPressed: _busy ? null : () => _save(remove: true),
            child: Text(l.bpRemove),
          ),
      ],
    );
  }
}
