import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:mobi_app/core/services/vehicle_type_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';

/// Nearby screen with list-first browsing.
class NearbyScreen extends StatefulWidget {
  final ValueChanged<Trip> onChat;
  final VoidCallback? onBack;

  const NearbyScreen({super.key, required this.onChat, this.onBack});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  String _vehicleId = 'cab';
  bool _isLoading = true;
  bool _hasError = false;
  double? _userLat;
  final _locationService = LocationService();
  final _driverLocationService = DriverLocationService();
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

  Future<void> _loadVehicleTypes() async {
    final types = await VehicleTypeService().getAll();
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
              id: d.driverId,
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
              price: '${d.distanceKm.toStringAsFixed(1)} km',
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
                    // Header
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      sliver: SliverToBoxAdapter(
                        child: MobiSurfacePanel(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                          borderRadius: 36,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        TappableIconButton(
                                          icon: widget.onBack != null
                                              ? LucideIcons.chevronLeft
                                              : LucideIcons.menu,
                                          onTap: widget.onBack,
                                        ),
                                        const SizedBox(width: 16),
                                        Flexible(
                                          child: Text(
                                            'Nearby',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.headlineMd
                                                .copyWith(color: cs.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.list,
                                          size: 14,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'LIST',
                                          style: AppTypography.labelSm.copyWith(
                                            letterSpacing: 1,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'NEARBY',
                                    style: AppTypography.displayLg.copyWith(
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Location prompt
                    if (_userLat == null && !_isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        sliver: SliverToBoxAdapter(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => AppSettings.openAppSettings(
                                type: AppSettingsType.location,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              splashColor: cs.primary.withValues(alpha: 0.12),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer.withValues(
                                    alpha: 0.94,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: cs.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.mapPin,
                                      size: 18,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Enable location to find drivers near you',
                                        style: AppTypography.bodySm.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      LucideIcons.chevronRight,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Vehicle filter
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverToBoxAdapter(
                        child: MobiSurfacePanel(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          borderRadius: 32,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VEHICLE TYPE',
                                style: AppTypography.labelSm.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              VehicleFilterChips(
                                selectedId: _vehicleId,
                                onSelected: _switchVehicle,
                                vehicleTypes: _vehicleTypes,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // Driver list
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: _hasError
                          ? SliverToBoxAdapter(
                              child: MobiErrorState(
                                title: 'Unable to find drivers',
                                subtitle:
                                    'Pull down to refresh or tap to retry.',
                                icon: LucideIcons.wifiOff,
                                onRetry: _loadLocationAndDrivers,
                                height: 280,
                              ),
                            )
                          : _isLoading
                          ? SliverList.builder(
                              itemCount: 4,
                              itemBuilder: (_, __) => const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: LoadingSkeleton.card(height: 128),
                              ),
                            )
                          : driverTrips.isNotEmpty
                          ? SliverList.builder(
                              itemCount: driverTrips.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DriverCard(
                                  trip: driverTrips[index],
                                  onChat: () =>
                                      widget.onChat(driverTrips[index]),
                                ),
                              ),
                            )
                          : SliverToBoxAdapter(
                              child: AiEmptyState(
                                title: 'No $_vehicleId drivers nearby.',
                                subtitle:
                                    'Try a different vehicle type or check back later.',
                                icon: LucideIcons.mapPin,
                                height: 280,
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
