import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_post_providers.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_posts.dart';
import 'package:mobi_app/features/bookings/data/trip_service.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';
import 'package:mobi_app/shared/widgets/mobi_info_chip.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_app/shared/widgets/route_map_card.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/trip.dart';
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

  bool _reviewSelected = false;
  ReviewScheduledPostGateway? _reviewGateway;
  ReviewScheduledPostIntent? _reviewIntent;
  bool _reviewRefreshQueued = false;

  ScheduledPostUiAction _actionToken() => _reviewSelected
      ? ScheduledPostUiAction.review(_reviewGateway, _reviewIntent)
      : ScheduledPostUiAction.ordinary(AccountActionToken.capture());

  void _onReviewChanged() {
    if (!mounted) return;
    if (_reviewIntent == null ||
        _reviewGateway?.isCurrent(_reviewIntent!) != true) {
      _loadRevision++;
      _reviewIntent = null;
      _trip = null;
      _isLoading = true;
    }
    if (_reviewRefreshQueued) return;
    _reviewRefreshQueued = true;
    scheduleMicrotask(() {
      _reviewRefreshQueued = false;
      if (mounted) unawaited(_loadTrip());
    });
  }

  int _loadRevision = 0;
  AccountSnapshot? _viewAccount;
  Trip? _trip;
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reviewSelected = ref.read(reviewScheduledPostsSelectedProvider);
    _reviewGateway = _reviewSelected
        ? ref.read(reviewScheduledPostGatewayProvider)
        : null;
    _reviewGateway?.addListener(_onReviewChanged);
    _viewAccount = _currentAccount();
    AccountContext.changes.addListener(_onAccountChanged);
    unawaited(_loadTrip());
  }

  AccountSnapshot? _currentAccount() {
    if (_reviewSelected) return null;
    if (!SupabaseConfig.isConfigured || SupabaseConfig.isLocalUiPreview) {
      return null;
    }
    try {
      return AccountContext.capture();
    } on Object {
      return null;
    }
  }

  void _onAccountChanged() {
    if (!mounted) return;
    if (_reviewSelected) {
      _onReviewChanged();
      return;
    }
    final current = _currentAccount();
    if (current?.identity == _viewAccount?.identity &&
        current?.generation == _viewAccount?.generation) {
      return;
    }
    _viewAccount = current;
    unawaited(_loadTrip());
  }

  @override
  void dispose() {
    AccountContext.changes.removeListener(_onAccountChanged);
    _reviewGateway?.removeListener(_onReviewChanged);
    _loadRevision++;
    super.dispose();
  }

  Future<void> _loadTrip() async {
    if (_reviewSelected) {
      _loadReviewTrip();
      return;
    }

    final revision = ++_loadRevision;
    final account = _currentAccount();
    setState(() {
      _isLoading = true;
      _error = null;
      _trip = null;
    });

    try {
      final trip = SupabaseConfig.isLocalUiPreview
          ? _previewTrip(widget.tripId)
          : await _tripService.getTripById(widget.tripId);
      if (mounted &&
          revision == _loadRevision &&
          (account == null || AccountContext.isCurrent(account))) {
        setState(() {
          _trip = trip;
          _isLoading = false;
          if (trip == null) _error = 'Trip not found.';
        });
      }
    } on Object catch (error) {
      if (mounted &&
          revision == _loadRevision &&
          (account == null || AccountContext.isCurrent(account))) {
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

  void _loadReviewTrip() {
    final revision = ++_loadRevision;
    try {
      final gateway = requireReviewScheduledPosts(_reviewGateway);
      final intent = gateway.capture(targetId: widget.tripId);
      final trip = gateway.get(intent);
      if (!mounted || revision != _loadRevision || !gateway.isCurrent(intent))
        return;
      setState(() {
        _reviewIntent = intent;
        _trip = trip;
        _isLoading = false;
        _error = null;
      });
    } on Object {
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _reviewIntent = null;
        _trip = null;
        _isLoading = false;
        _error = 'This post is unavailable in the current session.';
      });
    }
  }

  Trip? _previewTrip(String id) {
    for (final trip in AppConstants.mockTrips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  Future<void> _handleReviewCancel(ScheduledPostUiAction action) async {
    final gateway = action.gateway;
    final intent = action.intent;
    if (gateway == null || intent == null || !action.isCurrent) return;
    final confirmed = await MobiConfirmDialog.show(
      context: context,
      title: 'Cancel trip?',
      body: 'This cannot be undone.',
      confirmLabel: 'Cancel trip',
      isDestructive: true,
    );
    if (!mounted || confirmed != true || !action.isCurrent) return;
    setState(() => _isCancelling = true);
    try {
      gateway.cancel(intent);
      if (!mounted || !action.hasAuthority) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip cancelled.')));
      widget.onBack();
    } on Object {
      if (mounted && action.hasAuthority) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This post changed. Refresh before cancelling it.'),
          ),
        );
      }
    } finally {
      if (mounted && action.hasAuthority) setState(() => _isCancelling = false);
    }
  }

  Future<void> _handleCancel(
    ScheduledPostUiAction actionToken,
    Trip trip,
  ) async {
    if (!mounted || !actionToken.isCurrent) return;
    if (_reviewSelected) {
      await _handleReviewCancel(actionToken);
      return;
    }
    final account = _currentAccount();
    if (!SupabaseConfig.isLocalUiPreview && account == null) return;
    final confirmed = await MobiConfirmDialog.show(
      context: context,
      title: 'Cancel trip?',
      body: 'This cannot be undone.',
      confirmLabel: 'Cancel trip',
      isDestructive: true,
    );

    if (!mounted ||
        !actionToken.isCurrent ||
        !confirmed ||
        trip.id == null ||
        (account != null && !AccountContext.isCurrent(account))) {
      return;
    }

    setState(() => _isCancelling = true);

    try {
      await _tripService.cancelTrip(trip.id!);
      if (mounted &&
          actionToken.isCurrent &&
          (account == null || AccountContext.isCurrent(account))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Trip cancelled.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onBack();
      }
    } on Object catch (e) {
      if (mounted &&
          actionToken.isCurrent &&
          (account == null || AccountContext.isCurrent(account))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userMessageForError(e, fallback: 'Unable to cancel trip.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted &&
          actionToken.isCurrent &&
          (account == null || AccountContext.isCurrent(account))) {
        setState(() => _isCancelling = false);
      }
    }
  }

  void _openChat(ScheduledPostUiAction actionToken, Trip trip) {
    if (!mounted || !actionToken.isCurrent) return;
    if (_reviewSelected && _reviewGateway?.chatAvailable != true) return;
    final currentUserId = _currentUserIdForChat();
    if (trip.id == null || currentUserId == null) {
      return;
    }

    final query = <String, String>{'tripId': trip.id!};

    if (trip.authorId != currentUserId) {
      query['peerId'] = trip.authorId;
    }

    context.push(Uri(path: '/chat', queryParameters: query).toString());
  }

  String? _currentUserIdForChat() {
    if (_reviewSelected) {
      final intent = _reviewIntent;
      return intent != null &&
              _reviewGateway?.hasCurrentAuthority(intent) == true
          ? intent.actorId
          : null;
    }
    if (SupabaseConfig.isLocalUiPreview) {
      return 'preview-user';
    }
    return SupabaseConfig.isConfigured
        ? Supabase.instance.client.auth.currentUser?.id
        : null;
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
      case 'bus':
        return LucideIcons.bus;
      case 'trike':
        return LucideIcons.truck;
      case 'truck':
        return LucideIcons.layoutGrid;
      case 'private':
        return LucideIcons.shield;
      case 'rentals':
        return LucideIcons.keyRound;
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
    final actionToken = _actionToken();
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: MobiErrorState(
          title: _error ?? 'Something went wrong',
          onRetry: () {
            if (mounted && actionToken.isCurrent) unawaited(_loadTrip());
          },
          height: 280,
        ),
      ),
    );
  }

  Widget _buildContent() {
    final actionToken = _actionToken();
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
    final currentUserId = _currentUserIdForChat();
    final isTripOwner = currentUserId != null && trip.authorId == currentUserId;
    final canChat =
        currentUserId != null &&
        trip.id?.isNotEmpty == true &&
        (!_reviewSelected || _reviewGateway?.chatAvailable == true);
    final contactLabel = trip.whatsapp.trim().isNotEmpty
        ? trip.whatsapp.trim()
        : 'In-app chat';

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${trip.origin} → ${trip.destination}',
              textAlign: TextAlign.center,
              style: AppTypography.displayMd.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 34,
                height: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: [
                if (isCancelled)
                  const MobiStatusBadge(
                    label: 'Cancelled',
                    tone: MobiStatusBadgeTone.danger,
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
            const SizedBox(height: AppSpacing.xl),

            MobiTonalCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderRadius: AppRadii.xxl,
              child: Column(
                children: [
                  _TripDetailFactRow(
                    icon: LucideIcons.mapPin,
                    label: 'Pick up',
                    value: trip.origin,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _TripDetailFactRow(
                    icon: LucideIcons.flag,
                    label: 'Drop off',
                    value: trip.destination,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _TripDetailFactRow(
                    icon: LucideIcons.clock3,
                    label: 'Timing',
                    value: [
                      if (trip.departureDate.isNotEmpty) trip.departureDate,
                      timeDisplay,
                    ].join(' · '),
                  ),
                  const Divider(height: AppSpacing.lg),
                  _TripDetailFactRow(
                    icon: LucideIcons.armchair,
                    label: 'Seats',
                    value: trip.seats.toString(),
                  ),
                  const Divider(height: AppSpacing.lg),
                  _TripDetailFactRow(
                    icon: LucideIcons.messageCircle,
                    label: 'Contact',
                    value: contactLabel,
                  ),
                  if (trip.isRecurring && trip.recurringDays.isNotEmpty) ...[
                    const Divider(height: AppSpacing.lg),
                    _TripDetailFactRow(
                      icon: LucideIcons.refreshCw,
                      label: 'Repeat',
                      value: _formatDays(trip.recurringDays),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

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
                  originPlaceId: trip.originPlaceId,
                  destPlaceId: trip.destinationPlaceId,
                  height: 200,
                  allowExternalMap: !_reviewSelected,
                ),
              ),

            // Note
            if (trip.note != null && trip.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MobiTonalCard(
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

            // Marketplace notice — compact
            MobiTonalCard(
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
                  Expanded(
                    child: Text(
                      'Coordinate pick up, timing, luggage, and seats directly via chat.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Chat button
            MobiButton(
              width: double.infinity,
              onPressed: canChat ? () => _openChat(actionToken, trip) : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.messageCircle,
                    size: 20,
                    color: cs.onInverseSurface,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isTripOwner ? 'Chats' : 'Chat',
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onInverseSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (isTripOwner && !isCancelled) ...[
              MobiButton(
                width: double.infinity,
                variant: MobiButtonVariant.ghost,
                onPressed: () {
                  if (!mounted || !actionToken.isCurrent) return;
                  final tripId = trip.id;
                  if (tripId == null || tripId.isEmpty) {
                    return;
                  }
                  context.push('/trip/$tripId/edit');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.pencil, size: 18, color: cs.onSurface),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Edit trip',
                      style: AppTypography.labelLg.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Cancel trip
            if (isTripOwner && !isCancelled)
              Center(
                child: TextButton(
                  onPressed: _isCancelling
                      ? null
                      : () => _handleCancel(actionToken, trip),
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

class _TripDetailFactRow extends StatelessWidget {
  const _TripDetailFactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSm.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '—' : value,
                style: AppTypography.bodyMd.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
