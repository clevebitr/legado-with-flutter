// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'change_source_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChangeSourceState {

/// Where the run stands.
 ChangeSourceStatus get status;/// The keyword every source is searched with; defaults to the book's title.
 String get keyword;/// The candidates found so far, already ordered.
 List<ChangeSourceCandidate> get candidates;/// How many sources finished (successfully or not).
 int get processedSources;/// How many sources the scope resolved to.
 int get totalSources;/// How many of them failed.
 int get failedSources;/// Whether the user paused a running search.
 bool get isPaused;/// Whether a candidate's author must contain the book's author.
 bool get checkAuthor;/// Whether each candidate's detail page is read.
 bool get loadInfo;/// Whether each candidate's chapter list is read (chapter count).
 bool get loadToc;/// The source that just finished, for the progress line.
 String? get currentSourceName;/// Why the run failed, when [status] is [ChangeSourceStatus.failed].
 ParseFailureKind? get failureKind;/// The candidate the user picked; `null` on the list step.
 ChangeSourceCandidate? get selected;/// The picked candidate's table of contents.
 List<Chapter> get chapters;/// The chapter to align to, or `-1` while the list is still empty.
 int get chapterIndex;/// Whether the picked candidate's table of contents is being read.
 bool get isLoadingChapters;/// Why that chapter list could not be read.
 ParseFailureKind? get chaptersFailure;
/// Create a copy of ChangeSourceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeSourceStateCopyWith<ChangeSourceState> get copyWith => _$ChangeSourceStateCopyWithImpl<ChangeSourceState>(this as ChangeSourceState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ChangeSourceState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeSourceState&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.keyword, _this.keyword) || other.keyword == _this.keyword)&&const DeepCollectionEquality().equals(other.candidates, _this.candidates)&&(identical(other.processedSources, _this.processedSources) || other.processedSources == _this.processedSources)&&(identical(other.totalSources, _this.totalSources) || other.totalSources == _this.totalSources)&&(identical(other.failedSources, _this.failedSources) || other.failedSources == _this.failedSources)&&(identical(other.isPaused, _this.isPaused) || other.isPaused == _this.isPaused)&&(identical(other.checkAuthor, _this.checkAuthor) || other.checkAuthor == _this.checkAuthor)&&(identical(other.loadInfo, _this.loadInfo) || other.loadInfo == _this.loadInfo)&&(identical(other.loadToc, _this.loadToc) || other.loadToc == _this.loadToc)&&(identical(other.currentSourceName, _this.currentSourceName) || other.currentSourceName == _this.currentSourceName)&&(identical(other.failureKind, _this.failureKind) || other.failureKind == _this.failureKind)&&(identical(other.selected, _this.selected) || other.selected == _this.selected)&&const DeepCollectionEquality().equals(other.chapters, _this.chapters)&&(identical(other.chapterIndex, _this.chapterIndex) || other.chapterIndex == _this.chapterIndex)&&(identical(other.isLoadingChapters, _this.isLoadingChapters) || other.isLoadingChapters == _this.isLoadingChapters)&&(identical(other.chaptersFailure, _this.chaptersFailure) || other.chaptersFailure == _this.chaptersFailure));
}


@override
int get hashCode {
  final _this = this as ChangeSourceState;
  return Object.hash(runtimeType,_this.status,_this.keyword,const DeepCollectionEquality().hash(_this.candidates),_this.processedSources,_this.totalSources,_this.failedSources,_this.isPaused,_this.checkAuthor,_this.loadInfo,_this.loadToc,_this.currentSourceName,_this.failureKind,_this.selected,const DeepCollectionEquality().hash(_this.chapters),_this.chapterIndex,_this.isLoadingChapters,_this.chaptersFailure);
}

@override
String toString() {
  final _this = this as ChangeSourceState;
  return 'ChangeSourceState(status: ${_this.status}, keyword: ${_this.keyword}, candidates: ${_this.candidates}, processedSources: ${_this.processedSources}, totalSources: ${_this.totalSources}, failedSources: ${_this.failedSources}, isPaused: ${_this.isPaused}, checkAuthor: ${_this.checkAuthor}, loadInfo: ${_this.loadInfo}, loadToc: ${_this.loadToc}, currentSourceName: ${_this.currentSourceName}, failureKind: ${_this.failureKind}, selected: ${_this.selected}, chapters: ${_this.chapters}, chapterIndex: ${_this.chapterIndex}, isLoadingChapters: ${_this.isLoadingChapters}, chaptersFailure: ${_this.chaptersFailure})';
}


}

/// @nodoc
abstract mixin class $ChangeSourceStateCopyWith<$Res>  {
  factory $ChangeSourceStateCopyWith(ChangeSourceState value, $Res Function(ChangeSourceState) _then) = _$ChangeSourceStateCopyWithImpl;
@useResult
$Res call({
 ChangeSourceStatus status, String keyword, List<ChangeSourceCandidate> candidates, int processedSources, int totalSources, int failedSources, bool isPaused, bool checkAuthor, bool loadInfo, bool loadToc, String? currentSourceName, ParseFailureKind? failureKind, ChangeSourceCandidate? selected, List<Chapter> chapters, int chapterIndex, bool isLoadingChapters, ParseFailureKind? chaptersFailure
});




}
/// @nodoc
class _$ChangeSourceStateCopyWithImpl<$Res>
    implements $ChangeSourceStateCopyWith<$Res> {
  _$ChangeSourceStateCopyWithImpl(this._self, this._then);

  final ChangeSourceState _self;
  final $Res Function(ChangeSourceState) _then;

/// Create a copy of ChangeSourceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? keyword = null,Object? candidates = null,Object? processedSources = null,Object? totalSources = null,Object? failedSources = null,Object? isPaused = null,Object? checkAuthor = null,Object? loadInfo = null,Object? loadToc = null,Object? currentSourceName = freezed,Object? failureKind = freezed,Object? selected = freezed,Object? chapters = null,Object? chapterIndex = null,Object? isLoadingChapters = null,Object? chaptersFailure = freezed,}) {
  return _then(ChangeSourceState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChangeSourceStatus,keyword: null == keyword ? _self.keyword : keyword // ignore: cast_nullable_to_non_nullable
as String,candidates: null == candidates ? _self.candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<ChangeSourceCandidate>,processedSources: null == processedSources ? _self.processedSources : processedSources // ignore: cast_nullable_to_non_nullable
as int,totalSources: null == totalSources ? _self.totalSources : totalSources // ignore: cast_nullable_to_non_nullable
as int,failedSources: null == failedSources ? _self.failedSources : failedSources // ignore: cast_nullable_to_non_nullable
as int,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,checkAuthor: null == checkAuthor ? _self.checkAuthor : checkAuthor // ignore: cast_nullable_to_non_nullable
as bool,loadInfo: null == loadInfo ? _self.loadInfo : loadInfo // ignore: cast_nullable_to_non_nullable
as bool,loadToc: null == loadToc ? _self.loadToc : loadToc // ignore: cast_nullable_to_non_nullable
as bool,currentSourceName: freezed == currentSourceName ? _self.currentSourceName : currentSourceName // ignore: cast_nullable_to_non_nullable
as String?,failureKind: freezed == failureKind ? _self.failureKind : failureKind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as ChangeSourceCandidate?,chapters: null == chapters ? _self.chapters : chapters // ignore: cast_nullable_to_non_nullable
as List<Chapter>,chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,isLoadingChapters: null == isLoadingChapters ? _self.isLoadingChapters : isLoadingChapters // ignore: cast_nullable_to_non_nullable
as bool,chaptersFailure: freezed == chaptersFailure ? _self.chaptersFailure : chaptersFailure // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChangeSourceState].
extension ChangeSourceStatePatterns on ChangeSourceState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChangeSourceState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChangeSourceState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChangeSourceState value)  $default,){
final _that = this;
switch (_that) {
case _ChangeSourceState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChangeSourceState value)?  $default,){
final _that = this;
switch (_that) {
case _ChangeSourceState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ChangeSourceStatus status,  String keyword,  List<ChangeSourceCandidate> candidates,  int processedSources,  int totalSources,  int failedSources,  bool isPaused,  bool checkAuthor,  bool loadInfo,  bool loadToc,  String? currentSourceName,  ParseFailureKind? failureKind,  ChangeSourceCandidate? selected,  List<Chapter> chapters,  int chapterIndex,  bool isLoadingChapters,  ParseFailureKind? chaptersFailure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChangeSourceState() when $default != null:
return $default(_that.status,_that.keyword,_that.candidates,_that.processedSources,_that.totalSources,_that.failedSources,_that.isPaused,_that.checkAuthor,_that.loadInfo,_that.loadToc,_that.currentSourceName,_that.failureKind,_that.selected,_that.chapters,_that.chapterIndex,_that.isLoadingChapters,_that.chaptersFailure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ChangeSourceStatus status,  String keyword,  List<ChangeSourceCandidate> candidates,  int processedSources,  int totalSources,  int failedSources,  bool isPaused,  bool checkAuthor,  bool loadInfo,  bool loadToc,  String? currentSourceName,  ParseFailureKind? failureKind,  ChangeSourceCandidate? selected,  List<Chapter> chapters,  int chapterIndex,  bool isLoadingChapters,  ParseFailureKind? chaptersFailure)  $default,) {final _that = this;
switch (_that) {
case _ChangeSourceState():
return $default(_that.status,_that.keyword,_that.candidates,_that.processedSources,_that.totalSources,_that.failedSources,_that.isPaused,_that.checkAuthor,_that.loadInfo,_that.loadToc,_that.currentSourceName,_that.failureKind,_that.selected,_that.chapters,_that.chapterIndex,_that.isLoadingChapters,_that.chaptersFailure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ChangeSourceStatus status,  String keyword,  List<ChangeSourceCandidate> candidates,  int processedSources,  int totalSources,  int failedSources,  bool isPaused,  bool checkAuthor,  bool loadInfo,  bool loadToc,  String? currentSourceName,  ParseFailureKind? failureKind,  ChangeSourceCandidate? selected,  List<Chapter> chapters,  int chapterIndex,  bool isLoadingChapters,  ParseFailureKind? chaptersFailure)?  $default,) {final _that = this;
switch (_that) {
case _ChangeSourceState() when $default != null:
return $default(_that.status,_that.keyword,_that.candidates,_that.processedSources,_that.totalSources,_that.failedSources,_that.isPaused,_that.checkAuthor,_that.loadInfo,_that.loadToc,_that.currentSourceName,_that.failureKind,_that.selected,_that.chapters,_that.chapterIndex,_that.isLoadingChapters,_that.chaptersFailure);case _:
  return null;

}
}

}

/// @nodoc


class _ChangeSourceState implements ChangeSourceState {
  const _ChangeSourceState({this.status = ChangeSourceStatus.idle, this.keyword = '',  List<ChangeSourceCandidate> candidates = const <ChangeSourceCandidate>[], this.processedSources = 0, this.totalSources = 0, this.failedSources = 0, this.isPaused = false, this.checkAuthor = false, this.loadInfo = false, this.loadToc = false, this.currentSourceName, this.failureKind, this.selected,  List<Chapter> chapters = const <Chapter>[], this.chapterIndex = -1, this.isLoadingChapters = false, this.chaptersFailure}): _candidates = candidates,_chapters = chapters;
  

/// Where the run stands.
@override@JsonKey() final  ChangeSourceStatus status;
/// The keyword every source is searched with; defaults to the book's title.
@override@JsonKey() final  String keyword;
/// The candidates found so far, already ordered.
 final  List<ChangeSourceCandidate> _candidates;
/// The candidates found so far, already ordered.
@override@JsonKey() List<ChangeSourceCandidate> get candidates {
  if (_candidates is EqualUnmodifiableListView) return _candidates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_candidates);
}

/// How many sources finished (successfully or not).
@override@JsonKey() final  int processedSources;
/// How many sources the scope resolved to.
@override@JsonKey() final  int totalSources;
/// How many of them failed.
@override@JsonKey() final  int failedSources;
/// Whether the user paused a running search.
@override@JsonKey() final  bool isPaused;
/// Whether a candidate's author must contain the book's author.
@override@JsonKey() final  bool checkAuthor;
/// Whether each candidate's detail page is read.
@override@JsonKey() final  bool loadInfo;
/// Whether each candidate's chapter list is read (chapter count).
@override@JsonKey() final  bool loadToc;
/// The source that just finished, for the progress line.
@override final  String? currentSourceName;
/// Why the run failed, when [status] is [ChangeSourceStatus.failed].
@override final  ParseFailureKind? failureKind;
/// The candidate the user picked; `null` on the list step.
@override final  ChangeSourceCandidate? selected;
/// The picked candidate's table of contents.
 final  List<Chapter> _chapters;
/// The picked candidate's table of contents.
@override@JsonKey() List<Chapter> get chapters {
  if (_chapters is EqualUnmodifiableListView) return _chapters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chapters);
}

/// The chapter to align to, or `-1` while the list is still empty.
@override@JsonKey() final  int chapterIndex;
/// Whether the picked candidate's table of contents is being read.
@override@JsonKey() final  bool isLoadingChapters;
/// Why that chapter list could not be read.
@override final  ParseFailureKind? chaptersFailure;

/// Create a copy of ChangeSourceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChangeSourceStateCopyWith<_ChangeSourceState> get copyWith => __$ChangeSourceStateCopyWithImpl<_ChangeSourceState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChangeSourceState&&(identical(other.status, status) || other.status == status)&&(identical(other.keyword, keyword) || other.keyword == keyword)&&const DeepCollectionEquality().equals(other.candidates, _candidates)&&(identical(other.processedSources, processedSources) || other.processedSources == processedSources)&&(identical(other.totalSources, totalSources) || other.totalSources == totalSources)&&(identical(other.failedSources, failedSources) || other.failedSources == failedSources)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.checkAuthor, checkAuthor) || other.checkAuthor == checkAuthor)&&(identical(other.loadInfo, loadInfo) || other.loadInfo == loadInfo)&&(identical(other.loadToc, loadToc) || other.loadToc == loadToc)&&(identical(other.currentSourceName, currentSourceName) || other.currentSourceName == currentSourceName)&&(identical(other.failureKind, failureKind) || other.failureKind == failureKind)&&(identical(other.selected, selected) || other.selected == selected)&&const DeepCollectionEquality().equals(other.chapters, _chapters)&&(identical(other.chapterIndex, chapterIndex) || other.chapterIndex == chapterIndex)&&(identical(other.isLoadingChapters, isLoadingChapters) || other.isLoadingChapters == isLoadingChapters)&&(identical(other.chaptersFailure, chaptersFailure) || other.chaptersFailure == chaptersFailure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,keyword,const DeepCollectionEquality().hash(_candidates),processedSources,totalSources,failedSources,isPaused,checkAuthor,loadInfo,loadToc,currentSourceName,failureKind,selected,const DeepCollectionEquality().hash(_chapters),chapterIndex,isLoadingChapters,chaptersFailure);
}

@override
String toString() {
    return 'ChangeSourceState(status: $status, keyword: $keyword, candidates: $candidates, processedSources: $processedSources, totalSources: $totalSources, failedSources: $failedSources, isPaused: $isPaused, checkAuthor: $checkAuthor, loadInfo: $loadInfo, loadToc: $loadToc, currentSourceName: $currentSourceName, failureKind: $failureKind, selected: $selected, chapters: $chapters, chapterIndex: $chapterIndex, isLoadingChapters: $isLoadingChapters, chaptersFailure: $chaptersFailure)';
}


}

/// @nodoc
abstract mixin class _$ChangeSourceStateCopyWith<$Res> implements $ChangeSourceStateCopyWith<$Res> {
  factory _$ChangeSourceStateCopyWith(_ChangeSourceState value, $Res Function(_ChangeSourceState) _then) = __$ChangeSourceStateCopyWithImpl;
@override @useResult
$Res call({
 ChangeSourceStatus status, String keyword, List<ChangeSourceCandidate> candidates, int processedSources, int totalSources, int failedSources, bool isPaused, bool checkAuthor, bool loadInfo, bool loadToc, String? currentSourceName, ParseFailureKind? failureKind, ChangeSourceCandidate? selected, List<Chapter> chapters, int chapterIndex, bool isLoadingChapters, ParseFailureKind? chaptersFailure
});




}
/// @nodoc
class __$ChangeSourceStateCopyWithImpl<$Res>
    implements _$ChangeSourceStateCopyWith<$Res> {
  __$ChangeSourceStateCopyWithImpl(this._self, this._then);

  final _ChangeSourceState _self;
  final $Res Function(_ChangeSourceState) _then;

/// Create a copy of ChangeSourceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? keyword = null,Object? candidates = null,Object? processedSources = null,Object? totalSources = null,Object? failedSources = null,Object? isPaused = null,Object? checkAuthor = null,Object? loadInfo = null,Object? loadToc = null,Object? currentSourceName = freezed,Object? failureKind = freezed,Object? selected = freezed,Object? chapters = null,Object? chapterIndex = null,Object? isLoadingChapters = null,Object? chaptersFailure = freezed,}) {
  return _then(_ChangeSourceState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChangeSourceStatus,keyword: null == keyword ? _self.keyword : keyword // ignore: cast_nullable_to_non_nullable
as String,candidates: null == candidates ? _self._candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<ChangeSourceCandidate>,processedSources: null == processedSources ? _self.processedSources : processedSources // ignore: cast_nullable_to_non_nullable
as int,totalSources: null == totalSources ? _self.totalSources : totalSources // ignore: cast_nullable_to_non_nullable
as int,failedSources: null == failedSources ? _self.failedSources : failedSources // ignore: cast_nullable_to_non_nullable
as int,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,checkAuthor: null == checkAuthor ? _self.checkAuthor : checkAuthor // ignore: cast_nullable_to_non_nullable
as bool,loadInfo: null == loadInfo ? _self.loadInfo : loadInfo // ignore: cast_nullable_to_non_nullable
as bool,loadToc: null == loadToc ? _self.loadToc : loadToc // ignore: cast_nullable_to_non_nullable
as bool,currentSourceName: freezed == currentSourceName ? _self.currentSourceName : currentSourceName // ignore: cast_nullable_to_non_nullable
as String?,failureKind: freezed == failureKind ? _self.failureKind : failureKind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as ChangeSourceCandidate?,chapters: null == chapters ? _self._chapters : chapters // ignore: cast_nullable_to_non_nullable
as List<Chapter>,chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,isLoadingChapters: null == isLoadingChapters ? _self.isLoadingChapters : isLoadingChapters // ignore: cast_nullable_to_non_nullable
as bool,chaptersFailure: freezed == chaptersFailure ? _self.chaptersFailure : chaptersFailure // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,
  ));
}


}

// dart format on
