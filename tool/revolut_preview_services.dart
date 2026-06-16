import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/subscription_plan_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/models/subscription_plan_model.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final revolutPreviewOverrides = [
  countryServiceProvider.overrideWithValue(_PreviewCountryService()),
  vehicleTypeServiceProvider.overrideWithValue(_PreviewVehicleTypeService()),
  subscriptionPlanServiceProvider.overrideWithValue(
    _PreviewSubscriptionPlanService(),
  ),
  tripServiceProvider.overrideWithValue(_PreviewTripService()),
  adminServiceProvider.overrideWithValue(_PreviewAdminService()),
];

final _previewCountries = Country.fallbackCountries
    .where((country) => country.id == 'RW' || country.id == 'KE')
    .toList();

final _previewVehicleTypes = VehicleTypeModel.fallbackTypes
    .map(
      (type) => VehicleTypeModel(
        id: type.id,
        label: type.label,
        iconName: type.iconName,
        sortOrder: type.sortOrder,
        isActive: type.id != 'truck',
        countryIds: const ['RW', 'KE'],
      ),
    )
    .toList();

const _previewPlans = [
  SubscriptionPlanModel(
    id: 'plan-bus-daily',
    vehicleTypeId: 'bus',
    countryId: 'RW',
    intervalDays: 1,
    price: 1200,
    currency: 'RWF',
  ),
  SubscriptionPlanModel(
    id: 'plan-cab-monthly',
    vehicleTypeId: 'cab',
    countryId: 'RW',
    intervalDays: 30,
    price: 18000,
    currency: 'RWF',
  ),
  SubscriptionPlanModel(
    id: 'plan-moto-weekly',
    vehicleTypeId: 'moto',
    countryId: 'KE',
    intervalDays: 7,
    price: 900,
    currency: 'KES',
    isActive: false,
  ),
];

class _PreviewCountryService implements CountryService {
  @override
  Future<List<Country>> getCountries() async => _previewCountries;

  @override
  Future<List<Country>> getAfricanCountries() async => _previewCountries;

  @override
  Future<Country?> findById(String id) async => _previewCountries.firstWhere(
    (country) => country.id == id,
    orElse: () => _previewCountries.first,
  );

  @override
  Future<Country> findByDialingCode(String code) async =>
      findByDialingCodeSync(code) ?? _previewCountries.first;

  @override
  Country? findByDialingCodeSync(String code) => _previewCountries
      .where((country) => country.dialingCode == code)
      .firstOrNull;

  @override
  Future<String> currencyForCode(String dialingCode) async =>
      currencyForCodeSync(dialingCode);

  @override
  String currencyForCodeSync(String dialingCode) =>
      findByDialingCodeSync(dialingCode)?.currency ?? 'RWF';

  @override
  String momoBrandForCodeSync(String dialingCode) =>
      findByDialingCodeSync(dialingCode)?.momoBrand ?? 'MoMo';

  @override
  String buildUssdForNumber(
    String dialingCode,
    String phone, [
    String? amount,
  ]) =>
      findByDialingCodeSync(dialingCode)?.buildUssdForNumber(phone, amount) ??
      '';

  @override
  String buildUssdForCode(String dialingCode, String code, [String? amount]) =>
      findByDialingCodeSync(dialingCode)?.buildUssdForCode(code, amount) ?? '';

  @override
  String normalizeLocalPhoneDisplay({
    required String dialingCode,
    required String rawValue,
    Country? country,
  }) => rawValue.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Future<void> warmCache() async {}

  @override
  void clearCache() {}
}

class _PreviewVehicleTypeService implements VehicleTypeService {
  @override
  Future<List<VehicleTypeModel>> getAll({bool includeInactive = false}) async =>
      includeInactive
      ? _previewVehicleTypes
      : _previewVehicleTypes.where((type) => type.isActive).toList();

  @override
  Future<List<VehicleTypeModel>> getForCountry(String countryId) async =>
      _previewVehicleTypes
          .where((type) => type.countryIds.contains(countryId))
          .toList();

  @override
  Future<VehicleTypeModel?> findById(String id) async =>
      _previewVehicleTypes.where((type) => type.id == id).firstOrNull;

  @override
  void invalidateCache() {}

  @override
  Future<void> warmCache() async {}

  @override
  Future<void> update(VehicleTypeModel model) async {}

  @override
  Future<void> updateCountries(
    String vehicleTypeId,
    List<String> countryIds,
  ) async {}

  @override
  Future<void> toggleActive(String vehicleTypeId, bool isActive) async {}
}

class _PreviewSubscriptionPlanService implements SubscriptionPlanService {
  @override
  SupabaseClient get supabase => throw UnimplementedError();

  @override
  Future<List<SubscriptionPlanModel>> getAll({
    bool forceRefresh = false,
  }) async => _previewPlans;

  @override
  Future<List<SubscriptionPlanModel>> getAvailablePlans(
    String vehicleTypeId,
    String countryId,
  ) async => _previewPlans
      .where(
        (plan) =>
            plan.vehicleTypeId == vehicleTypeId &&
            plan.countryId == countryId &&
            plan.isActive,
      )
      .toList();

  @override
  Future<void> upsert({
    required String vehicleTypeId,
    required String countryId,
    required int intervalDays,
    required double price,
    required String currency,
    bool isActive = true,
  }) async {}

  @override
  Future<void> toggleActive(String id, bool isActive) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<SubscriptionOperationsSnapshot> getOperationsSnapshot({
    int limit = 25,
  }) async => const SubscriptionOperationsSnapshot(
    paymentRequests: [],
    smsReceipts: [],
  );

  @override
  Future<int> expireStalePaymentRequests() async => 0;

  @override
  Future<void> confirmMomoSmsReceipt({
    required String receiptId,
    String? reviewNote,
  }) async {}

  @override
  void invalidateCache() {}
}

class _PreviewTripService implements TripService {
  List<Trip> get _trips => const [
    Trip(
      id: 't1',
      authorId: 'preview-driver',
      authorName: 'Jean Driver',
      origin: 'Kigali Heights',
      destination: 'Kimironko Terminal',
      originLat: -1.9536,
      originLng: 30.0928,
      destLat: -1.9367,
      destLng: 30.1308,
      departureDate: '2026-06-20',
      departureTime: '08:30',
      role: 'driver',
      seats: 3,
      price: 'RWF 2,500',
      note: 'Shared morning route with two open seats.',
      isActive: true,
      status: 'active',
      vehicleTypeStr: 'bus',
      isRecurring: true,
      recurringDays: [0, 2, 4],
    ),
  ];

  @override
  Future<Trip> createTrip({
    required String origin,
    String? originPlaceId,
    double? originLat,
    double? originLng,
    required String destination,
    String? destinationPlaceId,
    double? destLat,
    double? destLng,
    required String departureDate,
    required String departureTime,
    required String role,
    String vehicleType = 'cab',
    bool isRecurring = false,
    List<int> recurringDays = const [],
    String? clientRequestId,
    String? note,
  }) async => _trips.first;

  @override
  Future<Trip?> getTripById(String tripId) async =>
      _trips.where((trip) => trip.id == tripId).firstOrNull ?? _trips.first;

  @override
  Future<List<Trip>> getMyTrips() async => _trips;

  @override
  Future<List<Trip>> getNearbyTrips({String? role}) async {
    final normalizedRole = role?.trim().toLowerCase();
    if (normalizedRole == 'driver' || normalizedRole == 'passenger') {
      return _trips.where((trip) => trip.role == normalizedRole).toList();
    }
    return _trips;
  }

  @override
  Future<List<Trip>> getCounterpartScheduledTrips(String viewerMode) async {
    final roleToView = viewerMode.trim().toLowerCase() == 'driver'
        ? 'passenger'
        : 'driver';
    return getNearbyTrips(role: roleToView);
  }

  @override
  Future<List<Trip>> getPoolSuggestions(
    String tripId, {
    int limit = 10,
  }) async => _trips.take(limit).toList();

  @override
  Future<Trip> updateTrip({
    required String tripId,
    required String origin,
    String? originPlaceId,
    double? originLat,
    double? originLng,
    required String destination,
    String? destinationPlaceId,
    double? destLat,
    double? destLng,
    required String departureDate,
    required String departureTime,
    required String role,
    String vehicleType = 'cab',
    bool isRecurring = false,
    List<int> recurringDays = const [],
    String? note,
  }) async => _trips.first;

  @override
  Future<void> cancelTrip(String tripId) async {}
}

class _PreviewAdminService implements AdminService {
  @override
  String? get currentUserId => 'preview-admin';

  @override
  Future<bool> checkAdminAccess(String phoneE164) async => true;

  @override
  Future<AdminDashboardStats> getDashboardStats() async =>
      const AdminDashboardStats(
        totalUsers: 214,
        activeDrivers: 58,
        activePassengers: 156,
        totalTrips: 482,
        activeTrips: 48,
        cancelledTrips: 6,
      );

  @override
  Future<List<AdminUserListItem>> listUsers({
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => const [
    AdminUserListItem(
      id: 'u1',
      name: 'Chantal Rider',
      phone: '+250788111222',
      role: 'passenger',
      isDriver: false,
      hasFaceId: true,
      isOnline: true,
      memberId: '482013',
      createdAt: '2026-06-10T08:00:00Z',
    ),
  ];

  @override
  Future<List<AdminTripListItem>> listTrips({
    String? status,
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => const [
    AdminTripListItem(
      id: 'trip-1',
      authorId: 'u2',
      authorName: 'Jean Driver',
      origin: 'Kigali Heights',
      destination: 'Kimironko Terminal',
      role: 'driver',
      vehicleType: 'bus',
      status: 'active',
      isActive: true,
      departureDate: '2026-06-20',
      memberId: '593821',
    ),
  ];

  @override
  Future<void> cancelTrip({required String tripId, String? reason}) async {}

  @override
  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {}

  @override
  Future<AdminTokenAdjustmentReceipt> adjustUserTokens({
    required String userId,
    required int amountTokens,
    String? note,
  }) async => AdminTokenAdjustmentReceipt(
    ledgerEntryId: 'ledger-$userId',
    profileId: userId,
    amountTokens: amountTokens,
    status: 'completed',
  );

  @override
  Future<List<AdminWhatsappNumberItem>> listWhatsappAdminNumbers() async =>
      const [
        AdminWhatsappNumberItem(
          id: 'allow-1',
          phoneE164: '+250788000111',
          countryCode: '+250',
          isActive: true,
          displayName: 'Ops lead',
        ),
      ];

  @override
  Future<AdminWhatsappNumberItem> upsertWhatsappAdminNumber({
    required String phoneE164,
    required String countryCode,
    String? displayName,
    bool isActive = true,
  }) async => AdminWhatsappNumberItem(
    id: 'allow-1',
    phoneE164: phoneE164,
    countryCode: countryCode,
    isActive: isActive,
    displayName: displayName,
  );

  @override
  Future<AdminWhatsappNumberItem> setWhatsappAdminNumberActive({
    required String id,
    required bool isActive,
  }) async => AdminWhatsappNumberItem(
    id: id,
    phoneE164: '+250788000111',
    countryCode: '+250',
    isActive: isActive,
  );

  @override
  Future<List<AdminAccessAttemptItem>> listAdminAccessAttempts({
    int limit = 20,
  }) async => const [
    AdminAccessAttemptItem(
      id: 'attempt-1',
      phoneE164: '+250788000111',
      status: 'approved',
      sourceApp: 'admin',
      createdAt: '2026-06-13T08:00:00Z',
    ),
  ];

  @override
  Future<List<AdminNotificationItem>> listAdminNotifications({
    int limit = 12,
  }) async => const [
    AdminNotificationItem(
      id: 'notice-1',
      userId: 'preview-admin',
      type: 'admin_digest',
      title: 'Daily ops review ready',
      body: 'Reports, trips, and BioPay queues are up to date.',
    ),
  ];

  @override
  Future<AdminPlatformSettings> getPlatformSettings() async =>
      const AdminPlatformSettings(
        insuranceAgentWhatsappE164: '+250795588248',
        tokenRedemptionAdminMemberId: '482013',
      );

  @override
  Future<AdminPlatformSettings> updatePlatformSetting({
    required String key,
    required String value,
  }) async => getPlatformSettings();

  @override
  Future<List<AdminTokenRedemptionItem>> listTokenRedemptions({
    String status = 'pending',
    int limit = 8,
  }) async => const [
    AdminTokenRedemptionItem(
      id: 'redeem-1',
      requesterProfileId: 'u1',
      requesterName: 'Chantal Rider',
      requesterMemberId: '482013',
      adminMemberId: '482999',
      momoNumber: '0788111222',
      amountTokens: 5000,
      amountRwf: 5000,
      status: 'pending',
      createdAt: '2026-06-16T08:00:00Z',
    ),
  ];

  @override
  Future<AdminTokenRedemptionItem> updateTokenRedemptionStatus({
    required String requestId,
    required String status,
    String? adminNote,
  }) async => AdminTokenRedemptionItem(
    id: requestId,
    requesterProfileId: 'u1',
    requesterName: 'Chantal Rider',
    requesterMemberId: '482013',
    adminMemberId: '482999',
    momoNumber: '0788111222',
    amountTokens: 5000,
    amountRwf: 5000,
    status: status,
    adminNote: adminNote,
  );

  @override
  Future<void> markAdminNotificationRead(String notificationId) async {}

  @override
  Future<void> markAllAdminNotificationsRead() async {}

  @override
  Future<int> sendPromoNotification({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 42;

  @override
  Future<String> requestPromoApproval({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 'campaign-1';

  @override
  Future<List<AdminCampaignApprovalItem>> listCampaignApprovals({
    String? status,
    String? campaignType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => const [
    AdminCampaignApprovalItem(
      id: 'campaign-1',
      organizationId: 'org-1',
      organizationName: 'Mobio',
      organizationSlug: 'mobio',
      title: 'Weekend route boost',
      body: 'Promote verified shared trips for Kigali commuters.',
      campaignType: 'promo',
      status: 'pending_approval',
      requestedBy: 'preview-admin',
      requestedByName: 'Ops lead',
      requestedAt: '2026-06-13T08:00:00Z',
    ),
  ];

  @override
  Future<List<AdminNotificationConsentSummary>>
  getNotificationConsentSummary() async => const [
    AdminNotificationConsentSummary(
      organizationId: 'org-1',
      organizationName: 'Mobio',
      eligibleProfileCount: 120,
      promotionalInAppCount: 82,
      promotionalPushCount: 70,
      promotionalAnyCount: 96,
      revokedOrDeniedCount: 8,
    ),
  ];

  @override
  Future<AdminCampaignAudiencePreview> getCampaignAudiencePreview({
    required String campaignId,
  }) async => const AdminCampaignAudiencePreview(
    campaignId: 'campaign-1',
    organizationId: 'org-1',
    eligibleRecipientCount: 120,
    promotionalConsentCount: 96,
    promotionalInAppCount: 82,
    promotionalPushCount: 70,
    revokedOrDeniedCount: 8,
    alreadySentCount: 0,
  );

  @override
  Future<List<AdminAuditLogItem>> listCampaignAuditTimeline({
    required String campaignId,
  }) async => _auditLogs;

  @override
  Future<List<AdminNotificationConsentTrendPoint>> getNotificationConsentTrend({
    int days = 30,
  }) async => const [
    AdminNotificationConsentTrendPoint(
      bucketDate: '2026-06-13',
      grantedCount: 96,
      revokedOrDeniedCount: 8,
      inAppGrantedCount: 82,
      pushGrantedCount: 70,
    ),
  ];

  @override
  Future<void> approveCampaign({
    required String campaignId,
    required bool approved,
    String? notes,
  }) async {}

  @override
  Future<int> sendApprovedCampaign({required String campaignId}) async => 96;

  @override
  Future<int> sendSystemAnnouncement({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 120;

  @override
  Future<int> sendPromo({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 96;

  @override
  Future<int> sendAnnouncement({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 120;

  static const _auditLogs = [
    AdminAuditLogItem(
      id: 'audit-1',
      adminName: 'Platform admin',
      action: 'review_report',
      targetType: 'user_report',
      targetId: 'report-1',
      details: {'status': 'reviewing', 'queue': 'safety'},
      createdAt: '2026-06-13T08:00:00Z',
    ),
    AdminAuditLogItem(
      id: 'audit-2',
      adminName: 'Ops lead',
      action: 'update_user_role',
      targetType: 'profile',
      targetId: 'u1',
      details: {'from': 'passenger', 'to': 'driver'},
      createdAt: '2026-06-12T14:30:00Z',
    ),
  ];

  @override
  Future<List<AdminAuditLogItem>> listAuditLogs({
    String? action,
    String? targetType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => _auditLogs;

  @override
  Future<List<AdminOperationalHealthEventItem>> listOperationalHealthEvents({
    String? status,
    String? severity,
    String? service,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async => const [
    AdminOperationalHealthEventItem(
      id: 'health-1',
      service: 'biopay',
      component: 'aws-face',
      status: 'ok',
      severity: 'info',
      message: 'Face provider responding within threshold.',
      userName: 'System',
      ingestOrigin: 'preview',
      occurredAt: '2026-06-13T08:00:00Z',
    ),
  ];

  @override
  Future<List<AdminUserReportItem>> listUserReports({
    String status = 'open',
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => const [
    AdminUserReportItem(
      id: 'report-1',
      reporterId: 'u1',
      reporterName: 'Chantal Rider',
      reporterPhone: '+250788111222',
      reportedId: 'u2',
      reportedName: 'Jean Driver',
      reportedPhone: '+250788333444',
      conversationId: 'conversation-1',
      tripId: 'trip-1',
      category: 'unsafe_behavior',
      details: 'Driver requested an off-platform payment before pickup.',
      status: 'open',
      createdAt: '2026-06-13T07:30:00Z',
    ),
    AdminUserReportItem(
      id: 'report-2',
      reporterId: 'u3',
      reporterName: 'Patrick Passenger',
      reportedId: 'u4',
      reportedName: 'Aline Driver',
      category: 'route_mismatch',
      details: 'Pickup location changed without confirmation.',
      status: 'resolved',
      resolutionNotes: 'Driver warned and route note updated.',
      createdAt: '2026-06-12T15:00:00Z',
    ),
  ];

  @override
  Future<void> reviewUserReport({
    required String reportId,
    required String status,
    String? notes,
  }) async {}
}
