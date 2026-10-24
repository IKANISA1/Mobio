import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/features/bookings/application/schedule_trip_state.dart';
import 'package:mobi_app/features/store_review/application/review_marketplace_owner.dart';
import 'package:mobi_app/features/store_review/domain/review_marketplace_store.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:mobi_app/features/store_review/domain/review_world_models.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';
import 'package:mobi_shared_types/models/trip.dart';

/// An opaque reviewed local row/draft, never a hosted operation or receipt.
final class ReviewScheduledPostIntent {
  ReviewScheduledPostIntent._(
    this._gateway,
    this._action,
    this.binding,
    this.worldInstance,
    this.targetId,
    this.expectedRevision,
    this.trip,
  );
  final ReviewScheduledPostGateway _gateway;
  final ReviewWorldAction _action;
  final ReviewWorldBinding binding;
  final int worldInstance;
  final String? targetId;
  final int? expectedRevision;
  final Trip? trip;
  String get actorId => _action.actorId;
}

final class ReviewScheduledPostPage {
  ReviewScheduledPostPage({
    required this.intent,
    required List<Trip> own,
    required List<Trip> counterpart,
    required Map<String, ReviewScheduledPostIntent> rows,
  }) : own = List.unmodifiable(own),
       counterpart = List.unmodifiable(counterpart),
       rows = Map.unmodifiable(rows);
  final ReviewScheduledPostIntent intent;
  final List<Trip> own;
  final List<Trip> counterpart;
  final Map<String, ReviewScheduledPostIntent> rows;
}

/// Feature composition of the accepted volatile owner only. It does not import
/// SDK/services, persistence, location, Places, permissions or transport APIs.
final class ReviewScheduledPostGateway extends ChangeNotifier {
  ReviewScheduledPostGateway(this.owner, {this.chatAvailable = false}) {
    owner.addListener(_changed);
  }
  final ReviewMarketplaceOwner owner;
  final bool chatAvailable;
  bool _disposed = false;
  bool get hasTransport => owner.hasTransport;
  ReviewWorldPhase get phase => owner.phase;
  static const rwandaOffset = Duration(hours: 2);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  ReviewWorldSnapshot _guard(
    ReviewScheduledPostIntent intent, {
    bool requireTargetRevision = true,
  }) {
    if (_disposed || !identical(intent._gateway, this)) {
      throw const ReviewWorldUnavailable('foreign_scheduled_intent');
    }
    final world = owner.store.snapshot(intent._action);
    if (!world.binding.sameWorld(intent.binding) ||
        world.worldInstance != intent.worldInstance ||
        (requireTargetRevision &&
            intent.targetId != null &&
            world.tripRevisions[intent.targetId] != intent.expectedRevision)) {
      throw const ReviewWorldUnavailable('stale_scheduled_intent');
    }
    return world;
  }

  bool hasCurrentAuthority(ReviewScheduledPostIntent intent) {
    try {
      _guard(intent, requireTargetRevision: false);
      return true;
    } on Object {
      return false;
    }
  }

  bool isCurrent(ReviewScheduledPostIntent intent) {
    try {
      _guard(intent);
      return true;
    } on Object {
      return false;
    }
  }

  ReviewScheduledPostIntent capture({String? targetId}) {
    if (_disposed) throw const ReviewWorldUnavailable('gateway_disposed');
    final action = owner.captureAction();
    final world = owner.store.snapshot(action);
    return _intent(world, action, targetId);
  }

  ReviewScheduledPostIntent _intent(
    ReviewWorldSnapshot world,
    ReviewWorldAction action,
    String? id,
  ) {
    final trip = id == null ? null : world.trips[id];
    if (id != null && trip == null) {
      throw const ReviewWorldUnavailable('unknown_post');
    }
    return ReviewScheduledPostIntent._(
      this,
      action,
      world.binding,
      world.worldInstance,
      id,
      id == null ? null : world.tripRevisions[id],
      trip == null ? null : _present(trip),
    );
  }

  DateTime now(ReviewScheduledPostIntent intent) {
    _guard(intent, requireTargetRevision: false);
    final now = owner.serverTimeUpperBound;
    if (now == null || !now.isUtc) {
      throw const ReviewWorldUnavailable('world_locked');
    }
    _guard(intent, requireTargetRevision: false);
    return now;
  }

  /// UTC-typed calendar components representing Rwanda wall time. Device
  /// timezone/wall clock never participates in reviewer scheduling authority.
  DateTime calendarNow(ReviewScheduledPostIntent intent) =>
      now(intent).add(rwandaOffset);

  List<PlaceDetails> places(ReviewScheduledPostIntent intent) {
    final entries = _guard(intent).places.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return List.unmodifiable(entries.map(_place));
  }

  static PlaceDetails _place(ReviewPlace value) => PlaceDetails(
    placeId: value.id,
    formattedAddress: value.label,
    latitude: value.latitude,
    longitude: value.longitude,
  );

  PlaceDetails requirePlace(
    ReviewScheduledPostIntent intent,
    PlaceDetails value,
  ) {
    final place = _guard(intent).places[value.placeId];
    if (place == null ||
        value.formattedAddress != place.label ||
        value.latitude != place.latitude ||
        value.longitude != place.longitude) {
      throw const ReviewWorldUnavailable('foreign_review_place');
    }
    return _place(place);
  }

  /// Deterministic read-only local shortcuts, derived solely from the 3 places.
  /// These are explicitly local IDs, never fabricated backend favorite IDs.
  List<FavoriteAddress> favorites(ReviewScheduledPostIntent intent) =>
      List.unmodifiable([
        for (final (index, place) in places(intent).indexed)
          FavoriteAddress(
            id: 'review-favorite:${intent.worldInstance}:${place.placeId}',
            profileId: intent.actorId,
            label: place.formattedAddress,
            addressType: 'other',
            formattedAddress: place.formattedAddress,
            placeId: place.placeId,
            latitude: place.latitude,
            longitude: place.longitude,
            sortOrder: index,
          ),
      ]);

  PlaceDetails favoritePlace(
    ReviewScheduledPostIntent intent,
    FavoriteAddress value,
  ) {
    final expected = favorites(intent).where((item) => item.id == value.id);
    if (expected.length != 1 ||
        value.profileId != intent.actorId ||
        value.placeId != expected.single.placeId ||
        value.formattedAddress != expected.single.formattedAddress ||
        value.latitude != expected.single.latitude ||
        value.longitude != expected.single.longitude) {
      throw const ReviewWorldUnavailable('foreign_review_favorite');
    }
    return requirePlace(intent, value.toPlaceDetails());
  }

  bool canUseRole(ReviewScheduledPostIntent intent, String role) {
    final profile = _guard(intent).profile;
    return role == 'passenger' || (role == 'driver' && profile.isDriver);
  }

  ScheduleTripState initialState(
    ReviewScheduledPostIntent intent, {
    String? mode,
  }) {
    final world = _guard(intent);
    final trip = intent.trip;
    if (trip != null && (trip.authorId != intent.actorId || !trip.isActive)) {
      throw const ReviewWorldUnavailable('post_not_editable');
    }
    final catalog = places(intent);
    final departure = trip == null
        ? calendarNow(intent).add(const Duration(hours: 1))
        : _startsAt(trip).add(rwandaOffset);
    final role = trip?.role ?? mode ?? 'passenger';
    if (!canUseRole(intent, role)) {
      throw const ReviewWorldUnavailable('driver_role_required');
    }
    return ScheduleTripState(
      isReviewSession: true,
      reviewPlaces: catalog,
      vehicleTypes: List.unmodifiable(VehicleTypeModel.fallbackTypes),
      transportAgencyNames: const [],
      selectedRole: role,
      vehicleId: trip?.vehicleTypeStr ?? world.profile.vehicleType ?? 'cab',
      originDetails: trip == null
          ? catalog.first
          : _place(world.places[trip.originPlaceId]!),
      destDetails: trip == null
          ? null
          : _place(world.places[trip.destinationPlaceId]!),
      favoriteAddresses: favorites(intent),
      date: DateTime.utc(departure.year, departure.month, departure.day),
      time: TimeOfDay(hour: departure.hour, minute: departure.minute),
      isRecurring: trip?.isRecurring ?? false,
      recurringDays: List.unmodifiable(trip?.recurringDays ?? const []),
      editingTrip: trip,
      clientRequestId: '',
    );
  }

  ReviewScheduledPostPage page(String mode) {
    if (!const ['passenger', 'driver'].contains(mode)) {
      throw const ReviewWorldUnavailable('invalid_viewer_mode');
    }
    final intent = capture();
    final world = _guard(intent);
    final own = owner.store.listTrips(
      intent._action,
      ownOnly: true,
      includeCancelled: true,
    );
    final counterpart = owner.store
        .listTrips(
          intent._action,
          role: mode == 'driver'
              ? MarketplaceRole.passenger
              : MarketplaceRole.driver,
        )
        .where((trip) => trip.authorId != intent.actorId)
        .toList();
    return ReviewScheduledPostPage(
      intent: intent,
      own: own.map(_present).toList(),
      counterpart: counterpart.map(_present).toList(),
      rows: {
        for (final trip in [...own, ...counterpart])
          trip.id!: _intent(world, intent._action, trip.id),
      },
    );
  }

  Trip get(ReviewScheduledPostIntent intent) {
    final id = intent.targetId;
    if (id == null) throw const ReviewWorldUnavailable('missing_post_target');
    _guard(intent);
    return _present(owner.store.getTrip(intent._action, id));
  }

  ReviewTripDraft _draft(
    ReviewScheduledPostIntent intent,
    ScheduleTripState state,
    String note,
  ) {
    if (!state.isReviewSession ||
        state.originDetails == null ||
        state.destDetails == null ||
        !canUseRole(intent, state.selectedRole ?? '')) {
      throw const ReviewWorldUnavailable('invalid_post');
    }
    final origin = requirePlace(intent, state.originDetails!);
    final destination = requirePlace(intent, state.destDetails!);
    return ReviewTripDraft(
      originPlaceId: origin.placeId,
      destinationPlaceId: destination.placeId,
      departureAt: DateTime.utc(
        state.date.year,
        state.date.month,
        state.date.day,
        state.time.hour,
        state.time.minute,
      ).subtract(rwandaOffset),
      role: state.selectedRole == 'driver'
          ? MarketplaceRole.driver
          : MarketplaceRole.passenger,
      vehicleType: state.vehicleId == 'private_' ? 'private' : state.vehicleId,
      seats: intent.trip?.seats ?? 1,
      note: note.trim().isEmpty ? null : note.trim(),
      recurringDays: state.isRecurring ? state.recurringDays : const [],
    );
  }

  Trip submit(
    ReviewScheduledPostIntent intent,
    ScheduleTripState state,
    String note,
  ) {
    _guard(intent);
    final input = _draft(intent, state, note);
    final post = owner.perform<Trip>(
      intent._action,
      (store) => intent.targetId == null
          ? store.createTrip(intent._action, input)
          : store.editTrip(
              intent._action,
              intent.targetId!,
              input,
              expectedRevision: intent.expectedRevision!,
            ),
    );
    return _present(post);
  }

  Trip cancel(ReviewScheduledPostIntent intent) {
    _guard(intent);
    final id = intent.targetId;
    if (id == null) throw const ReviewWorldUnavailable('missing_post_target');
    return _present(
      owner.perform<Trip>(
        intent._action,
        (store) => store.cancelTrip(
          intent._action,
          id,
          expectedRevision: intent.expectedRevision!,
        ),
      ),
    );
  }

  List<Trip> suggestions(ReviewScheduledPostIntent intent, Trip created) {
    _guard(intent);
    return List.unmodifiable(
      owner.store
          .listTrips(intent._action)
          .where(
            (trip) =>
                trip.id != created.id &&
                trip.authorId != intent.actorId &&
                trip.role != created.role &&
                trip.originPlaceId == created.originPlaceId &&
                trip.destinationPlaceId == created.destinationPlaceId,
          )
          .take(8)
          .map(_present),
    );
  }

  static DateTime _startsAt(Trip trip) {
    final raw = trip.startsAt;
    if (raw == null || !raw.endsWith('Z')) {
      throw const ReviewWorldUnavailable('invalid_fixture_departure');
    }
    return DateTime.parse(raw).toUtc();
  }

  static Trip _present(Trip trip) {
    final local = _startsAt(trip).add(rwandaOffset);
    String two(int value) => value.toString().padLeft(2, '0');
    return ReviewWorldSnapshot.copyTrip(
      trip.copyWith(
        departureDate: '${local.year}-${two(local.month)}-${two(local.day)}',
        departureTime: '${two(local.hour)}:${two(local.minute)}',
        time: '${two(local.hour)}:${two(local.minute)}',
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    owner.removeListener(_changed);
    super.dispose();
  }
}

/// Render-captured continuation fence. It cannot recapture a replacement world
/// from a later mutable screen field when an old dialog/button completes.
final class ScheduledPostUiAction {
  const ScheduledPostUiAction.ordinary(AccountActionToken action)
    : _ordinary = action,
      gateway = null,
      intent = null,
      _review = false;
  const ScheduledPostUiAction.review(this.gateway, this.intent)
    : _ordinary = null,
      _review = true;
  final AccountActionToken? _ordinary;
  final ReviewScheduledPostGateway? gateway;
  final ReviewScheduledPostIntent? intent;
  final bool _review;
  bool get isCurrent => _review
      ? gateway != null && intent != null && gateway!.isCurrent(intent!)
      : _ordinary?.isCurrent == true;
  bool get hasAuthority => _review
      ? gateway != null &&
            intent != null &&
            gateway!.hasCurrentAuthority(intent!)
      : _ordinary?.isCurrent == true;
}
