// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chapter_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChapterRequest {

/// The chapter page URL — the same value that used to be the whole argument.
 String get url;/// The chapter title, when the caller knows it (`java.get('title')`).
 String get title;/// The book title, when the caller knows it (`java.get('bookName')`).
 String get bookName;
/// Create a copy of ChapterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChapterRequestCopyWith<ChapterRequest> get copyWith => _$ChapterRequestCopyWithImpl<ChapterRequest>(this as ChapterRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ChapterRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChapterRequest&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.bookName, _this.bookName) || other.bookName == _this.bookName));
}


@override
int get hashCode {
  final _this = this as ChapterRequest;
  return Object.hash(runtimeType,_this.url,_this.title,_this.bookName);
}

@override
String toString() {
  final _this = this as ChapterRequest;
  return 'ChapterRequest(url: ${_this.url}, title: ${_this.title}, bookName: ${_this.bookName})';
}


}

/// @nodoc
abstract mixin class $ChapterRequestCopyWith<$Res>  {
  factory $ChapterRequestCopyWith(ChapterRequest value, $Res Function(ChapterRequest) _then) = _$ChapterRequestCopyWithImpl;
@useResult
$Res call({
 String url, String title, String bookName
});




}
/// @nodoc
class _$ChapterRequestCopyWithImpl<$Res>
    implements $ChapterRequestCopyWith<$Res> {
  _$ChapterRequestCopyWithImpl(this._self, this._then);

  final ChapterRequest _self;
  final $Res Function(ChapterRequest) _then;

/// Create a copy of ChapterRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? title = null,Object? bookName = null,}) {
  return _then(ChapterRequest(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChapterRequest].
extension ChapterRequestPatterns on ChapterRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChapterRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChapterRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChapterRequest value)  $default,){
final _that = this;
switch (_that) {
case _ChapterRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChapterRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ChapterRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String title,  String bookName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChapterRequest() when $default != null:
return $default(_that.url,_that.title,_that.bookName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String title,  String bookName)  $default,) {final _that = this;
switch (_that) {
case _ChapterRequest():
return $default(_that.url,_that.title,_that.bookName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String title,  String bookName)?  $default,) {final _that = this;
switch (_that) {
case _ChapterRequest() when $default != null:
return $default(_that.url,_that.title,_that.bookName);case _:
  return null;

}
}

}

/// @nodoc


class _ChapterRequest implements ChapterRequest {
  const _ChapterRequest({required this.url, this.title = '', this.bookName = ''});
  

/// The chapter page URL — the same value that used to be the whole argument.
@override final  String url;
/// The chapter title, when the caller knows it (`java.get('title')`).
@override@JsonKey() final  String title;
/// The book title, when the caller knows it (`java.get('bookName')`).
@override@JsonKey() final  String bookName;

/// Create a copy of ChapterRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChapterRequestCopyWith<_ChapterRequest> get copyWith => __$ChapterRequestCopyWithImpl<_ChapterRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChapterRequest&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.bookName, bookName) || other.bookName == bookName));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,title,bookName);
}

@override
String toString() {
    return 'ChapterRequest(url: $url, title: $title, bookName: $bookName)';
}


}

/// @nodoc
abstract mixin class _$ChapterRequestCopyWith<$Res> implements $ChapterRequestCopyWith<$Res> {
  factory _$ChapterRequestCopyWith(_ChapterRequest value, $Res Function(_ChapterRequest) _then) = __$ChapterRequestCopyWithImpl;
@override @useResult
$Res call({
 String url, String title, String bookName
});




}
/// @nodoc
class __$ChapterRequestCopyWithImpl<$Res>
    implements _$ChapterRequestCopyWith<$Res> {
  __$ChapterRequestCopyWithImpl(this._self, this._then);

  final _ChapterRequest _self;
  final $Res Function(_ChapterRequest) _then;

/// Create a copy of ChapterRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? title = null,Object? bookName = null,}) {
  return _then(_ChapterRequest(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
