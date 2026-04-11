import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';

/// Admin dashboard with live platform health, access control, and action queues.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);
  NotificationService get _notificationService =>
      ref.read(notificationServiceProvider);

  AdminDashboardStats? _stats;
  List<AdminWhatsappNumberItem> _adminNumbers = const [];
  List<AdminAccessAttemptItem> _accessAttempts = const [];
  List<AdminNotificationItem> _alerts = const [];
  StreamSubscription<AppNotification>? _notificationSubscription;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSavingNumber = false;
  bool _isMarkingAlerts = false;
  String? _busyNumberId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _notificationService.startListening();
    _notificationSubscription = _notificationService.onNotification.listen((_) {
      unawaited(_loadAlerts(silent: true));
    });
    unawaited(_loadDashboard());
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      if (silent) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _loadError = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _adminService.getDashboardStats(),
        _adminService.listWhatsappAdminNumbers(),
        _adminService.listAdminAccessAttempts(limit: 8),
        _adminService.listAdminNotifications(limit: 12),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _stats = results[0] as AdminDashboardStats;
        _adminNumbers = results[1] as List<AdminWhatsappNumberItem>;
        _accessAttempts = results[2] as List<AdminAccessAttemptItem>;
        _alerts = results[3] as List<AdminNotificationItem>;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadAlerts({bool silent = false}) async {
    if (!mounted) {
      return;
    }

    if (!silent) {
      setState(() => _isRefreshing = true);
    }

    try {
      final alerts = await _adminService.listAdminNotifications(limit: 12);
      if (!mounted) {
        return;
      }

      setState(() => _alerts = alerts);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadError = error.toString());
    } finally {
      if (mounted && !silent) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _markAlertAsRead(AdminNotificationItem notification) async {
    if (notification.isRead) {
      return;
    }

    try {
      await _adminService.markAdminNotificationRead(notification.id);
      await _loadAlerts(silent: true);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString(), isError: true);
    }
  }

  Future<void> _markAllAlertsRead() async {
    if (_isMarkingAlerts) {
      return;
    }

    setState(() => _isMarkingAlerts = true);

    try {
      await _adminService.markAllAdminNotificationsRead();
      await _loadAlerts(silent: true);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isMarkingAlerts = false);
      }
    }
  }

  Future<void> _toggleNumber(AdminWhatsappNumberItem item) async {
    setState(() => _busyNumberId = item.id);

    try {
      await _adminService.setWhatsappAdminNumberActive(
        id: item.id,
        isActive: !item.isActive,
      );
      await _loadDashboard(silent: true);
      if (!mounted) {
        return;
      }

      _showSnackBar(
        item.isActive ? 'Allowlist number paused.' : 'Allowlist number active.',
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyNumberId = null);
      }
    }
  }

  Future<void> _showWhatsappNumberSheet({
    AdminWhatsappNumberItem? existing,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final displayNameController = TextEditingController(
      text: existing?.displayName ?? '',
    );
    var localNumber = _localPhone(existing?.phoneE164, existing?.countryCode);
    var countryCode = existing?.countryCode ?? '+250';
    var isActive = existing?.isActive ?? true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ext.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminSectionHeader(
                      title: existing == null
                          ? 'Add allowlist'
                          : 'Edit allowlist',
                      subtitle: 'Approved WhatsApp numbers only.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    WhatsAppInput(
                      value: localNumber,
                      onChanged: (value) =>
                          setSheetState(() => localNumber = value),
                      countryCode: countryCode,
                      onCountryCodeChanged: (value) =>
                          setSheetState(() => countryCode = value),
                      label: 'WhatsApp',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: displayNameController,
                      style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Label',
                        filled: true,
                        fillColor: ext.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.55),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AdminPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: AppTypography.titleMd.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  isActive
                                      ? 'Can receive OTP.'
                                      : 'Stored only.',
                                  style: AppTypography.bodySm.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: isActive,
                            onChanged: (value) =>
                                setSheetState(() => isActive = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: MobiButton(
                            variant: MobiButtonVariant.ghost,
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: MobiButton(
                            isLoading: _isSavingNumber,
                            onPressed: _isSavingNumber
                                ? null
                                : () async {
                                    if (localNumber.trim().length < 6) {
                                      _showSnackBar(
                                        'Enter a valid WhatsApp number.',
                                        isError: true,
                                      );
                                      return;
                                    }

                                    Navigator.of(context).pop();
                                    await _saveWhatsappNumber(
                                      phoneE164:
                                          '$countryCode${localNumber.replaceFirst(RegExp(r'^0+'), '')}',
                                      countryCode: countryCode,
                                      displayName:
                                          displayNameController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : displayNameController.text.trim(),
                                      isActive: isActive,
                                    );
                                  },
                            child: Text(existing == null ? 'Save' : 'Update'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    displayNameController.dispose();
  }

  Future<void> _saveWhatsappNumber({
    required String phoneE164,
    required String countryCode,
    String? displayName,
    required bool isActive,
  }) async {
    setState(() => _isSavingNumber = true);

    try {
      await _adminService.upsertWhatsappAdminNumber(
        phoneE164: phoneE164,
        countryCode: countryCode,
        displayName: displayName,
        isActive: isActive,
      );
      await _loadDashboard(silent: true);
      if (!mounted) {
        return;
      }

      _showSnackBar('Allowlist saved.');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSavingNumber = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final unreadAlerts = _alerts.where((alert) => !alert.isRead).length;
    final blockedAttempts = _accessAttempts
        .where((attempt) => !_isPositiveAttempt(attempt.status))
        .length;
    final inactiveNumbers = _adminNumbers
        .where((item) => !item.isActive)
        .length;

    return AdminWorkspaceFrame(
      currentTab: AdminWorkspaceTab.overview,
      title: 'Operations',
      subtitle: 'Platform state, admin access, live queues.',
      actions: [
        AdminActionChip(
          label: 'Users',
          icon: LucideIcons.users,
          tone: MobiStatusBadgeTone.info,
          onTap: () => context.go('/admin/users'),
        ),
        AdminActionChip(
          label: 'Refresh',
          icon: LucideIcons.refreshCw,
          isBusy: _isRefreshing && !_isLoading,
          onTap: _isLoading
              ? null
              : () {
                  unawaited(_loadDashboard(silent: true));
                },
        ),
      ],
      child: RefreshIndicator.adaptive(
        onRefresh: () => _loadDashboard(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 160),
          children: [
            if (_loadError != null) ...[
              AdminPanel(
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.alertTriangle,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _loadError!,
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    AdminActionChip(
                      label: 'Retry',
                      icon: LucideIcons.refreshCw,
                      tone: MobiStatusBadgeTone.danger,
                      onTap: () {
                        unawaited(_loadDashboard());
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_isLoading) ...[
              const _DashboardLoadingState(),
            ] else ...[
              _DashboardMetricGrid(
                children: [
                  AdminMetricCard(
                    label: 'Users',
                    value: '${stats?.totalUsers ?? 0}',
                    hint: '${stats?.activePassengers ?? 0} passengers',
                    icon: LucideIcons.users,
                    tone: MobiStatusBadgeTone.brand,
                  ),
                  AdminMetricCard(
                    label: 'Drivers',
                    value: '${stats?.activeDrivers ?? 0}',
                    hint: 'Live driver pool',
                    icon: LucideIcons.car,
                    tone: MobiStatusBadgeTone.info,
                  ),
                  AdminMetricCard(
                    label: 'Active trips',
                    value: '${stats?.activeTrips ?? 0}',
                    hint: '${stats?.totalTrips ?? 0} total',
                    icon: LucideIcons.mapPin,
                    tone: MobiStatusBadgeTone.warning,
                  ),
                  AdminMetricCard(
                    label: 'Completed',
                    value: '${stats?.completedTrips ?? 0}',
                    hint: '${stats?.cancelledTrips ?? 0} cancelled',
                    icon: LucideIcons.badgeCheck,
                    tone: MobiStatusBadgeTone.positive,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AdminSectionHeader(
                      title: 'Attention',
                      subtitle: 'What needs action now.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _AttentionTile(
                          label: 'Unread alerts',
                          value: '$unreadAlerts',
                          tone: unreadAlerts > 0
                              ? MobiStatusBadgeTone.warning
                              : MobiStatusBadgeTone.positive,
                          icon: LucideIcons.bellRing,
                        ),
                        _AttentionTile(
                          label: 'Blocked access',
                          value: '$blockedAttempts',
                          tone: blockedAttempts > 0
                              ? MobiStatusBadgeTone.danger
                              : MobiStatusBadgeTone.positive,
                          icon: LucideIcons.shield,
                        ),
                        _AttentionTile(
                          label: 'Paused allowlist',
                          value: '$inactiveNumbers',
                          tone: inactiveNumbers > 0
                              ? MobiStatusBadgeTone.warning
                              : MobiStatusBadgeTone.neutral,
                          icon: LucideIcons.messageCircle,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AdminActionChip(
                          label: 'Mark alerts read',
                          icon: LucideIcons.checkCheck,
                          tone: MobiStatusBadgeTone.positive,
                          isBusy: _isMarkingAlerts,
                          onTap: unreadAlerts == 0
                              ? null
                              : () {
                                  unawaited(_markAllAlertsRead());
                                },
                        ),
                        AdminActionChip(
                          label: 'Add allowlist',
                          icon: LucideIcons.plus,
                          tone: MobiStatusBadgeTone.brand,
                          onTap: () {
                            unawaited(_showWhatsappNumberSheet());
                          },
                        ),
                        AdminActionChip(
                          label: 'Vehicle types',
                          icon: LucideIcons.car,
                          tone: MobiStatusBadgeTone.info,
                          onTap: () {
                            context.push('/admin/vehicle-types');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminSectionHeader(
                      title: 'Alerts',
                      subtitle: '${_alerts.length} recent events',
                      trailing: unreadAlerts == 0
                          ? const SizedBox.shrink()
                          : AdminActionChip(
                              label: 'Clear unread',
                              icon: LucideIcons.checkCheck,
                              tone: MobiStatusBadgeTone.positive,
                              isBusy: _isMarkingAlerts,
                              onTap: () {
                                unawaited(_markAllAlertsRead());
                              },
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_alerts.isEmpty)
                      const _InlineEmptyState(
                        icon: LucideIcons.bellOff,
                        title: 'No alerts',
                        message: 'Quiet workspace.',
                      )
                    else
                      ..._alerts.map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _AlertRow(
                            notification: alert,
                            onTap: () => _markAlertAsRead(alert),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AdminSectionHeader(
                      title: 'Access log',
                      subtitle: 'Recent admin sign-in decisions.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_accessAttempts.isEmpty)
                      const _InlineEmptyState(
                        icon: LucideIcons.shield,
                        title: 'No access events',
                        message: 'No recent attempts.',
                      )
                    else
                      ..._accessAttempts.map(
                        (attempt) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _AccessAttemptRow(attempt: attempt),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminSectionHeader(
                      title: 'Admin allowlist',
                      subtitle: '${_adminNumbers.length} numbers',
                      trailing: AdminActionChip(
                        label: 'Add',
                        icon: LucideIcons.plus,
                        tone: MobiStatusBadgeTone.brand,
                        onTap: () {
                          unawaited(_showWhatsappNumberSheet());
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_adminNumbers.isEmpty)
                      const _InlineEmptyState(
                        icon: LucideIcons.messageCircle,
                        title: 'No allowlist numbers',
                        message: 'Add an admin contact to start.',
                      )
                    else
                      ..._adminNumbers.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _AllowlistRow(
                            item: item,
                            isBusy: _busyNumberId == item.id,
                            onEdit: () =>
                                _showWhatsappNumberSheet(existing: item),
                            onToggle: () => _toggleNumber(item),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _DashboardMetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1200
            ? (width - AppSpacing.md * 3) / 4
            : width >= 760
            ? (width - AppSpacing.md) / 2
            : width;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children
              .map((child) => SizedBox(width: cardWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LoadingSkeleton(height: 108, borderRadius: 28),
        SizedBox(height: AppSpacing.md),
        LoadingSkeleton(height: 108, borderRadius: 28),
        SizedBox(height: AppSpacing.md),
        LoadingSkeleton(height: 220, borderRadius: 28),
        SizedBox(height: AppSpacing.md),
        LoadingSkeleton(height: 220, borderRadius: 28),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final MobiStatusBadgeTone tone;

  const _AttentionTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _toneFill(context, tone),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: _toneColor(context, tone)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.headlineLg.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: AppTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final AdminNotificationItem notification;
  final VoidCallback onTap;

  const _AlertRow({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = _alertTone(notification);

    return InkWell(
      onTap: notification.isRead ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _toneFill(context, tone),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _toneColor(context, tone).withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _alertIcon(notification),
                size: 18,
                color: _toneColor(context, tone),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        notification.title,
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      MobiStatusBadge(
                        label: notification.isRead ? 'Read' : 'Unread',
                        tone: notification.isRead
                            ? MobiStatusBadgeTone.neutral
                            : tone,
                      ),
                    ],
                  ),
                  if ((notification.body ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.body!,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(notification.createdAt),
                  style: AppTypography.labelSm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AdminActionChip(
                    label: 'Mark read',
                    icon: LucideIcons.check,
                    tone: tone,
                    onTap: onTap,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessAttemptRow extends StatelessWidget {
  final AdminAccessAttemptItem attempt;

  const _AccessAttemptRow({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = _attemptTone(attempt.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).extension<MobiThemeExtension>()!.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      attempt.phoneE164,
                      style: AppTypography.titleMd.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    MobiStatusBadge(
                      label: attempt.status.toUpperCase(),
                      tone: tone,
                    ),
                    MobiStatusBadge(
                      label: attempt.sourceApp.toUpperCase(),
                      tone: MobiStatusBadgeTone.neutral,
                    ),
                  ],
                ),
                if ((attempt.reason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    attempt.reason!,
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatTimestamp(attempt.createdAt),
            style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AllowlistRow extends StatelessWidget {
  final AdminWhatsappNumberItem item;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _AllowlistRow({
    required this.item,
    required this.isBusy,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).extension<MobiThemeExtension>()!.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      item.displayName?.trim().isNotEmpty == true
                          ? item.displayName!
                          : item.phoneE164,
                      style: AppTypography.titleMd.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    MobiStatusBadge(
                      label: item.isActive ? 'ACTIVE' : 'PAUSED',
                      tone: item.isActive
                          ? MobiStatusBadgeTone.positive
                          : MobiStatusBadgeTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.phoneE164,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.end,
            children: [
              AdminActionChip(
                label: 'Edit',
                icon: LucideIcons.pencil,
                tone: MobiStatusBadgeTone.info,
                onTap: onEdit,
              ),
              AdminActionChip(
                label: item.isActive ? 'Pause' : 'Enable',
                icon: item.isActive ? LucideIcons.pause : LucideIcons.play,
                tone: item.isActive
                    ? MobiStatusBadgeTone.warning
                    : MobiStatusBadgeTone.positive,
                isBusy: isBusy,
                onTap: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.titleMd.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Now';
  }

  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return value;
  }

  return DateFormat('dd MMM • HH:mm').format(parsed);
}

String _localPhone(String? phoneE164, String? countryCode) {
  if (phoneE164 == null || phoneE164.trim().isEmpty) {
    return '';
  }

  if (countryCode != null &&
      countryCode.isNotEmpty &&
      phoneE164.startsWith(countryCode)) {
    return phoneE164.substring(countryCode.length);
  }

  return phoneE164.replaceFirst(RegExp(r'^\+\d{1,4}'), '');
}

bool _isPositiveAttempt(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'approved' ||
      normalized == 'allowed' ||
      normalized == 'success';
}

MobiStatusBadgeTone _attemptTone(String status) {
  final normalized = status.trim().toLowerCase();
  if (_isPositiveAttempt(normalized)) {
    return MobiStatusBadgeTone.positive;
  }
  if (normalized.contains('pending') || normalized.contains('review')) {
    return MobiStatusBadgeTone.warning;
  }
  return MobiStatusBadgeTone.danger;
}

MobiStatusBadgeTone _alertTone(AdminNotificationItem alert) {
  final type = alert.type.toLowerCase();
  final title = alert.title.toLowerCase();
  if (type.contains('error') ||
      title.contains('error') ||
      title.contains('failed')) {
    return MobiStatusBadgeTone.danger;
  }
  if (type.contains('access') ||
      title.contains('review') ||
      title.contains('pending')) {
    return MobiStatusBadgeTone.warning;
  }
  if (type.contains('promo') || type.contains('announcement')) {
    return MobiStatusBadgeTone.info;
  }
  return MobiStatusBadgeTone.brand;
}

IconData _alertIcon(AdminNotificationItem alert) {
  final type = alert.type.toLowerCase();
  if (type.contains('error')) {
    return LucideIcons.alertTriangle;
  }
  if (type.contains('access')) {
    return LucideIcons.shield;
  }
  if (type.contains('promo')) {
    return LucideIcons.megaphone;
  }
  return LucideIcons.bellRing;
}

Color _toneColor(BuildContext context, MobiStatusBadgeTone tone) {
  final cs = Theme.of(context).colorScheme;

  return switch (tone) {
    MobiStatusBadgeTone.brand => cs.primary,
    MobiStatusBadgeTone.positive => cs.primary,
    MobiStatusBadgeTone.info => cs.tertiary,
    MobiStatusBadgeTone.warning => Colors.amber.shade800,
    MobiStatusBadgeTone.danger => cs.error,
    MobiStatusBadgeTone.neutral => cs.onSurfaceVariant,
  };
}

Color _toneFill(BuildContext context, MobiStatusBadgeTone tone) {
  final accent = _toneColor(context, tone);
  return accent.withValues(
    alpha: tone == MobiStatusBadgeTone.neutral ? 0.06 : 0.1,
  );
}
