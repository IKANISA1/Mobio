import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobi_app/core/async/external_action.dart';
import 'package:mobi_app/core/auth/account_bound_view.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/privacy_service.dart';
import '../domain/privacy_request.dart';

class PrivacyRequestScreen extends StatefulWidget {
  const PrivacyRequestScreen({super.key, required this.account, this.service});
  final AccountSnapshot account;
  final PrivacyService? service;
  @override
  State<PrivacyRequestScreen> createState() => _PrivacyRequestScreenState();
}

class _PrivacyRequestScreenState extends State<PrivacyRequestScreen>
    with WidgetsBindingObserver {
  late final PrivacyService _service = widget.service ?? PrivacyService();
  PrivacyPolicy? _policy;
  List<PrivacyRequest> _requests = [];
  bool _busy = false, _confirmed = false, _foreground = true;
  int _revision = 0;
  String? _message, _pendingId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AccountContext.changes.addListener(_invalidate);
    unawaited(_load());
  }

  void _invalidate() {
    _revision++;
    if (mounted)
      setState(() {
        _policy = null;
        _requests = [];
        _confirmed = false;
        _busy = false;
        _message = null;
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _invalidate();
    } else if (AccountContext.isCurrent(widget.account)) {
      unawaited(_load());
    }
  }

  bool _current(int revision) =>
      mounted &&
      _foreground &&
      revision == _revision &&
      AccountContext.isCurrent(widget.account);
  Future<void> _load() async {
    if (!_foreground || !AccountContext.isCurrent(widget.account)) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _policy = null;
      _requests = [];
      _confirmed = false;
      _message = null;
    });
    try {
      final policy = await _service.policy(widget.account);
      final rows = await _service.list(widget.account);
      if (!_current(revision)) return;
      setState(() {
        _policy = policy;
        _requests = rows;
        _busy = false;
        if (rows.any((v) => v.id == _pendingId && v.terminal))
          _pendingId = null;
      });
    } on Object catch (error) {
      if (_current(revision))
        setState(() {
          _busy = false;
          _message = error is PrivacyFailure
              ? error.message
              : 'Request status is unavailable. Use the existing contact page below.';
        });
    }
  }

  Future<void> _submit() async {
    final policy = _policy;
    if (_busy ||
        !_confirmed ||
        policy?.enabled != true ||
        policy?.noticeVersion == null)
      return;
    final revision = ++_revision;
    _pendingId ??= PrivacyService.requestId();
    final id = _pendingId!;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _service.request(
        widget.account,
        id,
        policy!.noticeVersion!,
      );
      if (!_current(revision)) return;
      setState(() {
        _requests = [result, ..._requests.where((v) => v.id != result.id)];
        _confirmed = false;
        _busy = false;
        _message =
            'Your request was recorded. This does not mean your account or data has been deleted.';
      });
    } on Object catch (error) {
      if (_current(revision))
        setState(() {
          _busy = false;
          _message = error is PrivacyFailure
              ? error.message
              : 'Submission could not be confirmed. Refresh before retrying.';
        });
    }
  }

  Future<void> _cancel(PrivacyRequest request) async {
    if (_busy || !request.canCancel) return;
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this deletion request?'),
        content: const Text(
          'This cancels the request only if processing has not started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (decision != true ||
        !mounted ||
        !_foreground ||
        !AccountContext.isCurrent(widget.account))
      return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _service.cancel(widget.account, request.id);
      if (!_current(revision)) return;
      setState(() {
        _requests = [result, ..._requests.where((v) => v.id != result.id)];
        _busy = false;
        if (result.status == 'cancelled') {
          _pendingId = null;
          _message = 'Request cancelled.';
        }
      });
    } on Object catch (error) {
      if (_current(revision))
        setState(() {
          _busy = false;
          _message = error is PrivacyFailure
              ? error.message
              : 'Cancellation could not be confirmed. Refresh for current status.';
        });
    }
  }

  Future<void> _openContact() async {
    try {
      final uri = Uri.parse(SupabaseConfig.accountDeletionUrl);
      if (uri.scheme != 'https' ||
          !await ExternalAction.run(
            launchUrl(uri, mode: LaunchMode.externalApplication),
            operation: 'open_external_link',
          ))
        throw StateError('Unavailable');
    } on Object {
      if (mounted)
        setState(
          () => _message =
              'The contact page could not be opened. Try again when connected.',
        );
    }
  }

  @override
  void dispose() {
    _revision++;
    AccountContext.changes.removeListener(_invalidate);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccountBoundView(
    account: widget.account,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Account deletion request'),
        actions: [
          IconButton(
            tooltip: 'Refresh request status',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !_foreground
          ? const Center(
              child: Text('Return to the app to refresh your request.'),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Request deletion of your account and associated personal data. Submission records a request; it does not immediately erase data or close your account.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Some records may need a documented retention exception. Status shows recorded completion evidence and any documented exceptions; it is not a promise that no records remain. Cancellation is only available before processing starts.',
                ),
                TextButton(
                  onPressed: _openContact,
                  child: const Text(
                    'Read the deletion notice / other ways to request',
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(liveRegion: true, child: Text(_message!)),
                  ),
                if (_policy != null &&
                    _policy!.enabled &&
                    !_requests.any((r) => !r.terminal)) ...[
                  Text('Notice version: ${_policy!.noticeVersion}'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmed,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _confirmed = value ?? false),
                    title: const Text(
                      'I have read the deletion notice and want to submit this request.',
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy || !_confirmed ? null : _submit,
                    child: const Text('Submit deletion request'),
                  ),
                ] else if (_policy != null && !_policy!.enabled)
                  const Text(
                    'In-app request intake is not enabled. Use the existing contact page above.',
                  ),
                const SizedBox(height: 20),
                Text(
                  'Your requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!_busy && _policy != null && _requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No request has been recorded for this account.',
                    ),
                  ),
                for (final request in _requests)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SelectableText('Reference: ${request.id}'),
                          Text('Requested: ${request.requestedAt.toLocal()}'),
                          if (request.retainedCategories.isNotEmpty)
                            Text(
                              'Documented retention: ${request.retainedCategories.join(', ')}',
                            ),
                          if (request.canCancel)
                            TextButton(
                              onPressed: _busy ? null : () => _cancel(request),
                              child: const Text('Cancel request'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}
