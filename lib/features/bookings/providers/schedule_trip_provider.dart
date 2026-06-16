import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/app_permission_service.dart';
import 'package:mobi_app/core/services/public_transport_service.dart';
import 'package:mobi_app/features/bookings/models/schedule_trip_state.dart';
import 'package:mobi_app/models/favorite_address.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';

class ScheduleTripArgs {
  const ScheduleTripArgs({this.mode, this.editingTripId});

  final String? mode;
  final String? editingTripId;

  bool get isEditMode => editingTripId?.isNotEmpty == true;
}

/// Provider for schedule arguments.
class ScheduleTripArgsNotifier extends Notifier<ScheduleTripArgs> {
  @override
  ScheduleTripArgs build() => const ScheduleTripArgs();

  void set(String? mode) => setCreateMode(mode);

  void setCreateMode(String? mode) {
    state = ScheduleTripArgs(mode: mode);
  }

  void setEditTrip({required String tripId, String? mode}) {
    state = ScheduleTripArgs(mode: mode, editingTripId: tripId);
  }
}

final scheduleTripArgsProvider =
    NotifierProvider<ScheduleTripArgsNotifier, ScheduleTripArgs>(
      ScheduleTripArgsNotifier.new,
    );

final scheduleTripProvider =
    AsyncNotifierProvider.autoDispose<
      ScheduleTripController,
      ScheduleTripState
    >(ScheduleTripController.new);

class ScheduleTripController extends AsyncNotifier<ScheduleTripState> {
  static const PlaceDetails _previewCurrentPickup = PlaceDetails(
    placeId: 'current-location-preview',
    formattedAddress: 'Kigali Heights, KG 7 Ave, Kigali',
    latitude: -1.9536,
    longitude: 30.0935,
  );
  static const List<FavoriteAddress> _previewFavoriteAddresses = [
    FavoriteAddress(
      id: 'preview-home',
      profileId: 'preview-profile',
      label: 'Home',
      addressType: 'home',
      formattedAddress: 'Kigali Heights, KG 7 Ave, Kigali',
      latitude: -1.9536,
      longitude: 30.0928,
    ),
    FavoriteAddress(
      id: 'preview-work',
      profileId: 'preview-profile',
      label: 'Work',
      addressType: 'work',
      formattedAddress: 'Norrsken House Kigali',
      latitude: -1.9544,
      longitude: 30.0922,
      sortOrder: 1,
    ),
    FavoriteAddress(
      id: 'preview-airport',
      profileId: 'preview-profile',
      label: 'Airport',
      addressType: 'other',
      formattedAddress: 'Kigali International Airport',
      latitude: -1.9686,
      longitude: 30.1395,
      sortOrder: 2,
    ),
  ];

  @override
  FutureOr<ScheduleTripState> build() async {
    final args = ref.watch(scheduleTripArgsProvider);

    if (SupabaseConfig.isLocalUiPreview) {
      final editingTrip = args.isEditMode ? AppConstants.mockTrips.first : null;
      final agencyNames = await _loadAgencyNames();
      return editingTrip == null
          ? ScheduleTripState(
              vehicleTypes: VehicleTypeModel.fallbackTypes,
              transportAgencyNames: agencyNames,
              selectedRole: args.mode,
              originDetails: _previewCurrentPickup,
              userLat: _previewCurrentPickup.latitude,
              userLng: _previewCurrentPickup.longitude,
              favoriteAddresses: _previewFavoriteAddresses,
              date: DateTime(2030, 6, 12),
              time: const TimeOfDay(hour: 9, minute: 0),
            )
          : ScheduleTripState.fromTrip(
              editingTrip,
              vehicleTypes: VehicleTypeModel.fallbackTypes,
              transportAgencyNames: agencyNames,
              favoriteAddresses: _previewFavoriteAddresses,
            );
    }

    final vt = await ref.read(vehicleTypeServiceProvider).getAll();
    final favorites = await _loadFavoriteAddresses();
    final agencyNames = await _loadAgencyNames();

    if (args.isEditMode) {
      final trip = await ref
          .read(tripServiceProvider)
          .getTripById(args.editingTripId!);
      if (trip == null) {
        throw const NotFoundException(message: 'Scheduled trip was not found.');
      }

      return ScheduleTripState.fromTrip(
        trip,
        vehicleTypes: vt,
        transportAgencyNames: agencyNames,
        favoriteAddresses: favorites,
      );
    }

    final initialState = ScheduleTripState(
      vehicleTypes: vt,
      transportAgencyNames: agencyNames,
      selectedRole: args.mode,
      favoriteAddresses: favorites,
    );

    unawaited(_prefillCurrentPickupIfEmpty());

    return initialState;
  }

  Future<List<FavoriteAddress>> _loadFavoriteAddresses() async {
    try {
      return await ref.read(favoriteAddressServiceProvider).list();
    } on Object catch (error) {
      debugPrint('Unable to load favorite addresses: $error');
      return const [];
    }
  }

  Future<List<String>> _loadAgencyNames() async {
    try {
      final names = await ref
          .read(publicTransportServiceProvider)
          .getAgencyNames();
      return names.isEmpty ? PublicTransportService.fallbackAgencyNames : names;
    } on Object catch (error) {
      debugPrint('Unable to load bus agencies: $error');
      return PublicTransportService.fallbackAgencyNames;
    }
  }

  Future<void> _prefillCurrentPickupIfEmpty() async {
    try {
      final hasAccess = await AppPermissionService.instance.hasLocationAccess();
      if (!hasAccess) return;

      final locationService = ref.read(locationServiceProvider);
      final position =
          await locationService.getLastKnownOrCached() ??
          await locationService.getCurrentPosition();

      if (position != null) {
        final currentState = state.value;
        if (currentState != null) {
          final nextState = currentState.copyWith(
            userLat: position.latitude,
            userLng: position.longitude,
          );
          state = AsyncValue.data(nextState);
        }

        final afterPositionState = state.value;
        if (afterPositionState?.originDetails != null) return;

        final details = await ref
            .read(placesServiceProvider)
            .reverseGeocode(position.latitude, position.longitude);

        final afterReverseGeocodeState = state.value;
        if (details != null &&
            afterReverseGeocodeState != null &&
            afterReverseGeocodeState.originDetails == null) {
          state = AsyncValue.data(
            afterReverseGeocodeState.copyWith(
              originDetails: details,
              validationMessage: null,
            ),
          );
        }
      }
    } on Object catch (error) {
      debugPrint('Unable to bootstrap location: $error');
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
          state = AsyncValue.data(
            current.copyWith(
              isLoadingLocation: false,
              validationMessage: 'Current location is unavailable.',
            ),
          );
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
    } on Object catch (error) {
      debugPrint('Unable to use current location: $error');
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(
            validationMessage: 'Unable to use current location. Try again.',
          ),
        );
      }
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
    state = AsyncValue.data(
      currentState.copyWith(originDetails: details, validationMessage: null),
    );
  }

  void setDestination(PlaceDetails? details) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(destDetails: details, validationMessage: null),
    );
  }

  void useFavoriteAsOrigin(FavoriteAddress address) {
    setOrigin(address.toPlaceDetails());
  }

  void useFavoriteAsDestination(FavoriteAddress address) {
    setDestination(address.toPlaceDetails());
  }

  Future<bool> saveFavoriteAddress({
    required bool fromOrigin,
    required String label,
    required String addressType,
  }) async {
    final currentState = state.value;
    if (currentState == null) return false;

    final place = fromOrigin
        ? currentState.originDetails
        : currentState.destDetails;
    if (place == null || place.formattedAddress.trim().isEmpty) {
      return false;
    }

    state = AsyncValue.data(
      currentState.copyWith(isSavingFavoriteAddress: true),
    );

    try {
      await ref
          .read(favoriteAddressServiceProvider)
          .save(
            label: label,
            addressType: addressType,
            place: place,
            sortOrder: currentState.favoriteAddresses.length,
          );
      final favorites = await _loadFavoriteAddresses();
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            favoriteAddresses: favorites,
            isSavingFavoriteAddress: false,
          ),
        );
      }
      return true;
    } on Object {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(isSavingFavoriteAddress: false),
        );
      }
      rethrow;
    }
  }

  Future<void> deleteFavoriteAddress(FavoriteAddress address) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(
      currentState.copyWith(isSavingFavoriteAddress: true),
    );

    try {
      await ref.read(favoriteAddressServiceProvider).delete(address.id);
      final favorites = await _loadFavoriteAddresses();
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            favoriteAddresses: favorites,
            isSavingFavoriteAddress: false,
          ),
        );
      }
    } on Object {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(isSavingFavoriteAddress: false),
        );
      }
      rethrow;
    }
  }

  void setVehicleId(String id) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(
        vehicleId: id,
        busAgencyName: id == 'bus' ? currentState.busAgencyName : '',
        rentalVehicleModel:
            id == 'rentals' || id == 'private' || id == 'private_'
            ? currentState.rentalVehicleModel
            : '',
        validationMessage: null,
      ),
    );
  }

  void setRentalVehicleModel(String model) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(rentalVehicleModel: model, validationMessage: null),
    );
  }

  void setBusAgencyName(String agency) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(busAgencyName: agency, validationMessage: null),
    );
  }

  void setRole(String role) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(selectedRole: role, validationMessage: null),
    );
  }

  void setDate(DateTime date) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(date: date, validationMessage: null),
    );
  }

  void setTime(TimeOfDay time) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(time: time, validationMessage: null),
    );
  }

  void toggleRecurring() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(
        isRecurring: !currentState.isRecurring,
        validationMessage: null,
      ),
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
    state = AsyncValue.data(
      currentState.copyWith(recurringDays: current, validationMessage: null),
    );
  }

  Future<Trip?> submitTrip({required String note}) async {
    final s = state.value;
    if (s == null) return null;

    final validationMessage = s.validateForSubmit(DateTime.now());
    if (validationMessage != null) {
      state = AsyncValue.data(
        s.copyWith(showErrors: true, validationMessage: validationMessage),
      );
      return null;
    }

    state = AsyncValue.data(
      s.copyWith(
        isSubmitting: true,
        showErrors: false,
        poolSuggestions: const [],
        poolSuggestionMessage: null,
        validationMessage: null,
      ),
    );

    if (SupabaseConfig.isLocalUiPreview) {
      final trip = s.editingTrip ?? AppConstants.mockTrips.first;
      state = AsyncValue.data(
        s.copyWith(
          createdTrip: trip,
          editingTrip: s.isEditMode ? trip : null,
          isSubmitting: false,
          poolSuggestions: const [],
          validationMessage: null,
        ),
      );
      return trip;
    }

    if (s.isEditMode) {
      try {
        final trip = await ref
            .read(tripServiceProvider)
            .updateTrip(
              tripId: s.editingTrip!.id!,
              origin: s.originDetails!.formattedAddress,
              originPlaceId: s.originDetails!.placeId,
              originLat: s.originDetails!.latitude != 0
                  ? s.originDetails!.latitude
                  : null,
              originLng: s.originDetails!.longitude != 0
                  ? s.originDetails!.longitude
                  : null,
              destination: s.destDetails!.formattedAddress,
              destinationPlaceId: s.destDetails!.placeId,
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
        state = AsyncValue.data(
          s.copyWith(
            createdTrip: trip,
            editingTrip: trip,
            isSubmitting: false,
            poolSuggestions: const [],
            validationMessage: null,
          ),
        );
        return trip;
      } on Object {
        final finalState = state.value;
        if (finalState != null) {
          state = AsyncValue.data(finalState.copyWith(isSubmitting: false));
        }
        rethrow;
      }
    }

    try {
      final trip = await ref
          .read(tripServiceProvider)
          .createTrip(
            origin: s.originDetails!.formattedAddress,
            originPlaceId: s.originDetails!.placeId,
            originLat: s.originDetails!.latitude != 0
                ? s.originDetails!.latitude
                : null,
            originLng: s.originDetails!.longitude != 0
                ? s.originDetails!.longitude
                : null,
            destination: s.destDetails!.formattedAddress,
            destinationPlaceId: s.destDetails!.placeId,
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
            clientRequestId: s.clientRequestId,
            note: note.trim().isEmpty ? null : note.trim(),
          );
      await _loadPoolSuggestions(trip);
      return trip;
    } on Object {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isSubmitting: false));
      }
      rethrow;
    }
  }

  Future<void> _loadPoolSuggestions(Trip trip) async {
    final tripId = trip.id;
    final currentState = state.value;
    if (currentState == null) {
      return;
    }

    if (tripId == null || tripId.isEmpty) {
      state = AsyncValue.data(
        currentState.copyWith(createdTrip: trip, isSubmitting: false),
      );
      return;
    }

    state = AsyncValue.data(
      currentState.copyWith(
        createdTrip: trip,
        isSubmitting: false,
        isLoadingPoolSuggestions: true,
      ),
    );

    try {
      final suggestions = await ref
          .read(tripServiceProvider)
          .getPoolSuggestions(tripId, limit: 8);
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            createdTrip: trip,
            poolSuggestions: suggestions,
            poolSuggestionMessage: null,
            isLoadingPoolSuggestions: false,
          ),
        );
      }
    } on Object catch (error) {
      debugPrint('Unable to load pool suggestions: $error');
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(
            createdTrip: trip,
            poolSuggestions: const [],
            poolSuggestionMessage:
                'Trip scheduled, but matching suggestions are unavailable.',
            isLoadingPoolSuggestions: false,
          ),
        );
      }
    }
  }
}
