import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/features/admin/admin_auth_screen.dart';
import 'package:mobi_app/features/admin/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/admin_users_screen.dart';
import 'package:mobi_app/features/biopay/biopay_screen.dart';
import 'package:mobi_app/features/bookings/bookings_screen.dart';
import 'package:mobi_app/features/bookings/schedule_trip_screen.dart';
import 'package:mobi_app/features/home/home_screen.dart';
import 'package:mobi_app/features/nearby/nearby_screen.dart';
import 'package:mobi_app/features/profile/profile_screen.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/providers/app_providers.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// _safePop is provided by core/utils/navigation_utils.dart (safePop)

String _chatPathForTrip(Trip trip) {
  final query = <String, String>{'peerId': trip.authorId};

  if (trip.id != null && trip.id!.isNotEmpty && trip.id != trip.authorId) {
    query['tripId'] = trip.id!;
  }

  return Uri(path: '/chat', queryParameters: query).toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// MobiShell — Bottom nav shell for StatefulShellRoute
// ─────────────────────────────────────────────────────────────────────────────

/// Main app shell with 3-tab navigation: Discover / BioPay / Profile.
/// Used as the [StatefulShellRoute] builder. Sub-screens push via
/// the root navigator and appear over the bottom nav.
class MobiShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MobiShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MobiShell> createState() => _MobiShellState();
}

class _MobiShellState extends ConsumerState<MobiShell> {
  // ─── Notifications ───
  final NotificationService? _notificationService = SupabaseConfig.isConfigured
      ? NotificationService()
      : null;
  final ProfileService _profileService = ProfileService();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    _syncNotificationListener();
    unawaited(_syncRoleFromSession());
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      _syncNotificationListener();
      unawaited(_syncRoleFromSession());
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _notificationService?.dispose();
    super.dispose();
  }

  Future<void> _syncRoleFromSession() async {
    if (!mounted || !SupabaseConfig.isConfigured) {
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      ref.read(roleProvider.notifier).set('passenger');
      return;
    }

    final profile = await _profileService.getMyProfile();
    if (!mounted) {
      return;
    }

    ref
        .read(roleProvider.notifier)
        .set(profile?['role'] == 'admin' ? 'admin' : 'passenger');
  }

  void _syncNotificationListener() {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    _notificationService?.stopListening();
    if (currentUser != null) {
      _notificationService?.startListening();
      // Re-register FCM token for push notifications on auth change
      unawaited(PushNotificationService.instance.registerToken());
    } else {
      // User signed out — unregister device token
      unawaited(PushNotificationService.instance.unregisterToken());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = ref.watch(roleProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Content — SafeArea keeps headers below the status bar
          SafeArea(
            bottom: false,
            // StatefulNavigationShell owns branch navigator keys. Keeping it
            // mounted exactly once avoids duplicate GlobalKey assertions during
            // tab switches and hot reload.
            child: widget.navigationShell,
          ),

          // Bottom nav
          MobiBottomNav(
            currentIndex: widget.navigationShell.currentIndex,
            isAdmin: role == 'admin',
            onTap: (i) => widget.navigationShell.goBranch(
              i,
              initialLocation: i == widget.navigationShell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper widgets — bridge GoRouter ↔ existing screen widgets via Riverpod
// ─────────────────────────────────────────────────────────────────────────────

/// Discover tab wrapper — passes shell state to [HomeScreen].
class HomeScreenWrapper extends ConsumerWidget {
  const HomeScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    if (role == 'admin') {
      return const AdminDashboardScreen();
    }

    final mode = ref.watch(modeProvider);
    return HomeScreen(
      mode: mode,
      onModeChanged: (m) => ref.read(modeProvider.notifier).set(m),
      onChat: (t) => context.push(_chatPathForTrip(t)),
      onViewNearby: () => context.push('/nearby'),
      onViewBookings: () => context.push('/bookings'),
      onSchedule: () => context.push('/schedule'),
    );
  }
}

/// BioPay tab wrapper.
class BioPayScreenWrapper extends ConsumerWidget {
  const BioPayScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    if (role == 'admin') {
      return const AdminUsersScreen();
    }

    return BioPayScreen(
      onGetQR: () => context.push('/biopay/qr'),
      onScanQR: () => context.push('/biopay/scan'),
      onFaceScan: () => context.push('/biopay/face-scan'),
      onPrivacyCenter: () => context.push('/biopay/privacy'),
      onManage: () => context.push('/edit-profile'),
      onEnroll: () => context.push('/biopay/enroll'),
    );
  }
}

/// Profile tab wrapper.
class ProfileScreenWrapper extends ConsumerWidget {
  const ProfileScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final themeProvider = ref.read(themeProviderProvider);
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) => ProfileScreen(
        isDarkMode: themeProvider.isDark,
        onDarkModeChanged: themeProvider.setDarkMode,
        onEditProfile: () => context.push('/edit-profile'),
        onPrivacyCenter: () => context.push('/biopay/privacy'),
        onAdminGateway: () => context.push('/admin-auth'),
        onFaceRegister: () => context.push('/biopay/register'),
        onExitAdmin: role == 'admin'
            ? () {
                ref.read(roleProvider.notifier).set('passenger');
                context.go(
                  '/profile',
                ); // Intentional: clear stack on exit admin
              }
            : null,
      ),
    );
  }
}

/// Admin auth screen wrapper.
class AdminAuthScreenWrapper extends ConsumerWidget {
  const AdminAuthScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminAuthScreen(
      onBack: () => safePop(context),
      onSuccess: () {
        ref.read(roleProvider.notifier).set('admin');
        context.go('/admin'); // Intentional: clear stack on admin success
      },
    );
  }
}

/// Nearby screen wrapper.
class NearbyScreenWrapper extends ConsumerWidget {
  const NearbyScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: NearbyScreen(
          onChat: (t) => context.push(_chatPathForTrip(t)),
          onBack: () => safePop(context),
        ),
      ),
    );
  }
}

/// Bookings screen wrapper.
class BookingsScreenWrapper extends ConsumerWidget {
  const BookingsScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: BookingsScreen(
          mode: mode,
          onModeChanged: (m) => ref.read(modeProvider.notifier).set(m),
          onSchedule: () => context.push('/schedule'),
          onTripDetails: (id) => context.push('/trip/$id'),
          onBack: () => safePop(context),
        ),
      ),
    );
  }
}

/// Schedule trip screen wrapper.
class ScheduleTripScreenWrapper extends ConsumerWidget {
  const ScheduleTripScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);
    return ScheduleTripScreen(
      mode: mode,
      onModeChanged: (m) => ref.read(modeProvider.notifier).set(m),
      onBack: () => safePop(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Config error screen
// ─────────────────────────────────────────────────────────────────────────────

class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ext.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unable to start Mobio',
                    style: AppTypography.headlineLg.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This APK was built without SUPABASE_URL and SUPABASE_ANON_KEY.',
                    style: AppTypography.bodyLg.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rebuild the app with --dart-define values for both keys '
                    'before running device UAT.',
                    style: AppTypography.bodyMd.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 404 Not Found screen
// ─────────────────────────────────────────────────────────────────────────────

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '404',
                  style: AppTypography.heroNumber.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Page not found',
                  style: AppTypography.titleLg.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 24),
                MobiButton(
                  variant: MobiButtonVariant.ghost,
                  onPressed: () => context.go('/'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
