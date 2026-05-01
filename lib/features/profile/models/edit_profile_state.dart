import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/models/subscription_plan_model.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';

class EditProfileState {
  final List<Country> countries;
  final String countryCode;
  final bool isLoading;
  final bool isSaving;
  final bool isDriver;
  final bool initialIsDriver;
  final String vehicleTypeId;
  final BiopayHandleType handleType;
  final List<VehicleTypeModel> vehicleTypes;
  final List<SubscriptionPlanModel> allPlans;
  final String initialWhatsApp;
  final String initialHandleValue;
  final String initialVehicleNumberPlate;

  const EditProfileState({
    this.countries = const [],
    this.countryCode = '+250',
    this.isLoading = true,
    this.isSaving = false,
    this.isDriver = false,
    this.initialIsDriver = false,
    this.vehicleTypeId = 'cab',
    this.handleType = BiopayHandleType.number,
    this.vehicleTypes = const [],
    this.allPlans = const [],
    this.initialWhatsApp = '',
    this.initialHandleValue = '',
    this.initialVehicleNumberPlate = '',
  });

  EditProfileState copyWith({
    List<Country>? countries,
    String? countryCode,
    bool? isLoading,
    bool? isSaving,
    bool? isDriver,
    bool? initialIsDriver,
    String? vehicleTypeId,
    BiopayHandleType? handleType,
    List<VehicleTypeModel>? vehicleTypes,
    List<SubscriptionPlanModel>? allPlans,
    String? initialWhatsApp,
    String? initialHandleValue,
    String? initialVehicleNumberPlate,
  }) {
    return EditProfileState(
      countries: countries ?? this.countries,
      countryCode: countryCode ?? this.countryCode,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDriver: isDriver ?? this.isDriver,
      initialIsDriver: initialIsDriver ?? this.initialIsDriver,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      handleType: handleType ?? this.handleType,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      allPlans: allPlans ?? this.allPlans,
      initialWhatsApp: initialWhatsApp ?? this.initialWhatsApp,
      initialHandleValue: initialHandleValue ?? this.initialHandleValue,
      initialVehicleNumberPlate: initialVehicleNumberPlate ?? this.initialVehicleNumberPlate,
    );
  }

  Country get selectedCountry {
    final matches = countries.where((c) => c.dialingCode == countryCode);
    return matches.isNotEmpty ? matches.first : countries.first;
  }
}
