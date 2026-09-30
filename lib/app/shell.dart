import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/core/firebase/firebase_analytics_service.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_app/features/notifications/data/notification_service.dart';
import 'package:mobi_app/features/notifications/data/push_notification_service.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MobiShell — Bottom nav shell for StatefulShellRoute
// ─────────────────────────────────────────────────────────────────────────────

/// Main app shell with navigation: Discover / Trips / BioPay / Profile.
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
  int _roleSyncRevision = 0;

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
    super.dispose();
  }

  Future<void> _syncRoleFromSession() async {
    final revision = ++_roleSyncRevision;
    if (!mounted || !SupabaseConfig.isConfigured) {
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      AdminSessionGuard.revoke();
      ref.read(roleProvider.notifier).set(AppRole.passenger);
      unawaited(FirebaseAnalyticsService.instance.setUserContext());
      return;
    }

    AccountSnapshot account;
    try {
      account = AccountContext.capture();
    } on Object {
      AdminSessionGuard.revoke();
      ref.read(roleProvider.notifier).set(AppRole.passenger);
      return;
    }

    final profile = await _profileService.getMyProfile().catchError(
      (Object _) => null,
    );
    if (!mounted ||
        revision != _roleSyncRevision ||
        !AccountContext.isCurrent(account)) {
      return;
    }

    final role = AppRole.fromString(profile?.role);
    if (!role.isAdmin) {
      AdminSessionGuard.revoke();
    }
    ref.read(roleProvider.notifier).set(role);

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
    final isExpandedWidth = MediaQuery.sizeOf(context).width >= 720;

    if (isExpandedWidth && !role.isAdmin) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Row(
            children: [
              _MobiNavigationRail(
                currentIndex: widget.navigationShell.currentIndex,
                isAdmin: role.isAdmin,
                onTap: (i) => widget.navigationShell.goBranch(
                  i,
                  initialLocation: i == widget.navigationShell.currentIndex,
                ),
              ),
              Expanded(child: widget.navigationShell),
            ],
          ),
        ),
      );
    }

    if (isExpandedWidth && role.isAdmin) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(child: widget.navigationShell),
      );
    }

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

class _MobiNavigationRail extends StatelessWidget {
  const _MobiNavigationRail({
    required this.currentIndex,
    required this.onTap,
    required this.isAdmin,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = isAdmin ? _adminItems : _passengerItems;

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      minWidth: 88,
      backgroundColor: cs.surface,
      labelType: NavigationRailLabelType.selected,
      indicatorColor: cs.primaryContainer,
      selectedIconTheme: IconThemeData(color: cs.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        color: cs.primary,
        fontWeight: FontWeight.w700,
      ),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Tooltip(message: item.label, child: Icon(item.icon)),
            selectedIcon: Icon(item.icon),
            label: Text(item.label),
          ),
      ],
    );
  }

  static const _passengerItems = [
    _RailItem(LucideIcons.compass, 'Home'),
    _RailItem(LucideIcons.calendarCheck, 'Trips'),
    _RailItem(LucideIcons.scanFace, 'BioPay'),
    _RailItem(LucideIcons.user, 'Profile'),
  ];

  static const _adminItems = [
    _RailItem(LucideIcons.layoutDashboard, 'Ops'),
    _RailItem(LucideIcons.users, 'Users'),
    _RailItem(LucideIcons.scanFace, 'BioPay'),
    _RailItem(LucideIcons.user, 'Account'),
  ];
}

class _RailItem {
  const _RailItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
