// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'backup_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BackupState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BackupState()';
}


}

/// @nodoc
class $BackupStateCopyWith<$Res>  {
$BackupStateCopyWith(BackupState _, $Res Function(BackupState) __);
}


/// Adds pattern-matching-related methods to [BackupState].
extension BackupStatePatterns on BackupState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BackupIdle value)?  idle,TResult Function( BackupWorking value)?  working,TResult Function( BackupPreviewReady value)?  previewReady,TResult Function( BackupExported value)?  exported,TResult Function( BackupRestored value)?  restored,TResult Function( BackupFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BackupIdle() when idle != null:
return idle(_that);case BackupWorking() when working != null:
return working(_that);case BackupPreviewReady() when previewReady != null:
return previewReady(_that);case BackupExported() when exported != null:
return exported(_that);case BackupRestored() when restored != null:
return restored(_that);case BackupFailed() when failed != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BackupIdle value)  idle,required TResult Function( BackupWorking value)  working,required TResult Function( BackupPreviewReady value)  previewReady,required TResult Function( BackupExported value)  exported,required TResult Function( BackupRestored value)  restored,required TResult Function( BackupFailed value)  failed,}){
final _that = this;
switch (_that) {
case BackupIdle():
return idle(_that);case BackupWorking():
return working(_that);case BackupPreviewReady():
return previewReady(_that);case BackupExported():
return exported(_that);case BackupRestored():
return restored(_that);case BackupFailed():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BackupIdle value)?  idle,TResult? Function( BackupWorking value)?  working,TResult? Function( BackupPreviewReady value)?  previewReady,TResult? Function( BackupExported value)?  exported,TResult? Function( BackupRestored value)?  restored,TResult? Function( BackupFailed value)?  failed,}){
final _that = this;
switch (_that) {
case BackupIdle() when idle != null:
return idle(_that);case BackupWorking() when working != null:
return working(_that);case BackupPreviewReady() when previewReady != null:
return previewReady(_that);case BackupExported() when exported != null:
return exported(_that);case BackupRestored() when restored != null:
return restored(_that);case BackupFailed() when failed != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( BackupAction action)?  working,TResult Function( BackupPreview preview,  List<int> bytes)?  previewReady,TResult Function( String fileName,  int totalRows)?  exported,TResult Function( BackupRestoreReport report)?  restored,TResult Function( ParseFailureKind kind)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BackupIdle() when idle != null:
return idle();case BackupWorking() when working != null:
return working(_that.action);case BackupPreviewReady() when previewReady != null:
return previewReady(_that.preview,_that.bytes);case BackupExported() when exported != null:
return exported(_that.fileName,_that.totalRows);case BackupRestored() when restored != null:
return restored(_that.report);case BackupFailed() when failed != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( BackupAction action)  working,required TResult Function( BackupPreview preview,  List<int> bytes)  previewReady,required TResult Function( String fileName,  int totalRows)  exported,required TResult Function( BackupRestoreReport report)  restored,required TResult Function( ParseFailureKind kind)  failed,}) {final _that = this;
switch (_that) {
case BackupIdle():
return idle();case BackupWorking():
return working(_that.action);case BackupPreviewReady():
return previewReady(_that.preview,_that.bytes);case BackupExported():
return exported(_that.fileName,_that.totalRows);case BackupRestored():
return restored(_that.report);case BackupFailed():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( BackupAction action)?  working,TResult? Function( BackupPreview preview,  List<int> bytes)?  previewReady,TResult? Function( String fileName,  int totalRows)?  exported,TResult? Function( BackupRestoreReport report)?  restored,TResult? Function( ParseFailureKind kind)?  failed,}) {final _that = this;
switch (_that) {
case BackupIdle() when idle != null:
return idle();case BackupWorking() when working != null:
return working(_that.action);case BackupPreviewReady() when previewReady != null:
return previewReady(_that.preview,_that.bytes);case BackupExported() when exported != null:
return exported(_that.fileName,_that.totalRows);case BackupRestored() when restored != null:
return restored(_that.report);case BackupFailed() when failed != null:
return failed(_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class BackupIdle implements BackupState {
  const BackupIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BackupState.idle()';
}


}




/// @nodoc


class BackupWorking implements BackupState {
  const BackupWorking(this.action);
  

 final  BackupAction action;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupWorkingCopyWith<BackupWorking> get copyWith => _$BackupWorkingCopyWithImpl<BackupWorking>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupWorking&&(identical(other.action, action) || other.action == action));
}


@override
int get hashCode {
    return Object.hash(runtimeType,action);
}

@override
String toString() {
    return 'BackupState.working(action: $action)';
}


}

/// @nodoc
abstract mixin class $BackupWorkingCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupWorkingCopyWith(BackupWorking value, $Res Function(BackupWorking) _then) = _$BackupWorkingCopyWithImpl;
@useResult
$Res call({
 BackupAction action
});




}
/// @nodoc
class _$BackupWorkingCopyWithImpl<$Res>
    implements $BackupWorkingCopyWith<$Res> {
  _$BackupWorkingCopyWithImpl(this._self, this._then);

  final BackupWorking _self;
  final $Res Function(BackupWorking) _then;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? action = null,}) {
  return _then(BackupWorking(
null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as BackupAction,
  ));
}


}

/// @nodoc


class BackupPreviewReady implements BackupState {
  const BackupPreviewReady({required this.preview, required  List<int> bytes}): _bytes = bytes;
  

 final  BackupPreview preview;
 final  List<int> _bytes;
 List<int> get bytes {
  if (_bytes is EqualUnmodifiableListView) return _bytes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bytes);
}


/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupPreviewReadyCopyWith<BackupPreviewReady> get copyWith => _$BackupPreviewReadyCopyWithImpl<BackupPreviewReady>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupPreviewReady&&(identical(other.preview, preview) || other.preview == preview)&&const DeepCollectionEquality().equals(other.bytes, _bytes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,preview,const DeepCollectionEquality().hash(_bytes));
}

@override
String toString() {
    return 'BackupState.previewReady(preview: $preview, bytes: $bytes)';
}


}

/// @nodoc
abstract mixin class $BackupPreviewReadyCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupPreviewReadyCopyWith(BackupPreviewReady value, $Res Function(BackupPreviewReady) _then) = _$BackupPreviewReadyCopyWithImpl;
@useResult
$Res call({
 BackupPreview preview, List<int> bytes
});




}
/// @nodoc
class _$BackupPreviewReadyCopyWithImpl<$Res>
    implements $BackupPreviewReadyCopyWith<$Res> {
  _$BackupPreviewReadyCopyWithImpl(this._self, this._then);

  final BackupPreviewReady _self;
  final $Res Function(BackupPreviewReady) _then;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? preview = null,Object? bytes = null,}) {
  return _then(BackupPreviewReady(
preview: null == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as BackupPreview,bytes: null == bytes ? _self._bytes : bytes // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

/// @nodoc


class BackupExported implements BackupState {
  const BackupExported({required this.fileName, required this.totalRows});
  

 final  String fileName;
 final  int totalRows;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupExportedCopyWith<BackupExported> get copyWith => _$BackupExportedCopyWithImpl<BackupExported>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupExported&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.totalRows, totalRows) || other.totalRows == totalRows));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fileName,totalRows);
}

@override
String toString() {
    return 'BackupState.exported(fileName: $fileName, totalRows: $totalRows)';
}


}

/// @nodoc
abstract mixin class $BackupExportedCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupExportedCopyWith(BackupExported value, $Res Function(BackupExported) _then) = _$BackupExportedCopyWithImpl;
@useResult
$Res call({
 String fileName, int totalRows
});




}
/// @nodoc
class _$BackupExportedCopyWithImpl<$Res>
    implements $BackupExportedCopyWith<$Res> {
  _$BackupExportedCopyWithImpl(this._self, this._then);

  final BackupExported _self;
  final $Res Function(BackupExported) _then;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? fileName = null,Object? totalRows = null,}) {
  return _then(BackupExported(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,totalRows: null == totalRows ? _self.totalRows : totalRows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class BackupRestored implements BackupState {
  const BackupRestored(this.report);
  

 final  BackupRestoreReport report;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupRestoredCopyWith<BackupRestored> get copyWith => _$BackupRestoredCopyWithImpl<BackupRestored>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupRestored&&(identical(other.report, report) || other.report == report));
}


@override
int get hashCode {
    return Object.hash(runtimeType,report);
}

@override
String toString() {
    return 'BackupState.restored(report: $report)';
}


}

/// @nodoc
abstract mixin class $BackupRestoredCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupRestoredCopyWith(BackupRestored value, $Res Function(BackupRestored) _then) = _$BackupRestoredCopyWithImpl;
@useResult
$Res call({
 BackupRestoreReport report
});




}
/// @nodoc
class _$BackupRestoredCopyWithImpl<$Res>
    implements $BackupRestoredCopyWith<$Res> {
  _$BackupRestoredCopyWithImpl(this._self, this._then);

  final BackupRestored _self;
  final $Res Function(BackupRestored) _then;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? report = null,}) {
  return _then(BackupRestored(
null == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as BackupRestoreReport,
  ));
}


}

/// @nodoc


class BackupFailed implements BackupState {
  const BackupFailed(this.kind);
  

 final  ParseFailureKind kind;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupFailedCopyWith<BackupFailed> get copyWith => _$BackupFailedCopyWithImpl<BackupFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupFailed&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind);
}

@override
String toString() {
    return 'BackupState.failed(kind: $kind)';
}


}

/// @nodoc
abstract mixin class $BackupFailedCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupFailedCopyWith(BackupFailed value, $Res Function(BackupFailed) _then) = _$BackupFailedCopyWithImpl;
@useResult
$Res call({
 ParseFailureKind kind
});




}
/// @nodoc
class _$BackupFailedCopyWithImpl<$Res>
    implements $BackupFailedCopyWith<$Res> {
  _$BackupFailedCopyWithImpl(this._self, this._then);

  final BackupFailed _self;
  final $Res Function(BackupFailed) _then;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,}) {
  return _then(BackupFailed(
null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind,
  ));
}


}

// dart format on
