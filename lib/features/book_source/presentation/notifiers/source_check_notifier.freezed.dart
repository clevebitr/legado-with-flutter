// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_check_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SourceCheckEntry {

/// The stored row's id, so the run can write its verdict back (`ADR-0043`).
 int get sourceId;/// The source's name, snapshotted because the row may be gone by the time the check ends.
 String get name;/// Where this source's check stands.
 SourceCheckStatus get status;/// Why it did not pass, when [status] is [SourceCheckStatus.failed].
 SourceCheckFailure? get failure;/// What each stage did, in the order the run reached them.
 List<SourceCheckStageOutcome> get stages;/// How long the check took, which is also what `respondTime` stores.
 int? get elapsedMillis;/// The failure of the whole call when it never produced a report (a thrown storage error).
 ParseFailureKind? get failureKind;/// The rule path of [failureKind], when there is one.
 String? get rulePath;
/// Create a copy of SourceCheckEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceCheckEntryCopyWith<SourceCheckEntry> get copyWith => _$SourceCheckEntryCopyWithImpl<SourceCheckEntry>(this as SourceCheckEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceCheckEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceCheckEntry&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&const DeepCollectionEquality().equals(other.stages, _this.stages)&&(identical(other.elapsedMillis, _this.elapsedMillis) || other.elapsedMillis == _this.elapsedMillis)&&(identical(other.failureKind, _this.failureKind) || other.failureKind == _this.failureKind)&&(identical(other.rulePath, _this.rulePath) || other.rulePath == _this.rulePath));
}


@override
int get hashCode {
  final _this = this as SourceCheckEntry;
  return Object.hash(runtimeType,_this.sourceId,_this.name,_this.status,_this.failure,const DeepCollectionEquality().hash(_this.stages),_this.elapsedMillis,_this.failureKind,_this.rulePath);
}

@override
String toString() {
  final _this = this as SourceCheckEntry;
  return 'SourceCheckEntry(sourceId: ${_this.sourceId}, name: ${_this.name}, status: ${_this.status}, failure: ${_this.failure}, stages: ${_this.stages}, elapsedMillis: ${_this.elapsedMillis}, failureKind: ${_this.failureKind}, rulePath: ${_this.rulePath})';
}


}

/// @nodoc
abstract mixin class $SourceCheckEntryCopyWith<$Res>  {
  factory $SourceCheckEntryCopyWith(SourceCheckEntry value, $Res Function(SourceCheckEntry) _then) = _$SourceCheckEntryCopyWithImpl;
@useResult
$Res call({
 int sourceId, String name, SourceCheckStatus status, SourceCheckFailure? failure, List<SourceCheckStageOutcome> stages, int? elapsedMillis, ParseFailureKind? failureKind, String? rulePath
});




}
/// @nodoc
class _$SourceCheckEntryCopyWithImpl<$Res>
    implements $SourceCheckEntryCopyWith<$Res> {
  _$SourceCheckEntryCopyWithImpl(this._self, this._then);

  final SourceCheckEntry _self;
  final $Res Function(SourceCheckEntry) _then;

/// Create a copy of SourceCheckEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? name = null,Object? status = null,Object? failure = freezed,Object? stages = null,Object? elapsedMillis = freezed,Object? failureKind = freezed,Object? rulePath = freezed,}) {
  return _then(SourceCheckEntry(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SourceCheckStatus,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as SourceCheckFailure?,stages: null == stages ? _self.stages : stages // ignore: cast_nullable_to_non_nullable
as List<SourceCheckStageOutcome>,elapsedMillis: freezed == elapsedMillis ? _self.elapsedMillis : elapsedMillis // ignore: cast_nullable_to_non_nullable
as int?,failureKind: freezed == failureKind ? _self.failureKind : failureKind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,rulePath: freezed == rulePath ? _self.rulePath : rulePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceCheckEntry].
extension SourceCheckEntryPatterns on SourceCheckEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceCheckEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceCheckEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceCheckEntry value)  $default,){
final _that = this;
switch (_that) {
case _SourceCheckEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceCheckEntry value)?  $default,){
final _that = this;
switch (_that) {
case _SourceCheckEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sourceId,  String name,  SourceCheckStatus status,  SourceCheckFailure? failure,  List<SourceCheckStageOutcome> stages,  int? elapsedMillis,  ParseFailureKind? failureKind,  String? rulePath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceCheckEntry() when $default != null:
return $default(_that.sourceId,_that.name,_that.status,_that.failure,_that.stages,_that.elapsedMillis,_that.failureKind,_that.rulePath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sourceId,  String name,  SourceCheckStatus status,  SourceCheckFailure? failure,  List<SourceCheckStageOutcome> stages,  int? elapsedMillis,  ParseFailureKind? failureKind,  String? rulePath)  $default,) {final _that = this;
switch (_that) {
case _SourceCheckEntry():
return $default(_that.sourceId,_that.name,_that.status,_that.failure,_that.stages,_that.elapsedMillis,_that.failureKind,_that.rulePath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sourceId,  String name,  SourceCheckStatus status,  SourceCheckFailure? failure,  List<SourceCheckStageOutcome> stages,  int? elapsedMillis,  ParseFailureKind? failureKind,  String? rulePath)?  $default,) {final _that = this;
switch (_that) {
case _SourceCheckEntry() when $default != null:
return $default(_that.sourceId,_that.name,_that.status,_that.failure,_that.stages,_that.elapsedMillis,_that.failureKind,_that.rulePath);case _:
  return null;

}
}

}

/// @nodoc


class _SourceCheckEntry implements SourceCheckEntry {
  const _SourceCheckEntry({required this.sourceId, required this.name, required this.status, this.failure,  List<SourceCheckStageOutcome> stages = const <SourceCheckStageOutcome>[], this.elapsedMillis, this.failureKind, this.rulePath}): _stages = stages;
  

/// The stored row's id, so the run can write its verdict back (`ADR-0043`).
@override final  int sourceId;
/// The source's name, snapshotted because the row may be gone by the time the check ends.
@override final  String name;
/// Where this source's check stands.
@override final  SourceCheckStatus status;
/// Why it did not pass, when [status] is [SourceCheckStatus.failed].
@override final  SourceCheckFailure? failure;
/// What each stage did, in the order the run reached them.
 final  List<SourceCheckStageOutcome> _stages;
/// What each stage did, in the order the run reached them.
@override@JsonKey() List<SourceCheckStageOutcome> get stages {
  if (_stages is EqualUnmodifiableListView) return _stages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stages);
}

/// How long the check took, which is also what `respondTime` stores.
@override final  int? elapsedMillis;
/// The failure of the whole call when it never produced a report (a thrown storage error).
@override final  ParseFailureKind? failureKind;
/// The rule path of [failureKind], when there is one.
@override final  String? rulePath;

/// Create a copy of SourceCheckEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceCheckEntryCopyWith<_SourceCheckEntry> get copyWith => __$SourceCheckEntryCopyWithImpl<_SourceCheckEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceCheckEntry&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.failure, failure) || other.failure == failure)&&const DeepCollectionEquality().equals(other.stages, _stages)&&(identical(other.elapsedMillis, elapsedMillis) || other.elapsedMillis == elapsedMillis)&&(identical(other.failureKind, failureKind) || other.failureKind == failureKind)&&(identical(other.rulePath, rulePath) || other.rulePath == rulePath));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceId,name,status,failure,const DeepCollectionEquality().hash(_stages),elapsedMillis,failureKind,rulePath);
}

@override
String toString() {
    return 'SourceCheckEntry(sourceId: $sourceId, name: $name, status: $status, failure: $failure, stages: $stages, elapsedMillis: $elapsedMillis, failureKind: $failureKind, rulePath: $rulePath)';
}


}

/// @nodoc
abstract mixin class _$SourceCheckEntryCopyWith<$Res> implements $SourceCheckEntryCopyWith<$Res> {
  factory _$SourceCheckEntryCopyWith(_SourceCheckEntry value, $Res Function(_SourceCheckEntry) _then) = __$SourceCheckEntryCopyWithImpl;
@override @useResult
$Res call({
 int sourceId, String name, SourceCheckStatus status, SourceCheckFailure? failure, List<SourceCheckStageOutcome> stages, int? elapsedMillis, ParseFailureKind? failureKind, String? rulePath
});




}
/// @nodoc
class __$SourceCheckEntryCopyWithImpl<$Res>
    implements _$SourceCheckEntryCopyWith<$Res> {
  __$SourceCheckEntryCopyWithImpl(this._self, this._then);

  final _SourceCheckEntry _self;
  final $Res Function(_SourceCheckEntry) _then;

/// Create a copy of SourceCheckEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? name = null,Object? status = null,Object? failure = freezed,Object? stages = null,Object? elapsedMillis = freezed,Object? failureKind = freezed,Object? rulePath = freezed,}) {
  return _then(_SourceCheckEntry(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SourceCheckStatus,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as SourceCheckFailure?,stages: null == stages ? _self._stages : stages // ignore: cast_nullable_to_non_nullable
as List<SourceCheckStageOutcome>,elapsedMillis: freezed == elapsedMillis ? _self.elapsedMillis : elapsedMillis // ignore: cast_nullable_to_non_nullable
as int?,failureKind: freezed == failureKind ? _self.failureKind : failureKind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,rulePath: freezed == rulePath ? _self.rulePath : rulePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$SourceCheckState {

/// Whether a batch is running right now.
 bool get isRunning;/// The settings the next run will use (stage switches, keyword, timeout).
 SourceCheckSettings get settings;/// One row per source of the current run, in the order the user selected them.
 List<SourceCheckEntry> get entries;
/// Create a copy of SourceCheckState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceCheckStateCopyWith<SourceCheckState> get copyWith => _$SourceCheckStateCopyWithImpl<SourceCheckState>(this as SourceCheckState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceCheckState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceCheckState&&(identical(other.isRunning, _this.isRunning) || other.isRunning == _this.isRunning)&&(identical(other.settings, _this.settings) || other.settings == _this.settings)&&const DeepCollectionEquality().equals(other.entries, _this.entries));
}


@override
int get hashCode {
  final _this = this as SourceCheckState;
  return Object.hash(runtimeType,_this.isRunning,_this.settings,const DeepCollectionEquality().hash(_this.entries));
}

@override
String toString() {
  final _this = this as SourceCheckState;
  return 'SourceCheckState(isRunning: ${_this.isRunning}, settings: ${_this.settings}, entries: ${_this.entries})';
}


}

/// @nodoc
abstract mixin class $SourceCheckStateCopyWith<$Res>  {
  factory $SourceCheckStateCopyWith(SourceCheckState value, $Res Function(SourceCheckState) _then) = _$SourceCheckStateCopyWithImpl;
@useResult
$Res call({
 bool isRunning, SourceCheckSettings settings, List<SourceCheckEntry> entries
});




}
/// @nodoc
class _$SourceCheckStateCopyWithImpl<$Res>
    implements $SourceCheckStateCopyWith<$Res> {
  _$SourceCheckStateCopyWithImpl(this._self, this._then);

  final SourceCheckState _self;
  final $Res Function(SourceCheckState) _then;

/// Create a copy of SourceCheckState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isRunning = null,Object? settings = null,Object? entries = null,}) {
  return _then(SourceCheckState(
isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as SourceCheckSettings,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<SourceCheckEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceCheckState].
extension SourceCheckStatePatterns on SourceCheckState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceCheckState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceCheckState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceCheckState value)  $default,){
final _that = this;
switch (_that) {
case _SourceCheckState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceCheckState value)?  $default,){
final _that = this;
switch (_that) {
case _SourceCheckState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isRunning,  SourceCheckSettings settings,  List<SourceCheckEntry> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceCheckState() when $default != null:
return $default(_that.isRunning,_that.settings,_that.entries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isRunning,  SourceCheckSettings settings,  List<SourceCheckEntry> entries)  $default,) {final _that = this;
switch (_that) {
case _SourceCheckState():
return $default(_that.isRunning,_that.settings,_that.entries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isRunning,  SourceCheckSettings settings,  List<SourceCheckEntry> entries)?  $default,) {final _that = this;
switch (_that) {
case _SourceCheckState() when $default != null:
return $default(_that.isRunning,_that.settings,_that.entries);case _:
  return null;

}
}

}

/// @nodoc


class _SourceCheckState implements SourceCheckState {
  const _SourceCheckState({this.isRunning = false, this.settings = const SourceCheckSettings(),  List<SourceCheckEntry> entries = const <SourceCheckEntry>[]}): _entries = entries;
  

/// Whether a batch is running right now.
@override@JsonKey() final  bool isRunning;
/// The settings the next run will use (stage switches, keyword, timeout).
@override@JsonKey() final  SourceCheckSettings settings;
/// One row per source of the current run, in the order the user selected them.
 final  List<SourceCheckEntry> _entries;
/// One row per source of the current run, in the order the user selected them.
@override@JsonKey() List<SourceCheckEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of SourceCheckState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceCheckStateCopyWith<_SourceCheckState> get copyWith => __$SourceCheckStateCopyWithImpl<_SourceCheckState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceCheckState&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.settings, settings) || other.settings == settings)&&const DeepCollectionEquality().equals(other.entries, _entries));
}


@override
int get hashCode {
    return Object.hash(runtimeType,isRunning,settings,const DeepCollectionEquality().hash(_entries));
}

@override
String toString() {
    return 'SourceCheckState(isRunning: $isRunning, settings: $settings, entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$SourceCheckStateCopyWith<$Res> implements $SourceCheckStateCopyWith<$Res> {
  factory _$SourceCheckStateCopyWith(_SourceCheckState value, $Res Function(_SourceCheckState) _then) = __$SourceCheckStateCopyWithImpl;
@override @useResult
$Res call({
 bool isRunning, SourceCheckSettings settings, List<SourceCheckEntry> entries
});




}
/// @nodoc
class __$SourceCheckStateCopyWithImpl<$Res>
    implements _$SourceCheckStateCopyWith<$Res> {
  __$SourceCheckStateCopyWithImpl(this._self, this._then);

  final _SourceCheckState _self;
  final $Res Function(_SourceCheckState) _then;

/// Create a copy of SourceCheckState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isRunning = null,Object? settings = null,Object? entries = null,}) {
  return _then(_SourceCheckState(
isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as SourceCheckSettings,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<SourceCheckEntry>,
  ));
}


}

// dart format on
