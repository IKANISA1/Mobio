import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/app/launch_screen.dart';
import 'package:mobi_app/app/router/error_screens.dart';
import 'package:mobi_app/features/admin/presentation/admin_audit_log_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_auth_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_broadcasts_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_dashboard_screen.dart';
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
import 'package:mobi_app/features/biopay/presentation/biopay_scan_screen.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/schedule_trip_screen.dart';
import 'package:mobi_app/features/bookings/presentation/trip_details_screen.dart';
import 'package:mobi_app/features/chat/presentation/chat_screen.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/features/nearby/presentation/nearby_screen.dart';
import 'package:mobi_app/features/notifications/presentation/notifications_screen.dart';
import 'package:mobi_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:mobi_app/features/profile/presentation/profile_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import 'revolut_preview_services.dart';
import 'revolut_whatsapp_preview_service.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    ProviderScope(
      overrides: revolutPreviewOverrides,
      child: const RevolutVisualProofApp(),
    ),
  );
}

class RevolutVisualProofApp extends StatelessWidget {
  const RevolutVisualProofApp({super.key});

  static const _screenFromDefine = String.fromEnvironment(
    'MOBI_VISUAL_PROOF_SCREEN',
  );

  @override
  Widget build(BuildContext context) {
    final queryScreen = Uri.base.queryParameters['screen'];
    final screen = _screenFromDefine.isNotEmpty
        ? _screenFromDefine
        : queryScreen ?? 'home_shell';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Uri.base.queryParameters['theme'] == 'light'
          ? AppTheme.lightTheme
          : AppTheme.darkTheme,
      home: _VisualProofHost(
        initialScreen: screen,
        allowInitialLink: _screenFromDefine.isEmpty && queryScreen == null,
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
    'notifications',
    'chat',
    'nearby',
    'biopay_home',
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

  void _advanceScreen() {
    setState(() {
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
    return _VisualProofSurface(screen: _screen);
  }
}

class _VisualProofSurface extends StatelessWidget {
  const _VisualProofSurface({required this.screen});

  final String screen;

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
    var child = _screenFor(baseScreen);
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
          MobiBottomNav(currentIndex: shellIndex, onTap: (_) {}),
        ],
      ),
    );
  }
}

Widget _screenFor(String screen) {
  return switch (screen) {
    'home' || 'home_shell' => HomeScreen(
      mode: 'passenger',
      onModeChanged: (_) {},
      onChat: (_) {},
      onViewNearby: () {},
      onViewBookings: () {},
      onSchedule: () {},
    ),
    'bookings' || 'bookings_shell' => BookingsScreen(
      mode: 'passenger',
      onModeChanged: (_) {},
      onSchedule: () {},
      onTripDetails: (_) {},
    ),
    'biopay_shell' || 'biopay_home' => BioPayScreen(
      onQr: () {},
      onScan: () {},
      onFace: () {},
      onNfc: () {},
      onRequestPayment: () {},
    ),
    'schedule' => ScheduleTripScreen(
      mode: 'passenger',
      onModeChanged: (_) {},
      onBack: () {},
    ),
    'trip_details' => TripDetailsScreen(tripId: 't1', onBack: () {}),
    'trip_edit' => ScheduleTripScreen(
      mode: 'driver',
      onModeChanged: (_) {},
      onBack: () {},
      editingTripId: 't1',
    ),
    'profile' || 'profile_shell' => ProfileScreen(
      isDarkMode: true,
      onDarkModeChanged: (_) {},
      onEditProfile: () {},
      onAdminGateway: () {},
    ),
    'edit_profile' ||
    'edit_profile_large_text' => EditProfileScreen(onBack: () {}),
    'profile_setup' => EditProfileScreen(isFirstRun: true, onBack: () {}),
    'notifications' => NotificationsScreen(onBack: () {}),
    'chat' => TripChatScreen(onBack: () {}),
    'nearby' => NearbyScreen(onChat: (_) {}, onTripDetails: (_) {}),
    'biopay_qr' => BioPayQrScreen(onBack: () {}),
    'biopay_scan' => BioPayScanScreen(onBack: () {}),
    'biopay_face_scan' => BioPayFaceScanScreen(onBack: () {}),
    'biopay_face_enroll' => BioPayFaceEnrollScreen(onBack: () {}),
    'biopay_nfc' => BioPayNfcScreen(onBack: () {}),
    'biopay_nfc_write' => BioPayNfcWriteCardScreen(onBack: () {}),
    'splash' => const MobiLaunchScreen(),
    'login' || 'login_large_text' => ProviderScope(
      overrides: [
        whatsappLoginServiceProvider.overrideWith(
          (ref) => PreviewWhatsAppLoginService(),
        ),
      ],
      child: WhatsAppLoginScreen(onBack: () {}, onSuccess: (_) {}),
    ),
    'admin_auth' => AdminAuthScreen(onBack: () {}, onSuccess: () {}),
    'admin_dashboard' => const AdminDashboardScreen(),
    'admin_users' => const AdminUsersScreen(),
    'admin_trips' => AdminTripsScreen(onBack: () {}),
    'admin_biopay_ops' => const BioPayAdminConsoleScreen(),
    'admin_vehicle_types' => AdminVehicleTypesScreen(onBack: () {}),
    'admin_subscriptions' => AdminSubscriptionsScreen(onBack: () {}),
    'admin_reports' ||
    'admin_reports_large_text' => AdminReportsScreen(onBack: () {}),
    'admin_health' => AdminOperationalHealthScreen(onBack: () {}),
    'admin_audit' => AdminAuditLogScreen(onBack: () {}),
    'admin_broadcasts' => AdminBroadcastsScreen(onBack: () {}),
    'schedule_keyboard' => ScheduleTripScreen(
      mode: 'passenger',
      onModeChanged: (_) {},
      onBack: () {},
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
