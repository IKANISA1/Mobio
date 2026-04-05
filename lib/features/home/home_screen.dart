import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/services/ride_request_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_shadows.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_app/shared/widgets/ride_request_sheet.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

/// Home (Discover) screen matching transito design.
class HomeScreen extends ConsumerStatefulWidget {
  final String mode;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<Trip> onChat;
  final VoidCallback onViewNearby;
  final VoidCallback? onViewBookings;
  final VoidCallback? onSchedule;

  const HomeScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onChat,
    required this.onViewNearby,
    this.onViewBookings,
    this.onSchedule,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _vehicleId = 'cab';
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDriverOnline = false;
  int _nearbyCount = 0;
  int _unreadCount = 0;
  List<Trip> _nearbyPreview = [];
  List<Trip> _scheduledPreview = [];
  List<VehicleTypeModel> _vehicleTypes = [];
  DriverLocationService get _driverLocationService => ref.read(driverLocationServiceProvider);

  TripService get _tripService => ref.read(tripServiceProvider);

  NotificationService get _notificationService => ref.read(notificationServiceProvider);

  RideRequestService get _rideRequestService => ref.read(rideRequestServiceProvider);

  StreamSubscription<AppNotification>? _notifSub;

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    _loadData();
    _loadUnreadCount();
    _listenForIncomingRequests();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _notificationService.dispose();
    super.dispose();
  }

  /// Listens for realtime notifications — if one is a ride request, show the sheet.
  void _listenForIncomingRequests() {
    _notificationService.startListening();
    _notifSub = _notificationService.onNotification.listen((notif) {
      // Update badge
      setState(() => _unreadCount++);

      // If it's a ride request/offer, auto-show the response sheet
      final rideRequestTypes = {'ride_request_received', 'ride_offer_received'};
      if (rideRequestTypes.contains(notif.type)) {
        final requestId = notif.metadata['ride_request_id'] as String?;
        if (requestId != null && mounted) {
          _showIncomingRequest(requestId);
        }
      }
    });
  }

  Future<void> _showIncomingRequest(String requestId) async {
    final request = await _rideRequestService.getById(requestId);
    if (request == null || !request.isPending || !mounted) return;

    showRideRequestSheet(context, request: request);
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } on Object catch (_) {
      // Silently fail — badge is non-critical
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      // Fetch nearby + scheduled in parallel
      final results = await Future.wait([
        _tripService.getNearbyTrips(),
        _tripService.getMyTrips(),
      ]);

      final nearby = results[0];
      final myTrips = results[1];

      // Get scheduled trips (active/upcoming)
      final scheduled = myTrips
          .where((t) => t.status == 'active' || t.status == null)
          .take(3)
          .toList();

      if (mounted) {
        setState(() {
          _nearbyCount = nearby.length;
          _nearbyPreview = nearby.take(3).toList();
          _scheduledPreview = scheduled;
          _isLoading = false;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _nearbyCount = 0;
          _nearbyPreview = [];
          _scheduledPreview = [];
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _loadVehicleTypes() async {
    final types = await VehicleTypeService().getAll();
    if (mounted) setState(() => _vehicleTypes = types);
  }

  void _switchVehicle(String id) {
    setState(() => _vehicleId = id);
    _loadData();
  }

  void _toggleDriverOnline(bool value) {
    setState(() => _isDriverOnline = value);
    _driverLocationService.setDriverOnlineStatus(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final mediaPadding = MediaQuery.paddingOf(context);
    final isDriver = widget.mode == 'driver';

    return SoftGradient(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: _loadData,
          color: cs.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(bottom: 136 + mediaPadding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: MobiSurfacePanel(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    borderRadius: 36,
                    child: Column(
                      children: [
                        _buildHeader(isDriver, cs, ext),
                        const SizedBox(height: 18),
                        MobiToggle(
                          labels: isDriver
                              ? const ['Passenger', 'Driver Mode']
                              : const ['Passenger', 'Driver'],
                          selectedIndex: isDriver ? 1 : 0,
                          onChanged: (i) => widget.onModeChanged(
                            i == 0 ? 'passenger' : 'driver',
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms).slideY(begin: -0.1),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child:
                      _TappableContainer(
                            onTap: widget.onViewNearby,
                            child: _buildHeroCard(isDriver),
                          )
                          .animate(delay: 100.ms)
                          .fade()
                          .scale(begin: const Offset(0.95, 0.95)),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          context: context,
                          icon: LucideIcons.mapPin,
                          label: 'Nearby',
                          subtitle: 'Find nearby drivers',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: widget.onViewNearby,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionTile(
                          context: context,
                          icon: LucideIcons.calendarCheck,
                          label: 'Schedule',
                          subtitle: 'Schedule a trip',
                          color: Theme.of(context).colorScheme.secondary,
                          onTap: () => widget.onSchedule?.call(),
                        ),
                      ),
                    ],
                  ).animate(delay: 200.ms).fade().slideY(begin: 0.1),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: MobiSurfacePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    borderRadius: 32,
                    child: VehicleFilterChips(
                      selectedId: _vehicleId,
                      onSelected: _switchVehicle,
                      vehicleTypes: _vehicleTypes,
                    ),
                  ).animate(delay: 300.ms).fade().slideX(begin: 0.1),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSectionHeader(
                    context: context,
                    title: isDriver ? 'Nearby Passengers' : 'Nearby Drivers',
                    onViewAll: widget.onViewNearby,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _hasError
                      ? MobiErrorState(
                          title: 'Unable to load data',
                          subtitle: 'Pull down to refresh or tap to retry.',
                          icon: LucideIcons.wifiOff,
                          onRetry: _loadData,
                          height: 240,
                        )
                      : _isLoading
                      ? Column(
                          children: List.generate(
                            2,
                            (_) => const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: LoadingSkeleton.card(height: 100),
                            ),
                          ),
                        )
                      : _nearbyPreview.isNotEmpty
                      ? Column(
                          children: _nearbyPreview
                              .map(
                                (trip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DriverCard(
                                    trip: trip,
                                    onChat: () => widget.onChat(trip),
                                  ),
                                ),
                              )
                              .toList()
                              .animate(interval: 100.ms)
                              .fade()
                              .slideY(begin: 0.1),
                        )
                      : AiEmptyState(
                          title:
                              'No nearby ${isDriver ? "passengers" : "drivers"} found.',
                          icon: LucideIcons.mapPin,
                          height: 200,
                        ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSectionHeader(
                    context: context,
                    title: 'Scheduled',
                    onViewAll: () => widget.onViewBookings?.call(),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _isLoading
                      ? Column(
                          children: List.generate(
                            2,
                            (_) => const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: LoadingSkeleton.card(height: 100),
                            ),
                          ),
                        )
                      : _scheduledPreview.isNotEmpty
                      ? Column(
                          children: _scheduledPreview
                              .map(
                                (trip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildScheduledCard(context, trip),
                                ),
                              )
                              .toList()
                              .animate(interval: 100.ms)
                              .fade()
                              .slideY(begin: 0.1),
                        )
                      : const AiEmptyState(
                          title: 'No scheduled trips.',
                          subtitle: 'Tap Nearby to find drivers.',
                          icon: LucideIcons.calendar,
                          height: 200,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDriver, ColorScheme cs, MobiThemeExtension ext) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: ClipRect(
                  child: Transform.scale(
                    scale: 1.38,
                    child: Image.asset(
                      'icon/mobi_logo_transparent.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Mobio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMd.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Notification bell with unread badge
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            children: [
              Center(
                child: Icon(
                  LucideIcons.bell,
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        color: cs.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (isDriver) const SizedBox(width: 8),
        if (isDriver)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ONLINE',
                style: AppTypography.labelSm.copyWith(
                  color: _isDriverOnline
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: Switch(
                  value: _isDriverOnline,
                  onChanged: _toggleDriverOnline,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  activeTrackColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  inactiveThumbColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  inactiveTrackColor: ext.surfaceContainer,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHeroCard(bool isDriver) {
    final heroText = _nearbyCount > 0
        ? '$_nearbyCount\n${isDriver ? "Passengers" : "Drivers"}\nNear You'
        : '${isDriver ? "Passengers" : "Drivers"} Near You';

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleSize = constraints.maxWidth < 300
            ? 40.0
            : constraints.maxWidth < 340
            ? 44.0
            : 52.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                AppColors.primaryDim,
              ],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: AppShadows.premium,
          ),
          child: Text(
            heroText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.displayLg.copyWith(
              fontSize: titleSize,
              height: 1.05,
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return _TappableContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ext.surfaceContainerLowest.withValues(
            alpha: ext.surfacePanelAlpha,
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: cs.outlineVariant.withValues(
              alpha: ext.surfacePanelBorderAlpha,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTypography.titleMd.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    VoidCallback? onViewAll,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return MobiSurfacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 28,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineLg.copyWith(color: cs.onSurface),
            ),
          ),
          if (onViewAll != null) const SizedBox(width: 12),
          if (onViewAll != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(999),
                splashColor: cs.primary.withValues(alpha: 0.12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ext.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    'View All',
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduledCard(BuildContext context, Trip trip) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest.withValues(
          alpha: ext.surfacePanelAlpha,
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: cs.outlineVariant.withValues(
            alpha: ext.surfacePanelBorderAlpha,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip.authorId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                AppConstants.getDriverId(trip.authorId),
                style: AppTypography.labelMd.copyWith(
                  letterSpacing: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          Text(
            '${trip.origin.toUpperCase()} → ${trip.destination.toUpperCase()}',
            style: AppTypography.titleMd.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trip.departureTime,
            style: AppTypography.displayMd.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildChip(
                context: context,
                icon: getVehicleIconFromId(trip.vehicleTypeStr),
                label: trip.vehicleTypeStr.toUpperCase(),
              ),
              const SizedBox(width: 8),
              _buildChip(
                context: context,
                label: 'EXPIRES IN 45M',
                isHighlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    IconData? icon,
    required String label,
    bool isHighlight = false,
  }) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : ext.surfaceContainerLowest.withValues(
                alpha: ext.surfacePanelAlpha - 0.08,
              ),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isHighlight
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outlineVariant.withValues(
                  alpha: ext.cardBorderAlpha,
                ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              letterSpacing: 0.5,
              color: isHighlight
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TappableContainer extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TappableContainer({required this.onTap, required this.child});

  @override
  ConsumerState<_TappableContainer> createState() => _TappableContainerState();
}

class _TappableContainerState extends ConsumerState<_TappableContainer> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _isPressed ? 0.96 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _isPressed ? 0.8 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
