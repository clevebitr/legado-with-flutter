// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_reader_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioReaderState {

/// The current chapter's tracks, in rule order.
 List<ReaderAudioTrack> get tracks;/// Index into [tracks].
 int get trackIndex;/// Whether audio is advancing right now.
 bool get isPlaying;/// Whether a track is being fetched or prepared.
 bool get isLoading;/// Whether the player reported buffering.
 bool get isBuffering;/// Whether the current track finished.
 bool get isCompleted;/// Position inside the current track.
 Duration get position;/// Duration of the current track, or `null` before the player decodes it.
 Duration? get duration;/// Playback speed (1.0 = normal).
 double get speed;/// A failure to show instead of the controls' normal labels.
 ParseFailure<Never>? get failure;
/// Create a copy of AudioReaderState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioReaderStateCopyWith<AudioReaderState> get copyWith => _$AudioReaderStateCopyWithImpl<AudioReaderState>(this as AudioReaderState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AudioReaderState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioReaderState&&const DeepCollectionEquality().equals(other.tracks, _this.tracks)&&(identical(other.trackIndex, _this.trackIndex) || other.trackIndex == _this.trackIndex)&&(identical(other.isPlaying, _this.isPlaying) || other.isPlaying == _this.isPlaying)&&(identical(other.isLoading, _this.isLoading) || other.isLoading == _this.isLoading)&&(identical(other.isBuffering, _this.isBuffering) || other.isBuffering == _this.isBuffering)&&(identical(other.isCompleted, _this.isCompleted) || other.isCompleted == _this.isCompleted)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.speed, _this.speed) || other.speed == _this.speed)&&const DeepCollectionEquality().equals(other.failure, _this.failure));
}


@override
int get hashCode {
  final _this = this as AudioReaderState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.tracks),_this.trackIndex,_this.isPlaying,_this.isLoading,_this.isBuffering,_this.isCompleted,_this.position,_this.duration,_this.speed,const DeepCollectionEquality().hash(_this.failure));
}

@override
String toString() {
  final _this = this as AudioReaderState;
  return 'AudioReaderState(tracks: ${_this.tracks}, trackIndex: ${_this.trackIndex}, isPlaying: ${_this.isPlaying}, isLoading: ${_this.isLoading}, isBuffering: ${_this.isBuffering}, isCompleted: ${_this.isCompleted}, position: ${_this.position}, duration: ${_this.duration}, speed: ${_this.speed}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $AudioReaderStateCopyWith<$Res>  {
  factory $AudioReaderStateCopyWith(AudioReaderState value, $Res Function(AudioReaderState) _then) = _$AudioReaderStateCopyWithImpl;
@useResult
$Res call({
 List<ReaderAudioTrack> tracks, int trackIndex, bool isPlaying, bool isLoading, bool isBuffering, bool isCompleted, Duration position, Duration? duration, double speed, ParseFailure<Never>? failure
});




}
/// @nodoc
class _$AudioReaderStateCopyWithImpl<$Res>
    implements $AudioReaderStateCopyWith<$Res> {
  _$AudioReaderStateCopyWithImpl(this._self, this._then);

  final AudioReaderState _self;
  final $Res Function(AudioReaderState) _then;

/// Create a copy of AudioReaderState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tracks = null,Object? trackIndex = null,Object? isPlaying = null,Object? isLoading = null,Object? isBuffering = null,Object? isCompleted = null,Object? position = null,Object? duration = freezed,Object? speed = null,Object? failure = freezed,}) {
  return _then(AudioReaderState(
tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<ReaderAudioTrack>,trackIndex: null == trackIndex ? _self.trackIndex : trackIndex // ignore: cast_nullable_to_non_nullable
as int,isPlaying: null == isPlaying ? _self.isPlaying : isPlaying // ignore: cast_nullable_to_non_nullable
as bool,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isBuffering: null == isBuffering ? _self.isBuffering : isBuffering // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailure<Never>?,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioReaderState].
extension AudioReaderStatePatterns on AudioReaderState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioReaderState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioReaderState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioReaderState value)  $default,){
final _that = this;
switch (_that) {
case _AudioReaderState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioReaderState value)?  $default,){
final _that = this;
switch (_that) {
case _AudioReaderState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ReaderAudioTrack> tracks,  int trackIndex,  bool isPlaying,  bool isLoading,  bool isBuffering,  bool isCompleted,  Duration position,  Duration? duration,  double speed,  ParseFailure<Never>? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioReaderState() when $default != null:
return $default(_that.tracks,_that.trackIndex,_that.isPlaying,_that.isLoading,_that.isBuffering,_that.isCompleted,_that.position,_that.duration,_that.speed,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ReaderAudioTrack> tracks,  int trackIndex,  bool isPlaying,  bool isLoading,  bool isBuffering,  bool isCompleted,  Duration position,  Duration? duration,  double speed,  ParseFailure<Never>? failure)  $default,) {final _that = this;
switch (_that) {
case _AudioReaderState():
return $default(_that.tracks,_that.trackIndex,_that.isPlaying,_that.isLoading,_that.isBuffering,_that.isCompleted,_that.position,_that.duration,_that.speed,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ReaderAudioTrack> tracks,  int trackIndex,  bool isPlaying,  bool isLoading,  bool isBuffering,  bool isCompleted,  Duration position,  Duration? duration,  double speed,  ParseFailure<Never>? failure)?  $default,) {final _that = this;
switch (_that) {
case _AudioReaderState() when $default != null:
return $default(_that.tracks,_that.trackIndex,_that.isPlaying,_that.isLoading,_that.isBuffering,_that.isCompleted,_that.position,_that.duration,_that.speed,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _AudioReaderState extends AudioReaderState {
  const _AudioReaderState({ List<ReaderAudioTrack> tracks = const <ReaderAudioTrack>[], this.trackIndex = 0, this.isPlaying = false, this.isLoading = false, this.isBuffering = false, this.isCompleted = false, this.position = Duration.zero, this.duration, this.speed = 1.0, this.failure}): _tracks = tracks,super._();
  

/// The current chapter's tracks, in rule order.
 final  List<ReaderAudioTrack> _tracks;
/// The current chapter's tracks, in rule order.
@override@JsonKey() List<ReaderAudioTrack> get tracks {
  if (_tracks is EqualUnmodifiableListView) return _tracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tracks);
}

/// Index into [tracks].
@override@JsonKey() final  int trackIndex;
/// Whether audio is advancing right now.
@override@JsonKey() final  bool isPlaying;
/// Whether a track is being fetched or prepared.
@override@JsonKey() final  bool isLoading;
/// Whether the player reported buffering.
@override@JsonKey() final  bool isBuffering;
/// Whether the current track finished.
@override@JsonKey() final  bool isCompleted;
/// Position inside the current track.
@override@JsonKey() final  Duration position;
/// Duration of the current track, or `null` before the player decodes it.
@override final  Duration? duration;
/// Playback speed (1.0 = normal).
@override@JsonKey() final  double speed;
/// A failure to show instead of the controls' normal labels.
@override final  ParseFailure<Never>? failure;

/// Create a copy of AudioReaderState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioReaderStateCopyWith<_AudioReaderState> get copyWith => __$AudioReaderStateCopyWithImpl<_AudioReaderState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioReaderState&&const DeepCollectionEquality().equals(other.tracks, _tracks)&&(identical(other.trackIndex, trackIndex) || other.trackIndex == trackIndex)&&(identical(other.isPlaying, isPlaying) || other.isPlaying == isPlaying)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isBuffering, isBuffering) || other.isBuffering == isBuffering)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.position, position) || other.position == position)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.speed, speed) || other.speed == speed)&&const DeepCollectionEquality().equals(other.failure, failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_tracks),trackIndex,isPlaying,isLoading,isBuffering,isCompleted,position,duration,speed,const DeepCollectionEquality().hash(failure));
}

@override
String toString() {
    return 'AudioReaderState(tracks: $tracks, trackIndex: $trackIndex, isPlaying: $isPlaying, isLoading: $isLoading, isBuffering: $isBuffering, isCompleted: $isCompleted, position: $position, duration: $duration, speed: $speed, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$AudioReaderStateCopyWith<$Res> implements $AudioReaderStateCopyWith<$Res> {
  factory _$AudioReaderStateCopyWith(_AudioReaderState value, $Res Function(_AudioReaderState) _then) = __$AudioReaderStateCopyWithImpl;
@override @useResult
$Res call({
 List<ReaderAudioTrack> tracks, int trackIndex, bool isPlaying, bool isLoading, bool isBuffering, bool isCompleted, Duration position, Duration? duration, double speed, ParseFailure<Never>? failure
});




}
/// @nodoc
class __$AudioReaderStateCopyWithImpl<$Res>
    implements _$AudioReaderStateCopyWith<$Res> {
  __$AudioReaderStateCopyWithImpl(this._self, this._then);

  final _AudioReaderState _self;
  final $Res Function(_AudioReaderState) _then;

/// Create a copy of AudioReaderState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tracks = null,Object? trackIndex = null,Object? isPlaying = null,Object? isLoading = null,Object? isBuffering = null,Object? isCompleted = null,Object? position = null,Object? duration = freezed,Object? speed = null,Object? failure = freezed,}) {
  return _then(_AudioReaderState(
tracks: null == tracks ? _self._tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<ReaderAudioTrack>,trackIndex: null == trackIndex ? _self.trackIndex : trackIndex // ignore: cast_nullable_to_non_nullable
as int,isPlaying: null == isPlaying ? _self.isPlaying : isPlaying // ignore: cast_nullable_to_non_nullable
as bool,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isBuffering: null == isBuffering ? _self.isBuffering : isBuffering // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailure<Never>?,
  ));
}


}

// dart format on
