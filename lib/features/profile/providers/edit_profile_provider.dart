import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/features/profile/models/edit_profile_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final editProfileProvider =
    AsyncNotifierProvider.autoDispose<EditProfileController, EditProfileState>(
      EditProfileController.new,
    );

class EditProfileController extends AsyncNotifier<EditProfileState> {
  @override
  FutureOr<EditProfileState> build() async {
    return _loadInitialData();
  }

  Future<EditProfileState> _loadInitialData() async {
    final countryService = ref.read(countryServiceProvider);
    final profileService = ref.read(profileServiceProvider);
    final vehicleTypeService = ref.read(vehicleTypeServiceProvider);
    final planService = ref.read(subscriptionPlanServiceProvider);

    final countries = await countryService.getCountries();
    final vehicleTypes = await vehicleTypeService.getAll();
    final plans = await planService.getAll();

    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentSession == null) {
      return EditProfileState(
        countries: countries,
        vehicleTypes: vehicleTypes,
        allPlans: plans,
        isLoading: false,
      );
    }

    try {
      final profile = await profileService.getMyProfile();
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
      final resolvedIsDriver = profile?.isDriver ?? (profile?.role == 'driver');
      final whatsAppValue = profile?.whatsapp ?? profile?.phone ?? '';

      return EditProfileState(
        countries: countries,
        countryCode: resolvedCountryCode,
        isLoading: false,
        isDriver: resolvedIsDriver,
        initialIsDriver: resolvedIsDriver,
        vehicleTypeId: resolvedVehicleTypeId,
        vehicleTypes: vehicleTypes,
        allPlans: plans,
        initialWhatsApp: whatsAppValue.trim(),
        initialVehicleNumberPlate: resolvedVehicleNumberPlate,
      );
    } on Object {
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

  void toggleDriverMode() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(isDriver: !currentState.isDriver),
    );
  }

  void setVehicleTypeId(String id) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(vehicleTypeId: id));
  }

  Future<bool> saveProfile({
    required String whatsApp,
    required String vehicleNumberPlate,
  }) async {
    final s = state.value;
    if (s == null) return false;

    final profileService = ref.read(profileServiceProvider);

    final normalizedPlate = vehicleNumberPlate
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    state = AsyncValue.data(s.copyWith(isSaving: true));

    try {
      await profileService.saveProfileSettings(
        whatsapp: whatsApp.trim(),
        countryCode: s.countryCode,
        isDriver: s.isDriver,
        vehicleTypeId: s.vehicleTypeId,
        vehicleNumberPlate: normalizedPlate,
        previousIsDriver: s.initialIsDriver,
      );
      return true;
    } on Object {
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isSaving: false));
      }
      rethrow;
    }
  }
}
