import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/core/utils/mobio_member_id.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/data/trip_service.dart';
import 'package:mobi_app/features/home/presentation/widgets/home_header.dart';
import 'package:mobi_app/features/home/presentation/widgets/home_hero_card.dart';
import 'package:mobi_app/features/home/presentation/widgets/scheduled_trip_card.dart';
import 'package:mobi_app/features/nearby/application/nearby_providers.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';
import 'package:mobi_app/features/nearby/data/nearby_discovery_service.dart';
import 'package:mobi_app/features/nearby/presentation/widgets/nearby_location_notice.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_app/features/notifications/data/notification_service.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/shared/models/discovery_person.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_action_row.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_motion.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/mobi_visual_theme.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';
import 'package:mobi_shared_types/models/trip.dart';
import 'package:mobi_shared_types/models/vehicle_type.dart';

/// Home (Discover) screen matching the MOBI Revolut-reference design.
class HomeScreen extends ConsumerStatefulWidget {
  final String mode;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<Trip> onChat;
  final ValueChanged<DiscoveryPerson> onChatPerson;
  final ValueChanged<String> onTripDetails;
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
    required this.onChatPerson,
    required this.onTripDetails,
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
  int _loadGeneration = 0;
  int _unreadRevision = 0;
  AccountSnapshot? _viewAccount;
  LocationAccessState _nearbyLocationState = LocationAccessState.granted;
  int _unreadCount = 0;
  List<Trip> _nearbyPreview = [];
  List<DiscoveryPerson> _nearbyPeople = [];
  List<Trip> _scheduledPreview = [];
  List<VehicleTypeModel> _vehicleTypes = [];

  TripService get _tripService => ref.read(tripServiceProvider);

  NotificationService get _notificationService =>
      ref.read(notificationServiceProvider);

  StreamSubscription<AppNotification>? _notifSub;

  AccountSnapshot? _currentAccount() {
    try {
      return AccountContext.capture();
    } on Object {
      return null;
    }
  }

  bool _current(AccountSnapshot? account) =>
      mounted && account != null && AccountContext.isCurrent(account);

  void _onAccountChanged() {
    if (!mounted || SupabaseConfig.isLocalUiPreview) return;
    final account = _currentAccount();
    if (account?.identity == _viewAccount?.identity &&
        account?.generation == _viewAccount?.generation) {
      return;
    }
    _viewAccount = account;
    _loadGeneration++;
    _unreadRevision++;
    setState(() {
      _nearbyPreview = [];
      _nearbyPeople = [];
      _scheduledPreview = [];
      _nearbyCount = 0;
      _unreadCount = 0;
      _isDriverOnline = false;
    });
    unawaited(_disableDriverSharing(showMessage: false));
    unawaited(_loadData());
    unawaited(_loadUnreadCount());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
      return;
    }

    _viewAccount = _currentAccount();
    AccountContext.changes.addListener(_onAccountChanged);
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
    AccountContext.changes.removeListener(_onAccountChanged);
    _loadGeneration++;
    _unreadRevision++;
    _notifSub?.cancel();
    // Do NOT dispose _notificationService — it is a shared singleton
    // managed by MobiShell via Riverpod.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadData());
    }
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
      final account = _currentAccount();
      if (_current(account) && notif.userId == account!.userId) {
        setState(() => _unreadCount++);
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    if (SupabaseConfig.isLocalUiPreview) {
      if (mounted) setState(() => _unreadCount = 1);
      return;
    }

    final account = _currentAccount();
    final revision = ++_unreadRevision;
    if (!_current(account)) return;
    try {
      final count = await _notificationService.getUnreadCount();
      if (_current(account) && revision == _unreadRevision) {
        setState(() => _unreadCount = count);
      }
    } on Object catch (_) {
      // Silently fail — badge is non-critical
    }
  }

  Future<void> _loadData() async {
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
      return;
    }

    final generation = ++_loadGeneration;
    final account = _currentAccount();
    setState(() {
      _isLoading = true;
      _hasError = false;
      _nearbyCount = 0;
      _nearbyPreview = [];
      _nearbyPeople = [];
      _scheduledPreview = [];
    });
    if (!_current(account)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final isDriver = widget.mode == 'driver';
      final (myTrips, scheduled, discovery) = await (
        _tripService.getMyTrips(),
        _tripService.getCounterpartScheduledTrips(widget.mode),
        isDriver
            ? Future<NearbyDiscoveryResult?>.value(null)
            : ref
                  .read(nearbyDiscoveryServiceProvider)
                  .load(
                    vehicleType: _vehicleId == 'all' ? null : _vehicleId,
                    preferCachedLocation: true,
                  ),
      ).wait;
      if (!_current(account) || generation != _loadGeneration) return;
      final onlineDrivers =
          discovery?.drivers
              .map(_personForNearbyDriver)
              .toList(growable: false) ??
          <DiscoveryPerson>[];

      final ownScheduled = myTrips
          .where((t) => t.status == 'active' || t.status == null)
          .take(3)
          .toList();
      final scheduledPreview = isDriver
          ? ownScheduled
          : scheduled.take(3).toList();

      if (mounted) {
        setState(() {
          _nearbyLocationState =
              discovery?.accessState ?? LocationAccessState.granted;
          _nearbyCount = isDriver ? scheduled.length : onlineDrivers.length;
          _nearbyPreview = isDriver ? scheduled.take(3).toList() : [];
          _nearbyPeople = isDriver ? [] : onlineDrivers.take(3).toList();
          _scheduledPreview = scheduledPreview;
          _isLoading = false;
        });
      }
    } on Object catch (_) {
      if (_current(account) && generation == _loadGeneration) {
        setState(() {
          _nearbyCount = 0;
          _nearbyPreview = [];
          _nearbyPeople = [];
          _scheduledPreview = [];
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  DiscoveryPerson _personForNearbyDriver(NearbyDriver driver) {
    return DiscoveryPerson(
      peerId: driver.driverId,
      memberId: displayMobioMemberId(driver.memberId),
      vehicleTypeId: driver.vehicleTypeId,
      distanceKm: driver.distanceKm,
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

    final account = _currentAccount();
    if (!_current(account)) return;
    if (!value) {
      await _disableDriverSharing();
      return;
    }

    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.location(),
    );
    if (!_current(account) ||
        action != PermissionAccessDialogAction.grantAccess) {
      return;
    }

    final granted = await ref
        .read(appPermissionServiceProvider)
        .ensureLocationAccess();
    if (!_current(account)) {
      return;
    }
    if (!granted) {
      _showSnackBar('Live location sharing was not enabled.', isError: true);
      setState(() => _isDriverOnline = false);
      return;
    }

    bool started;
    try {
      started = await ref.read(driverLocationSharingServiceProvider).start();
    } on MutationOutcomeUnknownException {
      if (!_current(account)) return;
      setState(() => _isDriverOnline = false);
      _showSnackBar(
        'Driver online status could not be confirmed. Check it before trying again.',
        isError: true,
      );
      return;
    } on Object {
      if (!_current(account)) return;
      setState(() => _isDriverOnline = false);
      _showSnackBar(
        'Live location sharing is unavailable right now.',
        isError: true,
      );
      return;
    }
    if (!_current(account)) {
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
    final account = _currentAccount();
    if (SupabaseConfig.isLocalUiPreview) {
      if (mounted) setState(() => _isDriverOnline = false);
      return;
    }

    try {
      await ref.read(driverLocationSharingServiceProvider).stop();
    } on MutationOutcomeUnknownException {
      if (!_current(account)) return;
      setState(() => _isDriverOnline = false);
      if (showMessage) {
        _showSnackBar(
          'Sharing stopped on this device. Server online status could not be confirmed.',
          isError: true,
        );
      }
      return;
    } on Object {
      if (!_current(account)) return;
      setState(() => _isDriverOnline = false);
      if (showMessage) {
        _showSnackBar(
          'Sharing stopped on this device. Check your online status before trying again.',
          isError: true,
        );
      }
      return;
    }
    if (_current(account)) {
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
      _nearbyLocationState = LocationAccessState.granted;
      _nearbyCount = nearby.length;
      _nearbyPreview = isDriver ? nearby : [];
      _nearbyPeople = isDriver
          ? []
          : nearby
                .map(
                  (trip) => DiscoveryPerson(
                    peerId: trip.authorId,
                    memberId: null,
                    vehicleTypeId:
                        trip.effectiveVehicleType == VehicleType.private_
                        ? 'private'
                        : trip.effectiveVehicleType.name,
                    distanceKm: null,
                  ),
                )
                .toList();
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
  Widget build(BuildContext context) =>
      MobiVisualTheme(family: MobiVisualFamily.home, builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final actionToken = AccountActionToken.capture();
    bool current() => mounted && actionToken.isCurrent;
    VoidCallback guarded(VoidCallback action) => () {
      if (current()) action();
    };
    VoidCallback? optional(VoidCallback? action) =>
        action == null ? null : guarded(action);
    Future<void> refresh() async {
      if (current()) await _loadData();
    }

    final cs = Theme.of(context).colorScheme;
    final mediaPadding = MediaQuery.paddingOf(context);
    final isDriver = widget.mode == 'driver';
    final locationUnavailable =
        !isDriver && _nearbyLocationState != LocationAccessState.granted;
    final discoverAction = guarded(
      isDriver
          ? (widget.onViewBookings ?? widget.onViewNearby)
          : widget.onViewNearby,
    );

    return SoftGradient(
      tone: SoftGradientTone.shell,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: refresh,
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
                  child:
                      Column(
                            children: [
                              HomeHeader(
                                isDriver: isDriver,
                                unreadCount: _unreadCount,
                                onModeChanged: (mode) {
                                  if (current()) widget.onModeChanged(mode);
                                },
                                isDriverOnline: _isDriverOnline,
                                onDriverOnlineToggle: (value) {
                                  if (current()) {
                                    unawaited(_toggleDriverOnline(value));
                                  }
                                },
                                onNotifications: optional(
                                  widget.onNotifications,
                                ),
                              ),
                            ],
                          )
                          .animateAccessible(context)
                          .fade(duration: 400.ms)
                          .slideY(begin: -0.1),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child:
                      HomeHeroCard(
                            isDriver: isDriver,
                            nearbyCount:
                                _isLoading || _hasError || locationUnavailable
                                ? null
                                : _nearbyCount,
                            onTap: discoverAction,
                          )
                          .animateAccessible(context, delay: 100.ms)
                          .fade()
                          .scale(begin: const Offset(0.95, 0.95)),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child:
                      MobiActionRow(
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
                                onTap: guarded(() => widget.onSchedule?.call()),
                              ),
                              MobiActionItem(
                                icon: LucideIcons.plugZap,
                                label: 'EV Charger',
                                accent: Theme.of(context).colorScheme.tertiary,
                                onTap: guarded(
                                  () => widget.onEvChargers?.call(),
                                ),
                              ),
                            ],
                          )
                          .animateAccessible(context, delay: 200.ms)
                          .fade()
                          .slideY(begin: 0.1),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child:
                      MobiSurfacePanel(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.sm,
                            ),
                            borderRadius: AppRadii.xxl,
                            child: VehicleFilterChips(
                              selectedId: _vehicleId,
                              onSelected: (id) {
                                if (current()) _switchVehicle(id);
                              },
                              vehicleTypes: _vehicleTypes,
                            ),
                          )
                          .animateAccessible(context, delay: 300.ms)
                          .fade()
                          .slideX(begin: 0.1),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: MobiSectionHeader(
                    title: isDriver ? 'Passenger requests' : 'Nearby',
                    caption: _isLoading
                        ? 'Loading'
                        : _hasError
                        ? 'Unavailable'
                        : locationUnavailable
                        ? needsNearbyLocationPermission(_nearbyLocationState)
                              ? 'Location needed'
                              : 'Location unavailable'
                        : _nearbyCount > 0
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
                          onRetry: refresh,
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
                      : locationUnavailable
                      ? NearbyLocationNotice(
                          accessState: _nearbyLocationState,
                          onEnableLocation: guarded(widget.onViewNearby),
                          onRetry: refresh,
                        )
                      : _nearbyPeople.isNotEmpty
                      ? Column(
                          children: _nearbyPeople
                              .map(
                                (person) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DriverCard.person(
                                    person: person,
                                    onChat: guarded(
                                      () => widget.onChatPerson(person),
                                    ),
                                  ),
                                ),
                              )
                              .toList()
                              .animateAccessible(context, interval: 100.ms)
                              .fade()
                              .slideY(begin: 0.1),
                        )
                      : _nearbyPreview.isNotEmpty
                      ? Column(
                          children: _nearbyPreview
                              .map(
                                (trip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DriverCard(
                                    trip: trip,
                                    onChat: guarded(() => widget.onChat(trip)),
                                  ),
                                ),
                              )
                              .toList()
                              .animateAccessible(context, interval: 100.ms)
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
                    onAction: guarded(() => widget.onViewBookings?.call()),
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
                                  child: ScheduledTripCard(
                                    trip: trip,
                                    onTap: trip.id?.isNotEmpty == true
                                        ? guarded(
                                            () =>
                                                widget.onTripDetails(trip.id!),
                                          )
                                        : null,
                                  ),
                                ),
                              )
                              .toList()
                              .animateAccessible(context, interval: 100.ms)
                              .fade()
                              .slideY(begin: 0.1),
                        )
                      : AiEmptyState(
                          title: 'No scheduled trips yet',
                          icon: LucideIcons.calendar,
                          height: 200,
                          onAction: optional(widget.onSchedule),
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
