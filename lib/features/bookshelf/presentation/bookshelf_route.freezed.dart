// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bookshelf_route.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookshelfRoute {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookshelfRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookshelfRoute()';
}


}

/// @nodoc
class $BookshelfRouteCopyWith<$Res>  {
$BookshelfRouteCopyWith(BookshelfRoute _, $Res Function(BookshelfRoute) __);
}


/// Adds pattern-matching-related methods to [BookshelfRoute].
extension BookshelfRoutePatterns on BookshelfRoute {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ShelfRoute value)?  shelf,TResult Function( ShelfGroupsRoute value)?  groups,TResult Function( ShelfBookEditRoute value)?  editBook,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ShelfRoute() when shelf != null:
return shelf(_that);case ShelfGroupsRoute() when groups != null:
return groups(_that);case ShelfBookEditRoute() when editBook != null:
return editBook(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ShelfRoute value)  shelf,required TResult Function( ShelfGroupsRoute value)  groups,required TResult Function( ShelfBookEditRoute value)  editBook,}){
final _that = this;
switch (_that) {
case ShelfRoute():
return shelf(_that);case ShelfGroupsRoute():
return groups(_that);case ShelfBookEditRoute():
return editBook(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ShelfRoute value)?  shelf,TResult? Function( ShelfGroupsRoute value)?  groups,TResult? Function( ShelfBookEditRoute value)?  editBook,}){
final _that = this;
switch (_that) {
case ShelfRoute() when shelf != null:
return shelf(_that);case ShelfGroupsRoute() when groups != null:
return groups(_that);case ShelfBookEditRoute() when editBook != null:
return editBook(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  shelf,TResult Function()?  groups,TResult Function( ShelvedBook book)?  editBook,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ShelfRoute() when shelf != null:
return shelf();case ShelfGroupsRoute() when groups != null:
return groups();case ShelfBookEditRoute() when editBook != null:
return editBook(_that.book);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  shelf,required TResult Function()  groups,required TResult Function( ShelvedBook book)  editBook,}) {final _that = this;
switch (_that) {
case ShelfRoute():
return shelf();case ShelfGroupsRoute():
return groups();case ShelfBookEditRoute():
return editBook(_that.book);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  shelf,TResult? Function()?  groups,TResult? Function( ShelvedBook book)?  editBook,}) {final _that = this;
switch (_that) {
case ShelfRoute() when shelf != null:
return shelf();case ShelfGroupsRoute() when groups != null:
return groups();case ShelfBookEditRoute() when editBook != null:
return editBook(_that.book);case _:
  return null;

}
}

}

/// @nodoc


class ShelfRoute extends BookshelfRoute {
  const ShelfRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookshelfRoute.shelf()';
}


}




/// @nodoc


class ShelfGroupsRoute extends BookshelfRoute {
  const ShelfGroupsRoute(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfGroupsRoute);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookshelfRoute.groups()';
}


}




/// @nodoc


class ShelfBookEditRoute extends BookshelfRoute {
  const ShelfBookEditRoute({required this.book}): super._();
  

 final  ShelvedBook book;

/// Create a copy of BookshelfRoute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShelfBookEditRouteCopyWith<ShelfBookEditRoute> get copyWith => _$ShelfBookEditRouteCopyWithImpl<ShelfBookEditRoute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfBookEditRoute&&(identical(other.book, book) || other.book == book));
}


@override
int get hashCode {
    return Object.hash(runtimeType,book);
}

@override
String toString() {
    return 'BookshelfRoute.editBook(book: $book)';
}


}

/// @nodoc
abstract mixin class $ShelfBookEditRouteCopyWith<$Res> implements $BookshelfRouteCopyWith<$Res> {
  factory $ShelfBookEditRouteCopyWith(ShelfBookEditRoute value, $Res Function(ShelfBookEditRoute) _then) = _$ShelfBookEditRouteCopyWithImpl;
@useResult
$Res call({
 ShelvedBook book
});


$ShelvedBookCopyWith<$Res> get book;

}
/// @nodoc
class _$ShelfBookEditRouteCopyWithImpl<$Res>
    implements $ShelfBookEditRouteCopyWith<$Res> {
  _$ShelfBookEditRouteCopyWithImpl(this._self, this._then);

  final ShelfBookEditRoute _self;
  final $Res Function(ShelfBookEditRoute) _then;

/// Create a copy of BookshelfRoute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? book = null,}) {
  return _then(ShelfBookEditRoute(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as ShelvedBook,
  ));
}

/// Create a copy of BookshelfRoute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ShelvedBookCopyWith<$Res> get book {
  
  return $ShelvedBookCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}

// dart format on
