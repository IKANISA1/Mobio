import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/trip_service.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_info_chip.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/route_map_card.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Trip Details screen — loads real data from TripService.
class TripDetailsScreen extends ConsumerStatefulWidget {
  final String tripId;
  final VoidCallback onBack;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    required this.onBack,
  });

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  TripService get _tripService => ref.read(tripServiceProvider);

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
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = userMessageForError(
            error,
            fallback: 'Unable to load trip details.',
          );
        });
      }
    }
  }

  Future<void> _handleCancel() async {
    final confirmed = await MobiConfirmDialog.show(
      context: context,
      title: 'Cancel trip?',
      body: 'This cannot be undone.',
      confirmLabel: 'Cancel trip',
      isDestructive: true,
    );

    if (!confirmed || _trip?.id == null) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userMessageForError(e, fallback: 'Unable to cancel trip.'),
            ),
          ),
        );
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
        child: Column(
          children: [
            // Header — compact via MobiPageHeader
            SafeArea(
              bottom: false,
              child: MobiPageHeader(title: 'Trip', onBack: widget.onBack),
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeleton(height: 32, width: 120),
            SizedBox(height: AppSpacing.md),
            LoadingSkeleton(height: 80),
            SizedBox(height: AppSpacing.xl),
            LoadingSkeleton(height: 260),
            SizedBox(height: AppSpacing.xl),
            LoadingSkeleton(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: MobiErrorState(
          title: _error ?? 'Something went wrong',
          onRetry: _loadTrip,
          height: 280,
        ),
      ),
    );
  }

  Widget _buildContent() {
    final trip = _trip!;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final hasCoords = (trip.originLat ?? 0) != 0 && (trip.destLat ?? 0) != 0;
    final timeDisplay = trip.departureTime.isNotEmpty
        ? trip.departureTime
        : trip.time.isNotEmpty
        ? trip.time
        : '—';
    final isCancelled = trip.status == 'cancelled';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isTripOwner = currentUserId != null && trip.authorId == currentUserId;

    return Expanded(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route map
            if (hasCoords)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
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

            // Status + metadata chips
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                MobiStatusBadge(
                  label: trip.status ?? 'active',
                  tone: isCancelled
                      ? MobiStatusBadgeTone.danger
                      : MobiStatusBadgeTone.positive,
                ),
                MobiInfoChip(
                  label: trip.vehicleTypeStr,
                  icon: _vehicleIcon(trip.vehicleTypeStr),
                ),
                MobiInfoChip(label: _formatTripId(trip.id)),
                if (trip.isRecurring)
                  const MobiInfoChip(
                    label: 'Recurring',
                    icon: LucideIcons.refreshCw,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Route text — compact
            Text(
              '${trip.origin} → ${trip.destination}',
              style: AppTypography.titleLg.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Main details card — simplified
            Hero(
              tag: 'trip_card_${trip.id ?? trip.hashCode}',
              child: Material(
                type: MaterialType.transparency,
                child: ClayCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  borderRadius: AppRadii.hero,
                  child: Column(
                    children: [
                      // Departure time — prominent
                      Row(
                        children: [
                          Icon(LucideIcons.clock, size: 18, color: cs.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Departure',
                            style: AppTypography.labelMd.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          timeDisplay,
                          style: AppTypography.headlineLg.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (trip.departureDate.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            trip.departureDate,
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],

                      // Recurring days
                      if (trip.isRecurring &&
                          trip.recurringDays.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Divider(color: ext.surfaceContainer, height: 1),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.refreshCw,
                              size: 16,
                              color: cs.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _formatDays(trip.recurringDays),
                                style: AppTypography.bodySm.copyWith(
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
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Note
            if (trip.note != null && trip.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ClayCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  borderRadius: AppRadii.xxl,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.stickyNote,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          trip.note!,
                          style: AppTypography.bodySm.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Expiry notice — compact
            ClayCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderRadius: AppRadii.xxl,
              color: ext.surfaceContainerLow,
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Expires in 60m',
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Chat button
            MobiButton(
              width: double.infinity,
              onPressed: _openChat,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.messageCircle,
                    size: 20,
                    color: cs.onPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isTripOwner ? 'Chats' : 'Chat',
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Cancel trip
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
                            color: cs.error,
                          ),
                        )
                      : Text(
                          'Cancel trip',
                          style: AppTypography.labelLg.copyWith(
                            color: cs.error,
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
