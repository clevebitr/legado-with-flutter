// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_results_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SearchResultsState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchResultsState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SearchResultsState()';
}


}

/// @nodoc
class $SearchResultsStateCopyWith<$Res>  {
$SearchResultsStateCopyWith(SearchResultsState _, $Res Function(SearchResultsState) __);
}


/// Adds pattern-matching-related methods to [SearchResultsState].
extension SearchResultsStatePatterns on SearchResultsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SearchResultsIdle value)?  idle,TResult Function( SearchResultsSearching value)?  searching,TResult Function( SearchResultsLoaded value)?  loaded,TResult Function( SearchResultsFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SearchResultsIdle() when idle != null:
return idle(_that);case SearchResultsSearching() when searching != null:
return searching(_that);case SearchResultsLoaded() when loaded != null:
return loaded(_that);case SearchResultsFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SearchResultsIdle value)  idle,required TResult Function( SearchResultsSearching value)  searching,required TResult Function( SearchResultsLoaded value)  loaded,required TResult Function( SearchResultsFailed value)  failed,}){
final _that = this;
switch (_that) {
case SearchResultsIdle():
return idle(_that);case SearchResultsSearching():
return searching(_that);case SearchResultsLoaded():
return loaded(_that);case SearchResultsFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SearchResultsIdle value)?  idle,TResult? Function( SearchResultsSearching value)?  searching,TResult? Function( SearchResultsLoaded value)?  loaded,TResult? Function( SearchResultsFailed value)?  failed,}){
final _that = this;
switch (_that) {
case SearchResultsIdle() when idle != null:
return idle(_that);case SearchResultsSearching() when searching != null:
return searching(_that);case SearchResultsLoaded() when loaded != null:
return loaded(_that);case SearchResultsFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  searching,TResult Function( List<Book> books)?  loaded,TResult Function( ParseFailureKind kind)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SearchResultsIdle() when idle != null:
return idle();case SearchResultsSearching() when searching != null:
return searching();case SearchResultsLoaded() when loaded != null:
return loaded(_that.books);case SearchResultsFailed() when failed != null:
return failed(_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  searching,required TResult Function( List<Book> books)  loaded,required TResult Function( ParseFailureKind kind)  failed,}) {final _that = this;
switch (_that) {
case SearchResultsIdle():
return idle();case SearchResultsSearching():
return searching();case SearchResultsLoaded():
return loaded(_that.books);case SearchResultsFailed():
return failed(_that.kind);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  searching,TResult? Function( List<Book> books)?  loaded,TResult? Function( ParseFailureKind kind)?  failed,}) {final _that = this;
switch (_that) {
case SearchResultsIdle() when idle != null:
return idle();case SearchResultsSearching() when searching != null:
return searching();case SearchResultsLoaded() when loaded != null:
return loaded(_that.books);case SearchResultsFailed() when failed != null:
return failed(_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class SearchResultsIdle implements SearchResultsState {
  const SearchResultsIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchResultsIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SearchResultsState.idle()';
}


}




/// @nodoc


class SearchResultsSearching implements SearchResultsState {
  const SearchResultsSearching();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchResultsSearching);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SearchResultsState.searching()';
}


}




/// @nodoc


class SearchResultsLoaded implements SearchResultsState {
  const SearchResultsLoaded( List<Book> books): _books = books;
  

 final  List<Book> _books;
 List<Book> get books {
  if (_books is EqualUnmodifiableListView) return _books;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_books);
}


/// Create a copy of SearchResultsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchResultsLoadedCopyWith<SearchResultsLoaded> get copyWith => _$SearchResultsLoadedCopyWithImpl<SearchResultsLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchResultsLoaded&&const DeepCollectionEquality().equals(other.books, _books));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_books));
}

@override
String toString() {
    return 'SearchResultsState.loaded(books: $books)';
}


}

/// @nodoc
abstract mixin class $SearchResultsLoadedCopyWith<$Res> implements $SearchResultsStateCopyWith<$Res> {
  factory $SearchResultsLoadedCopyWith(SearchResultsLoaded value, $Res Function(SearchResultsLoaded) _then) = _$SearchResultsLoadedCopyWithImpl;
@useResult
$Res call({
 List<Book> books
});




}
/// @nodoc
class _$SearchResultsLoadedCopyWithImpl<$Res>
    implements $SearchResultsLoadedCopyWith<$Res> {
  _$SearchResultsLoadedCopyWithImpl(this._self, this._then);

  final SearchResultsLoaded _self;
  final $Res Function(SearchResultsLoaded) _then;

/// Create a copy of SearchResultsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? books = null,}) {
  return _then(SearchResultsLoaded(
null == books ? _self._books : books // ignore: cast_nullable_to_non_nullable
as List<Book>,
  ));
}


}

/// @nodoc


class SearchResultsFailed implements SearchResultsState {
  const SearchResultsFailed(this.kind);
  

 final  ParseFailureKind kind;

/// Create a copy of SearchResultsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchResultsFailedCopyWith<SearchResultsFailed> get copyWith => _$SearchResultsFailedCopyWithImpl<SearchResultsFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchResultsFailed&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind);
}

@override
String toString() {
    return 'SearchResultsState.failed(kind: $kind)';
}


}

/// @nodoc
abstract mixin class $SearchResultsFailedCopyWith<$Res> implements $SearchResultsStateCopyWith<$Res> {
  factory $SearchResultsFailedCopyWith(SearchResultsFailed value, $Res Function(SearchResultsFailed) _then) = _$SearchResultsFailedCopyWithImpl;
@useResult
$Res call({
 ParseFailureKind kind
});




}
/// @nodoc
class _$SearchResultsFailedCopyWithImpl<$Res>
    implements $SearchResultsFailedCopyWith<$Res> {
  _$SearchResultsFailedCopyWithImpl(this._self, this._then);

  final SearchResultsFailed _self;
  final $Res Function(SearchResultsFailed) _then;

/// Create a copy of SearchResultsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,}) {
  return _then(SearchResultsFailed(
null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind,
  ));
}


}

// dart format on
