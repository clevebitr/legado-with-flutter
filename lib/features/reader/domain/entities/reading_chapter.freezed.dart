// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_chapter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingChapter {

/// The title as the source spelled it; may be empty when the rule matched nothing.
 String get title;/// The absolute chapter URL.
 String get url;
/// Create a copy of ReadingChapter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingChapterCopyWith<ReadingChapter> get copyWith => _$ReadingChapterCopyWithImpl<ReadingChapter>(this as ReadingChapter, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingChapter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingChapter&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url));
}


@override
int get hashCode {
  final _this = this as ReadingChapter;
  return Object.hash(runtimeType,_this.title,_this.url);
}

@override
String toString() {
  final _this = this as ReadingChapter;
  return 'ReadingChapter(title: ${_this.title}, url: ${_this.url})';
}


}

/// @nodoc
abstract mixin class $ReadingChapterCopyWith<$Res>  {
  factory $ReadingChapterCopyWith(ReadingChapter value, $Res Function(ReadingChapter) _then) = _$ReadingChapterCopyWithImpl;
@useResult
$Res call({
 String title, String url
});




}
/// @nodoc
class _$ReadingChapterCopyWithImpl<$Res>
    implements $ReadingChapterCopyWith<$Res> {
  _$ReadingChapterCopyWithImpl(this._self, this._then);

  final ReadingChapter _self;
  final $Res Function(ReadingChapter) _then;

/// Create a copy of ReadingChapter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? url = null,}) {
  return _then(ReadingChapter(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingChapter].
extension ReadingChapterPatterns on ReadingChapter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingChapter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingChapter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingChapter value)  $default,){
final _that = this;
switch (_that) {
case _ReadingChapter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingChapter value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingChapter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingChapter() when $default != null:
return $default(_that.title,_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String url)  $default,) {final _that = this;
switch (_that) {
case _ReadingChapter():
return $default(_that.title,_that.url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String url)?  $default,) {final _that = this;
switch (_that) {
case _ReadingChapter() when $default != null:
return $default(_that.title,_that.url);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingChapter implements ReadingChapter {
  const _ReadingChapter({required this.title, required this.url});
  

/// The title as the source spelled it; may be empty when the rule matched nothing.
@override final  String title;
/// The absolute chapter URL.
@override final  String url;

/// Create a copy of ReadingChapter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingChapterCopyWith<_ReadingChapter> get copyWith => __$ReadingChapterCopyWithImpl<_ReadingChapter>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingChapter&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,url);
}

@override
String toString() {
    return 'ReadingChapter(title: $title, url: $url)';
}


}

/// @nodoc
abstract mixin class _$ReadingChapterCopyWith<$Res> implements $ReadingChapterCopyWith<$Res> {
  factory _$ReadingChapterCopyWith(_ReadingChapter value, $Res Function(_ReadingChapter) _then) = __$ReadingChapterCopyWithImpl;
@override @useResult
$Res call({
 String title, String url
});




}
/// @nodoc
class __$ReadingChapterCopyWithImpl<$Res>
    implements _$ReadingChapterCopyWith<$Res> {
  __$ReadingChapterCopyWithImpl(this._self, this._then);

  final _ReadingChapter _self;
  final $Res Function(_ReadingChapter) _then;

/// Create a copy of ReadingChapter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? url = null,}) {
  return _then(_ReadingChapter(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
