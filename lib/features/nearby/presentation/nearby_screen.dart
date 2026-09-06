import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/location/google_maps_deep_link_service.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/features/nearby/application/nearby_providers.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';
import 'package:mobi_app/features/nearby/presentation/widgets/nearby_location_notice.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/mobi_top_command_bar.dart';
import 'package:mobi_app/shared/widgets/mobi_visual_theme.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';
import 'package:mobi_shared_types/models/trip.dart';
import 'package:mobi_shared_types/models/vehicle_type.dart';

/// Nearby screen with list-first browsing.
class NearbyScreen extends ConsumerStatefulWidget {
  final ValueChanged<Trip> onChat;
  final ValueChanged<String> onTripDetails;
  final VoidCallback? onBack;

  const NearbyScreen({
    super.key,
    required this.onChat,
    required this.onTripDetails,
    this.onBack,
  });

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen>
    with WidgetsBindingObserver {
  String _vehicleId = 'cab';
  bool _isLoading = true;
  bool _hasError = false;
  int _loadGeneration = 0;
  LocationAccessState _locationState = LocationAccessState.granted;
  double? _userLat;
  double? _userLng;
  List<NearbyDriver> _nearbyDrivers = [];
  List<VehicleTypeModel> _vehicleTypes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
      return;
    }

    _loadVehicleTypes();
    _loadLocationAndDrivers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadLocationAndDrivers());
    }
  }

  Future<void> _loadLocationAndDrivers() async {
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
      return;
    }

    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _userLat = null;
      _userLng = null;
      _nearbyDrivers = [];
    });

    try {
      final result = await ref
          .read(nearbyDiscoveryServiceProvider)
          .load(vehicleType: _vehicleId == 'all' ? null : _vehicleId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _locationState = result.accessState;
        _userLat = result.latitude;
        _userLng = result.longitude;
        _nearbyDrivers = result.drivers;
        _isLoading = false;
      });
    } on Object catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _requestLocationAndReload() async {
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
      return;
    }

    final permissionService = ref.read(appPermissionServiceProvider);
    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.location(),
    );
    if (action != PermissionAccessDialogAction.grantAccess) {
      return;
    }

    await permissionService.ensureLocationAccess();
    if (!mounted) return;
    await _loadLocationAndDrivers();
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
    setState(() {
      _vehicleId = id;
    });
    if (SupabaseConfig.isLocalUiPreview) {
      _loadLocalPreviewData();
    } else {
      _loadLocationAndDrivers();
    }
  }

  void _loadLocalPreviewData() {
    final source = AppConstants.mockTrips
        .where((trip) => trip.role == 'driver')
        .where(_matchesSelectedVehicle)
        .take(5)
        .toList();
    final drivers = <NearbyDriver>[];

    for (var i = 0; i < source.length; i++) {
      final trip = source[i];
      final type = trip.effectiveVehicleType;
      drivers.add(
        NearbyDriver(
          driverId: trip.authorId,
          memberId: AppConstants.getDriverId(trip.authorId),
          vehicleTypeId: type == VehicleType.private_ ? 'private' : type.name,
          latitude: trip.originLat ?? -1.9441,
          longitude: trip.originLng ?? 30.0619,
          distanceKm: 0.4 + (i * 0.35),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _vehicleTypes = VehicleTypeModel.fallbackTypes;
      _locationState = LocationAccessState.granted;
      _nearbyDrivers = drivers;
      _userLat = -1.9441;
      _userLng = 30.0619;
      _isLoading = false;
      _hasError = false;
    });
  }

  Future<void> _openDriversInGoogleMaps() async {
    final userLat = _userLat;
    final userLng = _userLng;
    if (userLat == null || userLng == null || _nearbyDrivers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No driver locations available.')),
      );
      return;
    }

    final opened = await GoogleMapsDeepLinkService.openNearbyDriverLocations(
      originLat: userLat,
      originLng: userLng,
      drivers: _nearbyDrivers.map(
        (driver) => GoogleMapsLocation(
          latitude: driver.latitude,
          longitude: driver.longitude,
          label: driver.memberId,
        ),
      ),
    );
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open Google Maps.')),
    );
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
  Widget build(BuildContext context) => MobiVisualTheme(
    family: MobiVisualFamily.payments,
    builder: _buildContent,
  );

  Widget _buildContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mediaPadding = MediaQuery.paddingOf(context);

    final List<Trip> driverTrips;
    if (_nearbyDrivers.isNotEmpty) {
      driverTrips = _nearbyDrivers
          .map(
            (d) => Trip(
              id: null,
              authorId: d.driverId,
              authorName: '',
              origin: 'Nearby',
              destination: '',
              departureDate: '',
              departureTime: '',
              role: 'driver',
              vehicleTypeStr: d.vehicleTypeId,
              originLat: d.latitude,
              originLng: d.longitude,
              description: '${d.distanceKm.toStringAsFixed(1)} km away',
            ),
          )
          .toList();
    } else {
      driverTrips = [];
    }

    return SoftGradient(
      tone: SoftGradientTone.nearby,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: _loadLocationAndDrivers,
          color: cs.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(bottom: 136 + mediaPadding.bottom),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          AppSpacing.md,
                          AppSpacing.screenPadding,
                          0,
                        ),
                        child: Column(
                          children: [
                            MobiTopCommandBar(
                              searchHint: 'Search nearby',
                              showSearch: false,
                              actions: [
                                MobiTopCommandBarAction(
                                  icon: LucideIcons.map,
                                  label: 'Drivers map',
                                  onTap: _openDriversInGoogleMaps,
                                ),
                                MobiTopCommandBarAction(
                                  icon: widget.onBack == null
                                      ? LucideIcons.slidersHorizontal
                                      : LucideIcons.arrowLeft,
                                  label: widget.onBack == null
                                      ? 'Filters'
                                      : 'Back',
                                  onTap: widget.onBack,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Find a ride nearby',
                              textAlign: TextAlign.center,
                              style: AppTypography.displayLg.copyWith(
                                color: Colors.white,
                                fontSize: 40,
                                height: 1.08,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 400.ms).slideY(begin: -0.1),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.md),
                    ),

                    // Location prompt — compact banner
                    if (_locationState != LocationAccessState.granted &&
                        !_isLoading &&
                        !_hasError)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          0,
                          AppSpacing.screenPadding,
                          AppSpacing.md,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: NearbyLocationNotice(
                            accessState: _locationState,
                            onEnableLocation: _requestLocationAndReload,
                            onRetry: _loadLocationAndDrivers,
                          ).animate(delay: 50.ms).fade().slideX(begin: 1.0),
                        ),
                      ),

                    // Vehicle filter — compact, no label
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                      ),
                      sliver: SliverToBoxAdapter(
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
                        ).animate(delay: 100.ms).fade().slideX(begin: 0.1),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sectionGap),
                    ),

                    // Driver list
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                      ),
                      sliver: _hasError
                          ? SliverToBoxAdapter(
                              child: MobiErrorState(
                                title: 'Load failed',
                                icon: LucideIcons.wifiOff,
                                onRetry: _loadLocationAndDrivers,
                                height: 240,
                              ),
                            )
                          : _isLoading
                          ? SliverList.builder(
                              itemCount: 4,
                              itemBuilder: (_, i) => const Padding(
                                padding: EdgeInsets.only(bottom: AppSpacing.md),
                                child: LoadingSkeleton.card(height: 128),
                              ),
                            )
                          : _locationState != LocationAccessState.granted
                          ? const SliverToBoxAdapter(child: SizedBox.shrink())
                          : driverTrips.isNotEmpty
                          ? SliverList.builder(
                              itemCount: driverTrips.length,
                              itemBuilder: (context, index) {
                                final driverTrip = driverTrips[index];
                                final card = DriverCard(
                                  trip: driverTrip,
                                  onChat: () => widget.onChat(driverTrip),
                                  onTap: driverTrip.id != null
                                      ? () =>
                                            widget.onTripDetails(driverTrip.id!)
                                      : null,
                                );

                                if (MediaQuery.disableAnimationsOf(context)) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md,
                                    ),
                                    child: card,
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: card
                                      .animate(delay: (150 + index * 50).ms)
                                      .fade()
                                      .slideY(begin: 0.1),
                                );
                              },
                            )
                          : const SliverToBoxAdapter(
                              child: AiEmptyState(
                                title: 'No drivers nearby',
                                icon: LucideIcons.mapPin,
                                height: 240,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
