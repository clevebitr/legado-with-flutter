// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'aggregate_search_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AggregateSearchState {

/// Where the run stands.
 AggregateSearchStatus get status;/// The merged, de-duplicated rows.
 List<SearchBook> get books;/// How many sources finished (successfully or not).
 int get processedSources;/// How many sources the scope resolved to.
 int get totalSources;/// How many of them failed.
 int get failedSources;/// Whether another page is worth asking for.
 bool get hasMore;/// Whether the user paused a running search.
 bool get isPaused;/// The page the next [AggregateSearch.loadMore] will ask for.
 int get page;/// Why the run failed, when [status] is [AggregateSearchStatus.failed].
 ParseFailureKind? get failureKind;/// Why no source could be searched, when the scope resolved to nothing.
 Map<String, SearchSourceSkip> get skipped;/// The match mode the next run uses.
 SearchMatchMode get matchMode;/// The source-type filter the next run uses.
 Set<BookSourceType> get types;
/// Create a copy of AggregateSearchState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AggregateSearchStateCopyWith<AggregateSearchState> get copyWith => _$AggregateSearchStateCopyWithImpl<AggregateSearchState>(this as AggregateSearchState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AggregateSearchState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AggregateSearchState&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.books, _this.books)&&(identical(other.processedSources, _this.processedSources) || other.processedSources == _this.processedSources)&&(identical(other.totalSources, _this.totalSources) || other.totalSources == _this.totalSources)&&(identical(other.failedSources, _this.failedSources) || other.failedSources == _this.failedSources)&&(identical(other.hasMore, _this.hasMore) || other.hasMore == _this.hasMore)&&(identical(other.isPaused, _this.isPaused) || other.isPaused == _this.isPaused)&&(identical(other.page, _this.page) || other.page == _this.page)&&(identical(other.failureKind, _this.failureKind) || other.failureKind == _this.failureKind)&&const DeepCollectionEquality().equals(other.skipped, _this.skipped)&&(identical(other.matchMode, _this.matchMode) || other.matchMode == _this.matchMode)&&const DeepCollectionEquality().equals(other.types, _this.types));
}


@override
int get hashCode {
  final _this = this as AggregateSearchState;
  return Object.hash(runtimeType,_this.status,const DeepCollectionEquality().hash(_this.books),_this.processedSources,_this.totalSources,_this.failedSources,_this.hasMore,_this.isPaused,_this.page,_this.failureKind,const DeepCollectionEquality().hash(_this.skipped),_this.matchMode,const DeepCollectionEquality().hash(_this.types));
}

@override
String toString() {
  final _this = this as AggregateSearchState;
  return 'AggregateSearchState(status: ${_this.status}, books: ${_this.books}, processedSources: ${_this.processedSources}, totalSources: ${_this.totalSources}, failedSources: ${_this.failedSources}, hasMore: ${_this.hasMore}, isPaused: ${_this.isPaused}, page: ${_this.page}, failureKind: ${_this.failureKind}, skipped: ${_this.skipped}, matchMode: ${_this.matchMode}, types: ${_this.types})';
}


}

/// @nodoc
abstract mixin class $AggregateSearchStateCopyWith<$Res>  {
  factory $AggregateSearchStateCopyWith(AggregateSearchState value, $Res Function(AggregateSearchState) _then) = _$AggregateSearchStateCopyWithImpl;
@useResult
$Res call({
 AggregateSearchStatus status, List<SearchBook> books, int processedSources, int totalSources, int failedSources, bool hasMore, bool isPaused, int page, ParseFailureKind? failureKind, Map<String, SearchSourceSkip> skipped, SearchMatchMode matchMode, Set<BookSourceType> types
});




}
/// @nodoc
class _$AggregateSearchStateCopyWithImpl<$Res>
    implements $AggregateSearchStateCopyWith<$Res> {
  _$AggregateSearchStateCopyWithImpl(this._self, this._then);

  final AggregateSearchState _self;
  final $Res Function(AggregateSearchState) _then;

/// Create a copy of AggregateSearchState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? books = null,Object? processedSources = null,Object? totalSources = null,Object? failedSources = null,Object? hasMore = null,Object? isPaused = null,Object? page = null,Object? failureKind = freezed,Object? skipped = null,Object? matchMode = null,Object? types = null,}) {
  return _then(AggregateSearchState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AggregateSearchStatus,books: null == books ? _self.books : books // ignore: cast_nullable_to_non_nullable
as List<SearchBook>,processedSources: null == processedSources ? _self.processedSources : processedSources // ignore: cast_nullable_to_non_nullable
as int,totalSources: null == totalSources ? _self.totalSources : totalSources // ignore: cast_nullable_to_non_nullable
as int,failedSources: null == failedSources ? _self.failedSources : failedSources // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,failureKind: freezed == failureKind ? _self.failureKind : failureKind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as Map<String, SearchSourceSkip>,matchMode: null == matchMode ? _self.matchMode : matchMode // ignore: cast_nullable_to_non_nullable
as SearchMatchMode,types: null == types ? _self.types : types // ignore: cast_nullable_to_non_nullable
as Set<BookSourceType>,
  ));
}

}


/// Adds pattern-matching-related methods to [AggregateSearchState].
extension AggregateSearchStatePatterns on AggregateSearchState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AggregateSearchState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AggregateSearchState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AggregateSearchState value)  $default,){
final _that = this;
switch (_that) {
case _AggregateSearchState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AggregateSearchState value)?  $default,){
final _that = this;
switch (_that) {
case _AggregateSearchState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AggregateSearchStatus status,  List<SearchBook> books,  int processedSources,  int totalSources,  int failedSources,  bool hasMore,  bool isPaused,  int page,  ParseFailureKind? failureKind,  Map<String, SearchSourceSkip> skipped,  SearchMatchMode matchMode,  Set<BookSourceType> types)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AggregateSearchState() when $default != null:
return $default(_that.status,_that.books,_that.processedSources,_that.totalSources,_that.failedSources,_that.hasMore,_that.isPaused,_that.page,_that.failureKind,_that.skipped,_that.matchMode,_that.types);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AggregateSearchStatus status,  List<SearchBook> books,  int processedSources,  int totalSources,  int failedSources,  bool hasMore,  bool isPaused,  int page,  ParseFailureKind? failureKind,  Map<String, SearchSourceSkip> skipped,  SearchMatchMode matchMode,  Set<BookSourceType> types)  $default,) {final _that = this;
switch (_that) {
case _AggregateSearchState():
return $default(_that.status,_that.books,_that.processedSources,_that.totalSources,_that.failedSources,_that.hasMore,_that.isPaused,_that.page,_that.failureKind,_that.skipped,_that.matchMode,_that.types);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AggregateSearchStatus status,  List<SearchBook> books,  int processedSources,  int totalSources,  int failedSources,  bool hasMore,  bool isPaused,  int page,  ParseFailureKind? failureKind,  Map<String, SearchSourceSkip> skipped,  SearchMatchMode matchMode,  Set<BookSourceType> types)?  $default,) {final _that = this;
switch (_that) {
case _AggregateSearchState() when $default != null:
return $default(_that.status,_that.books,_that.processedSources,_that.totalSources,_that.failedSources,_that.hasMore,_that.isPaused,_that.page,_that.failureKind,_that.skipped,_that.matchMode,_that.types);case _:
  return null;

}
}

}

/// @nodoc


class _AggregateSearchState implements AggregateSearchState {
  const _AggregateSearchState({this.status = AggregateSearchStatus.idle,  List<SearchBook> books = const <SearchBook>[], this.processedSources = 0, this.totalSources = 0, this.failedSources = 0, this.hasMore = false, this.isPaused = false, this.page = 1, this.failureKind,  Map<String, SearchSourceSkip> skipped = const <String, SearchSourceSkip>{}, this.matchMode = SearchMatchMode.defaultMode,  Set<BookSourceType> types = defaultSearchSourceTypes}): _books = books,_skipped = skipped,_types = types;
  

/// Where the run stands.
@override@JsonKey() final  AggregateSearchStatus status;
/// The merged, de-duplicated rows.
 final  List<SearchBook> _books;
/// The merged, de-duplicated rows.
@override@JsonKey() List<SearchBook> get books {
  if (_books is EqualUnmodifiableListView) return _books;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_books);
}

/// How many sources finished (successfully or not).
@override@JsonKey() final  int processedSources;
/// How many sources the scope resolved to.
@override@JsonKey() final  int totalSources;
/// How many of them failed.
@override@JsonKey() final  int failedSources;
/// Whether another page is worth asking for.
@override@JsonKey() final  bool hasMore;
/// Whether the user paused a running search.
@override@JsonKey() final  bool isPaused;
/// The page the next [AggregateSearch.loadMore] will ask for.
@override@JsonKey() final  int page;
/// Why the run failed, when [status] is [AggregateSearchStatus.failed].
@override final  ParseFailureKind? failureKind;
/// Why no source could be searched, when the scope resolved to nothing.
 final  Map<String, SearchSourceSkip> _skipped;
/// Why no source could be searched, when the scope resolved to nothing.
@override@JsonKey() Map<String, SearchSourceSkip> get skipped {
  if (_skipped is EqualUnmodifiableMapView) return _skipped;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_skipped);
}

/// The match mode the next run uses.
@override@JsonKey() final  SearchMatchMode matchMode;
/// The source-type filter the next run uses.
 final  Set<BookSourceType> _types;
/// The source-type filter the next run uses.
@override@JsonKey() Set<BookSourceType> get types {
  if (_types is EqualUnmodifiableSetView) return _types;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_types);
}


/// Create a copy of AggregateSearchState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AggregateSearchStateCopyWith<_AggregateSearchState> get copyWith => __$AggregateSearchStateCopyWithImpl<_AggregateSearchState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AggregateSearchState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.books, _books)&&(identical(other.processedSources, processedSources) || other.processedSources == processedSources)&&(identical(other.totalSources, totalSources) || other.totalSources == totalSources)&&(identical(other.failedSources, failedSources) || other.failedSources == failedSources)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.page, page) || other.page == page)&&(identical(other.failureKind, failureKind) || other.failureKind == failureKind)&&const DeepCollectionEquality().equals(other.skipped, _skipped)&&(identical(other.matchMode, matchMode) || other.matchMode == matchMode)&&const DeepCollectionEquality().equals(other.types, _types));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_books),processedSources,totalSources,failedSources,hasMore,isPaused,page,failureKind,const DeepCollectionEquality().hash(_skipped),matchMode,const DeepCollectionEquality().hash(_types));
}

@override
String toString() {
    return 'AggregateSearchState(status: $status, books: $books, processedSources: $processedSources, totalSources: $totalSources, failedSources: $failedSources, hasMore: $hasMore, isPaused: $isPaused, page: $page, failureKind: $failureKind, skipped: $skipped, matchMode: $matchMode, types: $types)';
}


}

/// @nodoc
abstract mixin class _$AggregateSearchStateCopyWith<$Res> implements $AggregateSearchStateCopyWith<$Res> {
  factory _$AggregateSearchStateCopyWith(_AggregateSearchState value, $Res Function(_AggregateSearchState) _then) = __$AggregateSearchStateCopyWithImpl;
@override @useResult
$Res call({
 AggregateSearchStatus status, List<SearchBook> books, int processedSources, int totalSources, int failedSources, bool hasMore, bool isPaused, int page, ParseFailureKind? failureKind, Map<String, SearchSourceSkip> skipped, SearchMatchMode matchMode, Set<BookSourceType> types
});




}
/// @nodoc
class __$AggregateSearchStateCopyWithImpl<$Res>
    implements _$AggregateSearchStateCopyWith<$Res> {
  __$AggregateSearchStateCopyWithImpl(this._self, this._then);

  final _AggregateSearchState _self;
  final $Res Function(_AggregateSearchState) _then;

/// Create a copy of AggregateSearchState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? books = null,Object? processedSources = null,Object? totalSources = null,Object? failedSources = null,Object? hasMore = null,Object? isPaused = null,Object? page = null,Object? failureKind = freezed,Object? skipped = null,Object? matchMode = null,Object? types = null,}) {
  return _then(_AggregateSearchState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AggregateSearchStatus,books: null == books ? _self._books : books // ignore: cast_nullable_to_non_nullable
as List<SearchBook>,processedSources: null == processedSources ? _self.processedSources : processedSources // ignore: cast_nullable_to_non_nullable
as int,totalSources: null == totalSources ? _self.totalSources : totalSources // ignore: cast_nullable_to_non_nullable
as int,failedSources: null == failedSources ? _self.failedSources : failedSources // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,failureKind: freezed == failureKind ? _self.failureKind : failureKind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,skipped: null == skipped ? _self._skipped : skipped // ignore: cast_nullable_to_non_nullable
as Map<String, SearchSourceSkip>,matchMode: null == matchMode ? _self.matchMode : matchMode // ignore: cast_nullable_to_non_nullable
as SearchMatchMode,types: null == types ? _self._types : types // ignore: cast_nullable_to_non_nullable
as Set<BookSourceType>,
  ));
}


}

// dart format on
