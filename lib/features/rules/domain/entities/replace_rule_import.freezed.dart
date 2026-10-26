// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'replace_rule_import.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReplaceRuleImportEntry {

/// Where the entry sat in the document; the page's selection is a set of these.
 int get index;/// The rule's name (`name`, or the legacy `replaceSummary`); may be empty.
 String get name;/// The typed payload, or `null` when the entry cannot be stored (see [problem]).
 RulePayload? get payload;/// Whether the rule will be in effect after the import.
 bool get isEnabled;/// The file's `order` (legacy `serialNumber`), or `null` to append.
 int? get sortOrder;/// Whether a stored rule has the same `name` + `pattern` and will be rewritten.
 bool get isUpdate;/// Why the entry is unusable; `null` for a usable one.
 ReplaceRuleImportProblem? get problem;
/// Create a copy of ReplaceRuleImportEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplaceRuleImportEntryCopyWith<ReplaceRuleImportEntry> get copyWith => _$ReplaceRuleImportEntryCopyWithImpl<ReplaceRuleImportEntry>(this as ReplaceRuleImportEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReplaceRuleImportEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplaceRuleImportEntry&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.payload, _this.payload) || other.payload == _this.payload)&&(identical(other.isEnabled, _this.isEnabled) || other.isEnabled == _this.isEnabled)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.isUpdate, _this.isUpdate) || other.isUpdate == _this.isUpdate)&&(identical(other.problem, _this.problem) || other.problem == _this.problem));
}


@override
int get hashCode {
  final _this = this as ReplaceRuleImportEntry;
  return Object.hash(runtimeType,_this.index,_this.name,_this.payload,_this.isEnabled,_this.sortOrder,_this.isUpdate,_this.problem);
}

@override
String toString() {
  final _this = this as ReplaceRuleImportEntry;
  return 'ReplaceRuleImportEntry(index: ${_this.index}, name: ${_this.name}, payload: ${_this.payload}, isEnabled: ${_this.isEnabled}, sortOrder: ${_this.sortOrder}, isUpdate: ${_this.isUpdate}, problem: ${_this.problem})';
}


}

/// @nodoc
abstract mixin class $ReplaceRuleImportEntryCopyWith<$Res>  {
  factory $ReplaceRuleImportEntryCopyWith(ReplaceRuleImportEntry value, $Res Function(ReplaceRuleImportEntry) _then) = _$ReplaceRuleImportEntryCopyWithImpl;
@useResult
$Res call({
 int index, String name, RulePayload? payload, bool isEnabled, int? sortOrder, bool isUpdate, ReplaceRuleImportProblem? problem
});


$RulePayloadCopyWith<$Res>? get payload;

}
/// @nodoc
class _$ReplaceRuleImportEntryCopyWithImpl<$Res>
    implements $ReplaceRuleImportEntryCopyWith<$Res> {
  _$ReplaceRuleImportEntryCopyWithImpl(this._self, this._then);

  final ReplaceRuleImportEntry _self;
  final $Res Function(ReplaceRuleImportEntry) _then;

/// Create a copy of ReplaceRuleImportEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? name = null,Object? payload = freezed,Object? isEnabled = null,Object? sortOrder = freezed,Object? isUpdate = null,Object? problem = freezed,}) {
  return _then(ReplaceRuleImportEntry(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,payload: freezed == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as RulePayload?,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,isUpdate: null == isUpdate ? _self.isUpdate : isUpdate // ignore: cast_nullable_to_non_nullable
as bool,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as ReplaceRuleImportProblem?,
  ));
}
/// Create a copy of ReplaceRuleImportEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RulePayloadCopyWith<$Res>? get payload {
    if (_self.payload == null) {
    return null;
  }

  return $RulePayloadCopyWith<$Res>(_self.payload!, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReplaceRuleImportEntry].
extension ReplaceRuleImportEntryPatterns on ReplaceRuleImportEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReplaceRuleImportEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReplaceRuleImportEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReplaceRuleImportEntry value)  $default,){
final _that = this;
switch (_that) {
case _ReplaceRuleImportEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReplaceRuleImportEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ReplaceRuleImportEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String name,  RulePayload? payload,  bool isEnabled,  int? sortOrder,  bool isUpdate,  ReplaceRuleImportProblem? problem)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReplaceRuleImportEntry() when $default != null:
return $default(_that.index,_that.name,_that.payload,_that.isEnabled,_that.sortOrder,_that.isUpdate,_that.problem);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String name,  RulePayload? payload,  bool isEnabled,  int? sortOrder,  bool isUpdate,  ReplaceRuleImportProblem? problem)  $default,) {final _that = this;
switch (_that) {
case _ReplaceRuleImportEntry():
return $default(_that.index,_that.name,_that.payload,_that.isEnabled,_that.sortOrder,_that.isUpdate,_that.problem);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String name,  RulePayload? payload,  bool isEnabled,  int? sortOrder,  bool isUpdate,  ReplaceRuleImportProblem? problem)?  $default,) {final _that = this;
switch (_that) {
case _ReplaceRuleImportEntry() when $default != null:
return $default(_that.index,_that.name,_that.payload,_that.isEnabled,_that.sortOrder,_that.isUpdate,_that.problem);case _:
  return null;

}
}

}

/// @nodoc


class _ReplaceRuleImportEntry extends ReplaceRuleImportEntry {
  const _ReplaceRuleImportEntry({required this.index, required this.name, required this.payload, required this.isEnabled, this.sortOrder, required this.isUpdate, this.problem}): super._();
  

/// Where the entry sat in the document; the page's selection is a set of these.
@override final  int index;
/// The rule's name (`name`, or the legacy `replaceSummary`); may be empty.
@override final  String name;
/// The typed payload, or `null` when the entry cannot be stored (see [problem]).
@override final  RulePayload? payload;
/// Whether the rule will be in effect after the import.
@override final  bool isEnabled;
/// The file's `order` (legacy `serialNumber`), or `null` to append.
@override final  int? sortOrder;
/// Whether a stored rule has the same `name` + `pattern` and will be rewritten.
@override final  bool isUpdate;
/// Why the entry is unusable; `null` for a usable one.
@override final  ReplaceRuleImportProblem? problem;

/// Create a copy of ReplaceRuleImportEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplaceRuleImportEntryCopyWith<_ReplaceRuleImportEntry> get copyWith => __$ReplaceRuleImportEntryCopyWithImpl<_ReplaceRuleImportEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplaceRuleImportEntry&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.payload, payload) || other.payload == payload)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isUpdate, isUpdate) || other.isUpdate == isUpdate)&&(identical(other.problem, problem) || other.problem == problem));
}


@override
int get hashCode {
    return Object.hash(runtimeType,index,name,payload,isEnabled,sortOrder,isUpdate,problem);
}

@override
String toString() {
    return 'ReplaceRuleImportEntry(index: $index, name: $name, payload: $payload, isEnabled: $isEnabled, sortOrder: $sortOrder, isUpdate: $isUpdate, problem: $problem)';
}


}

/// @nodoc
abstract mixin class _$ReplaceRuleImportEntryCopyWith<$Res> implements $ReplaceRuleImportEntryCopyWith<$Res> {
  factory _$ReplaceRuleImportEntryCopyWith(_ReplaceRuleImportEntry value, $Res Function(_ReplaceRuleImportEntry) _then) = __$ReplaceRuleImportEntryCopyWithImpl;
@override @useResult
$Res call({
 int index, String name, RulePayload? payload, bool isEnabled, int? sortOrder, bool isUpdate, ReplaceRuleImportProblem? problem
});


@override $RulePayloadCopyWith<$Res>? get payload;

}
/// @nodoc
class __$ReplaceRuleImportEntryCopyWithImpl<$Res>
    implements _$ReplaceRuleImportEntryCopyWith<$Res> {
  __$ReplaceRuleImportEntryCopyWithImpl(this._self, this._then);

  final _ReplaceRuleImportEntry _self;
  final $Res Function(_ReplaceRuleImportEntry) _then;

/// Create a copy of ReplaceRuleImportEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? name = null,Object? payload = freezed,Object? isEnabled = null,Object? sortOrder = freezed,Object? isUpdate = null,Object? problem = freezed,}) {
  return _then(_ReplaceRuleImportEntry(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,payload: freezed == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as RulePayload?,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,isUpdate: null == isUpdate ? _self.isUpdate : isUpdate // ignore: cast_nullable_to_non_nullable
as bool,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as ReplaceRuleImportProblem?,
  ));
}

/// Create a copy of ReplaceRuleImportEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RulePayloadCopyWith<$Res>? get payload {
    if (_self.payload == null) {
    return null;
  }

  return $RulePayloadCopyWith<$Res>(_self.payload!, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

/// @nodoc
mixin _$ReplaceRuleImportPreview {

/// Every entry of the document, usable or not, in document order.
 List<ReplaceRuleImportEntry> get entries;
/// Create a copy of ReplaceRuleImportPreview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplaceRuleImportPreviewCopyWith<ReplaceRuleImportPreview> get copyWith => _$ReplaceRuleImportPreviewCopyWithImpl<ReplaceRuleImportPreview>(this as ReplaceRuleImportPreview, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReplaceRuleImportPreview;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplaceRuleImportPreview&&const DeepCollectionEquality().equals(other.entries, _this.entries));
}


@override
int get hashCode {
  final _this = this as ReplaceRuleImportPreview;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.entries));
}

@override
String toString() {
  final _this = this as ReplaceRuleImportPreview;
  return 'ReplaceRuleImportPreview(entries: ${_this.entries})';
}


}

/// @nodoc
abstract mixin class $ReplaceRuleImportPreviewCopyWith<$Res>  {
  factory $ReplaceRuleImportPreviewCopyWith(ReplaceRuleImportPreview value, $Res Function(ReplaceRuleImportPreview) _then) = _$ReplaceRuleImportPreviewCopyWithImpl;
@useResult
$Res call({
 List<ReplaceRuleImportEntry> entries
});




}
/// @nodoc
class _$ReplaceRuleImportPreviewCopyWithImpl<$Res>
    implements $ReplaceRuleImportPreviewCopyWith<$Res> {
  _$ReplaceRuleImportPreviewCopyWithImpl(this._self, this._then);

  final ReplaceRuleImportPreview _self;
  final $Res Function(ReplaceRuleImportPreview) _then;

/// Create a copy of ReplaceRuleImportPreview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entries = null,}) {
  return _then(ReplaceRuleImportPreview(
entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<ReplaceRuleImportEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [ReplaceRuleImportPreview].
extension ReplaceRuleImportPreviewPatterns on ReplaceRuleImportPreview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReplaceRuleImportPreview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReplaceRuleImportPreview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReplaceRuleImportPreview value)  $default,){
final _that = this;
switch (_that) {
case _ReplaceRuleImportPreview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReplaceRuleImportPreview value)?  $default,){
final _that = this;
switch (_that) {
case _ReplaceRuleImportPreview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ReplaceRuleImportEntry> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReplaceRuleImportPreview() when $default != null:
return $default(_that.entries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ReplaceRuleImportEntry> entries)  $default,) {final _that = this;
switch (_that) {
case _ReplaceRuleImportPreview():
return $default(_that.entries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ReplaceRuleImportEntry> entries)?  $default,) {final _that = this;
switch (_that) {
case _ReplaceRuleImportPreview() when $default != null:
return $default(_that.entries);case _:
  return null;

}
}

}

/// @nodoc


class _ReplaceRuleImportPreview extends ReplaceRuleImportPreview {
  const _ReplaceRuleImportPreview({required  List<ReplaceRuleImportEntry> entries}): _entries = entries,super._();
  

/// Every entry of the document, usable or not, in document order.
 final  List<ReplaceRuleImportEntry> _entries;
/// Every entry of the document, usable or not, in document order.
@override List<ReplaceRuleImportEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of ReplaceRuleImportPreview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplaceRuleImportPreviewCopyWith<_ReplaceRuleImportPreview> get copyWith => __$ReplaceRuleImportPreviewCopyWithImpl<_ReplaceRuleImportPreview>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplaceRuleImportPreview&&const DeepCollectionEquality().equals(other.entries, _entries));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries));
}

@override
String toString() {
    return 'ReplaceRuleImportPreview(entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$ReplaceRuleImportPreviewCopyWith<$Res> implements $ReplaceRuleImportPreviewCopyWith<$Res> {
  factory _$ReplaceRuleImportPreviewCopyWith(_ReplaceRuleImportPreview value, $Res Function(_ReplaceRuleImportPreview) _then) = __$ReplaceRuleImportPreviewCopyWithImpl;
@override @useResult
$Res call({
 List<ReplaceRuleImportEntry> entries
});




}
/// @nodoc
class __$ReplaceRuleImportPreviewCopyWithImpl<$Res>
    implements _$ReplaceRuleImportPreviewCopyWith<$Res> {
  __$ReplaceRuleImportPreviewCopyWithImpl(this._self, this._then);

  final _ReplaceRuleImportPreview _self;
  final $Res Function(_ReplaceRuleImportPreview) _then;

/// Create a copy of ReplaceRuleImportPreview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entries = null,}) {
  return _then(_ReplaceRuleImportPreview(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<ReplaceRuleImportEntry>,
  ));
}


}

/// @nodoc
mixin _$ReplaceRuleImportReport {

/// How many rules were appended.
 int get created;/// How many rules were rewritten in place (same `name` + `pattern`).
 int get updated;/// How many entries of the document could not be stored at all.
 int get skipped;
/// Create a copy of ReplaceRuleImportReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplaceRuleImportReportCopyWith<ReplaceRuleImportReport> get copyWith => _$ReplaceRuleImportReportCopyWithImpl<ReplaceRuleImportReport>(this as ReplaceRuleImportReport, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReplaceRuleImportReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplaceRuleImportReport&&(identical(other.created, _this.created) || other.created == _this.created)&&(identical(other.updated, _this.updated) || other.updated == _this.updated)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped));
}


@override
int get hashCode {
  final _this = this as ReplaceRuleImportReport;
  return Object.hash(runtimeType,_this.created,_this.updated,_this.skipped);
}

@override
String toString() {
  final _this = this as ReplaceRuleImportReport;
  return 'ReplaceRuleImportReport(created: ${_this.created}, updated: ${_this.updated}, skipped: ${_this.skipped})';
}


}

/// @nodoc
abstract mixin class $ReplaceRuleImportReportCopyWith<$Res>  {
  factory $ReplaceRuleImportReportCopyWith(ReplaceRuleImportReport value, $Res Function(ReplaceRuleImportReport) _then) = _$ReplaceRuleImportReportCopyWithImpl;
@useResult
$Res call({
 int created, int updated, int skipped
});




}
/// @nodoc
class _$ReplaceRuleImportReportCopyWithImpl<$Res>
    implements $ReplaceRuleImportReportCopyWith<$Res> {
  _$ReplaceRuleImportReportCopyWithImpl(this._self, this._then);

  final ReplaceRuleImportReport _self;
  final $Res Function(ReplaceRuleImportReport) _then;

/// Create a copy of ReplaceRuleImportReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,Object? updated = null,Object? skipped = null,}) {
  return _then(ReplaceRuleImportReport(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReplaceRuleImportReport].
extension ReplaceRuleImportReportPatterns on ReplaceRuleImportReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReplaceRuleImportReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReplaceRuleImportReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReplaceRuleImportReport value)  $default,){
final _that = this;
switch (_that) {
case _ReplaceRuleImportReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReplaceRuleImportReport value)?  $default,){
final _that = this;
switch (_that) {
case _ReplaceRuleImportReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int created,  int updated,  int skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReplaceRuleImportReport() when $default != null:
return $default(_that.created,_that.updated,_that.skipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int created,  int updated,  int skipped)  $default,) {final _that = this;
switch (_that) {
case _ReplaceRuleImportReport():
return $default(_that.created,_that.updated,_that.skipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int created,  int updated,  int skipped)?  $default,) {final _that = this;
switch (_that) {
case _ReplaceRuleImportReport() when $default != null:
return $default(_that.created,_that.updated,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc


class _ReplaceRuleImportReport extends ReplaceRuleImportReport {
  const _ReplaceRuleImportReport({required this.created, required this.updated, required this.skipped}): super._();
  

/// How many rules were appended.
@override final  int created;
/// How many rules were rewritten in place (same `name` + `pattern`).
@override final  int updated;
/// How many entries of the document could not be stored at all.
@override final  int skipped;

/// Create a copy of ReplaceRuleImportReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplaceRuleImportReportCopyWith<_ReplaceRuleImportReport> get copyWith => __$ReplaceRuleImportReportCopyWithImpl<_ReplaceRuleImportReport>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplaceRuleImportReport&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}


@override
int get hashCode {
    return Object.hash(runtimeType,created,updated,skipped);
}

@override
String toString() {
    return 'ReplaceRuleImportReport(created: $created, updated: $updated, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$ReplaceRuleImportReportCopyWith<$Res> implements $ReplaceRuleImportReportCopyWith<$Res> {
  factory _$ReplaceRuleImportReportCopyWith(_ReplaceRuleImportReport value, $Res Function(_ReplaceRuleImportReport) _then) = __$ReplaceRuleImportReportCopyWithImpl;
@override @useResult
$Res call({
 int created, int updated, int skipped
});




}
/// @nodoc
class __$ReplaceRuleImportReportCopyWithImpl<$Res>
    implements _$ReplaceRuleImportReportCopyWith<$Res> {
  __$ReplaceRuleImportReportCopyWithImpl(this._self, this._then);

  final _ReplaceRuleImportReport _self;
  final $Res Function(_ReplaceRuleImportReport) _then;

/// Create a copy of ReplaceRuleImportReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? updated = null,Object? skipped = null,}) {
  return _then(_ReplaceRuleImportReport(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
