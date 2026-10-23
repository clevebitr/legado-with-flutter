// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReaderBook {

/// `bookSourceUrl` of the source the book came from.
 String get sourceUrl;/// The book's detail page URL — its identity inside [sourceUrl].
 String get bookUrl;/// The title to show while reading.
 String get name;/// The table-of-contents URL; the book page itself when the source declares no `tocUrl` rule.
 String get tocUrl;
/// Create a copy of ReaderBook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderBookCopyWith<ReaderBook> get copyWith => _$ReaderBookCopyWithImpl<ReaderBook>(this as ReaderBook, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReaderBook;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderBook&&(identical(other.sourceUrl, _this.sourceUrl) || other.sourceUrl == _this.sourceUrl)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.tocUrl, _this.tocUrl) || other.tocUrl == _this.tocUrl));
}


@override
int get hashCode {
  final _this = this as ReaderBook;
  return Object.hash(runtimeType,_this.sourceUrl,_this.bookUrl,_this.name,_this.tocUrl);
}

@override
String toString() {
  final _this = this as ReaderBook;
  return 'ReaderBook(sourceUrl: ${_this.sourceUrl}, bookUrl: ${_this.bookUrl}, name: ${_this.name}, tocUrl: ${_this.tocUrl})';
}


}

/// @nodoc
abstract mixin class $ReaderBookCopyWith<$Res>  {
  factory $ReaderBookCopyWith(ReaderBook value, $Res Function(ReaderBook) _then) = _$ReaderBookCopyWithImpl;
@useResult
$Res call({
 String sourceUrl, String bookUrl, String name, String tocUrl
});




}
/// @nodoc
class _$ReaderBookCopyWithImpl<$Res>
    implements $ReaderBookCopyWith<$Res> {
  _$ReaderBookCopyWithImpl(this._self, this._then);

  final ReaderBook _self;
  final $Res Function(ReaderBook) _then;

/// Create a copy of ReaderBook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceUrl = null,Object? bookUrl = null,Object? name = null,Object? tocUrl = null,}) {
  return _then(ReaderBook(
sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tocUrl: null == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderBook].
extension ReaderBookPatterns on ReaderBook {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderBook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderBook() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderBook value)  $default,){
final _that = this;
switch (_that) {
case _ReaderBook():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderBook value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderBook() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceUrl,  String bookUrl,  String name,  String tocUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderBook() when $default != null:
return $default(_that.sourceUrl,_that.bookUrl,_that.name,_that.tocUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceUrl,  String bookUrl,  String name,  String tocUrl)  $default,) {final _that = this;
switch (_that) {
case _ReaderBook():
return $default(_that.sourceUrl,_that.bookUrl,_that.name,_that.tocUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceUrl,  String bookUrl,  String name,  String tocUrl)?  $default,) {final _that = this;
switch (_that) {
case _ReaderBook() when $default != null:
return $default(_that.sourceUrl,_that.bookUrl,_that.name,_that.tocUrl);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderBook implements ReaderBook {
  const _ReaderBook({required this.sourceUrl, required this.bookUrl, required this.name, required this.tocUrl});
  

/// `bookSourceUrl` of the source the book came from.
@override final  String sourceUrl;
/// The book's detail page URL — its identity inside [sourceUrl].
@override final  String bookUrl;
/// The title to show while reading.
@override final  String name;
/// The table-of-contents URL; the book page itself when the source declares no `tocUrl` rule.
@override final  String tocUrl;

/// Create a copy of ReaderBook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderBookCopyWith<_ReaderBook> get copyWith => __$ReaderBookCopyWithImpl<_ReaderBook>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderBook&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.name, name) || other.name == name)&&(identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceUrl,bookUrl,name,tocUrl);
}

@override
String toString() {
    return 'ReaderBook(sourceUrl: $sourceUrl, bookUrl: $bookUrl, name: $name, tocUrl: $tocUrl)';
}


}

/// @nodoc
abstract mixin class _$ReaderBookCopyWith<$Res> implements $ReaderBookCopyWith<$Res> {
  factory _$ReaderBookCopyWith(_ReaderBook value, $Res Function(_ReaderBook) _then) = __$ReaderBookCopyWithImpl;
@override @useResult
$Res call({
 String sourceUrl, String bookUrl, String name, String tocUrl
});




}
/// @nodoc
class __$ReaderBookCopyWithImpl<$Res>
    implements _$ReaderBookCopyWith<$Res> {
  __$ReaderBookCopyWithImpl(this._self, this._then);

  final _ReaderBook _self;
  final $Res Function(_ReaderBook) _then;

/// Create a copy of ReaderBook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceUrl = null,Object? bookUrl = null,Object? name = null,Object? tocUrl = null,}) {
  return _then(_ReaderBook(
sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tocUrl: null == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
