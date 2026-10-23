// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_debug.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SourceDebugEvent {

 SourceDebugEventKind get kind; SourceDebugTarget get target; String get text; String? get url; ParseFailureKind? get failureKind; String? get rulePath; int get elapsedMillis;



@override
bool operator ==(Object other) {
  final _this = this as SourceDebugEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceDebugEvent&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.failureKind, _this.failureKind) || other.failureKind == _this.failureKind)&&(identical(other.rulePath, _this.rulePath) || other.rulePath == _this.rulePath)&&(identical(other.elapsedMillis, _this.elapsedMillis) || other.elapsedMillis == _this.elapsedMillis));
}


@override
int get hashCode {
  final _this = this as SourceDebugEvent;
  return Object.hash(runtimeType,_this.kind,_this.target,_this.text,_this.url,_this.failureKind,_this.rulePath,_this.elapsedMillis);
}

@override
String toString() {
  final _this = this as SourceDebugEvent;
  return 'SourceDebugEvent(kind: ${_this.kind}, target: ${_this.target}, text: ${_this.text}, url: ${_this.url}, failureKind: ${_this.failureKind}, rulePath: ${_this.rulePath}, elapsedMillis: ${_this.elapsedMillis})';
}


}




/// Adds pattern-matching-related methods to [SourceDebugEvent].
extension SourceDebugEventPatterns on SourceDebugEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceDebugEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceDebugEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceDebugEvent value)  $default,){
final _that = this;
switch (_that) {
case _SourceDebugEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceDebugEvent value)?  $default,){
final _that = this;
switch (_that) {
case _SourceDebugEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SourceDebugEventKind kind,  SourceDebugTarget target,  String text,  String? url,  ParseFailureKind? failureKind,  String? rulePath,  int elapsedMillis)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceDebugEvent() when $default != null:
return $default(_that.kind,_that.target,_that.text,_that.url,_that.failureKind,_that.rulePath,_that.elapsedMillis);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SourceDebugEventKind kind,  SourceDebugTarget target,  String text,  String? url,  ParseFailureKind? failureKind,  String? rulePath,  int elapsedMillis)  $default,) {final _that = this;
switch (_that) {
case _SourceDebugEvent():
return $default(_that.kind,_that.target,_that.text,_that.url,_that.failureKind,_that.rulePath,_that.elapsedMillis);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SourceDebugEventKind kind,  SourceDebugTarget target,  String text,  String? url,  ParseFailureKind? failureKind,  String? rulePath,  int elapsedMillis)?  $default,) {final _that = this;
switch (_that) {
case _SourceDebugEvent() when $default != null:
return $default(_that.kind,_that.target,_that.text,_that.url,_that.failureKind,_that.rulePath,_that.elapsedMillis);case _:
  return null;

}
}

}

/// @nodoc


class _SourceDebugEvent implements SourceDebugEvent {
  const _SourceDebugEvent({required this.kind, required this.target, required this.text, this.url, this.failureKind, this.rulePath, required this.elapsedMillis});
  

@override final  SourceDebugEventKind kind;
@override final  SourceDebugTarget target;
@override final  String text;
@override final  String? url;
@override final  ParseFailureKind? failureKind;
@override final  String? rulePath;
@override final  int elapsedMillis;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceDebugEvent&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.target, target) || other.target == target)&&(identical(other.text, text) || other.text == text)&&(identical(other.url, url) || other.url == url)&&(identical(other.failureKind, failureKind) || other.failureKind == failureKind)&&(identical(other.rulePath, rulePath) || other.rulePath == rulePath)&&(identical(other.elapsedMillis, elapsedMillis) || other.elapsedMillis == elapsedMillis));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,target,text,url,failureKind,rulePath,elapsedMillis);
}

@override
String toString() {
    return 'SourceDebugEvent(kind: $kind, target: $target, text: $text, url: $url, failureKind: $failureKind, rulePath: $rulePath, elapsedMillis: $elapsedMillis)';
}


}




// dart format on
