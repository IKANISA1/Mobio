import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  const NotificationsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  bool _writing = false;

  NotificationService get _service => ref.read(notificationServiceProvider);
  bool get _isPreview => ref.read(notificationUiPreviewProvider);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() {
    if (_isPreview) {
      return Future.value(_previewNotifications);
    }

    return _service.getNotifications(limit: 80);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _future = _load());
    try {
      await _future;
    } on Object catch (_) {
      // FutureBuilder owns the error state; gesture callbacks must not rethrow.
    }
  }

  Future<void> _markAllRead() async {
    if (_writing) return;
    setState(() => _writing = true);
    try {
      if (!_isPreview) await _service.markAllAsRead();
      await _refresh();
    } on Object catch (error) {
      _showWriteError(error);
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (_writing) return;
    setState(() => _writing = true);
    try {
      if (!_isPreview && !notification.isRead) {
        await _service.markAsRead(notification.id);
      }
      if (!mounted) return;
      unawaited(_refresh());
      final route = notification.route;
      if (route != '/notifications') context.push(route);
    } on Object catch (error) {
      _showWriteError(error);
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  void _showWriteError(Object error) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(AppExceptionMapper.map(error).message)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _writing ? null : _markAllRead,
                icon: const Icon(LucideIcons.checkCheck),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AppNotification>>(
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
                                onPressed: _refresh,
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
                      onRefresh: _refresh,
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
                    onRefresh: _refresh,
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
                          onTap: _writing ? null : () => _open(notification),
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
                onPressed: _refresh,
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
      color: Colors.white.withValues(alpha: unread ? 0.10 : 0.06),
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
                    color: Colors.white,
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
                        color: Colors.white,
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
                          color: Colors.white.withValues(alpha: 0.72),
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
