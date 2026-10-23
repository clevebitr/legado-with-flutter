// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_playback_engine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioPlaybackSnapshot {

/// Whether audio is advancing right now.
 bool get isPlaying;/// Whether the player is loading or buffering.
 bool get isBuffering;/// Whether the stream reached its end.
 bool get isCompleted;/// Position inside the current track.
 Duration get position;/// The track's duration, or `null` before the player decoded its metadata.
 Duration? get duration;/// A playback failure the player reported after the load.
 ParseFailure<Never>? get failure;
/// Create a copy of AudioPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioPlaybackSnapshotCopyWith<AudioPlaybackSnapshot> get copyWith => _$AudioPlaybackSnapshotCopyWithImpl<AudioPlaybackSnapshot>(this as AudioPlaybackSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AudioPlaybackSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioPlaybackSnapshot&&(identical(other.isPlaying, _this.isPlaying) || other.isPlaying == _this.isPlaying)&&(identical(other.isBuffering, _this.isBuffering) || other.isBuffering == _this.isBuffering)&&(identical(other.isCompleted, _this.isCompleted) || other.isCompleted == _this.isCompleted)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&const DeepCollectionEquality().equals(other.failure, _this.failure));
}


@override
int get hashCode {
  final _this = this as AudioPlaybackSnapshot;
  return Object.hash(runtimeType,_this.isPlaying,_this.isBuffering,_this.isCompleted,_this.position,_this.duration,const DeepCollectionEquality().hash(_this.failure));
}

@override
String toString() {
  final _this = this as AudioPlaybackSnapshot;
  return 'AudioPlaybackSnapshot(isPlaying: ${_this.isPlaying}, isBuffering: ${_this.isBuffering}, isCompleted: ${_this.isCompleted}, position: ${_this.position}, duration: ${_this.duration}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $AudioPlaybackSnapshotCopyWith<$Res>  {
  factory $AudioPlaybackSnapshotCopyWith(AudioPlaybackSnapshot value, $Res Function(AudioPlaybackSnapshot) _then) = _$AudioPlaybackSnapshotCopyWithImpl;
@useResult
$Res call({
 bool isPlaying, bool isBuffering, bool isCompleted, Duration position, Duration? duration, ParseFailure<Never>? failure
});




}
/// @nodoc
class _$AudioPlaybackSnapshotCopyWithImpl<$Res>
    implements $AudioPlaybackSnapshotCopyWith<$Res> {
  _$AudioPlaybackSnapshotCopyWithImpl(this._self, this._then);

  final AudioPlaybackSnapshot _self;
  final $Res Function(AudioPlaybackSnapshot) _then;

/// Create a copy of AudioPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isPlaying = null,Object? isBuffering = null,Object? isCompleted = null,Object? position = null,Object? duration = freezed,Object? failure = freezed,}) {
  return _then(AudioPlaybackSnapshot(
isPlaying: null == isPlaying ? _self.isPlaying : isPlaying // ignore: cast_nullable_to_non_nullable
as bool,isBuffering: null == isBuffering ? _self.isBuffering : isBuffering // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailure<Never>?,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioPlaybackSnapshot].
extension AudioPlaybackSnapshotPatterns on AudioPlaybackSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioPlaybackSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioPlaybackSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioPlaybackSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _AudioPlaybackSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioPlaybackSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _AudioPlaybackSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isPlaying,  bool isBuffering,  bool isCompleted,  Duration position,  Duration? duration,  ParseFailure<Never>? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioPlaybackSnapshot() when $default != null:
return $default(_that.isPlaying,_that.isBuffering,_that.isCompleted,_that.position,_that.duration,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isPlaying,  bool isBuffering,  bool isCompleted,  Duration position,  Duration? duration,  ParseFailure<Never>? failure)  $default,) {final _that = this;
switch (_that) {
case _AudioPlaybackSnapshot():
return $default(_that.isPlaying,_that.isBuffering,_that.isCompleted,_that.position,_that.duration,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isPlaying,  bool isBuffering,  bool isCompleted,  Duration position,  Duration? duration,  ParseFailure<Never>? failure)?  $default,) {final _that = this;
switch (_that) {
case _AudioPlaybackSnapshot() when $default != null:
return $default(_that.isPlaying,_that.isBuffering,_that.isCompleted,_that.position,_that.duration,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _AudioPlaybackSnapshot implements AudioPlaybackSnapshot {
  const _AudioPlaybackSnapshot({this.isPlaying = false, this.isBuffering = false, this.isCompleted = false, this.position = Duration.zero, this.duration, this.failure});
  

/// Whether audio is advancing right now.
@override@JsonKey() final  bool isPlaying;
/// Whether the player is loading or buffering.
@override@JsonKey() final  bool isBuffering;
/// Whether the stream reached its end.
@override@JsonKey() final  bool isCompleted;
/// Position inside the current track.
@override@JsonKey() final  Duration position;
/// The track's duration, or `null` before the player decoded its metadata.
@override final  Duration? duration;
/// A playback failure the player reported after the load.
@override final  ParseFailure<Never>? failure;

/// Create a copy of AudioPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioPlaybackSnapshotCopyWith<_AudioPlaybackSnapshot> get copyWith => __$AudioPlaybackSnapshotCopyWithImpl<_AudioPlaybackSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioPlaybackSnapshot&&(identical(other.isPlaying, isPlaying) || other.isPlaying == isPlaying)&&(identical(other.isBuffering, isBuffering) || other.isBuffering == isBuffering)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.position, position) || other.position == position)&&(identical(other.duration, duration) || other.duration == duration)&&const DeepCollectionEquality().equals(other.failure, failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,isPlaying,isBuffering,isCompleted,position,duration,const DeepCollectionEquality().hash(failure));
}

@override
String toString() {
    return 'AudioPlaybackSnapshot(isPlaying: $isPlaying, isBuffering: $isBuffering, isCompleted: $isCompleted, position: $position, duration: $duration, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$AudioPlaybackSnapshotCopyWith<$Res> implements $AudioPlaybackSnapshotCopyWith<$Res> {
  factory _$AudioPlaybackSnapshotCopyWith(_AudioPlaybackSnapshot value, $Res Function(_AudioPlaybackSnapshot) _then) = __$AudioPlaybackSnapshotCopyWithImpl;
@override @useResult
$Res call({
 bool isPlaying, bool isBuffering, bool isCompleted, Duration position, Duration? duration, ParseFailure<Never>? failure
});




}
/// @nodoc
class __$AudioPlaybackSnapshotCopyWithImpl<$Res>
    implements _$AudioPlaybackSnapshotCopyWith<$Res> {
  __$AudioPlaybackSnapshotCopyWithImpl(this._self, this._then);

  final _AudioPlaybackSnapshot _self;
  final $Res Function(_AudioPlaybackSnapshot) _then;

/// Create a copy of AudioPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isPlaying = null,Object? isBuffering = null,Object? isCompleted = null,Object? position = null,Object? duration = freezed,Object? failure = freezed,}) {
  return _then(_AudioPlaybackSnapshot(
isPlaying: null == isPlaying ? _self.isPlaying : isPlaying // ignore: cast_nullable_to_non_nullable
as bool,isBuffering: null == isBuffering ? _self.isBuffering : isBuffering // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailure<Never>?,
  ));
}


}

// dart format on
