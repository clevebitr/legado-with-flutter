// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_tts_highlight.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReaderTtsHighlight {

/// The chapter the range belongs to.
 String get chapterUrl;/// The offset of the first highlighted character in the rendered chapter body.
 int get start;/// The offset just past the last highlighted character.
 int get end;
/// Create a copy of ReaderTtsHighlight
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderTtsHighlightCopyWith<ReaderTtsHighlight> get copyWith => _$ReaderTtsHighlightCopyWithImpl<ReaderTtsHighlight>(this as ReaderTtsHighlight, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReaderTtsHighlight;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderTtsHighlight&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end));
}


@override
int get hashCode {
  final _this = this as ReaderTtsHighlight;
  return Object.hash(runtimeType,_this.chapterUrl,_this.start,_this.end);
}

@override
String toString() {
  final _this = this as ReaderTtsHighlight;
  return 'ReaderTtsHighlight(chapterUrl: ${_this.chapterUrl}, start: ${_this.start}, end: ${_this.end})';
}


}

/// @nodoc
abstract mixin class $ReaderTtsHighlightCopyWith<$Res>  {
  factory $ReaderTtsHighlightCopyWith(ReaderTtsHighlight value, $Res Function(ReaderTtsHighlight) _then) = _$ReaderTtsHighlightCopyWithImpl;
@useResult
$Res call({
 String chapterUrl, int start, int end
});




}
/// @nodoc
class _$ReaderTtsHighlightCopyWithImpl<$Res>
    implements $ReaderTtsHighlightCopyWith<$Res> {
  _$ReaderTtsHighlightCopyWithImpl(this._self, this._then);

  final ReaderTtsHighlight _self;
  final $Res Function(ReaderTtsHighlight) _then;

/// Create a copy of ReaderTtsHighlight
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapterUrl = null,Object? start = null,Object? end = null,}) {
  return _then(ReaderTtsHighlight(
chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderTtsHighlight].
extension ReaderTtsHighlightPatterns on ReaderTtsHighlight {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderTtsHighlight value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderTtsHighlight() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderTtsHighlight value)  $default,){
final _that = this;
switch (_that) {
case _ReaderTtsHighlight():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderTtsHighlight value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderTtsHighlight() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chapterUrl,  int start,  int end)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderTtsHighlight() when $default != null:
return $default(_that.chapterUrl,_that.start,_that.end);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chapterUrl,  int start,  int end)  $default,) {final _that = this;
switch (_that) {
case _ReaderTtsHighlight():
return $default(_that.chapterUrl,_that.start,_that.end);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chapterUrl,  int start,  int end)?  $default,) {final _that = this;
switch (_that) {
case _ReaderTtsHighlight() when $default != null:
return $default(_that.chapterUrl,_that.start,_that.end);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderTtsHighlight implements ReaderTtsHighlight {
  const _ReaderTtsHighlight({required this.chapterUrl, required this.start, required this.end});
  

/// The chapter the range belongs to.
@override final  String chapterUrl;
/// The offset of the first highlighted character in the rendered chapter body.
@override final  int start;
/// The offset just past the last highlighted character.
@override final  int end;

/// Create a copy of ReaderTtsHighlight
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderTtsHighlightCopyWith<_ReaderTtsHighlight> get copyWith => __$ReaderTtsHighlightCopyWithImpl<_ReaderTtsHighlight>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderTtsHighlight&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}


@override
int get hashCode {
    return Object.hash(runtimeType,chapterUrl,start,end);
}

@override
String toString() {
    return 'ReaderTtsHighlight(chapterUrl: $chapterUrl, start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class _$ReaderTtsHighlightCopyWith<$Res> implements $ReaderTtsHighlightCopyWith<$Res> {
  factory _$ReaderTtsHighlightCopyWith(_ReaderTtsHighlight value, $Res Function(_ReaderTtsHighlight) _then) = __$ReaderTtsHighlightCopyWithImpl;
@override @useResult
$Res call({
 String chapterUrl, int start, int end
});




}
/// @nodoc
class __$ReaderTtsHighlightCopyWithImpl<$Res>
    implements _$ReaderTtsHighlightCopyWith<$Res> {
  __$ReaderTtsHighlightCopyWithImpl(this._self, this._then);

  final _ReaderTtsHighlight _self;
  final $Res Function(_ReaderTtsHighlight) _then;

/// Create a copy of ReaderTtsHighlight
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chapterUrl = null,Object? start = null,Object? end = null,}) {
  return _then(_ReaderTtsHighlight(
chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
