// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_route.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReaderRoute {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ReaderRoute()';
}


}

/// @nodoc
class $ReaderRouteCopyWith<$Res>  {
$ReaderRouteCopyWith(ReaderRoute _, $Res Function(ReaderRoute) __);
}


/// Adds pattern-matching-related methods to [ReaderRoute].
extension ReaderRoutePatterns on ReaderRoute {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ReaderReadRoute value)?  read,TResult Function( ReaderBookmarksRoute value)?  bookmarks,TResult Function( ReaderRecordsRoute value)?  records,TResult Function( ReaderBookRecordsRoute value)?  bookRecords,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ReaderReadRoute() when read != null:
return read(_that);case ReaderBookmarksRoute() when bookmarks != null:
return bookmarks(_that);case ReaderRecordsRoute() when records != null:
return records(_that);case ReaderBookRecordsRoute() when bookRecords != null:
return bookRecords(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ReaderReadRoute value)  read,required TResult Function( ReaderBookmarksRoute value)  bookmarks,required TResult Function( ReaderRecordsRoute value)  records,required TResult Function( ReaderBookRecordsRoute value)  bookRecords,}){
final _that = this;
switch (_that) {
case ReaderReadRoute():
return read(_that);case ReaderBookmarksRoute():
return bookmarks(_that);case ReaderRecordsRoute():
return records(_that);case ReaderBookRecordsRoute():
return bookRecords(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ReaderReadRoute value)?  read,TResult? Function( ReaderBookmarksRoute value)?  bookmarks,TResult? Function( ReaderRecordsRoute value)?  records,TResult? Function( ReaderBookRecordsRoute value)?  bookRecords,}){
final _that = this;
switch (_that) {
case ReaderReadRoute() when read != null:
return read(_that);case ReaderBookmarksRoute() when bookmarks != null:
return bookmarks(_that);case ReaderRecordsRoute() when records != null:
return records(_that);case ReaderBookRecordsRoute() when bookRecords != null:
return bookRecords(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( ReaderBook book,  String? chapterUrl,  int charOffset)?  read,TResult Function()?  bookmarks,TResult Function()?  records,TResult Function( String sourceUrl,  String bookUrl,  String bookName)?  bookRecords,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ReaderReadRoute() when read != null:
return read(_that.book,_that.chapterUrl,_that.charOffset);case ReaderBookmarksRoute() when bookmarks != null:
return bookmarks();case ReaderRecordsRoute() when records != null:
return records();case ReaderBookRecordsRoute() when bookRecords != null:
return bookRecords(_that.sourceUrl,_that.bookUrl,_that.bookName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( ReaderBook book,  String? chapterUrl,  int charOffset)  read,required TResult Function()  bookmarks,required TResult Function()  records,required TResult Function( String sourceUrl,  String bookUrl,  String bookName)  bookRecords,}) {final _that = this;
switch (_that) {
case ReaderReadRoute():
return read(_that.book,_that.chapterUrl,_that.charOffset);case ReaderBookmarksRoute():
return bookmarks();case ReaderRecordsRoute():
return records();case ReaderBookRecordsRoute():
return bookRecords(_that.sourceUrl,_that.bookUrl,_that.bookName);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( ReaderBook book,  String? chapterUrl,  int charOffset)?  read,TResult? Function()?  bookmarks,TResult? Function()?  records,TResult? Function( String sourceUrl,  String bookUrl,  String bookName)?  bookRecords,}) {final _that = this;
switch (_that) {
case ReaderReadRoute() when read != null:
return read(_that.book,_that.chapterUrl,_that.charOffset);case ReaderBookmarksRoute() when bookmarks != null:
return bookmarks();case ReaderRecordsRoute() when records != null:
return records();case ReaderBookRecordsRoute() when bookRecords != null:
return bookRecords(_that.sourceUrl,_that.bookUrl,_that.bookName);case _:
  return null;

}
}

}

/// @nodoc


class ReaderReadRoute extends ReaderRoute {
  const ReaderReadRoute({required this.book, this.chapterUrl, this.charOffset = 0}): super._();
  

 final  ReaderBook book;
 final  String? chapterUrl;
@JsonKey() final  int charOffset;

/// Create a copy of ReaderRoute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderReadRouteCopyWith<ReaderReadRoute> get copyWith => _$ReaderReadRouteCopyWithImpl<ReaderReadRoute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderReadRoute&&(identical(other.book, book) || other.book == book)&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.charOffset, charOffset) || other.charOffset == charOffset));
}


@override
int get hashCode {
    return Object.hash(runtimeType,book,chapterUrl,charOffset);
}

@override
String toString() {
    return 'ReaderRoute.read(book: $book, chapterUrl: $chapterUrl, charOffset: $charOffset)';
}


}

/// @nodoc
abstract mixin class $ReaderReadRouteCopyWith<$Res> implements $ReaderRouteCopyWith<$Res> {
  factory $ReaderReadRouteCopyWith(ReaderReadRoute value, $Res Function(ReaderReadRoute) _then) = _$ReaderReadRouteCopyWithImpl;
@useResult
$Res call({
 ReaderBook book, String? chapterUrl, int charOffset
});


$ReaderBookCopyWith<$Res> get book;

}
/// @nodoc
class _$ReaderReadRouteCopyWithImpl<$Res>
    implements $ReaderReadRouteCopyWith<$Res> {
  _$ReaderReadRouteCopyWithImpl(this._self, this._then);

  final ReaderReadRoute _self;
  final $Res Function(ReaderReadRoute) _then;

/// Create a copy of ReaderRoute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? book = null,Object? chapterUrl = freezed,Object? charOffset = null,}) {
  return _then(ReaderReadRoute(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as ReaderBook,chapterUrl: freezed == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String?,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ReaderRoute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReaderBookCopyWith<$Res> get book {
  
  return $ReaderBookCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}

/// @nodoc


class ReaderBookmarksRoute extends ReaderRoute {
  const ReaderBookmarksRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderBookmarksRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ReaderRoute.bookmarks()';
}


}




/// @nodoc


class ReaderRecordsRoute extends ReaderRoute {
  const ReaderRecordsRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderRecordsRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ReaderRoute.records()';
}


}




/// @nodoc


class ReaderBookRecordsRoute extends ReaderRoute {
  const ReaderBookRecordsRoute({required this.sourceUrl, required this.bookUrl, required this.bookName}): super._();
  

 final  String sourceUrl;
 final  String bookUrl;
 final  String bookName;

/// Create a copy of ReaderRoute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderBookRecordsRouteCopyWith<ReaderBookRecordsRoute> get copyWith => _$ReaderBookRecordsRouteCopyWithImpl<ReaderBookRecordsRoute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderBookRecordsRoute&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.bookName, bookName) || other.bookName == bookName));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceUrl,bookUrl,bookName);
}

@override
String toString() {
    return 'ReaderRoute.bookRecords(sourceUrl: $sourceUrl, bookUrl: $bookUrl, bookName: $bookName)';
}


}

/// @nodoc
abstract mixin class $ReaderBookRecordsRouteCopyWith<$Res> implements $ReaderRouteCopyWith<$Res> {
  factory $ReaderBookRecordsRouteCopyWith(ReaderBookRecordsRoute value, $Res Function(ReaderBookRecordsRoute) _then) = _$ReaderBookRecordsRouteCopyWithImpl;
@useResult
$Res call({
 String sourceUrl, String bookUrl, String bookName
});




}
/// @nodoc
class _$ReaderBookRecordsRouteCopyWithImpl<$Res>
    implements $ReaderBookRecordsRouteCopyWith<$Res> {
  _$ReaderBookRecordsRouteCopyWithImpl(this._self, this._then);

  final ReaderBookRecordsRoute _self;
  final $Res Function(ReaderBookRecordsRoute) _then;

/// Create a copy of ReaderRoute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,}) {
  return _then(ReaderBookRecordsRoute(
sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
