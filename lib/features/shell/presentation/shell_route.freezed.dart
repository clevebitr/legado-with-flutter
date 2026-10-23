// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shell_route.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ShellRoute {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ShellRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ShellRoute()';
}


}

/// @nodoc
class $ShellRouteCopyWith<$Res>  {
$ShellRouteCopyWith(ShellRoute _, $Res Function(ShellRoute) __);
}


/// Adds pattern-matching-related methods to [ShellRoute].
extension ShellRoutePatterns on ShellRoute {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AboutRoute value)?  about,TResult Function( LegalNoticesRoute value)?  legalNotices,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AboutRoute() when about != null:
return about(_that);case LegalNoticesRoute() when legalNotices != null:
return legalNotices(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AboutRoute value)  about,required TResult Function( LegalNoticesRoute value)  legalNotices,}){
final _that = this;
switch (_that) {
case AboutRoute():
return about(_that);case LegalNoticesRoute():
return legalNotices(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AboutRoute value)?  about,TResult? Function( LegalNoticesRoute value)?  legalNotices,}){
final _that = this;
switch (_that) {
case AboutRoute() when about != null:
return about(_that);case LegalNoticesRoute() when legalNotices != null:
return legalNotices(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  about,TResult Function()?  legalNotices,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AboutRoute() when about != null:
return about();case LegalNoticesRoute() when legalNotices != null:
return legalNotices();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  about,required TResult Function()  legalNotices,}) {final _that = this;
switch (_that) {
case AboutRoute():
return about();case LegalNoticesRoute():
return legalNotices();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  about,TResult? Function()?  legalNotices,}) {final _that = this;
switch (_that) {
case AboutRoute() when about != null:
return about();case LegalNoticesRoute() when legalNotices != null:
return legalNotices();case _:
  return null;

}
}

}

/// @nodoc


class AboutRoute extends ShellRoute {
  const AboutRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AboutRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ShellRoute.about()';
}


}




/// @nodoc


class LegalNoticesRoute extends ShellRoute {
  const LegalNoticesRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LegalNoticesRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ShellRoute.legalNotices()';
}


}




// dart format on
