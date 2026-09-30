import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';

class PaymentProviderRoutesScreen extends ConsumerStatefulWidget {
  const PaymentProviderRoutesScreen({super.key});
  @override
  ConsumerState<PaymentProviderRoutesScreen> createState() =>
      _PaymentProviderRoutesScreenState();
}

class _PaymentProviderRoutesScreenState
    extends ConsumerState<PaymentProviderRoutesScreen> {
  final _actionToken = AccountActionToken.capture();
  bool get _actionIsCurrent => mounted && _actionToken.isCurrent;

  Map<String, dynamic> _data = {};
  bool _busy = false, _error = false;
  String? _errorMessage;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> data,
  ) async {
    return ref.read(paymentDiscoveryServiceProvider).adminCall(action, data);
  }

  Future<void> _load() async {
    if (!_actionIsCurrent) return;
    setState(() {
      _busy = true;
      _error = false;
      _errorMessage = null;
    });
    try {
      final value = await _call('list', {});
      if (_actionIsCurrent) setState(() => _data = value);
    } on Object catch (error) {
      if (_actionIsCurrent) {
        setState(() {
          _error = true;
          _errorMessage = userMessageForError(
            error,
            fallback: paymentCopy(context).bpRefreshRequired,
          );
        });
      }
    } finally {
      if (_actionIsCurrent) setState(() => _busy = false);
    }
  }

  Future<void> _transition(String action, Map<String, dynamic> route) async {
    if (!_actionIsCurrent) return;
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = false;
      _errorMessage = null;
    });
    try {
      await _call(action, {
        'id': route['id'],
        'adapter_version': route['adapter_version'],
      });
    } on Object catch (error) {
      if (_actionIsCurrent) {
        setState(() {
          _error = true;
          _errorMessage = userMessageForError(
            error,
            fallback: paymentCopy(context).bpRefreshRequired,
          );
        });
      }
    } finally {
      if (_actionIsCurrent) setState(() => _busy = false);
    }
    if (_actionIsCurrent && !_error) await _load();
  }

  Future<void> _edit([Map<String, dynamic>? route]) async {
    if (!_actionIsCurrent) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _RouteEditor(route: route, actionToken: _actionToken),
      ),
    );
    if (result == null || !_actionIsCurrent) return;
    try {
      await _call('save', result);
      if (_actionIsCurrent) await _load();
    } on Object catch (error) {
      if (_actionIsCurrent) {
        setState(() {
          _error = true;
          _errorMessage = userMessageForError(
            error,
            fallback: paymentCopy(context).bpRefreshRequired,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final statuses = {
      'draft': l.bpDraftRoute,
      'tested': l.bpTestedRoute,
      'approved': l.bpApprovedRoute,
      'disabled': l.bpDisabledRoute,
    };
    return Scaffold(
      body: AdminWorkspaceFrame(
        currentTab: AdminWorkspaceTab.biopayOps,
        title: l.bpRoutes,
        subtitle: l.bpRouteEvidence,
        actions: [
          AdminActionChip(
            label: l.bpAddRoute,
            icon: LucideIcons.plus,
            onTap: _busy ? null : _edit,
          ),
          AdminActionChip(
            label: l.bpRefresh,
            icon: LucideIcons.refreshCw,
            isBusy: _busy,
            onTap: _busy ? null : _load,
          ),
        ],
        child: ListView(
          padding: AdminLayoutTokens.pagePadding,
          children: [
            Text(l.bpRouteNotice),
            const SizedBox(height: 24),
            if (_error) PaymentError(_errorMessage ?? l.bpRefreshRequired),
            for (final raw in _data['routes'] as List? ?? const [])
              Builder(
                builder: (context) {
                  final route = Map<String, dynamic>.from(raw as Map);
                  final fee = PaymentFee(
                    certainty: FeeCertainty.values.byName(
                      route['fee_certainty'] as String,
                    ),
                    francs: (route['fee_rwf'] as num?)?.toInt(),
                    allIn: route['fee_all_in'] == true,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PaymentPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${paymentProviders[route['source_provider']]} → ${paymentProviders[route['destination_provider']]}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${route['rail']} · ${statuses[route['state']]} · ${l.bpReviewVersion} ${route['adapter_version']}',
                          ),
                          Text(
                            '${route['min_rwf']}–${route['max_rwf']} RWF · ${paymentFeeLabel(l, fee)}',
                          ),
                          Text(
                            '${l.bpDeviceEvidence}: ${route['device_families']}',
                          ),
                          if (route['instruction_template'] != null)
                            SelectableText(
                              route['instruction_template'] as String,
                            ),
                          if (route['evidence_url'] != null)
                            SelectableText(route['evidence_url'] as String),
                          if (route['test_evidence_url'] != null)
                            SelectableText(
                              route['test_evidence_url'] as String,
                            ),
                          if (route['tariff_evidence_url'] != null)
                            SelectableText(
                              route['tariff_evidence_url'] as String,
                            ),
                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: _busy ? null : () => _edit(route),
                                child: Text(l.bpChange),
                              ),
                              if (route['state'] == 'draft')
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _transition('tested', route),
                                  child: Text(l.bpRecordTest),
                                ),
                              if (route['state'] == 'tested')
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _transition('approve', route),
                                  child: Text(l.bpApproveRoute),
                                ),
                              if (route['state'] != 'disabled')
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _transition('disable', route),
                                  child: Text(l.bpDisableRoute),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Text(
              l.bpRouteEvidence,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final raw in _data['evidence'] as List? ?? const [])
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: PaymentPanel(
                  child: PaymentDetail(
                    raw['name'] as String,
                    '${raw['published_root'] ?? l.bpFeeUnknown}\n${raw['source_url'] ?? ''}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteEditor extends StatefulWidget {
  const _RouteEditor({this.route, required this.actionToken});
  final AccountActionToken actionToken;
  final Map<String, dynamic>? route;
  @override
  State<_RouteEditor> createState() => _RouteEditorState();
}

class _RouteEditorState extends State<_RouteEditor> {
  late final Map<String, TextEditingController> _fields;
  late final Map<String, dynamic> _value;
  bool _error = false;
  @override
  void initState() {
    super.initState();
    _value = {
      'source_provider': 'mtn_rw',
      'source_kind': 'mobileWallet',
      'destination_provider': 'mtn_rw',
      'destination_kind': 'mobileWallet',
      'purpose': 'transfer',
      'fee_certainty': 'unknown',
      'fee_all_in': false,
      'handoff_mode': 'instructions',
      'recipient_format': 'raw',
      'device_families': <String>[],
      'requires_sim': true,
      'requires_login_phone': false,
      'valid_from': DateTime.now().toUtc().toIso8601String(),
      ...?widget.route,
    };
    _fields = {
      for (final key in [
        'rail',
        'min_rwf',
        'max_rwf',
        'fee_rwf',
        'steps',
        'instruction_template',
        'evidence_url',
        'tariff_evidence_url',
        'test_evidence_url',
        'valid_from',
        'valid_until',
      ])
        key: TextEditingController(
          text:
              (_value[key] ??
                      (key == 'min_rwf'
                          ? 1
                          : key == 'max_rwf'
                          ? 10000000
                          : ''))
                  .toString(),
        ),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _dropdown(String key, String label, Map<String, String> values) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          initialValue: _value[key] as String,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: values.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _value[key] = v),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final kinds = {
      for (final k in PaymentMethodKind.values) k.name: paymentKindLabel(l, k),
    };
    final labels = {
      'rail': l.bpRail,
      'min_rwf': l.bpMinAmount,
      'max_rwf': l.bpMaxAmount,
      'fee_rwf': l.bpFee,
      'steps': l.bpSteps,
      'instruction_template': l.bpInstruction,
      'evidence_url': l.bpDeviceEvidence,
      'tariff_evidence_url': l.bpTariffEvidence,
      'test_evidence_url': l.bpTestEvidence,
      'valid_from': l.bpValidFrom,
      'valid_until': l.bpValidUntil,
    };
    return PaymentTaskScaffold(
      title: l.bpAddRoute,
      onBack: () => Navigator.pop(context),
      action: PaymentAction(
        label: l.bpSave,
        onPressed: () {
          if (!mounted || !widget.actionToken.isCurrent) return;
          final value = Map<String, dynamic>.from(_value);
          for (final e in _fields.entries) {
            value[e.key] =
                ['min_rwf', 'max_rwf', 'fee_rwf', 'steps'].contains(e.key)
                ? int.tryParse(e.value.text)
                : e.value.text.trim().isEmpty
                ? null
                : e.value.text.trim();
          }
          if (value['min_rwf'] == null ||
              value['max_rwf'] == null ||
              (value['rail'] as String? ?? '').isEmpty ||
              (value['fee_certainty'] != 'unknown' &&
                  value['fee_rwf'] == null)) {
            setState(() => _error = true);
            return;
          }
          Navigator.pop(context, value);
        },
      ),
      children: [
        if (_error) PaymentError(l.bpCheckFields),
        Text(l.bpRouteNotice),
        _dropdown('source_provider', l.bpFrom, paymentProviders),
        _dropdown(
          'source_kind',
          l.bpMethodKind,
          Map<String, String>.from(kinds)..remove('merchantCode'),
        ),
        _dropdown(
          'destination_provider',
          l.bpDestinationProvider,
          paymentProviders,
        ),
        _dropdown('destination_kind', l.bpMethodKind, kinds),
        _dropdown('recipient_format', l.bpRecipientFormat, {
          'raw': l.bpOriginalIdentifier,
          'e164Digits': '2507…',
          'rwandaNational': '07…',
        }),
        _dropdown('purpose', l.bpPurpose, {
          'transfer': l.bpTransfer,
          'merchant': l.bpMerchant,
        }),
        _dropdown('fee_certainty', l.bpFee, {
          'unknown': l.bpFeeUnknown,
          'exact': l.bpExactFee,
          'capped': l.bpCappedFee,
        }),
        SwitchListTile(
          title: Text(l.bpAllInFee),
          value: _value['fee_all_in'] == true,
          onChanged: (v) => setState(() => _value['fee_all_in'] = v),
        ),
        for (final e in labels.entries)
          TextField(
            controller: _fields[e.key],
            decoration: InputDecoration(labelText: e.value),
            maxLength: e.key == 'instruction_template' ? 1000 : 200,
            maxLines: e.key == 'instruction_template' ? 4 : 1,
          ),
        Text('${l.bpInstructionHelp}\n{recipient} · {amount} · {reference}'),
        _dropdown('handoff_mode', l.bpOpenProvider, {
          'instructions': l.bpManualMode,
          'dial': l.bpDialMode,
        }),
        for (final device in ['android', 'ios', 'web', 'desktop'])
          CheckboxListTile(
            title: Text(device),
            value: (_value['device_families'] as List).contains(device),
            onChanged: (v) => setState(() {
              final devices = List<String>.from(
                _value['device_families'] as List,
              );
              if (v == true) {
                devices.add(device);
              } else {
                devices.remove(device);
              }
              _value['device_families'] = devices;
            }),
          ),
        SwitchListTile(
          title: Text(l.bpRequiresSim),
          value: _value['requires_sim'] == true,
          onChanged: (v) => setState(() => _value['requires_sim'] = v),
        ),
        SwitchListTile(
          title: Text(l.bpRequiresLoginPhone),
          value: _value['requires_login_phone'] == true,
          onChanged: (v) => setState(() => _value['requires_login_phone'] = v),
        ),
      ],
    );
  }
}
