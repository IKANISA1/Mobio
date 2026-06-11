import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/services/firebase_analytics_service.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';

import 'package:mobi_app/features/admin/admin_audit_log_screen.dart';
import 'package:mobi_app/features/admin/admin_broadcasts_screen.dart';
import 'package:mobi_app/features/admin/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/admin_operational_health_screen.dart';
import 'package:mobi_app/features/admin/admin_reports_screen.dart';
import 'package:mobi_app/features/admin/admin_subscriptions_screen.dart';
import 'package:mobi_app/features/admin/admin_trips_screen.dart';
import 'package:mobi_app/features/admin/admin_users_screen.dart';
import 'package:mobi_app/features/admin/admin_vehicle_types_screen.dart';
import 'package:mobi_app/features/bookings/trip_details_screen.dart';
import 'package:mobi_app/features/chat/chat_screen.dart';
import 'package:mobi_app/features/profile/edit_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Route name constants for type-safe navigation.
abstract class AppRoutes {
  static const String discover = '/';
  static const String login = '/login';
  static const String biopay = '/biopay';
  static const String ledger = '/ledger';
  static const String profile = '/profile';
  static const String nearby = '/nearby';
  static const String bookings = '/bookings';
  static const String schedule = '/schedule';
  static const String tripDetails = '/trip/:id';
  static const String tripEdit = '/trip/:id/edit';
  static const String chat = '/chat';
  static const String editProfile = '/edit-profile';
  static const String profileSetup = '/profile/setup';
  static const String adminAuth = '/admin-auth';
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminProfile = '/admin/profile';
  static const String adminVehicleTypes = '/admin/vehicle-types';
  static const String adminSubscriptions = '/admin/subscriptions';
  static const String adminTrips = '/admin/trips';
  static const String adminReports = '/admin/reports';
  static const String adminFinance = '/admin/finance';
  static const String adminHealth = '/admin/health';
  static const String adminAudit = '/admin/audit';
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

  if (!SupabaseConfig.isConfigured) {
    return isProtectedAdminRoute ? AppRoutes.discover : null;
  }

  // Check if user has an active session
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return isProtectedAdminRoute ? '/admin-auth' : null;
    }

    final hasAdminRole = user.appMetadata['role'] == 'admin';
    final hasActiveAdminSession = AdminSessionGuard.isAdminFor(user.id);
    if (hasActiveAdminSession) {
      AdminSessionGuard.touch(user.id);
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

bool _hasVerifiedWhatsAppSession() {
  if (!SupabaseConfig.isConfigured) {
    return false;
  }

  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return false;
    }

    final provider = user.appMetadata['provider'];
    final role = user.appMetadata['role'];
    return provider == 'whatsapp_cloud_otp' ||
        provider == 'admin_whatsapp_otp' ||
        role == 'admin';
  } on Object catch (e) {
    AppLogger.error('App auth guard check failed: $e');
    return false;
  }
}

String _loginLocationFor(GoRouterState state) {
  return Uri(
    path: AppRoutes.login,
    queryParameters: {'redirect': state.uri.toString()},
  ).toString();
}

String _safeRedirectTarget(String? raw) {
  if (raw == null || raw.isEmpty) {
    return AppRoutes.discover;
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    return AppRoutes.discover;
  }

  final target = uri.toString();
  if (!target.startsWith('/') ||
      target.startsWith('//') ||
      target == AppRoutes.login ||
      target.startsWith('${AppRoutes.login}?')) {
    return AppRoutes.discover;
  }

  return target;
}

String? _appRouteGuard(GoRouterState state) {
  if (!SupabaseConfig.isConfigured) {
    return null;
  }

  final path = state.matchedLocation;
  if (path == AppRoutes.configError || path == AppRoutes.adminAuth) {
    return null;
  }

  final isProtectedAdminRoute =
      path == AppRoutes.adminDashboard || path.startsWith('/admin/');
  if (isProtectedAdminRoute) {
    return null;
  }

  final isLoginRoute = path == AppRoutes.login;
  final hasVerifiedSession = _hasVerifiedWhatsAppSession();
  if (isLoginRoute) {
    return hasVerifiedSession
        ? _safeRedirectTarget(state.uri.queryParameters['redirect'])
        : null;
  }

  return hasVerifiedSession ? null : _loginLocationFor(state);
}

class _SupabaseAuthRefreshListenable extends ChangeNotifier {
  StreamSubscription<AuthState>? _subscription;

  _SupabaseAuthRefreshListenable() {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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
    initialLocation: SupabaseConfig.shouldShowConfigError
        ? AppRoutes.configError
        : AppRoutes.discover,
    errorBuilder: (context, state) => const NotFoundScreen(),
    refreshListenable: _SupabaseAuthRefreshListenable(),
    redirect: (context, state) =>
        _adminRouteGuard(state) ?? _appRouteGuard(state),
    routes: [
      // ── Config error (no nav bar) ──
      GoRoute(
        path: '/config-error',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ConfigErrorScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => WhatsAppLoginScreenWrapper(
          redirectTo: state.uri.queryParameters['redirect'],
        ),
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
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          // Tab 1: scheduled trip posts
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const BookingsScreenWrapper(),
              ),
              GoRoute(
                path: '/admin/users',
                builder: (context, state) => const AdminUsersScreen(),
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
        builder: (context, state) =>
            ScopeUnavailableScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/schedule',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ScheduleTripScreenWrapper(),
      ),
      GoRoute(
        path: '/trip/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return EditTripScreenWrapper(
            tripId: tripId,
            onBack: () => safePop(context),
          );
        },
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
        path: '/profile/setup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            EditProfileScreen(isFirstRun: true, onBack: () => safePop(context)),
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
        path: '/admin/reports',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            AdminReportsScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/admin/finance',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ScopeUnavailableScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/admin/health',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            AdminOperationalHealthScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/admin/audit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AdminAuditLogScreen(
          onBack: () => safePop(context),
          initialSearch: state.uri.queryParameters['search'],
        ),
      ),
      GoRoute(
        path: '/admin/broadcasts',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            AdminBroadcastsScreen(onBack: () => safePop(context)),
      ),

      // ── Legacy payment/BioPay routes kept explicit but inactive ──
      GoRoute(
        path: '/biopay',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ScopeUnavailableScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/biopay/qr',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ScopeUnavailableScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/biopay/scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ScopeUnavailableScreen(onBack: () => safePop(context)),
      ),
      GoRoute(
        path: '/biopay/face-scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ScopeUnavailableScreen(onBack: () => safePop(context)),
      ),

      GoRoute(
        path: '/biopay/enroll',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ScopeUnavailableScreen(onBack: () => safePop(context)),
      ),
    ],
  );
}
