// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingRecord {

 int get id; String get sourceUrl; String get bookUrl; String get bookName; String? get chapterUrl; String? get chapterName; DateTime get startedAt; DateTime get endedAt; int get durationSeconds;
/// Create a copy of ReadingRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingRecordCopyWith<ReadingRecord> get copyWith => _$ReadingRecordCopyWithImpl<ReadingRecord>(this as ReadingRecord, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sourceUrl, _this.sourceUrl) || other.sourceUrl == _this.sourceUrl)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.bookName, _this.bookName) || other.bookName == _this.bookName)&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.chapterName, _this.chapterName) || other.chapterName == _this.chapterName)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.endedAt, _this.endedAt) || other.endedAt == _this.endedAt)&&(identical(other.durationSeconds, _this.durationSeconds) || other.durationSeconds == _this.durationSeconds));
}


@override
int get hashCode {
  final _this = this as ReadingRecord;
  return Object.hash(runtimeType,_this.id,_this.sourceUrl,_this.bookUrl,_this.bookName,_this.chapterUrl,_this.chapterName,_this.startedAt,_this.endedAt,_this.durationSeconds);
}

@override
String toString() {
  final _this = this as ReadingRecord;
  return 'ReadingRecord(id: ${_this.id}, sourceUrl: ${_this.sourceUrl}, bookUrl: ${_this.bookUrl}, bookName: ${_this.bookName}, chapterUrl: ${_this.chapterUrl}, chapterName: ${_this.chapterName}, startedAt: ${_this.startedAt}, endedAt: ${_this.endedAt}, durationSeconds: ${_this.durationSeconds})';
}


}

/// @nodoc
abstract mixin class $ReadingRecordCopyWith<$Res>  {
  factory $ReadingRecordCopyWith(ReadingRecord value, $Res Function(ReadingRecord) _then) = _$ReadingRecordCopyWithImpl;
@useResult
$Res call({
 int id, String sourceUrl, String bookUrl, String bookName, String? chapterUrl, String? chapterName, DateTime startedAt, DateTime endedAt, int durationSeconds
});




}
/// @nodoc
class _$ReadingRecordCopyWithImpl<$Res>
    implements $ReadingRecordCopyWith<$Res> {
  _$ReadingRecordCopyWithImpl(this._self, this._then);

  final ReadingRecord _self;
  final $Res Function(ReadingRecord) _then;

/// Create a copy of ReadingRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,Object? chapterUrl = freezed,Object? chapterName = freezed,Object? startedAt = null,Object? endedAt = null,Object? durationSeconds = null,}) {
  return _then(ReadingRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,chapterUrl: freezed == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: null == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingRecord].
extension ReadingRecordPatterns on ReadingRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingRecord value)  $default,){
final _that = this;
switch (_that) {
case _ReadingRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingRecord value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String sourceUrl,  String bookUrl,  String bookName,  String? chapterUrl,  String? chapterName,  DateTime startedAt,  DateTime endedAt,  int durationSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingRecord() when $default != null:
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.bookName,_that.chapterUrl,_that.chapterName,_that.startedAt,_that.endedAt,_that.durationSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String sourceUrl,  String bookUrl,  String bookName,  String? chapterUrl,  String? chapterName,  DateTime startedAt,  DateTime endedAt,  int durationSeconds)  $default,) {final _that = this;
switch (_that) {
case _ReadingRecord():
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.bookName,_that.chapterUrl,_that.chapterName,_that.startedAt,_that.endedAt,_that.durationSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String sourceUrl,  String bookUrl,  String bookName,  String? chapterUrl,  String? chapterName,  DateTime startedAt,  DateTime endedAt,  int durationSeconds)?  $default,) {final _that = this;
switch (_that) {
case _ReadingRecord() when $default != null:
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.bookName,_that.chapterUrl,_that.chapterName,_that.startedAt,_that.endedAt,_that.durationSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingRecord implements ReadingRecord {
  const _ReadingRecord({required this.id, required this.sourceUrl, required this.bookUrl, required this.bookName, this.chapterUrl, this.chapterName, required this.startedAt, required this.endedAt, required this.durationSeconds});
  

@override final  int id;
@override final  String sourceUrl;
@override final  String bookUrl;
@override final  String bookName;
@override final  String? chapterUrl;
@override final  String? chapterName;
@override final  DateTime startedAt;
@override final  DateTime endedAt;
@override final  int durationSeconds;

/// Create a copy of ReadingRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingRecordCopyWith<_ReadingRecord> get copyWith => __$ReadingRecordCopyWithImpl<_ReadingRecord>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.bookName, bookName) || other.bookName == bookName)&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.chapterName, chapterName) || other.chapterName == chapterName)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,sourceUrl,bookUrl,bookName,chapterUrl,chapterName,startedAt,endedAt,durationSeconds);
}

@override
String toString() {
    return 'ReadingRecord(id: $id, sourceUrl: $sourceUrl, bookUrl: $bookUrl, bookName: $bookName, chapterUrl: $chapterUrl, chapterName: $chapterName, startedAt: $startedAt, endedAt: $endedAt, durationSeconds: $durationSeconds)';
}


}

/// @nodoc
abstract mixin class _$ReadingRecordCopyWith<$Res> implements $ReadingRecordCopyWith<$Res> {
  factory _$ReadingRecordCopyWith(_ReadingRecord value, $Res Function(_ReadingRecord) _then) = __$ReadingRecordCopyWithImpl;
@override @useResult
$Res call({
 int id, String sourceUrl, String bookUrl, String bookName, String? chapterUrl, String? chapterName, DateTime startedAt, DateTime endedAt, int durationSeconds
});




}
/// @nodoc
class __$ReadingRecordCopyWithImpl<$Res>
    implements _$ReadingRecordCopyWith<$Res> {
  __$ReadingRecordCopyWithImpl(this._self, this._then);

  final _ReadingRecord _self;
  final $Res Function(_ReadingRecord) _then;

/// Create a copy of ReadingRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,Object? chapterUrl = freezed,Object? chapterName = freezed,Object? startedAt = null,Object? endedAt = null,Object? durationSeconds = null,}) {
  return _then(_ReadingRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,chapterUrl: freezed == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: null == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
