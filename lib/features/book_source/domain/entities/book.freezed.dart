// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Book {

 String get name; String get url; String? get author; String? get kind; String? get coverUrl; String? get intro; String? get lastChapter; String? get wordCount; String? get updateTime;
/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookCopyWith<Book> get copyWith => _$BookCopyWithImpl<Book>(this as Book, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Book;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Book&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&(identical(other.lastChapter, _this.lastChapter) || other.lastChapter == _this.lastChapter)&&(identical(other.wordCount, _this.wordCount) || other.wordCount == _this.wordCount)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime));
}


@override
int get hashCode {
  final _this = this as Book;
  return Object.hash(runtimeType,_this.name,_this.url,_this.author,_this.kind,_this.coverUrl,_this.intro,_this.lastChapter,_this.wordCount,_this.updateTime);
}

@override
String toString() {
  final _this = this as Book;
  return 'Book(name: ${_this.name}, url: ${_this.url}, author: ${_this.author}, kind: ${_this.kind}, coverUrl: ${_this.coverUrl}, intro: ${_this.intro}, lastChapter: ${_this.lastChapter}, wordCount: ${_this.wordCount}, updateTime: ${_this.updateTime})';
}


}

/// @nodoc
abstract mixin class $BookCopyWith<$Res>  {
  factory $BookCopyWith(Book value, $Res Function(Book) _then) = _$BookCopyWithImpl;
@useResult
$Res call({
 String name, String url, String? author, String? kind, String? coverUrl, String? intro, String? lastChapter, String? wordCount, String? updateTime
});




}
/// @nodoc
class _$BookCopyWithImpl<$Res>
    implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._self, this._then);

  final Book _self;
  final $Res Function(Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,Object? author = freezed,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? wordCount = freezed,Object? updateTime = freezed,}) {
  return _then(Book(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Book].
extension BookPatterns on Book {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Book value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Book value)  $default,){
final _that = this;
switch (_that) {
case _Book():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Book value)?  $default,){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String url,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.name,_that.url,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String url,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime)  $default,) {final _that = this;
switch (_that) {
case _Book():
return $default(_that.name,_that.url,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String url,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime)?  $default,) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.name,_that.url,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime);case _:
  return null;

}
}

}

/// @nodoc


class _Book implements Book {
  const _Book({required this.name, required this.url, this.author, this.kind, this.coverUrl, this.intro, this.lastChapter, this.wordCount, this.updateTime});
  

@override final  String name;
@override final  String url;
@override final  String? author;
@override final  String? kind;
@override final  String? coverUrl;
@override final  String? intro;
@override final  String? lastChapter;
@override final  String? wordCount;
@override final  String? updateTime;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookCopyWith<_Book> get copyWith => __$BookCopyWithImpl<_Book>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Book&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.author, author) || other.author == author)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.lastChapter, lastChapter) || other.lastChapter == lastChapter)&&(identical(other.wordCount, wordCount) || other.wordCount == wordCount)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,url,author,kind,coverUrl,intro,lastChapter,wordCount,updateTime);
}

@override
String toString() {
    return 'Book(name: $name, url: $url, author: $author, kind: $kind, coverUrl: $coverUrl, intro: $intro, lastChapter: $lastChapter, wordCount: $wordCount, updateTime: $updateTime)';
}


}

/// @nodoc
abstract mixin class _$BookCopyWith<$Res> implements $BookCopyWith<$Res> {
  factory _$BookCopyWith(_Book value, $Res Function(_Book) _then) = __$BookCopyWithImpl;
@override @useResult
$Res call({
 String name, String url, String? author, String? kind, String? coverUrl, String? intro, String? lastChapter, String? wordCount, String? updateTime
});




}
/// @nodoc
class __$BookCopyWithImpl<$Res>
    implements _$BookCopyWith<$Res> {
  __$BookCopyWithImpl(this._self, this._then);

  final _Book _self;
  final $Res Function(_Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,Object? author = freezed,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? wordCount = freezed,Object? updateTime = freezed,}) {
  return _then(_Book(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$BookInfo {

 String get name; String get url; String get tocUrl; String? get author; String? get kind; String? get coverUrl; String? get intro; String? get lastChapter; String? get wordCount; String? get updateTime;
/// Create a copy of BookInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookInfoCopyWith<BookInfo> get copyWith => _$BookInfoCopyWithImpl<BookInfo>(this as BookInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookInfo&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.tocUrl, _this.tocUrl) || other.tocUrl == _this.tocUrl)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&(identical(other.lastChapter, _this.lastChapter) || other.lastChapter == _this.lastChapter)&&(identical(other.wordCount, _this.wordCount) || other.wordCount == _this.wordCount)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime));
}


@override
int get hashCode {
  final _this = this as BookInfo;
  return Object.hash(runtimeType,_this.name,_this.url,_this.tocUrl,_this.author,_this.kind,_this.coverUrl,_this.intro,_this.lastChapter,_this.wordCount,_this.updateTime);
}

@override
String toString() {
  final _this = this as BookInfo;
  return 'BookInfo(name: ${_this.name}, url: ${_this.url}, tocUrl: ${_this.tocUrl}, author: ${_this.author}, kind: ${_this.kind}, coverUrl: ${_this.coverUrl}, intro: ${_this.intro}, lastChapter: ${_this.lastChapter}, wordCount: ${_this.wordCount}, updateTime: ${_this.updateTime})';
}


}

/// @nodoc
abstract mixin class $BookInfoCopyWith<$Res>  {
  factory $BookInfoCopyWith(BookInfo value, $Res Function(BookInfo) _then) = _$BookInfoCopyWithImpl;
@useResult
$Res call({
 String name, String url, String tocUrl, String? author, String? kind, String? coverUrl, String? intro, String? lastChapter, String? wordCount, String? updateTime
});




}
/// @nodoc
class _$BookInfoCopyWithImpl<$Res>
    implements $BookInfoCopyWith<$Res> {
  _$BookInfoCopyWithImpl(this._self, this._then);

  final BookInfo _self;
  final $Res Function(BookInfo) _then;

/// Create a copy of BookInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,Object? tocUrl = null,Object? author = freezed,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? wordCount = freezed,Object? updateTime = freezed,}) {
  return _then(BookInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,tocUrl: null == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookInfo].
extension BookInfoPatterns on BookInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookInfo value)  $default,){
final _that = this;
switch (_that) {
case _BookInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookInfo value)?  $default,){
final _that = this;
switch (_that) {
case _BookInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String url,  String tocUrl,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookInfo() when $default != null:
return $default(_that.name,_that.url,_that.tocUrl,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String url,  String tocUrl,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime)  $default,) {final _that = this;
switch (_that) {
case _BookInfo():
return $default(_that.name,_that.url,_that.tocUrl,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String url,  String tocUrl,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime)?  $default,) {final _that = this;
switch (_that) {
case _BookInfo() when $default != null:
return $default(_that.name,_that.url,_that.tocUrl,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime);case _:
  return null;

}
}

}

/// @nodoc


class _BookInfo implements BookInfo {
  const _BookInfo({required this.name, required this.url, required this.tocUrl, this.author, this.kind, this.coverUrl, this.intro, this.lastChapter, this.wordCount, this.updateTime});
  

@override final  String name;
@override final  String url;
@override final  String tocUrl;
@override final  String? author;
@override final  String? kind;
@override final  String? coverUrl;
@override final  String? intro;
@override final  String? lastChapter;
@override final  String? wordCount;
@override final  String? updateTime;

/// Create a copy of BookInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookInfoCopyWith<_BookInfo> get copyWith => __$BookInfoCopyWithImpl<_BookInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl)&&(identical(other.author, author) || other.author == author)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.lastChapter, lastChapter) || other.lastChapter == lastChapter)&&(identical(other.wordCount, wordCount) || other.wordCount == wordCount)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,url,tocUrl,author,kind,coverUrl,intro,lastChapter,wordCount,updateTime);
}

@override
String toString() {
    return 'BookInfo(name: $name, url: $url, tocUrl: $tocUrl, author: $author, kind: $kind, coverUrl: $coverUrl, intro: $intro, lastChapter: $lastChapter, wordCount: $wordCount, updateTime: $updateTime)';
}


}

/// @nodoc
abstract mixin class _$BookInfoCopyWith<$Res> implements $BookInfoCopyWith<$Res> {
  factory _$BookInfoCopyWith(_BookInfo value, $Res Function(_BookInfo) _then) = __$BookInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String url, String tocUrl, String? author, String? kind, String? coverUrl, String? intro, String? lastChapter, String? wordCount, String? updateTime
});




}
/// @nodoc
class __$BookInfoCopyWithImpl<$Res>
    implements _$BookInfoCopyWith<$Res> {
  __$BookInfoCopyWithImpl(this._self, this._then);

  final _BookInfo _self;
  final $Res Function(_BookInfo) _then;

/// Create a copy of BookInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,Object? tocUrl = null,Object? author = freezed,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? wordCount = freezed,Object? updateTime = freezed,}) {
  return _then(_BookInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,tocUrl: null == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$Chapter {

 String get name; String get url; bool get isVip; String? get updateTime;
/// Create a copy of Chapter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChapterCopyWith<Chapter> get copyWith => _$ChapterCopyWithImpl<Chapter>(this as Chapter, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Chapter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Chapter&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.isVip, _this.isVip) || other.isVip == _this.isVip)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime));
}


@override
int get hashCode {
  final _this = this as Chapter;
  return Object.hash(runtimeType,_this.name,_this.url,_this.isVip,_this.updateTime);
}

@override
String toString() {
  final _this = this as Chapter;
  return 'Chapter(name: ${_this.name}, url: ${_this.url}, isVip: ${_this.isVip}, updateTime: ${_this.updateTime})';
}


}

/// @nodoc
abstract mixin class $ChapterCopyWith<$Res>  {
  factory $ChapterCopyWith(Chapter value, $Res Function(Chapter) _then) = _$ChapterCopyWithImpl;
@useResult
$Res call({
 String name, String url, bool isVip, String? updateTime
});




}
/// @nodoc
class _$ChapterCopyWithImpl<$Res>
    implements $ChapterCopyWith<$Res> {
  _$ChapterCopyWithImpl(this._self, this._then);

  final Chapter _self;
  final $Res Function(Chapter) _then;

/// Create a copy of Chapter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,Object? isVip = null,Object? updateTime = freezed,}) {
  return _then(Chapter(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,isVip: null == isVip ? _self.isVip : isVip // ignore: cast_nullable_to_non_nullable
as bool,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Chapter].
extension ChapterPatterns on Chapter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Chapter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Chapter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Chapter value)  $default,){
final _that = this;
switch (_that) {
case _Chapter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Chapter value)?  $default,){
final _that = this;
switch (_that) {
case _Chapter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String url,  bool isVip,  String? updateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Chapter() when $default != null:
return $default(_that.name,_that.url,_that.isVip,_that.updateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String url,  bool isVip,  String? updateTime)  $default,) {final _that = this;
switch (_that) {
case _Chapter():
return $default(_that.name,_that.url,_that.isVip,_that.updateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String url,  bool isVip,  String? updateTime)?  $default,) {final _that = this;
switch (_that) {
case _Chapter() when $default != null:
return $default(_that.name,_that.url,_that.isVip,_that.updateTime);case _:
  return null;

}
}

}

/// @nodoc


class _Chapter implements Chapter {
  const _Chapter({required this.name, required this.url, this.isVip = false, this.updateTime});
  

@override final  String name;
@override final  String url;
@override@JsonKey() final  bool isVip;
@override final  String? updateTime;

/// Create a copy of Chapter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChapterCopyWith<_Chapter> get copyWith => __$ChapterCopyWithImpl<_Chapter>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Chapter&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.isVip, isVip) || other.isVip == isVip)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,url,isVip,updateTime);
}

@override
String toString() {
    return 'Chapter(name: $name, url: $url, isVip: $isVip, updateTime: $updateTime)';
}


}

/// @nodoc
abstract mixin class _$ChapterCopyWith<$Res> implements $ChapterCopyWith<$Res> {
  factory _$ChapterCopyWith(_Chapter value, $Res Function(_Chapter) _then) = __$ChapterCopyWithImpl;
@override @useResult
$Res call({
 String name, String url, bool isVip, String? updateTime
});




}
/// @nodoc
class __$ChapterCopyWithImpl<$Res>
    implements _$ChapterCopyWith<$Res> {
  __$ChapterCopyWithImpl(this._self, this._then);

  final _Chapter _self;
  final $Res Function(_Chapter) _then;

/// Create a copy of Chapter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,Object? isVip = null,Object? updateTime = freezed,}) {
  return _then(_Chapter(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,isVip: null == isVip ? _self.isVip : isVip // ignore: cast_nullable_to_non_nullable
as bool,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
