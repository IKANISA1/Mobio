import 'package:flutter/material.dart';
import 'package:mobi_app/models/favorite_address.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';

const Object _unset = Object();

class ScheduleTripState {
  final List<VehicleTypeModel> vehicleTypes;
  final String vehicleId;
  final PlaceDetails? originDetails;
  final PlaceDetails? destDetails;
  final bool isSubmitting;
  final DateTime date;
  final TimeOfDay time;
  final bool isRecurring;
  final List<int> recurringDays;
  final String? selectedRole;
  final bool showErrors;
  final bool isLoadingLocation;
  final bool isLoadingFavoriteAddresses;
  final bool isSavingFavoriteAddress;
  final bool isLoadingPoolSuggestions;
  final double? userLat;
  final double? userLng;
  final List<FavoriteAddress> favoriteAddresses;
  final List<Trip> poolSuggestions;
  final Trip? createdTrip;
  final Trip? editingTrip;
  final String? validationMessage;

  ScheduleTripState({
    this.vehicleTypes = const [],
    this.vehicleId = 'cab',
    this.originDetails,
    this.destDetails,
    this.isSubmitting = false,
    DateTime? date,
    TimeOfDay? time,
    this.isRecurring = false,
    this.recurringDays = const [],
    this.selectedRole,
    this.showErrors = false,
    this.isLoadingLocation = false,
    this.isLoadingFavoriteAddresses = false,
    this.isSavingFavoriteAddress = false,
    this.isLoadingPoolSuggestions = false,
    this.userLat,
    this.userLng,
    this.favoriteAddresses = const [],
    this.poolSuggestions = const [],
    this.createdTrip,
    this.editingTrip,
    this.validationMessage,
  }) : date = date ?? DateTime.now(),
       time = time ?? TimeOfDay.now();

  factory ScheduleTripState.fromTrip(
    Trip trip, {
    List<VehicleTypeModel> vehicleTypes = const [],
    List<FavoriteAddress> favoriteAddresses = const [],
  }) {
    return ScheduleTripState(
      vehicleTypes: vehicleTypes,
      vehicleId: trip.vehicleTypeStr == 'private'
          ? 'private_'
          : trip.vehicleTypeStr,
      originDetails: PlaceDetails(
        placeId: 'trip-origin-${trip.id ?? trip.hashCode}',
        formattedAddress: trip.origin,
        latitude: trip.originLat ?? 0,
        longitude: trip.originLng ?? 0,
      ),
      destDetails: PlaceDetails(
        placeId: 'trip-destination-${trip.id ?? trip.hashCode}',
        formattedAddress: trip.destination,
        latitude: trip.destLat ?? 0,
        longitude: trip.destLng ?? 0,
      ),
      date: _parseTripDate(trip.departureDate),
      time: _parseTripTime(trip.departureTime),
      isRecurring: trip.isRecurring,
      recurringDays: trip.recurringDays,
      selectedRole: trip.role,
      favoriteAddresses: favoriteAddresses,
      editingTrip: trip,
    );
  }

  ScheduleTripState copyWith({
    List<VehicleTypeModel>? vehicleTypes,
    String? vehicleId,
    Object? originDetails = _unset,
    Object? destDetails = _unset,
    bool? isSubmitting,
    DateTime? date,
    TimeOfDay? time,
    bool? isRecurring,
    List<int>? recurringDays,
    String? selectedRole,
    bool? showErrors,
    bool? isLoadingLocation,
    bool? isLoadingFavoriteAddresses,
    bool? isSavingFavoriteAddress,
    bool? isLoadingPoolSuggestions,
    Object? userLat = _unset,
    Object? userLng = _unset,
    List<FavoriteAddress>? favoriteAddresses,
    List<Trip>? poolSuggestions,
    Object? createdTrip = _unset,
    Object? editingTrip = _unset,
    Object? validationMessage = _unset,
  }) {
    return ScheduleTripState(
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      vehicleId: vehicleId ?? this.vehicleId,
      originDetails: identical(originDetails, _unset)
          ? this.originDetails
          : originDetails as PlaceDetails?,
      destDetails: identical(destDetails, _unset)
          ? this.destDetails
          : destDetails as PlaceDetails?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      date: date ?? this.date,
      time: time ?? this.time,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDays: recurringDays ?? this.recurringDays,
      selectedRole: selectedRole ?? this.selectedRole,
      showErrors: showErrors ?? this.showErrors,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingFavoriteAddresses:
          isLoadingFavoriteAddresses ?? this.isLoadingFavoriteAddresses,
      isSavingFavoriteAddress:
          isSavingFavoriteAddress ?? this.isSavingFavoriteAddress,
      isLoadingPoolSuggestions:
          isLoadingPoolSuggestions ?? this.isLoadingPoolSuggestions,
      userLat: identical(userLat, _unset) ? this.userLat : userLat as double?,
      userLng: identical(userLng, _unset) ? this.userLng : userLng as double?,
      favoriteAddresses: favoriteAddresses ?? this.favoriteAddresses,
      poolSuggestions: poolSuggestions ?? this.poolSuggestions,
      createdTrip: identical(createdTrip, _unset)
          ? this.createdTrip
          : createdTrip as Trip?,
      editingTrip: identical(editingTrip, _unset)
          ? this.editingTrip
          : editingTrip as Trip?,
      validationMessage: identical(validationMessage, _unset)
          ? this.validationMessage
          : validationMessage as String?,
    );
  }

  bool get isEditMode => editingTrip?.id?.isNotEmpty == true;

  DateTime get selectedDateTime {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? validateForSubmit(DateTime now) {
    if (selectedRole == null) {
      return 'Choose whether this trip is for a passenger or driver.';
    }
    if (originDetails == null) {
      return 'Choose a pickup location.';
    }
    if (destDetails == null) {
      return 'Choose a destination.';
    }
    if (selectedDateTime.isBefore(now)) {
      return 'Choose a future departure time.';
    }
    if (isRecurring && recurringDays.isEmpty) {
      return 'Choose at least one repeat day or turn repeat off.';
    }
    return null;
  }
}

DateTime _parseTripDate(String value) {
  return DateTime.tryParse(value) ?? DateTime.now();
}

TimeOfDay _parseTripTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
  if (match == null) {
    return TimeOfDay.now();
  }

  var hour = int.tryParse(match.group(1) ?? '') ?? TimeOfDay.now().hour;
  final minute = int.tryParse(match.group(2) ?? '') ?? TimeOfDay.now().minute;
  final lower = value.toLowerCase();
  if (lower.contains('pm') && hour < 12) {
    hour += 12;
  } else if (lower.contains('am') && hour == 12) {
    hour = 0;
  }

  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}
