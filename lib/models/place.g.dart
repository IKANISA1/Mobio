// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlacePrediction _$PlacePredictionFromJson(Map<String, dynamic> json) =>
    _PlacePrediction(
      placeId: json['placeId'] as String,
      description: json['description'] as String,
      primaryText: json['primaryText'] as String?,
      secondaryText: json['secondaryText'] as String?,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      predictionType: json['predictionType'] as String? ?? 'place',
    );

Map<String, dynamic> _$PlacePredictionToJson(_PlacePrediction instance) =>
    <String, dynamic>{
      'placeId': instance.placeId,
      'description': instance.description,
      'primaryText': instance.primaryText,
      'secondaryText': instance.secondaryText,
      'distanceMeters': instance.distanceMeters,
      'predictionType': instance.predictionType,
    };

_PlaceDetails _$PlaceDetailsFromJson(Map<String, dynamic> json) =>
    _PlaceDetails(
      placeId: json['placeId'] as String,
      formattedAddress: json['formattedAddress'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$PlaceDetailsToJson(_PlaceDetails instance) =>
    <String, dynamic>{
      'placeId': instance.placeId,
      'formattedAddress': instance.formattedAddress,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
