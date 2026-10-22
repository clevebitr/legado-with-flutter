// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_tts_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReaderTtsState {

/// Whether the engine is speaking right now.
 bool get isSpeaking;/// Whether speech is paused and can be resumed.
 bool get isPaused;/// Whether the chapter text is being fetched or the first chunk is being prepared.
 bool get isPreparing;/// The system voices the sheet offers; empty when the platform lists none.
 List<SpeechVoice> get voices;/// Speech rate multiplier (1.0 = normal).
 double get rate;/// Speech pitch (1.0 = normal).
 double get pitch;/// The selected voice, or `null` for the platform default.
 SpeechVoice? get voice;/// Whether leaving the reader stops speech.
 bool get stopOnExit;/// A failure to explain in the sheet.
 ParseFailure<Never>? get failure;
/// Create a copy of ReaderTtsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderTtsStateCopyWith<ReaderTtsState> get copyWith => _$ReaderTtsStateCopyWithImpl<ReaderTtsState>(this as ReaderTtsState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReaderTtsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderTtsState&&(identical(other.isSpeaking, _this.isSpeaking) || other.isSpeaking == _this.isSpeaking)&&(identical(other.isPaused, _this.isPaused) || other.isPaused == _this.isPaused)&&(identical(other.isPreparing, _this.isPreparing) || other.isPreparing == _this.isPreparing)&&const DeepCollectionEquality().equals(other.voices, _this.voices)&&(identical(other.rate, _this.rate) || other.rate == _this.rate)&&(identical(other.pitch, _this.pitch) || other.pitch == _this.pitch)&&(identical(other.voice, _this.voice) || other.voice == _this.voice)&&(identical(other.stopOnExit, _this.stopOnExit) || other.stopOnExit == _this.stopOnExit)&&const DeepCollectionEquality().equals(other.failure, _this.failure));
}


@override
int get hashCode {
  final _this = this as ReaderTtsState;
  return Object.hash(runtimeType,_this.isSpeaking,_this.isPaused,_this.isPreparing,const DeepCollectionEquality().hash(_this.voices),_this.rate,_this.pitch,_this.voice,_this.stopOnExit,const DeepCollectionEquality().hash(_this.failure));
}

@override
String toString() {
  final _this = this as ReaderTtsState;
  return 'ReaderTtsState(isSpeaking: ${_this.isSpeaking}, isPaused: ${_this.isPaused}, isPreparing: ${_this.isPreparing}, voices: ${_this.voices}, rate: ${_this.rate}, pitch: ${_this.pitch}, voice: ${_this.voice}, stopOnExit: ${_this.stopOnExit}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $ReaderTtsStateCopyWith<$Res>  {
  factory $ReaderTtsStateCopyWith(ReaderTtsState value, $Res Function(ReaderTtsState) _then) = _$ReaderTtsStateCopyWithImpl;
@useResult
$Res call({
 bool isSpeaking, bool isPaused, bool isPreparing, List<SpeechVoice> voices, double rate, double pitch, SpeechVoice? voice, bool stopOnExit, ParseFailure<Never>? failure
});


$SpeechVoiceCopyWith<$Res>? get voice;

}
/// @nodoc
class _$ReaderTtsStateCopyWithImpl<$Res>
    implements $ReaderTtsStateCopyWith<$Res> {
  _$ReaderTtsStateCopyWithImpl(this._self, this._then);

  final ReaderTtsState _self;
  final $Res Function(ReaderTtsState) _then;

/// Create a copy of ReaderTtsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isSpeaking = null,Object? isPaused = null,Object? isPreparing = null,Object? voices = null,Object? rate = null,Object? pitch = null,Object? voice = freezed,Object? stopOnExit = null,Object? failure = freezed,}) {
  return _then(ReaderTtsState(
isSpeaking: null == isSpeaking ? _self.isSpeaking : isSpeaking // ignore: cast_nullable_to_non_nullable
as bool,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,isPreparing: null == isPreparing ? _self.isPreparing : isPreparing // ignore: cast_nullable_to_non_nullable
as bool,voices: null == voices ? _self.voices : voices // ignore: cast_nullable_to_non_nullable
as List<SpeechVoice>,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,voice: freezed == voice ? _self.voice : voice // ignore: cast_nullable_to_non_nullable
as SpeechVoice?,stopOnExit: null == stopOnExit ? _self.stopOnExit : stopOnExit // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailure<Never>?,
  ));
}
/// Create a copy of ReaderTtsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeechVoiceCopyWith<$Res>? get voice {
    if (_self.voice == null) {
    return null;
  }

  return $SpeechVoiceCopyWith<$Res>(_self.voice!, (value) {
    return _then(_self.copyWith(voice: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReaderTtsState].
extension ReaderTtsStatePatterns on ReaderTtsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderTtsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderTtsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderTtsState value)  $default,){
final _that = this;
switch (_that) {
case _ReaderTtsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderTtsState value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderTtsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isSpeaking,  bool isPaused,  bool isPreparing,  List<SpeechVoice> voices,  double rate,  double pitch,  SpeechVoice? voice,  bool stopOnExit,  ParseFailure<Never>? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderTtsState() when $default != null:
return $default(_that.isSpeaking,_that.isPaused,_that.isPreparing,_that.voices,_that.rate,_that.pitch,_that.voice,_that.stopOnExit,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isSpeaking,  bool isPaused,  bool isPreparing,  List<SpeechVoice> voices,  double rate,  double pitch,  SpeechVoice? voice,  bool stopOnExit,  ParseFailure<Never>? failure)  $default,) {final _that = this;
switch (_that) {
case _ReaderTtsState():
return $default(_that.isSpeaking,_that.isPaused,_that.isPreparing,_that.voices,_that.rate,_that.pitch,_that.voice,_that.stopOnExit,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isSpeaking,  bool isPaused,  bool isPreparing,  List<SpeechVoice> voices,  double rate,  double pitch,  SpeechVoice? voice,  bool stopOnExit,  ParseFailure<Never>? failure)?  $default,) {final _that = this;
switch (_that) {
case _ReaderTtsState() when $default != null:
return $default(_that.isSpeaking,_that.isPaused,_that.isPreparing,_that.voices,_that.rate,_that.pitch,_that.voice,_that.stopOnExit,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderTtsState extends ReaderTtsState {
  const _ReaderTtsState({this.isSpeaking = false, this.isPaused = false, this.isPreparing = false,  List<SpeechVoice> voices = const <SpeechVoice>[], this.rate = 1.0, this.pitch = 1.0, this.voice, this.stopOnExit = true, this.failure}): _voices = voices,super._();
  

/// Whether the engine is speaking right now.
@override@JsonKey() final  bool isSpeaking;
/// Whether speech is paused and can be resumed.
@override@JsonKey() final  bool isPaused;
/// Whether the chapter text is being fetched or the first chunk is being prepared.
@override@JsonKey() final  bool isPreparing;
/// The system voices the sheet offers; empty when the platform lists none.
 final  List<SpeechVoice> _voices;
/// The system voices the sheet offers; empty when the platform lists none.
@override@JsonKey() List<SpeechVoice> get voices {
  if (_voices is EqualUnmodifiableListView) return _voices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_voices);
}

/// Speech rate multiplier (1.0 = normal).
@override@JsonKey() final  double rate;
/// Speech pitch (1.0 = normal).
@override@JsonKey() final  double pitch;
/// The selected voice, or `null` for the platform default.
@override final  SpeechVoice? voice;
/// Whether leaving the reader stops speech.
@override@JsonKey() final  bool stopOnExit;
/// A failure to explain in the sheet.
@override final  ParseFailure<Never>? failure;

/// Create a copy of ReaderTtsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderTtsStateCopyWith<_ReaderTtsState> get copyWith => __$ReaderTtsStateCopyWithImpl<_ReaderTtsState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderTtsState&&(identical(other.isSpeaking, isSpeaking) || other.isSpeaking == isSpeaking)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.isPreparing, isPreparing) || other.isPreparing == isPreparing)&&const DeepCollectionEquality().equals(other.voices, _voices)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.voice, voice) || other.voice == voice)&&(identical(other.stopOnExit, stopOnExit) || other.stopOnExit == stopOnExit)&&const DeepCollectionEquality().equals(other.failure, failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,isSpeaking,isPaused,isPreparing,const DeepCollectionEquality().hash(_voices),rate,pitch,voice,stopOnExit,const DeepCollectionEquality().hash(failure));
}

@override
String toString() {
    return 'ReaderTtsState(isSpeaking: $isSpeaking, isPaused: $isPaused, isPreparing: $isPreparing, voices: $voices, rate: $rate, pitch: $pitch, voice: $voice, stopOnExit: $stopOnExit, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$ReaderTtsStateCopyWith<$Res> implements $ReaderTtsStateCopyWith<$Res> {
  factory _$ReaderTtsStateCopyWith(_ReaderTtsState value, $Res Function(_ReaderTtsState) _then) = __$ReaderTtsStateCopyWithImpl;
@override @useResult
$Res call({
 bool isSpeaking, bool isPaused, bool isPreparing, List<SpeechVoice> voices, double rate, double pitch, SpeechVoice? voice, bool stopOnExit, ParseFailure<Never>? failure
});


@override $SpeechVoiceCopyWith<$Res>? get voice;

}
/// @nodoc
class __$ReaderTtsStateCopyWithImpl<$Res>
    implements _$ReaderTtsStateCopyWith<$Res> {
  __$ReaderTtsStateCopyWithImpl(this._self, this._then);

  final _ReaderTtsState _self;
  final $Res Function(_ReaderTtsState) _then;

/// Create a copy of ReaderTtsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isSpeaking = null,Object? isPaused = null,Object? isPreparing = null,Object? voices = null,Object? rate = null,Object? pitch = null,Object? voice = freezed,Object? stopOnExit = null,Object? failure = freezed,}) {
  return _then(_ReaderTtsState(
isSpeaking: null == isSpeaking ? _self.isSpeaking : isSpeaking // ignore: cast_nullable_to_non_nullable
as bool,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,isPreparing: null == isPreparing ? _self.isPreparing : isPreparing // ignore: cast_nullable_to_non_nullable
as bool,voices: null == voices ? _self._voices : voices // ignore: cast_nullable_to_non_nullable
as List<SpeechVoice>,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,voice: freezed == voice ? _self.voice : voice // ignore: cast_nullable_to_non_nullable
as SpeechVoice?,stopOnExit: null == stopOnExit ? _self.stopOnExit : stopOnExit // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailure<Never>?,
  ));
}

/// Create a copy of ReaderTtsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeechVoiceCopyWith<$Res>? get voice {
    if (_self.voice == null) {
    return null;
  }

  return $SpeechVoiceCopyWith<$Res>(_self.voice!, (value) {
    return _then(_self.copyWith(voice: value));
  });
}
}

// dart format on
