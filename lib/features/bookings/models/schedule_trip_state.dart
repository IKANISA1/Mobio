import 'package:flutter/material.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/models/route_info.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';

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
  final double? userLat;
  final double? userLng;

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
    this.userLat,
    this.userLng,
  }) : date = date ?? DateTime.now(),
       time = time ?? TimeOfDay.now();

  ScheduleTripState copyWith({
    List<VehicleTypeModel>? vehicleTypes,
    String? vehicleId,
    PlaceDetails? originDetails,
    PlaceDetails? destDetails,
    RouteInfo? routeInfo,
    bool? isComputingRoute,
    bool? isSubmitting,
    DateTime? date,
    TimeOfDay? time,
    bool? isRecurring,
    List<int>? recurringDays,
    String? selectedRole,
    bool? showErrors,
    bool? isLoadingLocation,
    double? userLat,
    double? userLng,
  }) {
    return ScheduleTripState(
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      vehicleId: vehicleId ?? this.vehicleId,
      originDetails: originDetails ?? this.originDetails,
      destDetails: destDetails ?? this.destDetails,
      routeInfo: routeInfo ?? this.routeInfo,
      isComputingRoute: isComputingRoute ?? this.isComputingRoute,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      date: date ?? this.date,
      time: time ?? this.time,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDays: recurringDays ?? this.recurringDays,
      selectedRole: selectedRole ?? this.selectedRole,
      showErrors: showErrors ?? this.showErrors,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
    );
  }
}
