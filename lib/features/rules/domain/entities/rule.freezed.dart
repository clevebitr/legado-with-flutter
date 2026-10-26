// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Rule {

 int get id; RuleKind get kind; String get name; RulePayload get payload; bool get isEnabled; bool get isBuiltIn; int get sortOrder;
/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleCopyWith<Rule> get copyWith => _$RuleCopyWithImpl<Rule>(this as Rule, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Rule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Rule&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.payload, _this.payload) || other.payload == _this.payload)&&(identical(other.isEnabled, _this.isEnabled) || other.isEnabled == _this.isEnabled)&&(identical(other.isBuiltIn, _this.isBuiltIn) || other.isBuiltIn == _this.isBuiltIn)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder));
}


@override
int get hashCode {
  final _this = this as Rule;
  return Object.hash(runtimeType,_this.id,_this.kind,_this.name,_this.payload,_this.isEnabled,_this.isBuiltIn,_this.sortOrder);
}

@override
String toString() {
  final _this = this as Rule;
  return 'Rule(id: ${_this.id}, kind: ${_this.kind}, name: ${_this.name}, payload: ${_this.payload}, isEnabled: ${_this.isEnabled}, isBuiltIn: ${_this.isBuiltIn}, sortOrder: ${_this.sortOrder})';
}


}

/// @nodoc
abstract mixin class $RuleCopyWith<$Res>  {
  factory $RuleCopyWith(Rule value, $Res Function(Rule) _then) = _$RuleCopyWithImpl;
@useResult
$Res call({
 int id, RuleKind kind, String name, RulePayload payload, bool isEnabled, bool isBuiltIn, int sortOrder
});


$RulePayloadCopyWith<$Res> get payload;

}
/// @nodoc
class _$RuleCopyWithImpl<$Res>
    implements $RuleCopyWith<$Res> {
  _$RuleCopyWithImpl(this._self, this._then);

  final Rule _self;
  final $Res Function(Rule) _then;

/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? payload = null,Object? isEnabled = null,Object? isBuiltIn = null,Object? sortOrder = null,}) {
  return _then(Rule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as RulePayload,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RulePayloadCopyWith<$Res> get payload {
  
  return $RulePayloadCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}


/// Adds pattern-matching-related methods to [Rule].
extension RulePatterns on Rule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Rule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Rule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Rule value)  $default,){
final _that = this;
switch (_that) {
case _Rule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Rule value)?  $default,){
final _that = this;
switch (_that) {
case _Rule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  RuleKind kind,  String name,  RulePayload payload,  bool isEnabled,  bool isBuiltIn,  int sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Rule() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.payload,_that.isEnabled,_that.isBuiltIn,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  RuleKind kind,  String name,  RulePayload payload,  bool isEnabled,  bool isBuiltIn,  int sortOrder)  $default,) {final _that = this;
switch (_that) {
case _Rule():
return $default(_that.id,_that.kind,_that.name,_that.payload,_that.isEnabled,_that.isBuiltIn,_that.sortOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  RuleKind kind,  String name,  RulePayload payload,  bool isEnabled,  bool isBuiltIn,  int sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _Rule() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.payload,_that.isEnabled,_that.isBuiltIn,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc


class _Rule implements Rule {
  const _Rule({required this.id, required this.kind, required this.name, required this.payload, required this.isEnabled, required this.isBuiltIn, required this.sortOrder});
  

@override final  int id;
@override final  RuleKind kind;
@override final  String name;
@override final  RulePayload payload;
@override final  bool isEnabled;
@override final  bool isBuiltIn;
@override final  int sortOrder;

/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleCopyWith<_Rule> get copyWith => __$RuleCopyWithImpl<_Rule>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Rule&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.payload, payload) || other.payload == payload)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.isBuiltIn, isBuiltIn) || other.isBuiltIn == isBuiltIn)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,kind,name,payload,isEnabled,isBuiltIn,sortOrder);
}

@override
String toString() {
    return 'Rule(id: $id, kind: $kind, name: $name, payload: $payload, isEnabled: $isEnabled, isBuiltIn: $isBuiltIn, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$RuleCopyWith<$Res> implements $RuleCopyWith<$Res> {
  factory _$RuleCopyWith(_Rule value, $Res Function(_Rule) _then) = __$RuleCopyWithImpl;
@override @useResult
$Res call({
 int id, RuleKind kind, String name, RulePayload payload, bool isEnabled, bool isBuiltIn, int sortOrder
});


@override $RulePayloadCopyWith<$Res> get payload;

}
/// @nodoc
class __$RuleCopyWithImpl<$Res>
    implements _$RuleCopyWith<$Res> {
  __$RuleCopyWithImpl(this._self, this._then);

  final _Rule _self;
  final $Res Function(_Rule) _then;

/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? payload = null,Object? isEnabled = null,Object? isBuiltIn = null,Object? sortOrder = null,}) {
  return _then(_Rule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as RulePayload,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RulePayloadCopyWith<$Res> get payload {
  
  return $RulePayloadCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

/// @nodoc
mixin _$RuleDraft {

 RuleKind get kind; String get name; RulePayload get payload; bool get isEnabled; bool get isBuiltIn;/// Where the row should sit inside its kind; `null` appends (what「新增」does).
///
/// An import is the one caller that needs it: the file carries an `order` per rule and the
/// imported list must come out in the file's order (ADR-0071 §决策 1).
 int? get sortOrder;
/// Create a copy of RuleDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleDraftCopyWith<RuleDraft> get copyWith => _$RuleDraftCopyWithImpl<RuleDraft>(this as RuleDraft, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RuleDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleDraft&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.payload, _this.payload) || other.payload == _this.payload)&&(identical(other.isEnabled, _this.isEnabled) || other.isEnabled == _this.isEnabled)&&(identical(other.isBuiltIn, _this.isBuiltIn) || other.isBuiltIn == _this.isBuiltIn)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder));
}


@override
int get hashCode {
  final _this = this as RuleDraft;
  return Object.hash(runtimeType,_this.kind,_this.name,_this.payload,_this.isEnabled,_this.isBuiltIn,_this.sortOrder);
}

@override
String toString() {
  final _this = this as RuleDraft;
  return 'RuleDraft(kind: ${_this.kind}, name: ${_this.name}, payload: ${_this.payload}, isEnabled: ${_this.isEnabled}, isBuiltIn: ${_this.isBuiltIn}, sortOrder: ${_this.sortOrder})';
}


}

/// @nodoc
abstract mixin class $RuleDraftCopyWith<$Res>  {
  factory $RuleDraftCopyWith(RuleDraft value, $Res Function(RuleDraft) _then) = _$RuleDraftCopyWithImpl;
@useResult
$Res call({
 RuleKind kind, String name, RulePayload payload, bool isEnabled, bool isBuiltIn, int? sortOrder
});


$RulePayloadCopyWith<$Res> get payload;

}
/// @nodoc
class _$RuleDraftCopyWithImpl<$Res>
    implements $RuleDraftCopyWith<$Res> {
  _$RuleDraftCopyWithImpl(this._self, this._then);

  final RuleDraft _self;
  final $Res Function(RuleDraft) _then;

/// Create a copy of RuleDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? name = null,Object? payload = null,Object? isEnabled = null,Object? isBuiltIn = null,Object? sortOrder = freezed,}) {
  return _then(RuleDraft(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as RulePayload,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of RuleDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RulePayloadCopyWith<$Res> get payload {
  
  return $RulePayloadCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}


/// Adds pattern-matching-related methods to [RuleDraft].
extension RuleDraftPatterns on RuleDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleDraft value)  $default,){
final _that = this;
switch (_that) {
case _RuleDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleDraft value)?  $default,){
final _that = this;
switch (_that) {
case _RuleDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RuleKind kind,  String name,  RulePayload payload,  bool isEnabled,  bool isBuiltIn,  int? sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleDraft() when $default != null:
return $default(_that.kind,_that.name,_that.payload,_that.isEnabled,_that.isBuiltIn,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RuleKind kind,  String name,  RulePayload payload,  bool isEnabled,  bool isBuiltIn,  int? sortOrder)  $default,) {final _that = this;
switch (_that) {
case _RuleDraft():
return $default(_that.kind,_that.name,_that.payload,_that.isEnabled,_that.isBuiltIn,_that.sortOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RuleKind kind,  String name,  RulePayload payload,  bool isEnabled,  bool isBuiltIn,  int? sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _RuleDraft() when $default != null:
return $default(_that.kind,_that.name,_that.payload,_that.isEnabled,_that.isBuiltIn,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc


class _RuleDraft implements RuleDraft {
  const _RuleDraft({required this.kind, required this.name, required this.payload, this.isEnabled = true, this.isBuiltIn = false, this.sortOrder});
  

@override final  RuleKind kind;
@override final  String name;
@override final  RulePayload payload;
@override@JsonKey() final  bool isEnabled;
@override@JsonKey() final  bool isBuiltIn;
/// Where the row should sit inside its kind; `null` appends (what「新增」does).
///
/// An import is the one caller that needs it: the file carries an `order` per rule and the
/// imported list must come out in the file's order (ADR-0071 §决策 1).
@override final  int? sortOrder;

/// Create a copy of RuleDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleDraftCopyWith<_RuleDraft> get copyWith => __$RuleDraftCopyWithImpl<_RuleDraft>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleDraft&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.payload, payload) || other.payload == payload)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.isBuiltIn, isBuiltIn) || other.isBuiltIn == isBuiltIn)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,name,payload,isEnabled,isBuiltIn,sortOrder);
}

@override
String toString() {
    return 'RuleDraft(kind: $kind, name: $name, payload: $payload, isEnabled: $isEnabled, isBuiltIn: $isBuiltIn, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$RuleDraftCopyWith<$Res> implements $RuleDraftCopyWith<$Res> {
  factory _$RuleDraftCopyWith(_RuleDraft value, $Res Function(_RuleDraft) _then) = __$RuleDraftCopyWithImpl;
@override @useResult
$Res call({
 RuleKind kind, String name, RulePayload payload, bool isEnabled, bool isBuiltIn, int? sortOrder
});


@override $RulePayloadCopyWith<$Res> get payload;

}
/// @nodoc
class __$RuleDraftCopyWithImpl<$Res>
    implements _$RuleDraftCopyWith<$Res> {
  __$RuleDraftCopyWithImpl(this._self, this._then);

  final _RuleDraft _self;
  final $Res Function(_RuleDraft) _then;

/// Create a copy of RuleDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? name = null,Object? payload = null,Object? isEnabled = null,Object? isBuiltIn = null,Object? sortOrder = freezed,}) {
  return _then(_RuleDraft(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as RulePayload,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of RuleDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RulePayloadCopyWith<$Res> get payload {
  
  return $RulePayloadCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

// dart format on
