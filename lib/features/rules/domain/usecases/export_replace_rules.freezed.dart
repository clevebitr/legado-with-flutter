// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'export_replace_rules.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReplaceRuleExport {

/// The file name to suggest to the save dialog.
 String get fileName;/// The JSON text to write.
 String get contents;/// How many rules the document holds.
 int get count;/// How many stored rules were left out because their payload cannot be read.
 int get skipped;
/// Create a copy of ReplaceRuleExport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplaceRuleExportCopyWith<ReplaceRuleExport> get copyWith => _$ReplaceRuleExportCopyWithImpl<ReplaceRuleExport>(this as ReplaceRuleExport, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReplaceRuleExport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplaceRuleExport&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.contents, _this.contents) || other.contents == _this.contents)&&(identical(other.count, _this.count) || other.count == _this.count)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped));
}


@override
int get hashCode {
  final _this = this as ReplaceRuleExport;
  return Object.hash(runtimeType,_this.fileName,_this.contents,_this.count,_this.skipped);
}

@override
String toString() {
  final _this = this as ReplaceRuleExport;
  return 'ReplaceRuleExport(fileName: ${_this.fileName}, contents: ${_this.contents}, count: ${_this.count}, skipped: ${_this.skipped})';
}


}

/// @nodoc
abstract mixin class $ReplaceRuleExportCopyWith<$Res>  {
  factory $ReplaceRuleExportCopyWith(ReplaceRuleExport value, $Res Function(ReplaceRuleExport) _then) = _$ReplaceRuleExportCopyWithImpl;
@useResult
$Res call({
 String fileName, String contents, int count, int skipped
});




}
/// @nodoc
class _$ReplaceRuleExportCopyWithImpl<$Res>
    implements $ReplaceRuleExportCopyWith<$Res> {
  _$ReplaceRuleExportCopyWithImpl(this._self, this._then);

  final ReplaceRuleExport _self;
  final $Res Function(ReplaceRuleExport) _then;

/// Create a copy of ReplaceRuleExport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileName = null,Object? contents = null,Object? count = null,Object? skipped = null,}) {
  return _then(ReplaceRuleExport(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,contents: null == contents ? _self.contents : contents // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReplaceRuleExport].
extension ReplaceRuleExportPatterns on ReplaceRuleExport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReplaceRuleExport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReplaceRuleExport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReplaceRuleExport value)  $default,){
final _that = this;
switch (_that) {
case _ReplaceRuleExport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReplaceRuleExport value)?  $default,){
final _that = this;
switch (_that) {
case _ReplaceRuleExport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fileName,  String contents,  int count,  int skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReplaceRuleExport() when $default != null:
return $default(_that.fileName,_that.contents,_that.count,_that.skipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fileName,  String contents,  int count,  int skipped)  $default,) {final _that = this;
switch (_that) {
case _ReplaceRuleExport():
return $default(_that.fileName,_that.contents,_that.count,_that.skipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fileName,  String contents,  int count,  int skipped)?  $default,) {final _that = this;
switch (_that) {
case _ReplaceRuleExport() when $default != null:
return $default(_that.fileName,_that.contents,_that.count,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc


class _ReplaceRuleExport implements ReplaceRuleExport {
  const _ReplaceRuleExport({required this.fileName, required this.contents, required this.count, required this.skipped});
  

/// The file name to suggest to the save dialog.
@override final  String fileName;
/// The JSON text to write.
@override final  String contents;
/// How many rules the document holds.
@override final  int count;
/// How many stored rules were left out because their payload cannot be read.
@override final  int skipped;

/// Create a copy of ReplaceRuleExport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplaceRuleExportCopyWith<_ReplaceRuleExport> get copyWith => __$ReplaceRuleExportCopyWithImpl<_ReplaceRuleExport>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplaceRuleExport&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.contents, contents) || other.contents == contents)&&(identical(other.count, count) || other.count == count)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fileName,contents,count,skipped);
}

@override
String toString() {
    return 'ReplaceRuleExport(fileName: $fileName, contents: $contents, count: $count, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$ReplaceRuleExportCopyWith<$Res> implements $ReplaceRuleExportCopyWith<$Res> {
  factory _$ReplaceRuleExportCopyWith(_ReplaceRuleExport value, $Res Function(_ReplaceRuleExport) _then) = __$ReplaceRuleExportCopyWithImpl;
@override @useResult
$Res call({
 String fileName, String contents, int count, int skipped
});




}
/// @nodoc
class __$ReplaceRuleExportCopyWithImpl<$Res>
    implements _$ReplaceRuleExportCopyWith<$Res> {
  __$ReplaceRuleExportCopyWithImpl(this._self, this._then);

  final _ReplaceRuleExport _self;
  final $Res Function(_ReplaceRuleExport) _then;

/// Create a copy of ReplaceRuleExport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileName = null,Object? contents = null,Object? count = null,Object? skipped = null,}) {
  return _then(_ReplaceRuleExport(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,contents: null == contents ? _self.contents : contents // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
