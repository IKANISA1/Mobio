// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride_request.freezed.dart';
part 'ride_request.g.dart';

/// Status lifecycle of a ride request/offer.
enum RideRequestStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('accepted')
  accepted,
  @JsonValue('declined')
  declined,
  @JsonValue('cancelled')
  cancelled,
}

/// Type of interaction.
enum RideRequestType {
  @JsonValue('request')
  request,
  @JsonValue('offer')
  offer,
}

@freezed
abstract class RideRequest with _$RideRequest {
  const RideRequest._();

  const factory RideRequest({
    /// UUID primary key.
    String? id,

    /// The trip this request is associated with (null for nearby-driver requests).
    @JsonKey(name: 'trip_id') String? tripId,

    /// Who sent the request/offer.
    @JsonKey(name: 'requester_id') required String requesterId,

    /// Who receives/responds to the request/offer.
    @JsonKey(name: 'responder_id') required String responderId,

    /// 'request' (passenger→driver) or 'offer' (driver→passenger).
    @Default(RideRequestType.request) RideRequestType type,

    /// Current status.
    @Default(RideRequestStatus.pending) RideRequestStatus status,

    /// Optional message from the requester.
    String? message,

    /// Extra data (vehicle type, distance, etc.).
    @Default({}) Map<String, dynamic> metadata,

    /// Timestamps.
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _RideRequest;

  factory RideRequest.fromJson(Map<String, dynamic> json) =>
      _$RideRequestFromJson(json);

  /// Whether this request is still actionable.
  bool get isPending => status == RideRequestStatus.pending;

  /// Whether the given user is the responder.
  bool isResponder(String userId) => responderId == userId;

  /// Whether the given user is the requester.
  bool isRequester(String userId) => requesterId == userId;
}
