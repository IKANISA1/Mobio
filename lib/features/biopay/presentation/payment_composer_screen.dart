import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/async/external_action.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/application/payment_composer_controller.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery_response.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';

class PaymentComposerScreen extends ConsumerStatefulWidget {
  const PaymentComposerScreen({super.key, this.entry, this.resume = false});
  final String? entry;
  final bool resume;
  @override
  ConsumerState<PaymentComposerScreen> createState() =>
      _PaymentComposerScreenState();
}

class _PaymentComposerScreenState extends ConsumerState<PaymentComposerScreen>
    with WidgetsBindingObserver {
  PaymentComposerController? _controller;
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  List<PaymentMethod> _methods = const [];
  List<Map<String, dynamic>> _recents = const [];
  bool _loading = true;
  bool _more = false;
  bool _allowLeave = false;
  String? _error;
  AccountSnapshot? _viewAccount;
  int _loadRevision = 0;

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
    _loadRevision++;
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _controller = null;
    _viewAccount = null;
    _phone.clear();
    _amount.clear();
    _reference.clear();
    setState(() {
      _methods = const [];
      _recents = const [];
      _loading = false;
      _error = 'authRequired';
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final revision = ++_loadRevision;
    AccountSnapshot? account;
    bool current() =>
        revision == _loadRevision &&
        _current(account) &&
        (origin?.isCurrent ?? true);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(paymentDiscoveryServiceProvider);
      account = service.captureAccount();
      _viewAccount = account;
      final owner = account.userId;
      final workspace = await service.call('workspace', {});
      if (!current()) return;
      PaymentDiscoveryResponse.validate('workspace', workspace, {}, owner);
      var draft = PaymentDraft(id: newBioPayUuid(), ownerId: owner);
      if (widget.resume) {
        final id = await service.rememberedDraft(owner);
        if (!current()) return;
        final rows = workspace['drafts'] as List? ?? const [];
        final saved = rows
            .whereType<Map<String, dynamic>>()
            .where((x) => x['id'] == id && x['owner_id'] == owner)
            .firstOrNull;
        if (saved != null) {
          draft = PaymentDraft.fromJson(Map<String, dynamic>.from(saved));
        }
      }
      final entry = widget.entry;
      if (entry != null && entry.isNotEmpty) {
        final parsed = parsePaymentEntry(entry);
        if (parsed != null) {
          draft = draft.copyWith(
            linkToken: parsed.legacy && parsed.token != null
                ? null
                : parsed.token,
            lookup: parsed.legacy && parsed.token != null
                ? 'legacy:${parsed.token}'
                : '',
            manualMethod: parsed.manual,
            amount: parsed.amount?.toString(),
            purpose: parsed.manual?.kind == PaymentMethodKind.merchantCode
                ? PaymentPurpose.merchant
                : null,
          );
        } else if (normalizeRwandaPhone(entry) != null) {
          draft = draft.copyWith(lookup: normalizeRwandaPhone(entry));
        } else {
          _error = 'invalidQr';
        }
      }
      if (!current()) return;
      _controller?.removeListener(_changed);
      _controller?.dispose();
      _methods = workspaceMethods(workspace);
      if (!widget.resume) {
        final preferred = _methods
            .where((m) => m.preferred && m.canSend && m.active)
            .firstOrNull;
        if (preferred != null) draft = draft.copyWith(sourceId: preferred.id);
      }
      _recents = (workspace['recents'] as List? ?? const [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      final controller = PaymentComposerController(
        gateway: service,
        draft: draft,
      )..addListener(_changed);
      _controller = controller;
      _phone.text = draft.lookup.startsWith('legacy:') ? '' : draft.lookup;
      _amount.text = draft.amount;
      _reference.text = draft.reference;
      setState(() => _loading = false);
      if (draft.attemptId != null) {
        controller.invalidateOnResume();
      } else if (draft.lookup.isNotEmpty ||
          draft.linkToken != null ||
          draft.manualMethod != null) {
        await controller.resolve();
        if (current() && identical(_controller, controller)) {
          _amount.text = controller.draft.amount;
          _reference.text = controller.draft.reference;
        }
      }
    } on Object {
      if (mounted && revision == _loadRevision) {
        setState(() {
          _loading = false;
          _error = 'refreshRequired';
        });
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _needsSave {
    final c = _controller;
    return c != null &&
        c.accountCurrent &&
        !c.saved &&
        c.draft.attemptId == null &&
        (c.draft.lookup.isNotEmpty ||
            c.draft.linkToken != null ||
            c.draft.manualMethod != null ||
            c.draft.amount.isNotEmpty);
  }

  Future<void> _leave(
    AccountSnapshot? account,
    PaymentComposerController? controller,
    AccountActionToken origin,
  ) async {
    if (!mounted ||
        !origin.isCurrent ||
        !identical(controller, _controller) ||
        !identical(account, _viewAccount)) {
      return;
    }
    if (_controller?.busy == true) return;
    if (_needsSave) {
      final l = paymentCopy(context);
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => PaymentAccountView(
          isCurrent: () => _current(account),
          child: AlertDialog(
            title: Text(l.bpSaveDraft),
            content: Text(l.bpLeaveDraft),
            actions: [
              TextButton(
                onPressed: () {
                  if (_current(account)) Navigator.pop(context);
                },
                child: Text(l.bpCancel),
              ),
              TextButton(
                onPressed: () {
                  if (_current(account)) Navigator.pop(context, 'discard');
                },
                child: Text(l.bpDiscard),
              ),
              TextButton(
                onPressed: () {
                  if (_current(account)) Navigator.pop(context, 'save');
                },
                child: Text(l.bpSave),
              ),
            ],
          ),
        ),
      );
      if (!_current(account) ||
          !identical(controller, _controller) ||
          choice == null) {
        return;
      }
      if (choice == 'save') {
        await controller!.save();
        if (!_current(account) ||
            !identical(controller, _controller) ||
            !controller.saved) {
          return;
        }
      }
    }
    setState(() => _allowLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted &&
        origin.isCurrent &&
        identical(controller, _controller) &&
        identical(account, _viewAccount)) {
      context.canPop() ? context.pop() : context.go('/biopay');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller?.invalidateOnResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AccountContext.changes.removeListener(_accountChanged);
    _loadRevision++;
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _phone.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickContact(
    AccountSnapshot? account,
    PaymentComposerController? controller,
  ) async {
    if (!_current(account) ||
        controller == null ||
        !identical(controller, _controller)) {
      return;
    }
    try {
      final selected = await ref
          .read(paymentDiscoveryServiceProvider)
          .pickPhone();
      if (!_current(account) ||
          !identical(controller, _controller) ||
          selected == null) {
        return;
      }
      final phone = normalizeRwandaPhone(selected['phone'] ?? '');
      if (phone == null) {
        setState(() => _error = 'checkFields');
        return;
      }
      // Contact nickname is intentionally not promoted to account identity.
      _phone.text = phone;
      _controller!.recipient = null;
      _controller!.edit(
        _controller!.draft.copyWith(lookup: phone, clearRecipient: true),
      );
    } on Object {
      if (_current(account)) setState(() => _error = 'checkFields');
    }
  }

  Future<void> _manual(
    AccountSnapshot? account,
    PaymentComposerController? controller,
  ) async {
    if (!_current(account) ||
        controller == null ||
        !identical(controller, _controller)) {
      return;
    }
    final l = paymentCopy(context);
    var provider = 'mtn_rw';
    var kind = PaymentMethodKind.mobileWallet;
    final number = TextEditingController();
    String? error;
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => PaymentAccountView(
        isCurrent: () => _current(account),
        child: StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(l.bpManual),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: provider,
                    decoration: InputDecoration(labelText: l.bpProvider),
                    items: paymentProviders.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (_current(account)) update(() => provider = v!);
                    },
                  ),
                  DropdownButtonFormField<PaymentMethodKind>(
                    isExpanded: true,
                    initialValue: kind,
                    decoration: InputDecoration(labelText: l.bpMethodKind),
                    items: PaymentMethodKind.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(paymentKindLabel(l, v)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (_current(account)) update(() => kind = v!);
                    },
                  ),
                  TextField(
                    controller: number,
                    decoration: InputDecoration(
                      labelText: l.bpIdentifier,
                      errorText: error,
                    ),
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 16),
                  Text(l.bpUnverified),
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
                  final identifier = kind == PaymentMethodKind.mobileWallet
                      ? normalizeRwandaPhone(number.text)
                      : number.text.trim();
                  final value = PaymentMethod(
                    id: 'manual',
                    ownerId: '',
                    version: 0,
                    provider: provider,
                    kind: kind,
                    identifier: identifier ?? '',
                    label: l.bpManual,
                  );
                  if (value.validationError != null) {
                    update(() => error = l.bpCheckFields);
                    return;
                  }
                  Navigator.pop(context, value);
                },
                child: Text(l.bpContinue),
              ),
            ],
          ),
        ),
      ),
    );
    number.dispose();
    if (!_current(account) ||
        !identical(controller, _controller) ||
        method == null) {
      return;
    }
    final c = _controller!;
    c.edit(
      c.draft.copyWith(
        lookup: '',
        clearRecipient: true,
        manualMethod: method,
        purpose: method.kind == PaymentMethodKind.merchantCode
            ? PaymentPurpose.merchant
            : PaymentPurpose.transfer,
      ),
    );
    await c.resolve();
  }

  Future<void> _sources(
    AccountSnapshot? account,
    PaymentComposerController? c,
  ) async {
    if (!_current(account) || c == null || !identical(c, _controller)) return;
    final screenContext = context;
    final l = paymentCopy(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PaymentAccountView(
        isCurrent: () => _current(account),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l.bpMyAccounts,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ListTile(
                title: Text(l.bpAllAccounts),
                onTap: () {
                  if (_current(account)) Navigator.pop(context, '');
                },
              ),
              for (final method in _methods)
                ListTile(
                  title: Text(method.label),
                  subtitle: Text(
                    '${paymentProviders[method.provider] ?? method.provider} · ${method.maskedIdentifier}'
                    '${!method.canSend
                        ? '\n${l.bpSourceUnavailable}'
                        : c.sourceAvailability[method.id] == null
                        ? ''
                        : '\n${paymentSourceReason(l, c.sourceAvailability[method.id]!)}'}',
                  ),
                  trailing: method.preferred
                      ? Icon(Icons.star, semanticLabel: l.bpPreferred)
                      : null,
                  enabled:
                      method.canSend && c.sourceAvailability[method.id] == null,
                  onTap: () {
                    if (_current(account)) Navigator.pop(context, method.id);
                  },
                ),
              PaymentAction(
                label: l.bpMethods,
                secondary: true,
                onPressed: () {
                  if (!_current(account) || !identical(c, _controller)) return;
                  Navigator.pop(context);
                  screenContext.push('/profile/payment-methods');
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && _current(account) && identical(c, _controller)) {
      c.edit(c.draft.copyWith(sourceId: picked));
    }
  }

  Future<void> _handoff(
    AccountSnapshot? account,
    PaymentComposerController? c,
  ) async {
    if (!_current(account) || c == null || !identical(c, _controller)) return;
    final prepared = await c.prepare();
    if (!_current(account) || !identical(c, _controller) || prepared == null) {
      return;
    }
    try {
      final service = ref.read(paymentDiscoveryServiceProvider);
      final opened = await service.openReviewedInstruction(prepared);
      if (!_current(account) || !identical(c, _controller)) return;
      if (opened) await c.record(PaymentEvidence.handoffOpened);
      // Failure leaves the reviewed, copyable instructions and unknown outcome.
    } on Object {
      if (_current(account)) setState(() => _error = 'refreshRequired');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final c = _controller;
    final account = _viewAccount;
    final origin = _origin();
    bool current() =>
        origin.isCurrent && _current(account) && identical(c, _controller);

    final error = _error ?? c?.error;
    final children = <Widget>[
      if (error != null)
        PaymentError(
          c?.failureMessage ??
              (error == 'wholeAmount'
                  ? l.bpWholeAmount
                  : error == 'invalidQr'
                  ? l.bpInvalidQr
                  : error == 'checkFields'
                  ? l.bpCheckFields
                  : error == 'recipientChanged'
                  ? l.bpRecipientChanged
                  : error == 'sourceChanged'
                  ? l.bpSourceChanged
                  : error == 'feeChanged'
                  ? l.bpFeeChanged
                  : error == 'routeChanged'
                  ? l.bpRouteChanged
                  : l.bpRefreshRequired),
        ),
      if (c != null && !c.accountCurrent) PaymentError(l.bpSignIn),
      if (!_loading && c == null)
        PaymentAction(
          label: l.bpRefresh,
          onPressed: () => _load(originAccount: account, origin: origin),
        ),
    ];
    if (c != null && c.accountCurrent) {
      if (c.step == ComposerStep.recipient) {
        children.addAll([
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l.bpPhone,
              hintText: '+250 7…',
            ),
            onChanged: (value) {
              if (!current()) return;
              c
                ..recipient = null
                ..edit(
                  c.draft.copyWith(
                    lookup: normalizeRwandaPhone(value) ?? value,
                    clearRecipient: true,
                  ),
                );
            },
          ),
          PaymentAction(
            label: l.bpContacts,
            onPressed: c.busy
                ? null
                : () {
                    if (current()) unawaited(_pickContact(account, c));
                  },
            secondary: true,
          ),
          PaymentAction(
            label: l.bpManual,
            onPressed: c.busy
                ? null
                : () {
                    if (current()) unawaited(_manual(account, c));
                  },
            secondary: true,
          ),
          if (_recents.isNotEmpty) ...[
            Text(l.bpRecents, style: Theme.of(context).textTheme.titleLarge),
            for (final recent in _recents.take(5))
              ListTile(
                title: Text(recent['nickname'] as String),
                subtitle: Text(recent['lookup'] as String),
                onTap: () {
                  if (!current()) return;
                  _phone.text = recent['lookup'] as String;
                  c.edit(
                    c.draft.copyWith(lookup: _phone.text, clearRecipient: true),
                  );
                },
              ),
          ],
        ]);
      } else if (c.step == ComposerStep.options) {
        children.addAll([
          PaymentPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.recipient?.assurance == 'manual'
                      ? l.bpUnverified
                      : l.bpShared,
                ),
                for (final method in c.recipient?.methods ?? <PaymentMethod>[])
                  PaymentDetail(
                    paymentProviders[method.provider] ?? method.provider,
                    method.identifier,
                  ),
                TextButton(
                  onPressed: () {
                    if (!current()) return;
                    c
                      ..recipient = null
                      ..edit(c.draft.copyWith(clearRecipient: true));
                  },
                  child: Text(l.bpChange),
                ),
              ],
            ),
          ),
          if (c.recipient?.methods.isEmpty ?? true) ...[
            PaymentError(l.bpNoShared),
            PaymentAction(
              label: l.bpManual,
              onPressed: () {
                if (current()) unawaited(_manual(account, c));
              },
            ),
          ],
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            readOnly: c.recipient?.fixedAmount != null,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              labelText: l.bpAmount,
              suffixText: 'RWF',
            ),
            style: Theme.of(context).textTheme.headlineLarge,
            onChanged: (value) {
              if (current()) c.edit(c.draft.copyWith(amount: value));
            },
          ),
          DropdownButtonFormField<PaymentPurpose>(
            isExpanded: true,
            key: ValueKey(c.draft.purpose),
            initialValue: c.draft.purpose,
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
            onChanged: c.recipient?.purpose != null
                ? null
                : (value) {
                    if (current()) c.edit(c.draft.copyWith(purpose: value));
                  },
          ),
          TextField(
            controller: _reference,
            readOnly: c.recipient?.reference.isNotEmpty ?? false,
            maxLength: 80,
            decoration: InputDecoration(labelText: l.bpReference),
            onChanged: (value) {
              if (current()) c.edit(c.draft.copyWith(reference: value));
            },
          ),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            tileColor: Theme.of(context).colorScheme.surfaceContainer,
            title: Text(l.bpFrom),
            subtitle: Text(
              _methods
                      .where((m) => m.id == c.draft.sourceId)
                      .firstOrNull
                      ?.label ??
                  l.bpAllAccounts,
            ),
            trailing: const Icon(Icons.expand_more),
            onTap: () {
              if (current()) unawaited(_sources(account, c));
            },
          ),
          if (c.quoteId != null && c.options.isEmpty)
            PaymentError(
              c.sourceAvailability[c.draft.sourceId] == null
                  ? l.bpNoOptions
                  : paymentSourceReason(
                      l,
                      c.sourceAvailability[c.draft.sourceId]!,
                    ),
            ),
          for (final option in c.options.take(_more ? c.options.length : 3))
            PaymentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${option.source.label} → ${paymentProviders[option.destination.provider] ?? option.destination.provider}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${option.destination.maskedIdentifier} · ${option.rail}',
                  ),
                  const SizedBox(height: 8),
                  Text(paymentFeeLabel(l, option.fee)),
                  Text(
                    option.fee.certainty == FeeCertainty.unknown
                        ? l.bpCheckProviderFee
                        : l.bpFeeReviewed,
                  ),
                  if (option.fee.totalUpperBound(parseRwf(c.draft.amount) ?? 0)
                      case final int total)
                    Text(
                      '${option.fee.certainty == FeeCertainty.exact ? l.bpTotal : l.bpTotalCap}: $total RWF',
                    ),
                  TextButton(
                    onPressed: c.busy
                        ? null
                        : () {
                            if (current()) c.review(option);
                          },
                    child: Text(l.bpReview),
                  ),
                ],
              ),
            ),
          if (!_more && c.options.length > 3)
            TextButton(
              onPressed: () {
                if (current()) setState(() => _more = true);
              },
              child: Text(l.bpMore),
            ),
          PaymentAction(
            label: l.bpSaveDraft,
            onPressed: c.busy
                ? null
                : () {
                    if (current()) unawaited(c.save());
                  },
            secondary: true,
          ),
          Semantics(
            liveRegion: true,
            child: Text(c.saved ? l.bpSaved : l.bpNotSaved),
          ),
        ]);
      } else if (c.step == ComposerStep.review && c.selected != null) {
        final option = c.selected!;
        children.addAll([
          Text(
            '${c.draft.amount} RWF',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          PaymentPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.recipient?.assurance == 'manual'
                      ? l.bpUnverified
                      : l.bpShared,
                ),
                PaymentDetail(
                  l.bpIdentifier,
                  '${paymentProviders[option.destination.provider]} · ${option.destination.identifier}',
                ),
                PaymentDetail(
                  l.bpFrom,
                  '${option.source.label} · ${option.source.maskedIdentifier}',
                ),
                PaymentDetail(
                  l.bpPurpose,
                  c.draft.purpose == PaymentPurpose.transfer
                      ? l.bpTransfer
                      : l.bpMerchant,
                ),
                PaymentDetail(l.bpFee, paymentFeeLabel(l, option.fee)),
                if (option.fee.totalUpperBound(int.parse(c.draft.amount))
                    case final int total)
                  PaymentDetail(
                    option.fee.certainty == FeeCertainty.exact
                        ? l.bpTotal
                        : l.bpTotalCap,
                    '$total RWF',
                  ),
                if (c.draft.reference.isNotEmpty)
                  PaymentDetail(l.bpReference, c.draft.reference),
                if (c.draft.reference.isNotEmpty && !option.supportsReference)
                  Text(l.bpReferenceLocalOnly),
                if (option.source.simLabel != null)
                  PaymentDetail(l.bpSim, option.source.simLabel!),
              ],
            ),
          ),
          Text(
            c.gateway.deviceFamily == 'android'
                ? l.bpSimGuidance
                : l.bpManualDevice,
          ),
          Text(l.bpExternalOnly),
          TextButton(
            onPressed: () {
              if (!current()) return;
              c.step = ComposerStep.options;
              _changed();
            },
            child: Text(l.bpChange),
          ),
        ]);
      } else if (c.step == ComposerStep.outcome) {
        children.addAll([
          Text(
            paymentEvidenceLabel(l, c.draft.evidence),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(l.bpOutcomeHelp),
          if (c.prepared?['instruction'] case final String instruction)
            PaymentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(instruction),
                  const SizedBox(height: 12),
                  Text(l.bpExternalOnly),
                  TextButton(
                    onPressed: () {
                      if (!current()) return;
                      ExternalAction.start(
                        Clipboard.setData(ClipboardData(text: instruction)),
                        operation: 'copy_to_clipboard',
                      );
                    },
                    child: Text(l.bpCopyInstructions),
                  ),
                ],
              ),
            ),
          PaymentAction(
            label: l.bpReportDone,
            onPressed:
                c.busy || c.draft.evidence == PaymentEvidence.userReported
                ? null
                : () {
                    if (current()) {
                      unawaited(c.record(PaymentEvidence.userReported));
                    }
                  },
            secondary: true,
          ),
          PaymentAction(
            label: l.bpSupport,
            secondary: true,
            onPressed: () => showPaymentSupport(
              context,
              attemptId: c.draft.attemptId,
              isCurrent: current,
              evidence: paymentEvidenceLabel(l, c.draft.evidence),
            ),
          ),
          PaymentAction(
            label: l.bpActivity,
            secondary: true,
            onPressed: () {
              if (current()) context.push('/biopay/activity');
            },
          ),
        ]);
      }
    }
    return PopScope<void>(
      canPop: _allowLeave || (!_needsSave && !(c?.busy ?? false)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave(account, c, origin));
      },
      child: PaymentTaskScaffold(
        title: c?.step == ComposerStep.review
            ? l.bpReview
            : c?.step == ComposerStep.outcome
            ? l.bpOutcome
            : c?.step == ComposerStep.options
            ? l.bpPay
            : l.bpRecipient,
        onBack: () => _leave(account, c, origin),
        busy: _loading || (c?.busy ?? false),
        action: c == null || !c.accountCurrent
            ? null
            : switch (c.step) {
                ComposerStep.recipient => PaymentAction(
                  label: l.bpContinue,
                  onPressed: c.busy || normalizeRwandaPhone(_phone.text) == null
                      ? null
                      : () {
                          if (current()) unawaited(c.resolve());
                        },
                ),
                ComposerStep.options => PaymentAction(
                  label: l.bpCompare,
                  onPressed: c.busy || (c.recipient?.methods.isEmpty ?? true)
                      ? null
                      : () {
                          if (current()) unawaited(c.quote());
                        },
                ),
                ComposerStep.review => PaymentAction(
                  label:
                      c.gateway.deviceFamily != 'android' ||
                          c.selected?.handoffMode != 'dial'
                      ? l.bpOpenProvider
                      : c.selected?.source.provider == 'mtn_rw'
                      ? l.bpOpenMomo
                      : l.bpOpenBank,
                  onPressed: c.busy
                      ? null
                      : () {
                          if (current()) unawaited(_handoff(account, c));
                        },
                ),
                ComposerStep.outcome => null,
              },
        children: children,
      ),
    );
  }
}

Future<void> showPaymentSupport(
  BuildContext context, {
  String? attemptId,
  required String evidence,
  bool Function()? isCurrent,
}) async {
  bool current() => context.mounted && (isCurrent?.call() ?? true);
  if (!current()) return;
  final l = paymentCopy(context);
  final summary = 'Mobio BioPay\n${attemptId ?? ''}\n$evidence';
  await showDialog<void>(
    context: context,
    builder: (context) => PaymentAccountView(
      isCurrent: current,
      child: AlertDialog(
        title: Text(l.bpSupportSummary),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.bpSupportNotice),
              const SizedBox(height: 16),
              SelectableText(summary),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (current()) Navigator.pop(context);
            },
            child: Text(l.bpBack),
          ),
          TextButton(
            onPressed: () {
              if (!current()) return;
              ExternalAction.start(
                Clipboard.setData(ClipboardData(text: summary)),
                operation: 'copy_to_clipboard',
              );
            },
            child: Text(l.bpCopy),
          ),
        ],
      ),
    ),
  );
}

/// Modal content remains tied to the account that opened it.
class PaymentAccountView extends StatelessWidget {
  const PaymentAccountView({
    super.key,
    required this.isCurrent,
    required this.child,
  });
  final bool Function() isCurrent;
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: AccountContext.changes,
    builder: (context, value, _) => isCurrent()
        ? child
        : const Material(
            child: Center(child: Text('Account changed. Close this view.')),
          ),
  );
}
