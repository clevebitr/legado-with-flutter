// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_session_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReaderSessionState {

/// Index into the book's chapter list.
 int get chapterIndex;/// Estimated character offset inside the current chapter.
 int get charOffset;
/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderSessionStateCopyWith<ReaderSessionState> get copyWith => _$ReaderSessionStateCopyWithImpl<ReaderSessionState>(this as ReaderSessionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReaderSessionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderSessionState&&(identical(other.chapterIndex, _this.chapterIndex) || other.chapterIndex == _this.chapterIndex)&&(identical(other.charOffset, _this.charOffset) || other.charOffset == _this.charOffset));
}


@override
int get hashCode {
  final _this = this as ReaderSessionState;
  return Object.hash(runtimeType,_this.chapterIndex,_this.charOffset);
}

@override
String toString() {
  final _this = this as ReaderSessionState;
  return 'ReaderSessionState(chapterIndex: ${_this.chapterIndex}, charOffset: ${_this.charOffset})';
}


}

/// @nodoc
abstract mixin class $ReaderSessionStateCopyWith<$Res>  {
  factory $ReaderSessionStateCopyWith(ReaderSessionState value, $Res Function(ReaderSessionState) _then) = _$ReaderSessionStateCopyWithImpl;
@useResult
$Res call({
 int chapterIndex, int charOffset
});




}
/// @nodoc
class _$ReaderSessionStateCopyWithImpl<$Res>
    implements $ReaderSessionStateCopyWith<$Res> {
  _$ReaderSessionStateCopyWithImpl(this._self, this._then);

  final ReaderSessionState _self;
  final $Res Function(ReaderSessionState) _then;

/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapterIndex = null,Object? charOffset = null,}) {
  return _then(ReaderSessionState(
chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderSessionState].
extension ReaderSessionStatePatterns on ReaderSessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderSessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderSessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderSessionState value)  $default,){
final _that = this;
switch (_that) {
case _ReaderSessionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderSessionState value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderSessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int chapterIndex,  int charOffset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderSessionState() when $default != null:
return $default(_that.chapterIndex,_that.charOffset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int chapterIndex,  int charOffset)  $default,) {final _that = this;
switch (_that) {
case _ReaderSessionState():
return $default(_that.chapterIndex,_that.charOffset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int chapterIndex,  int charOffset)?  $default,) {final _that = this;
switch (_that) {
case _ReaderSessionState() when $default != null:
return $default(_that.chapterIndex,_that.charOffset);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderSessionState implements ReaderSessionState {
  const _ReaderSessionState({required this.chapterIndex, this.charOffset = 0});
  

/// Index into the book's chapter list.
@override final  int chapterIndex;
/// Estimated character offset inside the current chapter.
@override@JsonKey() final  int charOffset;

/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderSessionStateCopyWith<_ReaderSessionState> get copyWith => __$ReaderSessionStateCopyWithImpl<_ReaderSessionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderSessionState&&(identical(other.chapterIndex, chapterIndex) || other.chapterIndex == chapterIndex)&&(identical(other.charOffset, charOffset) || other.charOffset == charOffset));
}


@override
int get hashCode {
    return Object.hash(runtimeType,chapterIndex,charOffset);
}

@override
String toString() {
    return 'ReaderSessionState(chapterIndex: $chapterIndex, charOffset: $charOffset)';
}


}

/// @nodoc
abstract mixin class _$ReaderSessionStateCopyWith<$Res> implements $ReaderSessionStateCopyWith<$Res> {
  factory _$ReaderSessionStateCopyWith(_ReaderSessionState value, $Res Function(_ReaderSessionState) _then) = __$ReaderSessionStateCopyWithImpl;
@override @useResult
$Res call({
 int chapterIndex, int charOffset
});




}
/// @nodoc
class __$ReaderSessionStateCopyWithImpl<$Res>
    implements _$ReaderSessionStateCopyWith<$Res> {
  __$ReaderSessionStateCopyWithImpl(this._self, this._then);

  final _ReaderSessionState _self;
  final $Res Function(_ReaderSessionState) _then;

/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chapterIndex = null,Object? charOffset = null,}) {
  return _then(_ReaderSessionState(
chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
