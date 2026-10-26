// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shelved_book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ShelvedBook {

 int get id; String get sourceUrl; String get bookUrl;/// The table-of-contents URL the detail page resolved; `null` for rows stored before 5.3.
 String? get tocUrl;/// The title shown on the shelf.
 String get name; String? get author; String? get kind; String? get coverUrl; String? get intro; String? get lastChapter; ShelfStatus get status; bool get isPinned;/// The shelf group this entry belongs to, or `null` for 「未分组」 (ADR-0066 §决策 2).
 int? get groupId;/// Absolute path of the cover the user picked, or `null` to use [coverUrl].
 String? get customCoverPath; DateTime get addedAt; ReadingProgressPosition? get progress;
/// Create a copy of ShelvedBook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShelvedBookCopyWith<ShelvedBook> get copyWith => _$ShelvedBookCopyWithImpl<ShelvedBook>(this as ShelvedBook, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ShelvedBook;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelvedBook&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sourceUrl, _this.sourceUrl) || other.sourceUrl == _this.sourceUrl)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.tocUrl, _this.tocUrl) || other.tocUrl == _this.tocUrl)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&(identical(other.lastChapter, _this.lastChapter) || other.lastChapter == _this.lastChapter)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.isPinned, _this.isPinned) || other.isPinned == _this.isPinned)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.customCoverPath, _this.customCoverPath) || other.customCoverPath == _this.customCoverPath)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt)&&(identical(other.progress, _this.progress) || other.progress == _this.progress));
}


@override
int get hashCode {
  final _this = this as ShelvedBook;
  return Object.hash(runtimeType,_this.id,_this.sourceUrl,_this.bookUrl,_this.tocUrl,_this.name,_this.author,_this.kind,_this.coverUrl,_this.intro,_this.lastChapter,_this.status,_this.isPinned,_this.groupId,_this.customCoverPath,_this.addedAt,_this.progress);
}

@override
String toString() {
  final _this = this as ShelvedBook;
  return 'ShelvedBook(id: ${_this.id}, sourceUrl: ${_this.sourceUrl}, bookUrl: ${_this.bookUrl}, tocUrl: ${_this.tocUrl}, name: ${_this.name}, author: ${_this.author}, kind: ${_this.kind}, coverUrl: ${_this.coverUrl}, intro: ${_this.intro}, lastChapter: ${_this.lastChapter}, status: ${_this.status}, isPinned: ${_this.isPinned}, groupId: ${_this.groupId}, customCoverPath: ${_this.customCoverPath}, addedAt: ${_this.addedAt}, progress: ${_this.progress})';
}


}

/// @nodoc
abstract mixin class $ShelvedBookCopyWith<$Res>  {
  factory $ShelvedBookCopyWith(ShelvedBook value, $Res Function(ShelvedBook) _then) = _$ShelvedBookCopyWithImpl;
@useResult
$Res call({
 int id, String sourceUrl, String bookUrl, String? tocUrl, String name, String? author, String? kind, String? coverUrl, String? intro, String? lastChapter, ShelfStatus status, bool isPinned, int? groupId, String? customCoverPath, DateTime addedAt, ReadingProgressPosition? progress
});


$ReadingProgressPositionCopyWith<$Res>? get progress;

}
/// @nodoc
class _$ShelvedBookCopyWithImpl<$Res>
    implements $ShelvedBookCopyWith<$Res> {
  _$ShelvedBookCopyWithImpl(this._self, this._then);

  final ShelvedBook _self;
  final $Res Function(ShelvedBook) _then;

/// Create a copy of ShelvedBook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceUrl = null,Object? bookUrl = null,Object? tocUrl = freezed,Object? name = null,Object? author = freezed,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? status = null,Object? isPinned = null,Object? groupId = freezed,Object? customCoverPath = freezed,Object? addedAt = null,Object? progress = freezed,}) {
  return _then(ShelvedBook(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,tocUrl: freezed == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ShelfStatus,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int?,customCoverPath: freezed == customCoverPath ? _self.customCoverPath : customCoverPath // ignore: cast_nullable_to_non_nullable
as String?,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ReadingProgressPosition?,
  ));
}
/// Create a copy of ShelvedBook
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadingProgressPositionCopyWith<$Res>? get progress {
    if (_self.progress == null) {
    return null;
  }

  return $ReadingProgressPositionCopyWith<$Res>(_self.progress!, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}


/// Adds pattern-matching-related methods to [ShelvedBook].
extension ShelvedBookPatterns on ShelvedBook {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShelvedBook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShelvedBook() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShelvedBook value)  $default,){
final _that = this;
switch (_that) {
case _ShelvedBook():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShelvedBook value)?  $default,){
final _that = this;
switch (_that) {
case _ShelvedBook() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String sourceUrl,  String bookUrl,  String? tocUrl,  String name,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  ShelfStatus status,  bool isPinned,  int? groupId,  String? customCoverPath,  DateTime addedAt,  ReadingProgressPosition? progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShelvedBook() when $default != null:
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.tocUrl,_that.name,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.status,_that.isPinned,_that.groupId,_that.customCoverPath,_that.addedAt,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String sourceUrl,  String bookUrl,  String? tocUrl,  String name,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  ShelfStatus status,  bool isPinned,  int? groupId,  String? customCoverPath,  DateTime addedAt,  ReadingProgressPosition? progress)  $default,) {final _that = this;
switch (_that) {
case _ShelvedBook():
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.tocUrl,_that.name,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.status,_that.isPinned,_that.groupId,_that.customCoverPath,_that.addedAt,_that.progress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String sourceUrl,  String bookUrl,  String? tocUrl,  String name,  String? author,  String? kind,  String? coverUrl,  String? intro,  String? lastChapter,  ShelfStatus status,  bool isPinned,  int? groupId,  String? customCoverPath,  DateTime addedAt,  ReadingProgressPosition? progress)?  $default,) {final _that = this;
switch (_that) {
case _ShelvedBook() when $default != null:
return $default(_that.id,_that.sourceUrl,_that.bookUrl,_that.tocUrl,_that.name,_that.author,_that.kind,_that.coverUrl,_that.intro,_that.lastChapter,_that.status,_that.isPinned,_that.groupId,_that.customCoverPath,_that.addedAt,_that.progress);case _:
  return null;

}
}

}

/// @nodoc


class _ShelvedBook implements ShelvedBook {
  const _ShelvedBook({required this.id, required this.sourceUrl, required this.bookUrl, this.tocUrl, required this.name, this.author, this.kind, this.coverUrl, this.intro, this.lastChapter, this.status = ShelfStatus.tracking, this.isPinned = false, this.groupId, this.customCoverPath, required this.addedAt, this.progress});
  

@override final  int id;
@override final  String sourceUrl;
@override final  String bookUrl;
/// The table-of-contents URL the detail page resolved; `null` for rows stored before 5.3.
@override final  String? tocUrl;
/// The title shown on the shelf.
@override final  String name;
@override final  String? author;
@override final  String? kind;
@override final  String? coverUrl;
@override final  String? intro;
@override final  String? lastChapter;
@override@JsonKey() final  ShelfStatus status;
@override@JsonKey() final  bool isPinned;
/// The shelf group this entry belongs to, or `null` for 「未分组」 (ADR-0066 §决策 2).
@override final  int? groupId;
/// Absolute path of the cover the user picked, or `null` to use [coverUrl].
@override final  String? customCoverPath;
@override final  DateTime addedAt;
@override final  ReadingProgressPosition? progress;

/// Create a copy of ShelvedBook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShelvedBookCopyWith<_ShelvedBook> get copyWith => __$ShelvedBookCopyWithImpl<_ShelvedBook>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShelvedBook&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl)&&(identical(other.name, name) || other.name == name)&&(identical(other.author, author) || other.author == author)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.lastChapter, lastChapter) || other.lastChapter == lastChapter)&&(identical(other.status, status) || other.status == status)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.customCoverPath, customCoverPath) || other.customCoverPath == customCoverPath)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,sourceUrl,bookUrl,tocUrl,name,author,kind,coverUrl,intro,lastChapter,status,isPinned,groupId,customCoverPath,addedAt,progress);
}

@override
String toString() {
    return 'ShelvedBook(id: $id, sourceUrl: $sourceUrl, bookUrl: $bookUrl, tocUrl: $tocUrl, name: $name, author: $author, kind: $kind, coverUrl: $coverUrl, intro: $intro, lastChapter: $lastChapter, status: $status, isPinned: $isPinned, groupId: $groupId, customCoverPath: $customCoverPath, addedAt: $addedAt, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$ShelvedBookCopyWith<$Res> implements $ShelvedBookCopyWith<$Res> {
  factory _$ShelvedBookCopyWith(_ShelvedBook value, $Res Function(_ShelvedBook) _then) = __$ShelvedBookCopyWithImpl;
@override @useResult
$Res call({
 int id, String sourceUrl, String bookUrl, String? tocUrl, String name, String? author, String? kind, String? coverUrl, String? intro, String? lastChapter, ShelfStatus status, bool isPinned, int? groupId, String? customCoverPath, DateTime addedAt, ReadingProgressPosition? progress
});


@override $ReadingProgressPositionCopyWith<$Res>? get progress;

}
/// @nodoc
class __$ShelvedBookCopyWithImpl<$Res>
    implements _$ShelvedBookCopyWith<$Res> {
  __$ShelvedBookCopyWithImpl(this._self, this._then);

  final _ShelvedBook _self;
  final $Res Function(_ShelvedBook) _then;

/// Create a copy of ShelvedBook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceUrl = null,Object? bookUrl = null,Object? tocUrl = freezed,Object? name = null,Object? author = freezed,Object? kind = freezed,Object? coverUrl = freezed,Object? intro = freezed,Object? lastChapter = freezed,Object? status = null,Object? isPinned = null,Object? groupId = freezed,Object? customCoverPath = freezed,Object? addedAt = null,Object? progress = freezed,}) {
  return _then(_ShelvedBook(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceUrl: null == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String,bookUrl: null == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String,tocUrl: freezed == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ShelfStatus,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int?,customCoverPath: freezed == customCoverPath ? _self.customCoverPath : customCoverPath // ignore: cast_nullable_to_non_nullable
as String?,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ReadingProgressPosition?,
  ));
}

/// Create a copy of ShelvedBook
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadingProgressPositionCopyWith<$Res>? get progress {
    if (_self.progress == null) {
    return null;
  }

  return $ReadingProgressPositionCopyWith<$Res>(_self.progress!, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}

/// @nodoc
mixin _$ReadingProgressPosition {

 String get chapterUrl; String? get chapterName; int get charOffset; DateTime get updatedAt;
/// Create a copy of ReadingProgressPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingProgressPositionCopyWith<ReadingProgressPosition> get copyWith => _$ReadingProgressPositionCopyWithImpl<ReadingProgressPosition>(this as ReadingProgressPosition, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingProgressPosition;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingProgressPosition&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.chapterName, _this.chapterName) || other.chapterName == _this.chapterName)&&(identical(other.charOffset, _this.charOffset) || other.charOffset == _this.charOffset)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as ReadingProgressPosition;
  return Object.hash(runtimeType,_this.chapterUrl,_this.chapterName,_this.charOffset,_this.updatedAt);
}

@override
String toString() {
  final _this = this as ReadingProgressPosition;
  return 'ReadingProgressPosition(chapterUrl: ${_this.chapterUrl}, chapterName: ${_this.chapterName}, charOffset: ${_this.charOffset}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ReadingProgressPositionCopyWith<$Res>  {
  factory $ReadingProgressPositionCopyWith(ReadingProgressPosition value, $Res Function(ReadingProgressPosition) _then) = _$ReadingProgressPositionCopyWithImpl;
@useResult
$Res call({
 String chapterUrl, String? chapterName, int charOffset, DateTime updatedAt
});




}
/// @nodoc
class _$ReadingProgressPositionCopyWithImpl<$Res>
    implements $ReadingProgressPositionCopyWith<$Res> {
  _$ReadingProgressPositionCopyWithImpl(this._self, this._then);

  final ReadingProgressPosition _self;
  final $Res Function(ReadingProgressPosition) _then;

/// Create a copy of ReadingProgressPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapterUrl = null,Object? chapterName = freezed,Object? charOffset = null,Object? updatedAt = null,}) {
  return _then(ReadingProgressPosition(
chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingProgressPosition].
extension ReadingProgressPositionPatterns on ReadingProgressPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingProgressPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingProgressPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingProgressPosition value)  $default,){
final _that = this;
switch (_that) {
case _ReadingProgressPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingProgressPosition value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingProgressPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chapterUrl,  String? chapterName,  int charOffset,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingProgressPosition() when $default != null:
return $default(_that.chapterUrl,_that.chapterName,_that.charOffset,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chapterUrl,  String? chapterName,  int charOffset,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ReadingProgressPosition():
return $default(_that.chapterUrl,_that.chapterName,_that.charOffset,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chapterUrl,  String? chapterName,  int charOffset,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ReadingProgressPosition() when $default != null:
return $default(_that.chapterUrl,_that.chapterName,_that.charOffset,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingProgressPosition implements ReadingProgressPosition {
  const _ReadingProgressPosition({required this.chapterUrl, this.chapterName, this.charOffset = 0, required this.updatedAt});
  

@override final  String chapterUrl;
@override final  String? chapterName;
@override@JsonKey() final  int charOffset;
@override final  DateTime updatedAt;

/// Create a copy of ReadingProgressPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingProgressPositionCopyWith<_ReadingProgressPosition> get copyWith => __$ReadingProgressPositionCopyWithImpl<_ReadingProgressPosition>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingProgressPosition&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.chapterName, chapterName) || other.chapterName == chapterName)&&(identical(other.charOffset, charOffset) || other.charOffset == charOffset)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,chapterUrl,chapterName,charOffset,updatedAt);
}

@override
String toString() {
    return 'ReadingProgressPosition(chapterUrl: $chapterUrl, chapterName: $chapterName, charOffset: $charOffset, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ReadingProgressPositionCopyWith<$Res> implements $ReadingProgressPositionCopyWith<$Res> {
  factory _$ReadingProgressPositionCopyWith(_ReadingProgressPosition value, $Res Function(_ReadingProgressPosition) _then) = __$ReadingProgressPositionCopyWithImpl;
@override @useResult
$Res call({
 String chapterUrl, String? chapterName, int charOffset, DateTime updatedAt
});




}
/// @nodoc
class __$ReadingProgressPositionCopyWithImpl<$Res>
    implements _$ReadingProgressPositionCopyWith<$Res> {
  __$ReadingProgressPositionCopyWithImpl(this._self, this._then);

  final _ReadingProgressPosition _self;
  final $Res Function(_ReadingProgressPosition) _then;

/// Create a copy of ReadingProgressPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chapterUrl = null,Object? chapterName = freezed,Object? charOffset = null,Object? updatedAt = null,}) {
  return _then(_ReadingProgressPosition(
chapterUrl: null == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,charOffset: null == charOffset ? _self.charOffset : charOffset // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
