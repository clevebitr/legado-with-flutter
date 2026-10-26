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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BackupIdle value)?  idle,TResult Function( BackupWorking value)?  working,TResult Function( BackupPreviewReady value)?  previewReady,TResult Function( BackupPasswordNeeded value)?  passwordNeeded,TResult Function( BackupExported value)?  exported,TResult Function( BackupRestored value)?  restored,TResult Function( BackupRemoteListed value)?  remoteListed,TResult Function( BackupFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BackupIdle() when idle != null:
return idle(_that);case BackupWorking() when working != null:
return working(_that);case BackupPreviewReady() when previewReady != null:
return previewReady(_that);case BackupPasswordNeeded() when passwordNeeded != null:
return passwordNeeded(_that);case BackupExported() when exported != null:
return exported(_that);case BackupRestored() when restored != null:
return restored(_that);case BackupRemoteListed() when remoteListed != null:
return remoteListed(_that);case BackupFailed() when failed != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BackupIdle value)  idle,required TResult Function( BackupWorking value)  working,required TResult Function( BackupPreviewReady value)  previewReady,required TResult Function( BackupPasswordNeeded value)  passwordNeeded,required TResult Function( BackupExported value)  exported,required TResult Function( BackupRestored value)  restored,required TResult Function( BackupRemoteListed value)  remoteListed,required TResult Function( BackupFailed value)  failed,}){
final _that = this;
switch (_that) {
case BackupIdle():
return idle(_that);case BackupWorking():
return working(_that);case BackupPreviewReady():
return previewReady(_that);case BackupPasswordNeeded():
return passwordNeeded(_that);case BackupExported():
return exported(_that);case BackupRestored():
return restored(_that);case BackupRemoteListed():
return remoteListed(_that);case BackupFailed():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BackupIdle value)?  idle,TResult? Function( BackupWorking value)?  working,TResult? Function( BackupPreviewReady value)?  previewReady,TResult? Function( BackupPasswordNeeded value)?  passwordNeeded,TResult? Function( BackupExported value)?  exported,TResult? Function( BackupRestored value)?  restored,TResult? Function( BackupRemoteListed value)?  remoteListed,TResult? Function( BackupFailed value)?  failed,}){
final _that = this;
switch (_that) {
case BackupIdle() when idle != null:
return idle(_that);case BackupWorking() when working != null:
return working(_that);case BackupPreviewReady() when previewReady != null:
return previewReady(_that);case BackupPasswordNeeded() when passwordNeeded != null:
return passwordNeeded(_that);case BackupExported() when exported != null:
return exported(_that);case BackupRestored() when restored != null:
return restored(_that);case BackupRemoteListed() when remoteListed != null:
return remoteListed(_that);case BackupFailed() when failed != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( BackupAction action)?  working,TResult Function( BackupPreview preview,  List<int> bytes,  bool isRemote)?  previewReady,TResult Function( List<int> bytes,  bool isRetry,  bool isRemote)?  passwordNeeded,TResult Function( String fileName,  int totalRows,  String path)?  exported,TResult Function( RestoreOutcome outcome)?  restored,TResult Function( List<RemoteBackup> backups)?  remoteListed,TResult Function( ParseFailureKind kind)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BackupIdle() when idle != null:
return idle();case BackupWorking() when working != null:
return working(_that.action);case BackupPreviewReady() when previewReady != null:
return previewReady(_that.preview,_that.bytes,_that.isRemote);case BackupPasswordNeeded() when passwordNeeded != null:
return passwordNeeded(_that.bytes,_that.isRetry,_that.isRemote);case BackupExported() when exported != null:
return exported(_that.fileName,_that.totalRows,_that.path);case BackupRestored() when restored != null:
return restored(_that.outcome);case BackupRemoteListed() when remoteListed != null:
return remoteListed(_that.backups);case BackupFailed() when failed != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( BackupAction action)  working,required TResult Function( BackupPreview preview,  List<int> bytes,  bool isRemote)  previewReady,required TResult Function( List<int> bytes,  bool isRetry,  bool isRemote)  passwordNeeded,required TResult Function( String fileName,  int totalRows,  String path)  exported,required TResult Function( RestoreOutcome outcome)  restored,required TResult Function( List<RemoteBackup> backups)  remoteListed,required TResult Function( ParseFailureKind kind)  failed,}) {final _that = this;
switch (_that) {
case BackupIdle():
return idle();case BackupWorking():
return working(_that.action);case BackupPreviewReady():
return previewReady(_that.preview,_that.bytes,_that.isRemote);case BackupPasswordNeeded():
return passwordNeeded(_that.bytes,_that.isRetry,_that.isRemote);case BackupExported():
return exported(_that.fileName,_that.totalRows,_that.path);case BackupRestored():
return restored(_that.outcome);case BackupRemoteListed():
return remoteListed(_that.backups);case BackupFailed():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( BackupAction action)?  working,TResult? Function( BackupPreview preview,  List<int> bytes,  bool isRemote)?  previewReady,TResult? Function( List<int> bytes,  bool isRetry,  bool isRemote)?  passwordNeeded,TResult? Function( String fileName,  int totalRows,  String path)?  exported,TResult? Function( RestoreOutcome outcome)?  restored,TResult? Function( List<RemoteBackup> backups)?  remoteListed,TResult? Function( ParseFailureKind kind)?  failed,}) {final _that = this;
switch (_that) {
case BackupIdle() when idle != null:
return idle();case BackupWorking() when working != null:
return working(_that.action);case BackupPreviewReady() when previewReady != null:
return previewReady(_that.preview,_that.bytes,_that.isRemote);case BackupPasswordNeeded() when passwordNeeded != null:
return passwordNeeded(_that.bytes,_that.isRetry,_that.isRemote);case BackupExported() when exported != null:
return exported(_that.fileName,_that.totalRows,_that.path);case BackupRestored() when restored != null:
return restored(_that.outcome);case BackupRemoteListed() when remoteListed != null:
return remoteListed(_that.backups);case BackupFailed() when failed != null:
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
  const BackupPreviewReady({required this.preview, required  List<int> bytes, this.isRemote = false}): _bytes = bytes;
  

 final  BackupPreview preview;
 final  List<int> _bytes;
 List<int> get bytes {
  if (_bytes is EqualUnmodifiableListView) return _bytes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bytes);
}

@JsonKey() final  bool isRemote;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupPreviewReadyCopyWith<BackupPreviewReady> get copyWith => _$BackupPreviewReadyCopyWithImpl<BackupPreviewReady>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupPreviewReady&&(identical(other.preview, preview) || other.preview == preview)&&const DeepCollectionEquality().equals(other.bytes, _bytes)&&(identical(other.isRemote, isRemote) || other.isRemote == isRemote));
}


@override
int get hashCode {
    return Object.hash(runtimeType,preview,const DeepCollectionEquality().hash(_bytes),isRemote);
}

@override
String toString() {
    return 'BackupState.previewReady(preview: $preview, bytes: $bytes, isRemote: $isRemote)';
}


}

/// @nodoc
abstract mixin class $BackupPreviewReadyCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupPreviewReadyCopyWith(BackupPreviewReady value, $Res Function(BackupPreviewReady) _then) = _$BackupPreviewReadyCopyWithImpl;
@useResult
$Res call({
 BackupPreview preview, List<int> bytes, bool isRemote
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
@pragma('vm:prefer-inline') $Res call({Object? preview = null,Object? bytes = null,Object? isRemote = null,}) {
  return _then(BackupPreviewReady(
preview: null == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as BackupPreview,bytes: null == bytes ? _self._bytes : bytes // ignore: cast_nullable_to_non_nullable
as List<int>,isRemote: null == isRemote ? _self.isRemote : isRemote // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class BackupPasswordNeeded implements BackupState {
  const BackupPasswordNeeded({required  List<int> bytes, this.isRetry = false, this.isRemote = false}): _bytes = bytes;
  

 final  List<int> _bytes;
 List<int> get bytes {
  if (_bytes is EqualUnmodifiableListView) return _bytes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bytes);
}

@JsonKey() final  bool isRetry;
@JsonKey() final  bool isRemote;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupPasswordNeededCopyWith<BackupPasswordNeeded> get copyWith => _$BackupPasswordNeededCopyWithImpl<BackupPasswordNeeded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupPasswordNeeded&&const DeepCollectionEquality().equals(other.bytes, _bytes)&&(identical(other.isRetry, isRetry) || other.isRetry == isRetry)&&(identical(other.isRemote, isRemote) || other.isRemote == isRemote));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_bytes),isRetry,isRemote);
}

@override
String toString() {
    return 'BackupState.passwordNeeded(bytes: $bytes, isRetry: $isRetry, isRemote: $isRemote)';
}


}

/// @nodoc
abstract mixin class $BackupPasswordNeededCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupPasswordNeededCopyWith(BackupPasswordNeeded value, $Res Function(BackupPasswordNeeded) _then) = _$BackupPasswordNeededCopyWithImpl;
@useResult
$Res call({
 List<int> bytes, bool isRetry, bool isRemote
});




}
/// @nodoc
class _$BackupPasswordNeededCopyWithImpl<$Res>
    implements $BackupPasswordNeededCopyWith<$Res> {
  _$BackupPasswordNeededCopyWithImpl(this._self, this._then);

  final BackupPasswordNeeded _self;
  final $Res Function(BackupPasswordNeeded) _then;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bytes = null,Object? isRetry = null,Object? isRemote = null,}) {
  return _then(BackupPasswordNeeded(
bytes: null == bytes ? _self._bytes : bytes // ignore: cast_nullable_to_non_nullable
as List<int>,isRetry: null == isRetry ? _self.isRetry : isRetry // ignore: cast_nullable_to_non_nullable
as bool,isRemote: null == isRemote ? _self.isRemote : isRemote // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class BackupExported implements BackupState {
  const BackupExported({required this.fileName, required this.totalRows, required this.path});
  

 final  String fileName;
 final  int totalRows;
 final  String path;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupExportedCopyWith<BackupExported> get copyWith => _$BackupExportedCopyWithImpl<BackupExported>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupExported&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.totalRows, totalRows) || other.totalRows == totalRows)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fileName,totalRows,path);
}

@override
String toString() {
    return 'BackupState.exported(fileName: $fileName, totalRows: $totalRows, path: $path)';
}


}

/// @nodoc
abstract mixin class $BackupExportedCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupExportedCopyWith(BackupExported value, $Res Function(BackupExported) _then) = _$BackupExportedCopyWithImpl;
@useResult
$Res call({
 String fileName, int totalRows, String path
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
@pragma('vm:prefer-inline') $Res call({Object? fileName = null,Object? totalRows = null,Object? path = null,}) {
  return _then(BackupExported(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,totalRows: null == totalRows ? _self.totalRows : totalRows // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class BackupRestored implements BackupState {
  const BackupRestored(this.outcome);
  

 final  RestoreOutcome outcome;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupRestoredCopyWith<BackupRestored> get copyWith => _$BackupRestoredCopyWithImpl<BackupRestored>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupRestored&&(identical(other.outcome, outcome) || other.outcome == outcome));
}


@override
int get hashCode {
    return Object.hash(runtimeType,outcome);
}

@override
String toString() {
    return 'BackupState.restored(outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class $BackupRestoredCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupRestoredCopyWith(BackupRestored value, $Res Function(BackupRestored) _then) = _$BackupRestoredCopyWithImpl;
@useResult
$Res call({
 RestoreOutcome outcome
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
@pragma('vm:prefer-inline') $Res call({Object? outcome = null,}) {
  return _then(BackupRestored(
null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as RestoreOutcome,
  ));
}


}

/// @nodoc


class BackupRemoteListed implements BackupState {
  const BackupRemoteListed( List<RemoteBackup> backups): _backups = backups;
  

 final  List<RemoteBackup> _backups;
 List<RemoteBackup> get backups {
  if (_backups is EqualUnmodifiableListView) return _backups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_backups);
}


/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupRemoteListedCopyWith<BackupRemoteListed> get copyWith => _$BackupRemoteListedCopyWithImpl<BackupRemoteListed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupRemoteListed&&const DeepCollectionEquality().equals(other.backups, _backups));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_backups));
}

@override
String toString() {
    return 'BackupState.remoteListed(backups: $backups)';
}


}

/// @nodoc
abstract mixin class $BackupRemoteListedCopyWith<$Res> implements $BackupStateCopyWith<$Res> {
  factory $BackupRemoteListedCopyWith(BackupRemoteListed value, $Res Function(BackupRemoteListed) _then) = _$BackupRemoteListedCopyWithImpl;
@useResult
$Res call({
 List<RemoteBackup> backups
});




}
/// @nodoc
class _$BackupRemoteListedCopyWithImpl<$Res>
    implements $BackupRemoteListedCopyWith<$Res> {
  _$BackupRemoteListedCopyWithImpl(this._self, this._then);

  final BackupRemoteListed _self;
  final $Res Function(BackupRemoteListed) _then;

/// Create a copy of BackupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? backups = null,}) {
  return _then(BackupRemoteListed(
null == backups ? _self._backups : backups // ignore: cast_nullable_to_non_nullable
as List<RemoteBackup>,
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
