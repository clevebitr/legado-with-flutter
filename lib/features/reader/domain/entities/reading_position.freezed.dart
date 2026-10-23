// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_position.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingPosition {

/// The chapter the reader was on.
 String get chapterUrl;/// Its title, kept so a list can show «reading: chapter» without fetching anything.
 String? get chapterName;/// The estimated character offset inside that chapter's body.
 int get charOffset;
/// Create a copy of ReadingPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingPositionCopyWith<ReadingPosition> get copyWith => _$ReadingPositionCopyWithImpl<ReadingPosition>(this as ReadingPosition, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingPosition;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingPosition&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.chapterName, _this.chapterName) || other.chapterName == _this.chapterName)&&(identical(other.charOffset, _this.charOffset) || other.charOffset == _this.charOffset));
}


@override
int get hashCode {
  final _this = this as ReadingPosition;
  return Object.hash(runtimeType,_this.chapterUrl,_this.chapterName,_this.charOffset);
}

@override
String toString() {
  final _this = this as ReadingPosition;
  return 'ReadingPosition(chapterUrl: ${_this.chapterUrl}, chapterName: ${_this.chapterName}, charOffset: ${_this.charOffset})';
}


}

/// @nodoc
abstract mixin class $ReadingPositionCopyWith<$Res>  {
  factory $ReadingPositionCopyWith(ReadingPosition value, $Res Function(ReadingPosition) _then) = _$ReadingPositionCopyWithImpl;
@useResult
$Res call({
 String chapterUrl, String? chapterName, int charOffset
});




}
/// @nodoc
class _$ReadingPositionCopyWithImpl<$Res>
    implements $ReadingPositionCopyWith<$Res> {
  _$ReadingPositionCopyWithImpl(this._self, this._then);

  final ReadingPosition _self;
  final $Res Function(ReadingPosition) _then;

/// Create a copy of ReadingPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapterUrl = null,Object? chapterName = freezed,Object? charOffset = null,}) {
  return _then(ReadingPosition(
chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingPosition].
extension ReadingPositionPatterns on ReadingPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingPosition value)  $default,){
final _that = this;
switch (_that) {
case _ReadingPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingPosition value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chapterUrl,  String? chapterName,  int charOffset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingPosition() when $default != null:
return $default(_that.chapterUrl,_that.chapterName,_that.charOffset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chapterUrl,  String? chapterName,  int charOffset)  $default,) {final _that = this;
switch (_that) {
case _ReadingPosition():
return $default(_that.chapterUrl,_that.chapterName,_that.charOffset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chapterUrl,  String? chapterName,  int charOffset)?  $default,) {final _that = this;
switch (_that) {
case _ReadingPosition() when $default != null:
return $default(_that.chapterUrl,_that.chapterName,_that.charOffset);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingPosition implements ReadingPosition {
  const _ReadingPosition({required this.chapterUrl, this.chapterName, this.charOffset = 0});
  

/// The chapter the reader was on.
@override final  String chapterUrl;
/// Its title, kept so a list can show «reading: chapter» without fetching anything.
@override final  String? chapterName;
/// The estimated character offset inside that chapter's body.
@override@JsonKey() final  int charOffset;

/// Create a copy of ReadingPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingPositionCopyWith<_ReadingPosition> get copyWith => __$ReadingPositionCopyWithImpl<_ReadingPosition>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingPosition&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.chapterName, chapterName) || other.chapterName == chapterName)&&(identical(other.charOffset, charOffset) || other.charOffset == charOffset));
}


@override
int get hashCode {
    return Object.hash(runtimeType,chapterUrl,chapterName,charOffset);
}

@override
String toString() {
    return 'ReadingPosition(chapterUrl: $chapterUrl, chapterName: $chapterName, charOffset: $charOffset)';
}


}

/// @nodoc
abstract mixin class _$ReadingPositionCopyWith<$Res> implements $ReadingPositionCopyWith<$Res> {
  factory _$ReadingPositionCopyWith(_ReadingPosition value, $Res Function(_ReadingPosition) _then) = __$ReadingPositionCopyWithImpl;
@override @useResult
$Res call({
 String chapterUrl, String? chapterName, int charOffset
});




}
/// @nodoc
class __$ReadingPositionCopyWithImpl<$Res>
    implements _$ReadingPositionCopyWith<$Res> {
  __$ReadingPositionCopyWithImpl(this._self, this._then);

  final _ReadingPosition _self;
  final $Res Function(_ReadingPosition) _then;

/// Create a copy of ReadingPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chapterUrl = null,Object? chapterName = freezed,Object? charOffset = null,}) {
  return _then(_ReadingPosition(
chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
