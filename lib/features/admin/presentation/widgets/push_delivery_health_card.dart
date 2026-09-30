import 'package:flutter/material.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uses a dedicated server RPC; never treats FCM acceptance as device delivery.
class PushDeliveryHealthCard extends StatefulWidget {
  const PushDeliveryHealthCard({super.key})
    : captureAccount = null,
      loadHealth = null;
  @visibleForTesting
  const PushDeliveryHealthCard.test({
    super.key,
    required this.captureAccount,
    required this.loadHealth,
  });
  final AccountSnapshot Function()? captureAccount;
  final Future<Object?> Function()? loadHealth;
  @override
  State<PushDeliveryHealthCard> createState() => _PushDeliveryHealthCardState();
}

class _PushDeliveryHealthCardState extends State<PushDeliveryHealthCard>
    with WidgetsBindingObserver {
  late final AccountActionToken _origin = AccountActionToken.capture(
    captureAccount: widget.captureAccount,
  );
  bool get _current => mounted && _origin.isCurrent;
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AccountContext.changes.addListener(_clear);
    _load();
  }

  void _clear() {
    _revision++;
    if (mounted) {
      setState(() {
        _data = null;
        _loading = false;
        _error = 'Refresh to check current delivery status.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _clear();
  }

  Future<void> _load() async {
    if (!_current) return;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final account = widget.captureAccount?.call() ?? AccountContext.capture();
      if (!_current) return;
      final result =
          await (widget.loadHealth?.call() ??
                  Supabase.instance.client.rpc('rpc_push_health'))
              .timeout(const Duration(seconds: 5));
      if (!_current) return;
      if (widget.loadHealth == null) AccountContext.requireCurrent(account);
      if (!mounted || revision != _revision) return;
      final data = Map<String, dynamic>.from(result as Map);
      if (data['enabled'] is! bool ||
          data['counts'] is! Map ||
          data['not_queued_24h'] is! Map ||
          data['accepted_means'] != 'provider_accepted_not_device_delivered' ||
          (data['counts'] as Map).values.any(
            (dynamic v) => v is! int || v < 0,
          ) ||
          (data['not_queued_24h'] as Map).values.any(
            (dynamic v) => v is! int || v < 0,
          )) {
        throw const FormatException('Invalid health response');
      }
      setState(() {
        _data = data;
        _loading = false;
      });
    } on Object {
      if (_current && revision == _revision) {
        setState(() {
          _loading = false;
          _error =
              'Delivery health unavailable. Check the admin session and backend.';
        });
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    AccountContext.changes.removeListener(_clear);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final counts = data?['counts'] as Map? ?? const {};
    final omissions = data?['not_queued_24h'] as Map? ?? const {};
    int omitted(String key) =>
        omissions[key] is int ? omissions[key] as int : 0;
    int count(String key) =>
        counts[key] is num ? (counts[key] as num).toInt() : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Push delivery',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh push delivery health',
                  onPressed: _loading || !_current ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            if (data != null) ...[
              Text(
                data['enabled'] == true
                    ? 'Dispatch enabled'
                    : 'Dispatch paused',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Queued: ${count('queued')}'),
                  Text('In progress: ${count('leased')}'),
                  Text('Provider accepted: ${count('accepted')}'),
                  Text(
                    'Needs review: ${count('dead') + count('invalid_token')}',
                  ),
                  Text('Expired: ${count('expired')}'),
                  Text('Suppressed: ${count('skipped')}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Oldest pending: ${data['oldest_pending_seconds'] ?? 0} seconds',
              ),
              Text(
                'Last worker poll: ${data['last_worker_poll_at'] ?? 'Not observed'}',
              ),
              Text(
                'Not queued in 24 hours — no active device: ${omitted('no_targets')}; consent: ${omitted('consent_denied')}; capacity: ${omitted('over_capacity')}.',
              ),
              Text(
                'Not requested: ${omitted('not_requested')}; invalid type/channels: ${omitted('unknown_type') + omitted('invalid_channels')}.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Provider acceptance does not confirm device delivery or reading. Counts are retained totals.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
