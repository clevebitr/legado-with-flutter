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

 String get name; String get url; String get tocUrl; String? get author; String? get kind; String? get coverUrl; String? get intro; String? get lastChapter; String? get wordCount; String? get updateTime; bool get canReName;
/// Create a copy of BookInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookInfoCopyWith<BookInfo> get copyWith => _$BookInfoCopyWithImpl<BookInfo>(this as BookInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookInfo&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.tocUrl, _this.tocUrl) || other.tocUrl == _this.tocUrl)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&(identical(other.lastChapter, _this.lastChapter) || other.lastChapter == _this.lastChapter)&&(identical(other.wordCount, _this.wordCount) || other.wordCount == _this.wordCount)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime)&&(identical(other.canReName, _this.canReName) || other.canReName == _this.canReName));
}


@override
int get hashCode {
  final _this = this as BookInfo;
  return Object.hash(runtimeType,_this.name,_this.url,_this.tocUrl,_this.author,_this.kind,_this.coverUrl,_this.intro,_this.lastChapter,_this.wordCount,_this.updateTime,_this.canReName);
}

@override
String toString() {
  final _this = this as BookInfo;
  return 'BookInfo(name: ${_this.name}, url: ${_this.url}, tocUrl: ${_this.tocUrl}, author: ${_this.author}, kind: ${_this.kind}, coverUrl: ${_this.coverUrl}, intro: ${_this.intro}, lastChapter: ${_this.lastChapter}, wordCount: ${_this.wordCount}, updateTime: ${_this.updateTime}, canReName: ${_this.canReName})';
}


}

/// @nodoc
abstract mixin class $BookInfoCopyWith<$Res>  {
  factory $BookInfoCopyWith(BookInfo value, $Res Function(BookInfo) _then) = _$BookInfoCopyWithImpl;
@useResult
$Res call({
 String name, String url, String tocUrl, String? author, String? kind, String? coverUrl, String? intro, String? lastChapter, String? wordCount, String? updateTime, bool canReName
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
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,Object? tocUrl = null,Object? author = freezed,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? wordCount = freezed,Object? updateTime = freezed,Object? canReName = null,}) {
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
as String?,canReName: null == canReName ? _self.canReName : canReName // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String url,  String tocUrl,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime,  bool canReName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookInfo() when $default != null:
return $default(_that.name,_that.url,_that.tocUrl,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime,_that.canReName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String url,  String tocUrl,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime,  bool canReName)  $default,) {final _that = this;
switch (_that) {
case _BookInfo():
return $default(_that.name,_that.url,_that.tocUrl,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime,_that.canReName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String url,  String tocUrl,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? wordCount,  String? updateTime,  bool canReName)?  $default,) {final _that = this;
switch (_that) {
case _BookInfo() when $default != null:
return $default(_that.name,_that.url,_that.tocUrl,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.wordCount,_that.updateTime,_that.canReName);case _:
  return null;

}
}

}

/// @nodoc


class _BookInfo implements BookInfo {
  const _BookInfo({required this.name, required this.url, required this.tocUrl, this.author, this.kind, this.coverUrl, this.intro, this.lastChapter, this.wordCount, this.updateTime, this.canReName = false});
  

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
@override@JsonKey() final  bool canReName;

/// Create a copy of BookInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookInfoCopyWith<_BookInfo> get copyWith => __$BookInfoCopyWithImpl<_BookInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl)&&(identical(other.author, author) || other.author == author)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.lastChapter, lastChapter) || other.lastChapter == lastChapter)&&(identical(other.wordCount, wordCount) || other.wordCount == wordCount)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime)&&(identical(other.canReName, canReName) || other.canReName == canReName));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,url,tocUrl,author,kind,coverUrl,intro,lastChapter,wordCount,updateTime,canReName);
}

@override
String toString() {
    return 'BookInfo(name: $name, url: $url, tocUrl: $tocUrl, author: $author, kind: $kind, coverUrl: $coverUrl, intro: $intro, lastChapter: $lastChapter, wordCount: $wordCount, updateTime: $updateTime, canReName: $canReName)';
}


}

/// @nodoc
abstract mixin class _$BookInfoCopyWith<$Res> implements $BookInfoCopyWith<$Res> {
  factory _$BookInfoCopyWith(_BookInfo value, $Res Function(_BookInfo) _then) = __$BookInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String url, String tocUrl, String? author, String? kind, String? coverUrl, String? intro, String? lastChapter, String? wordCount, String? updateTime, bool canReName
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
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,Object? tocUrl = null,Object? author = freezed,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? wordCount = freezed,Object? updateTime = freezed,Object? canReName = null,}) {
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
as String?,canReName: null == canReName ? _self.canReName : canReName // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$Chapter {

 String get name; String get url; bool get isVip; bool get isPay; bool get isVolume; String? get updateTime; String? get wordCount; Map<String, String> get variable; String? get reviewImg;
/// Create a copy of Chapter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChapterCopyWith<Chapter> get copyWith => _$ChapterCopyWithImpl<Chapter>(this as Chapter, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Chapter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Chapter&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.isVip, _this.isVip) || other.isVip == _this.isVip)&&(identical(other.isPay, _this.isPay) || other.isPay == _this.isPay)&&(identical(other.isVolume, _this.isVolume) || other.isVolume == _this.isVolume)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime)&&(identical(other.wordCount, _this.wordCount) || other.wordCount == _this.wordCount)&&const DeepCollectionEquality().equals(other.variable, _this.variable)&&(identical(other.reviewImg, _this.reviewImg) || other.reviewImg == _this.reviewImg));
}


@override
int get hashCode {
  final _this = this as Chapter;
  return Object.hash(runtimeType,_this.name,_this.url,_this.isVip,_this.isPay,_this.isVolume,_this.updateTime,_this.wordCount,const DeepCollectionEquality().hash(_this.variable),_this.reviewImg);
}

@override
String toString() {
  final _this = this as Chapter;
  return 'Chapter(name: ${_this.name}, url: ${_this.url}, isVip: ${_this.isVip}, isPay: ${_this.isPay}, isVolume: ${_this.isVolume}, updateTime: ${_this.updateTime}, wordCount: ${_this.wordCount}, variable: ${_this.variable}, reviewImg: ${_this.reviewImg})';
}


}

/// @nodoc
abstract mixin class $ChapterCopyWith<$Res>  {
  factory $ChapterCopyWith(Chapter value, $Res Function(Chapter) _then) = _$ChapterCopyWithImpl;
@useResult
$Res call({
 String name, String url, bool isVip, bool isPay, bool isVolume, String? updateTime, String? wordCount, Map<String, String> variable, String? reviewImg
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
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,Object? isVip = null,Object? isPay = null,Object? isVolume = null,Object? updateTime = freezed,Object? wordCount = freezed,Object? variable = null,Object? reviewImg = freezed,}) {
  return _then(Chapter(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,isVip: null == isVip ? _self.isVip : isVip // ignore: cast_nullable_to_non_nullable
as bool,isPay: null == isPay ? _self.isPay : isPay // ignore: cast_nullable_to_non_nullable
as bool,isVolume: null == isVolume ? _self.isVolume : isVolume // ignore: cast_nullable_to_non_nullable
as bool,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,variable: null == variable ? _self.variable : variable // ignore: cast_nullable_to_non_nullable
as Map<String, String>,reviewImg: freezed == reviewImg ? _self.reviewImg : reviewImg // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String url,  bool isVip,  bool isPay,  bool isVolume,  String? updateTime,  String? wordCount,  Map<String, String> variable,  String? reviewImg)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Chapter() when $default != null:
return $default(_that.name,_that.url,_that.isVip,_that.isPay,_that.isVolume,_that.updateTime,_that.wordCount,_that.variable,_that.reviewImg);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String url,  bool isVip,  bool isPay,  bool isVolume,  String? updateTime,  String? wordCount,  Map<String, String> variable,  String? reviewImg)  $default,) {final _that = this;
switch (_that) {
case _Chapter():
return $default(_that.name,_that.url,_that.isVip,_that.isPay,_that.isVolume,_that.updateTime,_that.wordCount,_that.variable,_that.reviewImg);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String url,  bool isVip,  bool isPay,  bool isVolume,  String? updateTime,  String? wordCount,  Map<String, String> variable,  String? reviewImg)?  $default,) {final _that = this;
switch (_that) {
case _Chapter() when $default != null:
return $default(_that.name,_that.url,_that.isVip,_that.isPay,_that.isVolume,_that.updateTime,_that.wordCount,_that.variable,_that.reviewImg);case _:
  return null;

}
}

}

/// @nodoc


class _Chapter implements Chapter {
  const _Chapter({required this.name, required this.url, this.isVip = false, this.isPay = false, this.isVolume = false, this.updateTime, this.wordCount,  Map<String, String> variable = const <String, String>{}, this.reviewImg}): _variable = variable;
  

@override final  String name;
@override final  String url;
@override@JsonKey() final  bool isVip;
@override@JsonKey() final  bool isPay;
@override@JsonKey() final  bool isVolume;
@override final  String? updateTime;
@override final  String? wordCount;
 final  Map<String, String> _variable;
@override@JsonKey() Map<String, String> get variable {
  if (_variable is EqualUnmodifiableMapView) return _variable;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_variable);
}

@override final  String? reviewImg;

/// Create a copy of Chapter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChapterCopyWith<_Chapter> get copyWith => __$ChapterCopyWithImpl<_Chapter>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Chapter&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.isVip, isVip) || other.isVip == isVip)&&(identical(other.isPay, isPay) || other.isPay == isPay)&&(identical(other.isVolume, isVolume) || other.isVolume == isVolume)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime)&&(identical(other.wordCount, wordCount) || other.wordCount == wordCount)&&const DeepCollectionEquality().equals(other.variable, _variable)&&(identical(other.reviewImg, reviewImg) || other.reviewImg == reviewImg));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,url,isVip,isPay,isVolume,updateTime,wordCount,const DeepCollectionEquality().hash(_variable),reviewImg);
}

@override
String toString() {
    return 'Chapter(name: $name, url: $url, isVip: $isVip, isPay: $isPay, isVolume: $isVolume, updateTime: $updateTime, wordCount: $wordCount, variable: $variable, reviewImg: $reviewImg)';
}


}

/// @nodoc
abstract mixin class _$ChapterCopyWith<$Res> implements $ChapterCopyWith<$Res> {
  factory _$ChapterCopyWith(_Chapter value, $Res Function(_Chapter) _then) = __$ChapterCopyWithImpl;
@override @useResult
$Res call({
 String name, String url, bool isVip, bool isPay, bool isVolume, String? updateTime, String? wordCount, Map<String, String> variable, String? reviewImg
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
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,Object? isVip = null,Object? isPay = null,Object? isVolume = null,Object? updateTime = freezed,Object? wordCount = freezed,Object? variable = null,Object? reviewImg = freezed,}) {
  return _then(_Chapter(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,isVip: null == isVip ? _self.isVip : isVip // ignore: cast_nullable_to_non_nullable
as bool,isPay: null == isPay ? _self.isPay : isPay // ignore: cast_nullable_to_non_nullable
as bool,isVolume: null == isVolume ? _self.isVolume : isVolume // ignore: cast_nullable_to_non_nullable
as bool,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,variable: null == variable ? _self._variable : variable // ignore: cast_nullable_to_non_nullable
as Map<String, String>,reviewImg: freezed == reviewImg ? _self.reviewImg : reviewImg // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
