// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'parse_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ParseResult<T> {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ParseResult<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ParseResult<$T>()';
}


}




/// Adds pattern-matching-related methods to [ParseResult].
extension ParseResultPatterns<T> on ParseResult<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ParseSuccess<T> value)?  success,TResult Function( ParseFailure<T> value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ParseSuccess() when success != null:
return success(_that);case ParseFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ParseSuccess<T> value)  success,required TResult Function( ParseFailure<T> value)  failure,}){
final _that = this;
switch (_that) {
case ParseSuccess():
return success(_that);case ParseFailure():
return failure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ParseSuccess<T> value)?  success,TResult? Function( ParseFailure<T> value)?  failure,}){
final _that = this;
switch (_that) {
case ParseSuccess() when success != null:
return success(_that);case ParseFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( T data)?  success,TResult Function( ParseFailureKind kind,  String rulePath,  Object? cause,  StackTrace? stackTrace)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ParseSuccess() when success != null:
return success(_that.data);case ParseFailure() when failure != null:
return failure(_that.kind,_that.rulePath,_that.cause,_that.stackTrace);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( T data)  success,required TResult Function( ParseFailureKind kind,  String rulePath,  Object? cause,  StackTrace? stackTrace)  failure,}) {final _that = this;
switch (_that) {
case ParseSuccess():
return success(_that.data);case ParseFailure():
return failure(_that.kind,_that.rulePath,_that.cause,_that.stackTrace);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( T data)?  success,TResult? Function( ParseFailureKind kind,  String rulePath,  Object? cause,  StackTrace? stackTrace)?  failure,}) {final _that = this;
switch (_that) {
case ParseSuccess() when success != null:
return success(_that.data);case ParseFailure() when failure != null:
return failure(_that.kind,_that.rulePath,_that.cause,_that.stackTrace);case _:
  return null;

}
}

}

/// @nodoc


class ParseSuccess<T> implements ParseResult<T> {
  const ParseSuccess(this.data);
  

 final  T data;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ParseSuccess<T>&&const DeepCollectionEquality().equals(other.data, data));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(data));
}

@override
String toString() {
    return 'ParseResult<$T>.success(data: $data)';
}


}




/// @nodoc


class ParseFailure<T> implements ParseResult<T> {
  const ParseFailure({required this.kind, required this.rulePath, this.cause, this.stackTrace});
  

 final  ParseFailureKind kind;
 final  String rulePath;
 final  Object? cause;
 final  StackTrace? stackTrace;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ParseFailure<T>&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.rulePath, rulePath) || other.rulePath == rulePath)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.stackTrace, stackTrace) || other.stackTrace == stackTrace));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,rulePath,const DeepCollectionEquality().hash(cause),stackTrace);
}

@override
String toString() {
    return 'ParseResult<$T>.failure(kind: $kind, rulePath: $rulePath, cause: $cause, stackTrace: $stackTrace)';
}


}




// dart format on
