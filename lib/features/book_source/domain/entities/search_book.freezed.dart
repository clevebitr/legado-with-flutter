// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SearchBook {

/// The title as the first origin spelled it.
 String get name;/// The author as the first origin spelled it; `null` when the rule matched nothing.
 String? get author;/// The detail URL of the first origin.
 String get url;/// The `bookSourceUrl`s that found this book, de-duplicated, in discovery order.
 List<String> get origins;/// The category as the first origin spelled it.
 String? get kind;/// The cover URL as the first origin spelled it.
 String? get coverUrl;/// The introduction as the first origin spelled it.
 String? get intro;/// The latest chapter as the first origin spelled it.
 String? get lastChapter;/// The update time as the first origin spelled it (display string, `book-source.md` §2).
 String? get updateTime;
/// Create a copy of SearchBook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchBookCopyWith<SearchBook> get copyWith => _$SearchBookCopyWithImpl<SearchBook>(this as SearchBook, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SearchBook;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchBook&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.url, _this.url) || other.url == _this.url)&&const DeepCollectionEquality().equals(other.origins, _this.origins)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&(identical(other.lastChapter, _this.lastChapter) || other.lastChapter == _this.lastChapter)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime));
}


@override
int get hashCode {
  final _this = this as SearchBook;
  return Object.hash(runtimeType,_this.name,_this.author,_this.url,const DeepCollectionEquality().hash(_this.origins),_this.kind,_this.coverUrl,_this.intro,_this.lastChapter,_this.updateTime);
}

@override
String toString() {
  final _this = this as SearchBook;
  return 'SearchBook(name: ${_this.name}, author: ${_this.author}, url: ${_this.url}, origins: ${_this.origins}, kind: ${_this.kind}, coverUrl: ${_this.coverUrl}, intro: ${_this.intro}, lastChapter: ${_this.lastChapter}, updateTime: ${_this.updateTime})';
}


}

/// @nodoc
abstract mixin class $SearchBookCopyWith<$Res>  {
  factory $SearchBookCopyWith(SearchBook value, $Res Function(SearchBook) _then) = _$SearchBookCopyWithImpl;
@useResult
$Res call({
 String name, String? author, String url, List<String> origins, String? kind, String? coverUrl, String? intro, String? lastChapter, String? updateTime
});




}
/// @nodoc
class _$SearchBookCopyWithImpl<$Res>
    implements $SearchBookCopyWith<$Res> {
  _$SearchBookCopyWithImpl(this._self, this._then);

  final SearchBook _self;
  final $Res Function(SearchBook) _then;

/// Create a copy of SearchBook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? author = freezed,Object? url = null,Object? origins = null,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? updateTime = freezed,}) {
  return _then(SearchBook(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,origins: null == origins ? _self.origins : origins // ignore: cast_nullable_to_non_nullable
as List<String>,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchBook].
extension SearchBookPatterns on SearchBook {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchBook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchBook() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchBook value)  $default,){
final _that = this;
switch (_that) {
case _SearchBook():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchBook value)?  $default,){
final _that = this;
switch (_that) {
case _SearchBook() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? author,  String url,  List<String> origins,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? updateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchBook() when $default != null:
return $default(_that.name,_that.author,_that.url,_that.origins,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.updateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? author,  String url,  List<String> origins,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? updateTime)  $default,) {final _that = this;
switch (_that) {
case _SearchBook():
return $default(_that.name,_that.author,_that.url,_that.origins,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.updateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? author,  String url,  List<String> origins,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  String? updateTime)?  $default,) {final _that = this;
switch (_that) {
case _SearchBook() when $default != null:
return $default(_that.name,_that.author,_that.url,_that.origins,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.updateTime);case _:
  return null;

}
}

}

/// @nodoc


class _SearchBook implements SearchBook {
  const _SearchBook({required this.name, this.author, required this.url,  List<String> origins = const <String>[], this.kind, this.coverUrl, this.intro, this.lastChapter, this.updateTime}): _origins = origins;
  

/// The title as the first origin spelled it.
@override final  String name;
/// The author as the first origin spelled it; `null` when the rule matched nothing.
@override final  String? author;
/// The detail URL of the first origin.
@override final  String url;
/// The `bookSourceUrl`s that found this book, de-duplicated, in discovery order.
 final  List<String> _origins;
/// The `bookSourceUrl`s that found this book, de-duplicated, in discovery order.
@override@JsonKey() List<String> get origins {
  if (_origins is EqualUnmodifiableListView) return _origins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_origins);
}

/// The category as the first origin spelled it.
@override final  String? kind;
/// The cover URL as the first origin spelled it.
@override final  String? coverUrl;
/// The introduction as the first origin spelled it.
@override final  String? intro;
/// The latest chapter as the first origin spelled it.
@override final  String? lastChapter;
/// The update time as the first origin spelled it (display string, `book-source.md` §2).
@override final  String? updateTime;

/// Create a copy of SearchBook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchBookCopyWith<_SearchBook> get copyWith => __$SearchBookCopyWithImpl<_SearchBook>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchBook&&(identical(other.name, name) || other.name == name)&&(identical(other.author, author) || other.author == author)&&(identical(other.url, url) || other.url == url)&&const DeepCollectionEquality().equals(other.origins, _origins)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.lastChapter, lastChapter) || other.lastChapter == lastChapter)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,author,url,const DeepCollectionEquality().hash(_origins),kind,coverUrl,intro,lastChapter,updateTime);
}

@override
String toString() {
    return 'SearchBook(name: $name, author: $author, url: $url, origins: $origins, kind: $kind, coverUrl: $coverUrl, intro: $intro, lastChapter: $lastChapter, updateTime: $updateTime)';
}


}

/// @nodoc
abstract mixin class _$SearchBookCopyWith<$Res> implements $SearchBookCopyWith<$Res> {
  factory _$SearchBookCopyWith(_SearchBook value, $Res Function(_SearchBook) _then) = __$SearchBookCopyWithImpl;
@override @useResult
$Res call({
 String name, String? author, String url, List<String> origins, String? kind, String? coverUrl, String? intro, String? lastChapter, String? updateTime
});




}
/// @nodoc
class __$SearchBookCopyWithImpl<$Res>
    implements _$SearchBookCopyWith<$Res> {
  __$SearchBookCopyWithImpl(this._self, this._then);

  final _SearchBook _self;
  final $Res Function(_SearchBook) _then;

/// Create a copy of SearchBook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? author = freezed,Object? url = null,Object? origins = null,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? updateTime = freezed,}) {
  return _then(_SearchBook(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,origins: null == origins ? _self._origins : origins // ignore: cast_nullable_to_non_nullable
as List<String>,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
