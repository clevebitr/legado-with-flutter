// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_check.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SourceCheckStageOutcome {

/// The stage this outcome belongs to.
 SourceCheckStage get stage;/// Whether the stage was usable, failed or was skipped by a stop.
 SourceCheckStatus get status;/// The failure kind the stage's `ParseResult` carried, when it failed.
 ParseFailureKind? get failureKind;/// The rule path of the failure (`book-source.md` §7), when it failed.
 String? get rulePath;/// The group token written into the source's group list, when it failed.
 String? get invalidGroup;



@override
bool operator ==(Object other) {
  final _this = this as SourceCheckStageOutcome;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceCheckStageOutcome&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.failureKind, _this.failureKind) || other.failureKind == _this.failureKind)&&(identical(other.rulePath, _this.rulePath) || other.rulePath == _this.rulePath)&&(identical(other.invalidGroup, _this.invalidGroup) || other.invalidGroup == _this.invalidGroup));
}


@override
int get hashCode {
  final _this = this as SourceCheckStageOutcome;
  return Object.hash(runtimeType,_this.stage,_this.status,_this.failureKind,_this.rulePath,_this.invalidGroup);
}

@override
String toString() {
  final _this = this as SourceCheckStageOutcome;
  return 'SourceCheckStageOutcome(stage: ${_this.stage}, status: ${_this.status}, failureKind: ${_this.failureKind}, rulePath: ${_this.rulePath}, invalidGroup: ${_this.invalidGroup})';
}


}




/// Adds pattern-matching-related methods to [SourceCheckStageOutcome].
extension SourceCheckStageOutcomePatterns on SourceCheckStageOutcome {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceCheckStageOutcome value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceCheckStageOutcome() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceCheckStageOutcome value)  $default,){
final _that = this;
switch (_that) {
case _SourceCheckStageOutcome():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceCheckStageOutcome value)?  $default,){
final _that = this;
switch (_that) {
case _SourceCheckStageOutcome() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SourceCheckStage stage,  SourceCheckStatus status,  ParseFailureKind? failureKind,  String? rulePath,  String? invalidGroup)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceCheckStageOutcome() when $default != null:
return $default(_that.stage,_that.status,_that.failureKind,_that.rulePath,_that.invalidGroup);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SourceCheckStage stage,  SourceCheckStatus status,  ParseFailureKind? failureKind,  String? rulePath,  String? invalidGroup)  $default,) {final _that = this;
switch (_that) {
case _SourceCheckStageOutcome():
return $default(_that.stage,_that.status,_that.failureKind,_that.rulePath,_that.invalidGroup);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SourceCheckStage stage,  SourceCheckStatus status,  ParseFailureKind? failureKind,  String? rulePath,  String? invalidGroup)?  $default,) {final _that = this;
switch (_that) {
case _SourceCheckStageOutcome() when $default != null:
return $default(_that.stage,_that.status,_that.failureKind,_that.rulePath,_that.invalidGroup);case _:
  return null;

}
}

}

/// @nodoc


class _SourceCheckStageOutcome implements SourceCheckStageOutcome {
  const _SourceCheckStageOutcome({required this.stage, required this.status, this.failureKind, this.rulePath, this.invalidGroup});
  

/// The stage this outcome belongs to.
@override final  SourceCheckStage stage;
/// Whether the stage was usable, failed or was skipped by a stop.
@override final  SourceCheckStatus status;
/// The failure kind the stage's `ParseResult` carried, when it failed.
@override final  ParseFailureKind? failureKind;
/// The rule path of the failure (`book-source.md` §7), when it failed.
@override final  String? rulePath;
/// The group token written into the source's group list, when it failed.
@override final  String? invalidGroup;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceCheckStageOutcome&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.status, status) || other.status == status)&&(identical(other.failureKind, failureKind) || other.failureKind == failureKind)&&(identical(other.rulePath, rulePath) || other.rulePath == rulePath)&&(identical(other.invalidGroup, invalidGroup) || other.invalidGroup == invalidGroup));
}


@override
int get hashCode {
    return Object.hash(runtimeType,stage,status,failureKind,rulePath,invalidGroup);
}

@override
String toString() {
    return 'SourceCheckStageOutcome(stage: $stage, status: $status, failureKind: $failureKind, rulePath: $rulePath, invalidGroup: $invalidGroup)';
}


}




/// @nodoc
mixin _$SourceCheckReport {

 SourceCheckStatus get status;/// One outcome per stage that actually ran, in [SourceCheckStage] order.
 List<SourceCheckStageOutcome> get stages;/// The group tokens this run should leave on the source (empty when it is healthy).
 List<String> get invalidGroups;/// The error note the run should leave in `bookSourceComment`, or `null` when healthy.
 String? get errorComment;/// How long the check took, which is what `respondTime` stores.
 int get elapsedMillis;



@override
bool operator ==(Object other) {
  final _this = this as SourceCheckReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceCheckReport&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.stages, _this.stages)&&const DeepCollectionEquality().equals(other.invalidGroups, _this.invalidGroups)&&(identical(other.errorComment, _this.errorComment) || other.errorComment == _this.errorComment)&&(identical(other.elapsedMillis, _this.elapsedMillis) || other.elapsedMillis == _this.elapsedMillis));
}


@override
int get hashCode {
  final _this = this as SourceCheckReport;
  return Object.hash(runtimeType,_this.status,const DeepCollectionEquality().hash(_this.stages),const DeepCollectionEquality().hash(_this.invalidGroups),_this.errorComment,_this.elapsedMillis);
}

@override
String toString() {
  final _this = this as SourceCheckReport;
  return 'SourceCheckReport(status: ${_this.status}, stages: ${_this.stages}, invalidGroups: ${_this.invalidGroups}, errorComment: ${_this.errorComment}, elapsedMillis: ${_this.elapsedMillis})';
}


}




/// Adds pattern-matching-related methods to [SourceCheckReport].
extension SourceCheckReportPatterns on SourceCheckReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceCheckReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceCheckReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceCheckReport value)  $default,){
final _that = this;
switch (_that) {
case _SourceCheckReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceCheckReport value)?  $default,){
final _that = this;
switch (_that) {
case _SourceCheckReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SourceCheckStatus status,  List<SourceCheckStageOutcome> stages,  List<String> invalidGroups,  String? errorComment,  int elapsedMillis)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceCheckReport() when $default != null:
return $default(_that.status,_that.stages,_that.invalidGroups,_that.errorComment,_that.elapsedMillis);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SourceCheckStatus status,  List<SourceCheckStageOutcome> stages,  List<String> invalidGroups,  String? errorComment,  int elapsedMillis)  $default,) {final _that = this;
switch (_that) {
case _SourceCheckReport():
return $default(_that.status,_that.stages,_that.invalidGroups,_that.errorComment,_that.elapsedMillis);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SourceCheckStatus status,  List<SourceCheckStageOutcome> stages,  List<String> invalidGroups,  String? errorComment,  int elapsedMillis)?  $default,) {final _that = this;
switch (_that) {
case _SourceCheckReport() when $default != null:
return $default(_that.status,_that.stages,_that.invalidGroups,_that.errorComment,_that.elapsedMillis);case _:
  return null;

}
}

}

/// @nodoc


class _SourceCheckReport implements SourceCheckReport {
  const _SourceCheckReport({required this.status,  List<SourceCheckStageOutcome> stages = const <SourceCheckStageOutcome>[],  List<String> invalidGroups = const <String>[], this.errorComment, required this.elapsedMillis}): _stages = stages,_invalidGroups = invalidGroups;
  

@override final  SourceCheckStatus status;
/// One outcome per stage that actually ran, in [SourceCheckStage] order.
 final  List<SourceCheckStageOutcome> _stages;
/// One outcome per stage that actually ran, in [SourceCheckStage] order.
@override@JsonKey() List<SourceCheckStageOutcome> get stages {
  if (_stages is EqualUnmodifiableListView) return _stages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stages);
}

/// The group tokens this run should leave on the source (empty when it is healthy).
 final  List<String> _invalidGroups;
/// The group tokens this run should leave on the source (empty when it is healthy).
@override@JsonKey() List<String> get invalidGroups {
  if (_invalidGroups is EqualUnmodifiableListView) return _invalidGroups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_invalidGroups);
}

/// The error note the run should leave in `bookSourceComment`, or `null` when healthy.
@override final  String? errorComment;
/// How long the check took, which is what `respondTime` stores.
@override final  int elapsedMillis;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceCheckReport&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.stages, _stages)&&const DeepCollectionEquality().equals(other.invalidGroups, _invalidGroups)&&(identical(other.errorComment, errorComment) || other.errorComment == errorComment)&&(identical(other.elapsedMillis, elapsedMillis) || other.elapsedMillis == elapsedMillis));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_stages),const DeepCollectionEquality().hash(_invalidGroups),errorComment,elapsedMillis);
}

@override
String toString() {
    return 'SourceCheckReport(status: $status, stages: $stages, invalidGroups: $invalidGroups, errorComment: $errorComment, elapsedMillis: $elapsedMillis)';
}


}




// dart format on
