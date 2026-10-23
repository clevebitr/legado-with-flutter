// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingPage {

/// The absolute image URL.
 String get url;/// Headers the image request must carry.
 Map<String, String> get headers;
/// Create a copy of ReadingPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingPageCopyWith<ReadingPage> get copyWith => _$ReadingPageCopyWithImpl<ReadingPage>(this as ReadingPage, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingPage&&(identical(other.url, _this.url) || other.url == _this.url)&&const DeepCollectionEquality().equals(other.headers, _this.headers));
}


@override
int get hashCode {
  final _this = this as ReadingPage;
  return Object.hash(runtimeType,_this.url,const DeepCollectionEquality().hash(_this.headers));
}

@override
String toString() {
  final _this = this as ReadingPage;
  return 'ReadingPage(url: ${_this.url}, headers: ${_this.headers})';
}


}

/// @nodoc
abstract mixin class $ReadingPageCopyWith<$Res>  {
  factory $ReadingPageCopyWith(ReadingPage value, $Res Function(ReadingPage) _then) = _$ReadingPageCopyWithImpl;
@useResult
$Res call({
 String url, Map<String, String> headers
});




}
/// @nodoc
class _$ReadingPageCopyWithImpl<$Res>
    implements $ReadingPageCopyWith<$Res> {
  _$ReadingPageCopyWithImpl(this._self, this._then);

  final ReadingPage _self;
  final $Res Function(ReadingPage) _then;

/// Create a copy of ReadingPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? headers = null,}) {
  return _then(ReadingPage(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingPage].
extension ReadingPagePatterns on ReadingPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingPage value)  $default,){
final _that = this;
switch (_that) {
case _ReadingPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingPage value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  Map<String, String> headers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingPage() when $default != null:
return $default(_that.url,_that.headers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  Map<String, String> headers)  $default,) {final _that = this;
switch (_that) {
case _ReadingPage():
return $default(_that.url,_that.headers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  Map<String, String> headers)?  $default,) {final _that = this;
switch (_that) {
case _ReadingPage() when $default != null:
return $default(_that.url,_that.headers);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingPage implements ReadingPage {
  const _ReadingPage({required this.url,  Map<String, String> headers = const <String, String>{}}): _headers = headers;
  

/// The absolute image URL.
@override final  String url;
/// Headers the image request must carry.
 final  Map<String, String> _headers;
/// Headers the image request must carry.
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}


/// Create a copy of ReadingPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingPageCopyWith<_ReadingPage> get copyWith => __$ReadingPageCopyWithImpl<_ReadingPage>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingPage&&(identical(other.url, url) || other.url == url)&&const DeepCollectionEquality().equals(other.headers, _headers));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,const DeepCollectionEquality().hash(_headers));
}

@override
String toString() {
    return 'ReadingPage(url: $url, headers: $headers)';
}


}

/// @nodoc
abstract mixin class _$ReadingPageCopyWith<$Res> implements $ReadingPageCopyWith<$Res> {
  factory _$ReadingPageCopyWith(_ReadingPage value, $Res Function(_ReadingPage) _then) = __$ReadingPageCopyWithImpl;
@override @useResult
$Res call({
 String url, Map<String, String> headers
});




}
/// @nodoc
class __$ReadingPageCopyWithImpl<$Res>
    implements _$ReadingPageCopyWith<$Res> {
  __$ReadingPageCopyWithImpl(this._self, this._then);

  final _ReadingPage _self;
  final $Res Function(_ReadingPage) _then;

/// Create a copy of ReadingPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? headers = null,}) {
  return _then(_ReadingPage(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
