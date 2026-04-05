import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/ride_request_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
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

  RideRequestService get _rideRequestService => ref.read(rideRequestServiceProvider);

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
          _error = e.toString();
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
                                if (widget.onBack != null)
                                  TappableIconButton(
                                    icon: LucideIcons.chevronLeft,
                                    onTap: widget.onBack,
                                  )
                                else
                                  const TappableIconButton(
                                    icon: LucideIcons.menu,
                                  ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Scheduled',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.headlineMd.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
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
                                  _activeToggle == 0
                                      ? 'My Trips'
                                      : 'Nearby Trips',
                                  style: AppTypography.displayLg,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            MobiToggle(
                              labels: const ['MINE', 'NEARBY'],
                              selectedIndex: _activeToggle,
                              onChanged: _switchToggle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

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
                    elevation: 8,
                    shadowColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                    child: InkWell(
                      onTap: widget.onSchedule,
                      customBorder: const CircleBorder(),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      child: const Center(
                        child: Icon(
                          LucideIcons.plus,
                          size: 28,
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
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
            sliver: SliverToBoxAdapter(child: _buildSectionLabel(section)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.builder(
              itemCount: 2,
              itemBuilder: (_, i) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LoadingSkeleton(height: 192),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    }).toList();
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AiEmptyState(
        title: 'Something went wrong',
        subtitle: 'Pull down to retry.',
        icon: LucideIcons.alertTriangle,
        height: 220,
        onAction: _loadTrips,
        actionLabel: 'RETRY',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AiEmptyState(
        title: _activeToggle == 0
            ? 'No trips scheduled yet.'
            : 'No nearby trips found.',
        subtitle: _activeToggle == 0
            ? 'Tap + to create one.'
            : 'Pull down to refresh.',
        icon: _activeToggle == 0 ? LucideIcons.calendar : LucideIcons.mapPin,
        height: 260,
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
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
            sliver: SliverToBoxAdapter(child: _buildSectionLabel(section)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    }).toList();
  }

  Widget _buildSectionLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return MobiSurfacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 999,
      color: ext.surfaceContainerLowest.withValues(
        alpha: ext.surfacePanelAlpha,
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final isNearby = _activeToggle == 1;
    final route =
        '${trip.origin.toUpperCase()} → ${trip.destination.toUpperCase()}';
    final timeDisplay = trip.departureTime.isNotEmpty
        ? trip.departureTime
        : trip.time;
    final vType = trip.effectiveVehicleType;
    final nearbyLabel = trip.authorId.length >= 6
        ? trip.authorId.substring(0, 6).toUpperCase()
        : AppConstants.getDriverId(trip.authorId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Hero(
        tag: 'trip_card_${trip.id ?? trip.hashCode}',
        child: Material(
          type: MaterialType.transparency,
          child: ClayCard(
            padding: const EdgeInsets.all(32),
            onTap: () => widget.onTripDetails(trip.id ?? ''),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                style: AppTypography.labelSm.copyWith(
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
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.displayMd.copyWith(
                              letterSpacing: -1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isNearby)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.messageCircle,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge(
                      vType.displayName,
                      Theme.of(context).colorScheme.secondaryContainer,
                      Theme.of(context).colorScheme.onSecondaryContainer,
                      icon: getVehicleIcon(vType),
                    ),
                    _badge(
                      trip.status == 'active'
                          ? 'ACTIVE'
                          : (trip.status?.toUpperCase() ?? 'ACTIVE'),
                      trip.status == 'active'
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                      trip.status == 'active'
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Action row
                Container(
                  padding: const EdgeInsets.only(top: 16),
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
                                'CANCEL TRIP',
                                style: AppTypography.labelSm.copyWith(
                                  letterSpacing: 1.5,
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
                                  'DETAILS',
                                  style: AppTypography.labelSm.copyWith(
                                    letterSpacing: 1.5,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(
          context,
        ).extension<MobiThemeExtension>()!.surfaceContainerHigh,
        title: Text('Cancel Trip', style: AppTypography.titleLg),
        content: Text(
          'Are you sure you want to cancel this trip?',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'YES',
              style: AppTypography.titleMd.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to cancel trip: $e')));
        }
      }
    }
  }

  Widget _badge(String text, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 4),
          ],
          Text(text, style: AppTypography.labelSm.copyWith(color: fg)),
        ],
      ),
    );
  }

  /// Builds a "REQUEST" or "OFFER" button for nearby trip cards.
  ///
  /// - If the nearby trip is from a driver → current user (passenger) sees "REQUEST"
  /// - If the nearby trip is from a passenger → current user (driver) sees "OFFER"
  Widget _buildRequestOfferButton(Trip trip) {
    final cs = Theme.of(context).colorScheme;
    final isDriver = trip.role == 'driver';
    final label = isDriver ? 'REQUEST' : 'OFFER';
    final doneLabel = isDriver ? 'REQUESTED' : 'OFFERED';
    final icon = isDriver ? LucideIcons.send : LucideIcons.gift;
    const doneIcon = LucideIcons.checkCircle;
    final isDone = _requestedTripIds.contains(trip.id);

    return Material(
      color: isDone ? cs.primaryContainer : cs.primary,
      borderRadius: BorderRadius.circular(20),
      elevation: isDone ? 0 : 2,
      shadowColor: cs.primary.withValues(alpha: 0.3),
      child: InkWell(
        onTap: isDone ? null : () => _handleRequestOffer(trip),
        borderRadius: BorderRadius.circular(20),
        splashColor: cs.onPrimary.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                style: AppTypography.labelSm.copyWith(
                  letterSpacing: 1,
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

    try {
      if (isDriver) {
        // Current user is passenger, requesting a ride from this driver
        await _rideRequestService.sendRequest(
          responderId: trip.authorId,
          tripId: trip.id,
          metadata: {
            'vehicle_type': trip.vehicleTypeStr,
            'route': '${trip.origin} → ${trip.destination}',
            'source': 'nearby_trips',
          },
        );
      } else {
        // Current user is driver, offering a ride to this passenger
        await _rideRequestService.sendOffer(
          responderId: trip.authorId,
          tripId: trip.id!,
          metadata: {
            'route': '${trip.origin} → ${trip.destination}',
            'source': 'nearby_trips',
          },
        );
      }

      if (mounted) {
        setState(() => _requestedTripIds.add(trip.id!));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDriver ? 'Ride request sent!' : 'Ride offer sent!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
