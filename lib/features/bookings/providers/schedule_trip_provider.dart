import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/features/bookings/models/schedule_trip_state.dart';
import 'package:mobi_app/models/place.dart';

/// Provider for schedule arguments (mode).
class ScheduleTripArgsNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? mode) => state = mode;
}

final scheduleTripArgsProvider =
    NotifierProvider<ScheduleTripArgsNotifier, String?>(
      ScheduleTripArgsNotifier.new,
    );

final scheduleTripProvider =
    AsyncNotifierProvider.autoDispose<
      ScheduleTripController,
      ScheduleTripState
    >(ScheduleTripController.new);

class ScheduleTripController extends AsyncNotifier<ScheduleTripState> {
  @override
  FutureOr<ScheduleTripState> build() async {
    final mode = ref.watch(scheduleTripArgsProvider);

    // Load vehicle types immediately
    final vt = await ref.read(vehicleTypeServiceProvider).getAll();

    // Initial state with role from argument if provided
    final initialState = ScheduleTripState(
      vehicleTypes: vt,
      selectedRole: mode,
    );

    // Bootstrap location in background
    unawaited(_initLocation());

    return initialState;
  }

  Future<void> _initLocation() async {
    final hasAccess = await AppPermissionService.instance.hasLocationAccess();
    if (!hasAccess) return;

    final locationService = ref.read(locationServiceProvider);
    final position =
        await locationService.getLastKnownOrCached() ??
        await locationService.getCurrentPosition();

    if (position != null) {
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(
          currentState.copyWith(
            userLat: position.latitude,
            userLng: position.longitude,
          ),
        );
      }
    }
  }

  Future<void> handleCurrentLocation() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(isLoadingLocation: true));
    HapticFeedback.lightImpact();

    try {
      final locationService = ref.read(locationServiceProvider);
      final placesService = ref.read(placesServiceProvider);

      final position = await locationService.getCurrentPosition();
      if (position == null) {
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(current.copyWith(isLoadingLocation: false));
        }
        return;
      }

      final details = await placesService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (details != null) {
        setOrigin(details);
      }
    } catch (_) {
    } finally {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isLoadingLocation: false));
      }
    }
  }

  void setOrigin(PlaceDetails? details) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(originDetails: details));
    unawaited(_tryComputeRoute());
  }

  void setDestination(PlaceDetails? details) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(destDetails: details));
    unawaited(_tryComputeRoute());
  }

  void setVehicleId(String id) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(vehicleId: id));
  }

  void setRole(String role) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(selectedRole: role));
  }

  void setDate(DateTime date) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(date: date));
  }

  void setTime(TimeOfDay time) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(time: time));
  }

  void toggleRecurring() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(isRecurring: !currentState.isRecurring),
    );
  }

  void toggleRecurringDay(int dayIndex) {
    final currentState = state.value;
    if (currentState == null) return;

    final current = List<int>.from(currentState.recurringDays);
    if (current.contains(dayIndex)) {
      current.remove(dayIndex);
    } else {
      current.add(dayIndex);
    }
    state = AsyncValue.data(currentState.copyWith(recurringDays: current));
  }

  Future<void> _tryComputeRoute() async {
    final s = state.value;
    if (s == null || s.originDetails == null || s.destDetails == null) {
      if (s != null) {
        state = AsyncValue.data(s.copyWith(routeInfo: null));
      }
      return;
    }

    if (s.originDetails!.latitude == 0 || s.destDetails!.latitude == 0) return;

    state = AsyncValue.data(s.copyWith(isComputingRoute: true));

    try {
      final route = await ref
          .read(placesServiceProvider)
          .computeRoute(
            originLat: s.originDetails!.latitude,
            originLng: s.originDetails!.longitude,
            destLat: s.destDetails!.latitude,
            destLng: s.destDetails!.longitude,
          );
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(routeInfo: route, isComputingRoute: false),
        );
      }
    } catch (e) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(routeInfo: null, isComputingRoute: false),
        );
      }
    }
  }

  Future<bool> submitTrip({required String note}) async {
    final s = state.value;
    if (s == null) return false;

    if (s.selectedRole == null ||
        s.originDetails == null ||
        s.destDetails == null) {
      state = AsyncValue.data(s.copyWith(showErrors: true));
      return false;
    }

    final selectedDateTime = DateTime(
      s.date.year,
      s.date.month,
      s.date.day,
      s.time.hour,
      s.time.minute,
    );

    if (selectedDateTime.isBefore(DateTime.now())) {
      return false;
    }

    state = AsyncValue.data(s.copyWith(isSubmitting: true, showErrors: false));

    try {
      await ref
          .read(tripServiceProvider)
          .createTrip(
            origin: s.originDetails!.formattedAddress,
            originLat: s.originDetails!.latitude != 0
                ? s.originDetails!.latitude
                : null,
            originLng: s.originDetails!.longitude != 0
                ? s.originDetails!.longitude
                : null,
            destination: s.destDetails!.formattedAddress,
            destLat: s.destDetails!.latitude != 0
                ? s.destDetails!.latitude
                : null,
            destLng: s.destDetails!.longitude != 0
                ? s.destDetails!.longitude
                : null,
            departureDate: DateFormat('yyyy-MM-dd').format(s.date),
            departureTime:
                '${s.time.hour.toString().padLeft(2, '0')}:${s.time.minute.toString().padLeft(2, '0')}',
            role: s.selectedRole!,
            vehicleType: s.vehicleId == 'private_' ? 'private' : s.vehicleId,
            isRecurring: s.isRecurring,
            recurringDays: s.recurringDays,
            note: note.trim().isEmpty ? null : note.trim(),
          );
      return true;
    } catch (e) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isSubmitting: false));
      }
      rethrow;
    }
  }
}
