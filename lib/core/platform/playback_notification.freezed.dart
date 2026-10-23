// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaybackNotificationMetadata {

/// A stable identity for the track (the media URL).
 String get id;/// The chapter title.
 String get title;/// The book title.
 String get album;/// The track's duration, when known.
 Duration? get duration;/// Cover art, when the reader has one.
 Uri? get artUri;
/// Create a copy of PlaybackNotificationMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackNotificationMetadataCopyWith<PlaybackNotificationMetadata> get copyWith => _$PlaybackNotificationMetadataCopyWithImpl<PlaybackNotificationMetadata>(this as PlaybackNotificationMetadata, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlaybackNotificationMetadata;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackNotificationMetadata&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.album, _this.album) || other.album == _this.album)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.artUri, _this.artUri) || other.artUri == _this.artUri));
}


@override
int get hashCode {
  final _this = this as PlaybackNotificationMetadata;
  return Object.hash(runtimeType,_this.id,_this.title,_this.album,_this.duration,_this.artUri);
}

@override
String toString() {
  final _this = this as PlaybackNotificationMetadata;
  return 'PlaybackNotificationMetadata(id: ${_this.id}, title: ${_this.title}, album: ${_this.album}, duration: ${_this.duration}, artUri: ${_this.artUri})';
}


}

/// @nodoc
abstract mixin class $PlaybackNotificationMetadataCopyWith<$Res>  {
  factory $PlaybackNotificationMetadataCopyWith(PlaybackNotificationMetadata value, $Res Function(PlaybackNotificationMetadata) _then) = _$PlaybackNotificationMetadataCopyWithImpl;
@useResult
$Res call({
 String id, String title, String album, Duration? duration, Uri? artUri
});




}
/// @nodoc
class _$PlaybackNotificationMetadataCopyWithImpl<$Res>
    implements $PlaybackNotificationMetadataCopyWith<$Res> {
  _$PlaybackNotificationMetadataCopyWithImpl(this._self, this._then);

  final PlaybackNotificationMetadata _self;
  final $Res Function(PlaybackNotificationMetadata) _then;

/// Create a copy of PlaybackNotificationMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? album = null,Object? duration = freezed,Object? artUri = freezed,}) {
  return _then(PlaybackNotificationMetadata(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,album: null == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,artUri: freezed == artUri ? _self.artUri : artUri // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaybackNotificationMetadata].
extension PlaybackNotificationMetadataPatterns on PlaybackNotificationMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaybackNotificationMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaybackNotificationMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaybackNotificationMetadata value)  $default,){
final _that = this;
switch (_that) {
case _PlaybackNotificationMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaybackNotificationMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _PlaybackNotificationMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String album,  Duration? duration,  Uri? artUri)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaybackNotificationMetadata() when $default != null:
return $default(_that.id,_that.title,_that.album,_that.duration,_that.artUri);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String album,  Duration? duration,  Uri? artUri)  $default,) {final _that = this;
switch (_that) {
case _PlaybackNotificationMetadata():
return $default(_that.id,_that.title,_that.album,_that.duration,_that.artUri);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String album,  Duration? duration,  Uri? artUri)?  $default,) {final _that = this;
switch (_that) {
case _PlaybackNotificationMetadata() when $default != null:
return $default(_that.id,_that.title,_that.album,_that.duration,_that.artUri);case _:
  return null;

}
}

}

/// @nodoc


class _PlaybackNotificationMetadata implements PlaybackNotificationMetadata {
  const _PlaybackNotificationMetadata({required this.id, required this.title, required this.album, this.duration, this.artUri});
  

/// A stable identity for the track (the media URL).
@override final  String id;
/// The chapter title.
@override final  String title;
/// The book title.
@override final  String album;
/// The track's duration, when known.
@override final  Duration? duration;
/// Cover art, when the reader has one.
@override final  Uri? artUri;

/// Create a copy of PlaybackNotificationMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaybackNotificationMetadataCopyWith<_PlaybackNotificationMetadata> get copyWith => __$PlaybackNotificationMetadataCopyWithImpl<_PlaybackNotificationMetadata>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaybackNotificationMetadata&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.album, album) || other.album == album)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.artUri, artUri) || other.artUri == artUri));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,album,duration,artUri);
}

@override
String toString() {
    return 'PlaybackNotificationMetadata(id: $id, title: $title, album: $album, duration: $duration, artUri: $artUri)';
}


}

/// @nodoc
abstract mixin class _$PlaybackNotificationMetadataCopyWith<$Res> implements $PlaybackNotificationMetadataCopyWith<$Res> {
  factory _$PlaybackNotificationMetadataCopyWith(_PlaybackNotificationMetadata value, $Res Function(_PlaybackNotificationMetadata) _then) = __$PlaybackNotificationMetadataCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String album, Duration? duration, Uri? artUri
});




}
/// @nodoc
class __$PlaybackNotificationMetadataCopyWithImpl<$Res>
    implements _$PlaybackNotificationMetadataCopyWith<$Res> {
  __$PlaybackNotificationMetadataCopyWithImpl(this._self, this._then);

  final _PlaybackNotificationMetadata _self;
  final $Res Function(_PlaybackNotificationMetadata) _then;

/// Create a copy of PlaybackNotificationMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? album = null,Object? duration = freezed,Object? artUri = freezed,}) {
  return _then(_PlaybackNotificationMetadata(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,album: null == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,artUri: freezed == artUri ? _self.artUri : artUri // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}


}

/// @nodoc
mixin _$PlaybackNotificationState {

/// Whether audio is advancing.
 bool get isPlaying;/// Whether the player is buffering.
 bool get isBuffering;/// Whether the track finished.
 bool get isCompleted;/// The position the system projects from.
 Duration get position;/// The playback speed the system projects with.
 double get speed;
/// Create a copy of PlaybackNotificationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackNotificationStateCopyWith<PlaybackNotificationState> get copyWith => _$PlaybackNotificationStateCopyWithImpl<PlaybackNotificationState>(this as PlaybackNotificationState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlaybackNotificationState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackNotificationState&&(identical(other.isPlaying, _this.isPlaying) || other.isPlaying == _this.isPlaying)&&(identical(other.isBuffering, _this.isBuffering) || other.isBuffering == _this.isBuffering)&&(identical(other.isCompleted, _this.isCompleted) || other.isCompleted == _this.isCompleted)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.speed, _this.speed) || other.speed == _this.speed));
}


@override
int get hashCode {
  final _this = this as PlaybackNotificationState;
  return Object.hash(runtimeType,_this.isPlaying,_this.isBuffering,_this.isCompleted,_this.position,_this.speed);
}

@override
String toString() {
  final _this = this as PlaybackNotificationState;
  return 'PlaybackNotificationState(isPlaying: ${_this.isPlaying}, isBuffering: ${_this.isBuffering}, isCompleted: ${_this.isCompleted}, position: ${_this.position}, speed: ${_this.speed})';
}


}

/// @nodoc
abstract mixin class $PlaybackNotificationStateCopyWith<$Res>  {
  factory $PlaybackNotificationStateCopyWith(PlaybackNotificationState value, $Res Function(PlaybackNotificationState) _then) = _$PlaybackNotificationStateCopyWithImpl;
@useResult
$Res call({
 bool isPlaying, bool isBuffering, bool isCompleted, Duration position, double speed
});




}
/// @nodoc
class _$PlaybackNotificationStateCopyWithImpl<$Res>
    implements $PlaybackNotificationStateCopyWith<$Res> {
  _$PlaybackNotificationStateCopyWithImpl(this._self, this._then);

  final PlaybackNotificationState _self;
  final $Res Function(PlaybackNotificationState) _then;

/// Create a copy of PlaybackNotificationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isPlaying = null,Object? isBuffering = null,Object? isCompleted = null,Object? position = null,Object? speed = null,}) {
  return _then(PlaybackNotificationState(
isPlaying: null == isPlaying ? _self.isPlaying : isPlaying // ignore: cast_nullable_to_non_nullable
as bool,isBuffering: null == isBuffering ? _self.isBuffering : isBuffering // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaybackNotificationState].
extension PlaybackNotificationStatePatterns on PlaybackNotificationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaybackNotificationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaybackNotificationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaybackNotificationState value)  $default,){
final _that = this;
switch (_that) {
case _PlaybackNotificationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaybackNotificationState value)?  $default,){
final _that = this;
switch (_that) {
case _PlaybackNotificationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isPlaying,  bool isBuffering,  bool isCompleted,  Duration position,  double speed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaybackNotificationState() when $default != null:
return $default(_that.isPlaying,_that.isBuffering,_that.isCompleted,_that.position,_that.speed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isPlaying,  bool isBuffering,  bool isCompleted,  Duration position,  double speed)  $default,) {final _that = this;
switch (_that) {
case _PlaybackNotificationState():
return $default(_that.isPlaying,_that.isBuffering,_that.isCompleted,_that.position,_that.speed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isPlaying,  bool isBuffering,  bool isCompleted,  Duration position,  double speed)?  $default,) {final _that = this;
switch (_that) {
case _PlaybackNotificationState() when $default != null:
return $default(_that.isPlaying,_that.isBuffering,_that.isCompleted,_that.position,_that.speed);case _:
  return null;

}
}

}

/// @nodoc


class _PlaybackNotificationState implements PlaybackNotificationState {
  const _PlaybackNotificationState({required this.isPlaying, this.isBuffering = false, this.isCompleted = false, this.position = Duration.zero, this.speed = 1.0});
  

/// Whether audio is advancing.
@override final  bool isPlaying;
/// Whether the player is buffering.
@override@JsonKey() final  bool isBuffering;
/// Whether the track finished.
@override@JsonKey() final  bool isCompleted;
/// The position the system projects from.
@override@JsonKey() final  Duration position;
/// The playback speed the system projects with.
@override@JsonKey() final  double speed;

/// Create a copy of PlaybackNotificationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaybackNotificationStateCopyWith<_PlaybackNotificationState> get copyWith => __$PlaybackNotificationStateCopyWithImpl<_PlaybackNotificationState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaybackNotificationState&&(identical(other.isPlaying, isPlaying) || other.isPlaying == isPlaying)&&(identical(other.isBuffering, isBuffering) || other.isBuffering == isBuffering)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.position, position) || other.position == position)&&(identical(other.speed, speed) || other.speed == speed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,isPlaying,isBuffering,isCompleted,position,speed);
}

@override
String toString() {
    return 'PlaybackNotificationState(isPlaying: $isPlaying, isBuffering: $isBuffering, isCompleted: $isCompleted, position: $position, speed: $speed)';
}


}

/// @nodoc
abstract mixin class _$PlaybackNotificationStateCopyWith<$Res> implements $PlaybackNotificationStateCopyWith<$Res> {
  factory _$PlaybackNotificationStateCopyWith(_PlaybackNotificationState value, $Res Function(_PlaybackNotificationState) _then) = __$PlaybackNotificationStateCopyWithImpl;
@override @useResult
$Res call({
 bool isPlaying, bool isBuffering, bool isCompleted, Duration position, double speed
});




}
/// @nodoc
class __$PlaybackNotificationStateCopyWithImpl<$Res>
    implements _$PlaybackNotificationStateCopyWith<$Res> {
  __$PlaybackNotificationStateCopyWithImpl(this._self, this._then);

  final _PlaybackNotificationState _self;
  final $Res Function(_PlaybackNotificationState) _then;

/// Create a copy of PlaybackNotificationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isPlaying = null,Object? isBuffering = null,Object? isCompleted = null,Object? position = null,Object? speed = null,}) {
  return _then(_PlaybackNotificationState(
isPlaying: null == isPlaying ? _self.isPlaying : isPlaying // ignore: cast_nullable_to_non_nullable
as bool,isBuffering: null == isBuffering ? _self.isBuffering : isBuffering // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
