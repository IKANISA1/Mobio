import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/services/firebase_analytics_service.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';

import 'package:mobi_app/features/admin/admin_broadcasts_screen.dart';
import 'package:mobi_app/features/admin/admin_subscriptions_screen.dart';
import 'package:mobi_app/features/admin/admin_trips_screen.dart';
import 'package:mobi_app/features/admin/admin_vehicle_types_screen.dart';
import 'package:mobi_app/features/biopay/face_enrollment_screen_entry.dart';
import 'package:mobi_app/features/biopay/face_scan_screen_entry.dart';
import 'package:mobi_app/features/biopay/get_qr_screen_entry.dart';
import 'package:mobi_app/features/biopay/scan_qr_screen_entry.dart';
import 'package:mobi_app/features/bookings/trip_details_screen.dart';
import 'package:mobi_app/features/chat/chat_screen.dart';
import 'package:mobi_app/features/profile/edit_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Route name constants for type-safe navigation.
abstract class AppRoutes {
  static const String discover = '/';
  static const String biopay = '/biopay';
  static const String ledger = '/ledger';
  static const String profile = '/profile';
  static const String nearby = '/nearby';
  static const String bookings = '/bookings';
  static const String schedule = '/schedule';
  static const String tripDetails = '/trip/:id';
  static const String chat = '/chat';
  static const String editProfile = '/edit-profile';
  static const String adminAuth = '/admin-auth';
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminProfile = '/admin/profile';
  static const String adminVehicleTypes = '/admin/vehicle-types';
  static const String adminSubscriptions = '/admin/subscriptions';
  static const String adminTrips = '/admin/trips';
  static const String adminBroadcasts = '/admin/broadcasts';
  static const String getQr = '/biopay/qr';
  static const String scanQr = '/biopay/scan';
  static const String faceScan = '/biopay/face-scan';
  static const String faceEnroll = '/biopay/enroll';

  static const String configError = '/config-error';
}

/// Admin route guard — validates role before allowing admin UI.
///
/// Accepts the user as admin if:
///   1. `app_metadata.role == 'admin'` (set by the OTP-backed admin flow), OR
///   2. `AdminSessionGuard.isAdmin` (in-memory session continuity fallback).
///
/// Server-side RPCs still enforce `role = 'admin'` independently.
String? _adminRouteGuard(GoRouterState state) {
  final path = state.matchedLocation;
  final isAdminAuthRoute = path == '/admin-auth';
  final isProtectedAdminRoute = path == '/admin' || path.startsWith('/admin/');
  if (!isAdminAuthRoute && !isProtectedAdminRoute) {
    return null;
  }

  // Check if user has an active session
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return isProtectedAdminRoute ? '/admin-auth' : null;
    }

    final hasAdminRole = user.appMetadata['role'] == 'admin';
    final hasActiveAdminSession = AdminSessionGuard.isAdmin;
    if (hasActiveAdminSession) {
      AdminSessionGuard.touch();
    }

    final hasAdminAccess = hasAdminRole || hasActiveAdminSession;
    if (isAdminAuthRoute) {
      return hasAdminAccess ? '/admin' : null;
    }

    if (hasAdminAccess) {
      return null;
    }

    AppLogger.warning(
      'Admin guard: user ${user.id} lacks admin access, redirecting to /admin-auth',
    );
    return '/admin-auth';
  } on Object catch (e) {
    AppLogger.error('Admin guard check failed: $e');
    return isProtectedAdminRoute ? '/admin-auth' : null;
  }
}

/// Creates the app-level [GoRouter] instance.
GoRouter createRouter() {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  // Wire the navigator key to PushNotificationService so notification taps
  // can trigger in-app navigation.
  PushNotificationService.instance.navigatorKey = rootNavigatorKey;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: FirebaseAnalyticsService.instance.observers,
    initialLocation: SupabaseConfig.isConfigured ? '/' : '/config-error',
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) => _adminRouteGuard(state),
    routes: [
      // ── Config error (no nav bar) ──
      GoRoute(
        path: '/config-error',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ConfigErrorScreen(),
      ),

      // ── Main shell with 3-tab bottom nav ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MobiShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Discover
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreenWrapper(),
              ),
              GoRoute(
                path: '/admin',
                builder: (context, state) => const HomeScreenWrapper(),
              ),
            ],
          ),
          // Tab 1: BioPay
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/biopay',
                builder: (context, state) => const BioPayScreenWrapper(),
              ),
              GoRoute(
                path: '/admin/users',
                builder: (context, state) => const BioPayScreenWrapper(),
              ),
            ],
          ),
          // Tab 2: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreenWrapper(),
              ),
              GoRoute(
                path: '/admin/profile',
                builder: (context, state) => const ProfileScreenWrapper(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-page routes (push over bottom nav) ──
      GoRoute(
        path: '/nearby',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NearbyScreenWrapper(),
      ),
      GoRoute(
        path: '/ledger',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LedgerScreenWrapper(),
      ),
      GoRoute(
        path: '/bookings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BookingsScreenWrapper(),
      ),
      GoRoute(
        path: '/schedule',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ScheduleTripScreenWrapper(),
      ),
      GoRoute(
        path: '/trip/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return TripDetailsScreen(
            tripId: tripId,
            onBack: () => safePop(context),
          );
        },
      ),
      GoRoute(
        path: '/chat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TripChatScreen(
          tripId: state.uri.queryParameters['tripId'],
          peerId: state.uri.queryParameters['peerId'],
          conversationId: state.uri.queryParameters['conversationId'],
          onBack: () => safePop(context),
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            EditProfileScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/admin-auth',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminAuthScreenWrapper(),
      ),
      GoRoute(
        path: '/admin/vehicle-types',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            AdminVehicleTypesScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/admin/subscriptions',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            AdminSubscriptionsScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/admin/trips',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            AdminTripsScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/admin/broadcasts',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            AdminBroadcastsScreen(onBack: () => safePop(context)),
      ),

      // ── BioPay sub-screens ──
      GoRoute(
        path: '/biopay/qr',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            GetQrScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/biopay/scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ScanQrScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/biopay/face-scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            FaceScanScreen(onBack: () => safePop(context)),
      ),

      GoRoute(
        path: '/biopay/enroll',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            FaceEnrollmentScreen(onBack: () => safePop(context)),
      ),
    ],
  );
}
