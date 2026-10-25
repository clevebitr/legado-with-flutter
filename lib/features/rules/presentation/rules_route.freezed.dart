// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rules_route.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RulesRoute {

 RuleKind get kind;
/// Create a copy of RulesRoute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RulesRouteCopyWith<RulesRoute> get copyWith => _$RulesRouteCopyWithImpl<RulesRoute>(this as RulesRoute, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RulesRoute;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesRoute&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}


@override
int get hashCode {
  final _this = this as RulesRoute;
  return Object.hash(runtimeType,_this.kind);
}

@override
String toString() {
  final _this = this as RulesRoute;
  return 'RulesRoute(kind: ${_this.kind})';
}


}

/// @nodoc
abstract mixin class $RulesRouteCopyWith<$Res>  {
  factory $RulesRouteCopyWith(RulesRoute value, $Res Function(RulesRoute) _then) = _$RulesRouteCopyWithImpl;
@useResult
$Res call({
 RuleKind kind
});




}
/// @nodoc
class _$RulesRouteCopyWithImpl<$Res>
    implements $RulesRouteCopyWith<$Res> {
  _$RulesRouteCopyWithImpl(this._self, this._then);

  final RulesRoute _self;
  final $Res Function(RulesRoute) _then;

/// Create a copy of RulesRoute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleKind,
  ));
}

}


/// Adds pattern-matching-related methods to [RulesRoute].
extension RulesRoutePatterns on RulesRoute {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RulesListRoute value)?  list,TResult Function( RulesEditRoute value)?  edit,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RulesListRoute() when list != null:
return list(_that);case RulesEditRoute() when edit != null:
return edit(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RulesListRoute value)  list,required TResult Function( RulesEditRoute value)  edit,}){
final _that = this;
switch (_that) {
case RulesListRoute():
return list(_that);case RulesEditRoute():
return edit(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RulesListRoute value)?  list,TResult? Function( RulesEditRoute value)?  edit,}){
final _that = this;
switch (_that) {
case RulesListRoute() when list != null:
return list(_that);case RulesEditRoute() when edit != null:
return edit(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( RuleKind kind)?  list,TResult Function( RuleKind kind,  int? ruleId)?  edit,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RulesListRoute() when list != null:
return list(_that.kind);case RulesEditRoute() when edit != null:
return edit(_that.kind,_that.ruleId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( RuleKind kind)  list,required TResult Function( RuleKind kind,  int? ruleId)  edit,}) {final _that = this;
switch (_that) {
case RulesListRoute():
return list(_that.kind);case RulesEditRoute():
return edit(_that.kind,_that.ruleId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( RuleKind kind)?  list,TResult? Function( RuleKind kind,  int? ruleId)?  edit,}) {final _that = this;
switch (_that) {
case RulesListRoute() when list != null:
return list(_that.kind);case RulesEditRoute() when edit != null:
return edit(_that.kind,_that.ruleId);case _:
  return null;

}
}

}

/// @nodoc


class RulesListRoute extends RulesRoute {
  const RulesListRoute({required this.kind}): super._();
  

@override final  RuleKind kind;

/// Create a copy of RulesRoute
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RulesListRouteCopyWith<RulesListRoute> get copyWith => _$RulesListRouteCopyWithImpl<RulesListRoute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesListRoute&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind);
}

@override
String toString() {
    return 'RulesRoute.list(kind: $kind)';
}


}

/// @nodoc
abstract mixin class $RulesListRouteCopyWith<$Res> implements $RulesRouteCopyWith<$Res> {
  factory $RulesListRouteCopyWith(RulesListRoute value, $Res Function(RulesListRoute) _then) = _$RulesListRouteCopyWithImpl;
@override @useResult
$Res call({
 RuleKind kind
});




}
/// @nodoc
class _$RulesListRouteCopyWithImpl<$Res>
    implements $RulesListRouteCopyWith<$Res> {
  _$RulesListRouteCopyWithImpl(this._self, this._then);

  final RulesListRoute _self;
  final $Res Function(RulesListRoute) _then;

/// Create a copy of RulesRoute
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,}) {
  return _then(RulesListRoute(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleKind,
  ));
}


}

/// @nodoc


class RulesEditRoute extends RulesRoute {
  const RulesEditRoute({required this.kind, this.ruleId}): super._();
  

@override final  RuleKind kind;
 final  int? ruleId;

/// Create a copy of RulesRoute
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RulesEditRouteCopyWith<RulesEditRoute> get copyWith => _$RulesEditRouteCopyWithImpl<RulesEditRoute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulesEditRoute&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.ruleId, ruleId) || other.ruleId == ruleId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,ruleId);
}

@override
String toString() {
    return 'RulesRoute.edit(kind: $kind, ruleId: $ruleId)';
}


}

/// @nodoc
abstract mixin class $RulesEditRouteCopyWith<$Res> implements $RulesRouteCopyWith<$Res> {
  factory $RulesEditRouteCopyWith(RulesEditRoute value, $Res Function(RulesEditRoute) _then) = _$RulesEditRouteCopyWithImpl;
@override @useResult
$Res call({
 RuleKind kind, int? ruleId
});




}
/// @nodoc
class _$RulesEditRouteCopyWithImpl<$Res>
    implements $RulesEditRouteCopyWith<$Res> {
  _$RulesEditRouteCopyWithImpl(this._self, this._then);

  final RulesEditRoute _self;
  final $Res Function(RulesEditRoute) _then;

/// Create a copy of RulesRoute
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? ruleId = freezed,}) {
  return _then(RulesEditRoute(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleKind,ruleId: freezed == ruleId ? _self.ruleId : ruleId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
