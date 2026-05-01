import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/features/admin/models/admin_dashboard_state.dart';

final adminDashboardProvider = AsyncNotifierProvider.autoDispose<
  AdminDashboardController,
  AdminDashboardState
>(AdminDashboardController.new);

class AdminDashboardController
    extends AsyncNotifier<AdminDashboardState> {
  AdminService get _adminService => ref.read(adminServiceProvider);

  @override
  FutureOr<AdminDashboardState> build() async {
    final notificationService = ref.read(notificationServiceProvider);
    final subscription = notificationService.onNotification.listen((_) {
      unawaited(loadAlerts(silent: true));
    });

    ref.onDispose(() {
      subscription.cancel();
    });

    return _fetchDashboardData();
  }

  Future<AdminDashboardState> _fetchDashboardData() async {
    try {
      final results = await Future.wait<dynamic>([
        _adminService.getDashboardStats(),
        _adminService.listWhatsappAdminNumbers(),
        _adminService.listAdminAccessAttempts(limit: 8),
        _adminService.listAdminNotifications(limit: 12),
      ]);

      return AdminDashboardState(
        stats: results[0] as AdminDashboardStats,
        adminNumbers: results[1] as List<AdminWhatsappNumberItem>,
        accessAttempts: results[2] as List<AdminAccessAttemptItem>,
        alerts: results[3] as List<AdminNotificationItem>,
        isLoading: false,
      );
    } catch (error) {
      return AdminDashboardState(
        isLoading: false,
        loadError: error.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchDashboardData());
  }

  Future<void> loadAlerts({bool silent = false}) async {
    final currentState = state.value;
    if (currentState == null) return;

    if (!silent) {
      state = AsyncValue.data(currentState.copyWith(isRefreshing: true));
    }

    try {
      final alerts = await _adminService.listAdminNotifications(limit: 12);
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            alerts: alerts,
            isRefreshing: false,
          ),
        );
      }
    } catch (error) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            loadError: error.toString(),
            isRefreshing: false,
          ),
        );
      }
    }
  }

  Future<void> markAlertAsRead(AdminNotificationItem notification) async {
    if (notification.isRead) return;

    try {
      await _adminService.markAdminNotificationRead(notification.id);
      await loadAlerts(silent: true);
    } catch (error) {
      // Handled silently or via state
    }
  }

  Future<void> markAllAlertsRead() async {
    final currentState = state.value;
    if (currentState == null || currentState.isMarkingAlerts) return;

    state = AsyncValue.data(currentState.copyWith(isMarkingAlerts: true));

    try {
      await _adminService.markAllAdminNotificationsRead();
      await loadAlerts(silent: true);
    } catch (error) {
      // Handled silently
    } finally {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isMarkingAlerts: false));
      }
    }
  }

  Future<void> toggleNumber(AdminWhatsappNumberItem item) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(busyNumberId: item.id));

    try {
      await _adminService.setWhatsappAdminNumberActive(
        id: item.id,
        isActive: !item.isActive,
      );
      final updatedData = await _fetchDashboardData();
      state = AsyncValue.data(updatedData.copyWith(busyNumberId: null));
    } catch (error) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(busyNumberId: null));
      }
    }
  }

  Future<void> saveWhatsappNumber({
    required String phoneE164,
    required String countryCode,
    String? displayName,
    bool isActive = true,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(isSavingNumber: true));

    try {
      await _adminService.upsertWhatsappAdminNumber(
        phoneE164: phoneE164,
        countryCode: countryCode,
        displayName: displayName,
        isActive: isActive,
      );
      final updatedData = await _fetchDashboardData();
      state = AsyncValue.data(updatedData.copyWith(isSavingNumber: false));
    } catch (error) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isSavingNumber: false));
      }
      rethrow;
    }
  }
}
