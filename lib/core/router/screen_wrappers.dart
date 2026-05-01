import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/core/services/supabase_session_service.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/features/admin/admin_auth_screen.dart';
import 'package:mobi_app/features/admin/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/admin_users_screen.dart';
import 'package:mobi_app/features/biopay/biopay_screen.dart';
import 'package:mobi_app/features/bookings/bookings_screen.dart';
import 'package:mobi_app/features/bookings/schedule_trip_screen.dart';
import 'package:mobi_app/features/home/home_screen.dart';
import 'package:mobi_app/features/ledger/ledger_screen.dart';
import 'package:mobi_app/features/nearby/nearby_screen.dart';
import 'package:mobi_app/features/profile/profile_screen.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/providers/app_providers.dart';

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
    if (role.isAdmin) {
      return const AdminUsersScreen();
    }

    return BioPayScreen(
      onGetQR: () => context.push('/biopay/qr'),
      onScanQR: () => context.push('/biopay/scan'),
      onFaceScan: () => context.push('/biopay/face-scan'),
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
    void handleExitAdmin() {
      unawaited(_exitAdminSession(context, ref));
    }

    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) => ProfileScreen(
        isDarkMode: themeProvider.isDark,
        onDarkModeChanged: themeProvider.setDarkMode,
        onEditProfile: () => context.push('/edit-profile'),
        onViewLedger: () => context.push('/ledger'),
        onAdminGateway: () => context.push('/admin-auth'),
        onFaceRegister: () => context.push('/biopay/enroll'),
        onExitAdmin: role.isAdmin ? handleExitAdmin : null,
      ),
    );
  }
}

Future<void> _exitAdminSession(BuildContext context, WidgetRef ref) async {
  AdminSessionGuard.revoke();
  ref.read(roleProvider.notifier).set(AppRole.passenger);
  await SupabaseSessionService.signOutToAnonymous();
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

/// Ledger screen wrapper.
class LedgerScreenWrapper extends ConsumerWidget {
  const LedgerScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const LedgerScreen();
  }
}
