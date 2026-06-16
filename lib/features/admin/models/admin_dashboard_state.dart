import 'package:mobi_app/core/services/admin_service.dart';

class AdminDashboardState {
  final AdminDashboardStats? stats;
  final List<AdminWhatsappNumberItem> adminNumbers;
  final AdminPlatformSettings platformSettings;
  final List<AdminTokenRedemptionItem> tokenRedemptions;
  final List<AdminAccessAttemptItem> accessAttempts;
  final List<AdminNotificationItem> alerts;
  final bool isLoading;
  final bool isRefreshing;
  final bool isSavingNumber;
  final bool isSavingPlatformSettings;
  final bool isMarkingAlerts;
  final String? busyNumberId;
  final String? busyRedemptionId;
  final String? loadError;

  const AdminDashboardState({
    this.stats,
    this.adminNumbers = const [],
    this.platformSettings = const AdminPlatformSettings(),
    this.tokenRedemptions = const [],
    this.accessAttempts = const [],
    this.alerts = const [],
    this.isLoading = true,
    this.isRefreshing = false,
    this.isSavingNumber = false,
    this.isSavingPlatformSettings = false,
    this.isMarkingAlerts = false,
    this.busyNumberId,
    this.busyRedemptionId,
    this.loadError,
  });

  AdminDashboardState copyWith({
    AdminDashboardStats? stats,
    List<AdminWhatsappNumberItem>? adminNumbers,
    AdminPlatformSettings? platformSettings,
    List<AdminTokenRedemptionItem>? tokenRedemptions,
    List<AdminAccessAttemptItem>? accessAttempts,
    List<AdminNotificationItem>? alerts,
    bool? isLoading,
    bool? isRefreshing,
    bool? isSavingNumber,
    bool? isSavingPlatformSettings,
    bool? isMarkingAlerts,
    String? busyNumberId,
    String? busyRedemptionId,
    String? loadError,
  }) {
    return AdminDashboardState(
      stats: stats ?? this.stats,
      adminNumbers: adminNumbers ?? this.adminNumbers,
      platformSettings: platformSettings ?? this.platformSettings,
      tokenRedemptions: tokenRedemptions ?? this.tokenRedemptions,
      accessAttempts: accessAttempts ?? this.accessAttempts,
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSavingNumber: isSavingNumber ?? this.isSavingNumber,
      isSavingPlatformSettings:
          isSavingPlatformSettings ?? this.isSavingPlatformSettings,
      isMarkingAlerts: isMarkingAlerts ?? this.isMarkingAlerts,
      busyNumberId: busyNumberId ?? this.busyNumberId,
      busyRedemptionId: busyRedemptionId ?? this.busyRedemptionId,
      loadError: loadError ?? this.loadError,
    );
  }
}
