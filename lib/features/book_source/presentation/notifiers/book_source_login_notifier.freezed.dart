// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_source_login_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookSourceLoginState {

/// The source being signed in.
 StoredBookSource get source;/// The rendered form; empty when the source only declares a browser address.
 LoginForm? get form;/// The values collected so far, keyed by the field's `name`.
 Map<String, String> get values;/// Why the form could not be resolved, when it could not.
 ParseFailureKind? get failure;/// Whether a submit (or a button action) is in flight.
 bool get isSubmitting;/// Whether the last submit succeeded.
 bool get isSignedIn;/// Why the last submit failed, when it did.
 ParseFailureKind? get submitFailure;
/// Create a copy of BookSourceLoginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSourceLoginStateCopyWith<BookSourceLoginState> get copyWith => _$BookSourceLoginStateCopyWithImpl<BookSourceLoginState>(this as BookSourceLoginState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookSourceLoginState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceLoginState&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.form, _this.form) || other.form == _this.form)&&const DeepCollectionEquality().equals(other.values, _this.values)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&(identical(other.isSubmitting, _this.isSubmitting) || other.isSubmitting == _this.isSubmitting)&&(identical(other.isSignedIn, _this.isSignedIn) || other.isSignedIn == _this.isSignedIn)&&(identical(other.submitFailure, _this.submitFailure) || other.submitFailure == _this.submitFailure));
}


@override
int get hashCode {
  final _this = this as BookSourceLoginState;
  return Object.hash(runtimeType,_this.source,_this.form,const DeepCollectionEquality().hash(_this.values),_this.failure,_this.isSubmitting,_this.isSignedIn,_this.submitFailure);
}

@override
String toString() {
  final _this = this as BookSourceLoginState;
  return 'BookSourceLoginState(source: ${_this.source}, form: ${_this.form}, values: ${_this.values}, failure: ${_this.failure}, isSubmitting: ${_this.isSubmitting}, isSignedIn: ${_this.isSignedIn}, submitFailure: ${_this.submitFailure})';
}


}

/// @nodoc
abstract mixin class $BookSourceLoginStateCopyWith<$Res>  {
  factory $BookSourceLoginStateCopyWith(BookSourceLoginState value, $Res Function(BookSourceLoginState) _then) = _$BookSourceLoginStateCopyWithImpl;
@useResult
$Res call({
 StoredBookSource source, LoginForm? form, Map<String, String> values, ParseFailureKind? failure, bool isSubmitting, bool isSignedIn, ParseFailureKind? submitFailure
});


$StoredBookSourceCopyWith<$Res> get source;$LoginFormCopyWith<$Res>? get form;

}
/// @nodoc
class _$BookSourceLoginStateCopyWithImpl<$Res>
    implements $BookSourceLoginStateCopyWith<$Res> {
  _$BookSourceLoginStateCopyWithImpl(this._self, this._then);

  final BookSourceLoginState _self;
  final $Res Function(BookSourceLoginState) _then;

/// Create a copy of BookSourceLoginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? form = freezed,Object? values = null,Object? failure = freezed,Object? isSubmitting = null,Object? isSignedIn = null,Object? submitFailure = freezed,}) {
  return _then(BookSourceLoginState(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as StoredBookSource,form: freezed == form ? _self.form : form // ignore: cast_nullable_to_non_nullable
as LoginForm?,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as Map<String, String>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,isSubmitting: null == isSubmitting ? _self.isSubmitting : isSubmitting // ignore: cast_nullable_to_non_nullable
as bool,isSignedIn: null == isSignedIn ? _self.isSignedIn : isSignedIn // ignore: cast_nullable_to_non_nullable
as bool,submitFailure: freezed == submitFailure ? _self.submitFailure : submitFailure // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,
  ));
}
/// Create a copy of BookSourceLoginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StoredBookSourceCopyWith<$Res> get source {
  
  return $StoredBookSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}/// Create a copy of BookSourceLoginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LoginFormCopyWith<$Res>? get form {
    if (_self.form == null) {
    return null;
  }

  return $LoginFormCopyWith<$Res>(_self.form!, (value) {
    return _then(_self.copyWith(form: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookSourceLoginState].
extension BookSourceLoginStatePatterns on BookSourceLoginState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookSourceLoginState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookSourceLoginState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookSourceLoginState value)  $default,){
final _that = this;
switch (_that) {
case _BookSourceLoginState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookSourceLoginState value)?  $default,){
final _that = this;
switch (_that) {
case _BookSourceLoginState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StoredBookSource source,  LoginForm? form,  Map<String, String> values,  ParseFailureKind? failure,  bool isSubmitting,  bool isSignedIn,  ParseFailureKind? submitFailure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookSourceLoginState() when $default != null:
return $default(_that.source,_that.form,_that.values,_that.failure,_that.isSubmitting,_that.isSignedIn,_that.submitFailure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StoredBookSource source,  LoginForm? form,  Map<String, String> values,  ParseFailureKind? failure,  bool isSubmitting,  bool isSignedIn,  ParseFailureKind? submitFailure)  $default,) {final _that = this;
switch (_that) {
case _BookSourceLoginState():
return $default(_that.source,_that.form,_that.values,_that.failure,_that.isSubmitting,_that.isSignedIn,_that.submitFailure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StoredBookSource source,  LoginForm? form,  Map<String, String> values,  ParseFailureKind? failure,  bool isSubmitting,  bool isSignedIn,  ParseFailureKind? submitFailure)?  $default,) {final _that = this;
switch (_that) {
case _BookSourceLoginState() when $default != null:
return $default(_that.source,_that.form,_that.values,_that.failure,_that.isSubmitting,_that.isSignedIn,_that.submitFailure);case _:
  return null;

}
}

}

/// @nodoc


class _BookSourceLoginState implements BookSourceLoginState {
  const _BookSourceLoginState({required this.source, this.form,  Map<String, String> values = const <String, String>{}, this.failure, this.isSubmitting = false, this.isSignedIn = false, this.submitFailure}): _values = values;
  

/// The source being signed in.
@override final  StoredBookSource source;
/// The rendered form; empty when the source only declares a browser address.
@override final  LoginForm? form;
/// The values collected so far, keyed by the field's `name`.
 final  Map<String, String> _values;
/// The values collected so far, keyed by the field's `name`.
@override@JsonKey() Map<String, String> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}

/// Why the form could not be resolved, when it could not.
@override final  ParseFailureKind? failure;
/// Whether a submit (or a button action) is in flight.
@override@JsonKey() final  bool isSubmitting;
/// Whether the last submit succeeded.
@override@JsonKey() final  bool isSignedIn;
/// Why the last submit failed, when it did.
@override final  ParseFailureKind? submitFailure;

/// Create a copy of BookSourceLoginState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookSourceLoginStateCopyWith<_BookSourceLoginState> get copyWith => __$BookSourceLoginStateCopyWithImpl<_BookSourceLoginState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookSourceLoginState&&(identical(other.source, source) || other.source == source)&&(identical(other.form, form) || other.form == form)&&const DeepCollectionEquality().equals(other.values, _values)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.isSubmitting, isSubmitting) || other.isSubmitting == isSubmitting)&&(identical(other.isSignedIn, isSignedIn) || other.isSignedIn == isSignedIn)&&(identical(other.submitFailure, submitFailure) || other.submitFailure == submitFailure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,source,form,const DeepCollectionEquality().hash(_values),failure,isSubmitting,isSignedIn,submitFailure);
}

@override
String toString() {
    return 'BookSourceLoginState(source: $source, form: $form, values: $values, failure: $failure, isSubmitting: $isSubmitting, isSignedIn: $isSignedIn, submitFailure: $submitFailure)';
}


}

/// @nodoc
abstract mixin class _$BookSourceLoginStateCopyWith<$Res> implements $BookSourceLoginStateCopyWith<$Res> {
  factory _$BookSourceLoginStateCopyWith(_BookSourceLoginState value, $Res Function(_BookSourceLoginState) _then) = __$BookSourceLoginStateCopyWithImpl;
@override @useResult
$Res call({
 StoredBookSource source, LoginForm? form, Map<String, String> values, ParseFailureKind? failure, bool isSubmitting, bool isSignedIn, ParseFailureKind? submitFailure
});


@override $StoredBookSourceCopyWith<$Res> get source;@override $LoginFormCopyWith<$Res>? get form;

}
/// @nodoc
class __$BookSourceLoginStateCopyWithImpl<$Res>
    implements _$BookSourceLoginStateCopyWith<$Res> {
  __$BookSourceLoginStateCopyWithImpl(this._self, this._then);

  final _BookSourceLoginState _self;
  final $Res Function(_BookSourceLoginState) _then;

/// Create a copy of BookSourceLoginState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? form = freezed,Object? values = null,Object? failure = freezed,Object? isSubmitting = null,Object? isSignedIn = null,Object? submitFailure = freezed,}) {
  return _then(_BookSourceLoginState(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as StoredBookSource,form: freezed == form ? _self.form : form // ignore: cast_nullable_to_non_nullable
as LoginForm?,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as Map<String, String>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,isSubmitting: null == isSubmitting ? _self.isSubmitting : isSubmitting // ignore: cast_nullable_to_non_nullable
as bool,isSignedIn: null == isSignedIn ? _self.isSignedIn : isSignedIn // ignore: cast_nullable_to_non_nullable
as bool,submitFailure: freezed == submitFailure ? _self.submitFailure : submitFailure // ignore: cast_nullable_to_non_nullable
as ParseFailureKind?,
  ));
}

/// Create a copy of BookSourceLoginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StoredBookSourceCopyWith<$Res> get source {
  
  return $StoredBookSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}/// Create a copy of BookSourceLoginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LoginFormCopyWith<$Res>? get form {
    if (_self.form == null) {
    return null;
  }

  return $LoginFormCopyWith<$Res>(_self.form!, (value) {
    return _then(_self.copyWith(form: value));
  });
}
}

// dart format on
