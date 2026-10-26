// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'export_book_sources.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookSourceExport {

/// The file name to suggest to the save dialog.
 String get fileName;/// The JSON text to write.
 String get contents;/// How many sources the document holds.
 int get count;
/// Create a copy of BookSourceExport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSourceExportCopyWith<BookSourceExport> get copyWith => _$BookSourceExportCopyWithImpl<BookSourceExport>(this as BookSourceExport, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookSourceExport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceExport&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.contents, _this.contents) || other.contents == _this.contents)&&(identical(other.count, _this.count) || other.count == _this.count));
}


@override
int get hashCode {
  final _this = this as BookSourceExport;
  return Object.hash(runtimeType,_this.fileName,_this.contents,_this.count);
}

@override
String toString() {
  final _this = this as BookSourceExport;
  return 'BookSourceExport(fileName: ${_this.fileName}, contents: ${_this.contents}, count: ${_this.count})';
}


}

/// @nodoc
abstract mixin class $BookSourceExportCopyWith<$Res>  {
  factory $BookSourceExportCopyWith(BookSourceExport value, $Res Function(BookSourceExport) _then) = _$BookSourceExportCopyWithImpl;
@useResult
$Res call({
 String fileName, String contents, int count
});




}
/// @nodoc
class _$BookSourceExportCopyWithImpl<$Res>
    implements $BookSourceExportCopyWith<$Res> {
  _$BookSourceExportCopyWithImpl(this._self, this._then);

  final BookSourceExport _self;
  final $Res Function(BookSourceExport) _then;

/// Create a copy of BookSourceExport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileName = null,Object? contents = null,Object? count = null,}) {
  return _then(BookSourceExport(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,contents: null == contents ? _self.contents : contents // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BookSourceExport].
extension BookSourceExportPatterns on BookSourceExport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookSourceExport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookSourceExport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookSourceExport value)  $default,){
final _that = this;
switch (_that) {
case _BookSourceExport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookSourceExport value)?  $default,){
final _that = this;
switch (_that) {
case _BookSourceExport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fileName,  String contents,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookSourceExport() when $default != null:
return $default(_that.fileName,_that.contents,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fileName,  String contents,  int count)  $default,) {final _that = this;
switch (_that) {
case _BookSourceExport():
return $default(_that.fileName,_that.contents,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fileName,  String contents,  int count)?  $default,) {final _that = this;
switch (_that) {
case _BookSourceExport() when $default != null:
return $default(_that.fileName,_that.contents,_that.count);case _:
  return null;

}
}

}

/// @nodoc


class _BookSourceExport implements BookSourceExport {
  const _BookSourceExport({required this.fileName, required this.contents, required this.count});
  

/// The file name to suggest to the save dialog.
@override final  String fileName;
/// The JSON text to write.
@override final  String contents;
/// How many sources the document holds.
@override final  int count;

/// Create a copy of BookSourceExport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookSourceExportCopyWith<_BookSourceExport> get copyWith => __$BookSourceExportCopyWithImpl<_BookSourceExport>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookSourceExport&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.contents, contents) || other.contents == contents)&&(identical(other.count, count) || other.count == count));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fileName,contents,count);
}

@override
String toString() {
    return 'BookSourceExport(fileName: $fileName, contents: $contents, count: $count)';
}


}

/// @nodoc
abstract mixin class _$BookSourceExportCopyWith<$Res> implements $BookSourceExportCopyWith<$Res> {
  factory _$BookSourceExportCopyWith(_BookSourceExport value, $Res Function(_BookSourceExport) _then) = __$BookSourceExportCopyWithImpl;
@override @useResult
$Res call({
 String fileName, String contents, int count
});




}
/// @nodoc
class __$BookSourceExportCopyWithImpl<$Res>
    implements _$BookSourceExportCopyWith<$Res> {
  __$BookSourceExportCopyWithImpl(this._self, this._then);

  final _BookSourceExport _self;
  final $Res Function(_BookSourceExport) _then;

/// Create a copy of BookSourceExport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileName = null,Object? contents = null,Object? count = null,}) {
  return _then(_BookSourceExport(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,contents: null == contents ? _self.contents : contents // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
