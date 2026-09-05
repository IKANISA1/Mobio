import 'package:flutter/material.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';
import 'package:mobi_shared_types/models/trip.dart';

const Object _unset = Object();

const List<String> rentalVehicleModelOptions = [
  'SUV',
  'Sedan',
  'Truck',
  'Van',
  'Bus',
];

String? normalizeRentalVehicleModel(String value) {
  final normalized = value.trim();
  for (final option in rentalVehicleModelOptions) {
    if (option.toLowerCase() == normalized.toLowerCase()) {
      return option;
    }
  }
  return null;
}

class ScheduleTripState {
  final List<VehicleTypeModel> vehicleTypes;
  final List<String> transportAgencyNames;
  final String vehicleId;
  final String busAgencyName;
  final String rentalVehicleModel;
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
  final String? poolSuggestionMessage;
  final Trip? createdTrip;
  final Trip? editingTrip;
  final String? validationMessage;
  final String clientRequestId;

  ScheduleTripState({
    this.vehicleTypes = const [],
    this.transportAgencyNames = const [],
    this.vehicleId = 'cab',
    this.busAgencyName = '',
    this.rentalVehicleModel = '',
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
    this.poolSuggestionMessage,
    this.createdTrip,
    this.editingTrip,
    this.validationMessage,
    String? clientRequestId,
  }) : date = date ?? DateTime.now(),
       time = time ?? TimeOfDay.now(),
       clientRequestId = clientRequestId ?? _newClientRequestId();

  factory ScheduleTripState.fromTrip(
    Trip trip, {
    List<VehicleTypeModel> vehicleTypes = const [],
    List<String> transportAgencyNames = const [],
    List<FavoriteAddress> favoriteAddresses = const [],
  }) {
    return ScheduleTripState(
      vehicleTypes: vehicleTypes,
      transportAgencyNames: transportAgencyNames,
      vehicleId: trip.vehicleTypeStr == 'private'
          ? 'private_'
          : trip.vehicleTypeStr,
      busAgencyName: _busAgencyFromNote(trip.note, transportAgencyNames),
      rentalVehicleModel: _vehicleModelFromNote(trip.note),
      originDetails: PlaceDetails(
        placeId:
            trip.originPlaceId ?? 'trip-origin-${trip.id ?? trip.hashCode}',
        formattedAddress: trip.origin,
        latitude: trip.originLat ?? 0,
        longitude: trip.originLng ?? 0,
      ),
      destDetails: PlaceDetails(
        placeId:
            trip.destinationPlaceId ??
            'trip-destination-${trip.id ?? trip.hashCode}',
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
      clientRequestId: trip.clientRequestId,
    );
  }

  ScheduleTripState copyWith({
    List<VehicleTypeModel>? vehicleTypes,
    List<String>? transportAgencyNames,
    String? vehicleId,
    String? busAgencyName,
    String? rentalVehicleModel,
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
    Object? poolSuggestionMessage = _unset,
    Object? createdTrip = _unset,
    Object? editingTrip = _unset,
    Object? validationMessage = _unset,
    String? clientRequestId,
  }) {
    return ScheduleTripState(
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      transportAgencyNames: transportAgencyNames ?? this.transportAgencyNames,
      vehicleId: vehicleId ?? this.vehicleId,
      busAgencyName: busAgencyName ?? this.busAgencyName,
      rentalVehicleModel: rentalVehicleModel ?? this.rentalVehicleModel,
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
      poolSuggestionMessage: identical(poolSuggestionMessage, _unset)
          ? this.poolSuggestionMessage
          : poolSuggestionMessage as String?,
      createdTrip: identical(createdTrip, _unset)
          ? this.createdTrip
          : createdTrip as Trip?,
      editingTrip: identical(editingTrip, _unset)
          ? this.editingTrip
          : editingTrip as Trip?,
      validationMessage: identical(validationMessage, _unset)
          ? this.validationMessage
          : validationMessage as String?,
      clientRequestId: clientRequestId ?? this.clientRequestId,
    );
  }

  bool get isEditMode => editingTrip?.id?.isNotEmpty == true;

  bool get requiresBusAgency => vehicleId == 'bus';

  String? get normalizedBusAgencyName =>
      normalizeBusAgencyName(busAgencyName, transportAgencyNames);

  bool get requiresRentalVehicleModel => vehicleId == 'rentals';

  bool get requiresVehicleModel =>
      vehicleId == 'rentals' ||
      vehicleId == 'private' ||
      vehicleId == 'private_';

  String? get normalizedRentalVehicleModel =>
      normalizeRentalVehicleModel(rentalVehicleModel);

  bool canSubmit(DateTime now) => validateForSubmit(now) == null;

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
    if (!_hasResolvedRoute(originDetails!)) {
      return 'Choose a pickup from the location results.';
    }
    if (!_hasResolvedRoute(destDetails!)) {
      return 'Choose a destination from the location results.';
    }
    if (requiresBusAgency && normalizedBusAgencyName == null) {
      return 'Select the bus agency.';
    }
    if (requiresVehicleModel && normalizedRentalVehicleModel == null) {
      return vehicleId == 'rentals'
          ? 'Select the rental vehicle model.'
          : 'Select the vehicle model.';
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

String? normalizeBusAgencyName(String value, List<String> agencies) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return null;
  final options = _normalizedAgencyNames(agencies);
  if (options.isEmpty) return normalized;
  for (final agency in options) {
    if (agency.toLowerCase() == normalized.toLowerCase()) {
      return agency;
    }
  }
  return null;
}

List<String> normalizedBusAgencyNames(List<String> agencies) =>
    _normalizedAgencyNames(agencies);

String _newClientRequestId() {
  return 'trip-${DateTime.now().microsecondsSinceEpoch}';
}

bool _hasResolvedRoute(PlaceDetails details) {
  return details.placeId.trim().isNotEmpty &&
      details.formattedAddress.trim().isNotEmpty &&
      (details.latitude != 0 || details.longitude != 0);
}

String _vehicleModelFromNote(String? note) {
  final value = note?.trim();
  if (value == null || value.isEmpty) return '';
  final match = RegExp(
    r'^(?:Rental model|Vehicle model):\s*(SUV|Sedan|Truck|Van|Bus)\s*$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(value);
  if (match == null) return '';
  return normalizeRentalVehicleModel(match.group(1) ?? '') ?? '';
}

String _busAgencyFromNote(String? note, List<String> agencies) {
  final value = note?.trim();
  if (value == null || value.isEmpty) return '';
  final match = RegExp(
    r'^Bus agency:\s*(.+?)\s*$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(value);
  if (match == null) return '';
  return normalizeBusAgencyName(match.group(1) ?? '', agencies) ?? '';
}

List<String> _normalizedAgencyNames(List<String> agencies) {
  return agencies
      .map((name) => name.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
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
