import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/features/admin/models/admin_dashboard_state.dart';
import 'package:mobi_app/features/admin/providers/admin_dashboard_provider.dart';
import 'package:mobi_app/features/admin/widgets/admin_dashboard_panels.dart';
import 'package:mobi_app/features/admin/widgets/admin_stats_grid.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/features/admin/widgets/admin_whatsapp_sheet.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';

/// Admin dashboard with live platform health, access control, and action queues.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showWhatsappSheet(
    BuildContext context,
    WidgetRef ref, {
    AdminWhatsappNumberItem? existing,
  }) {
    MobiBottomSheet.show<void>(
      context: context,
      includeViewInsets: false,
      builder: (ctx) => AdminWhatsappSheet(
        existing: existing,
        onSave:
            ({
              required String phoneE164,
              required String countryCode,
              String? displayName,
              required bool isActive,
            }) async {
              await ref
                  .read(adminDashboardProvider.notifier)
                  .saveWhatsappNumber(
                    phoneE164: phoneE164,
                    countryCode: countryCode,
                    displayName: displayName,
                    isActive: isActive,
                  );
              if (context.mounted) {
                _showSnackBar(context, 'Allowlist updated.');
              }
            },
      ),
    );
  }

  void _showPlatformSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    AdminPlatformSettings settings,
  ) {
    final insuranceController = TextEditingController(
      text: settings.insuranceAgentWhatsappE164,
    );
    final adminWalletController = TextEditingController(
      text: settings.tokenRedemptionAdminMemberId,
    );

    MobiBottomSheet.show<void>(
      context: context,
      includeViewInsets: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminSectionHeader(
              title: 'Platform settings',
              subtitle: 'Insurance contact and redemption wallet',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: insuranceController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Insurance agent WhatsApp',
                hintText: '+250795588248',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: adminWalletController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Redemption admin wallet ID',
                counterText: '',
                hintText: '123456',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AdminActionChip(
                    label: 'Cancel',
                    icon: LucideIcons.x,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AdminActionChip(
                    label: 'Save',
                    icon: LucideIcons.save,
                    tone: MobiStatusBadgeTone.brand,
                    onTap: () async {
                      try {
                        await ref
                            .read(adminDashboardProvider.notifier)
                            .savePlatformSettings(
                              insuranceAgentWhatsappE164: insuranceController
                                  .text
                                  .trim(),
                              tokenRedemptionAdminMemberId:
                                  adminWalletController.text.trim(),
                            );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          _showSnackBar(context, 'Platform settings updated.');
                        }
                      } on Object catch (error) {
                        if (context.mounted) {
                          _showSnackBar(
                            context,
                            error.toString(),
                            isError: true,
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      insuranceController.dispose();
      adminWalletController.dispose();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(adminDashboardProvider);
    final controller = ref.read(adminDashboardProvider.notifier);

    return AdminWorkspaceFrame(
      currentTab: AdminWorkspaceTab.overview,
      title: 'Operations',
      subtitle: 'Live state and access.',
      actions: [
        AdminActionChip(
          label: 'Users',
          icon: LucideIcons.users,
          tone: MobiStatusBadgeTone.info,
          onTap: () => context.go('/admin/users'),
        ),
        AdminActionChip(
          label: 'Health',
          icon: LucideIcons.activity,
          tone: MobiStatusBadgeTone.warning,
          onTap: () => context.go('/admin/health'),
        ),
        AdminActionChip(
          label: 'Refresh',
          icon: LucideIcons.refreshCw,
          isBusy:
              asyncState.isLoading || (asyncState.value?.isRefreshing ?? false),
          onTap: asyncState.isLoading ? null : controller.refresh,
        ),
      ],
      child: asyncState.when(
        data: (state) => RefreshIndicator.adaptive(
          onRefresh: controller.refresh,
          child: _DashboardContent(
            state: state,
            controller: controller,
            onAddNumber: () => _showWhatsappSheet(context, ref),
            onEditNumber: (item) =>
                _showWhatsappSheet(context, ref, existing: item),
            onEditPlatformSettings: () => _showPlatformSettingsSheet(
              context,
              ref,
              state.platformSettings,
            ),
          ),
        ),
        loading: () => const _DashboardLoadingState(),
        error: (err, stack) =>
            _ErrorBanner(message: err.toString(), onRetry: controller.refresh),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.state,
    required this.controller,
    required this.onAddNumber,
    required this.onEditNumber,
    required this.onEditPlatformSettings,
  });

  final AdminDashboardState state;
  final AdminDashboardController controller;
  final VoidCallback onAddNumber;
  final ValueChanged<AdminWhatsappNumberItem> onEditNumber;
  final VoidCallback onEditPlatformSettings;

  @override
  Widget build(BuildContext context) {
    final unreadAlerts = state.alerts.where((alert) => !alert.isRead).length;
    final blockedAttempts = state.accessAttempts
        .where((attempt) => !_isPositiveAttempt(attempt.status))
        .length;
    final inactiveNumbers = state.adminNumbers
        .where((item) => !item.isActive)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1120;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AdminLayoutTokens.pagePadding,
          children: [
            if (state.loadError != null) ...[
              _ErrorBanner(
                message: state.loadError!,
                onRetry: controller.refresh,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AdminStatsGrid(stats: state.stats, isLoading: state.isLoading),
            const SizedBox(height: AppSpacing.lg),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        AdminPriorityPanel(
                          unreadAlerts: unreadAlerts,
                          blockedAttempts: blockedAttempts,
                          inactiveNumbers: inactiveNumbers,
                          isMarkingAlerts: state.isMarkingAlerts,
                          onReadAll: controller.markAllAlertsRead,
                          onAddNumber: onAddNumber,
                          onGoToUsers: () => context.push('/admin/users'),
                          onGoToTrips: () => context.push('/admin/trips'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AdminAccessPanel(accessAttempts: state.accessAttempts),
                        const SizedBox(height: AppSpacing.lg),
                        AdminPlatformSettingsPanel(
                          settings: state.platformSettings,
                          isSaving: state.isSavingPlatformSettings,
                          onEdit: onEditPlatformSettings,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      children: [
                        AdminAlertsPanel(
                          alerts: state.alerts,
                          unreadCount: unreadAlerts,
                          isMarkingRead: state.isMarkingAlerts,
                          onMarkRead: controller.markAlertAsRead,
                          onReadAll: controller.markAllAlertsRead,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AdminAllowlistPanel(
                          adminNumbers: state.adminNumbers,
                          busyNumberId: state.busyNumberId,
                          onAdd: onAddNumber,
                          onEdit: onEditNumber,
                          onToggle: controller.toggleNumber,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AdminTokenRedemptionsPanel(
                          redemptions: state.tokenRedemptions,
                          busyRedemptionId: state.busyRedemptionId,
                          onCashSent: controller.markTokenRedemptionCashSent,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              AdminPriorityPanel(
                unreadAlerts: unreadAlerts,
                blockedAttempts: blockedAttempts,
                inactiveNumbers: inactiveNumbers,
                isMarkingAlerts: state.isMarkingAlerts,
                onReadAll: controller.markAllAlertsRead,
                onAddNumber: onAddNumber,
                onGoToUsers: () => context.push('/admin/users'),
                onGoToTrips: () => context.push('/admin/trips'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminAlertsPanel(
                alerts: state.alerts,
                unreadCount: unreadAlerts,
                isMarkingRead: state.isMarkingAlerts,
                onMarkRead: controller.markAlertAsRead,
                onReadAll: controller.markAllAlertsRead,
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminAccessPanel(accessAttempts: state.accessAttempts),
              const SizedBox(height: AppSpacing.lg),
              AdminPlatformSettingsPanel(
                settings: state.platformSettings,
                isSaving: state.isSavingPlatformSettings,
                onEdit: onEditPlatformSettings,
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminTokenRedemptionsPanel(
                redemptions: state.tokenRedemptions,
                busyRedemptionId: state.busyRedemptionId,
                onCashSent: controller.markTokenRedemptionCashSent,
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminAllowlistPanel(
                adminNumbers: state.adminNumbers,
                busyNumberId: state.busyNumberId,
                onAdd: onAddNumber,
                onEdit: onEditNumber,
                onToggle: controller.toggleNumber,
              ),
            ],
          ],
        );
      },
    );
  }

  bool _isPositiveAttempt(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'approved' ||
        normalized == 'allowed' ||
        normalized == 'success';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Row(
        children: [
          Icon(
            LucideIcons.alertTriangle,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
          AdminActionChip(
            label: 'Retry',
            icon: LucideIcons.refreshCw,
            tone: MobiStatusBadgeTone.danger,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AdminLayoutTokens.pagePadding,
      children: const [
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
