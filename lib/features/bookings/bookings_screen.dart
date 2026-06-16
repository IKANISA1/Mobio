import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/vehicle_type_icon.dart';
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
  bool _authRequired = false;
  String? _error;
  List<Trip> _myTrips = [];
  List<Trip> _nearbyTrips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void didUpdateWidget(covariant BookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _loadTrips();
    }
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _authRequired = false;
      _error = null;
    });

    if (SupabaseConfig.isLocalUiPreview) {
      final trips = AppConstants.mockTrips;
      final myRole = widget.mode == 'driver' ? 'driver' : 'passenger';
      final nearbyRole = widget.mode == 'driver' ? 'passenger' : 'driver';
      if (mounted) {
        setState(() {
          _myTrips = trips
              .where((trip) => trip.role == myRole)
              .take(3)
              .map((trip) => trip.copyWith(status: 'active'))
              .toList();
          _nearbyTrips = trips
              .where((trip) => trip.role == nearbyRole)
              .take(4)
              .map((trip) => trip.copyWith(status: 'active'))
              .toList();
          _isLoading = false;
        });
      }
      return;
    }

    final hasSession =
        SupabaseConfig.isConfigured &&
        Supabase.instance.client.auth.currentSession != null;

    if (!hasSession) {
      if (mounted) {
        setState(() {
          _myTrips = [];
          _nearbyTrips = [];
          _isLoading = false;
          _authRequired = true;
        });
      }
      return;
    }

    try {
      final tripService = ref.read(tripServiceProvider);
      final results = await Future.wait([
        tripService.getMyTrips(),
        tripService.getCounterpartScheduledTrips(widget.mode),
      ]);

      if (mounted) {
        setState(() {
          _myTrips = results[0];
          _nearbyTrips = results[1];
          _isLoading = false;
          _authRequired = false;
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
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
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
                      child: Column(
                        children: [
                          Text(
                            'Trips',
                            textAlign: TextAlign.center,
                            style: AppTypography.displayLg.copyWith(
                              color: Colors.white,
                              fontSize: 42,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          MobiSurfacePanel(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            borderRadius: AppRadii.pill,
                            child: MobiToggle(
                              labels: const ['Mine', 'Nearby'],
                              selectedIndex: _activeToggle,
                              onChanged: _switchToggle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.sectionGap),
                  ),

                  // Content
                  if (_isLoading)
                    ..._buildLoadingSlivers()
                  else if (_authRequired)
                    SliverToBoxAdapter(child: _buildAuthRequiredState())
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
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.22),
                    child: InkWell(
                      onTap: widget.onSchedule,
                      customBorder: const CircleBorder(),
                      splashColor: Colors.white.withValues(
                        alpha: ext.pressedWhiteAlpha,
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.plus,
                          size: 24,
                          color: Colors.black,
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
    return List.generate(2, (_) {
      return SliverMainAxisGroup(
        slivers: [
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

  Widget _buildAuthRequiredState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AiEmptyState(
        title: 'Sign in to manage trips',
        icon: LucideIcons.lock,
        height: 260,
        onAction: () => context.go('/login?redirect=/bookings'),
        actionLabel: 'Sign in',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AiEmptyState(
        title: _activeToggle == 0
            ? 'No scheduled trips yet'
            : 'No nearby trips',
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

  Widget _buildTripCard(Trip trip) {
    final isNearby = _activeToggle == 1;
    final route = '${trip.origin} → ${trip.destination}';
    final timeDisplay = trip.departureTime.isNotEmpty
        ? trip.departureTime
        : trip.time;
    final vType = trip.effectiveVehicleType;
    final vehicleTypeId = vType == VehicleType.private_
        ? 'private'
        : vType.name;
    final nearbyLabel = trip.authorId.length >= 6
        ? trip.authorId.substring(0, 6).toUpperCase()
        : AppConstants.getDriverId(trip.authorId);

    String capitalize(String? s) => (s == null || s.isEmpty)
        ? 'Active'
        : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

    final statusLabel = capitalize(trip.status);
    final statusTone = trip.status == 'active'
        ? MobiStatusBadgeTone.positive
        : MobiStatusBadgeTone.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Hero(
        tag: 'trip_card_${trip.id ?? trip.hashCode}',
        child: Material(
          type: MaterialType.transparency,
          child: ClayCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            borderRadius: AppRadii.hero,
            onTap: () => widget.onTripDetails(trip.id ?? ''),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                    ),
                    child: Center(
                      child: VehicleTypeIcon.fromId(
                        vehicleTypeId: vehicleTypeId,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNearby && trip.authorId.isNotEmpty)
                        Text(
                          nearbyLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      Text(
                        route,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$timeDisplay · ${vType.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MobiStatusBadge(label: statusLabel, tone: statusTone),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isNearby && trip.status != 'cancelled')
                          InkWell(
                            onTap: () => _cancelTrip(trip),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 6,
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTypography.labelMd.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        Icon(
                          isNearby
                              ? LucideIcons.messageCircle
                              : LucideIcons.chevronRight,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancelTrip(Trip trip) async {
    if (SupabaseConfig.isLocalUiPreview) {
      if (mounted) {
        setState(() {
          _myTrips = _myTrips.where((item) => item.id != trip.id).toList();
          _nearbyTrips = _nearbyTrips
              .where((item) => item.id != trip.id)
              .toList();
        });
      }
      return;
    }

    final confirmed = await MobiConfirmDialog.show(
      context: context,
      title: 'Cancel trip?',
      body: 'This cannot be undone.',
      confirmLabel: 'Cancel trip',
      isDestructive: true,
    );

    if (confirmed == true && trip.id != null) {
      try {
        await ref.read(tripServiceProvider).cancelTrip(trip.id!);
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
}
