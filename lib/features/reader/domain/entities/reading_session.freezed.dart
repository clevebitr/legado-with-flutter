// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingSession {

/// `bookSourceUrl` of the source the book came from.
 String get sourceUrl;/// The book's detail page URL.
 String get bookUrl;/// The book title as the reader knew it.
 String get bookName;/// The chapter the session ended on, when the list had loaded.
 String? get chapterUrl;/// Its title, when known.
 String? get chapterName; DateTime get startedAt; DateTime get endedAt;
/// Create a copy of ReadingSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingSessionCopyWith<ReadingSession> get copyWith => _$ReadingSessionCopyWithImpl<ReadingSession>(this as ReadingSession, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingSession&&(identical(other.sourceUrl, _this.sourceUrl) || other.sourceUrl == _this.sourceUrl)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.bookName, _this.bookName) || other.bookName == _this.bookName)&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.chapterName, _this.chapterName) || other.chapterName == _this.chapterName)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.endedAt, _this.endedAt) || other.endedAt == _this.endedAt));
}


@override
int get hashCode {
  final _this = this as ReadingSession;
  return Object.hash(runtimeType,_this.sourceUrl,_this.bookUrl,_this.bookName,_this.chapterUrl,_this.chapterName,_this.startedAt,_this.endedAt);
}

@override
String toString() {
  final _this = this as ReadingSession;
  return 'ReadingSession(sourceUrl: ${_this.sourceUrl}, bookUrl: ${_this.bookUrl}, bookName: ${_this.bookName}, chapterUrl: ${_this.chapterUrl}, chapterName: ${_this.chapterName}, startedAt: ${_this.startedAt}, endedAt: ${_this.endedAt})';
}


}

/// @nodoc
abstract mixin class $ReadingSessionCopyWith<$Res>  {
  factory $ReadingSessionCopyWith(ReadingSession value, $Res Function(ReadingSession) _then) = _$ReadingSessionCopyWithImpl;
@useResult
$Res call({
 String sourceUrl, String bookUrl, String bookName, String? chapterUrl, String? chapterName, DateTime startedAt, DateTime endedAt
});




}
/// @nodoc
class _$ReadingSessionCopyWithImpl<$Res>
    implements $ReadingSessionCopyWith<$Res> {
  _$ReadingSessionCopyWithImpl(this._self, this._then);

  final ReadingSession _self;
  final $Res Function(ReadingSession) _then;

/// Create a copy of ReadingSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,Object? chapterUrl = freezed,Object? chapterName = freezed,Object? startedAt = null,Object? endedAt = null,}) {
  return _then(ReadingSession(
sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,chapterUrl: freezed == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: null == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingSession].
extension ReadingSessionPatterns on ReadingSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingSession value)  $default,){
final _that = this;
switch (_that) {
case _ReadingSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingSession value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceUrl,  String bookUrl,  String bookName,  String? chapterUrl,  String? chapterName,  DateTime startedAt,  DateTime endedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingSession() when $default != null:
return $default(_that.sourceUrl,_that.bookUrl,_that.bookName,_that.chapterUrl,_that.chapterName,_that.startedAt,_that.endedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceUrl,  String bookUrl,  String bookName,  String? chapterUrl,  String? chapterName,  DateTime startedAt,  DateTime endedAt)  $default,) {final _that = this;
switch (_that) {
case _ReadingSession():
return $default(_that.sourceUrl,_that.bookUrl,_that.bookName,_that.chapterUrl,_that.chapterName,_that.startedAt,_that.endedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceUrl,  String bookUrl,  String bookName,  String? chapterUrl,  String? chapterName,  DateTime startedAt,  DateTime endedAt)?  $default,) {final _that = this;
switch (_that) {
case _ReadingSession() when $default != null:
return $default(_that.sourceUrl,_that.bookUrl,_that.bookName,_that.chapterUrl,_that.chapterName,_that.startedAt,_that.endedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingSession extends ReadingSession {
  const _ReadingSession({required this.sourceUrl, required this.bookUrl, required this.bookName, this.chapterUrl, this.chapterName, required this.startedAt, required this.endedAt}): super._();
  

/// `bookSourceUrl` of the source the book came from.
@override final  String sourceUrl;
/// The book's detail page URL.
@override final  String bookUrl;
/// The book title as the reader knew it.
@override final  String bookName;
/// The chapter the session ended on, when the list had loaded.
@override final  String? chapterUrl;
/// Its title, when known.
@override final  String? chapterName;
@override final  DateTime startedAt;
@override final  DateTime endedAt;

/// Create a copy of ReadingSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingSessionCopyWith<_ReadingSession> get copyWith => __$ReadingSessionCopyWithImpl<_ReadingSession>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingSession&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.bookName, bookName) || other.bookName == bookName)&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.chapterName, chapterName) || other.chapterName == chapterName)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceUrl,bookUrl,bookName,chapterUrl,chapterName,startedAt,endedAt);
}

@override
String toString() {
    return 'ReadingSession(sourceUrl: $sourceUrl, bookUrl: $bookUrl, bookName: $bookName, chapterUrl: $chapterUrl, chapterName: $chapterName, startedAt: $startedAt, endedAt: $endedAt)';
}


}

/// @nodoc
abstract mixin class _$ReadingSessionCopyWith<$Res> implements $ReadingSessionCopyWith<$Res> {
  factory _$ReadingSessionCopyWith(_ReadingSession value, $Res Function(_ReadingSession) _then) = __$ReadingSessionCopyWithImpl;
@override @useResult
$Res call({
 String sourceUrl, String bookUrl, String bookName, String? chapterUrl, String? chapterName, DateTime startedAt, DateTime endedAt
});




}
/// @nodoc
class __$ReadingSessionCopyWithImpl<$Res>
    implements _$ReadingSessionCopyWith<$Res> {
  __$ReadingSessionCopyWithImpl(this._self, this._then);

  final _ReadingSession _self;
  final $Res Function(_ReadingSession) _then;

/// Create a copy of ReadingSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceUrl = null,Object? bookUrl = null,Object? bookName = null,Object? chapterUrl = freezed,Object? chapterName = freezed,Object? startedAt = null,Object? endedAt = null,}) {
  return _then(_ReadingSession(
sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,bookName: null == bookName ? _self.bookName : bookName // ignore: cast_nullable_to_non_nullable
as String,chapterUrl: freezed == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: null == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
