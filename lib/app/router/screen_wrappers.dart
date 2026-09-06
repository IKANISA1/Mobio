import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/auth/supabase_session_service.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/features/admin/presentation/admin_auth_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:mobi_app/features/auth/presentation/whatsapp_login_screen.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/schedule_trip_screen.dart';
import 'package:mobi_app/features/ev_chargers/presentation/ev_charger_locator_screen.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/features/nearby/application/nearby_providers.dart';
import 'package:mobi_app/features/nearby/presentation/nearby_screen.dart';
import 'package:mobi_app/features/notifications/presentation/notifications_screen.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/presentation/profile_screen.dart';
import 'package:mobi_app/shared/widgets/platform_feature_notice_screen.dart';
import 'package:mobi_shared_types/models/trip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route helpers
// ─────────────────────────────────────────────────────────────────────────────

String chatPathForTrip(Trip trip) {
  final query = <String, String>{'peerId': trip.authorId};

  if (trip.id != null && trip.id!.isNotEmpty && trip.id != trip.authorId) {
    query['tripId'] = trip.id!;
  }

  return Uri(path: '/chat', queryParameters: query).toString();
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
    if (role.isAdmin) {
      return const AdminDashboardScreen();
    }

    final mode = ref.watch(modeProvider);
    return HomeScreen(
      mode: mode.value,
      onModeChanged: (m) =>
          ref.read(modeProvider.notifier).set(AppMode.fromString(m)),
      onChat: (t) => context.push(chatPathForTrip(t)),
      onViewNearby: () => context.push('/nearby'),
      onViewBookings: () => context.go('/bookings'),
      onSchedule: () => context.push('/schedule'),
      onEvChargers: () => context.push('/ev-chargers'),
      onNotifications: () => context.push('/notifications'),
    );
  }
}

class EvChargerLocatorScreenWrapper extends StatelessWidget {
  const EvChargerLocatorScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return EvChargerLocatorScreen(onBack: () => safePop(context));
  }
}

/// In-app notification inbox.
class NotificationsScreenWrapper extends ConsumerWidget {
  const NotificationsScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationsScreen(onBack: () => safePop(context));
  }
}

/// Profile tab wrapper.
class ProfileScreenWrapper extends ConsumerWidget {
  const ProfileScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final themeProvider = ref.read(themeProviderProvider);
    void handleExitAdmin() {
      unawaited(_exitAdminSession(context, ref));
    }

    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) => ProfileScreen(
        isDarkMode: themeProvider.isDark,
        onDarkModeChanged: themeProvider.setDarkMode,
        onEditProfile: () => context.push('/edit-profile'),
        onWallet: () => context.push('/wallet'),
        onInviteAndEarn: () => context.push('/wallet'),
        onMobioPlus: () => context.push('/mobio-plus'),
        onBioPayEnroll: () => context.push('/biopay/enroll'),
        onNfcWriteCard: () => context.push('/biopay/nfc/write-card'),
        onAdminGateway: () => context.push('/admin-auth'),
        onExitAdmin: role.isAdmin ? handleExitAdmin : null,
      ),
    );
  }
}

Future<void> _exitAdminSession(BuildContext context, WidgetRef ref) async {
  AdminSessionGuard.revoke();
  ref.read(roleProvider.notifier).set(AppRole.passenger);
  await SupabaseSessionService.signOutToAnonymous(
    beforeSignOut: () => ref.read(driverLocationSharingServiceProvider).stop(),
  );
  if (!context.mounted) {
    return;
  }

  context.go('/profile'); // Intentional: clear stack on exit admin
}

/// Admin auth screen wrapper.
class AdminAuthScreenWrapper extends ConsumerWidget {
  const AdminAuthScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminAuthScreen(
      onBack: () => safePop(context),
      onSuccess: () {
        ref.read(roleProvider.notifier).set(AppRole.admin);
        context.go('/admin'); // Intentional: clear stack on admin success
      },
    );
  }
}

/// Passenger/driver WhatsApp login wrapper.
class WhatsAppLoginScreenWrapper extends ConsumerWidget {
  final String? redirectTo;

  const WhatsAppLoginScreenWrapper({super.key, this.redirectTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WhatsAppLoginScreen(
      onBack: () => safePop(context),
      onSuccess: (role) {
        ref.read(roleProvider.notifier).set(role);
        ref
            .read(modeProvider.notifier)
            .set(role.isDriver ? AppMode.driver : AppMode.passenger);
        unawaited(
          ref.read(referralAttributionServiceProvider).completePendingSignup(),
        );
        context.go(_safeAppRedirectTarget(redirectTo));
      },
      initialRole: ref.watch(modeProvider).isDriver
          ? AppRole.driver
          : AppRole.passenger,
    );
  }
}

String _safeAppRedirectTarget(String? raw) {
  if (raw == null || raw.isEmpty) {
    return '/';
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    return '/';
  }

  final target = uri.toString();
  if (!target.startsWith('/') ||
      target.startsWith('//') ||
      target == '/login' ||
      target.startsWith('/login?')) {
    return '/';
  }

  return target;
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
          onChat: (t) => context.push(chatPathForTrip(t)),
          onTripDetails: (id) => context.push('/trip/$id'),
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
          mode: mode.value,
          onModeChanged: (m) =>
              ref.read(modeProvider.notifier).set(AppMode.fromString(m)),
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
      mode: mode.value,
      onModeChanged: (m) =>
          ref.read(modeProvider.notifier).set(AppMode.fromString(m)),
      onBack: () => safePop(context),
    );
  }
}

/// Edit scheduled trip screen wrapper.
class EditTripScreenWrapper extends ConsumerWidget {
  final String tripId;
  final VoidCallback onBack;

  const EditTripScreenWrapper({
    super.key,
    required this.tripId,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);
    return ScheduleTripScreen(
      mode: mode.value,
      onModeChanged: (m) =>
          ref.read(modeProvider.notifier).set(AppMode.fromString(m)),
      onBack: onBack,
      editingTripId: tripId,
    );
  }
}

/// Settlement, ledger, dispatch lifecycle, and trip-payment routes remain
/// unavailable in the active Mobio product scope.
class ScopeUnavailableScreen extends StatelessWidget {
  const ScopeUnavailableScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return PlatformFeatureNoticeScreen(
      title: 'Feature unavailable',
      message:
          'Mobio supports nearby discovery, scheduled trip posts, communication, and BioPay USSD handoff. Fare negotiation and payment settlement happen manually outside the app.',
      note:
          'Ledger, in-app settlement, dispatch lifecycle, and trip settlement flows are legacy surfaces and are not active in this release.',
      showPlatformNote: false,
      onBack: onBack,
    );
  }
}
