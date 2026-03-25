import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_info.freezed.dart';
part 'route_info.g.dart';

@freezed
abstract class RouteInfo with _$RouteInfo {
  const factory RouteInfo({
    required int distanceMeters,
    required String duration,
    required String encodedPolyline,
    @Default('DRIVE') String travelMode,
  }) = _RouteInfo;

  factory RouteInfo.fromJson(Map<String, dynamic> json) =>
      _$RouteInfoFromJson(json);
}
