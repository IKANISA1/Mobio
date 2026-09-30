import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_app/features/notifications/data/notification_service.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, required this.onBack})
    : _captureOverride = null,
      _isCurrentOverride = null;

  @visibleForTesting
  const NotificationsScreen.test({
    super.key,
    required this.onBack,
    required AccountSnapshot Function() captureAccount,
    required bool Function(AccountSnapshot) isCurrent,
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;

  final VoidCallback onBack;
  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  bool _writing = false;
  AccountSnapshot? _viewAccount;
  int _loadRevision = 0;

  NotificationService get _service => ref.read(notificationServiceProvider);
  bool get _isPreview => ref.read(notificationUiPreviewProvider);

  AccountSnapshot? _captureAccount() {
    if (_isPreview && widget._captureOverride == null) return null;
    try {
      return widget._captureOverride?.call() ?? AccountContext.capture();
    } on Object {
      return null;
    }
  }

  bool _current(AccountSnapshot? account) =>
      mounted &&
      (account == null
          ? _isPreview && widget._captureOverride == null
          : widget._isCurrentOverride?.call(account) ??
                AccountContext.isCurrent(account));

  void _onAccountChanged() {
    if (!mounted) return;
    final account = _captureAccount();
    if (account?.identity == _viewAccount?.identity &&
        account?.generation == _viewAccount?.generation) {
      return;
    }
    _viewAccount = account;
    setState(() {
      _loadRevision++;
      _writing = false;
      _future = _load(account);
    });
  }

  @override
  void initState() {
    super.initState();
    _viewAccount = _captureAccount();
    _future = _load(_viewAccount);
    AccountContext.changes.addListener(_onAccountChanged);
  }

  @override
  void dispose() {
    _loadRevision++;
    AccountContext.changes.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<List<AppNotification>> _load(AccountSnapshot? account) {
    final future = _read(account);
    // Observe failures immediately, including account invalidation before the
    // next frame attaches FutureBuilder. The original Future retains its error
    // for the visible error state; discarded generations cannot leak errors.
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    return future;
  }

  Future<List<AppNotification>> _read(AccountSnapshot? account) async {
    if (_isPreview) {
      return _previewNotifications;
    }
    if (account == null || !_current(account)) {
      throw const AuthException(message: 'Sign in to view notifications.');
    }
    final rows = await _service.getNotifications(limit: 80);
    if (!_current(account)) throw const StaleAccountWork();
    if (rows.any((row) => row.userId != account.userId)) {
      throw const FormatException('Notification inbox owner mismatch');
    }
    return rows;
  }

  Future<void> _refreshFor(AccountSnapshot? account) async {
    if (!_current(account)) return;
    final future = _load(account);
    setState(() {
      _loadRevision++;
      _future = future;
    });
    try {
      await future;
    } on Object catch (_) {
      // FutureBuilder owns the error state; gesture callbacks must not rethrow.
    }
  }

  Future<void> _markAllRead(AccountSnapshot? account) async {
    if (_writing || !_current(account)) return;
    setState(() => _writing = true);
    try {
      if (!_isPreview) await _service.markAllAsRead();
      if (!_current(account)) return;
      await _refreshFor(account);
    } on Object catch (error) {
      if (_current(account)) _showWriteError(error);
    } finally {
      if (_current(account)) setState(() => _writing = false);
    }
  }

  Future<void> _open(
    AppNotification notification,
    AccountSnapshot? account,
  ) async {
    if (_writing ||
        !_current(account) ||
        (!_isPreview && notification.userId != account?.userId)) {
      return;
    }
    setState(() => _writing = true);
    try {
      if (!_isPreview && !notification.isRead) {
        await _service.markAsRead(notification.id);
      }
      if (!_current(account)) return;
      unawaited(_refreshFor(account));
      final route = notification.route;
      if (!mounted || !_current(account)) return;
      if (route != '/notifications') context.push(route);
    } on Object catch (error) {
      if (_current(account)) _showWriteError(error);
    } finally {
      if (_current(account)) setState(() => _writing = false);
    }
  }

  void _showWriteError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppExceptionMapper.map(error).message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final renderedAccount = _viewAccount;
    return SoftGradient(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MobiPageHeader(
              title: 'Notifications',
              onBack: widget.onBack,
              trailing: IconButton(
                tooltip: 'Mark all read',
                onPressed: _writing
                    ? null
                    : () => _markAllRead(renderedAccount),
                icon: const Icon(LucideIcons.checkCheck),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AppNotification>>(
                key: ValueKey(_loadRevision),
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    final cs = Theme.of(context).colorScheme;
                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Column(
                            children: [
                              Icon(
                                LucideIcons.alertTriangle,
                                color: cs.error,
                                size: 32,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Couldn’t load notifications',
                                textAlign: TextAlign.center,
                                style: AppTypography.titleLg.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                AppExceptionMapper.map(snapshot.error!).message,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMd.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              MobiButton(
                                onPressed: () => _refreshFor(renderedAccount),
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  final notifications = snapshot.data ?? const [];
                  if (notifications.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => _refreshFor(renderedAccount),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xxxl,
                          AppSpacing.lg,
                          AppSpacing.xxxl,
                        ),
                        children: const [
                          AiEmptyState(
                            icon: LucideIcons.bell,
                            title: 'No notifications',
                            subtitle:
                                'Chats, trip updates, and account alerts will appear here.',
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => _refreshFor(renderedAccount),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xxxl,
                      ),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _NotificationTile(
                          notification: notification,
                          onTap: _writing
                              ? null
                              : () => _open(notification, renderedAccount),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                MediaQuery.paddingOf(context).bottom + AppSpacing.md,
              ),
              child: MobiButton(
                variant: MobiButtonVariant.ghost,
                onPressed: () => _refreshFor(renderedAccount),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.refreshCw, size: 18),
                    SizedBox(width: AppSpacing.sm),
                    Text('Refresh'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppNotification> get _previewNotifications => const [
    AppNotification(
      id: 'preview-chat',
      userId: 'preview-user',
      type: 'chat_message',
      title: 'New passenger message',
      body: 'A passenger asked about pickup time.',
      metadata: {'route': '/chat'},
      isRead: false,
      createdAt: 'now',
    ),
    AppNotification(
      id: 'preview-trip',
      userId: 'preview-user',
      type: 'public_transport_booking',
      title: 'Bus booking update',
      body: 'Your scheduled public transport request is active.',
      metadata: {'route': '/bookings'},
      isRead: true,
      createdAt: 'today',
    ),
  ];
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = !notification.isRead;

    return Material(
      color: unread ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: unread
                  ? cs.primary.withValues(alpha: 0.50)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: unread ? 0.30 : 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(notification.type),
                    color: cs.onSurface,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMd.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((notification.body ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        notification.body!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMd.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _labelFor(notification.type),
                      style: AppTypography.labelSm.copyWith(
                        color: cs.primary.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox.square(
                  dimension: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'chat_message' => LucideIcons.messageCircle,
      'trip_response' || 'trip_updated' || 'trip_cancelled' => LucideIcons.car,
      'public_transport_booking' ||
      'public_transport_schedule_change' => LucideIcons.bus,
      'promo' => LucideIcons.megaphone,
      'profile_action_required' => LucideIcons.userCog,
      _ => LucideIcons.bell,
    };
  }

  String _labelFor(String type) {
    return switch (type) {
      'chat_message' => 'Chat',
      'trip_response' || 'trip_updated' || 'trip_cancelled' => 'Trip',
      'public_transport_booking' ||
      'public_transport_schedule_change' => 'Public transport',
      'promo' => 'Promotion',
      'profile_action_required' => 'Profile',
      _ => 'Mobio',
    };
  }
}
