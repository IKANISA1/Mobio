import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/auth/admin_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Masks admin content immediately on account changes and on expiry or blur.
/// Only foreground input can request a lease touch.
class AdminSessionBoundary extends StatefulWidget {
  const AdminSessionBoundary({
    super.key,
    required this.child,
    required this.router,
    this.accountChanges,
    this.canAccess,
    this.synchronize,
  });
  final Widget child;
  final GoRouter router;
  final ValueNotifier<int>? accountChanges;
  final bool Function()? canAccess;
  final Future<void> Function({required bool userActivity})? synchronize;

  @override
  State<AdminSessionBoundary> createState() => _AdminSessionBoundaryState();
}

class _AdminSessionBoundaryState extends State<AdminSessionBoundary>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  DateTime _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);
  ValueNotifier<int> get _changes =>
      widget.accountChanges ?? AccountContext.changes;

  bool get _protected {
    final path = widget.router.routeInformationProvider.value.uri.path;
    if (path == '/admin' || path.startsWith('/admin/')) return true;
    try {
      return path == '/home' &&
          Supabase.instance.client.auth.currentUser?.appMetadata['role'] ==
              'admin';
    } on Object {
      return false;
    }
  }

  bool get _hasLease {
    if (widget.canAccess != null) return widget.canAccess!();
    try {
      final auth = Supabase.instance.client.auth;
      return !AccountContext.exitRequested &&
          AccountContext.hasVerifiedSession &&
          AdminSessionGuard.isAdminFor(
            auth.currentUser?.id,
            sessionId: AccountContext.sessionId(auth.currentSession),
          );
    } on Object {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes.addListener(_accountChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _protected) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AdminSessionBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountChanges != widget.accountChanges) {
      (oldWidget.accountChanges ?? AccountContext.changes).removeListener(
        _accountChanged,
      );
      _changes.addListener(_accountChanged);
    }
  }

  void _accountChanged() {
    _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);
    if (mounted) setState(() {});
  }

  Future<void> _refresh({required bool userActivity}) async {
    final token = AccountActionToken.capture();
    final revision = _changes.value;
    try {
      if (widget.synchronize != null) {
        await widget.synchronize!(userActivity: userActivity);
      } else {
        await AdminSessionService.synchronize(userActivity: userActivity);
      }
      if (mounted && revision == _changes.value && token.isCurrent)
        setState(() {});
    } on Object {
      if (mounted && revision == _changes.value && token.isCurrent)
        setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _protected) unawaited(_refresh(userActivity: false));
    if (mounted) setState(() {});
  }

  void _activity() {
    if (!_foreground ||
        !_protected ||
        !_hasLease ||
        DateTime.now().difference(_lastInteraction) <
            const Duration(seconds: 30))
      return;
    _lastInteraction = DateTime.now();
    unawaited(_refresh(userActivity: true));
  }

  @override
  void dispose() {
    _changes.removeListener(_accountChanged);
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_protected) return widget.child;
    if (!_foreground || !_hasLease) {
      return Material(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Admin session locked'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => widget.router.go('/admin-auth'),
                child: const Text('Verify again'),
              ),
            ],
          ),
        ),
      );
    }
    return Listener(
      onPointerDown: (_) => _activity(),
      child: Focus(
        onKeyEvent: (_, _) {
          _activity();
          return KeyEventResult.ignored;
        },
        child: KeyedSubtree(key: ValueKey(_changes.value), child: widget.child),
      ),
    );
  }
}
