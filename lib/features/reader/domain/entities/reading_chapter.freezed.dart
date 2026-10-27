// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_chapter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingChapter {

/// The title as the source spelled it; may be empty when the rule matched nothing.
 String get title;/// The absolute chapter URL.
 String get url;/// Whether the source marked the chapter VIP-only (`chapter.isVip`, M25/S3b).
///
/// The reader itself only needs the title and the address, but the content stage's rules read
/// the chapter as `chapter.*` upstream, so the flags have to reach the adapter that builds them.
 bool get isVip;/// Whether the source marked the chapter as bought (`chapter.isPay`).
 bool get isPay;/// Whether this entry is a volume heading rather than a chapter (`chapter.isVolume`).
 bool get isVolume;/// The display-only update time the source had, or `null`.
 String? get updateTime;
/// Create a copy of ReadingChapter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingChapterCopyWith<ReadingChapter> get copyWith => _$ReadingChapterCopyWithImpl<ReadingChapter>(this as ReadingChapter, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingChapter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingChapter&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.isVip, _this.isVip) || other.isVip == _this.isVip)&&(identical(other.isPay, _this.isPay) || other.isPay == _this.isPay)&&(identical(other.isVolume, _this.isVolume) || other.isVolume == _this.isVolume)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime));
}


@override
int get hashCode {
  final _this = this as ReadingChapter;
  return Object.hash(runtimeType,_this.title,_this.url,_this.isVip,_this.isPay,_this.isVolume,_this.updateTime);
}

@override
String toString() {
  final _this = this as ReadingChapter;
  return 'ReadingChapter(title: ${_this.title}, url: ${_this.url}, isVip: ${_this.isVip}, isPay: ${_this.isPay}, isVolume: ${_this.isVolume}, updateTime: ${_this.updateTime})';
}


}

/// @nodoc
abstract mixin class $ReadingChapterCopyWith<$Res>  {
  factory $ReadingChapterCopyWith(ReadingChapter value, $Res Function(ReadingChapter) _then) = _$ReadingChapterCopyWithImpl;
@useResult
$Res call({
 String title, String url, bool isVip, bool isPay, bool isVolume, String? updateTime
});




}
/// @nodoc
class _$ReadingChapterCopyWithImpl<$Res>
    implements $ReadingChapterCopyWith<$Res> {
  _$ReadingChapterCopyWithImpl(this._self, this._then);

  final ReadingChapter _self;
  final $Res Function(ReadingChapter) _then;

/// Create a copy of ReadingChapter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? url = null,Object? isVip = null,Object? isPay = null,Object? isVolume = null,Object? updateTime = freezed,}) {
  return _then(ReadingChapter(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,isVip: null == isVip ? _self.isVip : isVip // ignore: cast_nullable_to_non_nullable
as bool,isPay: null == isPay ? _self.isPay : isPay // ignore: cast_nullable_to_non_nullable
as bool,isVolume: null == isVolume ? _self.isVolume : isVolume // ignore: cast_nullable_to_non_nullable
as bool,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingChapter].
extension ReadingChapterPatterns on ReadingChapter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingChapter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingChapter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingChapter value)  $default,){
final _that = this;
switch (_that) {
case _ReadingChapter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingChapter value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingChapter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String url,  bool isVip,  bool isPay,  bool isVolume,  String? updateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingChapter() when $default != null:
return $default(_that.title,_that.url,_that.isVip,_that.isPay,_that.isVolume,_that.updateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String url,  bool isVip,  bool isPay,  bool isVolume,  String? updateTime)  $default,) {final _that = this;
switch (_that) {
case _ReadingChapter():
return $default(_that.title,_that.url,_that.isVip,_that.isPay,_that.isVolume,_that.updateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String url,  bool isVip,  bool isPay,  bool isVolume,  String? updateTime)?  $default,) {final _that = this;
switch (_that) {
case _ReadingChapter() when $default != null:
return $default(_that.title,_that.url,_that.isVip,_that.isPay,_that.isVolume,_that.updateTime);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingChapter implements ReadingChapter {
  const _ReadingChapter({required this.title, required this.url, this.isVip = false, this.isPay = false, this.isVolume = false, this.updateTime});
  

/// The title as the source spelled it; may be empty when the rule matched nothing.
@override final  String title;
/// The absolute chapter URL.
@override final  String url;
/// Whether the source marked the chapter VIP-only (`chapter.isVip`, M25/S3b).
///
/// The reader itself only needs the title and the address, but the content stage's rules read
/// the chapter as `chapter.*` upstream, so the flags have to reach the adapter that builds them.
@override@JsonKey() final  bool isVip;
/// Whether the source marked the chapter as bought (`chapter.isPay`).
@override@JsonKey() final  bool isPay;
/// Whether this entry is a volume heading rather than a chapter (`chapter.isVolume`).
@override@JsonKey() final  bool isVolume;
/// The display-only update time the source had, or `null`.
@override final  String? updateTime;

/// Create a copy of ReadingChapter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingChapterCopyWith<_ReadingChapter> get copyWith => __$ReadingChapterCopyWithImpl<_ReadingChapter>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingChapter&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.isVip, isVip) || other.isVip == isVip)&&(identical(other.isPay, isPay) || other.isPay == isPay)&&(identical(other.isVolume, isVolume) || other.isVolume == isVolume)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,url,isVip,isPay,isVolume,updateTime);
}

@override
String toString() {
    return 'ReadingChapter(title: $title, url: $url, isVip: $isVip, isPay: $isPay, isVolume: $isVolume, updateTime: $updateTime)';
}


}

/// @nodoc
abstract mixin class _$ReadingChapterCopyWith<$Res> implements $ReadingChapterCopyWith<$Res> {
  factory _$ReadingChapterCopyWith(_ReadingChapter value, $Res Function(_ReadingChapter) _then) = __$ReadingChapterCopyWithImpl;
@override @useResult
$Res call({
 String title, String url, bool isVip, bool isPay, bool isVolume, String? updateTime
});




}
/// @nodoc
class __$ReadingChapterCopyWithImpl<$Res>
    implements _$ReadingChapterCopyWith<$Res> {
  __$ReadingChapterCopyWithImpl(this._self, this._then);

  final _ReadingChapter _self;
  final $Res Function(_ReadingChapter) _then;

/// Create a copy of ReadingChapter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? url = null,Object? isVip = null,Object? isPay = null,Object? isVolume = null,Object? updateTime = freezed,}) {
  return _then(_ReadingChapter(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,isVip: null == isVip ? _self.isVip : isVip // ignore: cast_nullable_to_non_nullable
as bool,isPay: null == isPay ? _self.isPay : isPay // ignore: cast_nullable_to_non_nullable
as bool,isVolume: null == isVolume ? _self.isVolume : isVolume // ignore: cast_nullable_to_non_nullable
as bool,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
