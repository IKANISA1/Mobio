// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteInfo {

 int get distanceMeters; String get duration; String get encodedPolyline; String get travelMode;
/// Create a copy of RouteInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteInfoCopyWith<RouteInfo> get copyWith => _$RouteInfoCopyWithImpl<RouteInfo>(this as RouteInfo, _$identity);

  /// Serializes this RouteInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteInfo&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.encodedPolyline, encodedPolyline) || other.encodedPolyline == encodedPolyline)&&(identical(other.travelMode, travelMode) || other.travelMode == travelMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,distanceMeters,duration,encodedPolyline,travelMode);

@override
String toString() {
  return 'RouteInfo(distanceMeters: $distanceMeters, duration: $duration, encodedPolyline: $encodedPolyline, travelMode: $travelMode)';
}


}

/// @nodoc
abstract mixin class $RouteInfoCopyWith<$Res>  {
  factory $RouteInfoCopyWith(RouteInfo value, $Res Function(RouteInfo) _then) = _$RouteInfoCopyWithImpl;
@useResult
$Res call({
 int distanceMeters, String duration, String encodedPolyline, String travelMode
});




}
/// @nodoc
class _$RouteInfoCopyWithImpl<$Res>
    implements $RouteInfoCopyWith<$Res> {
  _$RouteInfoCopyWithImpl(this._self, this._then);

  final RouteInfo _self;
  final $Res Function(RouteInfo) _then;

/// Create a copy of RouteInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? distanceMeters = null,Object? duration = null,Object? encodedPolyline = null,Object? travelMode = null,}) {
  return _then(_self.copyWith(
distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as String,encodedPolyline: null == encodedPolyline ? _self.encodedPolyline : encodedPolyline // ignore: cast_nullable_to_non_nullable
as String,travelMode: null == travelMode ? _self.travelMode : travelMode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteInfo].
extension RouteInfoPatterns on RouteInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteInfo value)  $default,){
final _that = this;
switch (_that) {
case _RouteInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteInfo value)?  $default,){
final _that = this;
switch (_that) {
case _RouteInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int distanceMeters,  String duration,  String encodedPolyline,  String travelMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteInfo() when $default != null:
return $default(_that.distanceMeters,_that.duration,_that.encodedPolyline,_that.travelMode);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int distanceMeters,  String duration,  String encodedPolyline,  String travelMode)  $default,) {final _that = this;
switch (_that) {
case _RouteInfo():
return $default(_that.distanceMeters,_that.duration,_that.encodedPolyline,_that.travelMode);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int distanceMeters,  String duration,  String encodedPolyline,  String travelMode)?  $default,) {final _that = this;
switch (_that) {
case _RouteInfo() when $default != null:
return $default(_that.distanceMeters,_that.duration,_that.encodedPolyline,_that.travelMode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteInfo implements RouteInfo {
  const _RouteInfo({required this.distanceMeters, required this.duration, required this.encodedPolyline, this.travelMode = 'DRIVE'});
  factory _RouteInfo.fromJson(Map<String, dynamic> json) => _$RouteInfoFromJson(json);

@override final  int distanceMeters;
@override final  String duration;
@override final  String encodedPolyline;
@override@JsonKey() final  String travelMode;

/// Create a copy of RouteInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteInfoCopyWith<_RouteInfo> get copyWith => __$RouteInfoCopyWithImpl<_RouteInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteInfo&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.encodedPolyline, encodedPolyline) || other.encodedPolyline == encodedPolyline)&&(identical(other.travelMode, travelMode) || other.travelMode == travelMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,distanceMeters,duration,encodedPolyline,travelMode);

@override
String toString() {
  return 'RouteInfo(distanceMeters: $distanceMeters, duration: $duration, encodedPolyline: $encodedPolyline, travelMode: $travelMode)';
}


}

/// @nodoc
abstract mixin class _$RouteInfoCopyWith<$Res> implements $RouteInfoCopyWith<$Res> {
  factory _$RouteInfoCopyWith(_RouteInfo value, $Res Function(_RouteInfo) _then) = __$RouteInfoCopyWithImpl;
@override @useResult
$Res call({
 int distanceMeters, String duration, String encodedPolyline, String travelMode
});




}
/// @nodoc
class __$RouteInfoCopyWithImpl<$Res>
    implements _$RouteInfoCopyWith<$Res> {
  __$RouteInfoCopyWithImpl(this._self, this._then);

  final _RouteInfo _self;
  final $Res Function(_RouteInfo) _then;

/// Create a copy of RouteInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? distanceMeters = null,Object? duration = null,Object? encodedPolyline = null,Object? travelMode = null,}) {
  return _then(_RouteInfo(
distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as String,encodedPolyline: null == encodedPolyline ? _self.encodedPolyline : encodedPolyline // ignore: cast_nullable_to_non_nullable
as String,travelMode: null == travelMode ? _self.travelMode : travelMode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
