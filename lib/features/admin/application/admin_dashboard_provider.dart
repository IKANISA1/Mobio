import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/application/admin_dashboard_state.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';

final adminDashboardProvider =
    AsyncNotifierProvider.autoDispose<
      AdminDashboardController,
      AdminDashboardState
    >(AdminDashboardController.new);

class AdminDashboardController extends AsyncNotifier<AdminDashboardState> {
  AdminDashboardController() : _captureToken = AccountActionToken.capture;
  AdminDashboardController.test({
    required AccountSnapshot? Function() captureAccount,
  }) : _captureToken = (() =>
           AccountActionToken.capture(captureAccount: captureAccount));
  final AccountActionToken Function() _captureToken;
  late AccountActionToken _origin;
  int _revision = 0;
  bool _current(AccountActionToken token, int revision) =>
      ref.mounted && token.isCurrent && revision == _revision;
  void _require(AccountActionToken token, int revision) {
    if (!_current(token, revision)) throw const StaleAccountWork();
  }

  AdminService get _adminService => ref.read(adminServiceProvider);

  @override
  FutureOr<AdminDashboardState> build() async {
    final token = _origin = _captureToken();
    final revision = ++_revision;
    void invalidate() {
      if (!ref.mounted || token.isCurrent) return;
      _revision++;
      state = const AsyncValue.data(AdminDashboardState(isLoading: false));
      ref.invalidateSelf();
    }

    AccountContext.changes.addListener(invalidate);
    ref.onDispose(() {
      _revision++;
      AccountContext.changes.removeListener(invalidate);
    });
    final notificationService = ref.read(notificationServiceProvider);
    final subscription = notificationService.onNotification.listen((_) {
      if (ref.mounted && token.isCurrent) {
        unawaited(loadAlerts(silent: true, actionToken: token));
      }
    });

    ref.onDispose(subscription.cancel);

    return _fetchDashboardData(token, revision);
  }

  Future<AdminDashboardState> _fetchDashboardData(
    AccountActionToken token,
    int revision,
  ) async {
    _require(token, revision);
    try {
      final results = await Future.wait<dynamic>([
        _adminService.getDashboardStats(),
        _adminService.listWhatsappAdminNumbers(),
        _adminService.listAdminAccessAttempts(limit: 8),
        _adminService.listAdminNotifications(limit: 12),
        _adminService.getPlatformSettings(),
        _adminService.listTokenRedemptions(status: 'pending', limit: 8),
      ]);

      _require(token, revision);
      return AdminDashboardState(
        stats: results[0] as AdminDashboardStats,
        adminNumbers: results[1] as List<AdminWhatsappNumberItem>,
        accessAttempts: results[2] as List<AdminAccessAttemptItem>,
        alerts: results[3] as List<AdminNotificationItem>,
        platformSettings: results[4] as AdminPlatformSettings,
        tokenRedemptions: results[5] as List<AdminTokenRedemptionItem>,
        isLoading: false,
      );
    } on Object catch (error) {
      _require(token, revision);
      return AdminDashboardState(isLoading: false, loadError: error.toString());
    }
  }

  Future<void> refresh({AccountActionToken? actionToken}) async {
    final token = actionToken ?? _origin;
    if (!ref.mounted || !token.isCurrent) return;
    final revision = ++_revision;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => _fetchDashboardData(token, revision),
    );
    if (_current(token, revision)) state = result;
  }

  Future<void> loadAlerts({
    bool silent = false,
    AccountActionToken? actionToken,
  }) async {
    final token = actionToken ?? _origin;
    final revision = _revision;
    if (!_current(token, revision)) return;
    final currentState = state.value;
    if (currentState == null) return;

    if (!silent) {
      state = AsyncValue.data(currentState.copyWith(isRefreshing: true));
    }

    try {
      final alerts = await _adminService.listAdminNotifications(limit: 12);
      if (!_current(token, revision)) return;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(alerts: alerts, isRefreshing: false),
        );
      }
    } on Object catch (error) {
      if (!_current(token, revision)) return;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(loadError: error.toString(), isRefreshing: false),
        );
      }
    }
  }

  Future<void> markAlertAsRead(
    AdminNotificationItem notification, {
    AccountActionToken? actionToken,
  }) async {
    final token = actionToken ?? _origin;
    final revision = _revision;
    if (!_current(token, revision)) return;
    if (notification.isRead) return;

    try {
      await _adminService.markAdminNotificationRead(notification.id);
      if (!_current(token, revision)) return;
      await loadAlerts(silent: true, actionToken: token);
    } on Object {
      // Handled silently or via state
    }
  }

  Future<void> markAllAlertsRead({AccountActionToken? actionToken}) async {
    final token = actionToken ?? _origin;
    final revision = _revision;
    if (!_current(token, revision)) return;
    final currentState = state.value;
    if (currentState == null || currentState.isMarkingAlerts) return;

    state = AsyncValue.data(currentState.copyWith(isMarkingAlerts: true));

    try {
      await _adminService.markAllAdminNotificationsRead();
      if (!_current(token, revision)) return;
      await loadAlerts(silent: true, actionToken: token);
    } on Object {
      // Handled silently
    } finally {
      if (_current(token, revision)) {
        final finalState = state.value;
        if (finalState != null) {
          state = AsyncValue.data(finalState.copyWith(isMarkingAlerts: false));
        }
      }
    }
  }

  Future<void> toggleNumber(
    AdminWhatsappNumberItem item, {
    AccountActionToken? actionToken,
  }) async {
    final token = actionToken ?? _origin;
    final revision = _revision;
    if (!_current(token, revision)) return;
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(busyNumberId: item.id));

    try {
      await _adminService.setWhatsappAdminNumberActive(
        id: item.id,
        isActive: !item.isActive,
      );
      if (!_current(token, revision)) return;
      final updatedData = await _fetchDashboardData(token, revision);
      if (!_current(token, revision)) return;
      state = AsyncValue.data(updatedData.copyWith(busyNumberId: null));
    } on Object {
      if (!_current(token, revision)) return;
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
    AccountActionToken? actionToken,
  }) async {
    final token = actionToken ?? _origin;
    final revision = _revision;
    if (!_current(token, revision)) return;
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
      if (!_current(token, revision)) return;
      final updatedData = await _fetchDashboardData(token, revision);
      if (!_current(token, revision)) return;
      state = AsyncValue.data(updatedData.copyWith(isSavingNumber: false));
    } on Object {
      if (!_current(token, revision)) return;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isSavingNumber: false));
      }
      rethrow;
    }
  }

  Future<void> savePlatformSettings({
    required String insuranceAgentWhatsappE164,
    required String tokenRedemptionAdminMemberId,
    AccountActionToken? actionToken,
  }) async {
    final token = actionToken ?? _origin;
    final revision = _revision;
    if (!_current(token, revision)) return;
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(
      currentState.copyWith(isSavingPlatformSettings: true),
    );

    try {
      await _adminService.updatePlatformSetting(
        key: 'insurance_agent_whatsapp_e164',
        value: insuranceAgentWhatsappE164,
      );
      if (!_current(token, revision)) return;
      await _adminService.updatePlatformSetting(
        key: 'token_redemption_admin_member_id',
        value: tokenRedemptionAdminMemberId,
      );
      if (!_current(token, revision)) return;
      final updatedData = await _fetchDashboardData(token, revision);
      if (!_current(token, revision)) return;
      state = AsyncValue.data(
        updatedData.copyWith(isSavingPlatformSettings: false),
      );
    } on Object {
      if (!_current(token, revision)) return;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(isSavingPlatformSettings: false),
        );
      }
      rethrow;
    }
  }

  Future<void> markTokenRedemptionCashSent(
    AdminTokenRedemptionItem item, {
    AccountActionToken? actionToken,
  }) async {
    final token = actionToken ?? _origin;
    final revision = _revision;
    if (!_current(token, revision)) return;
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(busyRedemptionId: item.id));

    try {
      await _adminService.updateTokenRedemptionStatus(
        requestId: item.id,
        status: 'cash_sent',
      );
      if (!_current(token, revision)) return;
      final updatedData = await _fetchDashboardData(token, revision);
      if (!_current(token, revision)) return;
      state = AsyncValue.data(updatedData.copyWith(busyRedemptionId: ''));
    } on Object {
      if (!_current(token, revision)) return;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(busyRedemptionId: ''));
      }
      rethrow;
    }
  }
}
