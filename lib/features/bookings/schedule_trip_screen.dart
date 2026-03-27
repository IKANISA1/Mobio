import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/ai_content_service.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/location_service.dart';
import 'package:mobi_app/core/services/places_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/models/route_info.dart';
import 'package:mobi_app/models/vehicle_type.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/place_autocomplete_field.dart';
import 'package:mobi_app/shared/widgets/route_map_card.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

/// Schedule Trip screen with route preview map.
class ScheduleTripScreen extends StatefulWidget {
  final String mode;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onBack;

  const ScheduleTripScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onBack,
  });

  @override
  State<ScheduleTripScreen> createState() => _ScheduleTripScreenState();
}

class _ScheduleTripScreenState extends State<ScheduleTripScreen> {
  VehicleType _vehicle = VehicleType.cab;
  PlaceDetails? _originDetails;
  PlaceDetails? _destDetails;
  RouteInfo? _routeInfo;
  bool _isComputingRoute = false;
  bool _isSubmitting = false;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _isRecurring = false;
  final List<int> _recurringDays = [];
  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final _placesService = PlacesService();
  final _tripService = TripService();
  final _locationService = LocationService();
  final _noteController = TextEditingController();
  bool _showErrors = false;
  bool _isLoadingLocation = false;

  /// Cached user lat/lng for proximity-biased autocomplete.
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Requests location permission (with pre-prompt dialog) and caches position
  /// for proximity-biased autocomplete. Graceful: autocomplete works without it.
  Future<void> _initLocation() async {
    // Check if already granted (no dialog needed)
    final alreadyGranted = await AppPermissionService.instance
        .hasLocationAccess();

    if (!alreadyGranted && mounted) {
      // Show pre-prompt dialog before system dialog
      final action = await PermissionAccessDialog.show(
        context,
        config: PermissionAccessDialogConfig.location(),
      );
      if (action != PermissionAccessDialogAction.grantAccess) {
        return; // User declined — autocomplete still works, just no proximity
      }
    }

    // Try to get position (will request system permission if needed)
    final position =
        await _locationService.getLastKnownOrCached() ??
        await _locationService.getCurrentPosition();

    if (mounted && position != null) {
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });
    }
  }

  /// Fetches the user's current GPS position and reverse-geocodes it.
  Future<void> _handleCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    HapticFeedback.lightImpact();

    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access location. Check permissions.'),
            ),
          );
        }
        return;
      }

      final details = await _placesService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted && details != null) {
        _onOriginSelected(details);
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get current location.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _onOriginSelected(PlaceDetails? details) {
    setState(() => _originDetails = details);
    _tryComputeRoute();
  }

  void _onDestSelected(PlaceDetails? details) {
    setState(() => _destDetails = details);
    _tryComputeRoute();
  }

  Future<void> _tryComputeRoute() async {
    if (_originDetails == null || _destDetails == null) {
      setState(() => _routeInfo = null);
      return;
    }

    // Skip if both locations are at 0,0 (no real coordinates)
    if (_originDetails!.latitude == 0 && _originDetails!.longitude == 0) return;
    if (_destDetails!.latitude == 0 && _destDetails!.longitude == 0) return;

    setState(() => _isComputingRoute = true);

    final route = await _placesService.computeRoute(
      originLat: _originDetails!.latitude,
      originLng: _originDetails!.longitude,
      destLat: _destDetails!.latitude,
      destLng: _destDetails!.longitude,
    );

    if (mounted) {
      setState(() {
        _routeInfo = route;
        _isComputingRoute = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    // Validate required fields
    if (_originDetails == null || _destDetails == null) {
      setState(() => _showErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select both departure and destination locations.',
          ),
        ),
      );
      return;
    }
    setState(() => _showErrors = false);

    // Validate date is not in the past
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (selectedDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip date and time must be in the future.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _tripService.createTrip(
        origin: _originDetails!.formattedAddress,
        originLat: _originDetails!.latitude != 0
            ? _originDetails!.latitude
            : null,
        originLng: _originDetails!.longitude != 0
            ? _originDetails!.longitude
            : null,
        destination: _destDetails!.formattedAddress,
        destLat: _destDetails!.latitude != 0 ? _destDetails!.latitude : null,
        destLng: _destDetails!.longitude != 0 ? _destDetails!.longitude : null,
        departureDate: DateFormat('yyyy-MM-dd').format(_date),
        departureTime:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        role: widget.mode,
        vehicleType: _vehicle.name == 'private_' ? 'private' : _vehicle.name,
        isRecurring: _isRecurring,
        recurringDays: _recurringDays,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Trip scheduled successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onBack();
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule trip: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SoftGradient(
        category: PromoCategory.scheduledTrips,
        visibilityMode: SoftGradientVisibilityMode.reading,
        allowMotion: true,
        child: Column(
          children: [
            // Glass header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: MobiSurfacePanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  borderRadius: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TappableIconButton(
                        icon: LucideIcons.chevronLeft,
                        onTap: widget.onBack,
                      ),
                      Text(
                        'SCHEDULE',
                        style: AppTypography.labelLg.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Icon(
                        LucideIcons.moreVertical,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  32,
                  16,
                  32,
                  136 + mediaPadding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Passenger/Driver toggle
                    MobiSurfacePanel(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 32,
                      child: MobiToggle(
                        labels: const ['Passenger', 'Driver'],
                        selectedIndex: widget.mode == 'passenger' ? 0 : 1,
                        onChanged: (i) => widget.onModeChanged(
                          i == 0 ? 'passenger' : 'driver',
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // FROM + GPS button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlaceAutocompleteField(
                          label: 'FROM',
                          initialValue: _originDetails?.formattedAddress ?? '',
                          placeholder: 'Enter departure location',
                          onPlaceSelected: _onOriginSelected,
                          userLat: _userLat,
                          userLng: _userLng,
                          iconBg: _showErrors && _originDetails == null
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                          iconColor: _showErrors && _originDetails == null
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                          icon: LucideIcons.mapPin,
                          trailing: Tooltip(
                            message: 'Use current location',
                            child: InkWell(
                              onTap: _isLoadingLocation
                                  ? null
                                  : _handleCurrentLocation,
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: _isLoadingLocation
                                    ? Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      )
                                    : Icon(
                                        LucideIcons.crosshair,
                                        size: 18,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        if (_showErrors && _originDetails == null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 6),
                            child: Text(
                              'Required',
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // TO
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlaceAutocompleteField(
                          label: 'TO',
                          initialValue: _destDetails?.formattedAddress ?? '',
                          placeholder: 'Enter destination',
                          onPlaceSelected: _onDestSelected,
                          userLat: _userLat,
                          userLng: _userLng,
                          iconBg: _showErrors && _destDetails == null
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                          iconColor: _showErrors && _destDetails == null
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                          icon: LucideIcons.flag,
                        ),
                        if (_showErrors && _destDetails == null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 6),
                            child: Text(
                              'Required',
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Route map preview (shown when both locations selected)
                    if (_isComputingRoute)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    else if (_originDetails != null &&
                        _destDetails != null &&
                        _originDetails!.latitude != 0 &&
                        _destDetails!.latitude != 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: RouteMapCard(
                          originLat: _originDetails!.latitude,
                          originLng: _originDetails!.longitude,
                          destLat: _destDetails!.latitude,
                          destLng: _destDetails!.longitude,
                          originLabel: _originDetails!.formattedAddress,
                          destLabel: _destDetails!.formattedAddress,
                          routeInfo: _routeInfo,
                          height: 180,
                        ),
                      ),

                    // Date
                    _buildTapCard(
                      label: 'Departure Date',
                      value: DateFormat('MMM dd, yyyy').format(_date),
                      icon: LucideIcons.calendar,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Time
                    _buildTapCard(
                      label: 'Departure Time',
                      value: _time.format(context),
                      icon: LucideIcons.clock,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Recurring
                    ClayCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _isRecurring
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Theme.of(context)
                                            .extension<MobiThemeExtension>()!
                                            .surfaceContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.refreshCw,
                                  size: 24,
                                  color: _isRecurring
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RECURRING TRIP',
                                      style: AppTypography.labelSm,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Repeat',
                                      style: AppTypography.titleLg,
                                    ),
                                  ],
                                ),
                              ),
                              Semantics(
                                label: 'Toggle recurring trip',
                                toggled: _isRecurring,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(
                                      () => _isRecurring = !_isRecurring,
                                    );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 48,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _isRecurring
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(context)
                                                .extension<
                                                  MobiThemeExtension
                                                >()!
                                                .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      alignment: _isRecurring
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .extension<MobiThemeExtension>()!
                                              .surfaceContainerLowest,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isRecurring) ...[
                            const SizedBox(height: 16),
                            Divider(
                              color: Theme.of(context)
                                  .extension<MobiThemeExtension>()!
                                  .surfaceContainer,
                              height: 1,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (idx) {
                                final isSelected = _recurringDays.contains(idx);
                                final dayNames = [
                                  'Monday',
                                  'Tuesday',
                                  'Wednesday',
                                  'Thursday',
                                  'Friday',
                                  'Saturday',
                                  'Sunday',
                                ];
                                return Semantics(
                                  label:
                                      '${dayNames[idx]}${isSelected ? ", selected" : ""}',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (isSelected) {
                                          _recurringDays.remove(idx);
                                        } else {
                                          _recurringDays.add(idx);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(context)
                                                  .extension<
                                                    MobiThemeExtension
                                                  >()!
                                                  .surfaceContainer,
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _dayLabels[idx],
                                          style: AppTypography.labelSm.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Vehicle Type
                    Text('VEHICLE TYPE', style: AppTypography.labelSm),
                    const SizedBox(height: 12),
                    _buildVehicleGrid(),
                    const SizedBox(height: 24),

                    // Optional Note
                    Text('OPTIONAL NOTE', style: AppTypography.labelSm),
                    const SizedBox(height: 12),
                    ClayCard(
                      padding: const EdgeInsets.all(32),
                      child: TextField(
                        controller: _noteController,
                        maxLines: 3,
                        style: AppTypography.titleMd,
                        decoration: InputDecoration(
                          hintText:
                              'Additional requirements or flight details...',
                          hintStyle: AppTypography.titleMd.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.3),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Continue button
                    MobiButton(
                      width: double.infinity,
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'CONTINUE',
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  LucideIcons.arrowRight,
                                  size: 24,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).extension<MobiThemeExtension>()!.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppTypography.labelSm),
              const SizedBox(height: 4),
              Text(value, style: AppTypography.titleLg),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleGrid() {
    final types = [
      (VehicleType.moto, 'Moto', LucideIcons.zap),
      (VehicleType.cab, 'Cab', LucideIcons.car),
      (VehicleType.trike, 'Trike', LucideIcons.truck),
      (VehicleType.truck, 'Truck', LucideIcons.layoutGrid),
      (VehicleType.private_, 'Private', LucideIcons.shield),
    ];

    return Row(
      children: types.map((entry) {
        final (type, label, icon) = entry;
        final isSelected = _vehicle == type;
        return Expanded(
          child: Semantics(
            label: '$label vehicle type${isSelected ? ", selected" : ""}',
            child: Tooltip(
              message: label,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _vehicle = type);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryFixed
                              : Theme.of(context)
                                    .extension<MobiThemeExtension>()!
                                    .surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 24,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimaryFixed
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryFixed
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
