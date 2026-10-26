// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'login_form.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LoginField {

/// The key the value is stored under (upstream's `name`).
 String get name;/// What the page shows.
 String get title;/// Which control to render.
 LoginFieldType get type;/// The choices of a [LoginFieldType.select], in order.
 List<String> get options;/// The starting value (upstream's `default`).
 String get initialValue;/// What a [LoginFieldType.button] does, verbatim.
 String? get action;
/// Create a copy of LoginField
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginFieldCopyWith<LoginField> get copyWith => _$LoginFieldCopyWithImpl<LoginField>(this as LoginField, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LoginField;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginField&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.type, _this.type) || other.type == _this.type)&&const DeepCollectionEquality().equals(other.options, _this.options)&&(identical(other.initialValue, _this.initialValue) || other.initialValue == _this.initialValue)&&(identical(other.action, _this.action) || other.action == _this.action));
}


@override
int get hashCode {
  final _this = this as LoginField;
  return Object.hash(runtimeType,_this.name,_this.title,_this.type,const DeepCollectionEquality().hash(_this.options),_this.initialValue,_this.action);
}

@override
String toString() {
  final _this = this as LoginField;
  return 'LoginField(name: ${_this.name}, title: ${_this.title}, type: ${_this.type}, options: ${_this.options}, initialValue: ${_this.initialValue}, action: ${_this.action})';
}


}

/// @nodoc
abstract mixin class $LoginFieldCopyWith<$Res>  {
  factory $LoginFieldCopyWith(LoginField value, $Res Function(LoginField) _then) = _$LoginFieldCopyWithImpl;
@useResult
$Res call({
 String name, String title, LoginFieldType type, List<String> options, String initialValue, String? action
});




}
/// @nodoc
class _$LoginFieldCopyWithImpl<$Res>
    implements $LoginFieldCopyWith<$Res> {
  _$LoginFieldCopyWithImpl(this._self, this._then);

  final LoginField _self;
  final $Res Function(LoginField) _then;

/// Create a copy of LoginField
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? title = null,Object? type = null,Object? options = null,Object? initialValue = null,Object? action = freezed,}) {
  return _then(LoginField(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LoginFieldType,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,initialValue: null == initialValue ? _self.initialValue : initialValue // ignore: cast_nullable_to_non_nullable
as String,action: freezed == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LoginField].
extension LoginFieldPatterns on LoginField {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginField value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginField() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginField value)  $default,){
final _that = this;
switch (_that) {
case _LoginField():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginField value)?  $default,){
final _that = this;
switch (_that) {
case _LoginField() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String title,  LoginFieldType type,  List<String> options,  String initialValue,  String? action)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginField() when $default != null:
return $default(_that.name,_that.title,_that.type,_that.options,_that.initialValue,_that.action);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String title,  LoginFieldType type,  List<String> options,  String initialValue,  String? action)  $default,) {final _that = this;
switch (_that) {
case _LoginField():
return $default(_that.name,_that.title,_that.type,_that.options,_that.initialValue,_that.action);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String title,  LoginFieldType type,  List<String> options,  String initialValue,  String? action)?  $default,) {final _that = this;
switch (_that) {
case _LoginField() when $default != null:
return $default(_that.name,_that.title,_that.type,_that.options,_that.initialValue,_that.action);case _:
  return null;

}
}

}

/// @nodoc


class _LoginField implements LoginField {
  const _LoginField({required this.name, required this.title, required this.type,  List<String> options = const <String>[], this.initialValue = '', this.action}): _options = options;
  

/// The key the value is stored under (upstream's `name`).
@override final  String name;
/// What the page shows.
@override final  String title;
/// Which control to render.
@override final  LoginFieldType type;
/// The choices of a [LoginFieldType.select], in order.
 final  List<String> _options;
/// The choices of a [LoginFieldType.select], in order.
@override@JsonKey() List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

/// The starting value (upstream's `default`).
@override@JsonKey() final  String initialValue;
/// What a [LoginFieldType.button] does, verbatim.
@override final  String? action;

/// Create a copy of LoginField
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginFieldCopyWith<_LoginField> get copyWith => __$LoginFieldCopyWithImpl<_LoginField>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginField&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.options, _options)&&(identical(other.initialValue, initialValue) || other.initialValue == initialValue)&&(identical(other.action, action) || other.action == action));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,title,type,const DeepCollectionEquality().hash(_options),initialValue,action);
}

@override
String toString() {
    return 'LoginField(name: $name, title: $title, type: $type, options: $options, initialValue: $initialValue, action: $action)';
}


}

/// @nodoc
abstract mixin class _$LoginFieldCopyWith<$Res> implements $LoginFieldCopyWith<$Res> {
  factory _$LoginFieldCopyWith(_LoginField value, $Res Function(_LoginField) _then) = __$LoginFieldCopyWithImpl;
@override @useResult
$Res call({
 String name, String title, LoginFieldType type, List<String> options, String initialValue, String? action
});




}
/// @nodoc
class __$LoginFieldCopyWithImpl<$Res>
    implements _$LoginFieldCopyWith<$Res> {
  __$LoginFieldCopyWithImpl(this._self, this._then);

  final _LoginField _self;
  final $Res Function(_LoginField) _then;

/// Create a copy of LoginField
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? title = null,Object? type = null,Object? options = null,Object? initialValue = null,Object? action = freezed,}) {
  return _then(_LoginField(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LoginFieldType,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,initialValue: null == initialValue ? _self.initialValue : initialValue // ignore: cast_nullable_to_non_nullable
as String,action: freezed == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$LoginForm {

/// The rows, in the file's order.
 List<LoginField> get fields;
/// Create a copy of LoginForm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginFormCopyWith<LoginForm> get copyWith => _$LoginFormCopyWithImpl<LoginForm>(this as LoginForm, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LoginForm;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginForm&&const DeepCollectionEquality().equals(other.fields, _this.fields));
}


@override
int get hashCode {
  final _this = this as LoginForm;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.fields));
}

@override
String toString() {
  final _this = this as LoginForm;
  return 'LoginForm(fields: ${_this.fields})';
}


}

/// @nodoc
abstract mixin class $LoginFormCopyWith<$Res>  {
  factory $LoginFormCopyWith(LoginForm value, $Res Function(LoginForm) _then) = _$LoginFormCopyWithImpl;
@useResult
$Res call({
 List<LoginField> fields
});




}
/// @nodoc
class _$LoginFormCopyWithImpl<$Res>
    implements $LoginFormCopyWith<$Res> {
  _$LoginFormCopyWithImpl(this._self, this._then);

  final LoginForm _self;
  final $Res Function(LoginForm) _then;

/// Create a copy of LoginForm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fields = null,}) {
  return _then(LoginForm(
fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as List<LoginField>,
  ));
}

}


/// Adds pattern-matching-related methods to [LoginForm].
extension LoginFormPatterns on LoginForm {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginForm value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginForm() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginForm value)  $default,){
final _that = this;
switch (_that) {
case _LoginForm():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginForm value)?  $default,){
final _that = this;
switch (_that) {
case _LoginForm() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LoginField> fields)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginForm() when $default != null:
return $default(_that.fields);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LoginField> fields)  $default,) {final _that = this;
switch (_that) {
case _LoginForm():
return $default(_that.fields);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LoginField> fields)?  $default,) {final _that = this;
switch (_that) {
case _LoginForm() when $default != null:
return $default(_that.fields);case _:
  return null;

}
}

}

/// @nodoc


class _LoginForm extends LoginForm {
  const _LoginForm({required  List<LoginField> fields}): _fields = fields,super._();
  

/// The rows, in the file's order.
 final  List<LoginField> _fields;
/// The rows, in the file's order.
@override List<LoginField> get fields {
  if (_fields is EqualUnmodifiableListView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fields);
}


/// Create a copy of LoginForm
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginFormCopyWith<_LoginForm> get copyWith => __$LoginFormCopyWithImpl<_LoginForm>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginForm&&const DeepCollectionEquality().equals(other.fields, _fields));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_fields));
}

@override
String toString() {
    return 'LoginForm(fields: $fields)';
}


}

/// @nodoc
abstract mixin class _$LoginFormCopyWith<$Res> implements $LoginFormCopyWith<$Res> {
  factory _$LoginFormCopyWith(_LoginForm value, $Res Function(_LoginForm) _then) = __$LoginFormCopyWithImpl;
@override @useResult
$Res call({
 List<LoginField> fields
});




}
/// @nodoc
class __$LoginFormCopyWithImpl<$Res>
    implements _$LoginFormCopyWith<$Res> {
  __$LoginFormCopyWithImpl(this._self, this._then);

  final _LoginForm _self;
  final $Res Function(_LoginForm) _then;

/// Create a copy of LoginForm
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fields = null,}) {
  return _then(_LoginForm(
fields: null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as List<LoginField>,
  ));
}


}

// dart format on
