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
 String get bookName;/// The book's detail URL, when the caller knows it (`book.bookUrl`, ADR-0055 P2).
 String get bookUrl;/// The book's table-of-contents URL (`book.tocUrl`, ADR-0055 P2).
 String get tocUrl;/// The author, when the caller knows it (`book.author`, ADR-0055 P2).
 String get author;/// The category, when the caller knows it (`book.kind`, ADR-0055 P2).
 String get kind;/// The introduction, when the caller knows it (`book.intro`, ADR-0055 P2).
 String get intro;
/// Create a copy of ChapterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChapterRequestCopyWith<ChapterRequest> get copyWith => _$ChapterRequestCopyWithImpl<ChapterRequest>(this as ChapterRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ChapterRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChapterRequest&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.bookName, _this.bookName) || other.bookName == _this.bookName)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.tocUrl, _this.tocUrl) || other.tocUrl == _this.tocUrl)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.intro, _this.intro) || other.intro == _this.intro));
}


@override
int get hashCode {
  final _this = this as ChapterRequest;
  return Object.hash(runtimeType,_this.url,_this.title,_this.bookName,_this.bookUrl,_this.tocUrl,_this.author,_this.kind,_this.intro);
}

@override
String toString() {
  final _this = this as ChapterRequest;
  return 'ChapterRequest(url: ${_this.url}, title: ${_this.title}, bookName: ${_this.bookName}, bookUrl: ${_this.bookUrl}, tocUrl: ${_this.tocUrl}, author: ${_this.author}, kind: ${_this.kind}, intro: ${_this.intro})';
}


}

/// @nodoc
abstract mixin class $ChapterRequestCopyWith<$Res>  {
  factory $ChapterRequestCopyWith(ChapterRequest value, $Res Function(ChapterRequest) _then) = _$ChapterRequestCopyWithImpl;
@useResult
$Res call({
 String url, String title, String bookName, String bookUrl, String tocUrl, String author, String kind, String intro
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
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? title = null,Object? bookName = null,Object? bookUrl = null,Object? tocUrl = null,Object? author = null,Object? kind = null,Object? intro = null,}) {
  return _then(ChapterRequest(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,tocUrl: null == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,intro: null == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String title,  String bookName,  String bookUrl,  String tocUrl,  String author,  String kind,  String intro)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChapterRequest() when $default != null:
return $default(_that.url,_that.title,_that.bookName,_that.bookUrl,_that.tocUrl,_that.author,_that.kind,_that.intro);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String title,  String bookName,  String bookUrl,  String tocUrl,  String author,  String kind,  String intro)  $default,) {final _that = this;
switch (_that) {
case _ChapterRequest():
return $default(_that.url,_that.title,_that.bookName,_that.bookUrl,_that.tocUrl,_that.author,_that.kind,_that.intro);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String title,  String bookName,  String bookUrl,  String tocUrl,  String author,  String kind,  String intro)?  $default,) {final _that = this;
switch (_that) {
case _ChapterRequest() when $default != null:
return $default(_that.url,_that.title,_that.bookName,_that.bookUrl,_that.tocUrl,_that.author,_that.kind,_that.intro);case _:
  return null;

}
}

}

/// @nodoc


class _ChapterRequest implements ChapterRequest {
  const _ChapterRequest({required this.url, this.title = '', this.bookName = '', this.bookUrl = '', this.tocUrl = '', this.author = '', this.kind = '', this.intro = ''});
  

/// The chapter page URL — the same value that used to be the whole argument.
@override final  String url;
/// The chapter title, when the caller knows it (`java.get('title')`).
@override@JsonKey() final  String title;
/// The book title, when the caller knows it (`java.get('bookName')`).
@override@JsonKey() final  String bookName;
/// The book's detail URL, when the caller knows it (`book.bookUrl`, ADR-0055 P2).
@override@JsonKey() final  String bookUrl;
/// The book's table-of-contents URL (`book.tocUrl`, ADR-0055 P2).
@override@JsonKey() final  String tocUrl;
/// The author, when the caller knows it (`book.author`, ADR-0055 P2).
@override@JsonKey() final  String author;
/// The category, when the caller knows it (`book.kind`, ADR-0055 P2).
@override@JsonKey() final  String kind;
/// The introduction, when the caller knows it (`book.intro`, ADR-0055 P2).
@override@JsonKey() final  String intro;

/// Create a copy of ChapterRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChapterRequestCopyWith<_ChapterRequest> get copyWith => __$ChapterRequestCopyWithImpl<_ChapterRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChapterRequest&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.bookName, bookName) || other.bookName == bookName)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl)&&(identical(other.author, author) || other.author == author)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.intro, intro) || other.intro == intro));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,title,bookName,bookUrl,tocUrl,author,kind,intro);
}

@override
String toString() {
    return 'ChapterRequest(url: $url, title: $title, bookName: $bookName, bookUrl: $bookUrl, tocUrl: $tocUrl, author: $author, kind: $kind, intro: $intro)';
}


}

/// @nodoc
abstract mixin class _$ChapterRequestCopyWith<$Res> implements $ChapterRequestCopyWith<$Res> {
  factory _$ChapterRequestCopyWith(_ChapterRequest value, $Res Function(_ChapterRequest) _then) = __$ChapterRequestCopyWithImpl;
@override @useResult
$Res call({
 String url, String title, String bookName, String bookUrl, String tocUrl, String author, String kind, String intro
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
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? title = null,Object? bookName = null,Object? bookUrl = null,Object? tocUrl = null,Object? author = null,Object? kind = null,Object? intro = null,}) {
  return _then(_ChapterRequest(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,tocUrl: null == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,intro: null == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
