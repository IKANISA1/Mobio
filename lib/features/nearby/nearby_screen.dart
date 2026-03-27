import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:app_settings/app_settings.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/core/services/ai_content_service.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

/// Nearby screen with list-first browsing.
class NearbyScreen extends StatefulWidget {
  final ValueChanged<Trip> onChat;
  final VoidCallback? onBack;

  const NearbyScreen({super.key, required this.onChat, this.onBack});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  VehicleType _vehicle = VehicleType.cab;
  bool _isLoading = true;
  double? _userLat;
  double? _userLng;
  final _locationService = LocationService();
  final _driverLocationService = DriverLocationService();
  List<NearbyDriver> _nearbyDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadLocationAndDrivers();
  }

  Future<void> _loadLocationAndDrivers() async {
    setState(() => _isLoading = true);

    final position = await _locationService.getCurrentPosition();
    if (mounted && position != null) {
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });

      final drivers = await _driverLocationService.findNearbyDrivers(
        latitude: position.latitude,
        longitude: position.longitude,
        vehicleType: _vehicle.name == 'all' ? null : _vehicle.name,
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
  }

  void _switchVehicle(VehicleType v) {
    setState(() {
      _vehicle = v;
    });
    _loadLocationAndDrivers();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
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
      category: PromoCategory.nearbyDrivers,
      visibilityMode: SoftGradientVisibilityMode.reading,
      allowMotion: true,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 136 + mediaPadding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
                                    style: AppTypography.headlineMd.copyWith(
                                      color: cs.primary,
                                    ),
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
              const SizedBox(height: 16),

              // Location prompt
              if (_userLat == null && !_isLoading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
                          color: cs.primaryContainer.withValues(alpha: 0.94),
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

              // Vehicle filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                        selected: _vehicle,
                        onSelected: _switchVehicle,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Driver list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: _isLoading
                      ? List.generate(
                          4,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: LoadingSkeleton(height: 128),
                          ),
                        )
                      : driverTrips.isNotEmpty
                      ? driverTrips
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
                      : [
                          AiEmptyState(
                            title:
                                'No ${_vehicle.label.toLowerCase()} drivers nearby.',
                            subtitle:
                                'Try a different vehicle type or check back later.',
                            icon: LucideIcons.mapPin,
                            height: 280,
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
