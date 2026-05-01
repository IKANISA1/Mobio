import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/bookings/models/schedule_trip_state.dart';
import 'package:mobi_app/features/bookings/providers/schedule_trip_provider.dart';
import 'package:mobi_app/features/bookings/widgets/trip_mode_selector.dart';
import 'package:mobi_app/features/bookings/widgets/trip_repeat_picker.dart';
import 'package:mobi_app/features/bookings/widgets/trip_route_form.dart';
import 'package:mobi_app/features/bookings/widgets/trip_timing_picker.dart';
import 'package:mobi_app/features/bookings/widgets/trip_vehicle_grid.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

/// Schedule Trip screen with route preview map.
class ScheduleTripScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ScheduleTripScreen> createState() => _ScheduleTripScreenState();
}

class _ScheduleTripScreenState extends ConsumerState<ScheduleTripScreen> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();

    // Set args immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scheduleTripArgsProvider.notifier).set(widget.mode);
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
      final success = await controller.submitTrip(note: _noteController.text);
      if (success) {
        _showSnackBar('Trip scheduled.');
        widget.onBack();
      } else {
        _showSnackBar('Please complete all required fields.');
      }
    } catch (e) {
      _showSnackBar(
        userMessageForError(
          e,
          fallback: 'Failed to schedule trip. Please try again.',
        ),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(scheduleTripProvider);
    final controller = ref.read(scheduleTripProvider.notifier);
    final mediaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: asyncState.when(
        data: (state) => _buildContent(state, controller, mediaPadding),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(err.toString())),
      ),
    );
  }

  Widget _buildContent(
    ScheduleTripState state,
    ScheduleTripController controller,
    EdgeInsets mediaPadding,
  ) {
    return SoftGradient(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: MobiPageHeader(title: 'Schedule', onBack: widget.onBack),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    routeInfo: state.routeInfo,
                    isComputingRoute: state.isComputingRoute,
                    isLoadingLocation: state.isLoadingLocation,
                    showErrors: state.showErrors,
                    userLat: state.userLat,
                    userLng: state.userLng,
                    onOriginSelected: controller.setOrigin,
                    onDestSelected: controller.setDestination,
                    onHandleCurrentLocation: controller.handleCurrentLocation,
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
                      'Schedule',
                      style: AppTypography.labelLg.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
