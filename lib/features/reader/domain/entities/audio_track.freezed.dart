// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReaderAudioTrack {

/// The absolute address the player loads.
 String get url;/// Request headers the source declared; empty when it declared none.
 Map<String, String> get headers;
/// Create a copy of ReaderAudioTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderAudioTrackCopyWith<ReaderAudioTrack> get copyWith => _$ReaderAudioTrackCopyWithImpl<ReaderAudioTrack>(this as ReaderAudioTrack, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReaderAudioTrack;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderAudioTrack&&(identical(other.url, _this.url) || other.url == _this.url)&&const DeepCollectionEquality().equals(other.headers, _this.headers));
}


@override
int get hashCode {
  final _this = this as ReaderAudioTrack;
  return Object.hash(runtimeType,_this.url,const DeepCollectionEquality().hash(_this.headers));
}

@override
String toString() {
  final _this = this as ReaderAudioTrack;
  return 'ReaderAudioTrack(url: ${_this.url}, headers: ${_this.headers})';
}


}

/// @nodoc
abstract mixin class $ReaderAudioTrackCopyWith<$Res>  {
  factory $ReaderAudioTrackCopyWith(ReaderAudioTrack value, $Res Function(ReaderAudioTrack) _then) = _$ReaderAudioTrackCopyWithImpl;
@useResult
$Res call({
 String url, Map<String, String> headers
});




}
/// @nodoc
class _$ReaderAudioTrackCopyWithImpl<$Res>
    implements $ReaderAudioTrackCopyWith<$Res> {
  _$ReaderAudioTrackCopyWithImpl(this._self, this._then);

  final ReaderAudioTrack _self;
  final $Res Function(ReaderAudioTrack) _then;

/// Create a copy of ReaderAudioTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? headers = null,}) {
  return _then(ReaderAudioTrack(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderAudioTrack].
extension ReaderAudioTrackPatterns on ReaderAudioTrack {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderAudioTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderAudioTrack() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderAudioTrack value)  $default,){
final _that = this;
switch (_that) {
case _ReaderAudioTrack():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderAudioTrack value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderAudioTrack() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  Map<String, String> headers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderAudioTrack() when $default != null:
return $default(_that.url,_that.headers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  Map<String, String> headers)  $default,) {final _that = this;
switch (_that) {
case _ReaderAudioTrack():
return $default(_that.url,_that.headers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  Map<String, String> headers)?  $default,) {final _that = this;
switch (_that) {
case _ReaderAudioTrack() when $default != null:
return $default(_that.url,_that.headers);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderAudioTrack implements ReaderAudioTrack {
  const _ReaderAudioTrack({required this.url,  Map<String, String> headers = const <String, String>{}}): _headers = headers;
  

/// The absolute address the player loads.
@override final  String url;
/// Request headers the source declared; empty when it declared none.
 final  Map<String, String> _headers;
/// Request headers the source declared; empty when it declared none.
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}


/// Create a copy of ReaderAudioTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderAudioTrackCopyWith<_ReaderAudioTrack> get copyWith => __$ReaderAudioTrackCopyWithImpl<_ReaderAudioTrack>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderAudioTrack&&(identical(other.url, url) || other.url == url)&&const DeepCollectionEquality().equals(other.headers, _headers));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,const DeepCollectionEquality().hash(_headers));
}

@override
String toString() {
    return 'ReaderAudioTrack(url: $url, headers: $headers)';
}


}

/// @nodoc
abstract mixin class _$ReaderAudioTrackCopyWith<$Res> implements $ReaderAudioTrackCopyWith<$Res> {
  factory _$ReaderAudioTrackCopyWith(_ReaderAudioTrack value, $Res Function(_ReaderAudioTrack) _then) = __$ReaderAudioTrackCopyWithImpl;
@override @useResult
$Res call({
 String url, Map<String, String> headers
});




}
/// @nodoc
class __$ReaderAudioTrackCopyWithImpl<$Res>
    implements _$ReaderAudioTrackCopyWith<$Res> {
  __$ReaderAudioTrackCopyWithImpl(this._self, this._then);

  final _ReaderAudioTrack _self;
  final $Res Function(_ReaderAudioTrack) _then;

/// Create a copy of ReaderAudioTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? headers = null,}) {
  return _then(_ReaderAudioTrack(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
