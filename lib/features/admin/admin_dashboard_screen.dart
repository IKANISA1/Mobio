import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';

/// Admin dashboard with live Supabase metrics and admin access controls.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  final NotificationService _notificationService = NotificationService();

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
        item.isActive
            ? 'Admin WhatsApp number disabled.'
            : 'Admin WhatsApp number enabled.',
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
    final colorScheme = Theme.of(context).colorScheme;
    final themeExtension = Theme.of(context).extension<MobiThemeExtension>()!;
    final displayNameController = TextEditingController(
      text: existing?.displayName ?? '',
    );
    var localNumber = _localPhone(existing?.phoneE164, existing?.countryCode);
    var countryCode = existing?.countryCode ?? '+250';
    var isActive = existing?.isActive ?? true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: themeExtension.surfaceContainerLow,
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
                  20,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null
                          ? 'Add admin number'
                          : 'Edit admin number',
                      style: AppTypography.titleLg.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Only allowlisted WhatsApp numbers can receive platform-admin OTPs.',
                      style: AppTypography.bodySm.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    WhatsAppInput(
                      value: localNumber,
                      onChanged: (value) =>
                          setSheetState(() => localNumber = value),
                      countryCode: countryCode,
                      onCountryCodeChanged: (value) =>
                          setSheetState(() => countryCode = value),
                      label: 'Approved WhatsApp Number',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: displayNameController,
                      style: AppTypography.titleMd.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Display name',
                        filled: true,
                        fillColor: themeExtension.surfaceContainerLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClayCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      borderRadius: 24,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Number status',
                                  style: AppTypography.titleMd.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isActive
                                      ? 'This number can receive admin OTPs.'
                                      : 'This number stays on record but cannot sign in.',
                                  style: AppTypography.bodySm.copyWith(
                                    color: colorScheme.onSurfaceVariant,
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: MobiButton(
                            variant: MobiButtonVariant.ghost,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MobiButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            isLoading: _isSavingNumber,
                            onPressed: _isSavingNumber
                                ? null
                                : () async {
                                    final trimmedDisplayName =
                                        displayNameController.text.trim();
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
                                      displayName: trimmedDisplayName.isEmpty
                                          ? null
                                          : trimmedDisplayName,
                                      isActive: isActive,
                                    );
                                  },
                            child: Text(
                              existing == null
                                  ? 'Save Number'
                                  : 'Update Number',
                            ),
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

      _showSnackBar('Admin WhatsApp number saved.');
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
    final colorScheme = Theme.of(context).colorScheme;
    final stats = _stats;
    final unreadAlerts = _alerts.where((alert) => !alert.isRead).length;
    final cards = [
      _StatCardData(
        label: 'Total Users',
        value: stats?.totalUsers.toString() ?? '0',
        color: colorScheme.primary,
        icon: LucideIcons.users,
      ),
      _StatCardData(
        label: 'Active Drivers',
        value: stats?.activeDrivers.toString() ?? '0',
        color: colorScheme.tertiary,
        icon: LucideIcons.car,
      ),
      _StatCardData(
        label: 'Active Passengers',
        value: stats?.activePassengers.toString() ?? '0',
        color: colorScheme.primary,
        icon: LucideIcons.user,
      ),
      _StatCardData(
        label: 'Trips',
        value: stats?.totalTrips.toString() ?? '0',
        color: colorScheme.tertiary,
        icon: LucideIcons.mapPin,
      ),
    ];

    return RefreshIndicator.adaptive(
      onRefresh: () => _loadDashboard(silent: true),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: AppTypography.displayMd.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Live platform overview and admin access controls',
                        style: AppTypography.bodyLg.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ClayCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 24,
                  onTap: _isRefreshing
                      ? null
                      : () => _loadDashboard(silent: true),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.refreshCw,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        unreadAlerts > 0 ? '$unreadAlerts new' : 'Refresh',
                        style: AppTypography.labelSm.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loadError != null) ...[
              ClayCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.alertCircle,
                      color: colorScheme.error,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard data unavailable',
                            style: AppTypography.titleMd.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loadError!,
                            style: AppTypography.bodySm.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                if (_isLoading) {
                  return const LoadingSkeleton(height: 160, borderRadius: 24);
                }

                final stat = cards[index];
                return ClayCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              stat.label.toUpperCase(),
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: 0.2,
                            child: Icon(stat.icon, size: 20, color: stat.color),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        stat.value,
                        style: AppTypography.headlineLg.copyWith(
                          color: stat.color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ClayCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Row(
                children: [
                  Expanded(
                    child: _TripHealthMetric(
                      label: 'Active',
                      value: _isLoading
                          ? '...'
                          : (_stats?.activeTrips.toString() ?? '0'),
                    ),
                  ),
                  Expanded(
                    child: _TripHealthMetric(
                      label: 'Completed',
                      value: _isLoading
                          ? '...'
                          : (_stats?.completedTrips.toString() ?? '0'),
                    ),
                  ),
                  Expanded(
                    child: _TripHealthMetric(
                      label: 'Cancelled',
                      value: _isLoading
                          ? '...'
                          : (_stats?.cancelledTrips.toString() ?? '0'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Vehicle Types management shortcut
            ClayCard(
              onTap: () => context.push('/admin/vehicle-types'),
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      LucideIcons.car,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle Types',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage vehicle types and country availability',
                          style: AppTypography.bodySm.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              title: 'Admin Alerts',
              subtitle: 'Blocked access attempts routed to current admins.',
              action: unreadAlerts > 0
                  ? MobiButton(
                      variant: MobiButtonVariant.ghost,
                      isLoading: _isMarkingAlerts,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      onPressed: _markAllAlertsRead,
                      child: const Text('Mark all read'),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              ...List.generate(
                2,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LoadingSkeleton(height: 112, borderRadius: 24),
                ),
              )
            else if (_alerts.isEmpty)
              const _EmptyCard(
                title: 'No alerts yet',
                body: 'Blocked admin-access alerts will appear here.',
              )
            else
              ..._alerts.map(
                (alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClayCard(
                    onTap: () => _markAlertAsRead(alert),
                    padding: const EdgeInsets.all(20),
                    borderRadius: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            LucideIcons.shieldAlert,
                            size: 22,
                            color: colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      alert.title,
                                      style: AppTypography.titleMd.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (!alert.isRead)
                                    _StatusPill(
                                      label: 'NEW',
                                      background: colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      foreground: colorScheme.primary,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if ((alert.body ?? '').isNotEmpty)
                                Text(
                                  alert.body!,
                                  style: AppTypography.bodySm.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Text(
                                _formatTimestamp(alert.createdAt),
                                style: AppTypography.labelSm.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            _SectionHeader(
              title: 'Admin WhatsApp Numbers',
              subtitle: 'Manage the allowlist used by platform-admin OTP.',
              action: MobiButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                onPressed: _showWhatsappNumberSheet,
                child: const Text('Add number'),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              ...List.generate(
                2,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LoadingSkeleton(height: 120, borderRadius: 24),
                ),
              )
            else if (_adminNumbers.isEmpty)
              const _EmptyCard(
                title: 'No admin numbers',
                body:
                    'Add approved WhatsApp numbers to enable platform-admin access.',
              )
            else
              ..._adminNumbers.map(
                (number) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClayCard(
                    onTap: () => _showWhatsappNumberSheet(existing: number),
                    padding: const EdgeInsets.all(20),
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                number.phoneE164,
                                style: AppTypography.titleMd.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusPill(
                              label: number.isActive ? 'ACTIVE' : 'PAUSED',
                              background: number.isActive
                                  ? colorScheme.primary.withValues(alpha: 0.12)
                                  : colorScheme.surfaceContainerHighest,
                              foreground: number.isActive
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          number.displayName?.trim().isNotEmpty == true
                              ? number.displayName!
                              : 'Platform Admin',
                          style: AppTypography.bodyMd.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Updated ${_formatTimestamp(number.updatedAt ?? number.createdAt)}',
                                style: AppTypography.labelSm.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            MobiButton(
                              variant: number.isActive
                                  ? MobiButtonVariant.ghost
                                  : MobiButtonVariant.success,
                              isLoading: _busyNumberId == number.id,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              onPressed: _busyNumberId == number.id
                                  ? null
                                  : () => _toggleNumber(number),
                              child: Text(
                                number.isActive ? 'Disable' : 'Enable',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            const _SectionHeader(
              title: 'Recent Access Attempts',
              subtitle: 'Audit trail for admin entry requests.',
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              ...List.generate(
                3,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LoadingSkeleton(height: 112, borderRadius: 24),
                ),
              )
            else if (_accessAttempts.isEmpty)
              const _EmptyCard(
                title: 'No access attempts yet',
                body: 'Admin OTP send and verify events will appear here.',
              )
            else
              ..._accessAttempts.map(
                (attempt) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClayCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                attempt.phoneE164,
                                style: AppTypography.titleMd.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusPill(
                              label: _statusLabel(attempt.status),
                              background: _statusBackground(
                                context,
                                attempt.status,
                              ),
                              foreground: _statusForeground(
                                context,
                                attempt.status,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          attempt.reason ?? 'No extra details recorded.',
                          style: AppTypography.bodySm.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.activity,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                attempt.sourceApp,
                                style: AppTypography.labelSm.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatTimestamp(attempt.createdAt),
                              style: AppTypography.labelSm.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.headlineSm.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.bodySm.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClayCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMd.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.bodySm.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatCardData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCardData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _TripHealthMetric extends StatelessWidget {
  const _TripHealthMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSm.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.titleLg.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'denied_not_allowlisted':
      return 'BLOCKED';
    case 'delivery_failed':
      return 'FAILED';
    case 'invalid_code':
      return 'INVALID OTP';
    case 'locked_out':
      return 'LOCKED';
    case 'otp_sent':
      return 'OTP SENT';
    case 'rate_limited':
      return 'COOLDOWN';
    case 'verified':
      return 'VERIFIED';
    case 'verify_denied':
      return 'DENIED';
    default:
      return status.replaceAll('_', ' ').toUpperCase();
  }
}

Color _statusBackground(BuildContext context, String status) {
  final colorScheme = Theme.of(context).colorScheme;

  switch (status) {
    case 'verified':
    case 'otp_sent':
      return colorScheme.primary.withValues(alpha: 0.12);
    case 'rate_limited':
      return colorScheme.secondaryContainer;
    case 'invalid_code':
    case 'delivery_failed':
    case 'locked_out':
    case 'verify_denied':
    case 'denied_not_allowlisted':
      return colorScheme.error.withValues(alpha: 0.12);
    default:
      return colorScheme.surfaceContainerHighest;
  }
}

Color _statusForeground(BuildContext context, String status) {
  final colorScheme = Theme.of(context).colorScheme;

  switch (status) {
    case 'verified':
    case 'otp_sent':
      return colorScheme.primary;
    case 'rate_limited':
      return colorScheme.onSecondaryContainer;
    case 'invalid_code':
    case 'delivery_failed':
    case 'locked_out':
    case 'verify_denied':
    case 'denied_not_allowlisted':
      return colorScheme.error;
    default:
      return colorScheme.onSurfaceVariant;
  }
}

String _formatTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) {
    return 'Just now';
  }

  final timestamp = DateTime.tryParse(raw)?.toLocal();
  if (timestamp == null) {
    return raw;
  }

  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) {
    return 'Just now';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }

  return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
}

String _localPhone(String? phoneE164, String? countryCode) {
  final phone = phoneE164?.trim();
  final prefix = countryCode?.trim();

  if (phone == null || phone.isEmpty) {
    return '';
  }

  if (prefix != null && prefix.isNotEmpty && phone.startsWith(prefix)) {
    return phone.substring(prefix.length).replaceFirst(RegExp(r'^0+'), '');
  }

  return phone.replaceFirst(RegExp(r'^\+'), '');
}
