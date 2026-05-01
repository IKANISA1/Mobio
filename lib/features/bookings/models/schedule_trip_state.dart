import 'package:flutter/material.dart';
import 'package:mobi_app/models/favorite_address.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/models/route_info.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';

const Object _unset = Object();

class ScheduleTripState {
  final List<VehicleTypeModel> vehicleTypes;
  final String vehicleId;
  final PlaceDetails? originDetails;
  final PlaceDetails? destDetails;
  final RouteInfo? routeInfo;
  final bool isComputingRoute;
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
  final String? validationMessage;

  ScheduleTripState({
    this.vehicleTypes = const [],
    this.vehicleId = 'cab',
    this.originDetails,
    this.destDetails,
    this.routeInfo,
    this.isComputingRoute = false,
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
    this.validationMessage,
  }) : date = date ?? DateTime.now(),
       time = time ?? TimeOfDay.now();

  ScheduleTripState copyWith({
    List<VehicleTypeModel>? vehicleTypes,
    String? vehicleId,
    Object? originDetails = _unset,
    Object? destDetails = _unset,
    Object? routeInfo = _unset,
    bool? isComputingRoute,
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
      routeInfo: identical(routeInfo, _unset)
          ? this.routeInfo
          : routeInfo as RouteInfo?,
      isComputingRoute: isComputingRoute ?? this.isComputingRoute,
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
      validationMessage: identical(validationMessage, _unset)
          ? this.validationMessage
          : validationMessage as String?,
    );
  }

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
