import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/bookings/models/schedule_trip_state.dart';
import 'package:mobi_app/features/bookings/providers/schedule_trip_provider.dart';
import 'package:mobi_app/features/bookings/widgets/trip_mode_selector.dart';
import 'package:mobi_app/features/bookings/widgets/trip_repeat_picker.dart';
import 'package:mobi_app/features/bookings/widgets/trip_route_form.dart';
import 'package:mobi_app/features/bookings/widgets/trip_timing_picker.dart';
import 'package:mobi_app/features/bookings/widgets/trip_vehicle_grid.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_async_state_view.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

/// Schedule Trip screen with route preview map.
class ScheduleTripScreen extends ConsumerStatefulWidget {
  final String mode;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onBack;
  final String? editingTripId;

  const ScheduleTripScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onBack,
    this.editingTripId,
  });

  @override
  ConsumerState<ScheduleTripScreen> createState() => _ScheduleTripScreenState();
}

class _ScheduleTripScreenState extends ConsumerState<ScheduleTripScreen> {
  late final TextEditingController _noteController;
  String? _noteSyncedTripId;

  bool get _isEditMode => widget.editingTripId?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ref.read(scheduleTripArgsProvider.notifier);
      final editingTripId = widget.editingTripId;
      if (editingTripId != null && editingTripId.isNotEmpty) {
        args.setEditTrip(tripId: editingTripId, mode: widget.mode);
      } else {
        args.setCreateMode(widget.mode);
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _handleSubmit(WidgetRef ref) async {
    final controller = ref.read(scheduleTripProvider.notifier);
    try {
      final trip = await controller.submitTrip(note: _noteController.text);
      if (trip != null) {
        final suggestions =
            ref.read(scheduleTripProvider).value?.poolSuggestions ?? const [];
        if (suggestions.isNotEmpty) {
          await _showScheduledPostSuggestionsSheet(suggestions);
        }
        _showSnackBar(_isEditMode ? 'Trip updated.' : 'Trip scheduled.');
        widget.onBack();
      } else {
        final message =
            ref.read(scheduleTripProvider).value?.validationMessage ??
            'Please complete all required fields.';
        _showSnackBar(message);
      }
    } on Object catch (e) {
      _showSnackBar(
        userMessageForError(
          e,
          fallback: _isEditMode
              ? 'Failed to save changes. Please try again.'
              : 'Failed to schedule trip. Please try again.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _showScheduledPostSuggestionsSheet(
    List<Trip> suggestions,
  ) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Similar scheduled posts',
                  style: AppTypography.headlineSm.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'People with similar route or timing.',
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final trip = suggestions[index];
                      return _PoolSuggestionTile(trip: trip);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCurrentLocation(ScheduleTripController controller) async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final hasAccess = await permissionService.hasLocationAccess();

    if (!hasAccess && mounted) {
      final action = await PermissionAccessDialog.show(
        context,
        config: PermissionAccessDialogConfig.location(),
      );
      if (action != PermissionAccessDialogAction.grantAccess) {
        return;
      }

      final granted = await permissionService.ensureLocationAccess();
      if (!granted) {
        _showSnackBar('Location access was not enabled.', isError: true);
        return;
      }
    }

    await controller.handleCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(scheduleTripProvider);
    final controller = ref.read(scheduleTripProvider.notifier);
    final mediaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: MobiAsyncStateView<ScheduleTripState>(
        value: asyncState,
        data: (state) => _buildContent(state, controller, mediaPadding),
        loading: (_) => _ScheduleTripSkeleton(onBack: widget.onBack),
        errorTitle: 'Unable to load scheduler',
        errorMessageBuilder: (error) => userMessageForError(
          error,
          fallback: 'Trip scheduling is unavailable. Please try again.',
        ),
        onRetry: () => ref.invalidate(scheduleTripProvider),
      ),
    );
  }

  Widget _buildContent(
    ScheduleTripState state,
    ScheduleTripController controller,
    EdgeInsets mediaPadding,
  ) {
    _syncNoteController(state);
    final title = state.isEditMode ? 'Edit trip' : 'Schedule';

    return SoftGradient(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: MobiPageHeader(title: title, onBack: widget.onBack),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                136 + mediaPadding.bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(
                              state.isEditMode ? 'Edit trip' : 'Schedule ride',
                              textAlign: TextAlign.center,
                              style: AppTypography.displayMd.copyWith(
                                color: Colors.white,
                                fontSize: 36,
                                height: 1.08,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Route, timing, and vehicle in one flow',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyLg.copyWith(
                                color: Colors.white.withValues(alpha: 0.74),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      if (state.validationMessage != null) ...[
                        MobiStateBanner(
                          icon: LucideIcons.alertTriangle,
                          title: 'Check trip details',
                          subtitle: state.validationMessage,
                          tone: MobiStateBannerTone.warning,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      TripModeSelector(
                        selectedRole: state.selectedRole,
                        showErrors: state.showErrors,
                        onChanged: (role) {
                          controller.setRole(role);
                          widget.onModeChanged(role);
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TripRouteForm(
                        originDetails: state.originDetails,
                        destDetails: state.destDetails,
                        isLoadingLocation: state.isLoadingLocation,
                        showErrors: state.showErrors,
                        userLat: state.userLat,
                        userLng: state.userLng,
                        favoriteAddresses: state.favoriteAddresses,
                        isSavingFavoriteAddress: state.isSavingFavoriteAddress,
                        onOriginSelected: controller.setOrigin,
                        onDestSelected: controller.setDestination,
                        onHandleCurrentLocation: () =>
                            unawaited(_handleCurrentLocation(controller)),
                        onFavoriteOriginSelected:
                            controller.useFavoriteAsOrigin,
                        onFavoriteDestSelected:
                            controller.useFavoriteAsDestination,
                        onSaveFavoriteAddress: controller.saveFavoriteAddress,
                        onDeleteFavoriteAddress:
                            controller.deleteFavoriteAddress,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TripTimingPicker(
                        date: state.date,
                        time: state.time,
                        onDateChanged: controller.setDate,
                        onTimeChanged: controller.setTime,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TripRepeatPicker(
                        isRecurring: state.isRecurring,
                        recurringDays: state.recurringDays,
                        onToggleRecurring: controller.toggleRecurring,
                        onToggleDay: controller.toggleRecurringDay,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TripVehicleGrid(
                        vehicleTypes: state.vehicleTypes,
                        selectedVehicleId: state.vehicleId,
                        onSelected: controller.setVehicleId,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const MobiSectionHeader(
                        title: 'Note',
                        caption: 'Optional',
                        icon: LucideIcons.stickyNote,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      MobiInputField(
                        label: 'Note',
                        hint: 'Requirements or details',
                        controller: _noteController,
                        maxLines: 3,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      MobiButton(
                        width: double.infinity,
                        onPressed: state.isSubmitting
                            ? null
                            : () => _handleSubmit(ref),
                        isLoading: state.isSubmitting,
                        child: Text(
                          state.isEditMode ? 'Save changes' : 'Schedule',
                          style: AppTypography.labelLg.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(
                              context,
                            ).colorScheme.onInverseSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _syncNoteController(ScheduleTripState state) {
    final trip = state.editingTrip;
    final tripId = trip?.id;
    if (tripId == null || _noteSyncedTripId == tripId) {
      return;
    }

    _noteSyncedTripId = tripId;
    _noteController.text = trip?.note ?? '';
  }
}

class _ScheduleTripSkeleton extends StatelessWidget {
  const _ScheduleTripSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SoftGradient(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: MobiPageHeader(title: 'Schedule', onBack: onBack),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 136),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LoadingSkeleton(height: 84, borderRadius: 28),
                      SizedBox(height: AppSpacing.xl),
                      LoadingSkeleton(height: 220, borderRadius: 32),
                      SizedBox(height: AppSpacing.xl),
                      LoadingSkeleton(height: 132, borderRadius: 32),
                      SizedBox(height: AppSpacing.xl),
                      LoadingSkeleton(height: 180, borderRadius: 32),
                      SizedBox(height: AppSpacing.xl),
                      LoadingSkeleton(height: 92, borderRadius: 32),
                      SizedBox(height: AppSpacing.xxl),
                      LoadingSkeleton.button(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoolSuggestionTile extends StatelessWidget {
  const _PoolSuggestionTile({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  trip.role == 'driver' ? LucideIcons.car : LucideIcons.users,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    trip.authorName.isEmpty ? 'Nearby trip' : trip.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                  ),
                ),
                Text(
                  trip.departureTime,
                  style: AppTypography.labelMd.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${trip.origin} -> ${trip.destination}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
            ),
            if (trip.note?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                trip.note!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm.copyWith(color: cs.onSurface),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
