import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_shared_types/models/country.dart';
import 'package:mobi_shared_types/models/subscription_plan_model.dart';

class EditProfileState {
  final List<Country> countries;
  final String countryCode;
  final bool isLoading;
  final bool isSaving;
  final bool isDriver;
  final bool initialIsDriver;
  final String vehicleTypeId;
  final List<VehicleTypeModel> vehicleTypes;
  final List<String> transportAgencyNames;
  final List<SubscriptionPlanModel> allPlans;
  final String initialWhatsApp;
  final String initialMomoNumber;
  final String initialMomoPayCode;
  final String initialVehicleNumberPlate;
  final String initialBusAgencyName;
  final String initialBusPassengerCapacity;
  final String initialRentalVehicleModel;

  const EditProfileState({
    this.countries = const [],
    this.countryCode = '+250',
    this.isLoading = true,
    this.isSaving = false,
    this.isDriver = false,
    this.initialIsDriver = false,
    this.vehicleTypeId = 'cab',
    this.vehicleTypes = const [],
    this.transportAgencyNames = const [],
    this.allPlans = const [],
    this.initialWhatsApp = '',
    this.initialMomoNumber = '',
    this.initialMomoPayCode = '',
    this.initialVehicleNumberPlate = '',
    this.initialBusAgencyName = '',
    this.initialBusPassengerCapacity = '',
    this.initialRentalVehicleModel = '',
  });

  EditProfileState copyWith({
    List<Country>? countries,
    String? countryCode,
    bool? isLoading,
    bool? isSaving,
    bool? isDriver,
    bool? initialIsDriver,
    String? vehicleTypeId,
    List<VehicleTypeModel>? vehicleTypes,
    List<String>? transportAgencyNames,
    List<SubscriptionPlanModel>? allPlans,
    String? initialWhatsApp,
    String? initialMomoNumber,
    String? initialMomoPayCode,
    String? initialVehicleNumberPlate,
    String? initialBusAgencyName,
    String? initialBusPassengerCapacity,
    String? initialRentalVehicleModel,
  }) {
    return EditProfileState(
      countries: countries ?? this.countries,
      countryCode: countryCode ?? this.countryCode,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDriver: isDriver ?? this.isDriver,
      initialIsDriver: initialIsDriver ?? this.initialIsDriver,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      transportAgencyNames: transportAgencyNames ?? this.transportAgencyNames,
      allPlans: allPlans ?? this.allPlans,
      initialWhatsApp: initialWhatsApp ?? this.initialWhatsApp,
      initialMomoNumber: initialMomoNumber ?? this.initialMomoNumber,
      initialMomoPayCode: initialMomoPayCode ?? this.initialMomoPayCode,
      initialVehicleNumberPlate:
          initialVehicleNumberPlate ?? this.initialVehicleNumberPlate,
      initialBusAgencyName: initialBusAgencyName ?? this.initialBusAgencyName,
      initialBusPassengerCapacity:
          initialBusPassengerCapacity ?? this.initialBusPassengerCapacity,
      initialRentalVehicleModel:
          initialRentalVehicleModel ?? this.initialRentalVehicleModel,
    );
  }

  Country get selectedCountry {
    if (countries.isEmpty) {
      return Country.fallbackCountries.first;
    }

    final matches = countries.where((c) => c.dialingCode == countryCode);
    return matches.isNotEmpty ? matches.first : countries.first;
  }
}
