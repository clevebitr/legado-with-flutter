// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'explore_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExploreState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExploreState()';
}


}

/// @nodoc
class $ExploreStateCopyWith<$Res>  {
$ExploreStateCopyWith(ExploreState _, $Res Function(ExploreState) __);
}


/// Adds pattern-matching-related methods to [ExploreState].
extension ExploreStatePatterns on ExploreState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ExploreIdle value)?  idle,TResult Function( ExploreCategories value)?  categories,TResult Function( ExploreCategoriesFailed value)?  failedCategories,TResult Function( ExploreLoadingBooks value)?  loadingBooks,TResult Function( ExploreBooksLoaded value)?  books,TResult Function( ExploreBooksFailed value)?  failedBooks,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ExploreIdle() when idle != null:
return idle(_that);case ExploreCategories() when categories != null:
return categories(_that);case ExploreCategoriesFailed() when failedCategories != null:
return failedCategories(_that);case ExploreLoadingBooks() when loadingBooks != null:
return loadingBooks(_that);case ExploreBooksLoaded() when books != null:
return books(_that);case ExploreBooksFailed() when failedBooks != null:
return failedBooks(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ExploreIdle value)  idle,required TResult Function( ExploreCategories value)  categories,required TResult Function( ExploreCategoriesFailed value)  failedCategories,required TResult Function( ExploreLoadingBooks value)  loadingBooks,required TResult Function( ExploreBooksLoaded value)  books,required TResult Function( ExploreBooksFailed value)  failedBooks,}){
final _that = this;
switch (_that) {
case ExploreIdle():
return idle(_that);case ExploreCategories():
return categories(_that);case ExploreCategoriesFailed():
return failedCategories(_that);case ExploreLoadingBooks():
return loadingBooks(_that);case ExploreBooksLoaded():
return books(_that);case ExploreBooksFailed():
return failedBooks(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ExploreIdle value)?  idle,TResult? Function( ExploreCategories value)?  categories,TResult? Function( ExploreCategoriesFailed value)?  failedCategories,TResult? Function( ExploreLoadingBooks value)?  loadingBooks,TResult? Function( ExploreBooksLoaded value)?  books,TResult? Function( ExploreBooksFailed value)?  failedBooks,}){
final _that = this;
switch (_that) {
case ExploreIdle() when idle != null:
return idle(_that);case ExploreCategories() when categories != null:
return categories(_that);case ExploreCategoriesFailed() when failedCategories != null:
return failedCategories(_that);case ExploreLoadingBooks() when loadingBooks != null:
return loadingBooks(_that);case ExploreBooksLoaded() when books != null:
return books(_that);case ExploreBooksFailed() when failedBooks != null:
return failedBooks(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( List<ExploreCategory> categories)?  categories,TResult Function( ParseFailureKind kind)?  failedCategories,TResult Function( List<ExploreCategory> categories,  ExploreCategory category)?  loadingBooks,TResult Function( List<ExploreCategory> categories,  ExploreCategory category,  List<Book> books)?  books,TResult Function( List<ExploreCategory> categories,  ExploreCategory category,  ParseFailureKind kind)?  failedBooks,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ExploreIdle() when idle != null:
return idle();case ExploreCategories() when categories != null:
return categories(_that.categories);case ExploreCategoriesFailed() when failedCategories != null:
return failedCategories(_that.kind);case ExploreLoadingBooks() when loadingBooks != null:
return loadingBooks(_that.categories,_that.category);case ExploreBooksLoaded() when books != null:
return books(_that.categories,_that.category,_that.books);case ExploreBooksFailed() when failedBooks != null:
return failedBooks(_that.categories,_that.category,_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( List<ExploreCategory> categories)  categories,required TResult Function( ParseFailureKind kind)  failedCategories,required TResult Function( List<ExploreCategory> categories,  ExploreCategory category)  loadingBooks,required TResult Function( List<ExploreCategory> categories,  ExploreCategory category,  List<Book> books)  books,required TResult Function( List<ExploreCategory> categories,  ExploreCategory category,  ParseFailureKind kind)  failedBooks,}) {final _that = this;
switch (_that) {
case ExploreIdle():
return idle();case ExploreCategories():
return categories(_that.categories);case ExploreCategoriesFailed():
return failedCategories(_that.kind);case ExploreLoadingBooks():
return loadingBooks(_that.categories,_that.category);case ExploreBooksLoaded():
return books(_that.categories,_that.category,_that.books);case ExploreBooksFailed():
return failedBooks(_that.categories,_that.category,_that.kind);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( List<ExploreCategory> categories)?  categories,TResult? Function( ParseFailureKind kind)?  failedCategories,TResult? Function( List<ExploreCategory> categories,  ExploreCategory category)?  loadingBooks,TResult? Function( List<ExploreCategory> categories,  ExploreCategory category,  List<Book> books)?  books,TResult? Function( List<ExploreCategory> categories,  ExploreCategory category,  ParseFailureKind kind)?  failedBooks,}) {final _that = this;
switch (_that) {
case ExploreIdle() when idle != null:
return idle();case ExploreCategories() when categories != null:
return categories(_that.categories);case ExploreCategoriesFailed() when failedCategories != null:
return failedCategories(_that.kind);case ExploreLoadingBooks() when loadingBooks != null:
return loadingBooks(_that.categories,_that.category);case ExploreBooksLoaded() when books != null:
return books(_that.categories,_that.category,_that.books);case ExploreBooksFailed() when failedBooks != null:
return failedBooks(_that.categories,_that.category,_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class ExploreIdle implements ExploreState {
  const ExploreIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExploreState.idle()';
}


}




/// @nodoc


class ExploreCategories implements ExploreState {
  const ExploreCategories( List<ExploreCategory> categories): _categories = categories;
  

 final  List<ExploreCategory> _categories;
 List<ExploreCategory> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}


/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExploreCategoriesCopyWith<ExploreCategories> get copyWith => _$ExploreCategoriesCopyWithImpl<ExploreCategories>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreCategories&&const DeepCollectionEquality().equals(other.categories, _categories));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_categories));
}

@override
String toString() {
    return 'ExploreState.categories(categories: $categories)';
}


}

/// @nodoc
abstract mixin class $ExploreCategoriesCopyWith<$Res> implements $ExploreStateCopyWith<$Res> {
  factory $ExploreCategoriesCopyWith(ExploreCategories value, $Res Function(ExploreCategories) _then) = _$ExploreCategoriesCopyWithImpl;
@useResult
$Res call({
 List<ExploreCategory> categories
});




}
/// @nodoc
class _$ExploreCategoriesCopyWithImpl<$Res>
    implements $ExploreCategoriesCopyWith<$Res> {
  _$ExploreCategoriesCopyWithImpl(this._self, this._then);

  final ExploreCategories _self;
  final $Res Function(ExploreCategories) _then;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? categories = null,}) {
  return _then(ExploreCategories(
null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<ExploreCategory>,
  ));
}


}

/// @nodoc


class ExploreCategoriesFailed implements ExploreState {
  const ExploreCategoriesFailed(this.kind);
  

 final  ParseFailureKind kind;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExploreCategoriesFailedCopyWith<ExploreCategoriesFailed> get copyWith => _$ExploreCategoriesFailedCopyWithImpl<ExploreCategoriesFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreCategoriesFailed&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind);
}

@override
String toString() {
    return 'ExploreState.failedCategories(kind: $kind)';
}


}

/// @nodoc
abstract mixin class $ExploreCategoriesFailedCopyWith<$Res> implements $ExploreStateCopyWith<$Res> {
  factory $ExploreCategoriesFailedCopyWith(ExploreCategoriesFailed value, $Res Function(ExploreCategoriesFailed) _then) = _$ExploreCategoriesFailedCopyWithImpl;
@useResult
$Res call({
 ParseFailureKind kind
});




}
/// @nodoc
class _$ExploreCategoriesFailedCopyWithImpl<$Res>
    implements $ExploreCategoriesFailedCopyWith<$Res> {
  _$ExploreCategoriesFailedCopyWithImpl(this._self, this._then);

  final ExploreCategoriesFailed _self;
  final $Res Function(ExploreCategoriesFailed) _then;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,}) {
  return _then(ExploreCategoriesFailed(
null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind,
  ));
}


}

/// @nodoc


class ExploreLoadingBooks implements ExploreState {
  const ExploreLoadingBooks( List<ExploreCategory> categories, this.category): _categories = categories;
  

 final  List<ExploreCategory> _categories;
 List<ExploreCategory> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  ExploreCategory category;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExploreLoadingBooksCopyWith<ExploreLoadingBooks> get copyWith => _$ExploreLoadingBooksCopyWithImpl<ExploreLoadingBooks>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreLoadingBooks&&const DeepCollectionEquality().equals(other.categories, _categories)&&(identical(other.category, category) || other.category == category));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_categories),category);
}

@override
String toString() {
    return 'ExploreState.loadingBooks(categories: $categories, category: $category)';
}


}

/// @nodoc
abstract mixin class $ExploreLoadingBooksCopyWith<$Res> implements $ExploreStateCopyWith<$Res> {
  factory $ExploreLoadingBooksCopyWith(ExploreLoadingBooks value, $Res Function(ExploreLoadingBooks) _then) = _$ExploreLoadingBooksCopyWithImpl;
@useResult
$Res call({
 List<ExploreCategory> categories, ExploreCategory category
});


$ExploreCategoryCopyWith<$Res> get category;

}
/// @nodoc
class _$ExploreLoadingBooksCopyWithImpl<$Res>
    implements $ExploreLoadingBooksCopyWith<$Res> {
  _$ExploreLoadingBooksCopyWithImpl(this._self, this._then);

  final ExploreLoadingBooks _self;
  final $Res Function(ExploreLoadingBooks) _then;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? categories = null,Object? category = null,}) {
  return _then(ExploreLoadingBooks(
null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<ExploreCategory>,null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as ExploreCategory,
  ));
}

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExploreCategoryCopyWith<$Res> get category {
  
  return $ExploreCategoryCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}
}

/// @nodoc


class ExploreBooksLoaded implements ExploreState {
  const ExploreBooksLoaded( List<ExploreCategory> categories, this.category,  List<Book> books): _categories = categories,_books = books;
  

 final  List<ExploreCategory> _categories;
 List<ExploreCategory> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  ExploreCategory category;
 final  List<Book> _books;
 List<Book> get books {
  if (_books is EqualUnmodifiableListView) return _books;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_books);
}


/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExploreBooksLoadedCopyWith<ExploreBooksLoaded> get copyWith => _$ExploreBooksLoadedCopyWithImpl<ExploreBooksLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreBooksLoaded&&const DeepCollectionEquality().equals(other.categories, _categories)&&(identical(other.category, category) || other.category == category)&&const DeepCollectionEquality().equals(other.books, _books));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_categories),category,const DeepCollectionEquality().hash(_books));
}

@override
String toString() {
    return 'ExploreState.books(categories: $categories, category: $category, books: $books)';
}


}

/// @nodoc
abstract mixin class $ExploreBooksLoadedCopyWith<$Res> implements $ExploreStateCopyWith<$Res> {
  factory $ExploreBooksLoadedCopyWith(ExploreBooksLoaded value, $Res Function(ExploreBooksLoaded) _then) = _$ExploreBooksLoadedCopyWithImpl;
@useResult
$Res call({
 List<ExploreCategory> categories, ExploreCategory category, List<Book> books
});


$ExploreCategoryCopyWith<$Res> get category;

}
/// @nodoc
class _$ExploreBooksLoadedCopyWithImpl<$Res>
    implements $ExploreBooksLoadedCopyWith<$Res> {
  _$ExploreBooksLoadedCopyWithImpl(this._self, this._then);

  final ExploreBooksLoaded _self;
  final $Res Function(ExploreBooksLoaded) _then;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? categories = null,Object? category = null,Object? books = null,}) {
  return _then(ExploreBooksLoaded(
null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<ExploreCategory>,null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as ExploreCategory,null == books ? _self._books : books // ignore: cast_nullable_to_non_nullable
as List<Book>,
  ));
}

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExploreCategoryCopyWith<$Res> get category {
  
  return $ExploreCategoryCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}
}

/// @nodoc


class ExploreBooksFailed implements ExploreState {
  const ExploreBooksFailed( List<ExploreCategory> categories, this.category, this.kind): _categories = categories;
  

 final  List<ExploreCategory> _categories;
 List<ExploreCategory> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  ExploreCategory category;
 final  ParseFailureKind kind;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExploreBooksFailedCopyWith<ExploreBooksFailed> get copyWith => _$ExploreBooksFailedCopyWithImpl<ExploreBooksFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreBooksFailed&&const DeepCollectionEquality().equals(other.categories, _categories)&&(identical(other.category, category) || other.category == category)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_categories),category,kind);
}

@override
String toString() {
    return 'ExploreState.failedBooks(categories: $categories, category: $category, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $ExploreBooksFailedCopyWith<$Res> implements $ExploreStateCopyWith<$Res> {
  factory $ExploreBooksFailedCopyWith(ExploreBooksFailed value, $Res Function(ExploreBooksFailed) _then) = _$ExploreBooksFailedCopyWithImpl;
@useResult
$Res call({
 List<ExploreCategory> categories, ExploreCategory category, ParseFailureKind kind
});


$ExploreCategoryCopyWith<$Res> get category;

}
/// @nodoc
class _$ExploreBooksFailedCopyWithImpl<$Res>
    implements $ExploreBooksFailedCopyWith<$Res> {
  _$ExploreBooksFailedCopyWithImpl(this._self, this._then);

  final ExploreBooksFailed _self;
  final $Res Function(ExploreBooksFailed) _then;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? categories = null,Object? category = null,Object? kind = null,}) {
  return _then(ExploreBooksFailed(
null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<ExploreCategory>,null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as ExploreCategory,null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind,
  ));
}

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExploreCategoryCopyWith<$Res> get category {
  
  return $ExploreCategoryCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}
}

// dart format on
