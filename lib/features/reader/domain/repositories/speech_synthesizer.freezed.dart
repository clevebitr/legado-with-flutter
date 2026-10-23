// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'speech_synthesizer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SpeechVoice {

/// The display name the system reports.
 String get name;/// The voice's locale tag, or an empty string when the platform omits it.
 String get locale;
/// Create a copy of SpeechVoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeechVoiceCopyWith<SpeechVoice> get copyWith => _$SpeechVoiceCopyWithImpl<SpeechVoice>(this as SpeechVoice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SpeechVoice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeechVoice&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.locale, _this.locale) || other.locale == _this.locale));
}


@override
int get hashCode {
  final _this = this as SpeechVoice;
  return Object.hash(runtimeType,_this.name,_this.locale);
}

@override
String toString() {
  final _this = this as SpeechVoice;
  return 'SpeechVoice(name: ${_this.name}, locale: ${_this.locale})';
}


}

/// @nodoc
abstract mixin class $SpeechVoiceCopyWith<$Res>  {
  factory $SpeechVoiceCopyWith(SpeechVoice value, $Res Function(SpeechVoice) _then) = _$SpeechVoiceCopyWithImpl;
@useResult
$Res call({
 String name, String locale
});




}
/// @nodoc
class _$SpeechVoiceCopyWithImpl<$Res>
    implements $SpeechVoiceCopyWith<$Res> {
  _$SpeechVoiceCopyWithImpl(this._self, this._then);

  final SpeechVoice _self;
  final $Res Function(SpeechVoice) _then;

/// Create a copy of SpeechVoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? locale = null,}) {
  return _then(SpeechVoice(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeechVoice].
extension SpeechVoicePatterns on SpeechVoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeechVoice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeechVoice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeechVoice value)  $default,){
final _that = this;
switch (_that) {
case _SpeechVoice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeechVoice value)?  $default,){
final _that = this;
switch (_that) {
case _SpeechVoice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String locale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeechVoice() when $default != null:
return $default(_that.name,_that.locale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String locale)  $default,) {final _that = this;
switch (_that) {
case _SpeechVoice():
return $default(_that.name,_that.locale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String locale)?  $default,) {final _that = this;
switch (_that) {
case _SpeechVoice() when $default != null:
return $default(_that.name,_that.locale);case _:
  return null;

}
}

}

/// @nodoc


class _SpeechVoice implements SpeechVoice {
  const _SpeechVoice({required this.name, this.locale = ''});
  

/// The display name the system reports.
@override final  String name;
/// The voice's locale tag, or an empty string when the platform omits it.
@override@JsonKey() final  String locale;

/// Create a copy of SpeechVoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeechVoiceCopyWith<_SpeechVoice> get copyWith => __$SpeechVoiceCopyWithImpl<_SpeechVoice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeechVoice&&(identical(other.name, name) || other.name == name)&&(identical(other.locale, locale) || other.locale == locale));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,locale);
}

@override
String toString() {
    return 'SpeechVoice(name: $name, locale: $locale)';
}


}

/// @nodoc
abstract mixin class _$SpeechVoiceCopyWith<$Res> implements $SpeechVoiceCopyWith<$Res> {
  factory _$SpeechVoiceCopyWith(_SpeechVoice value, $Res Function(_SpeechVoice) _then) = __$SpeechVoiceCopyWithImpl;
@override @useResult
$Res call({
 String name, String locale
});




}
/// @nodoc
class __$SpeechVoiceCopyWithImpl<$Res>
    implements _$SpeechVoiceCopyWith<$Res> {
  __$SpeechVoiceCopyWithImpl(this._self, this._then);

  final _SpeechVoice _self;
  final $Res Function(_SpeechVoice) _then;

/// Create a copy of SpeechVoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? locale = null,}) {
  return _then(_SpeechVoice(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$SpeechRange {

/// The offset of the first character being voiced.
 int get start;/// The offset just past the last character being voiced.
 int get end;
/// Create a copy of SpeechRange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeechRangeCopyWith<SpeechRange> get copyWith => _$SpeechRangeCopyWithImpl<SpeechRange>(this as SpeechRange, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SpeechRange;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeechRange&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end));
}


@override
int get hashCode {
  final _this = this as SpeechRange;
  return Object.hash(runtimeType,_this.start,_this.end);
}

@override
String toString() {
  final _this = this as SpeechRange;
  return 'SpeechRange(start: ${_this.start}, end: ${_this.end})';
}


}

/// @nodoc
abstract mixin class $SpeechRangeCopyWith<$Res>  {
  factory $SpeechRangeCopyWith(SpeechRange value, $Res Function(SpeechRange) _then) = _$SpeechRangeCopyWithImpl;
@useResult
$Res call({
 int start, int end
});




}
/// @nodoc
class _$SpeechRangeCopyWithImpl<$Res>
    implements $SpeechRangeCopyWith<$Res> {
  _$SpeechRangeCopyWithImpl(this._self, this._then);

  final SpeechRange _self;
  final $Res Function(SpeechRange) _then;

/// Create a copy of SpeechRange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = null,Object? end = null,}) {
  return _then(SpeechRange(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeechRange].
extension SpeechRangePatterns on SpeechRange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeechRange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeechRange() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeechRange value)  $default,){
final _that = this;
switch (_that) {
case _SpeechRange():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeechRange value)?  $default,){
final _that = this;
switch (_that) {
case _SpeechRange() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int start,  int end)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeechRange() when $default != null:
return $default(_that.start,_that.end);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int start,  int end)  $default,) {final _that = this;
switch (_that) {
case _SpeechRange():
return $default(_that.start,_that.end);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int start,  int end)?  $default,) {final _that = this;
switch (_that) {
case _SpeechRange() when $default != null:
return $default(_that.start,_that.end);case _:
  return null;

}
}

}

/// @nodoc


class _SpeechRange implements SpeechRange {
  const _SpeechRange({required this.start, required this.end});
  

/// The offset of the first character being voiced.
@override final  int start;
/// The offset just past the last character being voiced.
@override final  int end;

/// Create a copy of SpeechRange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeechRangeCopyWith<_SpeechRange> get copyWith => __$SpeechRangeCopyWithImpl<_SpeechRange>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeechRange&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}


@override
int get hashCode {
    return Object.hash(runtimeType,start,end);
}

@override
String toString() {
    return 'SpeechRange(start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class _$SpeechRangeCopyWith<$Res> implements $SpeechRangeCopyWith<$Res> {
  factory _$SpeechRangeCopyWith(_SpeechRange value, $Res Function(_SpeechRange) _then) = __$SpeechRangeCopyWithImpl;
@override @useResult
$Res call({
 int start, int end
});




}
/// @nodoc
class __$SpeechRangeCopyWithImpl<$Res>
    implements _$SpeechRangeCopyWith<$Res> {
  __$SpeechRangeCopyWithImpl(this._self, this._then);

  final _SpeechRange _self;
  final $Res Function(_SpeechRange) _then;

/// Create a copy of SpeechRange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = null,Object? end = null,}) {
  return _then(_SpeechRange(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$SpeechSnapshot {

/// Whether the engine is speaking (or paused, which the platform still reports as active).
 bool get isSpeaking;/// Whether the engine is paused.
 bool get isPaused;/// Whether the current utterance finished.
 bool get isCompleted;/// The range of the current utterance the engine is voicing right now, or `null`.
///
/// Android and iOS report it; a platform without progress support leaves it `null`, and the
/// highlight then covers the whole utterance (ADR-0057 §决策 5).
 SpeechRange? get spokenRange;/// An engine error to show instead of the normal controls.
 ParseFailure<Never>? get failure;
/// Create a copy of SpeechSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeechSnapshotCopyWith<SpeechSnapshot> get copyWith => _$SpeechSnapshotCopyWithImpl<SpeechSnapshot>(this as SpeechSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SpeechSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeechSnapshot&&(identical(other.isSpeaking, _this.isSpeaking) || other.isSpeaking == _this.isSpeaking)&&(identical(other.isPaused, _this.isPaused) || other.isPaused == _this.isPaused)&&(identical(other.isCompleted, _this.isCompleted) || other.isCompleted == _this.isCompleted)&&(identical(other.spokenRange, _this.spokenRange) || other.spokenRange == _this.spokenRange)&&const DeepCollectionEquality().equals(other.failure, _this.failure));
}


@override
int get hashCode {
  final _this = this as SpeechSnapshot;
  return Object.hash(runtimeType,_this.isSpeaking,_this.isPaused,_this.isCompleted,_this.spokenRange,const DeepCollectionEquality().hash(_this.failure));
}

@override
String toString() {
  final _this = this as SpeechSnapshot;
  return 'SpeechSnapshot(isSpeaking: ${_this.isSpeaking}, isPaused: ${_this.isPaused}, isCompleted: ${_this.isCompleted}, spokenRange: ${_this.spokenRange}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $SpeechSnapshotCopyWith<$Res>  {
  factory $SpeechSnapshotCopyWith(SpeechSnapshot value, $Res Function(SpeechSnapshot) _then) = _$SpeechSnapshotCopyWithImpl;
@useResult
$Res call({
 bool isSpeaking, bool isPaused, bool isCompleted, SpeechRange? spokenRange, ParseFailure<Never>? failure
});


$SpeechRangeCopyWith<$Res>? get spokenRange;

}
/// @nodoc
class _$SpeechSnapshotCopyWithImpl<$Res>
    implements $SpeechSnapshotCopyWith<$Res> {
  _$SpeechSnapshotCopyWithImpl(this._self, this._then);

  final SpeechSnapshot _self;
  final $Res Function(SpeechSnapshot) _then;

/// Create a copy of SpeechSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isSpeaking = null,Object? isPaused = null,Object? isCompleted = null,Object? spokenRange = freezed,Object? failure = freezed,}) {
  return _then(SpeechSnapshot(
isSpeaking: null == isSpeaking ? _self.isSpeaking : isSpeaking // ignore: cast_nullable_to_non_nullable
as bool,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,spokenRange: freezed == spokenRange ? _self.spokenRange : spokenRange // ignore: cast_nullable_to_non_nullable
as SpeechRange?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailure<Never>?,
  ));
}
/// Create a copy of SpeechSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeechRangeCopyWith<$Res>? get spokenRange {
    if (_self.spokenRange == null) {
    return null;
  }

  return $SpeechRangeCopyWith<$Res>(_self.spokenRange!, (value) {
    return _then(_self.copyWith(spokenRange: value));
  });
}
}


/// Adds pattern-matching-related methods to [SpeechSnapshot].
extension SpeechSnapshotPatterns on SpeechSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeechSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeechSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeechSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _SpeechSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeechSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _SpeechSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isSpeaking,  bool isPaused,  bool isCompleted,  SpeechRange? spokenRange,  ParseFailure<Never>? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeechSnapshot() when $default != null:
return $default(_that.isSpeaking,_that.isPaused,_that.isCompleted,_that.spokenRange,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isSpeaking,  bool isPaused,  bool isCompleted,  SpeechRange? spokenRange,  ParseFailure<Never>? failure)  $default,) {final _that = this;
switch (_that) {
case _SpeechSnapshot():
return $default(_that.isSpeaking,_that.isPaused,_that.isCompleted,_that.spokenRange,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isSpeaking,  bool isPaused,  bool isCompleted,  SpeechRange? spokenRange,  ParseFailure<Never>? failure)?  $default,) {final _that = this;
switch (_that) {
case _SpeechSnapshot() when $default != null:
return $default(_that.isSpeaking,_that.isPaused,_that.isCompleted,_that.spokenRange,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _SpeechSnapshot implements SpeechSnapshot {
  const _SpeechSnapshot({this.isSpeaking = false, this.isPaused = false, this.isCompleted = false, this.spokenRange, this.failure});
  

/// Whether the engine is speaking (or paused, which the platform still reports as active).
@override@JsonKey() final  bool isSpeaking;
/// Whether the engine is paused.
@override@JsonKey() final  bool isPaused;
/// Whether the current utterance finished.
@override@JsonKey() final  bool isCompleted;
/// The range of the current utterance the engine is voicing right now, or `null`.
///
/// Android and iOS report it; a platform without progress support leaves it `null`, and the
/// highlight then covers the whole utterance (ADR-0057 §决策 5).
@override final  SpeechRange? spokenRange;
/// An engine error to show instead of the normal controls.
@override final  ParseFailure<Never>? failure;

/// Create a copy of SpeechSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeechSnapshotCopyWith<_SpeechSnapshot> get copyWith => __$SpeechSnapshotCopyWithImpl<_SpeechSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeechSnapshot&&(identical(other.isSpeaking, isSpeaking) || other.isSpeaking == isSpeaking)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.spokenRange, spokenRange) || other.spokenRange == spokenRange)&&const DeepCollectionEquality().equals(other.failure, failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,isSpeaking,isPaused,isCompleted,spokenRange,const DeepCollectionEquality().hash(failure));
}

@override
String toString() {
    return 'SpeechSnapshot(isSpeaking: $isSpeaking, isPaused: $isPaused, isCompleted: $isCompleted, spokenRange: $spokenRange, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$SpeechSnapshotCopyWith<$Res> implements $SpeechSnapshotCopyWith<$Res> {
  factory _$SpeechSnapshotCopyWith(_SpeechSnapshot value, $Res Function(_SpeechSnapshot) _then) = __$SpeechSnapshotCopyWithImpl;
@override @useResult
$Res call({
 bool isSpeaking, bool isPaused, bool isCompleted, SpeechRange? spokenRange, ParseFailure<Never>? failure
});


@override $SpeechRangeCopyWith<$Res>? get spokenRange;

}
/// @nodoc
class __$SpeechSnapshotCopyWithImpl<$Res>
    implements _$SpeechSnapshotCopyWith<$Res> {
  __$SpeechSnapshotCopyWithImpl(this._self, this._then);

  final _SpeechSnapshot _self;
  final $Res Function(_SpeechSnapshot) _then;

/// Create a copy of SpeechSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isSpeaking = null,Object? isPaused = null,Object? isCompleted = null,Object? spokenRange = freezed,Object? failure = freezed,}) {
  return _then(_SpeechSnapshot(
isSpeaking: null == isSpeaking ? _self.isSpeaking : isSpeaking // ignore: cast_nullable_to_non_nullable
as bool,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,spokenRange: freezed == spokenRange ? _self.spokenRange : spokenRange // ignore: cast_nullable_to_non_nullable
as SpeechRange?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailure<Never>?,
  ));
}

/// Create a copy of SpeechSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeechRangeCopyWith<$Res>? get spokenRange {
    if (_self.spokenRange == null) {
    return null;
  }

  return $SpeechRangeCopyWith<$Res>(_self.spokenRange!, (value) {
    return _then(_self.copyWith(spokenRange: value));
  });
}
}

// dart format on
