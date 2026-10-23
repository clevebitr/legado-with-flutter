// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'import_book_sources.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookSourceImportReport {

/// How many entries were new identities.
 int get inserted;/// How many entries matched a stored row and only refreshed its payload.
 int get refreshed;/// How many entries were rejected and left out.
 int get skipped;



@override
bool operator ==(Object other) {
  final _this = this as BookSourceImportReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceImportReport&&(identical(other.inserted, _this.inserted) || other.inserted == _this.inserted)&&(identical(other.refreshed, _this.refreshed) || other.refreshed == _this.refreshed)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped));
}


@override
int get hashCode {
  final _this = this as BookSourceImportReport;
  return Object.hash(runtimeType,_this.inserted,_this.refreshed,_this.skipped);
}

@override
String toString() {
  final _this = this as BookSourceImportReport;
  return 'BookSourceImportReport(inserted: ${_this.inserted}, refreshed: ${_this.refreshed}, skipped: ${_this.skipped})';
}


}




/// Adds pattern-matching-related methods to [BookSourceImportReport].
extension BookSourceImportReportPatterns on BookSourceImportReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookSourceImportReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookSourceImportReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookSourceImportReport value)  $default,){
final _that = this;
switch (_that) {
case _BookSourceImportReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookSourceImportReport value)?  $default,){
final _that = this;
switch (_that) {
case _BookSourceImportReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int inserted,  int refreshed,  int skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookSourceImportReport() when $default != null:
return $default(_that.inserted,_that.refreshed,_that.skipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int inserted,  int refreshed,  int skipped)  $default,) {final _that = this;
switch (_that) {
case _BookSourceImportReport():
return $default(_that.inserted,_that.refreshed,_that.skipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int inserted,  int refreshed,  int skipped)?  $default,) {final _that = this;
switch (_that) {
case _BookSourceImportReport() when $default != null:
return $default(_that.inserted,_that.refreshed,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc


class _BookSourceImportReport extends BookSourceImportReport {
  const _BookSourceImportReport({required this.inserted, required this.refreshed, required this.skipped}): super._();
  

/// How many entries were new identities.
@override final  int inserted;
/// How many entries matched a stored row and only refreshed its payload.
@override final  int refreshed;
/// How many entries were rejected and left out.
@override final  int skipped;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookSourceImportReport&&(identical(other.inserted, inserted) || other.inserted == inserted)&&(identical(other.refreshed, refreshed) || other.refreshed == refreshed)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}


@override
int get hashCode {
    return Object.hash(runtimeType,inserted,refreshed,skipped);
}

@override
String toString() {
    return 'BookSourceImportReport(inserted: $inserted, refreshed: $refreshed, skipped: $skipped)';
}


}




// dart format on
