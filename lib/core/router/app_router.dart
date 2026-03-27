import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/biopay/face_enrollment_screen.dart';
import 'package:mobi_app/features/biopay/biopay_privacy_screen.dart';
import 'package:mobi_app/features/biopay/face_registration_screen.dart';
import 'package:mobi_app/features/biopay/face_scan_screen.dart';
import 'package:mobi_app/features/biopay/get_qr_screen.dart';
import 'package:mobi_app/features/biopay/scan_qr_screen.dart';
import 'package:mobi_app/features/bookings/trip_details_screen.dart';
import 'package:mobi_app/features/chat/chat_screen.dart';
import 'package:mobi_app/features/profile/edit_profile_screen.dart';

/// Route name constants for type-safe navigation.
abstract class AppRoutes {
  static const String discover = '/';
  static const String biopay = '/biopay';
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
  static const String getQr = '/biopay/qr';
  static const String scanQr = '/biopay/scan';
  static const String faceScan = '/biopay/face-scan';
  static const String faceRegister = '/biopay/register';
  static const String faceEnroll = '/biopay/enroll';
  static const String biopayPrivacy = '/biopay/privacy';
  static const String configError = '/config-error';
}

/// Safely pops — falls back to root if nothing to pop.
void _safePop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

/// Creates the app-level [GoRouter] instance.
GoRouter createRouter() {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: SupabaseConfig.isConfigured ? '/' : '/config-error',
    errorBuilder: (context, state) => const NotFoundScreen(),
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
            onBack: () => _safePop(context),
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
          onBack: () => _safePop(context),
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            EditProfileScreen(onBack: () => _safePop(context)),
      ),
      GoRoute(
        path: '/admin-auth',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminAuthScreenWrapper(),
      ),

      // ── BioPay sub-screens ──
      GoRoute(
        path: '/biopay/qr',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            GetQrScreen(onBack: () => _safePop(context)),
      ),
      GoRoute(
        path: '/biopay/scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ScanQrScreen(onBack: () => _safePop(context)),
      ),
      GoRoute(
        path: '/biopay/face-scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            FaceScanScreen(onBack: () => _safePop(context)),
      ),
      GoRoute(
        path: '/biopay/register',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => FaceRegistrationScreen(
          onBack: () => _safePop(context),
          onEnroll: () => context.push('/biopay/enroll'),
          onPrivacyCenter: () => context.push('/biopay/privacy'),
        ),
      ),
      GoRoute(
        path: '/biopay/enroll',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            FaceEnrollmentScreen(onBack: () => _safePop(context)),
      ),
      GoRoute(
        path: '/biopay/privacy',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            BiopayPrivacyScreen(onBack: () => _safePop(context)),
      ),
    ],
  );
}
