// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_source_import_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookSourceImportState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImportState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceImportState()';
}


}

/// @nodoc
class $BookSourceImportStateCopyWith<$Res>  {
$BookSourceImportStateCopyWith(BookSourceImportState _, $Res Function(BookSourceImportState) __);
}


/// Adds pattern-matching-related methods to [BookSourceImportState].
extension BookSourceImportStatePatterns on BookSourceImportState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BookSourceImportIdle value)?  idle,TResult Function( BookSourceImporting value)?  importing,TResult Function( BookSourceImportPreviewing value)?  preview,TResult Function( BookSourceImportCommitting value)?  committing,TResult Function( BookSourceImportDone value)?  done,TResult Function( BookSourceImportFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BookSourceImportIdle() when idle != null:
return idle(_that);case BookSourceImporting() when importing != null:
return importing(_that);case BookSourceImportPreviewing() when preview != null:
return preview(_that);case BookSourceImportCommitting() when committing != null:
return committing(_that);case BookSourceImportDone() when done != null:
return done(_that);case BookSourceImportFailed() when failed != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BookSourceImportIdle value)  idle,required TResult Function( BookSourceImporting value)  importing,required TResult Function( BookSourceImportPreviewing value)  preview,required TResult Function( BookSourceImportCommitting value)  committing,required TResult Function( BookSourceImportDone value)  done,required TResult Function( BookSourceImportFailed value)  failed,}){
final _that = this;
switch (_that) {
case BookSourceImportIdle():
return idle(_that);case BookSourceImporting():
return importing(_that);case BookSourceImportPreviewing():
return preview(_that);case BookSourceImportCommitting():
return committing(_that);case BookSourceImportDone():
return done(_that);case BookSourceImportFailed():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BookSourceImportIdle value)?  idle,TResult? Function( BookSourceImporting value)?  importing,TResult? Function( BookSourceImportPreviewing value)?  preview,TResult? Function( BookSourceImportCommitting value)?  committing,TResult? Function( BookSourceImportDone value)?  done,TResult? Function( BookSourceImportFailed value)?  failed,}){
final _that = this;
switch (_that) {
case BookSourceImportIdle() when idle != null:
return idle(_that);case BookSourceImporting() when importing != null:
return importing(_that);case BookSourceImportPreviewing() when preview != null:
return preview(_that);case BookSourceImportCommitting() when committing != null:
return committing(_that);case BookSourceImportDone() when done != null:
return done(_that);case BookSourceImportFailed() when failed != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  importing,TResult Function( BookSourceImportPreview preview)?  preview,TResult Function()?  committing,TResult Function( BookSourceImportReport report)?  done,TResult Function( ParseFailureKind kind)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BookSourceImportIdle() when idle != null:
return idle();case BookSourceImporting() when importing != null:
return importing();case BookSourceImportPreviewing() when preview != null:
return preview(_that.preview);case BookSourceImportCommitting() when committing != null:
return committing();case BookSourceImportDone() when done != null:
return done(_that.report);case BookSourceImportFailed() when failed != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  importing,required TResult Function( BookSourceImportPreview preview)  preview,required TResult Function()  committing,required TResult Function( BookSourceImportReport report)  done,required TResult Function( ParseFailureKind kind)  failed,}) {final _that = this;
switch (_that) {
case BookSourceImportIdle():
return idle();case BookSourceImporting():
return importing();case BookSourceImportPreviewing():
return preview(_that.preview);case BookSourceImportCommitting():
return committing();case BookSourceImportDone():
return done(_that.report);case BookSourceImportFailed():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  importing,TResult? Function( BookSourceImportPreview preview)?  preview,TResult? Function()?  committing,TResult? Function( BookSourceImportReport report)?  done,TResult? Function( ParseFailureKind kind)?  failed,}) {final _that = this;
switch (_that) {
case BookSourceImportIdle() when idle != null:
return idle();case BookSourceImporting() when importing != null:
return importing();case BookSourceImportPreviewing() when preview != null:
return preview(_that.preview);case BookSourceImportCommitting() when committing != null:
return committing();case BookSourceImportDone() when done != null:
return done(_that.report);case BookSourceImportFailed() when failed != null:
return failed(_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class BookSourceImportIdle implements BookSourceImportState {
  const BookSourceImportIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImportIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceImportState.idle()';
}


}




/// @nodoc


class BookSourceImporting implements BookSourceImportState {
  const BookSourceImporting();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImporting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceImportState.importing()';
}


}




/// @nodoc


class BookSourceImportPreviewing implements BookSourceImportState {
  const BookSourceImportPreviewing(this.preview);
  

 final  BookSourceImportPreview preview;

/// Create a copy of BookSourceImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSourceImportPreviewingCopyWith<BookSourceImportPreviewing> get copyWith => _$BookSourceImportPreviewingCopyWithImpl<BookSourceImportPreviewing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImportPreviewing&&(identical(other.preview, preview) || other.preview == preview));
}


@override
int get hashCode {
    return Object.hash(runtimeType,preview);
}

@override
String toString() {
    return 'BookSourceImportState.preview(preview: $preview)';
}


}

/// @nodoc
abstract mixin class $BookSourceImportPreviewingCopyWith<$Res> implements $BookSourceImportStateCopyWith<$Res> {
  factory $BookSourceImportPreviewingCopyWith(BookSourceImportPreviewing value, $Res Function(BookSourceImportPreviewing) _then) = _$BookSourceImportPreviewingCopyWithImpl;
@useResult
$Res call({
 BookSourceImportPreview preview
});




}
/// @nodoc
class _$BookSourceImportPreviewingCopyWithImpl<$Res>
    implements $BookSourceImportPreviewingCopyWith<$Res> {
  _$BookSourceImportPreviewingCopyWithImpl(this._self, this._then);

  final BookSourceImportPreviewing _self;
  final $Res Function(BookSourceImportPreviewing) _then;

/// Create a copy of BookSourceImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? preview = null,}) {
  return _then(BookSourceImportPreviewing(
null == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as BookSourceImportPreview,
  ));
}


}

/// @nodoc


class BookSourceImportCommitting implements BookSourceImportState {
  const BookSourceImportCommitting();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImportCommitting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSourceImportState.committing()';
}


}




/// @nodoc


class BookSourceImportDone implements BookSourceImportState {
  const BookSourceImportDone(this.report);
  

 final  BookSourceImportReport report;

/// Create a copy of BookSourceImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSourceImportDoneCopyWith<BookSourceImportDone> get copyWith => _$BookSourceImportDoneCopyWithImpl<BookSourceImportDone>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImportDone&&(identical(other.report, report) || other.report == report));
}


@override
int get hashCode {
    return Object.hash(runtimeType,report);
}

@override
String toString() {
    return 'BookSourceImportState.done(report: $report)';
}


}

/// @nodoc
abstract mixin class $BookSourceImportDoneCopyWith<$Res> implements $BookSourceImportStateCopyWith<$Res> {
  factory $BookSourceImportDoneCopyWith(BookSourceImportDone value, $Res Function(BookSourceImportDone) _then) = _$BookSourceImportDoneCopyWithImpl;
@useResult
$Res call({
 BookSourceImportReport report
});




}
/// @nodoc
class _$BookSourceImportDoneCopyWithImpl<$Res>
    implements $BookSourceImportDoneCopyWith<$Res> {
  _$BookSourceImportDoneCopyWithImpl(this._self, this._then);

  final BookSourceImportDone _self;
  final $Res Function(BookSourceImportDone) _then;

/// Create a copy of BookSourceImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? report = null,}) {
  return _then(BookSourceImportDone(
null == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as BookSourceImportReport,
  ));
}


}

/// @nodoc


class BookSourceImportFailed implements BookSourceImportState {
  const BookSourceImportFailed(this.kind);
  

 final  ParseFailureKind kind;

/// Create a copy of BookSourceImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSourceImportFailedCopyWith<BookSourceImportFailed> get copyWith => _$BookSourceImportFailedCopyWithImpl<BookSourceImportFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImportFailed&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind);
}

@override
String toString() {
    return 'BookSourceImportState.failed(kind: $kind)';
}


}

/// @nodoc
abstract mixin class $BookSourceImportFailedCopyWith<$Res> implements $BookSourceImportStateCopyWith<$Res> {
  factory $BookSourceImportFailedCopyWith(BookSourceImportFailed value, $Res Function(BookSourceImportFailed) _then) = _$BookSourceImportFailedCopyWithImpl;
@useResult
$Res call({
 ParseFailureKind kind
});




}
/// @nodoc
class _$BookSourceImportFailedCopyWithImpl<$Res>
    implements $BookSourceImportFailedCopyWith<$Res> {
  _$BookSourceImportFailedCopyWithImpl(this._self, this._then);

  final BookSourceImportFailed _self;
  final $Res Function(BookSourceImportFailed) _then;

/// Create a copy of BookSourceImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,}) {
  return _then(BookSourceImportFailed(
null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ParseFailureKind,
  ));
}


}

// dart format on
