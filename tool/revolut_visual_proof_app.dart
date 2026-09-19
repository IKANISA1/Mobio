import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/app/launch_screen.dart';
import 'package:mobi_app/app/router/error_screens.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/admin/presentation/admin_audit_log_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_auth_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_broadcasts_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_ev_chargers_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_operational_health_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_reports_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_subscriptions_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_trips_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_users_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_vehicle_types_screen.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/auth/application/auth_providers.dart';
import 'package:mobi_app/features/auth/presentation/whatsapp_login_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_admin_console_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_enroll_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_scan_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_home_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_write_card_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_qr_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_request_payment_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_scan_screen.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/schedule_trip_screen.dart';
import 'package:mobi_app/features/bookings/presentation/trip_details_screen.dart';
import 'package:mobi_app/features/chat/presentation/chat_screen.dart';
import 'package:mobi_app/features/ev_chargers/presentation/ev_charger_locator_screen.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/features/nearby/presentation/nearby_screen.dart';
import 'package:mobi_app/features/notifications/presentation/notifications_screen.dart';
import 'package:mobi_app/features/profile/presentation/driver_plus_screen.dart';
import 'package:mobi_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:mobi_app/features/profile/presentation/profile_screen.dart';
import 'package:mobi_app/features/profile/presentation/wallet_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import 'revolut_preview_services.dart';
import 'revolut_whatsapp_preview_service.dart';

void main() {
  if (!SupabaseConfig.isVisualProofMode) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Build this fixture with scripts/web/build_visual_proof.sh. Production release builds do not enable previews.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    ProviderScope(
      overrides: revolutPreviewOverrides,
      child: const RevolutVisualProofApp(),
    ),
  );
}

class RevolutVisualProofApp extends StatelessWidget {
  const RevolutVisualProofApp({super.key, this.initialScreen});

  final String? initialScreen;

  static const _screenFromDefine = String.fromEnvironment(
    'MOBI_VISUAL_PROOF_SCREEN',
  );

  @override
  Widget build(BuildContext context) {
    final queryScreen = Uri.base.queryParameters['screen'];
    final screen =
        initialScreen ??
        (_screenFromDefine.isNotEmpty
            ? _screenFromDefine
            : queryScreen ?? 'home_shell');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Uri.base.queryParameters['theme'] == 'light'
          ? AppTheme.lightTheme
          : AppTheme.darkTheme,
      home: _VisualProofHost(
        initialScreen: screen,
        allowInitialLink:
            initialScreen == null &&
            _screenFromDefine.isEmpty &&
            queryScreen == null,
      ),
    );
  }
}

class _VisualProofHost extends StatefulWidget {
  const _VisualProofHost({
    required this.initialScreen,
    required this.allowInitialLink,
  });

  final String initialScreen;
  final bool allowInitialLink;

  @override
  State<_VisualProofHost> createState() => _VisualProofHostState();
}

class _VisualProofHostState extends State<_VisualProofHost> {
  static const _autoplay = bool.fromEnvironment('MOBI_VISUAL_PROOF_AUTOPLAY');
  static const _intervalMs = int.fromEnvironment(
    'MOBI_VISUAL_PROOF_INTERVAL_MS',
    defaultValue: 4500,
  );
  static const _holdFirstMs = int.fromEnvironment(
    'MOBI_VISUAL_PROOF_HOLD_FIRST_MS',
    defaultValue: _intervalMs,
  );
  static const _screens = [
    'splash',
    'login',
    'home_shell',
    'bookings_shell',
    'biopay_shell',
    'profile_shell',
    'home',
    'bookings',
    'schedule',
    'trip_details',
    'trip_edit',
    'profile',
    'edit_profile',
    'profile_setup',
    'wallet',
    'mobio_plus',
    'notifications',
    'chat',
    'nearby',
    'ev_locator',
    'biopay_home',
    'biopay_request',
    'biopay_qr',
    'biopay_scan',
    'biopay_face_scan',
    'biopay_face_enroll',
    'biopay_nfc',
    'biopay_nfc_write',
    'admin_auth',
    'admin_dashboard',
    'admin_users',
    'admin_trips',
    'admin_ev',
    'admin_biopay_ops',
    'admin_vehicle_types',
    'admin_subscriptions',
    'admin_reports',
    'admin_health',
    'admin_audit',
    'admin_broadcasts',
    'config_error',
    'not_found',
    'login_large_text',
    'schedule_keyboard',
    'edit_profile_large_text',
    'admin_reports_large_text',
    'admin',
    'home_scroll',
    'bookings_scroll',
    'profile_scroll',
  ];

  late String _screen = widget.initialScreen;
  String _tripId = 't1';
  final List<({String screen, String tripId})> _history = [];
  String _mode = 'passenger';
  bool _isDarkMode = Uri.base.queryParameters['theme'] != 'light';
  late int _nextIndex;
  Timer? _timer;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    if (widget.allowInitialLink) {
      unawaited(_loadInitialLink());
      _linkSub = AppLinks().uriLinkStream.listen(_applyLink, onError: (_) {});
    }
    if (_autoplay) {
      final initialIndex = _screens.indexOf(_screen);
      _nextIndex = initialIndex < 0 ? 1 : initialIndex + 1;
      _timer = Timer(const Duration(milliseconds: _holdFirstMs), () {
        if (!mounted) {
          return;
        }
        _advanceScreen();
        _timer = Timer.periodic(const Duration(milliseconds: _intervalMs), (_) {
          if (mounted) {
            _advanceScreen();
          }
        });
      });
    }
  }

  void _navigate(String destination) {
    setState(() {
      if (destination.endsWith('_shell')) {
        _history.clear();
      } else {
        _history.add((screen: _screen, tripId: _tripId));
      }
      if (destination.startsWith('trip_details:')) {
        _tripId = destination.substring('trip_details:'.length);
        _screen = 'trip_details';
      } else {
        _screen = destination;
      }
    });
  }

  void _back(String fallback) {
    setState(() {
      if (_history.isEmpty) {
        _screen = fallback;
        return;
      }
      final previous = _history.removeLast();
      _screen = previous.screen;
      _tripId = previous.tripId;
    });
  }

  void _advanceScreen() {
    setState(() {
      _history.clear();
      _screen = _screens[_nextIndex % _screens.length];
      _nextIndex += 1;
    });
  }

  Future<void> _loadInitialLink() async {
    try {
      final uri = await AppLinks().getInitialLink();
      if (uri != null) {
        _applyLink(uri);
      }
    } on Object {
      // Proof harness only: ignore link plugin failures and keep default screen.
    }
  }

  void _applyLink(Uri uri) {
    final linkedScreen = uri.queryParameters['screen'];
    if (linkedScreen == null || !_screens.contains(linkedScreen) || !mounted) {
      return;
    }
    setState(() {
      _history.clear();
      _screen = linkedScreen;
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      child: _VisualProofSurface(
        screen: _screen,
        tripId: _tripId,
        onBack: _back,
        mode: _mode,
        isDarkMode: _isDarkMode,
        onModeChanged: (mode) => setState(() => _mode = mode),
        onDarkModeChanged: (dark) => setState(() => _isDarkMode = dark),
        onNavigate: _navigate,
      ),
    );
  }
}

class _VisualProofSurface extends StatelessWidget {
  const _VisualProofSurface({
    required this.screen,
    required this.tripId,
    required this.onBack,
    required this.onNavigate,
    required this.mode,
    required this.isDarkMode,
    required this.onModeChanged,
    required this.onDarkModeChanged,
  });

  final String screen;
  final String tripId;
  final ValueChanged<String> onBack;
  final ValueChanged<String> onNavigate;
  final String mode;
  final bool isDarkMode;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  Widget build(BuildContext context) {
    final baseScreen = _baseScreenFor(screen);
    final shellIndex = switch (baseScreen) {
      'home_shell' => 0,
      'bookings_shell' => 1,
      'biopay_shell' => 2,
      'profile_shell' => 3,
      _ => null,
    };
    var child = _screenFor(
      baseScreen,
      onNavigate,
      back: onBack,
      tripId: tripId,
      mode: mode,
      isDarkMode: isDarkMode,
      onModeChanged: onModeChanged,
      onDarkModeChanged: onDarkModeChanged,
    );
    final scrollOffset = _scrollOffsetFor(screen);
    if (scrollOffset != null) {
      child = _ScrollProofFrame(offset: scrollOffset, child: child);
    }

    child = _mediaFrameFor(screen, child);

    if (shellIndex == null) {
      return Scaffold(body: child);
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(bottom: false, child: child),
          MobiBottomNav(
            currentIndex: shellIndex,
            onTap: (index) {
              onNavigate(
                const [
                  'home_shell',
                  'bookings_shell',
                  'biopay_shell',
                  'profile_shell',
                ][index],
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget _screenFor(
  String screen,
  ValueChanged<String> go, {
  required ValueChanged<String> back,
  required String tripId,
  required String mode,
  required bool isDarkMode,
  required ValueChanged<String> onModeChanged,
  required ValueChanged<bool> onDarkModeChanged,
}) {
  return switch (screen) {
    'home' || 'home_shell' => HomeScreen(
      mode: mode,
      onModeChanged: onModeChanged,
      onChat: (_) => go('chat'),
      onViewNearby: () => go('nearby'),
      onViewBookings: () => go('bookings_shell'),
      onSchedule: () => go('schedule'),
      onNotifications: () => go('notifications'),
      onEvChargers: () => go('ev_locator'),
    ),
    'bookings' || 'bookings_shell' => BookingsScreen(
      mode: mode,
      onModeChanged: onModeChanged,
      onSchedule: () => go('schedule'),
      onTripDetails: (id) => go('trip_details:$id'),
    ),
    'biopay_shell' || 'biopay_home' => BioPayScreen(
      onQr: () => go('biopay_qr'),
      onScan: () => go('biopay_scan'),
      onFace: () => go('biopay_face_scan'),
      onNfc: () => go('biopay_nfc'),
      onRequestPayment: () => go('biopay_request'),
    ),
    'schedule' => ScheduleTripScreen(
      mode: mode,
      onModeChanged: onModeChanged,
      onBack: () => back('home_shell'),
    ),
    'trip_details' => TripDetailsScreen(
      tripId: tripId,
      onBack: () => back('home_shell'),
    ),
    'trip_edit' => ScheduleTripScreen(
      mode: 'driver',
      onModeChanged: (_) {},
      onBack: () => back('home_shell'),
      editingTripId: 't1',
    ),
    'profile' || 'profile_shell' => ProfileScreen(
      isDarkMode: isDarkMode,
      onDarkModeChanged: onDarkModeChanged,
      onEditProfile: () => go('edit_profile'),
      onWallet: () => go('wallet'),
      onInviteAndEarn: () => go('wallet'),
      onMobioPlus: () => go('mobio_plus'),
      onBioPayEnroll: () => go('biopay_face_enroll'),
      onNfcWriteCard: () => go('biopay_nfc_write'),
      onAdminGateway: () => go('admin_auth'),
    ),
    'edit_profile' || 'edit_profile_large_text' => EditProfileScreen(
      onBack: () => back('home_shell'),
    ),
    'profile_setup' => EditProfileScreen(
      isFirstRun: true,
      onBack: () => back('home_shell'),
    ),
    'wallet' => WalletScreen(onBack: () => back('profile_shell')),
    'mobio_plus' => DriverPlusScreen(onBack: () => back('profile_shell')),
    'notifications' => NotificationsScreen(onBack: () => back('home_shell')),
    'chat' => TripChatScreen(onBack: () => back('home_shell')),
    'nearby' => NearbyScreen(
      onChat: (_) => go('chat'),
      onTripDetails: (id) => go('trip_details:$id'),
    ),
    'ev_locator' => EvChargerLocatorScreen(onBack: () => back('home_shell')),
    'biopay_request' => BioPayRequestPaymentScreen(
      onBack: () => back('biopay_shell'),
    ),
    'biopay_qr' => BioPayQrScreen(onBack: () => back('home_shell')),
    'biopay_scan' => BioPayScanScreen(onBack: () => back('home_shell')),
    'biopay_face_scan' => BioPayFaceScanScreen(
      onBack: () => back('home_shell'),
    ),
    'biopay_face_enroll' => BioPayFaceEnrollScreen(
      onBack: () => back('home_shell'),
    ),
    'biopay_nfc' => BioPayNfcScreen(onBack: () => back('home_shell')),
    'biopay_nfc_write' => BioPayNfcWriteCardScreen(
      onBack: () => back('home_shell'),
    ),
    'splash' => const MobiLaunchScreen(),
    'login' || 'login_large_text' => ProviderScope(
      overrides: [
        whatsappLoginServiceProvider.overrideWith(
          (ref) => PreviewWhatsAppLoginService(),
        ),
      ],
      child: WhatsAppLoginScreen(
        onBack: () => back('home_shell'),
        onSuccess: (_) => go('home_shell'),
      ),
    ),
    'admin_auth' => AdminAuthScreen(
      onBack: () => back('home_shell'),
      onSuccess: () => go('admin_dashboard'),
    ),
    'admin_dashboard' => const AdminDashboardScreen(),
    'admin_users' => const AdminUsersScreen(),
    'admin_trips' => AdminTripsScreen(onBack: () => back('home_shell')),
    'admin_ev' => AdminEvChargersScreen(onBack: () => back('admin_dashboard')),
    'admin_biopay_ops' => const BioPayAdminConsoleScreen(),
    'admin_vehicle_types' => AdminVehicleTypesScreen(
      onBack: () => back('home_shell'),
    ),
    'admin_subscriptions' => AdminSubscriptionsScreen(
      onBack: () => back('home_shell'),
    ),
    'admin_reports' || 'admin_reports_large_text' => AdminReportsScreen(
      onBack: () => back('home_shell'),
    ),
    'admin_health' => AdminOperationalHealthScreen(
      onBack: () => back('home_shell'),
    ),
    'admin_audit' => AdminAuditLogScreen(onBack: () => back('home_shell')),
    'admin_broadcasts' => AdminBroadcastsScreen(
      onBack: () => back('home_shell'),
    ),
    'schedule_keyboard' => ScheduleTripScreen(
      mode: 'passenger',
      onModeChanged: (_) {},
      onBack: () => back('home_shell'),
    ),
    'config_error' => const ConfigErrorScreen(),
    'not_found' => const NotFoundScreen(),
    'admin' => _adminPreview(),
    _ => const _UnknownScreen(),
  };
}

String _baseScreenFor(String screen) {
  return switch (screen) {
    'home_scroll' => 'home_shell',
    'bookings_scroll' => 'bookings_shell',
    'profile_scroll' => 'profile_shell',
    'schedule_keyboard' => 'schedule_keyboard',
    _ => screen,
  };
}

double? _scrollOffsetFor(String screen) {
  return switch (screen) {
    'home_scroll' => 620,
    'bookings_scroll' => 500,
    'profile_scroll' => 520,
    _ => null,
  };
}

Widget _mediaFrameFor(String screen, Widget child) {
  final largeText = screen.endsWith('_large_text');
  final keyboard = screen.endsWith('_keyboard');
  if (!largeText && !keyboard) {
    return child;
  }

  return Builder(
    builder: (context) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          textScaler: largeText ? const TextScaler.linear(2) : media.textScaler,
          viewInsets: keyboard
              ? media.viewInsets.copyWith(bottom: 320)
              : media.viewInsets,
        ),
        child: child,
      );
    },
  );
}

class _ScrollProofFrame extends StatefulWidget {
  const _ScrollProofFrame({required this.offset, required this.child});

  final double offset;
  final Widget child;

  @override
  State<_ScrollProofFrame> createState() => _ScrollProofFrameState();
}

class _ScrollProofFrameState extends State<_ScrollProofFrame> {
  final _controller = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleScroll();
  }

  @override
  void didUpdateWidget(covariant _ScrollProofFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offset != widget.offset) {
      _scheduleScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleScroll() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final target = math.min(
        widget.offset,
        _controller.position.maxScrollExtent,
      );
      _controller.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      child: widget.child,
    );
  }
}

Widget _adminPreview() {
  return AdminWorkspaceFrame(
    title: 'Operations',
    subtitle: 'Live platform controls',
    currentTab: AdminWorkspaceTab.overview,
    actions: const [
      AdminActionChip(icon: LucideIcons.refreshCw, label: 'Refresh'),
    ],
    child: ListView(
      padding: AdminLayoutTokens.pagePadding,
      children: const [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AdminMetricCard(
              label: 'Open reports',
              value: '12',
              icon: LucideIcons.flag,
            ),
            AdminMetricCard(
              label: 'Active trips',
              value: '48',
              icon: LucideIcons.navigation,
            ),
            AdminMetricCard(
              label: 'Live users',
              value: '214',
              icon: LucideIcons.users,
            ),
          ],
        ),
        SizedBox(height: 20),
        AdminEmptyState(
          icon: LucideIcons.shieldCheck,
          title: 'No critical alerts',
          message: 'Ops review is clear.',
        ),
      ],
    ),
  );
}

class _UnknownScreen extends StatelessWidget {
  const _UnknownScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Unknown visual proof screen'));
  }
}
