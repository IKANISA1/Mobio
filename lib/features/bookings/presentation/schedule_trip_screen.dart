import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_provider.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_mode_selector.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_repeat_picker.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_route_form.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_timing_picker.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_vehicle_grid.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_async_state_view.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_state_banner.dart';
import 'package:mobi_app/shared/widgets/permission_access_dialog.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_shared_types/models/trip.dart';

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
  bool _isNoteExpanded = false;
  bool _didRequestInitialPickupLocation = false;

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
      final state = ref.read(scheduleTripProvider).value;
      final trip = await controller.submitTrip(
        note: _submissionNote(state, _noteController.text),
      );
      if (trip != null) {
        final scheduleState = ref.read(scheduleTripProvider).value;
        final suggestions = scheduleState?.poolSuggestions ?? const [];
        if (suggestions.isNotEmpty) {
          await _showScheduledPostSuggestionsSheet(suggestions);
        }
        final poolMessage = scheduleState?.poolSuggestionMessage;
        if (poolMessage != null && poolMessage.isNotEmpty) {
          _showSnackBar(poolMessage);
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

    await MobiBottomSheet.show<void>(
      context: context,
      title: 'Similar scheduled posts',
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    _requestInitialPickupLocationIfNeeded(state, controller);
    final title = state.isEditMode ? 'Edit trip' : 'Schedule';
    final canSubmit = state.canSubmit(DateTime.now());

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
                      if (state.requiresBusAgency) ...[
                        const SizedBox(height: AppSpacing.md),
                        _BusAgencySelector(
                          agencies: state.transportAgencyNames,
                          selectedAgency: state.normalizedBusAgencyName,
                          onSelected: controller.setBusAgencyName,
                        ),
                      ],
                      if (state.requiresVehicleModel) ...[
                        const SizedBox(height: AppSpacing.md),
                        _RentalVehicleModelPicker(
                          selectedModel: state.normalizedRentalVehicleModel,
                          onSelected: controller.setRentalVehicleModel,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      _NoteDisclosure(
                        isExpanded: _isNoteExpanded,
                        controller: _noteController,
                        onToggle: () {
                          setState(() {
                            _isNoteExpanded = !_isNoteExpanded;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      MobiButton(
                        width: double.infinity,
                        onPressed: state.isSubmitting || !canSubmit
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
    _noteController.text = _noteWithoutScheduleMetadata(trip?.note ?? '');
    if (_noteController.text.trim().isNotEmpty) {
      _isNoteExpanded = true;
    }
  }

  void _requestInitialPickupLocationIfNeeded(
    ScheduleTripState state,
    ScheduleTripController controller,
  ) {
    if (_didRequestInitialPickupLocation ||
        state.isEditMode ||
        state.originDetails != null ||
        state.isLoadingLocation) {
      return;
    }

    _didRequestInitialPickupLocation = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final permissionService = ref.read(appPermissionServiceProvider);
      final hasAccess = await permissionService.hasLocationAccess();
      if (hasAccess) {
        return;
      }
      await _handleCurrentLocation(controller);
    });
  }
}

class _NoteDisclosure extends StatelessWidget {
  const _NoteDisclosure({
    required this.isExpanded,
    required this.controller,
    required this.onToggle,
  });

  final bool isExpanded;
  final TextEditingController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          toggled: isExpanded,
          label: 'Note',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ext.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        LucideIcons.stickyNote,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Note',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleLg.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Optional',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ext.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ext.borderSubtle.withValues(
                            alpha: ext.cardBorderAlpha,
                          ),
                        ),
                      ),
                      child: Icon(
                        isExpanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: isExpanded
              ? Padding(
                  key: const ValueKey('note-field'),
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: MobiInputField(
                    label: 'Note',
                    hint: 'Requirements or details',
                    controller: controller,
                    maxLines: 3,
                    keyboardType: TextInputType.text,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('note-collapsed')),
        ),
      ],
    );
  }
}

String _submissionNote(ScheduleTripState? state, String rawNote) {
  final metadata = <String>[];
  final note = _noteWithoutScheduleMetadata(rawNote);
  final busAgency = state?.normalizedBusAgencyName;
  if (state?.requiresBusAgency == true && busAgency != null) {
    metadata.add('Bus agency: $busAgency');
  }
  final rentalModel = state?.normalizedRentalVehicleModel;
  if (state?.requiresVehicleModel == true && rentalModel != null) {
    final label = state?.vehicleId == 'rentals'
        ? 'Rental model'
        : 'Vehicle model';
    metadata.add('$label: $rentalModel');
  }
  if (metadata.isEmpty) return note;
  return note.isEmpty ? metadata.join('\n') : '${metadata.join('\n')}\n$note';
}

String _noteWithoutScheduleMetadata(String note) {
  return note
      .replaceAll(RegExp(r'^Bus agency:\s*.+?\s*\n?', caseSensitive: false), '')
      .replaceAll(
        RegExp(
          r'^(?:Rental model|Vehicle model):\s*(SUV|Sedan|Truck|Van|Bus)\s*\n?',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}

class _BusAgencySelector extends StatelessWidget {
  const _BusAgencySelector({
    required this.agencies,
    required this.selectedAgency,
    required this.onSelected,
  });

  final List<String> agencies;
  final String? selectedAgency;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final selected = selectedAgency?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bus agency',
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: ext.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: ext.borderSubtle.withValues(
                  alpha: ext.surfacePanelBorderAlpha,
                ),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _showAgencyPicker(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected.isEmpty ? 'Select agency' : selected,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd.copyWith(
                          color: selected.isEmpty
                              ? cs.onSurfaceVariant.withValues(alpha: 0.38)
                              : cs.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAgencyPicker(BuildContext context) {
    MobiBottomSheet.show<void>(
      context: context,
      title: 'Select agency',
      maxHeightFraction: 0.78,
      builder: (context) {
        return _BusAgencyPickerSheet(
          agencies: normalizedBusAgencyNames(agencies),
          selectedAgency: selectedAgency ?? '',
          onSelected: (agency) {
            onSelected(agency);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

class _BusAgencyPickerSheet extends StatefulWidget {
  const _BusAgencyPickerSheet({
    required this.agencies,
    required this.selectedAgency,
    required this.onSelected,
  });

  final List<String> agencies;
  final String selectedAgency;
  final ValueChanged<String> onSelected;

  @override
  State<_BusAgencyPickerSheet> createState() => _BusAgencyPickerSheetState();
}

class _BusAgencyPickerSheetState extends State<_BusAgencyPickerSheet> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _query.toLowerCase();
    final filtered = widget.agencies
        .where((agency) => agency.toLowerCase().contains(query))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setState(() => _query = value.trim()),
            style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search agencies',
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              filled: true,
              fillColor: Theme.of(
                context,
              ).extension<MobiThemeExtension>()!.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'No agencies found',
                        style: AppTypography.bodyMd.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                    itemBuilder: (context, index) {
                      final agency = filtered[index];
                      final selected = agency == widget.selectedAgency;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          agency,
                          style: AppTypography.bodyMd.copyWith(
                            color: cs.onSurface,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: selected
                            ? Icon(
                                LucideIcons.check,
                                color: cs.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () => widget.onSelected(agency),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RentalVehicleModelPicker extends StatelessWidget {
  const _RentalVehicleModelPicker({
    required this.selectedModel,
    required this.onSelected,
  });

  final String? selectedModel;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ext.borderSubtle.withValues(alpha: ext.cardBorderAlpha),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vehicle model',
            style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: rentalVehicleModelOptions.map((model) {
              final isSelected = selectedModel == model;
              return Semantics(
                button: true,
                selected: isSelected,
                label: '$model rental model',
                child: Tooltip(
                  message: model,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onSelected(model),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer
                              : ext.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary.withValues(alpha: 0.45)
                                : ext.borderSubtle.withValues(
                                    alpha: ext.cardBorderAlpha,
                                  ),
                          ),
                        ),
                        child: Text(
                          model,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
