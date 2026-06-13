import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/features/bookings/bookings_screen.dart';
import 'package:mobi_app/features/bookings/schedule_trip_screen.dart';
import 'package:mobi_app/features/chat/chat_screen.dart';
import 'package:mobi_app/features/home/home_screen.dart';
import 'package:mobi_app/features/nearby/nearby_screen.dart';
import 'package:mobi_app/features/profile/profile_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: RevolutVisualProofApp()));
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
      theme: AppTheme.darkTheme,
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
    'home_shell',
    'bookings_shell',
    'profile_shell',
    'home',
    'bookings',
    'schedule',
    'profile',
    'chat',
    'nearby',
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
      'profile_shell' => 2,
      _ => null,
    };
    var child = _screenFor(baseScreen);
    final scrollOffset = _scrollOffsetFor(screen);
    if (scrollOffset != null) {
      child = _ScrollProofFrame(offset: scrollOffset, child: child);
    }

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
    'schedule' => ScheduleTripScreen(
      mode: 'passenger',
      onModeChanged: (_) {},
      onBack: () {},
    ),
    'profile' || 'profile_shell' => ProfileScreen(
      isDarkMode: true,
      onDarkModeChanged: (_) {},
      onEditProfile: () {},
      onAdminGateway: () {},
    ),
    'chat' => TripChatScreen(onBack: () {}),
    'nearby' => NearbyScreen(onChat: (_) {}, onTripDetails: (_) {}),
    'admin' => _adminPreview(),
    _ => const _UnknownScreen(),
  };
}

String _baseScreenFor(String screen) {
  return switch (screen) {
    'home_scroll' => 'home_shell',
    'bookings_scroll' => 'bookings_shell',
    'profile_scroll' => 'profile_shell',
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
