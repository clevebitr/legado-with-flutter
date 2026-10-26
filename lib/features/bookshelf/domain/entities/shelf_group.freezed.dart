// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shelf_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ShelfGroup {

 int get id; String get name; int get sortOrder;
/// Create a copy of ShelfGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShelfGroupCopyWith<ShelfGroup> get copyWith => _$ShelfGroupCopyWithImpl<ShelfGroup>(this as ShelfGroup, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ShelfGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfGroup&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder));
}


@override
int get hashCode {
  final _this = this as ShelfGroup;
  return Object.hash(runtimeType,_this.id,_this.name,_this.sortOrder);
}

@override
String toString() {
  final _this = this as ShelfGroup;
  return 'ShelfGroup(id: ${_this.id}, name: ${_this.name}, sortOrder: ${_this.sortOrder})';
}


}

/// @nodoc
abstract mixin class $ShelfGroupCopyWith<$Res>  {
  factory $ShelfGroupCopyWith(ShelfGroup value, $Res Function(ShelfGroup) _then) = _$ShelfGroupCopyWithImpl;
@useResult
$Res call({
 int id, String name, int sortOrder
});




}
/// @nodoc
class _$ShelfGroupCopyWithImpl<$Res>
    implements $ShelfGroupCopyWith<$Res> {
  _$ShelfGroupCopyWithImpl(this._self, this._then);

  final ShelfGroup _self;
  final $Res Function(ShelfGroup) _then;

/// Create a copy of ShelfGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sortOrder = null,}) {
  return _then(ShelfGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ShelfGroup].
extension ShelfGroupPatterns on ShelfGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShelfGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShelfGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShelfGroup value)  $default,){
final _that = this;
switch (_that) {
case _ShelfGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShelfGroup value)?  $default,){
final _that = this;
switch (_that) {
case _ShelfGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShelfGroup() when $default != null:
return $default(_that.id,_that.name,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int sortOrder)  $default,) {final _that = this;
switch (_that) {
case _ShelfGroup():
return $default(_that.id,_that.name,_that.sortOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _ShelfGroup() when $default != null:
return $default(_that.id,_that.name,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc


class _ShelfGroup implements ShelfGroup {
  const _ShelfGroup({required this.id, required this.name, this.sortOrder = 0});
  

@override final  int id;
@override final  String name;
@override@JsonKey() final  int sortOrder;

/// Create a copy of ShelfGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShelfGroupCopyWith<_ShelfGroup> get copyWith => __$ShelfGroupCopyWithImpl<_ShelfGroup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShelfGroup&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,sortOrder);
}

@override
String toString() {
    return 'ShelfGroup(id: $id, name: $name, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$ShelfGroupCopyWith<$Res> implements $ShelfGroupCopyWith<$Res> {
  factory _$ShelfGroupCopyWith(_ShelfGroup value, $Res Function(_ShelfGroup) _then) = __$ShelfGroupCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int sortOrder
});




}
/// @nodoc
class __$ShelfGroupCopyWithImpl<$Res>
    implements _$ShelfGroupCopyWith<$Res> {
  __$ShelfGroupCopyWithImpl(this._self, this._then);

  final _ShelfGroup _self;
  final $Res Function(_ShelfGroup) _then;

/// Create a copy of ShelfGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sortOrder = null,}) {
  return _then(_ShelfGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
