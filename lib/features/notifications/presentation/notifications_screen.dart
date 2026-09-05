import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
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

  NotificationService get _service => ref.read(notificationServiceProvider);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() {
    if (SupabaseConfig.isLocalUiPreview) {
      return Future.value(_previewNotifications);
    }

    return _service.getNotifications(limit: 80);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markAllRead() async {
    if (!SupabaseConfig.isLocalUiPreview) {
      await _service.markAllAsRead();
    }
    await _refresh();
  }

  Future<void> _open(AppNotification notification) async {
    if (!SupabaseConfig.isLocalUiPreview && !notification.isRead) {
      await _service.markAsRead(notification.id);
    }
    if (!mounted) return;
    final route = notification.route;
    if (route != '/notifications') {
      context.push(route);
    } else {
      await _refresh();
    }
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
                onPressed: _markAllRead,
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
                          onTap: () => _open(notification),
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
  final VoidCallback onTap;

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
                        fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w800,
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
