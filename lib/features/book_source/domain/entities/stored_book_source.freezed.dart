// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stored_book_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StoredBookSource {

/// The synthetic primary key; stable across re-imports, which is what lets the UI hold on
/// to "the current source" (ADR-0040 §决策 1).
 int get id;/// The parsed book source, with [BookSource.isEnabled] already copied onto it and the row's
/// own `customOrder` alongside (the model has no such field; `docs/dev/roadmap.md` 5.5 owns its display).
 BookSource get source;/// Whether the source takes part in search and explore.
 bool get isEnabled;/// The manual sort order the user gave it.
 int get customOrder;/// When the row was first imported.
 DateTime get importedAt;/// `bookSourceGroup` as stored, including the tokens the batch check writes (`搜索失效` …).
 String? get groupName;/// `lastUpdateTime` as stored, in milliseconds since the epoch.
 int? get lastUpdateTime;/// `respondTime` as stored — the last check's duration, or `null` when it was never checked.
 int? get respondTime;/// `weight` as stored; the list can sort by it (ADR-0045 §决策 2).
 int? get weight;/// `bookSourceComment` as stored, i.e. the user's note plus the check's `// Error: ` block.
 String? get comment;
/// Create a copy of StoredBookSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredBookSourceCopyWith<StoredBookSource> get copyWith => _$StoredBookSourceCopyWithImpl<StoredBookSource>(this as StoredBookSource, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StoredBookSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredBookSource&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.isEnabled, _this.isEnabled) || other.isEnabled == _this.isEnabled)&&(identical(other.customOrder, _this.customOrder) || other.customOrder == _this.customOrder)&&(identical(other.importedAt, _this.importedAt) || other.importedAt == _this.importedAt)&&(identical(other.groupName, _this.groupName) || other.groupName == _this.groupName)&&(identical(other.lastUpdateTime, _this.lastUpdateTime) || other.lastUpdateTime == _this.lastUpdateTime)&&(identical(other.respondTime, _this.respondTime) || other.respondTime == _this.respondTime)&&(identical(other.weight, _this.weight) || other.weight == _this.weight)&&(identical(other.comment, _this.comment) || other.comment == _this.comment));
}


@override
int get hashCode {
  final _this = this as StoredBookSource;
  return Object.hash(runtimeType,_this.id,_this.source,_this.isEnabled,_this.customOrder,_this.importedAt,_this.groupName,_this.lastUpdateTime,_this.respondTime,_this.weight,_this.comment);
}

@override
String toString() {
  final _this = this as StoredBookSource;
  return 'StoredBookSource(id: ${_this.id}, source: ${_this.source}, isEnabled: ${_this.isEnabled}, customOrder: ${_this.customOrder}, importedAt: ${_this.importedAt}, groupName: ${_this.groupName}, lastUpdateTime: ${_this.lastUpdateTime}, respondTime: ${_this.respondTime}, weight: ${_this.weight}, comment: ${_this.comment})';
}


}

/// @nodoc
abstract mixin class $StoredBookSourceCopyWith<$Res>  {
  factory $StoredBookSourceCopyWith(StoredBookSource value, $Res Function(StoredBookSource) _then) = _$StoredBookSourceCopyWithImpl;
@useResult
$Res call({
 int id, BookSource source, bool isEnabled, int customOrder, DateTime importedAt, String? groupName, int? lastUpdateTime, int? respondTime, int? weight, String? comment
});


$BookSourceCopyWith<$Res> get source;

}
/// @nodoc
class _$StoredBookSourceCopyWithImpl<$Res>
    implements $StoredBookSourceCopyWith<$Res> {
  _$StoredBookSourceCopyWithImpl(this._self, this._then);

  final StoredBookSource _self;
  final $Res Function(StoredBookSource) _then;

/// Create a copy of StoredBookSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? source = null,Object? isEnabled = null,Object? customOrder = null,Object? importedAt = null,Object? groupName = freezed,Object? lastUpdateTime = freezed,Object? respondTime = freezed,Object? weight = freezed,Object? comment = freezed,}) {
  return _then(StoredBookSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as BookSource,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,customOrder: null == customOrder ? _self.customOrder : customOrder // ignore: cast_nullable_to_non_nullable
as int,importedAt: null == importedAt ? _self.importedAt : importedAt // ignore: cast_nullable_to_non_nullable
as DateTime,groupName: freezed == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String?,lastUpdateTime: freezed == lastUpdateTime ? _self.lastUpdateTime : lastUpdateTime // ignore: cast_nullable_to_non_nullable
as int?,respondTime: freezed == respondTime ? _self.respondTime : respondTime // ignore: cast_nullable_to_non_nullable
as int?,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as int?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of StoredBookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookSourceCopyWith<$Res> get source {
  
  return $BookSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// Adds pattern-matching-related methods to [StoredBookSource].
extension StoredBookSourcePatterns on StoredBookSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StoredBookSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StoredBookSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StoredBookSource value)  $default,){
final _that = this;
switch (_that) {
case _StoredBookSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StoredBookSource value)?  $default,){
final _that = this;
switch (_that) {
case _StoredBookSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  BookSource source,  bool isEnabled,  int customOrder,  DateTime importedAt,  String? groupName,  int? lastUpdateTime,  int? respondTime,  int? weight,  String? comment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoredBookSource() when $default != null:
return $default(_that.id,_that.source,_that.isEnabled,_that.customOrder,_that.importedAt,_that.groupName,_that.lastUpdateTime,_that.respondTime,_that.weight,_that.comment);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  BookSource source,  bool isEnabled,  int customOrder,  DateTime importedAt,  String? groupName,  int? lastUpdateTime,  int? respondTime,  int? weight,  String? comment)  $default,) {final _that = this;
switch (_that) {
case _StoredBookSource():
return $default(_that.id,_that.source,_that.isEnabled,_that.customOrder,_that.importedAt,_that.groupName,_that.lastUpdateTime,_that.respondTime,_that.weight,_that.comment);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  BookSource source,  bool isEnabled,  int customOrder,  DateTime importedAt,  String? groupName,  int? lastUpdateTime,  int? respondTime,  int? weight,  String? comment)?  $default,) {final _that = this;
switch (_that) {
case _StoredBookSource() when $default != null:
return $default(_that.id,_that.source,_that.isEnabled,_that.customOrder,_that.importedAt,_that.groupName,_that.lastUpdateTime,_that.respondTime,_that.weight,_that.comment);case _:
  return null;

}
}

}

/// @nodoc


class _StoredBookSource implements StoredBookSource {
  const _StoredBookSource({required this.id, required this.source, required this.isEnabled, required this.customOrder, required this.importedAt, this.groupName, this.lastUpdateTime, this.respondTime, this.weight, this.comment});
  

/// The synthetic primary key; stable across re-imports, which is what lets the UI hold on
/// to "the current source" (ADR-0040 §决策 1).
@override final  int id;
/// The parsed book source, with [BookSource.isEnabled] already copied onto it and the row's
/// own `customOrder` alongside (the model has no such field; `docs/dev/roadmap.md` 5.5 owns its display).
@override final  BookSource source;
/// Whether the source takes part in search and explore.
@override final  bool isEnabled;
/// The manual sort order the user gave it.
@override final  int customOrder;
/// When the row was first imported.
@override final  DateTime importedAt;
/// `bookSourceGroup` as stored, including the tokens the batch check writes (`搜索失效` …).
@override final  String? groupName;
/// `lastUpdateTime` as stored, in milliseconds since the epoch.
@override final  int? lastUpdateTime;
/// `respondTime` as stored — the last check's duration, or `null` when it was never checked.
@override final  int? respondTime;
/// `weight` as stored; the list can sort by it (ADR-0045 §决策 2).
@override final  int? weight;
/// `bookSourceComment` as stored, i.e. the user's note plus the check's `// Error: ` block.
@override final  String? comment;

/// Create a copy of StoredBookSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoredBookSourceCopyWith<_StoredBookSource> get copyWith => __$StoredBookSourceCopyWithImpl<_StoredBookSource>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoredBookSource&&(identical(other.id, id) || other.id == id)&&(identical(other.source, source) || other.source == source)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.customOrder, customOrder) || other.customOrder == customOrder)&&(identical(other.importedAt, importedAt) || other.importedAt == importedAt)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.lastUpdateTime, lastUpdateTime) || other.lastUpdateTime == lastUpdateTime)&&(identical(other.respondTime, respondTime) || other.respondTime == respondTime)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.comment, comment) || other.comment == comment));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,source,isEnabled,customOrder,importedAt,groupName,lastUpdateTime,respondTime,weight,comment);
}

@override
String toString() {
    return 'StoredBookSource(id: $id, source: $source, isEnabled: $isEnabled, customOrder: $customOrder, importedAt: $importedAt, groupName: $groupName, lastUpdateTime: $lastUpdateTime, respondTime: $respondTime, weight: $weight, comment: $comment)';
}


}

/// @nodoc
abstract mixin class _$StoredBookSourceCopyWith<$Res> implements $StoredBookSourceCopyWith<$Res> {
  factory _$StoredBookSourceCopyWith(_StoredBookSource value, $Res Function(_StoredBookSource) _then) = __$StoredBookSourceCopyWithImpl;
@override @useResult
$Res call({
 int id, BookSource source, bool isEnabled, int customOrder, DateTime importedAt, String? groupName, int? lastUpdateTime, int? respondTime, int? weight, String? comment
});


@override $BookSourceCopyWith<$Res> get source;

}
/// @nodoc
class __$StoredBookSourceCopyWithImpl<$Res>
    implements _$StoredBookSourceCopyWith<$Res> {
  __$StoredBookSourceCopyWithImpl(this._self, this._then);

  final _StoredBookSource _self;
  final $Res Function(_StoredBookSource) _then;

/// Create a copy of StoredBookSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? source = null,Object? isEnabled = null,Object? customOrder = null,Object? importedAt = null,Object? groupName = freezed,Object? lastUpdateTime = freezed,Object? respondTime = freezed,Object? weight = freezed,Object? comment = freezed,}) {
  return _then(_StoredBookSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as BookSource,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,customOrder: null == customOrder ? _self.customOrder : customOrder // ignore: cast_nullable_to_non_nullable
as int,importedAt: null == importedAt ? _self.importedAt : importedAt // ignore: cast_nullable_to_non_nullable
as DateTime,groupName: freezed == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String?,lastUpdateTime: freezed == lastUpdateTime ? _self.lastUpdateTime : lastUpdateTime // ignore: cast_nullable_to_non_nullable
as int?,respondTime: freezed == respondTime ? _self.respondTime : respondTime // ignore: cast_nullable_to_non_nullable
as int?,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as int?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of StoredBookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookSourceCopyWith<$Res> get source {
  
  return $BookSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}

/// @nodoc
mixin _$BookSourceSaveReport {

/// How many entries were new identities.
 int get inserted;/// How many entries were the same identity as a stored row and only refreshed its payload.
 int get refreshed;



@override
bool operator ==(Object other) {
  final _this = this as BookSourceSaveReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceSaveReport&&(identical(other.inserted, _this.inserted) || other.inserted == _this.inserted)&&(identical(other.refreshed, _this.refreshed) || other.refreshed == _this.refreshed));
}


@override
int get hashCode {
  final _this = this as BookSourceSaveReport;
  return Object.hash(runtimeType,_this.inserted,_this.refreshed);
}

@override
String toString() {
  final _this = this as BookSourceSaveReport;
  return 'BookSourceSaveReport(inserted: ${_this.inserted}, refreshed: ${_this.refreshed})';
}


}




/// Adds pattern-matching-related methods to [BookSourceSaveReport].
extension BookSourceSaveReportPatterns on BookSourceSaveReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookSourceSaveReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookSourceSaveReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookSourceSaveReport value)  $default,){
final _that = this;
switch (_that) {
case _BookSourceSaveReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookSourceSaveReport value)?  $default,){
final _that = this;
switch (_that) {
case _BookSourceSaveReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int inserted,  int refreshed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookSourceSaveReport() when $default != null:
return $default(_that.inserted,_that.refreshed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int inserted,  int refreshed)  $default,) {final _that = this;
switch (_that) {
case _BookSourceSaveReport():
return $default(_that.inserted,_that.refreshed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int inserted,  int refreshed)?  $default,) {final _that = this;
switch (_that) {
case _BookSourceSaveReport() when $default != null:
return $default(_that.inserted,_that.refreshed);case _:
  return null;

}
}

}

/// @nodoc


class _BookSourceSaveReport implements BookSourceSaveReport {
  const _BookSourceSaveReport({required this.inserted, required this.refreshed});
  

/// How many entries were new identities.
@override final  int inserted;
/// How many entries were the same identity as a stored row and only refreshed its payload.
@override final  int refreshed;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookSourceSaveReport&&(identical(other.inserted, inserted) || other.inserted == inserted)&&(identical(other.refreshed, refreshed) || other.refreshed == refreshed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,inserted,refreshed);
}

@override
String toString() {
    return 'BookSourceSaveReport(inserted: $inserted, refreshed: $refreshed)';
}


}




// dart format on
