import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/firebase_analytics_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/services/push_notification_service.dart';
import 'package:mobi_app/features/ledger/providers/ledger_provider.dart';
import 'package:mobi_app/providers/app_providers.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Re-export extracted modules so existing imports of `app.dart` still resolve.
export 'package:mobi_app/core/router/error_screens.dart';
export 'package:mobi_app/core/router/screen_wrappers.dart';

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
  // Shared via Riverpod — never disposed by individual screens.
  NotificationService? get _notificationService => SupabaseConfig.isConfigured
      ? ref.read(notificationServiceProvider)
      : null;
  ProfileService get _profileService => ref.read(profileServiceProvider);
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (!SupabaseConfig.isConfigured || kIsWeb) {
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
    super.dispose();
  }

  Future<void> _syncRoleFromSession() async {
    if (!mounted || !SupabaseConfig.isConfigured) {
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      ref.read(roleProvider.notifier).set(AppRole.passenger);
      unawaited(FirebaseAnalyticsService.instance.setUserContext());
      return;
    }

    final profile = await _profileService.getMyProfile();
    if (!mounted) {
      return;
    }

    final role = AppRole.fromString(profile?.role);
    ref.read(roleProvider.notifier).set(role);

    // Sync ledger credentials to native side
    unawaited(ref.read(ledgerCredentialsSyncProvider.future));

    unawaited(
      FirebaseAnalyticsService.instance.setUserContext(
        userId: currentUser.id,
        role: role.value,
      ),
    );
  }

  void _syncNotificationListener() {
    if (!SupabaseConfig.isConfigured || kIsWeb) {
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    _notificationService?.stopListening();
    if (currentUser != null && !currentUser.isAnonymous) {
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
            isAdmin: role.isAdmin,
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
