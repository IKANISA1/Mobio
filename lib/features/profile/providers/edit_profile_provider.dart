import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/features/profile/models/edit_profile_state.dart';
import 'package:mobi_app/models/country.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final editProfileProvider = AsyncNotifierProvider.autoDispose<
  EditProfileController,
  EditProfileState
>(EditProfileController.new);

class EditProfileController extends AsyncNotifier<EditProfileState> {
  @override
  FutureOr<EditProfileState> build() async {
    return _loadInitialData();
  }

  Future<EditProfileState> _loadInitialData() async {
    final countryService = ref.read(countryServiceProvider);
    final profileService = ref.read(profileServiceProvider);
    final bioPayService = ref.read(bioPayServiceProvider);
    final vehicleTypeService = ref.read(vehicleTypeServiceProvider);
    final planService = ref.read(subscriptionPlanServiceProvider);

    final countries = await countryService.getCountries();
    final vehicleTypes = await vehicleTypeService.getAll();
    final plans = await planService.getAll();

    if (!SupabaseConfig.isConfigured || Supabase.instance.client.auth.currentSession == null) {
      return EditProfileState(
        countries: countries,
        vehicleTypes: vehicleTypes,
        allPlans: plans,
        isLoading: false,
      );
    }

    try {
      final profile = await profileService.getMyProfile();
      BiopayHandle? remoteHandle;
      try {
        final hubState = await bioPayService.loadHubState();
        remoteHandle = await countryService.parseBiopayUssd(hubState.ussdString);
      } catch (_) {}

      final profileCountryCode = profile?.countryCode?.trim().isNotEmpty == true
          ? profile!.countryCode!
          : null;

      final resolvedCountryCode = profileCountryCode ??
          remoteHandle?.countryCode ??
          countries.first.dialingCode;

      final storedHandleValue = (profile?.biopayHandleValue ?? '').trim();
      final storedHandleType = BiopayHandleType.fromStorage(profile?.biopayHandleType);

      final initialHandle = storedHandleValue.isNotEmpty
          ? BiopayHandle(
              type: storedHandleType,
              value: storedHandleType == BiopayHandleType.number
                  ? countryService.normalizeLocalPhoneDisplay(
                      dialingCode: resolvedCountryCode,
                      rawValue: storedHandleValue,
                    )
                  : countryService.normalizeCodeValue(storedHandleValue),
              countryCode: resolvedCountryCode,
            )
          : remoteHandle;

      final resolvedHandleType = initialHandle?.type ?? BiopayHandleType.number;
      final resolvedHandleValue = initialHandle?.value ?? '';
      final resolvedVehicleTypeId = (profile?.vehicleType?.isNotEmpty == true)
          ? profile!.vehicleType!
          : 'cab';
      final resolvedVehicleNumberPlate = (profile?.vehicleNumberPlate ?? '').trim();
      final resolvedIsDriver = profile?.isDriver ?? (profile?.role == 'driver');
      final whatsAppValue = profile?.whatsapp ?? profile?.phone ?? '';

      return EditProfileState(
        countries: countries,
        countryCode: resolvedCountryCode,
        isLoading: false,
        isDriver: resolvedIsDriver,
        initialIsDriver: resolvedIsDriver,
        vehicleTypeId: resolvedVehicleTypeId,
        handleType: resolvedHandleType,
        vehicleTypes: vehicleTypes,
        allPlans: plans,
        initialWhatsApp: whatsAppValue.trim(),
        initialHandleValue: resolvedHandleValue,
        initialVehicleNumberPlate: resolvedVehicleNumberPlate,
      );
    } catch (_) {
      return EditProfileState(
        countries: countries,
        vehicleTypes: vehicleTypes,
        allPlans: plans,
        isLoading: false,
      );
    }
  }

  void setCountryCode(String code) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(countryCode: code));
  }

  void setHandleType(BiopayHandleType type, String currentValue) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(handleType: type));
  }

  void toggleDriverMode() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(isDriver: !currentState.isDriver));
  }

  void setVehicleTypeId(String id) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(vehicleTypeId: id));
  }

  Future<bool> saveProfile({
    required String whatsApp,
    required String handleValue,
    required String vehicleNumberPlate,
  }) async {
    final s = state.value;
    if (s == null) return false;

    final profileService = ref.read(profileServiceProvider);
    final countryService = ref.read(countryServiceProvider);
    final bioPayService = ref.read(bioPayServiceProvider);

    final normalizedHandleValue = s.handleType == BiopayHandleType.number
        ? countryService.normalizeLocalPhoneDisplay(
            dialingCode: s.countryCode,
            rawValue: handleValue,
          )
        : countryService.normalizeCodeValue(handleValue);

    final normalizedPlate = vehicleNumberPlate.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    state = AsyncValue.data(s.copyWith(isSaving: true));

    try {
      await profileService.saveProfileSettings(
        whatsapp: whatsApp.trim(),
        countryCode: s.countryCode,
        biopayHandleType: s.handleType,
        biopayHandleValue: normalizedHandleValue,
        isDriver: s.isDriver,
        vehicleTypeId: s.vehicleTypeId,
        vehicleNumberPlate: normalizedPlate,
        previousIsDriver: s.initialIsDriver,
      );

      final localSession = await bioPayService.getLocalSession();
      if (localSession != null) {
        final ussdString = await countryService.buildBiopayUssd(
          dialingCode: s.countryCode,
          handleType: s.handleType,
          handleValue: normalizedHandleValue,
        );
        if (ussdString != null && ussdString.isNotEmpty) {
          await bioPayService.updateManagedProfile(ussdString: ussdString);
        }
      }
      return true;
    } catch (_) {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isSaving: false));
      }
      rethrow;
    }
  }
}
