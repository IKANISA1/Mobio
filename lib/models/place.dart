import 'package:freezed_annotation/freezed_annotation.dart';

part 'place.freezed.dart';
part 'place.g.dart';

@freezed
abstract class PlacePrediction with _$PlacePrediction {
  const factory PlacePrediction({
    required String placeId,
    required String description,

    /// Structured primary text (e.g. "Kicukiro Centre").
    String? primaryText,

    /// Structured secondary text (e.g. "Kigali, Rwanda").
    String? secondaryText,

    /// Distance from user's location in meters, if available.
    int? distanceMeters,

    /// "place" for place predictions, "query" for semantic/query predictions.
    @Default('place') String predictionType,
  }) = _PlacePrediction;

  factory PlacePrediction.fromJson(Map<String, dynamic> json) =>
      _$PlacePredictionFromJson(json);
}

@freezed
abstract class PlaceDetails with _$PlaceDetails {
  const factory PlaceDetails({
    required String placeId,
    required String formattedAddress,
    required double latitude,
    required double longitude,
  }) = _PlaceDetails;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) =>
      _$PlaceDetailsFromJson(json);
}
