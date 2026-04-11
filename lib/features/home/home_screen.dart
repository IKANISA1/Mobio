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
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_feature_tile.dart';
import 'package:mobi_app/shared/widgets/mobi_metric_tile.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
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
  DriverLocationService get _driverLocationService =>
      ref.read(driverLocationServiceProvider);

  TripService get _tripService => ref.read(tripServiceProvider);

  NotificationService get _notificationService =>
      ref.read(notificationServiceProvider);

  RideRequestService get _rideRequestService =>
      ref.read(rideRequestServiceProvider);

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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: MobiSurfacePanel(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    borderRadius: AppRadii.hero,
                    child: Column(
                      children: [
                        _buildHeader(isDriver, cs, ext),
                        const SizedBox(height: AppSpacing.lg),
                        MobiToggle(
                          labels: isDriver
                              ? const ['Ride', 'Drive']
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
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: _buildHeroCard(isDriver)
                      .animate(delay: 100.ms)
                      .fade()
                      .scale(begin: const Offset(0.95, 0.95)),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: MobiFeatureTile(
                          icon: LucideIcons.mapPin,
                          title: 'Nearby',
                          subtitle: isDriver ? 'Passengers' : 'Drivers',
                          accent: Theme.of(context).colorScheme.primary,
                          onTap: widget.onViewNearby,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MobiFeatureTile(
                          icon: LucideIcons.calendarCheck,
                          title: 'Schedule',
                          subtitle: 'New trip',
                          accent: Theme.of(context).colorScheme.secondary,
                          onTap: () => widget.onSchedule?.call(),
                        ),
                      ),
                    ],
                  ).animate(delay: 200.ms).fade().slideY(begin: 0.1),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: MobiSurfacePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    borderRadius: AppRadii.xxl,
                    child: VehicleFilterChips(
                      selectedId: _vehicleId,
                      onSelected: _switchVehicle,
                      vehicleTypes: _vehicleTypes,
                    ),
                  ).animate(delay: 300.ms).fade().slideX(begin: 0.1),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: MobiSectionHeader(
                    title: 'Nearby',
                    caption: isDriver ? 'Passengers' : 'Drivers',
                    icon: LucideIcons.mapPin,
                    actionLabel: 'All',
                    onAction: widget.onViewNearby,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: _hasError
                      ? MobiErrorState(
                          title: 'Load failed',
                          subtitle: 'Pull to retry.',
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
                          title: isDriver
                              ? 'No passengers nearby'
                              : 'No drivers nearby',
                          icon: LucideIcons.mapPin,
                          height: 200,
                        ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: MobiSectionHeader(
                    title: 'Scheduled',
                    caption: '${_scheduledPreview.length} upcoming',
                    icon: LucideIcons.calendarCheck,
                    actionLabel: 'All',
                    onAction: () => widget.onViewBookings?.call(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
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
                          title: 'No trips yet',
                          subtitle: 'Use Schedule.',
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
                  style: AppTypography.titleLg.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

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
              MobiStatusBadge(
                label: _isDriverOnline ? 'Online' : 'Offline',
                icon: _isDriverOnline ? LucideIcons.radio : LucideIcons.pause,
                tone: _isDriverOnline
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.neutral,
              ),
              const SizedBox(width: AppSpacing.xs),
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
    final cs = Theme.of(context).colorScheme;

    return ClayCard(
      onTap: widget.onViewNearby,
      color: cs.primaryContainer.withValues(alpha: 0.92),
      borderRadius: AppRadii.hero,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isDriver ? 'Nearby passengers' : 'Nearby drivers',
                  style: AppTypography.titleLg.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              MobiStatusBadge(
                label: _nearbyCount > 0 ? 'Live' : 'Quiet',
                icon: LucideIcons.sparkles,
                tone: _nearbyCount > 0
                    ? MobiStatusBadgeTone.positive
                    : MobiStatusBadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _nearbyCount.toString(),
            style: AppTypography.heroNumber.copyWith(
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isDriver ? 'Ready to pick up' : 'Ready to book',
            style: AppTypography.bodySm.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: MobiMetricTile(
                  label: 'Unread',
                  value: '$_unreadCount',
                  icon: LucideIcons.bell,
                  accent: cs.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MobiMetricTile(
                  label: 'Scheduled',
                  value: '${_scheduledPreview.length}',
                  icon: LucideIcons.calendarCheck,
                  accent: AppColors.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledCard(BuildContext context, Trip trip) {
    return ClayCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip.origin.toUpperCase()} → ${trip.destination.toUpperCase()}',
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      trip.departureTime,
                      style: AppTypography.headlineLg.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (trip.authorId.isNotEmpty)
                MobiStatusBadge(
                  label: AppConstants.getDriverId(trip.authorId),
                  tone: MobiStatusBadgeTone.brand,
                ),
              MobiStatusBadge(
                label: trip.vehicleTypeStr.toUpperCase(),
                icon: getVehicleIconFromId(trip.vehicleTypeStr),
                tone: MobiStatusBadgeTone.info,
              ),
              const MobiStatusBadge(
                label: 'Upcoming',
                tone: MobiStatusBadgeTone.positive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
