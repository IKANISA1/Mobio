import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:mobi_app/core/services/notification_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/features/home/widgets/home_header.dart';
import 'package:mobi_app/features/home/widgets/home_hero_card.dart';
import 'package:mobi_app/features/home/widgets/scheduled_trip_card.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_action_row.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

/// Home (Discover) screen matching the MOBI Revolut-reference design.
class HomeScreen extends ConsumerStatefulWidget {
  final String mode;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<Trip> onChat;
  final VoidCallback onViewNearby;
  final VoidCallback? onViewBookings;
  final VoidCallback? onSchedule;
  final VoidCallback? onEvChargers;
  final VoidCallback? onNotifications;

  const HomeScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onChat,
    required this.onViewNearby,
    this.onViewBookings,
    this.onSchedule,
    this.onEvChargers,
    this.onNotifications,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  String _vehicleId = 'cab';
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDriverOnline = false;
  int _nearbyCount = 0;
  int _unreadCount = 0;
  List<Trip> _nearbyPreview = [];
  List<Trip> _scheduledPreview = [];
  List<VehicleTypeModel> _vehicleTypes = [];

  TripService get _tripService => ref.read(tripServiceProvider);

  LocationService get _locationService => ref.read(locationServiceProvider);

  DriverLocationService get _driverLocationService =>
      ref.read(driverLocationServiceProvider);

  NotificationService get _notificationService =>
      ref.read(notificationServiceProvider);

  StreamSubscription<AppNotification>? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
      return;
    }

    _isDriverOnline = ref.read(driverLocationSharingServiceProvider).isSharing;
    _loadVehicleTypes();
    _loadData();
    _loadUnreadCount();
    _listenForIncomingRequests();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      if (oldWidget.mode == 'driver' && widget.mode != 'driver') {
        unawaited(_disableDriverSharing());
      }
      if (SupabaseConfig.isLocalUiPreview) {
        _loadLocalPreviewData();
      } else {
        unawaited(_loadData());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSub?.cancel();
    // Do NOT dispose _notificationService — it is a shared singleton
    // managed by MobiShell via Riverpod.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(_disableDriverSharing(showMessage: false));
    }
  }

  /// Listens for realtime notifications and updates the unread badge.
  void _listenForIncomingRequests() {
    if (SupabaseConfig.isLocalUiPreview) {
      return;
    }

    _notifSub = _notificationService.onNotification.listen((notif) {
      if (mounted) {
        setState(() => _unreadCount++);
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    if (SupabaseConfig.isLocalUiPreview) {
      if (mounted) setState(() => _unreadCount = 1);
      return;
    }

    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } on Object catch (_) {
      // Silently fail — badge is non-critical
    }
  }

  Future<void> _loadData() async {
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final isDriver = widget.mode == 'driver';
      final myTripsFuture = _tripService.getMyTrips();
      final scheduledFuture = _tripService.getCounterpartScheduledTrips(
        widget.mode,
      );
      final onlineDriversFuture = isDriver
          ? Future<List<Trip>>.value(const [])
          : _loadOnlineDriverTrips();

      final myTrips = await myTripsFuture;
      final scheduled = await scheduledFuture;
      final onlineDrivers = await onlineDriversFuture;

      final ownScheduled = myTrips
          .where((t) => t.status == 'active' || t.status == null)
          .take(3)
          .toList();
      final nearby = isDriver ? scheduled : onlineDrivers;
      final scheduledPreview = isDriver
          ? ownScheduled
          : scheduled.take(3).toList();

      if (mounted) {
        setState(() {
          _nearbyCount = nearby.length;
          _nearbyPreview = nearby.take(3).toList();
          _scheduledPreview = scheduledPreview;
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

  Future<List<Trip>> _loadOnlineDriverTrips() async {
    final hasAccess = await ref
        .read(appPermissionServiceProvider)
        .hasLocationAccess();
    if (!hasAccess) {
      return const [];
    }

    final position =
        await _locationService.getLastKnownOrCached() ??
        await _locationService.getCurrentPosition();
    if (position == null) {
      return const [];
    }

    final drivers = await _driverLocationService.findNearbyDrivers(
      latitude: position.latitude,
      longitude: position.longitude,
      vehicleType: _vehicleId == 'all' ? null : _vehicleId,
      limit: 20,
    );

    return drivers.map(_tripForNearbyDriver).toList(growable: false);
  }

  Trip _tripForNearbyDriver(NearbyDriver driver) {
    return Trip(
      authorId: driver.driverId,
      authorName: driver.memberId,
      origin: 'Nearby',
      destination: '',
      departureDate: '',
      departureTime: '',
      role: 'driver',
      vehicleTypeStr: driver.vehicleTypeId,
      originLat: driver.latitude,
      originLng: driver.longitude,
      description: '${driver.distanceKm.toStringAsFixed(1)} km away',
      status: 'active',
    );
  }

  Future<void> _loadVehicleTypes() async {
    if (SupabaseConfig.isLocalUiPreview) {
      if (mounted) {
        setState(() => _vehicleTypes = VehicleTypeModel.fallbackTypes);
      }
      return;
    }

    final types = await ref.read(vehicleTypeServiceProvider).getAll();
    if (mounted) setState(() => _vehicleTypes = types);
  }

  void _switchVehicle(String id) {
    setState(() => _vehicleId = id);
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
    } else {
      _loadData();
    }
  }

  Future<void> _toggleDriverOnline(bool value) async {
    if (SupabaseConfig.isLocalUiPreview) {
      setState(() => _isDriverOnline = value);
      return;
    }

    if (!value) {
      await _disableDriverSharing();
      return;
    }

    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.backgroundLocation(),
    );
    if (!mounted || action != PermissionAccessDialogAction.grantAccess) {
      return;
    }

    final granted = await ref
        .read(appPermissionServiceProvider)
        .ensureBackgroundLocationAccess();
    if (!mounted) {
      return;
    }
    if (!granted) {
      _showSnackBar('Live location sharing was not enabled.', isError: true);
      setState(() => _isDriverOnline = false);
      return;
    }

    final started = await ref
        .read(driverLocationSharingServiceProvider)
        .start();
    if (!mounted) {
      return;
    }
    setState(() => _isDriverOnline = started);
    if (!started) {
      _showSnackBar(
        'A fresh location is required to go online.',
        isError: true,
      );
      return;
    }
    _showSnackBar('Live driver location sharing is on.');
  }

  Future<void> _disableDriverSharing({bool showMessage = true}) async {
    if (SupabaseConfig.isLocalUiPreview) {
      if (mounted) setState(() => _isDriverOnline = false);
      return;
    }

    await ref.read(driverLocationSharingServiceProvider).stop();
    if (mounted) {
      setState(() => _isDriverOnline = false);
      if (showMessage) {
        _showSnackBar('Live driver location sharing is off.');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _loadLocalPreviewData() {
    final trips = AppConstants.mockTrips;
    final isDriver = widget.mode == 'driver';
    final nearby = trips
        .where(
          (trip) => isDriver ? trip.role == 'passenger' : trip.role == 'driver',
        )
        .where(_matchesSelectedVehicle)
        .take(3)
        .toList();
    final scheduled = trips
        .where(
          (trip) => isDriver ? trip.role == 'driver' : trip.role == 'driver',
        )
        .where((trip) => trip.status == 'active' || trip.status == 'approved')
        .take(3)
        .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _vehicleTypes = VehicleTypeModel.fallbackTypes;
      _nearbyCount = nearby.length;
      _nearbyPreview = nearby;
      _scheduledPreview = scheduled;
      _unreadCount = 1;
      _isLoading = false;
      _hasError = false;
    });
  }

  bool _matchesSelectedVehicle(Trip trip) {
    if (_vehicleId == 'all') {
      return true;
    }

    final type = trip.effectiveVehicleType;
    final id = type == VehicleType.private_ ? 'private' : type.name;
    return id == _vehicleId;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mediaPadding = MediaQuery.paddingOf(context);
    final isDriver = widget.mode == 'driver';
    final discoverAction = isDriver
        ? (widget.onViewBookings ?? widget.onViewNearby)
        : widget.onViewNearby;

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: Column(
                    children: [
                      HomeHeader(
                        isDriver: isDriver,
                        unreadCount: _unreadCount,
                        onModeChanged: widget.onModeChanged,
                        isDriverOnline: _isDriverOnline,
                        onDriverOnlineToggle: (value) =>
                            unawaited(_toggleDriverOnline(value)),
                        onNotifications: widget.onNotifications,
                      ),
                    ],
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
                            onTap: discoverAction,
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
                        icon: isDriver
                            ? LucideIcons.calendarSearch
                            : LucideIcons.mapPin,
                        label: isDriver ? 'Requests' : 'Nearby',
                        accent: Theme.of(context).colorScheme.primary,
                        onTap: discoverAction,
                      ),
                      MobiActionItem(
                        icon: LucideIcons.calendarCheck,
                        label: 'Schedule',
                        accent: Theme.of(context).colorScheme.secondary,
                        onTap: () => widget.onSchedule?.call(),
                      ),
                      MobiActionItem(
                        icon: LucideIcons.plugZap,
                        label: 'EV Charger',
                        accent: Theme.of(context).colorScheme.tertiary,
                        onTap: () => widget.onEvChargers?.call(),
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
                    title: isDriver ? 'Passenger requests' : 'Nearby',
                    caption: _nearbyCount > 0
                        ? isDriver
                              ? '$_nearbyCount scheduled'
                              : '$_nearbyCount live'
                        : isDriver
                        ? 'Scheduled'
                        : 'Live',
                    icon: isDriver
                        ? LucideIcons.calendarSearch
                        : LucideIcons.mapPin,
                    actionLabel: 'All',
                    onAction: discoverAction,
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
                              ? 'No passenger scheduled trips'
                              : 'No drivers nearby',
                          icon: isDriver
                              ? LucideIcons.calendarSearch
                              : LucideIcons.mapPin,
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
                          title: 'No scheduled trips yet',
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
