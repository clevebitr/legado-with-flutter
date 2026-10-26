// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bookmark.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Bookmark {

 int get id; String get sourceUrl; String get bookUrl; String get bookName; String? get tocUrl; String get chapterUrl; String? get chapterName; int get chapterIndex; int get charOffset; String? get excerpt; DateTime get createdAt;
/// Create a copy of Bookmark
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookmarkCopyWith<Bookmark> get copyWith => _$BookmarkCopyWithImpl<Bookmark>(this as Bookmark, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Bookmark;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Bookmark&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sourceUrl, _this.sourceUrl) || other.sourceUrl == _this.sourceUrl)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.bookName, _this.bookName) || other.bookName == _this.bookName)&&(identical(other.tocUrl, _this.tocUrl) || other.tocUrl == _this.tocUrl)&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.chapterName, _this.chapterName) || other.chapterName == _this.chapterName)&&(identical(other.chapterIndex, _this.chapterIndex) || other.chapterIndex == _this.chapterIndex)&&(identical(other.charOffset, _this.charOffset) || other.charOffset == _this.charOffset)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}


@override
int get hashCode {
  final _this = this as Bookmark;
  return Object.hash(runtimeType,_this.id,_this.sourceUrl,_this.bookUrl,_this.bookName,_this.tocUrl,_this.chapterUrl,_this.chapterName,_this.chapterIndex,_this.charOffset,_this.excerpt,_this.createdAt);
}

@override
String toString() {
  final _this = this as Bookmark;
  return 'Bookmark(id: ${_this.id}, sourceUrl: ${_this.sourceUrl}, bookUrl: ${_this.bookUrl}, bookName: ${_this.bookName}, tocUrl: ${_this.tocUrl}, chapterUrl: ${_this.chapterUrl}, chapterName: ${_this.chapterName}, chapterIndex: ${_this.chapterIndex}, charOffset: ${_this.charOffset}, excerpt: ${_this.excerpt}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $BookmarkCopyWith<$Res>  {
  factory $BookmarkCopyWith(Bookmark value, $Res Function(Bookmark) _then) = _$BookmarkCopyWithImpl;
@useResult
$Res call({
 int id, String sourceUrl, String bookUrl, String bookName, String? tocUrl, String chapterUrl, String? chapterName, int chapterIndex, int charOffset, String? excerpt, DateTime createdAt
});




}
/// @nodoc
class _$BookmarkCopyWithImpl<$Res>
    implements $BookmarkCopyWith<$Res> {
  _$BookmarkCopyWithImpl(this._self, this._then);

  final Bookmark _self;
  final $Res Function(Bookmark) _then;

/// Create a copy of Bookmark
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,Object? tocUrl = freezed,Object? chapterUrl = null,Object? chapterName = freezed,Object? chapterIndex = null,Object? charOffset = null,Object? excerpt = freezed,Object? createdAt = null,}) {
  return _then(Bookmark(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,tocUrl: freezed == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Bookmark].
extension BookmarkPatterns on Bookmark {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Bookmark value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Bookmark() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Bookmark value)  $default,){
final _that = this;
switch (_that) {
case _Bookmark():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Bookmark value)?  $default,){
final _that = this;
switch (_that) {
case _Bookmark() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String sourceUrl,  String bookUrl,  String bookName,  String? tocUrl,  String chapterUrl,  String? chapterName,  int chapterIndex,  int charOffset,  String? excerpt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Bookmark() when $default != null:
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.bookName,_that.tocUrl,_that.chapterUrl,_that.chapterName,_that.chapterIndex,_that.charOffset,_that.excerpt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String sourceUrl,  String bookUrl,  String bookName,  String? tocUrl,  String chapterUrl,  String? chapterName,  int chapterIndex,  int charOffset,  String? excerpt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Bookmark():
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.bookName,_that.tocUrl,_that.chapterUrl,_that.chapterName,_that.chapterIndex,_that.charOffset,_that.excerpt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String sourceUrl,  String bookUrl,  String bookName,  String? tocUrl,  String chapterUrl,  String? chapterName,  int chapterIndex,  int charOffset,  String? excerpt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Bookmark() when $default != null:
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.bookName,_that.tocUrl,_that.chapterUrl,_that.chapterName,_that.chapterIndex,_that.charOffset,_that.excerpt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Bookmark implements Bookmark {
  const _Bookmark({required this.id, required this.sourceUrl, required this.bookUrl, required this.bookName, this.tocUrl, required this.chapterUrl, this.chapterName, this.chapterIndex = 0, this.charOffset = 0, this.excerpt, required this.createdAt});
  

@override final  int id;
@override final  String sourceUrl;
@override final  String bookUrl;
@override final  String bookName;
@override final  String? tocUrl;
@override final  String chapterUrl;
@override final  String? chapterName;
@override@JsonKey() final  int chapterIndex;
@override@JsonKey() final  int charOffset;
@override final  String? excerpt;
@override final  DateTime createdAt;

/// Create a copy of Bookmark
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookmarkCopyWith<_Bookmark> get copyWith => __$BookmarkCopyWithImpl<_Bookmark>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Bookmark&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.bookName, bookName) || other.bookName == bookName)&&(identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl)&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.chapterName, chapterName) || other.chapterName == chapterName)&&(identical(other.chapterIndex, chapterIndex) || other.chapterIndex == chapterIndex)&&(identical(other.charOffset, charOffset) || other.charOffset == charOffset)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,sourceUrl,bookUrl,bookName,tocUrl,chapterUrl,chapterName,chapterIndex,charOffset,excerpt,createdAt);
}

@override
String toString() {
    return 'Bookmark(id: $id, sourceUrl: $sourceUrl, bookUrl: $bookUrl, bookName: $bookName, tocUrl: $tocUrl, chapterUrl: $chapterUrl, chapterName: $chapterName, chapterIndex: $chapterIndex, charOffset: $charOffset, excerpt: $excerpt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$BookmarkCopyWith<$Res> implements $BookmarkCopyWith<$Res> {
  factory _$BookmarkCopyWith(_Bookmark value, $Res Function(_Bookmark) _then) = __$BookmarkCopyWithImpl;
@override @useResult
$Res call({
 int id, String sourceUrl, String bookUrl, String bookName, String? tocUrl, String chapterUrl, String? chapterName, int chapterIndex, int charOffset, String? excerpt, DateTime createdAt
});




}
/// @nodoc
class __$BookmarkCopyWithImpl<$Res>
    implements _$BookmarkCopyWith<$Res> {
  __$BookmarkCopyWithImpl(this._self, this._then);

  final _Bookmark _self;
  final $Res Function(_Bookmark) _then;

/// Create a copy of Bookmark
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,Object? tocUrl = freezed,Object? chapterUrl = null,Object? chapterName = freezed,Object? chapterIndex = null,Object? charOffset = null,Object? excerpt = freezed,Object? createdAt = null,}) {
  return _then(_Bookmark(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,tocUrl: freezed == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$BookmarkDraft {

 String get sourceUrl; String get bookUrl; String get bookName; String? get tocUrl; String get chapterUrl; String? get chapterName; int get chapterIndex; int get charOffset; String? get excerpt;
/// Create a copy of BookmarkDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookmarkDraftCopyWith<BookmarkDraft> get copyWith => _$BookmarkDraftCopyWithImpl<BookmarkDraft>(this as BookmarkDraft, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookmarkDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookmarkDraft&&(identical(other.sourceUrl, _this.sourceUrl) || other.sourceUrl == _this.sourceUrl)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.bookName, _this.bookName) || other.bookName == _this.bookName)&&(identical(other.tocUrl, _this.tocUrl) || other.tocUrl == _this.tocUrl)&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.chapterName, _this.chapterName) || other.chapterName == _this.chapterName)&&(identical(other.chapterIndex, _this.chapterIndex) || other.chapterIndex == _this.chapterIndex)&&(identical(other.charOffset, _this.charOffset) || other.charOffset == _this.charOffset)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt));
}


@override
int get hashCode {
  final _this = this as BookmarkDraft;
  return Object.hash(runtimeType,_this.sourceUrl,_this.bookUrl,_this.bookName,_this.tocUrl,_this.chapterUrl,_this.chapterName,_this.chapterIndex,_this.charOffset,_this.excerpt);
}

@override
String toString() {
  final _this = this as BookmarkDraft;
  return 'BookmarkDraft(sourceUrl: ${_this.sourceUrl}, bookUrl: ${_this.bookUrl}, bookName: ${_this.bookName}, tocUrl: ${_this.tocUrl}, chapterUrl: ${_this.chapterUrl}, chapterName: ${_this.chapterName}, chapterIndex: ${_this.chapterIndex}, charOffset: ${_this.charOffset}, excerpt: ${_this.excerpt})';
}


}

/// @nodoc
abstract mixin class $BookmarkDraftCopyWith<$Res>  {
  factory $BookmarkDraftCopyWith(BookmarkDraft value, $Res Function(BookmarkDraft) _then) = _$BookmarkDraftCopyWithImpl;
@useResult
$Res call({
 String sourceUrl, String bookUrl, String bookName, String? tocUrl, String chapterUrl, String? chapterName, int chapterIndex, int charOffset, String? excerpt
});




}
/// @nodoc
class _$BookmarkDraftCopyWithImpl<$Res>
    implements $BookmarkDraftCopyWith<$Res> {
  _$BookmarkDraftCopyWithImpl(this._self, this._then);

  final BookmarkDraft _self;
  final $Res Function(BookmarkDraft) _then;

/// Create a copy of BookmarkDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,Object? tocUrl = freezed,Object? chapterUrl = null,Object? chapterName = freezed,Object? chapterIndex = null,Object? charOffset = null,Object? excerpt = freezed,}) {
  return _then(BookmarkDraft(
sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,tocUrl: freezed == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookmarkDraft].
extension BookmarkDraftPatterns on BookmarkDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookmarkDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookmarkDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookmarkDraft value)  $default,){
final _that = this;
switch (_that) {
case _BookmarkDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookmarkDraft value)?  $default,){
final _that = this;
switch (_that) {
case _BookmarkDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceUrl,  String bookUrl,  String bookName,  String? tocUrl,  String chapterUrl,  String? chapterName,  int chapterIndex,  int charOffset,  String? excerpt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookmarkDraft() when $default != null:
return $default(_that.sourceUrl,_that.bookUrl,_that.bookName,_that.tocUrl,_that.chapterUrl,_that.chapterName,_that.chapterIndex,_that.charOffset,_that.excerpt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceUrl,  String bookUrl,  String bookName,  String? tocUrl,  String chapterUrl,  String? chapterName,  int chapterIndex,  int charOffset,  String? excerpt)  $default,) {final _that = this;
switch (_that) {
case _BookmarkDraft():
return $default(_that.sourceUrl,_that.bookUrl,_that.bookName,_that.tocUrl,_that.chapterUrl,_that.chapterName,_that.chapterIndex,_that.charOffset,_that.excerpt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceUrl,  String bookUrl,  String bookName,  String? tocUrl,  String chapterUrl,  String? chapterName,  int chapterIndex,  int charOffset,  String? excerpt)?  $default,) {final _that = this;
switch (_that) {
case _BookmarkDraft() when $default != null:
return $default(_that.sourceUrl,_that.bookUrl,_that.bookName,_that.tocUrl,_that.chapterUrl,_that.chapterName,_that.chapterIndex,_that.charOffset,_that.excerpt);case _:
  return null;

}
}

}

/// @nodoc


class _BookmarkDraft implements BookmarkDraft {
  const _BookmarkDraft({required this.sourceUrl, required this.bookUrl, required this.bookName, this.tocUrl, required this.chapterUrl, this.chapterName, this.chapterIndex = 0, this.charOffset = 0, this.excerpt});
  

@override final  String sourceUrl;
@override final  String bookUrl;
@override final  String bookName;
@override final  String? tocUrl;
@override final  String chapterUrl;
@override final  String? chapterName;
@override@JsonKey() final  int chapterIndex;
@override@JsonKey() final  int charOffset;
@override final  String? excerpt;

/// Create a copy of BookmarkDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookmarkDraftCopyWith<_BookmarkDraft> get copyWith => __$BookmarkDraftCopyWithImpl<_BookmarkDraft>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookmarkDraft&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.bookName, bookName) || other.bookName == bookName)&&(identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl)&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.chapterName, chapterName) || other.chapterName == chapterName)&&(identical(other.chapterIndex, chapterIndex) || other.chapterIndex == chapterIndex)&&(identical(other.charOffset, charOffset) || other.charOffset == charOffset)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceUrl,bookUrl,bookName,tocUrl,chapterUrl,chapterName,chapterIndex,charOffset,excerpt);
}

@override
String toString() {
    return 'BookmarkDraft(sourceUrl: $sourceUrl, bookUrl: $bookUrl, bookName: $bookName, tocUrl: $tocUrl, chapterUrl: $chapterUrl, chapterName: $chapterName, chapterIndex: $chapterIndex, charOffset: $charOffset, excerpt: $excerpt)';
}


}

/// @nodoc
abstract mixin class _$BookmarkDraftCopyWith<$Res> implements $BookmarkDraftCopyWith<$Res> {
  factory _$BookmarkDraftCopyWith(_BookmarkDraft value, $Res Function(_BookmarkDraft) _then) = __$BookmarkDraftCopyWithImpl;
@override @useResult
$Res call({
 String sourceUrl, String bookUrl, String bookName, String? tocUrl, String chapterUrl, String? chapterName, int chapterIndex, int charOffset, String? excerpt
});




}
/// @nodoc
class __$BookmarkDraftCopyWithImpl<$Res>
    implements _$BookmarkDraftCopyWith<$Res> {
  __$BookmarkDraftCopyWithImpl(this._self, this._then);

  final _BookmarkDraft _self;
  final $Res Function(_BookmarkDraft) _then;

/// Create a copy of BookmarkDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,Object? tocUrl = freezed,Object? chapterUrl = null,Object? chapterName = freezed,Object? chapterIndex = null,Object? charOffset = null,Object? excerpt = freezed,}) {
  return _then(_BookmarkDraft(
sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,tocUrl: freezed == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
