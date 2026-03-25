// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteInfo _$RouteInfoFromJson(Map<String, dynamic> json) => _RouteInfo(
  distanceMeters: (json['distanceMeters'] as num).toInt(),
  duration: json['duration'] as String,
  encodedPolyline: json['encodedPolyline'] as String,
  travelMode: json['travelMode'] as String? ?? 'DRIVE',
);

Map<String, dynamic> _$RouteInfoToJson(_RouteInfo instance) =>
    <String, dynamic>{
      'distanceMeters': instance.distanceMeters,
      'duration': instance.duration,
      'encodedPolyline': instance.encodedPolyline,
      'travelMode': instance.travelMode,
    };
