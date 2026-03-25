import 'package:flutter/material.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/theme/theme_provider.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/features/home/home_screen.dart';
import 'package:mobi_app/features/nearby/nearby_screen.dart';
import 'package:mobi_app/features/bookings/bookings_screen.dart';
import 'package:mobi_app/features/bookings/schedule_trip_screen.dart';
import 'package:mobi_app/features/bookings/trip_details_screen.dart';
import 'package:mobi_app/features/biopay/biopay_screen.dart';
import 'package:mobi_app/features/biopay/get_qr_screen.dart';
import 'package:mobi_app/features/biopay/scan_qr_screen.dart';
import 'package:mobi_app/features/biopay/face_scan_screen.dart';
import 'package:mobi_app/features/biopay/face_registration_screen.dart';
import 'package:mobi_app/features/biopay/face_enrollment_screen.dart';
import 'package:mobi_app/features/profile/profile_screen.dart';
import 'package:mobi_app/features/profile/edit_profile_screen.dart';
import 'package:mobi_app/features/admin/admin_auth_screen.dart';
import 'package:mobi_app/features/admin/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/admin_users_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:mobi_app/shared/widgets/whatsapp_modal.dart';

/// Main app shell with 3-tab navigation: Discover / BioPay / Profile.
/// Sub-screens (Nearby, Bookings, Schedule, etc.) are pushed as overlays.
class MobiApp extends StatefulWidget {
  const MobiApp({super.key});

  @override
  State<MobiApp> createState() => _MobiAppState();
}

class _MobiAppState extends State<MobiApp> {
  // ─── Navigation state ───
  String _screen = 'main';
  // Screen values: 'main' | 'admin-auth' | 'schedule' |
  //   'trip-details' | 'edit-profile' | 'nearby' | 'bookings' |
  //   'get-qr' | 'scan-qr' | 'face-scan' | 'face-register' | 'face-enroll'

  String _role = 'passenger'; // 'passenger' | 'admin'
  int _tabIndex = 0; // 0=Discover, 1=BioPay, 2=Profile

  // ─── App state ───
  String _mode = 'passenger'; // 'passenger' | 'driver'
  Trip? _activeTrip;
  String? _selectedTripId;



  // ─── Notifications ───
  final NotificationService? _notificationService = SupabaseConfig.isConfigured
      ? NotificationService()
      : null;
  // ignore: unused_field — stored for future badge display
  final int _unreadCount = 0;

  @override
  void dispose() {
    _notificationService?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!SupabaseConfig.isConfigured) {
      _screen = 'config-error';
    }
  }

  /// Whether the system back button should be allowed to exit the app.
  bool get _canPop {
    // Only allow real exit from the Discover root when no overlay is showing.
    return _screen == 'main' && _tabIndex == 0 && _activeTrip == null;
  }

  /// Handle Android system back: navigate within the app state machine.
  void _handleBackNavigation(bool didPop, Object? result) {
    if (didPop) return; // Already popped (exit allowed)

    setState(() {
      if (_activeTrip != null) {
        _activeTrip = null;
      } else if (_screen != 'main') {
        // Any sub-screen → return to main shell
        _screen = 'main';
      } else if (_tabIndex != 0) {
        // Non-Discover tab → go to Discover
        _tabIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // No splash handling needed since native splash was kept


    if (_screen == 'config-error') {
      return const _ConfigErrorScreen();
    }

    // Wrap everything in PopScope for system back button handling
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: _handleBackNavigation,
      child: _buildScreenContent(),
    );
  }

  Widget _buildScreenContent() {
    final cs = Theme.of(context).colorScheme;

    // Admin auth
    if (_screen == 'admin-auth') {
      return AdminAuthScreen(
        onBack: () => setState(() => _screen = 'main'),
        onSuccess: () => setState(() {
          _role = 'admin';
          _tabIndex = 0;
          _screen = 'main';
        }),
      );
    }



    // Schedule trip
    if (_screen == 'schedule') {
      return ScheduleTripScreen(
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
        onBack: () => setState(() => _screen = 'main'),
      );
    }

    // Trip details
    if (_screen == 'trip-details' && _selectedTripId != null) {
      return TripDetailsScreen(
        tripId: _selectedTripId!,
        onBack: () => setState(() => _screen = 'main'),
      );
    }

    // Edit profile
    if (_screen == 'edit-profile') {
      return EditProfileScreen(
        onBack: () => setState(() => _screen = 'main'),
      );
    }

    // Nearby (full page — accessed from Discover tab)
    if (_screen == 'nearby') {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          bottom: false,
          child: NearbyScreen(
            onWhatsApp: (t) => setState(() => _activeTrip = t),
            onBack: () => setState(() => _screen = 'main'),
          ),
        ),
      );
    }

    // Bookings (full page — accessed from Discover tab)
    if (_screen == 'bookings') {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          bottom: false,
          child: BookingsScreen(
            mode: _mode,
            onModeChanged: (m) => setState(() => _mode = m),
            onSchedule: () => setState(() => _screen = 'schedule'),
            onTripDetails: (id) => setState(() {
              _selectedTripId = id;
              _screen = 'trip-details';
            }),
            onBack: () => setState(() => _screen = 'main'),
          ),
        ),
      );
    }

    // BioPay: Get QR
    if (_screen == 'get-qr') {
      return GetQrScreen(onBack: () => setState(() => _screen = 'main'));
    }

    // BioPay: Scan QR
    if (_screen == 'scan-qr') {
      return ScanQrScreen(onBack: () => setState(() => _screen = 'main'));
    }

    // BioPay: Face Scan
    if (_screen == 'face-scan') {
      return FaceScanScreen(onBack: () => setState(() => _screen = 'main'));
    }

    // BioPay: Face Registration (manual link)
    if (_screen == 'face-register') {
      return FaceRegistrationScreen(
        onBack: () => setState(() => _screen = 'main'),
        onEnroll: () => setState(() => _screen = 'face-enroll'),
      );
    }

    // BioPay: Face Enrollment (camera-based)
    if (_screen == 'face-enroll') {
      return FaceEnrollmentScreen(
        onBack: () => setState(() => _screen = 'main'),
      );
    }

    // Main shell with 3-tab bottom nav
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Content — SafeArea keeps headers below the status bar
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(
                  _role == 'admin' ? 'admin_$_tabIndex' : 'tab_$_tabIndex',
                ),
                child: _buildContent(),
              ),
            ),
          ),

          // Bottom nav
          MobiBottomNav(
            currentIndex: _tabIndex,
            isAdmin: _role == 'admin',
            onTap: (i) => setState(() {
              _tabIndex = i;
            }),
          ),

          // WhatsApp modal overlay
          if (_activeTrip != null)
            WhatsAppModal(
              driverName: _activeTrip!.authorName.split(' ').first,
              onOpen: () {
                // TODO: launch WhatsApp URL
                setState(() => _activeTrip = null);
              },
              onDismiss: () => setState(() => _activeTrip = null),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final themeProvider = ThemeProvider.of(context);

    if (_role == 'admin') {
      switch (_tabIndex) {
        case 0:
          return const AdminDashboardScreen();
        case 1:
          return const AdminUsersScreen();
        case 2:
          return ProfileScreen(
            isDarkMode: themeProvider.isDark,
            onDarkModeChanged: (_) => themeProvider.toggleTheme(),
            onExitAdmin: () => setState(() {
              _role = 'passenger';
              _tabIndex = 0;
            }),
            onEditProfile: () => setState(() => _screen = 'edit-profile'),
            onAdminGateway: () {},
            onFaceRegister: () => setState(() => _screen = 'face-register'),
          );
        default:
          return const AdminDashboardScreen();
      }
    }

    // Passenger/Driver — 3 tabs: Discover(0), BioPay(1), Profile(2)
    switch (_tabIndex) {
      case 0:
        return HomeScreen(
          mode: _mode,
          onModeChanged: (m) => setState(() => _mode = m),
          onWhatsApp: (t) => setState(() => _activeTrip = t),
          onViewNearby: () => setState(() => _screen = 'nearby'),
          onViewBookings: () => setState(() => _screen = 'bookings'),
          onSchedule: () => setState(() => _screen = 'schedule'),
        );
      case 1:
        return BioPayScreen(
          onGetQR: () => setState(() => _screen = 'get-qr'),
          onScanQR: () => setState(() => _screen = 'scan-qr'),
          onFaceScan: () => setState(() => _screen = 'face-scan'),
          onManage: () => setState(() => _screen = 'edit-profile'),
          onEnroll: () => setState(() => _screen = 'face-enroll'),
        );
      case 2:
        return ProfileScreen(
          isDarkMode: themeProvider.isDark,
          onDarkModeChanged: (_) => themeProvider.toggleTheme(),
          onEditProfile: () => setState(() => _screen = 'edit-profile'),
          onAdminGateway: () => setState(() => _screen = 'admin-auth'),
          onFaceRegister: () => setState(() => _screen = 'face-register'),
        );
      default:
        return HomeScreen(
          mode: _mode,
          onModeChanged: (m) => setState(() => _mode = m),
          onWhatsApp: (t) => setState(() => _activeTrip = t),
          onViewNearby: () => setState(() => _screen = 'nearby'),
          onViewBookings: () => setState(() => _screen = 'bookings'),
          onSchedule: () => setState(() => _screen = 'schedule'),
        );
    }
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  const _ConfigErrorScreen();

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
                    'Unable to start mobi',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This APK was built without SUPABASE_URL and SUPABASE_ANON_KEY.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rebuild the app with --dart-define values for both keys before running device UAT.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                      height: 1.5,
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
