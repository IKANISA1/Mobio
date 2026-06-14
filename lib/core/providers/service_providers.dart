import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/services/admin/admin_broadcast_service.dart';
import 'package:mobi_app/core/services/admin/admin_compliance_service.dart';
import 'package:mobi_app/core/services/admin/admin_dashboard_service.dart';
import 'package:mobi_app/core/services/admin/admin_trip_service.dart';
import 'package:mobi_app/core/services/admin/admin_user_service.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/biopay_admin_service.dart';
import 'package:mobi_app/core/services/biopay_face_service.dart';
import 'package:mobi_app/core/services/biopay_ussd_service.dart';
import 'package:mobi_app/core/services/chat_service.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/services/driver_location_sharing_service.dart';
import 'package:mobi_app/core/services/driver_plus_service.dart';
import 'package:mobi_app/core/services/favorite_address_service.dart';
import 'package:mobi_app/core/services/firebase_analytics_service.dart';
import 'package:mobi_app/core/services/firebase_auth_service.dart';
import 'package:mobi_app/core/services/firebase_remote_config_service.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:mobi_app/core/services/notification_consent_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/services/places_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/services/public_transport_service.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/services/referral_attribution_service.dart';
import 'package:mobi_app/core/services/referral_service.dart';
import 'package:mobi_app/core/services/subscription_plan_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/core/services/wallet_service.dart';
import 'package:mobi_app/core/services/whatsapp_login_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Dependency Injection container for all services

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Supabase client is unavailable because Supabase is not configured.',
    );
  }
  return Supabase.instance.client;
});

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
final biopayUssdServiceProvider = Provider(
  (ref) => BioPayUssdService(
    supabase: SupabaseConfig.isConfigured
        ? ref.read(supabaseClientProvider)
        : null,
  ),
);
final biopayAdminServiceProvider = Provider(
  (ref) => BioPayAdminService(
    supabase: SupabaseConfig.isConfigured
        ? ref.read(supabaseClientProvider)
        : null,
    faceService: ref.read(biopayFaceServiceProvider),
  ),
);
final biopayFaceServiceProvider = Provider(
  (ref) => BioPayFaceService(
    supabase: SupabaseConfig.isConfigured
        ? ref.read(supabaseClientProvider)
        : null,
  ),
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
final driverLocationSharingServiceProvider = Provider(
  (ref) => DriverLocationSharingService(
    locationService: ref.read(locationServiceProvider),
    driverLocationService: ref.read(driverLocationServiceProvider),
    profileService: ref.read(profileServiceProvider),
  ),
);
final driverPlusServiceProvider = Provider(
  (ref) => DriverPlusService(supabase: ref.read(supabaseClientProvider)),
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
final locationServiceProvider = Provider(
  (ref) => LocationService(
    permissionService: ref.read(appPermissionServiceProvider),
  ),
);
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
final profileServiceProvider = Provider(
  (ref) => ProfileService(supabase: ref.read(supabaseClientProvider)),
);
final publicTransportServiceProvider = Provider(
  (ref) => PublicTransportService(supabase: ref.read(supabaseClientProvider)),
);
final pushNotificationServiceProvider = Provider(
  (ref) => PushNotificationService.instance,
);
final referralServiceProvider = Provider(
  (ref) => ReferralService(supabase: ref.read(supabaseClientProvider)),
);
final referralAttributionServiceProvider = Provider(
  (ref) => ReferralAttributionService(
    referralService: ref.read(referralServiceProvider),
  ),
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
final walletServiceProvider = Provider(
  (ref) => WalletService(supabase: ref.read(supabaseClientProvider)),
);
final whatsappLoginServiceProvider = Provider((ref) => WhatsAppLoginService());
