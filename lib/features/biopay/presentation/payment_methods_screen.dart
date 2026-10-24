import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';

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
  String? _errorMessage;
  int _revision = 0;
  BuildContext? _sharingContext;
  BuildContext? _grantContext;
  final _sharingFocus = <String, FocusNode>{};

  FocusNode _sharingFocusFor(String id) => _sharingFocus.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'Payment method sharing $id'),
  );
  @override
  void initState() {
    super.initState();
    AccountContext.changes.addListener(_accountChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _revision++;
    AccountContext.changes.removeListener(_accountChanged);
    for (final focus in _sharingFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  void _accountChanged() {
    _revision++;
    for (final modal in [_grantContext, _sharingContext]) {
      if (modal != null &&
          modal.mounted &&
          ModalRoute.of(modal)?.isCurrent == true) {
        FocusScope.of(modal).unfocus();
        Navigator.of(modal).pop();
      }
    }
    if (!mounted) return;
    setState(() {
      _methods = const [];
      _busy = false;
      _error = false;
      _errorMessage = null;
    });
    unawaited(_load());
  }

  bool _current(
    PaymentDiscoveryGateway service,
    AccountSnapshot account,
    int revision,
  ) => mounted && revision == _revision && service.isCurrent(account);

  Future<void> _load() async {
    final service = ref.read(paymentDiscoveryServiceProvider);
    final revision = ++_revision;
    AccountSnapshot? account;
    setState(() {
      _busy = true;
      _error = false;
      _errorMessage = null;
    });
    try {
      account = service.captureAccount();
      final workspace = await service.call('workspace', {});
      if (_current(service, account, revision)) {
        setState(() => _methods = workspaceMethods(workspace));
      }
    } on Object {
      if (mounted &&
          revision == _revision &&
          (account == null || service.isCurrent(account))) {
        setState(() => _error = true);
      }
    } finally {
      if (mounted &&
          revision == _revision &&
          (account == null || service.isCurrent(account))) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _edit([PaymentMethod? method]) async {
    final service = ref.read(paymentDiscoveryServiceProvider);
    final account = service.captureAccount();
    final revision = _revision;
    if (method != null && method.ownerId != account.userId) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PaymentMethodEditor(method: method)),
    );
    if (_current(service, account, revision)) await _load();
  }

  Future<void> _sharing(PaymentMethod method) async {
    final l = paymentCopy(context);
    final service = ref.read(paymentDiscoveryServiceProvider);
    final revision = _revision;
    final triggerFocus = _sharingFocusFor(method.id);
    var restoreTrigger = true;
    AccountSnapshot? account;
    try {
      account = service.captureAccount();
      if (method.ownerId != account.userId) return;
      final sharingAccount = account;
      final info = await service.call('sharing', {'id': method.id});
      if (!_current(service, sharingAccount, revision)) return;
      await MobiBottomSheet.show<void>(
        context: context,
        title: l.bpViewAsPayer,
        closeLabel: MaterialLocalizations.of(context).closeButtonLabel,
        header: MobiBottomSheetHeader.dismissibleTask,
        tone: MobiBottomSheetTone.neutral,
        maxHeightFraction: .8,
        builder: (context) {
          _sharingContext = context;
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
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
                      if (!_current(service, sharingAccount, revision)) return;
                      restoreTrigger = false;
                      Navigator.pop(context);
                      await _grant(
                        method,
                        account: sharingAccount,
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
                  if (!_current(service, sharingAccount, revision)) return;
                  restoreTrigger = false;
                  Navigator.pop(context);
                  unawaited(_grant(method, account: sharingAccount));
                },
              ),
            ],
          );
        },
      );
    } on Object catch (error) {
      if (mounted &&
          revision == _revision &&
          (account == null || service.isCurrent(account))) {
        setState(() {
          _error = true;
          _errorMessage = userMessageForError(
            error,
            fallback: l.bpRefreshRequired,
          );
        });
      }
    } finally {
      _sharingContext = null;
      if (restoreTrigger &&
          mounted &&
          account != null &&
          _current(service, account, revision) &&
          triggerFocus.context != null) {
        triggerFocus.requestFocus();
      }
    }
  }

  Future<void> _grant(
    PaymentMethod method, {
    required AccountSnapshot account,
    String? memberId,
    bool remove = false,
  }) async {
    final service = ref.read(paymentDiscoveryServiceProvider);
    final revision = _revision;
    if (!_current(service, account, revision) ||
        method.ownerId != account.userId)
      return;
    final l = paymentCopy(context);
    var input = memberId ?? '';
    String? value = memberId;
    if (!remove) {
      value = await showDialog<String>(
        context: context,
        builder: (context) {
          _grantContext = context;
          return AlertDialog(
            title: Text(l.bpGrant),
            content: TextField(
              onChanged: (value) => input = value,
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
                  if (!_current(service, account, revision)) return;
                  if (RegExp(r'^[0-9]{6}$').hasMatch(input)) {
                    Navigator.pop(context, input);
                  }
                },
                child: Text(l.bpShare),
              ),
            ],
          );
        },
      );
    }
    _grantContext = null;
    if (value == null || !_current(service, account, revision)) return;
    try {
      await service.call('grant', {
        'method_id': method.id,
        'version': method.version,
        'member_id': value,
        'remove': remove,
      });
      if (_current(service, account, revision)) await _load();
    } on Object catch (error) {
      if (_current(service, account, revision)) {
        setState(() {
          _error = true;
          _errorMessage = userMessageForError(
            error,
            fallback: l.bpRefreshRequired,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final service = ref.read(paymentDiscoveryServiceProvider);
    AccountSnapshot? renderedAccount;
    try {
      renderedAccount = service.captureAccount();
    } on Object {
      renderedAccount = null;
    }
    final accountAtRender = renderedAccount;
    final renderedRevision = _revision;
    bool renderedCurrent() =>
        accountAtRender != null &&
        _current(service, accountAtRender, renderedRevision);
    return PaymentTaskScaffold(
      title: l.bpMethods,
      busy: _busy,
      onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
      action: PaymentAction(
        label: l.bpAddMethod,
        onPressed: _busy
            ? null
            : () {
                if (renderedCurrent()) unawaited(_edit());
              },
      ),
      children: [
        Text(l.bpPrivateDefault),
        if (_error) ...[
          PaymentError(_errorMessage ?? l.bpRefreshRequired),
          PaymentAction(
            label: l.bpRefresh,
            onPressed: () {
              if (renderedCurrent()) unawaited(_load());
            },
          ),
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
                  onTap: () {
                    if (renderedCurrent()) unawaited(_edit(method));
                  },
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
                    focusNode: _sharingFocusFor(method.id),
                    onPressed: () {
                      if (renderedCurrent()) unawaited(_sharing(method));
                    },
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
  bool _stale = false;
  String? _errorMessage;
  AccountSnapshot? _account;
  @override
  void initState() {
    super.initState();
    final service = ref.read(paymentDiscoveryServiceProvider);
    try {
      _account = service.captureAccount();
      _stale =
          widget.method != null && widget.method!.ownerId != _account!.userId;
    } on Object {
      _stale = true;
    }
    AccountContext.changes.addListener(_accountChanged);
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
    AccountContext.changes.removeListener(_accountChanged);
    _label.dispose();
    _identifier.dispose();
    _login.dispose();
    _sim.dispose();
    super.dispose();
  }

  void _accountChanged() {
    if (!mounted) return;
    final account = _account;
    if (account != null &&
        ref.read(paymentDiscoveryServiceProvider).isCurrent(account))
      return;
    FocusScope.of(context).unfocus();
    _label.clear();
    _identifier.clear();
    _login.clear();
    _sim.clear();
    setState(() {
      _stale = true;
      _busy = false;
      _error = false;
      _errorMessage = null;
    });
  }

  Future<void> _save({bool remove = false}) async {
    if (_busy || _stale || (!remove && !_form.currentState!.validate())) return;
    final service = ref.read(paymentDiscoveryServiceProvider);
    final account = _account;
    if (account == null || !service.isCurrent(account)) {
      _accountChanged();
      return;
    }
    final method = PaymentMethod(
      id: widget.method?.id ?? '',
      ownerId: account.userId,
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
      _errorMessage = null;
    });
    try {
      await service.call(
        remove ? 'remove_method' : 'save_method',
        method.toJson(),
      );
      if (mounted && service.isCurrent(account)) {
        safePop(context, fallback: '/profile/payment-methods');
      }
    } on Object catch (error) {
      if (mounted && service.isCurrent(account)) {
        setState(() {
          _error = true;
          _errorMessage = userMessageForError(
            error,
            fallback: paymentCopy(context).bpCheckFields,
          );
        });
      }
    } finally {
      if (mounted && service.isCurrent(account)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    return PaymentTaskScaffold(
      title: widget.method == null ? l.bpAddMethod : l.bpMethods,
      onBack: () => safePop(context, fallback: '/profile/payment-methods'),
      busy: _busy,
      action: PaymentAction(
        label: l.bpSave,
        onPressed: _busy || _stale ? null : _save,
      ),
      children: [
        if (_stale) PaymentError(l.bpRefreshRequired),
        if (!_stale) ...[
          if (_error) PaymentError(_errorMessage ?? l.bpCheckFields),
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
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
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
      ],
    );
  }
}
