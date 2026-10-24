// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'explore_category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExploreCategory {

 String get title; String? get url;
/// Create a copy of ExploreCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExploreCategoryCopyWith<ExploreCategory> get copyWith => _$ExploreCategoryCopyWithImpl<ExploreCategory>(this as ExploreCategory, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ExploreCategory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreCategory&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url));
}


@override
int get hashCode {
  final _this = this as ExploreCategory;
  return Object.hash(runtimeType,_this.title,_this.url);
}

@override
String toString() {
  final _this = this as ExploreCategory;
  return 'ExploreCategory(title: ${_this.title}, url: ${_this.url})';
}


}

/// @nodoc
abstract mixin class $ExploreCategoryCopyWith<$Res>  {
  factory $ExploreCategoryCopyWith(ExploreCategory value, $Res Function(ExploreCategory) _then) = _$ExploreCategoryCopyWithImpl;
@useResult
$Res call({
 String title, String? url
});




}
/// @nodoc
class _$ExploreCategoryCopyWithImpl<$Res>
    implements $ExploreCategoryCopyWith<$Res> {
  _$ExploreCategoryCopyWithImpl(this._self, this._then);

  final ExploreCategory _self;
  final $Res Function(ExploreCategory) _then;

/// Create a copy of ExploreCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? url = freezed,}) {
  return _then(ExploreCategory(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExploreCategory].
extension ExploreCategoryPatterns on ExploreCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExploreCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExploreCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExploreCategory value)  $default,){
final _that = this;
switch (_that) {
case _ExploreCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExploreCategory value)?  $default,){
final _that = this;
switch (_that) {
case _ExploreCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String? url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExploreCategory() when $default != null:
return $default(_that.title,_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String? url)  $default,) {final _that = this;
switch (_that) {
case _ExploreCategory():
return $default(_that.title,_that.url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String? url)?  $default,) {final _that = this;
switch (_that) {
case _ExploreCategory() when $default != null:
return $default(_that.title,_that.url);case _:
  return null;

}
}

}

/// @nodoc


class _ExploreCategory implements ExploreCategory {
  const _ExploreCategory({required this.title, this.url});
  

@override final  String title;
@override final  String? url;

/// Create a copy of ExploreCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExploreCategoryCopyWith<_ExploreCategory> get copyWith => __$ExploreCategoryCopyWithImpl<_ExploreCategory>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExploreCategory&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,url);
}

@override
String toString() {
    return 'ExploreCategory(title: $title, url: $url)';
}


}

/// @nodoc
abstract mixin class _$ExploreCategoryCopyWith<$Res> implements $ExploreCategoryCopyWith<$Res> {
  factory _$ExploreCategoryCopyWith(_ExploreCategory value, $Res Function(_ExploreCategory) _then) = __$ExploreCategoryCopyWithImpl;
@override @useResult
$Res call({
 String title, String? url
});




}
/// @nodoc
class __$ExploreCategoryCopyWithImpl<$Res>
    implements _$ExploreCategoryCopyWith<$Res> {
  __$ExploreCategoryCopyWithImpl(this._self, this._then);

  final _ExploreCategory _self;
  final $Res Function(_ExploreCategory) _then;

/// Create a copy of ExploreCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? url = freezed,}) {
  return _then(_ExploreCategory(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
