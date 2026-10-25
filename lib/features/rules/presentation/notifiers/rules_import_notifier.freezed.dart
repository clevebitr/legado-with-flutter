// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rules_import_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RulesImportState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesImportState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'RulesImportState()';
}


}

/// @nodoc
class $RulesImportStateCopyWith<$Res>  {
$RulesImportStateCopyWith(RulesImportState _, $Res Function(RulesImportState) __);
}


/// Adds pattern-matching-related methods to [RulesImportState].
extension RulesImportStatePatterns on RulesImportState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RulesImportIdle value)?  idle,TResult Function( RulesImportImporting value)?  importing,TResult Function( RulesImportPreviewing value)?  preview,TResult Function( RulesImportCommitting value)?  committing,TResult Function( RulesImportDone value)?  done,TResult Function( RulesImportFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RulesImportIdle() when idle != null:
return idle(_that);case RulesImportImporting() when importing != null:
return importing(_that);case RulesImportPreviewing() when preview != null:
return preview(_that);case RulesImportCommitting() when committing != null:
return committing(_that);case RulesImportDone() when done != null:
return done(_that);case RulesImportFailed() when failed != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RulesImportIdle value)  idle,required TResult Function( RulesImportImporting value)  importing,required TResult Function( RulesImportPreviewing value)  preview,required TResult Function( RulesImportCommitting value)  committing,required TResult Function( RulesImportDone value)  done,required TResult Function( RulesImportFailed value)  failed,}){
final _that = this;
switch (_that) {
case RulesImportIdle():
return idle(_that);case RulesImportImporting():
return importing(_that);case RulesImportPreviewing():
return preview(_that);case RulesImportCommitting():
return committing(_that);case RulesImportDone():
return done(_that);case RulesImportFailed():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RulesImportIdle value)?  idle,TResult? Function( RulesImportImporting value)?  importing,TResult? Function( RulesImportPreviewing value)?  preview,TResult? Function( RulesImportCommitting value)?  committing,TResult? Function( RulesImportDone value)?  done,TResult? Function( RulesImportFailed value)?  failed,}){
final _that = this;
switch (_that) {
case RulesImportIdle() when idle != null:
return idle(_that);case RulesImportImporting() when importing != null:
return importing(_that);case RulesImportPreviewing() when preview != null:
return preview(_that);case RulesImportCommitting() when committing != null:
return committing(_that);case RulesImportDone() when done != null:
return done(_that);case RulesImportFailed() when failed != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  importing,TResult Function( ReplaceRuleImportPreview preview)?  preview,TResult Function()?  committing,TResult Function( ReplaceRuleImportReport report)?  done,TResult Function( ParseFailureKind kind)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RulesImportIdle() when idle != null:
return idle();case RulesImportImporting() when importing != null:
return importing();case RulesImportPreviewing() when preview != null:
return preview(_that.preview);case RulesImportCommitting() when committing != null:
return committing();case RulesImportDone() when done != null:
return done(_that.report);case RulesImportFailed() when failed != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  importing,required TResult Function( ReplaceRuleImportPreview preview)  preview,required TResult Function()  committing,required TResult Function( ReplaceRuleImportReport report)  done,required TResult Function( ParseFailureKind kind)  failed,}) {final _that = this;
switch (_that) {
case RulesImportIdle():
return idle();case RulesImportImporting():
return importing();case RulesImportPreviewing():
return preview(_that.preview);case RulesImportCommitting():
return committing();case RulesImportDone():
return done(_that.report);case RulesImportFailed():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  importing,TResult? Function( ReplaceRuleImportPreview preview)?  preview,TResult? Function()?  committing,TResult? Function( ReplaceRuleImportReport report)?  done,TResult? Function( ParseFailureKind kind)?  failed,}) {final _that = this;
switch (_that) {
case RulesImportIdle() when idle != null:
return idle();case RulesImportImporting() when importing != null:
return importing();case RulesImportPreviewing() when preview != null:
return preview(_that.preview);case RulesImportCommitting() when committing != null:
return committing();case RulesImportDone() when done != null:
return done(_that.report);case RulesImportFailed() when failed != null:
return failed(_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class RulesImportIdle implements RulesImportState {
  const RulesImportIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesImportIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'RulesImportState.idle()';
}


}




/// @nodoc


class RulesImportImporting implements RulesImportState {
  const RulesImportImporting();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesImportImporting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'RulesImportState.importing()';
}


}




/// @nodoc


class RulesImportPreviewing implements RulesImportState {
  const RulesImportPreviewing(this.preview);
  

 final  ReplaceRuleImportPreview preview;

/// Create a copy of RulesImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RulesImportPreviewingCopyWith<RulesImportPreviewing> get copyWith => _$RulesImportPreviewingCopyWithImpl<RulesImportPreviewing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesImportPreviewing&&(identical(other.preview, preview) || other.preview == preview));
}


@override
int get hashCode {
    return Object.hash(runtimeType,preview);
}

@override
String toString() {
    return 'RulesImportState.preview(preview: $preview)';
}


}

/// @nodoc
abstract mixin class $RulesImportPreviewingCopyWith<$Res> implements $RulesImportStateCopyWith<$Res> {
  factory $RulesImportPreviewingCopyWith(RulesImportPreviewing value, $Res Function(RulesImportPreviewing) _then) = _$RulesImportPreviewingCopyWithImpl;
@useResult
$Res call({
 ReplaceRuleImportPreview preview
});


$ReplaceRuleImportPreviewCopyWith<$Res> get preview;

}
/// @nodoc
class _$RulesImportPreviewingCopyWithImpl<$Res>
    implements $RulesImportPreviewingCopyWith<$Res> {
  _$RulesImportPreviewingCopyWithImpl(this._self, this._then);

  final RulesImportPreviewing _self;
  final $Res Function(RulesImportPreviewing) _then;

/// Create a copy of RulesImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? preview = null,}) {
  return _then(RulesImportPreviewing(
null == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as ReplaceRuleImportPreview,
  ));
}

/// Create a copy of RulesImportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReplaceRuleImportPreviewCopyWith<$Res> get preview {
  
  return $ReplaceRuleImportPreviewCopyWith<$Res>(_self.preview, (value) {
    return _then(_self.copyWith(preview: value));
  });
}
}

/// @nodoc


class RulesImportCommitting implements RulesImportState {
  const RulesImportCommitting();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesImportCommitting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'RulesImportState.committing()';
}


}




/// @nodoc


class RulesImportDone implements RulesImportState {
  const RulesImportDone(this.report);
  

 final  ReplaceRuleImportReport report;

/// Create a copy of RulesImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RulesImportDoneCopyWith<RulesImportDone> get copyWith => _$RulesImportDoneCopyWithImpl<RulesImportDone>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesImportDone&&(identical(other.report, report) || other.report == report));
}


@override
int get hashCode {
    return Object.hash(runtimeType,report);
}

@override
String toString() {
    return 'RulesImportState.done(report: $report)';
}


}

/// @nodoc
abstract mixin class $RulesImportDoneCopyWith<$Res> implements $RulesImportStateCopyWith<$Res> {
  factory $RulesImportDoneCopyWith(RulesImportDone value, $Res Function(RulesImportDone) _then) = _$RulesImportDoneCopyWithImpl;
@useResult
$Res call({
 ReplaceRuleImportReport report
});


$ReplaceRuleImportReportCopyWith<$Res> get report;

}
/// @nodoc
class _$RulesImportDoneCopyWithImpl<$Res>
    implements $RulesImportDoneCopyWith<$Res> {
  _$RulesImportDoneCopyWithImpl(this._self, this._then);

  final RulesImportDone _self;
  final $Res Function(RulesImportDone) _then;

/// Create a copy of RulesImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? report = null,}) {
  return _then(RulesImportDone(
null == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as ReplaceRuleImportReport,
  ));
}

/// Create a copy of RulesImportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReplaceRuleImportReportCopyWith<$Res> get report {
  
  return $ReplaceRuleImportReportCopyWith<$Res>(_self.report, (value) {
    return _then(_self.copyWith(report: value));
  });
}
}

/// @nodoc


class RulesImportFailed implements RulesImportState {
  const RulesImportFailed(this.kind);
  

 final  ParseFailureKind kind;

/// Create a copy of RulesImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RulesImportFailedCopyWith<RulesImportFailed> get copyWith => _$RulesImportFailedCopyWithImpl<RulesImportFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesImportFailed&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind);
}

@override
String toString() {
    return 'RulesImportState.failed(kind: $kind)';
}


}

/// @nodoc
abstract mixin class $RulesImportFailedCopyWith<$Res> implements $RulesImportStateCopyWith<$Res> {
  factory $RulesImportFailedCopyWith(RulesImportFailed value, $Res Function(RulesImportFailed) _then) = _$RulesImportFailedCopyWithImpl;
@useResult
$Res call({
 ParseFailureKind kind
});




}
/// @nodoc
class _$RulesImportFailedCopyWithImpl<$Res>
    implements $RulesImportFailedCopyWith<$Res> {
  _$RulesImportFailedCopyWithImpl(this._self, this._then);

  final RulesImportFailed _self;
  final $Res Function(RulesImportFailed) _then;

/// Create a copy of RulesImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,}) {
  return _then(RulesImportFailed(
null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind,
  ));
}


}

// dart format on
