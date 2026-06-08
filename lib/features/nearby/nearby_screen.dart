import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

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

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  String _vehicleId = 'cab';
  bool _isLoading = true;
  bool _hasError = false;
  double? _userLat;
  LocationService get _locationService => ref.read(locationServiceProvider);

  DriverLocationService get _driverLocationService =>
      ref.read(driverLocationServiceProvider);

  List<NearbyDriver> _nearbyDrivers = [];
  List<VehicleTypeModel> _vehicleTypes = [];

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    _loadLocationAndDrivers();
  }

  Future<void> _loadLocationAndDrivers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final hasAccess = await ref
          .read(appPermissionServiceProvider)
          .hasLocationAccess();
      if (!hasAccess) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final position = await _locationService.getCurrentPosition();
      if (mounted && position != null) {
        setState(() {
          _userLat = position.latitude;
        });

        final drivers = await _driverLocationService.findNearbyDrivers(
          latitude: position.latitude,
          longitude: position.longitude,
          vehicleType: _vehicleId == 'all' ? null : _vehicleId,
        );

        if (mounted) {
          setState(() {
            _nearbyDrivers = drivers;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _requestLocationAndReload() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.location(),
    );
    if (action != PermissionAccessDialogAction.grantAccess) {
      return;
    }

    final granted = await permissionService.ensureLocationAccess();
    if (!granted) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    await _loadLocationAndDrivers();
  }

  Future<void> _loadVehicleTypes() async {
    final types = await ref.read(vehicleTypeServiceProvider).getAll();
    if (mounted) setState(() => _vehicleTypes = types);
  }

  void _switchVehicle(String id) {
    setState(() {
      _vehicleId = id;
    });
    _loadLocationAndDrivers();
  }

  @override
  Widget build(BuildContext context) {
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
                    // Header — compact, using MobiPageHeader
                    SliverToBoxAdapter(
                      child: MobiPageHeader(
                        title: 'Nearby',
                        onBack: widget.onBack,
                        showBackButton: widget.onBack != null,
                        trailing: MobiStatusBadge(
                          label: '${driverTrips.length}',
                          icon: LucideIcons.mapPin,
                          tone: driverTrips.isNotEmpty
                              ? MobiStatusBadgeTone.positive
                              : MobiStatusBadgeTone.neutral,
                        ),
                      ).animate().fade(duration: 400.ms).slideY(begin: -0.1),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.md),
                    ),

                    // Location prompt — compact banner
                    if (_userLat == null && !_isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          0,
                          AppSpacing.screenPadding,
                          AppSpacing.md,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: MobiStateBanner(
                            icon: LucideIcons.mapPin,
                            title: 'Enable location',
                            subtitle: 'Find drivers nearby',
                            tone: MobiStateBannerTone.brand,
                            onTap: _requestLocationAndReload,
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
