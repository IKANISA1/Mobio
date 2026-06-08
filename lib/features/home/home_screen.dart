import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/features/home/widgets/driver_demand_zones_panel.dart';
import 'package:mobi_app/features/home/widgets/home_header.dart';
import 'package:mobi_app/features/home/widgets/home_hero_card.dart';
import 'package:mobi_app/features/home/widgets/scheduled_trip_card.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_action_row.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
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
  List<DriverDemandZone> _demandZones = [];
  List<Trip> _nearbyPreview = [];
  List<Trip> _scheduledPreview = [];
  List<VehicleTypeModel> _vehicleTypes = [];
  DriverLocationService get _driverLocationService =>
      ref.read(driverLocationServiceProvider);

  TripService get _tripService => ref.read(tripServiceProvider);

  NotificationService get _notificationService =>
      ref.read(notificationServiceProvider);

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
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      unawaited(_loadData());
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    // Do NOT dispose _notificationService — it is a shared singleton
    // managed by MobiShell via Riverpod.
    super.dispose();
  }

  /// Listens for realtime notifications and updates the unread badge.
  void _listenForIncomingRequests() {
    _notifSub = _notificationService.onNotification.listen((notif) {
      if (mounted) {
        setState(() => _unreadCount++);
      }
    });
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
      final isDriver = widget.mode == 'driver';
      final nearbyFuture = _tripService.getNearbyTrips();
      final myTripsFuture = _tripService.getMyTrips();
      final demandZonesFuture = isDriver
          ? _fetchDemandZones()
          : Future.value(<DriverDemandZone>[]);

      final nearby = await nearbyFuture;
      final myTrips = await myTripsFuture;
      final demandZones = await demandZonesFuture;

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
          _demandZones = isDriver ? demandZones : [];
          _isLoading = false;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _nearbyCount = 0;
          _nearbyPreview = [];
          _scheduledPreview = [];
          _demandZones = [];
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<List<DriverDemandZone>> _fetchDemandZones() async {
    final position = await ref
        .read(locationServiceProvider)
        .getLastKnownOrCached();

    return _driverLocationService.getDemandZones(
      latitude: position?.latitude,
      longitude: position?.longitude,
      limit: 6,
    );
  }

  Future<void> _loadVehicleTypes() async {
    final types = await ref.read(vehicleTypeServiceProvider).getAll();
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
                        HomeHeader(
                          isDriver: isDriver,
                          unreadCount: _unreadCount,
                          isDriverOnline: _isDriverOnline,
                          onDriverOnlineToggle: _toggleDriverOnline,
                        ),
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
                  child:
                      HomeHeroCard(
                            isDriver: isDriver,
                            nearbyCount: _nearbyCount,
                            unreadCount: _unreadCount,
                            scheduledCount: _scheduledPreview.length,
                            onTap: widget.onViewNearby,
                          )
                          .animate(delay: 100.ms)
                          .fade()
                          .scale(begin: const Offset(0.95, 0.95)),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: MobiActionRow(
                    items: [
                      MobiActionItem(
                        icon: LucideIcons.mapPin,
                        label: 'Nearby',
                        accent: Theme.of(context).colorScheme.primary,
                        onTap: widget.onViewNearby,
                      ),
                      MobiActionItem(
                        icon: LucideIcons.calendarCheck,
                        label: 'Schedule',
                        accent: Theme.of(context).colorScheme.secondary,
                        onTap: () => widget.onSchedule?.call(),
                      ),
                    ],
                  ).animate(delay: 200.ms).fade().slideY(begin: 0.1),
                ),
                if (isDriver) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    child: DriverDemandZonesPanel(
                      zones: _demandZones,
                      isLoading: _isLoading,
                      onRefresh: _loadData,
                    ).animate(delay: 250.ms).fade().slideY(begin: 0.08),
                  ),
                ],
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
                    caption: _nearbyCount > 0 ? '$_nearbyCount live' : 'Live',
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
                    caption: _scheduledPreview.isNotEmpty
                        ? '${_scheduledPreview.length} upcoming'
                        : 'Upcoming',
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
                                  child: ScheduledTripCard(trip: trip),
                                ),
                              )
                              .toList()
                              .animate(interval: 100.ms)
                              .fade()
                              .slideY(begin: 0.1),
                        )
                      : AiEmptyState(
                          title: 'No trips yet',
                          icon: LucideIcons.calendar,
                          height: 200,
                          onAction: widget.onSchedule,
                          actionLabel: widget.onSchedule == null
                              ? null
                              : 'Schedule',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
