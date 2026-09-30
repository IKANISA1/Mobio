import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/application/admin_dashboard_provider.dart';
import 'package:mobi_app/features/admin/application/admin_dashboard_state.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_dashboard_panels.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_stats_grid.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_whatsapp_sheet.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';

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
    WidgetRef ref,
    AccountActionToken token, {
    AdminWhatsappNumberItem? existing,
  }) {
    if (!context.mounted || !token.isCurrent) return;
    MobiBottomSheet.show<void>(
      context: context,
      includeViewInsets: false,
      builder: (ctx) => _AdminAccountView(
        token: token,
        child: AdminWhatsappSheet(
          existing: existing,
          onSave:
              ({
                required String phoneE164,
                required String countryCode,
                String? displayName,
                required bool isActive,
              }) async {
                if (!context.mounted || !token.isCurrent) return;
                await ref
                    .read(adminDashboardProvider.notifier)
                    .saveWhatsappNumber(
                      phoneE164: phoneE164,
                      countryCode: countryCode,
                      displayName: displayName,
                      isActive: isActive,
                      actionToken: token,
                    );
                if (context.mounted && token.isCurrent) {
                  _showSnackBar(context, 'Allowlist updated.');
                }
              },
        ),
      ),
    );
  }

  void _showPlatformSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    AdminPlatformSettings settings,
    AccountActionToken token,
  ) {
    if (!context.mounted || !token.isCurrent) return;
    final insuranceController = TextEditingController(
      text: settings.insuranceAgentWhatsappE164,
    );
    final adminWalletController = TextEditingController(
      text: settings.tokenRedemptionAdminMemberId,
    );

    MobiBottomSheet.show<void>(
      context: context,
      includeViewInsets: true,
      builder: (ctx) => _AdminAccountView(
        token: token,
        child: Padding(
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
                        if (!context.mounted || !token.isCurrent) return;
                        try {
                          await ref
                              .read(adminDashboardProvider.notifier)
                              .savePlatformSettings(
                                insuranceAgentWhatsappE164: insuranceController
                                    .text
                                    .trim(),
                                tokenRedemptionAdminMemberId:
                                    adminWalletController.text.trim(),
                                actionToken: token,
                              );
                          if (!token.isCurrent) return;
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted && token.isCurrent) {
                            _showSnackBar(
                              context,
                              'Platform settings updated.',
                            );
                          }
                        } on Object {
                          if (context.mounted && token.isCurrent) {
                            _showSnackBar(
                              context,
                              'Unable to save settings. Please try again.',
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
      ),
    ).whenComplete(() {
      insuranceController.dispose();
      adminWalletController.dispose();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = AccountActionToken.capture();
    final asyncState = ref.watch(adminDashboardProvider);
    final controller = ref.read(adminDashboardProvider.notifier);

    return _AdminAccountView(
      token: token,
      child: AdminWorkspaceFrame(
        currentTab: AdminWorkspaceTab.overview,
        title: 'Operations',
        subtitle: 'Live state and access.',
        actions: [
          AdminActionChip(
            label: 'Users',
            icon: LucideIcons.users,
            tone: MobiStatusBadgeTone.info,
            onTap: () {
              if (context.mounted && token.isCurrent) {
                context.go('/admin/users');
              }
            },
          ),
          AdminActionChip(
            label: 'Health',
            icon: LucideIcons.activity,
            tone: MobiStatusBadgeTone.warning,
            onTap: () {
              if (context.mounted && token.isCurrent) {
                context.go('/admin/health');
              }
            },
          ),
          AdminActionChip(
            label: 'Refresh',
            icon: LucideIcons.refreshCw,
            isBusy:
                asyncState.isLoading ||
                (asyncState.value?.isRefreshing ?? false),
            onTap: asyncState.isLoading
                ? null
                : () => controller.refresh(actionToken: token),
          ),
        ],
        child: asyncState.when(
          data: (state) => RefreshIndicator.adaptive(
            onRefresh: () => controller.refresh(actionToken: token),
            child: _DashboardContent(
              state: state,
              controller: controller,
              token: token,
              onAddNumber: () => _showWhatsappSheet(context, ref, token),
              onEditNumber: (item) =>
                  _showWhatsappSheet(context, ref, token, existing: item),
              onEditPlatformSettings: () => _showPlatformSettingsSheet(
                context,
                ref,
                state.platformSettings,
                token,
              ),
            ),
          ),
          loading: () => const _DashboardLoadingState(),
          error: (err, stack) => _ErrorBanner(
            onRetry: () => controller.refresh(actionToken: token),
          ),
        ),
      ),
    );
  }
}

class _AdminAccountView extends StatelessWidget {
  const _AdminAccountView({required this.token, required this.child});
  final AccountActionToken token;
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: AccountContext.changes,
    builder: (_, _, _) => token.isCurrent
        ? child
        : const Center(child: Text('Admin session locked')),
  );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.state,
    required this.controller,
    required this.token,
    required this.onAddNumber,
    required this.onEditNumber,
    required this.onEditPlatformSettings,
  });

  final AdminDashboardState state;
  final AdminDashboardController controller;
  final AccountActionToken token;
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
                onRetry: () => controller.refresh(actionToken: token),
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
                          onReadAll: () =>
                              controller.markAllAlertsRead(actionToken: token),
                          onAddNumber: onAddNumber,
                          onGoToUsers: () {
                            if (context.mounted && token.isCurrent) {
                              context.push('/admin/users');
                            }
                          },
                          onGoToTrips: () {
                            if (context.mounted && token.isCurrent) {
                              context.push('/admin/trips');
                            }
                          },
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
                          onMarkRead: (item) => controller.markAlertAsRead(
                            item,
                            actionToken: token,
                          ),
                          onReadAll: () =>
                              controller.markAllAlertsRead(actionToken: token),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AdminAllowlistPanel(
                          adminNumbers: state.adminNumbers,
                          busyNumberId: state.busyNumberId,
                          onAdd: onAddNumber,
                          onEdit: onEditNumber,
                          onToggle: (item) =>
                              controller.toggleNumber(item, actionToken: token),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AdminTokenRedemptionsPanel(
                          redemptions: state.tokenRedemptions,
                          busyRedemptionId: state.busyRedemptionId,
                          onCashSent: (item) =>
                              controller.markTokenRedemptionCashSent(
                                item,
                                actionToken: token,
                              ),
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
                onReadAll: () =>
                    controller.markAllAlertsRead(actionToken: token),
                onAddNumber: onAddNumber,
                onGoToUsers: () {
                  if (context.mounted && token.isCurrent) {
                    context.push('/admin/users');
                  }
                },
                onGoToTrips: () {
                  if (context.mounted && token.isCurrent) {
                    context.push('/admin/trips');
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminAlertsPanel(
                alerts: state.alerts,
                unreadCount: unreadAlerts,
                isMarkingRead: state.isMarkingAlerts,
                onMarkRead: (item) =>
                    controller.markAlertAsRead(item, actionToken: token),
                onReadAll: () =>
                    controller.markAllAlertsRead(actionToken: token),
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
                onCashSent: (item) => controller.markTokenRedemptionCashSent(
                  item,
                  actionToken: token,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminAllowlistPanel(
                adminNumbers: state.adminNumbers,
                busyNumberId: state.busyNumberId,
                onAdd: onAddNumber,
                onEdit: onEditNumber,
                onToggle: (item) =>
                    controller.toggleNumber(item, actionToken: token),
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
  const _ErrorBanner({required this.onRetry});
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
          const Expanded(
            child: Text(
              'Unable to load operations. Check your connection and try again.',
            ),
          ),
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
