// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_source_route.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookSourceRoute {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceRoute()';
}


}

/// @nodoc
class $BookSourceRouteCopyWith<$Res>  {
$BookSourceRouteCopyWith(BookSourceRoute _, $Res Function(BookSourceRoute) __);
}


/// Adds pattern-matching-related methods to [BookSourceRoute].
extension BookSourceRoutePatterns on BookSourceRoute {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BookDetailRoute value)?  bookDetail,TResult Function( ExploreRoute value)?  explore,TResult Function( BookSourceListRoute value)?  importedSources,TResult Function( BookSourceImportRoute value)?  importSources,TResult Function( ReaderRoute value)?  reader,TResult Function( BookSourceCheckRoute value)?  checkSources,TResult Function( BookSourceDebugRoute value)?  debugSource,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BookDetailRoute() when bookDetail != null:
return bookDetail(_that);case ExploreRoute() when explore != null:
return explore(_that);case BookSourceListRoute() when importedSources != null:
return importedSources(_that);case BookSourceImportRoute() when importSources != null:
return importSources(_that);case ReaderRoute() when reader != null:
return reader(_that);case BookSourceCheckRoute() when checkSources != null:
return checkSources(_that);case BookSourceDebugRoute() when debugSource != null:
return debugSource(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BookDetailRoute value)  bookDetail,required TResult Function( ExploreRoute value)  explore,required TResult Function( BookSourceListRoute value)  importedSources,required TResult Function( BookSourceImportRoute value)  importSources,required TResult Function( ReaderRoute value)  reader,required TResult Function( BookSourceCheckRoute value)  checkSources,required TResult Function( BookSourceDebugRoute value)  debugSource,}){
final _that = this;
switch (_that) {
case BookDetailRoute():
return bookDetail(_that);case ExploreRoute():
return explore(_that);case BookSourceListRoute():
return importedSources(_that);case BookSourceImportRoute():
return importSources(_that);case ReaderRoute():
return reader(_that);case BookSourceCheckRoute():
return checkSources(_that);case BookSourceDebugRoute():
return debugSource(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BookDetailRoute value)?  bookDetail,TResult? Function( ExploreRoute value)?  explore,TResult? Function( BookSourceListRoute value)?  importedSources,TResult? Function( BookSourceImportRoute value)?  importSources,TResult? Function( ReaderRoute value)?  reader,TResult? Function( BookSourceCheckRoute value)?  checkSources,TResult? Function( BookSourceDebugRoute value)?  debugSource,}){
final _that = this;
switch (_that) {
case BookDetailRoute() when bookDetail != null:
return bookDetail(_that);case ExploreRoute() when explore != null:
return explore(_that);case BookSourceListRoute() when importedSources != null:
return importedSources(_that);case BookSourceImportRoute() when importSources != null:
return importSources(_that);case ReaderRoute() when reader != null:
return reader(_that);case BookSourceCheckRoute() when checkSources != null:
return checkSources(_that);case BookSourceDebugRoute() when debugSource != null:
return debugSource(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Book book)?  bookDetail,TResult Function()?  explore,TResult Function()?  importedSources,TResult Function()?  importSources,TResult Function( Chapter chapter)?  reader,TResult Function()?  checkSources,TResult Function( int? sourceId)?  debugSource,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BookDetailRoute() when bookDetail != null:
return bookDetail(_that.book);case ExploreRoute() when explore != null:
return explore();case BookSourceListRoute() when importedSources != null:
return importedSources();case BookSourceImportRoute() when importSources != null:
return importSources();case ReaderRoute() when reader != null:
return reader(_that.chapter);case BookSourceCheckRoute() when checkSources != null:
return checkSources();case BookSourceDebugRoute() when debugSource != null:
return debugSource(_that.sourceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Book book)  bookDetail,required TResult Function()  explore,required TResult Function()  importedSources,required TResult Function()  importSources,required TResult Function( Chapter chapter)  reader,required TResult Function()  checkSources,required TResult Function( int? sourceId)  debugSource,}) {final _that = this;
switch (_that) {
case BookDetailRoute():
return bookDetail(_that.book);case ExploreRoute():
return explore();case BookSourceListRoute():
return importedSources();case BookSourceImportRoute():
return importSources();case ReaderRoute():
return reader(_that.chapter);case BookSourceCheckRoute():
return checkSources();case BookSourceDebugRoute():
return debugSource(_that.sourceId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Book book)?  bookDetail,TResult? Function()?  explore,TResult? Function()?  importedSources,TResult? Function()?  importSources,TResult? Function( Chapter chapter)?  reader,TResult? Function()?  checkSources,TResult? Function( int? sourceId)?  debugSource,}) {final _that = this;
switch (_that) {
case BookDetailRoute() when bookDetail != null:
return bookDetail(_that.book);case ExploreRoute() when explore != null:
return explore();case BookSourceListRoute() when importedSources != null:
return importedSources();case BookSourceImportRoute() when importSources != null:
return importSources();case ReaderRoute() when reader != null:
return reader(_that.chapter);case BookSourceCheckRoute() when checkSources != null:
return checkSources();case BookSourceDebugRoute() when debugSource != null:
return debugSource(_that.sourceId);case _:
  return null;

}
}

}

/// @nodoc


class BookDetailRoute extends BookSourceRoute {
  const BookDetailRoute({required this.book}): super._();
  

 final  Book book;

/// Create a copy of BookSourceRoute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookDetailRouteCopyWith<BookDetailRoute> get copyWith => _$BookDetailRouteCopyWithImpl<BookDetailRoute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookDetailRoute&&(identical(other.book, book) || other.book == book));
}


@override
int get hashCode {
    return Object.hash(runtimeType,book);
}

@override
String toString() {
    return 'BookSourceRoute.bookDetail(book: $book)';
}


}

/// @nodoc
abstract mixin class $BookDetailRouteCopyWith<$Res> implements $BookSourceRouteCopyWith<$Res> {
  factory $BookDetailRouteCopyWith(BookDetailRoute value, $Res Function(BookDetailRoute) _then) = _$BookDetailRouteCopyWithImpl;
@useResult
$Res call({
 Book book
});


$BookCopyWith<$Res> get book;

}
/// @nodoc
class _$BookDetailRouteCopyWithImpl<$Res>
    implements $BookDetailRouteCopyWith<$Res> {
  _$BookDetailRouteCopyWithImpl(this._self, this._then);

  final BookDetailRoute _self;
  final $Res Function(BookDetailRoute) _then;

/// Create a copy of BookSourceRoute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? book = null,}) {
  return _then(BookDetailRoute(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as Book,
  ));
}

/// Create a copy of BookSourceRoute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookCopyWith<$Res> get book {
  
  return $BookCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}

/// @nodoc


class ExploreRoute extends BookSourceRoute {
  const ExploreRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceRoute.explore()';
}


}




/// @nodoc


class BookSourceListRoute extends BookSourceRoute {
  const BookSourceListRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceListRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceRoute.importedSources()';
}


}




/// @nodoc


class BookSourceImportRoute extends BookSourceRoute {
  const BookSourceImportRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImportRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceRoute.importSources()';
}


}




/// @nodoc


class ReaderRoute extends BookSourceRoute {
  const ReaderRoute({required this.chapter}): super._();
  

 final  Chapter chapter;

/// Create a copy of BookSourceRoute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderRouteCopyWith<ReaderRoute> get copyWith => _$ReaderRouteCopyWithImpl<ReaderRoute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderRoute&&(identical(other.chapter, chapter) || other.chapter == chapter));
}


@override
int get hashCode {
    return Object.hash(runtimeType,chapter);
}

@override
String toString() {
    return 'BookSourceRoute.reader(chapter: $chapter)';
}


}

/// @nodoc
abstract mixin class $ReaderRouteCopyWith<$Res> implements $BookSourceRouteCopyWith<$Res> {
  factory $ReaderRouteCopyWith(ReaderRoute value, $Res Function(ReaderRoute) _then) = _$ReaderRouteCopyWithImpl;
@useResult
$Res call({
 Chapter chapter
});


$ChapterCopyWith<$Res> get chapter;

}
/// @nodoc
class _$ReaderRouteCopyWithImpl<$Res>
    implements $ReaderRouteCopyWith<$Res> {
  _$ReaderRouteCopyWithImpl(this._self, this._then);

  final ReaderRoute _self;
  final $Res Function(ReaderRoute) _then;

/// Create a copy of BookSourceRoute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? chapter = null,}) {
  return _then(ReaderRoute(
chapter: null == chapter ? _self.chapter : chapter // ignore: cast_nullable_to_non_nullable
as Chapter,
  ));
}

/// Create a copy of BookSourceRoute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChapterCopyWith<$Res> get chapter {
  
  return $ChapterCopyWith<$Res>(_self.chapter, (value) {
    return _then(_self.copyWith(chapter: value));
  });
}
}

/// @nodoc


class BookSourceCheckRoute extends BookSourceRoute {
  const BookSourceCheckRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceCheckRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceRoute.checkSources()';
}


}




/// @nodoc


class BookSourceDebugRoute extends BookSourceRoute {
  const BookSourceDebugRoute({this.sourceId}): super._();
  

 final  int? sourceId;

/// Create a copy of BookSourceRoute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSourceDebugRouteCopyWith<BookSourceDebugRoute> get copyWith => _$BookSourceDebugRouteCopyWithImpl<BookSourceDebugRoute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceDebugRoute&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceId);
}

@override
String toString() {
    return 'BookSourceRoute.debugSource(sourceId: $sourceId)';
}


}

/// @nodoc
abstract mixin class $BookSourceDebugRouteCopyWith<$Res> implements $BookSourceRouteCopyWith<$Res> {
  factory $BookSourceDebugRouteCopyWith(BookSourceDebugRoute value, $Res Function(BookSourceDebugRoute) _then) = _$BookSourceDebugRouteCopyWithImpl;
@useResult
$Res call({
 int? sourceId
});




}
/// @nodoc
class _$BookSourceDebugRouteCopyWithImpl<$Res>
    implements $BookSourceDebugRouteCopyWith<$Res> {
  _$BookSourceDebugRouteCopyWithImpl(this._self, this._then);

  final BookSourceDebugRoute _self;
  final $Res Function(BookSourceDebugRoute) _then;

/// Create a copy of BookSourceRoute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sourceId = freezed,}) {
  return _then(BookSourceDebugRoute(
sourceId: freezed == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
