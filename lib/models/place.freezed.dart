// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'place.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlacePrediction {

 String get placeId; String get description;/// Structured primary text (e.g. "Kicukiro Centre").
 String? get primaryText;/// Structured secondary text (e.g. "Kigali, Rwanda").
 String? get secondaryText;/// Distance from user's location in meters, if available.
 int? get distanceMeters;/// "place" for place predictions, "query" for semantic/query predictions.
 String get predictionType;
/// Create a copy of PlacePrediction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlacePredictionCopyWith<PlacePrediction> get copyWith => _$PlacePredictionCopyWithImpl<PlacePrediction>(this as PlacePrediction, _$identity);

  /// Serializes this PlacePrediction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlacePrediction&&(identical(other.placeId, placeId) || other.placeId == placeId)&&(identical(other.description, description) || other.description == description)&&(identical(other.primaryText, primaryText) || other.primaryText == primaryText)&&(identical(other.secondaryText, secondaryText) || other.secondaryText == secondaryText)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.predictionType, predictionType) || other.predictionType == predictionType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,placeId,description,primaryText,secondaryText,distanceMeters,predictionType);

@override
String toString() {
  return 'PlacePrediction(placeId: $placeId, description: $description, primaryText: $primaryText, secondaryText: $secondaryText, distanceMeters: $distanceMeters, predictionType: $predictionType)';
}


}

/// @nodoc
abstract mixin class $PlacePredictionCopyWith<$Res>  {
  factory $PlacePredictionCopyWith(PlacePrediction value, $Res Function(PlacePrediction) _then) = _$PlacePredictionCopyWithImpl;
@useResult
$Res call({
 String placeId, String description, String? primaryText, String? secondaryText, int? distanceMeters, String predictionType
});




}
/// @nodoc
class _$PlacePredictionCopyWithImpl<$Res>
    implements $PlacePredictionCopyWith<$Res> {
  _$PlacePredictionCopyWithImpl(this._self, this._then);

  final PlacePrediction _self;
  final $Res Function(PlacePrediction) _then;

/// Create a copy of PlacePrediction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? placeId = null,Object? description = null,Object? primaryText = freezed,Object? secondaryText = freezed,Object? distanceMeters = freezed,Object? predictionType = null,}) {
  return _then(_self.copyWith(
placeId: null == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,primaryText: freezed == primaryText ? _self.primaryText : primaryText // ignore: cast_nullable_to_non_nullable
as String?,secondaryText: freezed == secondaryText ? _self.secondaryText : secondaryText // ignore: cast_nullable_to_non_nullable
as String?,distanceMeters: freezed == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as int?,predictionType: null == predictionType ? _self.predictionType : predictionType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PlacePrediction].
extension PlacePredictionPatterns on PlacePrediction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlacePrediction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlacePrediction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlacePrediction value)  $default,){
final _that = this;
switch (_that) {
case _PlacePrediction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlacePrediction value)?  $default,){
final _that = this;
switch (_that) {
case _PlacePrediction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String placeId,  String description,  String? primaryText,  String? secondaryText,  int? distanceMeters,  String predictionType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlacePrediction() when $default != null:
return $default(_that.placeId,_that.description,_that.primaryText,_that.secondaryText,_that.distanceMeters,_that.predictionType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String placeId,  String description,  String? primaryText,  String? secondaryText,  int? distanceMeters,  String predictionType)  $default,) {final _that = this;
switch (_that) {
case _PlacePrediction():
return $default(_that.placeId,_that.description,_that.primaryText,_that.secondaryText,_that.distanceMeters,_that.predictionType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String placeId,  String description,  String? primaryText,  String? secondaryText,  int? distanceMeters,  String predictionType)?  $default,) {final _that = this;
switch (_that) {
case _PlacePrediction() when $default != null:
return $default(_that.placeId,_that.description,_that.primaryText,_that.secondaryText,_that.distanceMeters,_that.predictionType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlacePrediction implements PlacePrediction {
  const _PlacePrediction({required this.placeId, required this.description, this.primaryText, this.secondaryText, this.distanceMeters, this.predictionType = 'place'});
  factory _PlacePrediction.fromJson(Map<String, dynamic> json) => _$PlacePredictionFromJson(json);

@override final  String placeId;
@override final  String description;
/// Structured primary text (e.g. "Kicukiro Centre").
@override final  String? primaryText;
/// Structured secondary text (e.g. "Kigali, Rwanda").
@override final  String? secondaryText;
/// Distance from user's location in meters, if available.
@override final  int? distanceMeters;
/// "place" for place predictions, "query" for semantic/query predictions.
@override@JsonKey() final  String predictionType;

/// Create a copy of PlacePrediction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlacePredictionCopyWith<_PlacePrediction> get copyWith => __$PlacePredictionCopyWithImpl<_PlacePrediction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlacePredictionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlacePrediction&&(identical(other.placeId, placeId) || other.placeId == placeId)&&(identical(other.description, description) || other.description == description)&&(identical(other.primaryText, primaryText) || other.primaryText == primaryText)&&(identical(other.secondaryText, secondaryText) || other.secondaryText == secondaryText)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.predictionType, predictionType) || other.predictionType == predictionType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,placeId,description,primaryText,secondaryText,distanceMeters,predictionType);

@override
String toString() {
  return 'PlacePrediction(placeId: $placeId, description: $description, primaryText: $primaryText, secondaryText: $secondaryText, distanceMeters: $distanceMeters, predictionType: $predictionType)';
}


}

/// @nodoc
abstract mixin class _$PlacePredictionCopyWith<$Res> implements $PlacePredictionCopyWith<$Res> {
  factory _$PlacePredictionCopyWith(_PlacePrediction value, $Res Function(_PlacePrediction) _then) = __$PlacePredictionCopyWithImpl;
@override @useResult
$Res call({
 String placeId, String description, String? primaryText, String? secondaryText, int? distanceMeters, String predictionType
});




}
/// @nodoc
class __$PlacePredictionCopyWithImpl<$Res>
    implements _$PlacePredictionCopyWith<$Res> {
  __$PlacePredictionCopyWithImpl(this._self, this._then);

  final _PlacePrediction _self;
  final $Res Function(_PlacePrediction) _then;

/// Create a copy of PlacePrediction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? placeId = null,Object? description = null,Object? primaryText = freezed,Object? secondaryText = freezed,Object? distanceMeters = freezed,Object? predictionType = null,}) {
  return _then(_PlacePrediction(
placeId: null == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,primaryText: freezed == primaryText ? _self.primaryText : primaryText // ignore: cast_nullable_to_non_nullable
as String?,secondaryText: freezed == secondaryText ? _self.secondaryText : secondaryText // ignore: cast_nullable_to_non_nullable
as String?,distanceMeters: freezed == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as int?,predictionType: null == predictionType ? _self.predictionType : predictionType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PlaceDetails {

 String get placeId; String get formattedAddress; double get latitude; double get longitude;
/// Create a copy of PlaceDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaceDetailsCopyWith<PlaceDetails> get copyWith => _$PlaceDetailsCopyWithImpl<PlaceDetails>(this as PlaceDetails, _$identity);

  /// Serializes this PlaceDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaceDetails&&(identical(other.placeId, placeId) || other.placeId == placeId)&&(identical(other.formattedAddress, formattedAddress) || other.formattedAddress == formattedAddress)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,placeId,formattedAddress,latitude,longitude);

@override
String toString() {
  return 'PlaceDetails(placeId: $placeId, formattedAddress: $formattedAddress, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class $PlaceDetailsCopyWith<$Res>  {
  factory $PlaceDetailsCopyWith(PlaceDetails value, $Res Function(PlaceDetails) _then) = _$PlaceDetailsCopyWithImpl;
@useResult
$Res call({
 String placeId, String formattedAddress, double latitude, double longitude
});




}
/// @nodoc
class _$PlaceDetailsCopyWithImpl<$Res>
    implements $PlaceDetailsCopyWith<$Res> {
  _$PlaceDetailsCopyWithImpl(this._self, this._then);

  final PlaceDetails _self;
  final $Res Function(PlaceDetails) _then;

/// Create a copy of PlaceDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? placeId = null,Object? formattedAddress = null,Object? latitude = null,Object? longitude = null,}) {
  return _then(_self.copyWith(
placeId: null == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String,formattedAddress: null == formattedAddress ? _self.formattedAddress : formattedAddress // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaceDetails].
extension PlaceDetailsPatterns on PlaceDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaceDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaceDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaceDetails value)  $default,){
final _that = this;
switch (_that) {
case _PlaceDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaceDetails value)?  $default,){
final _that = this;
switch (_that) {
case _PlaceDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String placeId,  String formattedAddress,  double latitude,  double longitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaceDetails() when $default != null:
return $default(_that.placeId,_that.formattedAddress,_that.latitude,_that.longitude);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String placeId,  String formattedAddress,  double latitude,  double longitude)  $default,) {final _that = this;
switch (_that) {
case _PlaceDetails():
return $default(_that.placeId,_that.formattedAddress,_that.latitude,_that.longitude);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String placeId,  String formattedAddress,  double latitude,  double longitude)?  $default,) {final _that = this;
switch (_that) {
case _PlaceDetails() when $default != null:
return $default(_that.placeId,_that.formattedAddress,_that.latitude,_that.longitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlaceDetails implements PlaceDetails {
  const _PlaceDetails({required this.placeId, required this.formattedAddress, required this.latitude, required this.longitude});
  factory _PlaceDetails.fromJson(Map<String, dynamic> json) => _$PlaceDetailsFromJson(json);

@override final  String placeId;
@override final  String formattedAddress;
@override final  double latitude;
@override final  double longitude;

/// Create a copy of PlaceDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaceDetailsCopyWith<_PlaceDetails> get copyWith => __$PlaceDetailsCopyWithImpl<_PlaceDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlaceDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaceDetails&&(identical(other.placeId, placeId) || other.placeId == placeId)&&(identical(other.formattedAddress, formattedAddress) || other.formattedAddress == formattedAddress)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,placeId,formattedAddress,latitude,longitude);

@override
String toString() {
  return 'PlaceDetails(placeId: $placeId, formattedAddress: $formattedAddress, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class _$PlaceDetailsCopyWith<$Res> implements $PlaceDetailsCopyWith<$Res> {
  factory _$PlaceDetailsCopyWith(_PlaceDetails value, $Res Function(_PlaceDetails) _then) = __$PlaceDetailsCopyWithImpl;
@override @useResult
$Res call({
 String placeId, String formattedAddress, double latitude, double longitude
});




}
/// @nodoc
class __$PlaceDetailsCopyWithImpl<$Res>
    implements _$PlaceDetailsCopyWith<$Res> {
  __$PlaceDetailsCopyWithImpl(this._self, this._then);

  final _PlaceDetails _self;
  final $Res Function(_PlaceDetails) _then;

/// Create a copy of PlaceDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? placeId = null,Object? formattedAddress = null,Object? latitude = null,Object? longitude = null,}) {
  return _then(_PlaceDetails(
placeId: null == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String,formattedAddress: null == formattedAddress ? _self.formattedAddress : formattedAddress // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
