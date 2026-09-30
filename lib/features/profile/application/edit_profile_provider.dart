import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/localization/country_providers.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/profile/application/edit_profile_state.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_shared_types/models/country.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final editProfileProvider =
    AsyncNotifierProvider.autoDispose<EditProfileController, EditProfileState>(
      EditProfileController.new,
    );

class EditProfileController extends AsyncNotifier<EditProfileState> {
  AccountActionToken? _formAccount;

  void _requireFormAccount([AccountActionToken? expected]) {
    if (!ref.mounted ||
        (expected != null && !identical(expected, _formAccount)) ||
        _formAccount?.isCurrent != true)
      throw const StaleAccountWork();
  }

  @override
  FutureOr<EditProfileState> build() async {
    final formAccount = AccountActionToken.capture();
    _formAccount = formAccount;
    void invalidateOldForm() {
      if (!ref.mounted || _formAccount?.isCurrent == true) return;
      state = const AsyncValue.loading();
      ref.invalidateSelf();
    }

    AccountContext.changes.addListener(invalidateOldForm);
    ref.onDispose(
      () => AccountContext.changes.removeListener(invalidateOldForm),
    );
    final result = await _loadInitialData();
    _requireFormAccount(formAccount);
    return result;
  }

  Future<EditProfileState> _loadInitialData() async {
    final formAccount = _formAccount;
    if (SupabaseConfig.isLocalUiPreview) {
      final agencyNames = await ref
          .read(publicTransportServiceProvider)
          .getAgencyNames();
      return EditProfileState(
        countries: Country.fallbackCountries,
        countryCode: '+250',
        isLoading: false,
        isDriver: true,
        initialIsDriver: true,
        vehicleTypeId: 'bus',
        vehicleTypes: const [...VehicleTypeModel.fallbackTypes],
        transportAgencyNames: agencyNames,
        initialWhatsApp: '788 767 816',
        initialMomoNumber: '0788767816',
        initialMomoPayCode: '123456',
        initialVehicleNumberPlate: 'RAB 204 T',
        initialBusAgencyName: 'VOLCANO',
        initialBusPassengerCapacity: '58',
        initialRentalVehicleModel: 'SUV',
      );
    }

    final countryService = ref.read(countryServiceProvider);
    final profileService = ref.read(profileServiceProvider);
    final vehicleTypeService = ref.read(vehicleTypeServiceProvider);
    final planService = ref.read(subscriptionPlanServiceProvider);
    final publicTransportService = ref.read(publicTransportServiceProvider);

    final account =
        SupabaseConfig.isConfigured &&
            Supabase.instance.client.auth.currentSession != null
        ? AccountContext.capture()
        : null;

    final countries = await countryService.getCountries();
    final vehicleTypes = await vehicleTypeService.getAll();
    final plans = await planService.getAll();
    final agencyNames = await publicTransportService.getAgencyNames();
    if (account != null) AccountContext.requireCurrent(account);
    _requireFormAccount(formAccount);

    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentSession == null) {
      return EditProfileState(
        countries: countries,
        vehicleTypes: vehicleTypes,
        transportAgencyNames: agencyNames,
        allPlans: plans,
        isLoading: false,
      );
    }

    try {
      final profile = await profileService.getMyProfile();
      if (account != null) AccountContext.requireCurrent(account);
      final profileCountryCode = profile?.countryCode?.trim().isNotEmpty == true
          ? profile!.countryCode!
          : null;

      final resolvedCountryCode =
          profileCountryCode ?? countries.first.dialingCode;
      final resolvedVehicleTypeId = (profile?.vehicleType?.isNotEmpty == true)
          ? profile!.vehicleType!
          : 'cab';
      final resolvedVehicleNumberPlate = (profile?.vehicleNumberPlate ?? '')
          .trim();
      final resolvedBusAgencyName = (profile?.busAgencyName ?? '').trim();
      final resolvedBusPassengerCapacity =
          profile?.busPassengerCapacity?.toString() ?? '';
      final resolvedRentalVehicleModel = (profile?.rentalVehicleModel ?? '')
          .trim();
      final resolvedIsDriver = profile?.isDriver ?? (profile?.role == 'driver');
      final whatsAppValue = profile?.whatsapp ?? profile?.phone ?? '';
      final resolvedMomoNumber =
          _localRwandaMomoNumber(profile?.momoNumber ?? '') ??
          _localRwandaMomoNumber(whatsAppValue) ??
          '';
      final resolvedMomoPayCode = (profile?.momoPayCode ?? '')
          .replaceAll(RegExp(r'[^0-9]'), '')
          .trim();

      return EditProfileState(
        countries: countries,
        countryCode: resolvedCountryCode,
        isLoading: false,
        isDriver: resolvedIsDriver,
        initialIsDriver: resolvedIsDriver,
        vehicleTypeId: resolvedVehicleTypeId,
        vehicleTypes: vehicleTypes,
        transportAgencyNames: agencyNames,
        allPlans: plans,
        initialWhatsApp: whatsAppValue.trim(),
        initialMomoNumber: resolvedMomoNumber,
        initialMomoPayCode: resolvedMomoPayCode,
        initialVehicleNumberPlate: resolvedVehicleNumberPlate,
        initialBusAgencyName: resolvedBusAgencyName,
        initialBusPassengerCapacity: resolvedBusPassengerCapacity,
        initialRentalVehicleModel: resolvedRentalVehicleModel,
      );
    } on StaleAccountWork {
      rethrow;
    } on Object {
      return EditProfileState(
        countries: countries,
        vehicleTypes: vehicleTypes,
        transportAgencyNames: agencyNames,
        allPlans: plans,
        isLoading: false,
      );
    }
  }

  void setCountryCode(String code) {
    final currentState = state.value;
    if (currentState == null ||
        state.isLoading ||
        _formAccount?.isCurrent != true)
      return;
    state = AsyncValue.data(currentState.copyWith(countryCode: code));
  }

  void toggleDriverMode() {
    final currentState = state.value;
    if (currentState == null ||
        state.isLoading ||
        _formAccount?.isCurrent != true)
      return;
    state = AsyncValue.data(
      currentState.copyWith(isDriver: !currentState.isDriver),
    );
  }

  void setVehicleTypeId(String id) {
    final currentState = state.value;
    if (currentState == null ||
        state.isLoading ||
        _formAccount?.isCurrent != true)
      return;
    state = AsyncValue.data(currentState.copyWith(vehicleTypeId: id));
  }

  Future<bool> saveProfile({
    required String momoNumber,
    required String momoPayCode,
    required String vehicleNumberPlate,
    required String busAgencyName,
    required String busPassengerCapacity,
    required String rentalVehicleModel,
  }) async {
    final s = state.value;
    if (s == null || state.isLoading || state.hasError) return false;
    _requireFormAccount();
    final formAccount = _formAccount!;

    final normalizedPlate = vehicleNumberPlate
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final normalizedMomoNumber =
        _localRwandaMomoNumber(momoNumber) ??
        _localRwandaMomoNumber(s.initialWhatsApp) ??
        '';
    final normalizedMomoPayCode = momoPayCode
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();
    final isBusDriver = s.isDriver && s.vehicleTypeId == 'bus';
    final requiresVehicleModel =
        s.isDriver &&
        (s.vehicleTypeId == 'rentals' ||
            s.vehicleTypeId == 'private' ||
            s.vehicleTypeId == 'private_');
    final normalizedBusAgencyName = busAgencyName
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final normalizedCapacityText = busPassengerCapacity.trim();
    final parsedBusCapacity = int.tryParse(normalizedCapacityText);
    final normalizedRentalVehicleModel = _normalizeRentalVehicleModel(
      rentalVehicleModel,
    );

    if (s.isDriver && normalizedPlate.isEmpty) {
      throw const ValidationException(
        message: 'Enter the vehicle plate number.',
      );
    }

    if (isBusDriver && normalizedBusAgencyName.isEmpty) {
      throw const ValidationException(message: 'Enter the bus agency name.');
    }

    if (isBusDriver &&
        (parsedBusCapacity == null ||
            parsedBusCapacity < 1 ||
            parsedBusCapacity > 120)) {
      throw const ValidationException(
        message: 'Enter a passenger capacity from 1 to 120.',
      );
    }

    if (requiresVehicleModel && normalizedRentalVehicleModel == null) {
      throw const ValidationException(message: 'Select the vehicle model.');
    }

    if (SupabaseConfig.isLocalUiPreview) return true;

    final account = AccountContext.capture();

    final profileService = ref.read(profileServiceProvider);

    state = AsyncValue.data(s.copyWith(isSaving: true));

    try {
      await profileService.saveProfileSettings(
        momoNumber: normalizedMomoNumber,
        momoPayCode: normalizedMomoPayCode,
        isDriver: s.isDriver,
        vehicleTypeId: s.vehicleTypeId,
        vehicleNumberPlate: normalizedPlate,
        busAgencyName: isBusDriver ? normalizedBusAgencyName : null,
        busPassengerCapacity: isBusDriver ? parsedBusCapacity : null,
        rentalVehicleModel: requiresVehicleModel
            ? normalizedRentalVehicleModel
            : null,
        previousIsDriver: s.initialIsDriver,
      );
      AccountContext.requireCurrent(account);
      _requireFormAccount(formAccount);
      return true;
    } on Object {
      _requireFormAccount(formAccount);
      final finalState = state.value;
      if (AccountContext.isCurrent(account) && finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isSaving: false));
      }
      rethrow;
    }
  }
}

String? _normalizeRentalVehicleModel(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return null;
  const allowed = {'SUV', 'Sedan', 'Truck', 'Van', 'Bus'};
  for (final option in allowed) {
    if (option.toLowerCase() == normalized.toLowerCase()) {
      return option;
    }
  }
  return null;
}

String? _localRwandaMomoNumber(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.length == 12 && digits.startsWith('2507')) {
    return '0${digits.substring(3)}';
  }
  if (digits.length == 9 && digits.startsWith('7')) {
    return '0$digits';
  }
  if (digits.length == 10 && digits.startsWith('07')) {
    return digits;
  }
  return digits;
}
