import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobi_app/core/services/admin/admin_broadcast_service.dart';
import 'package:mobi_app/core/services/admin/admin_compliance_service.dart';
import 'package:mobi_app/core/services/admin/admin_dashboard_service.dart';
import 'package:mobi_app/core/services/admin/admin_trip_service.dart';
import 'package:mobi_app/core/services/admin/admin_user_service.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/biopay_service.dart';
import 'package:mobi_app/core/services/chat_ai_service.dart';
import 'package:mobi_app/core/services/chat_service.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/services/favorite_address_service.dart';
import 'package:mobi_app/core/services/firebase_analytics_service.dart';
import 'package:mobi_app/core/services/firebase_auth_service.dart';
import 'package:mobi_app/core/services/firebase_remote_config_service.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:mobi_app/core/services/notification_consent_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/services/places_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/services/ride_request_service.dart';
import 'package:mobi_app/core/services/subscription_plan_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/core/services/whatsapp_login_service.dart';
import 'package:mobi_app/features/payments/services/payment_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Dependency Injection container for all services

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final adminServiceProvider = Provider(
  (ref) => AdminService(
    supabase: ref.read(supabaseClientProvider),
    dashboardService: ref.read(adminDashboardServiceProvider),
    userService: ref.read(adminUserServiceProvider),
    tripService: ref.read(adminTripServiceProvider),
    broadcastService: ref.read(adminBroadcastServiceProvider),
    complianceService: ref.read(adminComplianceServiceProvider),
  ),
);

final adminDashboardServiceProvider = Provider(
  (ref) => AdminDashboardService(supabase: ref.read(supabaseClientProvider)),
);

final adminUserServiceProvider = Provider(
  (ref) => AdminUserService(supabase: ref.read(supabaseClientProvider)),
);

final adminTripServiceProvider = Provider(
  (ref) => AdminTripService(supabase: ref.read(supabaseClientProvider)),
);

final adminBroadcastServiceProvider = Provider(
  (ref) => AdminBroadcastService(supabase: ref.read(supabaseClientProvider)),
);

final adminComplianceServiceProvider = Provider(
  (ref) => AdminComplianceService(supabase: ref.read(supabaseClientProvider)),
);
final appPermissionServiceProvider = Provider((ref) => AppPermissionService());
final bioPayServiceProvider = Provider((ref) => BioPayService());
final chatAiServiceProvider = Provider(
  (ref) => ChatAiService(supabase: ref.read(supabaseClientProvider)),
);
final chatServiceProvider = Provider(
  (ref) => ChatService(supabase: ref.read(supabaseClientProvider)),
);
final countryServiceProvider = Provider(
  (ref) => CountryService(supabase: ref.read(supabaseClientProvider)),
);
final driverLocationServiceProvider = Provider(
  (ref) => DriverLocationService(supabase: ref.read(supabaseClientProvider)),
);
final firebaseAnalyticsServiceProvider = Provider(
  (ref) => FirebaseAnalyticsService.instance,
);
final firebaseAuthServiceProvider = Provider(
  (ref) => FirebaseAuthService.instance,
);
final firebaseRemoteConfigServiceProvider = Provider(
  (ref) => FirebaseRemoteConfigService.instance,
);
final favoriteAddressServiceProvider = Provider(
  (ref) => FavoriteAddressService(supabase: ref.read(supabaseClientProvider)),
);
final locationServiceProvider = Provider((ref) => LocationService());
final notificationServiceProvider = Provider(
  (ref) => NotificationService(supabase: ref.read(supabaseClientProvider)),
);
final notificationConsentServiceProvider = Provider(
  (ref) =>
      NotificationConsentService(supabase: ref.read(supabaseClientProvider)),
);
final placesServiceProvider = Provider(
  (ref) => PlacesService(supabase: ref.read(supabaseClientProvider)),
);
final paymentServiceProvider = Provider((ref) => const PaymentService());
final profileServiceProvider = Provider(
  (ref) => ProfileService(supabase: ref.read(supabaseClientProvider)),
);
final pushNotificationServiceProvider = Provider(
  (ref) => PushNotificationService.instance,
);
final rideRequestServiceProvider = Provider(
  (ref) => RideRequestService(supabase: ref.read(supabaseClientProvider)),
);
final subscriptionPlanServiceProvider = Provider(
  (ref) => SubscriptionPlanService(supabase: ref.read(supabaseClientProvider)),
);
final tripServiceProvider = Provider(
  (ref) => TripService(supabase: ref.read(supabaseClientProvider)),
);
final vehicleTypeServiceProvider = Provider(
  (ref) => VehicleTypeService(supabase: ref.read(supabaseClientProvider)),
);
final whatsappLoginServiceProvider = Provider((ref) => WhatsAppLoginService());
