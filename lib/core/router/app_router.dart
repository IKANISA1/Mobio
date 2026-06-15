import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/router/app_page_transitions.dart';
import 'package:mobi_app/core/router/deferred_route_loader.dart';
import 'package:mobi_app/core/services/firebase_analytics_service.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/features/admin/admin_audit_log_screen.dart'
    deferred as admin_audit_log_route;
import 'package:mobi_app/features/admin/admin_broadcasts_screen.dart'
    deferred as admin_broadcasts_route;
import 'package:mobi_app/features/admin/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/admin_operational_health_screen.dart'
    deferred as admin_health_route;
import 'package:mobi_app/features/admin/admin_reports_screen.dart'
    deferred as admin_reports_route;
import 'package:mobi_app/features/admin/admin_subscriptions_screen.dart'
    deferred as admin_subscriptions_route;
import 'package:mobi_app/features/admin/admin_transport_agencies_screen.dart'
    deferred as admin_transport_agencies_route;
import 'package:mobi_app/features/admin/admin_trips_screen.dart'
    deferred as admin_trips_route;
import 'package:mobi_app/features/admin/admin_users_screen.dart';
import 'package:mobi_app/features/admin/admin_vehicle_types_screen.dart'
    deferred as admin_vehicle_types_route;
import 'package:mobi_app/features/biopay/biopay_admin_console_screen.dart'
    deferred as biopay_admin_route;
import 'package:mobi_app/features/biopay/biopay_face_enroll_screen.dart'
    deferred as biopay_face_enroll_route;
import 'package:mobi_app/features/biopay/biopay_face_scan_screen.dart'
    deferred as biopay_face_scan_route;
import 'package:mobi_app/features/biopay/biopay_home_screen.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_screen.dart'
    deferred as biopay_nfc_route;
import 'package:mobi_app/features/biopay/biopay_nfc_write_card_screen.dart'
    deferred as biopay_nfc_write_card_route;
import 'package:mobi_app/features/biopay/biopay_qr_screen.dart'
    deferred as biopay_qr_route;
import 'package:mobi_app/features/biopay/biopay_scan_screen.dart'
    deferred as biopay_scan_route;
import 'package:mobi_app/features/bookings/trip_details_screen.dart'
    deferred as trip_details_route;
import 'package:mobi_app/features/chat/chat_screen.dart' deferred as chat_route;
import 'package:mobi_app/features/profile/driver_plus_screen.dart';
import 'package:mobi_app/features/profile/edit_profile_screen.dart'
    deferred as edit_profile_route;
import 'package:mobi_app/features/profile/wallet_screen.dart';
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
  static const String wallet = '/wallet';
  static const String mobioPlus = '/mobio-plus';
  static const String profileSetup = '/profile/setup';
  static const String adminAuth = '/admin-auth';
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminProfile = '/admin/profile';
  static const String adminVehicleTypes = '/admin/vehicle-types';
  static const String adminAgencies = '/admin/agencies';
  static const String adminSubscriptions = '/admin/subscriptions';
  static const String adminTrips = '/admin/trips';
  static const String adminReports = '/admin/reports';
  static const String adminBioPayOps = '/admin/biopay';
  @Deprecated('Use adminBioPayOps. Kept as a redirect for old admin links.')
  static const String adminFinance = '/admin/finance';
  static const String adminHealth = '/admin/health';
  static const String adminAudit = '/admin/audit';
  static const String adminBroadcasts = '/admin/broadcasts';
  static const String getQr = '/biopay/qr';
  static const String scanQr = '/biopay/scan';
  static const String faceScan = '/biopay/face-scan';
  static const String faceEnroll = '/biopay/enroll';
  static const String nfc = '/biopay/nfc';
  static const String nfcWriteCard = '/biopay/nfc/write-card';

  static const String configError = '/config-error';
}

void _safePopToProfile(BuildContext context) {
  context.go(AppRoutes.profile);
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
        pageBuilder: (context, state) =>
            mobiRoutePage(state, const ConfigErrorScreen()),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          WhatsAppLoginScreenWrapper(
            redirectTo: state.uri.queryParameters['redirect'],
          ),
        ),
      ),

      // ── Main shell with bottom nav ──
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
          // Tab 2: BioPay
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/biopay',
                builder: (context, state) => BioPayScreen(
                  onQr: () => context.push('/biopay/qr'),
                  onScan: () => context.push('/biopay/scan'),
                  onFace: () => context.push('/biopay/face-scan'),
                  onNfc: () => context.push('/biopay/nfc'),
                ),
              ),
              GoRoute(
                path: '/admin/biopay',
                builder: (context, state) => DeferredRouteLoader(
                  loadLibrary: biopay_admin_route.loadLibrary,
                  builder: (context) =>
                      biopay_admin_route.BioPayAdminConsoleScreen(),
                ),
              ),
              GoRoute(
                path: '/admin/finance',
                redirect: (context, state) => '/admin/biopay',
              ),
            ],
          ),
          // Tab 3: Profile
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
        pageBuilder: (context, state) =>
            mobiRoutePage(state, const NearbyScreenWrapper()),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            mobiRoutePage(state, const NotificationsScreenWrapper()),
      ),
      GoRoute(
        path: '/ledger',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          ScopeUnavailableScreen(onBack: () => safePop(context)),
        ),
      ),
      GoRoute(
        path: '/schedule',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            mobiRoutePage(state, const ScheduleTripScreenWrapper()),
      ),
      GoRoute(
        path: '/trip/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return mobiRoutePage(
            state,
            EditTripScreenWrapper(
              tripId: tripId,
              onBack: () => safePop(context),
            ),
          );
        },
      ),
      GoRoute(
        path: '/trip/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return mobiRoutePage(
            state,
            DeferredRouteLoader(
              loadLibrary: trip_details_route.loadLibrary,
              builder: (context) => trip_details_route.TripDetailsScreen(
                tripId: tripId,
                onBack: () => safePop(context),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/chat',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: chat_route.loadLibrary,
            builder: (context) => chat_route.TripChatScreen(
              tripId: state.uri.queryParameters['tripId'],
              peerId: state.uri.queryParameters['peerId'],
              conversationId: state.uri.queryParameters['conversationId'],
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: edit_profile_route.loadLibrary,
            builder: (context) => edit_profile_route.EditProfileScreen(
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/wallet',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          WalletScreen(onBack: () => _safePopToProfile(context)),
        ),
      ),
      GoRoute(
        path: '/mobio-plus',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DriverPlusScreen(onBack: () => _safePopToProfile(context)),
        ),
      ),
      GoRoute(
        path: '/profile/setup',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: edit_profile_route.loadLibrary,
            builder: (context) => edit_profile_route.EditProfileScreen(
              isFirstRun: true,
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin-auth',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            mobiRoutePage(state, const AdminAuthScreenWrapper()),
      ),
      GoRoute(
        path: '/admin/vehicle-types',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: admin_vehicle_types_route.loadLibrary,
            builder: (context) =>
                admin_vehicle_types_route.AdminVehicleTypesScreen(
                  onBack: () => safePop(context),
                ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/agencies',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: admin_transport_agencies_route.loadLibrary,
            builder: (context) =>
                admin_transport_agencies_route.AdminTransportAgenciesScreen(
                  onBack: () => safePop(context),
                ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/subscriptions',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: admin_subscriptions_route.loadLibrary,
            builder: (context) =>
                admin_subscriptions_route.AdminSubscriptionsScreen(
                  onBack: () => safePop(context),
                ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/trips',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: admin_trips_route.loadLibrary,
            builder: (context) => admin_trips_route.AdminTripsScreen(
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/reports',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: admin_reports_route.loadLibrary,
            builder: (context) => admin_reports_route.AdminReportsScreen(
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/health',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: admin_health_route.loadLibrary,
            builder: (context) =>
                admin_health_route.AdminOperationalHealthScreen(
                  onBack: () => safePop(context),
                ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/audit',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: admin_audit_log_route.loadLibrary,
            builder: (context) => admin_audit_log_route.AdminAuditLogScreen(
              onBack: () => safePop(context),
              initialSearch: state.uri.queryParameters['search'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/broadcasts',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: admin_broadcasts_route.loadLibrary,
            builder: (context) => admin_broadcasts_route.AdminBroadcastsScreen(
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),

      GoRoute(
        path: '/biopay/qr',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: biopay_qr_route.loadLibrary,
            builder: (context) =>
                biopay_qr_route.BioPayQrScreen(onBack: () => safePop(context)),
          ),
        ),
      ),
      GoRoute(
        path: '/biopay/scan',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: biopay_scan_route.loadLibrary,
            builder: (context) => biopay_scan_route.BioPayScanScreen(
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/biopay/face-scan',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: biopay_face_scan_route.loadLibrary,
            builder: (context) => biopay_face_scan_route.BioPayFaceScanScreen(
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/biopay/enroll',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: biopay_face_enroll_route.loadLibrary,
            builder: (context) =>
                biopay_face_enroll_route.BioPayFaceEnrollScreen(
                  onBack: () => safePop(context),
                ),
          ),
        ),
      ),
      GoRoute(
        path: '/biopay/nfc',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: biopay_nfc_route.loadLibrary,
            builder: (context) => biopay_nfc_route.BioPayNfcScreen(
              onBack: () => safePop(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/biopay/nfc/write-card',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => mobiRoutePage(
          state,
          DeferredRouteLoader(
            loadLibrary: biopay_nfc_write_card_route.loadLibrary,
            builder: (context) =>
                biopay_nfc_write_card_route.BioPayNfcWriteCardScreen(
                  onBack: () => safePop(context),
                ),
          ),
        ),
      ),
    ],
  );
}
