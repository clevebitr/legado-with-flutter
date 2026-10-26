// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_search.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookSearchHit {

/// Index of the chapter in the book's list.
 int get chapterIndex;/// The chapter's title, so the results list is readable without the chapter list.
 String get chapterTitle;/// The chapter's address, which is what the reader opens.
 String get chapterUrl;/// Where the match starts inside the chapter body.
 int get offsetInText;/// The text around the match, for the results list.
 String get excerpt;
/// Create a copy of BookSearchHit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSearchHitCopyWith<BookSearchHit> get copyWith => _$BookSearchHitCopyWithImpl<BookSearchHit>(this as BookSearchHit, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookSearchHit;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSearchHit&&(identical(other.chapterIndex, _this.chapterIndex) || other.chapterIndex == _this.chapterIndex)&&(identical(other.chapterTitle, _this.chapterTitle) || other.chapterTitle == _this.chapterTitle)&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.offsetInText, _this.offsetInText) || other.offsetInText == _this.offsetInText)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt));
}


@override
int get hashCode {
  final _this = this as BookSearchHit;
  return Object.hash(runtimeType,_this.chapterIndex,_this.chapterTitle,_this.chapterUrl,_this.offsetInText,_this.excerpt);
}

@override
String toString() {
  final _this = this as BookSearchHit;
  return 'BookSearchHit(chapterIndex: ${_this.chapterIndex}, chapterTitle: ${_this.chapterTitle}, chapterUrl: ${_this.chapterUrl}, offsetInText: ${_this.offsetInText}, excerpt: ${_this.excerpt})';
}


}

/// @nodoc
abstract mixin class $BookSearchHitCopyWith<$Res>  {
  factory $BookSearchHitCopyWith(BookSearchHit value, $Res Function(BookSearchHit) _then) = _$BookSearchHitCopyWithImpl;
@useResult
$Res call({
 int chapterIndex, String chapterTitle, String chapterUrl, int offsetInText, String excerpt
});




}
/// @nodoc
class _$BookSearchHitCopyWithImpl<$Res>
    implements $BookSearchHitCopyWith<$Res> {
  _$BookSearchHitCopyWithImpl(this._self, this._then);

  final BookSearchHit _self;
  final $Res Function(BookSearchHit) _then;

/// Create a copy of BookSearchHit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapterIndex = null,Object? chapterTitle = null,Object? chapterUrl = null,Object? offsetInText = null,Object? excerpt = null,}) {
  return _then(BookSearchHit(
chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,chapterTitle: null == chapterTitle ? _self.chapterTitle : chapterTitle // ignore: cast_nullable_to_non_nullable
as String,chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,offsetInText: null == offsetInText ? _self.offsetInText : offsetInText // ignore: cast_nullable_to_non_nullable
as int,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BookSearchHit].
extension BookSearchHitPatterns on BookSearchHit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookSearchHit value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookSearchHit() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookSearchHit value)  $default,){
final _that = this;
switch (_that) {
case _BookSearchHit():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookSearchHit value)?  $default,){
final _that = this;
switch (_that) {
case _BookSearchHit() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int chapterIndex,  String chapterTitle,  String chapterUrl,  int offsetInText,  String excerpt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookSearchHit() when $default != null:
return $default(_that.chapterIndex,_that.chapterTitle,_that.chapterUrl,_that.offsetInText,_that.excerpt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int chapterIndex,  String chapterTitle,  String chapterUrl,  int offsetInText,  String excerpt)  $default,) {final _that = this;
switch (_that) {
case _BookSearchHit():
return $default(_that.chapterIndex,_that.chapterTitle,_that.chapterUrl,_that.offsetInText,_that.excerpt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int chapterIndex,  String chapterTitle,  String chapterUrl,  int offsetInText,  String excerpt)?  $default,) {final _that = this;
switch (_that) {
case _BookSearchHit() when $default != null:
return $default(_that.chapterIndex,_that.chapterTitle,_that.chapterUrl,_that.offsetInText,_that.excerpt);case _:
  return null;

}
}

}

/// @nodoc


class _BookSearchHit implements BookSearchHit {
  const _BookSearchHit({required this.chapterIndex, required this.chapterTitle, required this.chapterUrl, required this.offsetInText, required this.excerpt});
  

/// Index of the chapter in the book's list.
@override final  int chapterIndex;
/// The chapter's title, so the results list is readable without the chapter list.
@override final  String chapterTitle;
/// The chapter's address, which is what the reader opens.
@override final  String chapterUrl;
/// Where the match starts inside the chapter body.
@override final  int offsetInText;
/// The text around the match, for the results list.
@override final  String excerpt;

/// Create a copy of BookSearchHit
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookSearchHitCopyWith<_BookSearchHit> get copyWith => __$BookSearchHitCopyWithImpl<_BookSearchHit>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookSearchHit&&(identical(other.chapterIndex, chapterIndex) || other.chapterIndex == chapterIndex)&&(identical(other.chapterTitle, chapterTitle) || other.chapterTitle == chapterTitle)&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.offsetInText, offsetInText) || other.offsetInText == offsetInText)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,chapterIndex,chapterTitle,chapterUrl,offsetInText,excerpt);
}

@override
String toString() {
    return 'BookSearchHit(chapterIndex: $chapterIndex, chapterTitle: $chapterTitle, chapterUrl: $chapterUrl, offsetInText: $offsetInText, excerpt: $excerpt)';
}


}

/// @nodoc
abstract mixin class _$BookSearchHitCopyWith<$Res> implements $BookSearchHitCopyWith<$Res> {
  factory _$BookSearchHitCopyWith(_BookSearchHit value, $Res Function(_BookSearchHit) _then) = __$BookSearchHitCopyWithImpl;
@override @useResult
$Res call({
 int chapterIndex, String chapterTitle, String chapterUrl, int offsetInText, String excerpt
});




}
/// @nodoc
class __$BookSearchHitCopyWithImpl<$Res>
    implements _$BookSearchHitCopyWith<$Res> {
  __$BookSearchHitCopyWithImpl(this._self, this._then);

  final _BookSearchHit _self;
  final $Res Function(_BookSearchHit) _then;

/// Create a copy of BookSearchHit
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chapterIndex = null,Object? chapterTitle = null,Object? chapterUrl = null,Object? offsetInText = null,Object? excerpt = null,}) {
  return _then(_BookSearchHit(
chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,chapterTitle: null == chapterTitle ? _self.chapterTitle : chapterTitle // ignore: cast_nullable_to_non_nullable
as String,chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,offsetInText: null == offsetInText ? _self.offsetInText : offsetInText // ignore: cast_nullable_to_non_nullable
as int,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$BookSearchProgress {

/// Every hit found so far, in chapter order.
 List<BookSearchHit> get hits;/// How many chapters were read (successfully or not).
 int get scannedChapters;/// How many chapters the run intends to read.
 int get totalChapters;/// How many chapters could not be read; their absence is not a silent "no match".
 int get failedChapters;/// Whether the run is over, and why.
 BookSearchStop get stop;
/// Create a copy of BookSearchProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSearchProgressCopyWith<BookSearchProgress> get copyWith => _$BookSearchProgressCopyWithImpl<BookSearchProgress>(this as BookSearchProgress, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookSearchProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSearchProgress&&const DeepCollectionEquality().equals(other.hits, _this.hits)&&(identical(other.scannedChapters, _this.scannedChapters) || other.scannedChapters == _this.scannedChapters)&&(identical(other.totalChapters, _this.totalChapters) || other.totalChapters == _this.totalChapters)&&(identical(other.failedChapters, _this.failedChapters) || other.failedChapters == _this.failedChapters)&&(identical(other.stop, _this.stop) || other.stop == _this.stop));
}


@override
int get hashCode {
  final _this = this as BookSearchProgress;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.hits),_this.scannedChapters,_this.totalChapters,_this.failedChapters,_this.stop);
}

@override
String toString() {
  final _this = this as BookSearchProgress;
  return 'BookSearchProgress(hits: ${_this.hits}, scannedChapters: ${_this.scannedChapters}, totalChapters: ${_this.totalChapters}, failedChapters: ${_this.failedChapters}, stop: ${_this.stop})';
}


}

/// @nodoc
abstract mixin class $BookSearchProgressCopyWith<$Res>  {
  factory $BookSearchProgressCopyWith(BookSearchProgress value, $Res Function(BookSearchProgress) _then) = _$BookSearchProgressCopyWithImpl;
@useResult
$Res call({
 List<BookSearchHit> hits, int scannedChapters, int totalChapters, int failedChapters, BookSearchStop stop
});




}
/// @nodoc
class _$BookSearchProgressCopyWithImpl<$Res>
    implements $BookSearchProgressCopyWith<$Res> {
  _$BookSearchProgressCopyWithImpl(this._self, this._then);

  final BookSearchProgress _self;
  final $Res Function(BookSearchProgress) _then;

/// Create a copy of BookSearchProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hits = null,Object? scannedChapters = null,Object? totalChapters = null,Object? failedChapters = null,Object? stop = null,}) {
  return _then(BookSearchProgress(
hits: null == hits ? _self.hits : hits // ignore: cast_nullable_to_non_nullable
as List<BookSearchHit>,scannedChapters: null == scannedChapters ? _self.scannedChapters : scannedChapters // ignore: cast_nullable_to_non_nullable
as int,totalChapters: null == totalChapters ? _self.totalChapters : totalChapters // ignore: cast_nullable_to_non_nullable
as int,failedChapters: null == failedChapters ? _self.failedChapters : failedChapters // ignore: cast_nullable_to_non_nullable
as int,stop: null == stop ? _self.stop : stop // ignore: cast_nullable_to_non_nullable
as BookSearchStop,
  ));
}

}


/// Adds pattern-matching-related methods to [BookSearchProgress].
extension BookSearchProgressPatterns on BookSearchProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookSearchProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookSearchProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookSearchProgress value)  $default,){
final _that = this;
switch (_that) {
case _BookSearchProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookSearchProgress value)?  $default,){
final _that = this;
switch (_that) {
case _BookSearchProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<BookSearchHit> hits,  int scannedChapters,  int totalChapters,  int failedChapters,  BookSearchStop stop)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookSearchProgress() when $default != null:
return $default(_that.hits,_that.scannedChapters,_that.totalChapters,_that.failedChapters,_that.stop);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<BookSearchHit> hits,  int scannedChapters,  int totalChapters,  int failedChapters,  BookSearchStop stop)  $default,) {final _that = this;
switch (_that) {
case _BookSearchProgress():
return $default(_that.hits,_that.scannedChapters,_that.totalChapters,_that.failedChapters,_that.stop);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<BookSearchHit> hits,  int scannedChapters,  int totalChapters,  int failedChapters,  BookSearchStop stop)?  $default,) {final _that = this;
switch (_that) {
case _BookSearchProgress() when $default != null:
return $default(_that.hits,_that.scannedChapters,_that.totalChapters,_that.failedChapters,_that.stop);case _:
  return null;

}
}

}

/// @nodoc


class _BookSearchProgress extends BookSearchProgress {
  const _BookSearchProgress({required  List<BookSearchHit> hits, required this.scannedChapters, required this.totalChapters, this.failedChapters = 0, this.stop = BookSearchStop.running}): _hits = hits,super._();
  

/// Every hit found so far, in chapter order.
 final  List<BookSearchHit> _hits;
/// Every hit found so far, in chapter order.
@override List<BookSearchHit> get hits {
  if (_hits is EqualUnmodifiableListView) return _hits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hits);
}

/// How many chapters were read (successfully or not).
@override final  int scannedChapters;
/// How many chapters the run intends to read.
@override final  int totalChapters;
/// How many chapters could not be read; their absence is not a silent "no match".
@override@JsonKey() final  int failedChapters;
/// Whether the run is over, and why.
@override@JsonKey() final  BookSearchStop stop;

/// Create a copy of BookSearchProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookSearchProgressCopyWith<_BookSearchProgress> get copyWith => __$BookSearchProgressCopyWithImpl<_BookSearchProgress>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookSearchProgress&&const DeepCollectionEquality().equals(other.hits, _hits)&&(identical(other.scannedChapters, scannedChapters) || other.scannedChapters == scannedChapters)&&(identical(other.totalChapters, totalChapters) || other.totalChapters == totalChapters)&&(identical(other.failedChapters, failedChapters) || other.failedChapters == failedChapters)&&(identical(other.stop, stop) || other.stop == stop));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_hits),scannedChapters,totalChapters,failedChapters,stop);
}

@override
String toString() {
    return 'BookSearchProgress(hits: $hits, scannedChapters: $scannedChapters, totalChapters: $totalChapters, failedChapters: $failedChapters, stop: $stop)';
}


}

/// @nodoc
abstract mixin class _$BookSearchProgressCopyWith<$Res> implements $BookSearchProgressCopyWith<$Res> {
  factory _$BookSearchProgressCopyWith(_BookSearchProgress value, $Res Function(_BookSearchProgress) _then) = __$BookSearchProgressCopyWithImpl;
@override @useResult
$Res call({
 List<BookSearchHit> hits, int scannedChapters, int totalChapters, int failedChapters, BookSearchStop stop
});




}
/// @nodoc
class __$BookSearchProgressCopyWithImpl<$Res>
    implements _$BookSearchProgressCopyWith<$Res> {
  __$BookSearchProgressCopyWithImpl(this._self, this._then);

  final _BookSearchProgress _self;
  final $Res Function(_BookSearchProgress) _then;

/// Create a copy of BookSearchProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hits = null,Object? scannedChapters = null,Object? totalChapters = null,Object? failedChapters = null,Object? stop = null,}) {
  return _then(_BookSearchProgress(
hits: null == hits ? _self._hits : hits // ignore: cast_nullable_to_non_nullable
as List<BookSearchHit>,scannedChapters: null == scannedChapters ? _self.scannedChapters : scannedChapters // ignore: cast_nullable_to_non_nullable
as int,totalChapters: null == totalChapters ? _self.totalChapters : totalChapters // ignore: cast_nullable_to_non_nullable
as int,failedChapters: null == failedChapters ? _self.failedChapters : failedChapters // ignore: cast_nullable_to_non_nullable
as int,stop: null == stop ? _self.stop : stop // ignore: cast_nullable_to_non_nullable
as BookSearchStop,
  ));
}


}

// dart format on
