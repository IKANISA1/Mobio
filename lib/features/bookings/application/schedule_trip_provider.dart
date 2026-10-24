import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/location/location_providers.dart';
import 'package:mobi_app/core/permissions/permission_providers.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_post_providers.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_posts.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/bookings/data/public_transport_service.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';
import 'package:mobi_shared_types/models/trip.dart';

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
    >(
      ScheduleTripController.new,
      retry: (retryCount, error) => error is ReviewWorldUnavailable
          ? null
          : ProviderContainer.defaultRetry(retryCount, error),
    );

class ScheduleTripController extends AsyncNotifier<ScheduleTripState> {
  ScheduleTripController() : _captureOverride = null, _isCurrentOverride = null;

  @visibleForTesting
  ScheduleTripController.test({
    required AccountSnapshot? Function() captureAccount,
    required bool Function(AccountSnapshot?) isCurrent,
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;

  final AccountSnapshot? Function()? _captureOverride;
  final bool Function(AccountSnapshot?)? _isCurrentOverride;
  AccountSnapshot? _draftAccount;
  bool _reviewSelected = false;
  bool _reviewSubmitted = false;
  ReviewScheduledPostGateway? _reviewGateway;
  ReviewScheduledPostIntent? _reviewIntent;

  bool get isReviewSession => _reviewSelected;
  bool get isReviewCurrent =>
      _reviewIntent != null &&
      _reviewGateway?.hasCurrentAuthority(_reviewIntent!) == true;
  DateTime get comparisonNow => _reviewSelected
      ? requireReviewScheduledPosts(
          _reviewGateway,
        ).calendarNow(_requireReviewDraft())
      : DateTime.now();

  ReviewScheduledPostIntent _requireReviewDraft() {
    final intent = _reviewIntent;
    if (intent == null || !isReviewCurrent) {
      throw const ReviewWorldUnavailable('world_locked');
    }
    return intent;
  }

  int _buildRevision = 0;
  int _locationRevision = 0;

  AccountSnapshot? _captureAccount() {
    if (_reviewSelected) {
      throw const ReviewWorldUnavailable('ordinary_capture_denied_for_review');
    }
    if (_draftAccount != null) _requireCurrent(_draftAccount);
    return _captureOverride != null
        ? _captureOverride()
        : SupabaseConfig.isLocalUiPreview
        ? null
        : AccountContext.capture();
  }

  bool _isCurrent(AccountSnapshot? account) =>
      ref.mounted &&
      (_isCurrentOverride?.call(account) ??
          (account == null || AccountContext.isCurrent(account)));

  void _requireCurrent(AccountSnapshot? account) {
    if (!_isCurrent(account)) throw const StaleAccountWork();
  }

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
    final buildRevision = ++_buildRevision;
    _locationRevision++;
    _draftAccount = null;
    _reviewSubmitted = false;
    _reviewGateway = null;
    _reviewIntent = null;
    _reviewSelected = ref.watch(reviewScheduledPostsSelectedProvider);
    ref.onDispose(() {
      _buildRevision++;
      _locationRevision++;
    });
    final args = ref.watch(scheduleTripArgsProvider);

    if (_reviewSelected) {
      final gateway = requireReviewScheduledPosts(
        ref.watch(reviewScheduledPostGatewayProvider),
      );
      _reviewGateway = gateway;
      final intent = gateway.capture(targetId: args.editingTripId);
      _reviewIntent = intent;
      void onReviewChanged() {
        if (!gateway.hasCurrentAuthority(intent) && ref.mounted) {
          ref.invalidateSelf();
        }
      }

      gateway.addListener(onReviewChanged);
      ref.onDispose(() => gateway.removeListener(onReviewChanged));
      return gateway.initialState(intent, mode: args.mode);
    }

    if (SupabaseConfig.isLocalUiPreview && _captureOverride == null) {
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

    final account = _captureAccount();
    _draftAccount = account;
    void onAccountChanged() {
      if (!_isCurrent(account) && ref.mounted) ref.invalidateSelf();
    }

    AccountContext.changes.addListener(onAccountChanged);
    ref.onDispose(
      () => AccountContext.changes.removeListener(onAccountChanged),
    );
    final vt = await ref.read(vehicleTypeServiceProvider).getAll();
    _requireCurrent(account);
    final favorites = await _loadFavoriteAddresses();
    _requireCurrent(account);
    final agencyNames = await _loadAgencyNames();
    _requireCurrent(account);

    if (args.isEditMode) {
      final trip = await ref
          .read(tripServiceProvider)
          .getTripById(args.editingTripId!);
      _requireCurrent(account);
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

    unawaited(_prefillCurrentPickupIfEmpty(account, buildRevision));

    return initialState;
  }

  Future<List<FavoriteAddress>> _loadFavoriteAddresses() async {
    try {
      return await ref.read(favoriteAddressServiceProvider).list();
    } on StaleAccountWork {
      rethrow;
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
    } on StaleAccountWork {
      rethrow;
    } on Object catch (error) {
      debugPrint('Unable to load bus agencies: $error');
      return PublicTransportService.fallbackAgencyNames;
    }
  }

  Future<void> _prefillCurrentPickupIfEmpty(
    AccountSnapshot? account,
    int buildRevision,
  ) async {
    final revision = ++_locationRevision;
    bool current() =>
        revision == _locationRevision &&
        buildRevision == _buildRevision &&
        _isCurrent(account);
    try {
      final hasAccess = await ref
          .read(appPermissionServiceProvider)
          .hasLocationAccess();
      if (!current() || !hasAccess) return;

      final locationService = ref.read(locationServiceProvider);
      final cached = await locationService.getLastKnownOrCached();
      if (!current()) return;
      final position = cached ?? await locationService.getCurrentPosition();
      if (!current() || position == null) return;

      final currentState = state.value;
      if (currentState == null) return;
      state = AsyncValue.data(
        currentState.copyWith(
          userLat: position.latitude,
          userLng: position.longitude,
        ),
      );
      if (currentState.originDetails != null) return;

      final details = await ref
          .read(placesServiceProvider)
          .reverseGeocode(position.latitude, position.longitude);
      if (!current()) return;
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
    } on Object catch (error) {
      if (current()) debugPrint('Unable to bootstrap location: $error');
    }
  }

  Future<void> handleCurrentLocation() async {
    if (_reviewSelected) {
      final gateway = requireReviewScheduledPosts(_reviewGateway);
      setOrigin(gateway.places(_requireReviewDraft()).first);
      return;
    }
    final account = _captureAccount();
    final revision = ++_locationRevision;
    final buildRevision = _buildRevision;
    bool current() =>
        revision == _locationRevision &&
        buildRevision == _buildRevision &&
        _isCurrent(account);
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(isLoadingLocation: true));
    HapticFeedback.lightImpact();

    try {
      final locationService = ref.read(locationServiceProvider);
      final placesService = ref.read(placesServiceProvider);

      final position = await locationService.getCurrentPosition();
      if (!current()) return;
      if (position == null) {
        final latest = state.value;
        if (latest != null) {
          state = AsyncValue.data(
            latest.copyWith(
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
      if (!current()) return;
      final latest = state.value;
      if (details != null && latest != null) {
        state = AsyncValue.data(
          latest.copyWith(originDetails: details, validationMessage: null),
        );
      }
    } on Object catch (error) {
      if (!current()) return;
      debugPrint('Unable to use current location: $error');
      final latest = state.value;
      if (latest != null) {
        state = AsyncValue.data(
          latest.copyWith(
            validationMessage: 'Unable to use current location. Try again.',
          ),
        );
      }
    } finally {
      if (current()) {
        final finalState = state.value;
        if (finalState != null) {
          state = AsyncValue.data(
            finalState.copyWith(isLoadingLocation: false),
          );
        }
      }
    }
  }

  void setOrigin(PlaceDetails? details) {
    if (_reviewSelected && details != null) {
      details = requireReviewScheduledPosts(
        _reviewGateway,
      ).requirePlace(_requireReviewDraft(), details);
    } else if (_reviewSelected) {
      _requireReviewDraft();
    }
    _locationRevision++;
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(
        originDetails: details,
        validationMessage: null,
        isLoadingLocation: false,
      ),
    );
  }

  void setDestination(PlaceDetails? details) {
    if (_reviewSelected && details != null) {
      details = requireReviewScheduledPosts(
        _reviewGateway,
      ).requirePlace(_requireReviewDraft(), details);
    } else if (_reviewSelected) {
      _requireReviewDraft();
    }
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(destDetails: details, validationMessage: null),
    );
  }

  void useFavoriteAsOrigin(FavoriteAddress address) {
    setOrigin(
      _reviewSelected
          ? requireReviewScheduledPosts(
              _reviewGateway,
            ).favoritePlace(_requireReviewDraft(), address)
          : address.toPlaceDetails(),
    );
  }

  void useFavoriteAsDestination(FavoriteAddress address) {
    setDestination(
      _reviewSelected
          ? requireReviewScheduledPosts(
              _reviewGateway,
            ).favoritePlace(_requireReviewDraft(), address)
          : address.toPlaceDetails(),
    );
  }

  Future<bool> saveFavoriteAddress({
    required bool fromOrigin,
    required String label,
    required String addressType,
  }) async {
    if (_reviewSelected) {
      _requireReviewDraft();
      return false; // The current route offers read-only fixture shortcuts.
    }
    final account = _captureAccount();
    final buildRevision = _buildRevision;
    bool current() => buildRevision == _buildRevision && _isCurrent(account);
    final currentState = state.value;
    if (currentState == null || currentState.isSavingFavoriteAddress) {
      return false;
    }

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
      if (!current()) throw const StaleAccountWork();
      final favorites = await _loadFavoriteAddresses();
      if (!current()) throw const StaleAccountWork();
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
      final finalState = current() ? state.value : null;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(isSavingFavoriteAddress: false),
        );
      }
      rethrow;
    }
  }

  Future<void> deleteFavoriteAddress(FavoriteAddress address) async {
    if (_reviewSelected) {
      _requireReviewDraft();
      throw const ReviewWorldUnavailable('review_favorites_are_read_only');
    }
    final account = _captureAccount();
    final buildRevision = _buildRevision;
    bool current() => buildRevision == _buildRevision && _isCurrent(account);
    final currentState = state.value;
    if (currentState == null || currentState.isSavingFavoriteAddress) return;

    state = AsyncValue.data(
      currentState.copyWith(isSavingFavoriteAddress: true),
    );

    try {
      await ref.read(favoriteAddressServiceProvider).delete(address.id);
      if (!current()) throw const StaleAccountWork();
      final favorites = await _loadFavoriteAddresses();
      if (!current()) throw const StaleAccountWork();
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
      final finalState = current() ? state.value : null;
      if (finalState != null) {
        state = AsyncValue.data(
          finalState.copyWith(isSavingFavoriteAddress: false),
        );
      }
      rethrow;
    }
  }

  void setVehicleId(String id) {
    if (_reviewSelected) _requireReviewDraft();
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
    if (_reviewSelected) _requireReviewDraft();
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(rentalVehicleModel: model, validationMessage: null),
    );
  }

  void setBusAgencyName(String agency) {
    if (_reviewSelected) _requireReviewDraft();
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(busAgencyName: agency, validationMessage: null),
    );
  }

  void setRole(String role) {
    if (_reviewSelected &&
        !requireReviewScheduledPosts(
          _reviewGateway,
        ).canUseRole(_requireReviewDraft(), role)) {
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(
            validationMessage: 'This session cannot create a driver post.',
            showErrors: true,
          ),
        );
      }
      return;
    }
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(selectedRole: role, validationMessage: null),
    );
  }

  void setDate(DateTime date) {
    if (_reviewSelected) _requireReviewDraft();
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(date: date, validationMessage: null),
    );
  }

  void setTime(TimeOfDay time) {
    if (_reviewSelected) _requireReviewDraft();
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(time: time, validationMessage: null),
    );
  }

  void toggleRecurring() {
    if (_reviewSelected) _requireReviewDraft();
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
    if (_reviewSelected) _requireReviewDraft();
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
    if (_reviewSelected) return _submitReviewTrip(note);

    final account = _captureAccount();
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
        _requireCurrent(account);
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
        final finalState = _isCurrent(account) ? state.value : null;
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
      _requireCurrent(account);
      await _loadPoolSuggestions(trip, account);
      _requireCurrent(account);
      return trip;
    } on Object {
      final finalState = _isCurrent(account) ? state.value : null;
      if (finalState != null) {
        state = AsyncValue.data(finalState.copyWith(isSubmitting: false));
      }
      rethrow;
    }
  }

  Trip? _submitReviewTrip(String note) {
    if (_reviewSubmitted) {
      throw const ReviewWorldUnavailable('review_post_already_submitted');
    }
    final intent = _requireReviewDraft();
    final gateway = requireReviewScheduledPosts(_reviewGateway);
    final current = state.value;
    if (current == null || current.isSubmitting) return null;
    final message = current.validateForSubmit(gateway.calendarNow(intent));
    if (message != null) {
      state = AsyncValue.data(
        current.copyWith(showErrors: true, validationMessage: message),
      );
      return null;
    }
    state = AsyncValue.data(current.copyWith(isSubmitting: true));
    try {
      final post = gateway.submit(intent, current, note);
      _reviewSubmitted = true;
      if (!ref.mounted || !gateway.hasCurrentAuthority(intent)) {
        throw const ReviewWorldUnavailable('world_locked');
      }
      final suggestions = current.isEditMode
          ? const <Trip>[]
          : gateway.suggestions(intent, post);
      state = AsyncValue.data(
        current.copyWith(
          createdTrip: post,
          editingTrip: current.isEditMode ? post : null,
          isSubmitting: false,
          poolSuggestions: suggestions,
          validationMessage: null,
        ),
      );
      return post;
    } on Object {
      if (ref.mounted && gateway.hasCurrentAuthority(intent)) {
        state = AsyncValue.data(current.copyWith(isSubmitting: false));
      }
      rethrow;
    }
  }

  Future<void> _loadPoolSuggestions(Trip trip, AccountSnapshot? account) async {
    _requireCurrent(account);
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
      _requireCurrent(account);
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
    } on StaleAccountWork {
      rethrow;
    } on Object catch (error) {
      _requireCurrent(account);
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
