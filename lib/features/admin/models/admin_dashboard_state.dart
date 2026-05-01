import 'package:mobi_app/core/services/admin_service.dart';

class AdminDashboardState {
  final AdminDashboardStats? stats;
  final List<AdminWhatsappNumberItem> adminNumbers;
  final List<AdminAccessAttemptItem> accessAttempts;
  final List<AdminNotificationItem> alerts;
  final bool isLoading;
  final bool isRefreshing;
  final bool isSavingNumber;
  final bool isMarkingAlerts;
  final String? busyNumberId;
  final String? loadError;

  const AdminDashboardState({
    this.stats,
    this.adminNumbers = const [],
    this.accessAttempts = const [],
    this.alerts = const [],
    this.isLoading = true,
    this.isRefreshing = false,
    this.isSavingNumber = false,
    this.isMarkingAlerts = false,
    this.busyNumberId,
    this.loadError,
  });

  AdminDashboardState copyWith({
    AdminDashboardStats? stats,
    List<AdminWhatsappNumberItem>? adminNumbers,
    List<AdminAccessAttemptItem>? accessAttempts,
    List<AdminNotificationItem>? alerts,
    bool? isLoading,
    bool? isRefreshing,
    bool? isSavingNumber,
    bool? isMarkingAlerts,
    String? busyNumberId,
    String? loadError,
  }) {
    return AdminDashboardState(
      stats: stats ?? this.stats,
      adminNumbers: adminNumbers ?? this.adminNumbers,
      accessAttempts: accessAttempts ?? this.accessAttempts,
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSavingNumber: isSavingNumber ?? this.isSavingNumber,
      isMarkingAlerts: isMarkingAlerts ?? this.isMarkingAlerts,
      busyNumberId: busyNumberId ?? this.busyNumberId,
      loadError: loadError ?? this.loadError,
    );
  }
}
