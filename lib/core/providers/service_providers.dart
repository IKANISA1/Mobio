import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/biopay_service.dart';
import 'package:mobi_app/core/services/chat_ai_service.dart';
import 'package:mobi_app/core/services/chat_service.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/services/firebase_analytics_service.dart';
import 'package:mobi_app/core/services/firebase_auth_service.dart';
import 'package:mobi_app/core/services/firebase_remote_config_service.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/services/places_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/services/ride_request_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';

/// Centralized Dependency Injection container for all services

final adminServiceProvider = Provider((ref) => AdminService());
final appPermissionServiceProvider = Provider((ref) => AppPermissionService());
final bioPayServiceProvider = Provider((ref) => BioPayService());
final chatAiServiceProvider = Provider((ref) => ChatAiService());
final chatServiceProvider = Provider((ref) => ChatService());
final countryServiceProvider = Provider((ref) => CountryService());
final driverLocationServiceProvider = Provider(
  (ref) => DriverLocationService(),
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
final locationServiceProvider = Provider((ref) => LocationService());
final notificationServiceProvider = Provider((ref) => NotificationService());
final placesServiceProvider = Provider((ref) => PlacesService());
final profileServiceProvider = Provider((ref) => ProfileService());
final pushNotificationServiceProvider = Provider(
  (ref) => PushNotificationService.instance,
);
final rideRequestServiceProvider = Provider((ref) => RideRequestService());
final tripServiceProvider = Provider((ref) => TripService());
final vehicleTypeServiceProvider = Provider((ref) => VehicleTypeService());
