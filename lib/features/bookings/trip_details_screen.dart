import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/services/ai_content_service.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/route_map_card.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Trip Details screen — loads real data from TripService.
class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  final VoidCallback onBack;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    required this.onBack,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final _tripService = TripService();
  Trip? _trip;
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trip = await _tripService.getTripById(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _isLoading = false;
          if (trip == null) _error = 'Trip not found.';
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load trip details.';
        });
      }
    }
  }

  Future<void> _handleCancel() async {
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

    if (confirmed != true || _trip?.id == null) return;

    setState(() => _isCancelling = true);

    try {
      await _tripService.cancelTrip(_trip!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Trip cancelled.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onBack();
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel trip: $e')));
      }
    }
  }

  void _openChat() {
    final trip = _trip;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (trip == null || trip.id == null || currentUserId == null) {
      return;
    }

    final query = <String, String>{'tripId': trip.id!};

    if (trip.authorId != currentUserId) {
      query['peerId'] = trip.authorId;
    }

    context.push(Uri(path: '/chat', queryParameters: query).toString());
  }

  String _formatTripId(String? id) {
    if (id == null || id.isEmpty) return '#—';
    final short = id.length >= 8
        ? id.substring(0, 8).toUpperCase()
        : id.toUpperCase();
    return '#$short';
  }

  IconData _vehicleIcon(String vehicleTypeStr) {
    switch (vehicleTypeStr) {
      case 'moto':
        return LucideIcons.zap;
      case 'trike':
        return LucideIcons.truck;
      case 'truck':
        return LucideIcons.layoutGrid;
      case 'private':
        return LucideIcons.shield;
      case 'cab':
      default:
        return LucideIcons.car;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).extension<MobiThemeExtension>()!.surfaceContainerLow,
      body: SoftGradient(
        category: PromoCategory.scheduledTrips,
        visibilityMode: SoftGradientVisibilityMode.reading,
        allowMotion: true,
        child: Column(
          children: [
            // Header
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
                        'Trip Details',
                        style: AppTypography.titleLg.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 40), // Balance the back button
                    ],
                  ),
                ),
              ),
            ),

            // Content
            if (_isLoading)
              _buildLoading()
            else if (_error != null)
              _buildError()
            else
              _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Expanded(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeleton(height: 32, width: 120),
            SizedBox(height: 16),
            LoadingSkeleton(height: 80),
            SizedBox(height: 24),
            LoadingSkeleton(height: 260),
            SizedBox(height: 24),
            LoadingSkeleton(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClayCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.alertTriangle,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Something went wrong',
                style: AppTypography.titleMd.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              MobiButton(
                onPressed: widget.onBack,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                child: Text(
                  'GO BACK',
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final trip = _trip!;
    final hasCoords = (trip.originLat ?? 0) != 0 && (trip.destLat ?? 0) != 0;
    final timeDisplay = trip.departureTime.isNotEmpty
        ? trip.departureTime
        : trip.time.isNotEmpty
        ? trip.time
        : '—';
    final statusLabel = (trip.status ?? 'active').toUpperCase();
    final isCancelled = trip.status == 'cancelled';
    final vehicleLabel = trip.vehicleTypeStr.toUpperCase();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isTripOwner = currentUserId != null && trip.authorId == currentUserId;

    return Expanded(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route map (if coordinates available)
            if (hasCoords)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: RouteMapCard(
                  originLat: trip.originLat!,
                  originLng: trip.originLng!,
                  destLat: trip.destLat!,
                  destLng: trip.destLng!,
                  originLabel: trip.origin,
                  destLabel: trip.destination,
                  height: 200,
                ),
              ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isCancelled
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                statusLabel,
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCancelled
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Route name
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${trip.origin.toUpperCase()} TO\n${trip.destination.toUpperCase()}',
                  style: AppTypography.displayLg.copyWith(
                    height: 1.1,
                    letterSpacing: -2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Main details card
            ClayCard(
              padding: const EdgeInsets.all(40),
              borderRadius: 48,
              child: Column(
                children: [
                  // Departure time
                  Text('DEPARTURE TIME', style: AppTypography.labelSm),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timeDisplay,
                        style: AppTypography.displayLg.copyWith(
                          fontSize: 80,
                          letterSpacing: -4,
                          height: 0.9,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Departure date
                  if (trip.departureDate.isNotEmpty)
                    Text(
                      trip.departureDate,
                      style: AppTypography.bodyMd.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Divider
                  Container(
                    width: 200,
                    height: 1,
                    color: Theme.of(
                      context,
                    ).extension<MobiThemeExtension>()!.surfaceContainer,
                  ),
                  const SizedBox(height: 32),

                  // Vehicle + Trip ID
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VEHICLE', style: AppTypography.labelSm),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Icon(
                                    _vehicleIcon(trip.vehicleTypeStr),
                                    size: 24,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  vehicleLabel,
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TRIP ID', style: AppTypography.labelSm),
                            const SizedBox(height: 12),
                            Text(
                              _formatTripId(trip.id),
                              style: AppTypography.titleLg,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Recurring info
                  if (trip.isRecurring && trip.recurringDays.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Theme.of(
                        context,
                      ).extension<MobiThemeExtension>()!.surfaceContainer,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.refreshCw,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Repeats: ${_formatDays(trip.recurringDays)}',
                            style: AppTypography.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Note (if present)
            if (trip.note != null && trip.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ClayCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRIP NOTE', style: AppTypography.labelSm),
                      const SizedBox(height: 8),
                      Text(
                        trip.note!,
                        style: AppTypography.bodyMd.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Expiry notice
            ClayCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 40,
              color: Theme.of(
                context,
              ).extension<MobiThemeExtension>()!.surfaceContainerLow,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expiry notice',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Expires 60m after departure.',
                          style: AppTypography.bodySm.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // In-app chat button
            MobiButton(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              onPressed: _openChat,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.messageCircle,
                    size: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isTripOwner ? 'VIEW TRIP CHATS' : 'OPEN CHAT',
                    style: AppTypography.titleMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cancel trip (only for non-cancelled trips)
            if (!isCancelled)
              Center(
                child: TextButton(
                  onPressed: _isCancelling ? null : _handleCancel,
                  child: _isCancelling
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : Text(
                          'CANCEL TRIP',
                          style: AppTypography.labelLg.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDays(List<int> days) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days
        .where((d) => d >= 0 && d < labels.length)
        .map((d) => labels[d])
        .join(', ');
  }
}
