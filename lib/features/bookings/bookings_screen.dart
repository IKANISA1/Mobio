import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/ride_request_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_info_chip.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bookings screen with live data from TripService.
class BookingsScreen extends ConsumerStatefulWidget {
  final String mode;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onSchedule;
  final ValueChanged<String> onTripDetails;
  final VoidCallback? onBack;

  const BookingsScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onSchedule,
    required this.onTripDetails,
    this.onBack,
  });

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  int _activeToggle = 0; // 0 = mine, 1 = nearby
  bool _isLoading = true;
  String? _error;
  List<Trip> _myTrips = [];
  List<Trip> _nearbyTrips = [];
  TripService get _tripService => ref.read(tripServiceProvider);

  RideRequestService get _rideRequestService =>
      ref.read(rideRequestServiceProvider);

  final Set<String> _requestedTripIds = {};

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final hasSession =
        SupabaseConfig.isConfigured &&
        Supabase.instance.client.auth.currentSession != null;

    if (!hasSession) {
      if (mounted) {
        setState(() {
          _myTrips = [];
          _nearbyTrips = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final results = await Future.wait([
        _tripService.getMyTrips(),
        _tripService.getNearbyTrips(),
      ]);

      if (mounted) {
        setState(() {
          _myTrips = results[0];
          _nearbyTrips = results[1];
          _isLoading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = userMessageForError(
            e,
            fallback: 'Unable to load trips right now.',
          );
        });
      }
    }
  }

  void _switchToggle(int index) {
    setState(() => _activeToggle = index);
  }

  List<Trip> get _currentTrips => _activeToggle == 0 ? _myTrips : _nearbyTrips;

  /// Groups trips into TODAY, TOMORROW, LATER sections based on departure_date.
  Map<String, List<Trip>> _groupTrips(List<Trip> trips) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final grouped = <String, List<Trip>>{
      'TODAY': [],
      'TOMORROW': [],
      'LATER': [],
    };

    for (final trip in trips) {
      DateTime? tripDate;
      try {
        tripDate = DateTime.tryParse(trip.departureDate);
      } on Object catch (_) {}

      if (tripDate == null) {
        grouped['LATER']!.add(trip);
        continue;
      }

      final tripDay = DateTime(tripDate.year, tripDate.month, tripDate.day);
      if (tripDay.isAtSameMomentAs(today)) {
        grouped['TODAY']!.add(trip);
      } else if (tripDay.isAtSameMomentAs(tomorrow)) {
        grouped['TOMORROW']!.add(trip);
      } else {
        grouped['LATER']!.add(trip);
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final grouped = _groupTrips(_currentTrips);

    return SoftGradient(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadTrips,
              color: Theme.of(context).colorScheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                      AppSpacing.screenPadding,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: MobiSurfacePanel(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        borderRadius: AppRadii.hero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (widget.onBack != null)
                                  TappableIconButton(
                                    icon: LucideIcons.chevronLeft,
                                    onTap: widget.onBack,
                                  )
                                else
                                  const TappableIconButton(
                                    icon: LucideIcons.menu,
                                  ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    'Trips',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.titleLg.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                MobiStatusBadge(
                                  label: '${_currentTrips.length}',
                                  icon: _activeToggle == 0
                                      ? LucideIcons.calendarCheck
                                      : LucideIcons.mapPin,
                                  tone: MobiStatusBadgeTone.brand,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            MobiToggle(
                              labels: const ['Mine', 'Nearby'],
                              selectedIndex: _activeToggle,
                              onChanged: _switchToggle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.sectionGap),
                  ),

                  // Content
                  if (_isLoading)
                    ..._buildLoadingSlivers()
                  else if (_error != null)
                    SliverToBoxAdapter(child: _buildErrorState())
                  else if (_currentTrips.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else
                    ..._buildTripSlivers(grouped),

                  SliverPadding(
                    padding: EdgeInsets.only(bottom: 176 + mediaPadding.bottom),
                  ),
                ],
              ),
            ),

            // FAB
            Positioned(
              bottom: 112 + mediaPadding.bottom,
              right: 32,
              child: Semantics(
                button: true,
                label: 'Schedule new trip',
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.18),
                    child: InkWell(
                      onTap: widget.onSchedule,
                      customBorder: const CircleBorder(),
                      splashColor: Colors.white.withValues(alpha: 0.12),
                      child: const Center(
                        child: Icon(
                          LucideIcons.plus,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLoadingSlivers() {
    return ['TODAY', 'TOMORROW'].map((section) {
      return SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(
              left: AppSpacing.screenPadding,
              right: AppSpacing.screenPadding,
              bottom: AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(child: _buildSectionLabel(section)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            sliver: SliverList.builder(
              itemCount: 2,
              itemBuilder: (_, i) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LoadingSkeleton(height: 192),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      );
    }).toList();
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: MobiErrorState(
        title: 'Unable to load trips',
        subtitle: _error,
        icon: LucideIcons.alertTriangle,
        onRetry: _loadTrips,
        height: 220,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AiEmptyState(
        title: _activeToggle == 0 ? 'No trips yet' : 'No nearby trips',
        icon: _activeToggle == 0 ? LucideIcons.calendar : LucideIcons.mapPin,
        height: 260,
        onAction: _activeToggle == 0 ? widget.onSchedule : _loadTrips,
        actionLabel: _activeToggle == 0 ? 'Schedule' : 'Refresh',
      ),
    );
  }

  List<Widget> _buildTripSlivers(Map<String, List<Trip>> grouped) {
    return ['TODAY', 'TOMORROW', 'LATER'].map((section) {
      final sectionTrips = grouped[section] ?? [];
      if (sectionTrips.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      return SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(
              left: AppSpacing.screenPadding,
              right: AppSpacing.screenPadding,
              bottom: AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(child: _buildSectionLabel(section)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            sliver: SliverList.builder(
              itemCount: sectionTrips.length,
              itemBuilder: (context, index) {
                final content = _buildTripCard(sectionTrips[index]);
                if (MediaQuery.disableAnimationsOf(context)) {
                  return content;
                }
                return content
                    .animate(delay: (100 + index * 50).ms)
                    .fade(duration: 350.ms)
                    .slideY(
                      begin: 0.1,
                      duration: 350.ms,
                      curve: Curves.easeOutQuad,
                    );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      );
    }).toList();
  }

  Widget _buildSectionLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return MobiSurfacePanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      borderRadius: AppRadii.pill,
      color: ext.surfaceContainerLowest.withValues(
        alpha: ext.surfacePanelAlpha,
      ),
      child: Text(switch (label) {
        'TODAY' => 'Today',
        'TOMORROW' => 'Tomorrow',
        _ => 'Later',
      }, style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant)),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final isNearby = _activeToggle == 1;
    final route = '${trip.origin} → ${trip.destination}';
    final timeDisplay = trip.departureTime.isNotEmpty
        ? trip.departureTime
        : trip.time;
    final vType = trip.effectiveVehicleType;
    final nearbyLabel = trip.authorId.length >= 6
        ? trip.authorId.substring(0, 6).toUpperCase()
        : AppConstants.getDriverId(trip.authorId);

    String capitalize(String? s) => (s == null || s.isEmpty)
        ? 'Active'
        : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Hero(
        tag: 'trip_card_${trip.id ?? trip.hashCode}',
        child: Material(
          type: MaterialType.transparency,
          child: ClayCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            onTap: () => widget.onTripDetails(trip.id ?? ''),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNearby && trip.authorId.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                nearbyLabel,
                                style: AppTypography.labelMd.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          Text(
                            route,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleLg.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      isNearby
                          ? LucideIcons.messageCircle
                          : LucideIcons.chevronRight,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    MobiInfoChip(label: timeDisplay, icon: LucideIcons.clock),
                    MobiStatusBadge(
                      label: vType.displayName,
                      icon: getVehicleIcon(vType),
                      tone: MobiStatusBadgeTone.info,
                    ),
                    MobiStatusBadge(
                      label: capitalize(trip.status),
                      tone: trip.status == 'active'
                          ? MobiStatusBadgeTone.positive
                          : MobiStatusBadgeTone.danger,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(
                          context,
                        ).extension<MobiThemeExtension>()!.surfaceContainer,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isNearby && trip.status != 'cancelled')
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _cancelTrip(trip),
                            borderRadius: BorderRadius.circular(24),
                            splashColor: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTypography.labelLg.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (isNearby && trip.id != null)
                        _buildRequestOfferButton(trip)
                      else
                        const SizedBox.shrink(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onTripDetails(trip.id ?? ''),
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Details',
                                  style: AppTypography.labelLg.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  LucideIcons.arrowRight,
                                  size: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Future<void> _cancelTrip(Trip trip) async {
    final confirmed = await MobiConfirmDialog.show(
      context: context,
      title: 'Cancel trip?',
      body: 'This cannot be undone.',
      confirmLabel: 'Cancel trip',
      isDestructive: true,
    );

    if (confirmed == true && trip.id != null) {
      try {
        await _tripService.cancelTrip(trip.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Trip cancelled.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          _loadTrips(); // Refresh
        }
      } on Object catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                userMessageForError(
                  e,
                  fallback: 'Failed to cancel trip. Please try again.',
                ),
              ),
            ),
          );
        }
      }
    }
  }

  Widget _buildRequestOfferButton(Trip trip) {
    final cs = Theme.of(context).colorScheme;
    final isDriver = trip.role == 'driver';
    final label = isDriver ? 'Request' : 'Offer';
    final doneLabel = isDriver ? 'Requested' : 'Offered';
    final icon = isDriver ? LucideIcons.send : LucideIcons.gift;
    const doneIcon = LucideIcons.checkCircle;
    final isDone = _requestedTripIds.contains(trip.id);

    return Material(
      color: isDone ? cs.primaryContainer : cs.primary,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: isDone ? null : () => _handleRequestOffer(trip),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        splashColor: cs.onPrimary.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDone ? doneIcon : icon,
                size: 14,
                color: isDone ? cs.primary : cs.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                isDone ? doneLabel : label,
                style: AppTypography.labelLg.copyWith(
                  color: isDone ? cs.primary : cs.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRequestOffer(Trip trip) async {
    final isDriver = trip.role == 'driver';
    final tripId = trip.id;

    try {
      if (isDriver) {
        // Current user is passenger, requesting a ride from this driver
        await _rideRequestService.sendRequest(
          responderId: trip.authorId,
          tripId: tripId,
          metadata: {
            'vehicle_type': trip.vehicleTypeStr,
            'route': '${trip.origin} → ${trip.destination}',
            'source': 'nearby_trips',
          },
        );
      } else {
        // Current user is driver, offering a ride to this passenger
        if (tripId == null) {
          throw Exception('Cannot offer a ride to a trip without an ID.');
        }
        await _rideRequestService.sendOffer(
          responderId: trip.authorId,
          tripId: tripId,
          metadata: {
            'route': '${trip.origin} → ${trip.destination}',
            'source': 'nearby_trips',
          },
        );
      }

      if (mounted && tripId != null) {
        setState(() => _requestedTripIds.add(tripId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDriver ? 'Ride request sent!' : 'Ride offer sent!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userMessageForError(
                e,
                fallback: 'Unable to send the ride request right now.',
              ),
            ),
          ),
        );
      }
    }
  }
}
