// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rule_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RulePayload {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RulePayload);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'RulePayload()';
}


}

/// @nodoc
class $RulePayloadCopyWith<$Res>  {
$RulePayloadCopyWith(RulePayload _, $Res Function(RulePayload) __);
}


/// Adds pattern-matching-related methods to [RulePayload].
extension RulePayloadPatterns on RulePayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ReplacePayload value)?  replace,TResult Function( TocPayload value)?  toc,TResult Function( DictPayload value)?  dict,TResult Function( HighlightPayload value)?  highlight,TResult Function( MalformedPayload value)?  malformed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ReplacePayload() when replace != null:
return replace(_that);case TocPayload() when toc != null:
return toc(_that);case DictPayload() when dict != null:
return dict(_that);case HighlightPayload() when highlight != null:
return highlight(_that);case MalformedPayload() when malformed != null:
return malformed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ReplacePayload value)  replace,required TResult Function( TocPayload value)  toc,required TResult Function( DictPayload value)  dict,required TResult Function( HighlightPayload value)  highlight,required TResult Function( MalformedPayload value)  malformed,}){
final _that = this;
switch (_that) {
case ReplacePayload():
return replace(_that);case TocPayload():
return toc(_that);case DictPayload():
return dict(_that);case HighlightPayload():
return highlight(_that);case MalformedPayload():
return malformed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ReplacePayload value)?  replace,TResult? Function( TocPayload value)?  toc,TResult? Function( DictPayload value)?  dict,TResult? Function( HighlightPayload value)?  highlight,TResult? Function( MalformedPayload value)?  malformed,}){
final _that = this;
switch (_that) {
case ReplacePayload() when replace != null:
return replace(_that);case TocPayload() when toc != null:
return toc(_that);case DictPayload() when dict != null:
return dict(_that);case HighlightPayload() when highlight != null:
return highlight(_that);case MalformedPayload() when malformed != null:
return malformed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String pattern,  String replacement,  bool isRegex,  int? timeoutMs,  String? group,  bool scopeContent,  bool scopeTitle,  Map<String, Object?> extra)?  replace,TResult Function( String rule,  int? serialNumber,  Map<String, Object?> extra)?  toc,TResult Function( String urlRule,  String showRule,  String? ruleGroupType,  Map<String, Object?> extra)?  dict,TResult Function( String pattern,  String? colorHex,  String? group,  Map<String, Object?> extra)?  highlight,TResult Function( String raw)?  malformed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ReplacePayload() when replace != null:
return replace(_that.pattern,_that.replacement,_that.isRegex,_that.timeoutMs,_that.group,_that.scopeContent,_that.scopeTitle,_that.extra);case TocPayload() when toc != null:
return toc(_that.rule,_that.serialNumber,_that.extra);case DictPayload() when dict != null:
return dict(_that.urlRule,_that.showRule,_that.ruleGroupType,_that.extra);case HighlightPayload() when highlight != null:
return highlight(_that.pattern,_that.colorHex,_that.group,_that.extra);case MalformedPayload() when malformed != null:
return malformed(_that.raw);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String pattern,  String replacement,  bool isRegex,  int? timeoutMs,  String? group,  bool scopeContent,  bool scopeTitle,  Map<String, Object?> extra)  replace,required TResult Function( String rule,  int? serialNumber,  Map<String, Object?> extra)  toc,required TResult Function( String urlRule,  String showRule,  String? ruleGroupType,  Map<String, Object?> extra)  dict,required TResult Function( String pattern,  String? colorHex,  String? group,  Map<String, Object?> extra)  highlight,required TResult Function( String raw)  malformed,}) {final _that = this;
switch (_that) {
case ReplacePayload():
return replace(_that.pattern,_that.replacement,_that.isRegex,_that.timeoutMs,_that.group,_that.scopeContent,_that.scopeTitle,_that.extra);case TocPayload():
return toc(_that.rule,_that.serialNumber,_that.extra);case DictPayload():
return dict(_that.urlRule,_that.showRule,_that.ruleGroupType,_that.extra);case HighlightPayload():
return highlight(_that.pattern,_that.colorHex,_that.group,_that.extra);case MalformedPayload():
return malformed(_that.raw);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String pattern,  String replacement,  bool isRegex,  int? timeoutMs,  String? group,  bool scopeContent,  bool scopeTitle,  Map<String, Object?> extra)?  replace,TResult? Function( String rule,  int? serialNumber,  Map<String, Object?> extra)?  toc,TResult? Function( String urlRule,  String showRule,  String? ruleGroupType,  Map<String, Object?> extra)?  dict,TResult? Function( String pattern,  String? colorHex,  String? group,  Map<String, Object?> extra)?  highlight,TResult? Function( String raw)?  malformed,}) {final _that = this;
switch (_that) {
case ReplacePayload() when replace != null:
return replace(_that.pattern,_that.replacement,_that.isRegex,_that.timeoutMs,_that.group,_that.scopeContent,_that.scopeTitle,_that.extra);case TocPayload() when toc != null:
return toc(_that.rule,_that.serialNumber,_that.extra);case DictPayload() when dict != null:
return dict(_that.urlRule,_that.showRule,_that.ruleGroupType,_that.extra);case HighlightPayload() when highlight != null:
return highlight(_that.pattern,_that.colorHex,_that.group,_that.extra);case MalformedPayload() when malformed != null:
return malformed(_that.raw);case _:
  return null;

}
}

}

/// @nodoc


class ReplacePayload implements RulePayload {
  const ReplacePayload({required this.pattern, required this.replacement, this.isRegex = true, this.timeoutMs, this.group, this.scopeContent = true, this.scopeTitle = false,  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  

 final  String pattern;
 final  String replacement;
@JsonKey() final  bool isRegex;
 final  int? timeoutMs;
 final  String? group;
@JsonKey() final  bool scopeContent;
@JsonKey() final  bool scopeTitle;
 final  Map<String, Object?> _extra;
@JsonKey() Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplacePayloadCopyWith<ReplacePayload> get copyWith => _$ReplacePayloadCopyWithImpl<ReplacePayload>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplacePayload&&(identical(other.pattern, pattern) || other.pattern == pattern)&&(identical(other.replacement, replacement) || other.replacement == replacement)&&(identical(other.isRegex, isRegex) || other.isRegex == isRegex)&&(identical(other.timeoutMs, timeoutMs) || other.timeoutMs == timeoutMs)&&(identical(other.group, group) || other.group == group)&&(identical(other.scopeContent, scopeContent) || other.scopeContent == scopeContent)&&(identical(other.scopeTitle, scopeTitle) || other.scopeTitle == scopeTitle)&&const DeepCollectionEquality().equals(other.extra, _extra));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pattern,replacement,isRegex,timeoutMs,group,scopeContent,scopeTitle,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'RulePayload.replace(pattern: $pattern, replacement: $replacement, isRegex: $isRegex, timeoutMs: $timeoutMs, group: $group, scopeContent: $scopeContent, scopeTitle: $scopeTitle, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $ReplacePayloadCopyWith<$Res> implements $RulePayloadCopyWith<$Res> {
  factory $ReplacePayloadCopyWith(ReplacePayload value, $Res Function(ReplacePayload) _then) = _$ReplacePayloadCopyWithImpl;
@useResult
$Res call({
 String pattern, String replacement, bool isRegex, int? timeoutMs, String? group, bool scopeContent, bool scopeTitle, Map<String, Object?> extra
});




}
/// @nodoc
class _$ReplacePayloadCopyWithImpl<$Res>
    implements $ReplacePayloadCopyWith<$Res> {
  _$ReplacePayloadCopyWithImpl(this._self, this._then);

  final ReplacePayload _self;
  final $Res Function(ReplacePayload) _then;

/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pattern = null,Object? replacement = null,Object? isRegex = null,Object? timeoutMs = freezed,Object? group = freezed,Object? scopeContent = null,Object? scopeTitle = null,Object? extra = null,}) {
  return _then(ReplacePayload(
pattern: null == pattern ? _self.pattern : pattern // ignore: cast_nullable_to_non_nullable
as String,replacement: null == replacement ? _self.replacement : replacement // ignore: cast_nullable_to_non_nullable
as String,isRegex: null == isRegex ? _self.isRegex : isRegex // ignore: cast_nullable_to_non_nullable
as bool,timeoutMs: freezed == timeoutMs ? _self.timeoutMs : timeoutMs // ignore: cast_nullable_to_non_nullable
as int?,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,scopeContent: null == scopeContent ? _self.scopeContent : scopeContent // ignore: cast_nullable_to_non_nullable
as bool,scopeTitle: null == scopeTitle ? _self.scopeTitle : scopeTitle // ignore: cast_nullable_to_non_nullable
as bool,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

/// @nodoc


class TocPayload implements RulePayload {
  const TocPayload({required this.rule, this.serialNumber,  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  

 final  String rule;
 final  int? serialNumber;
 final  Map<String, Object?> _extra;
@JsonKey() Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TocPayloadCopyWith<TocPayload> get copyWith => _$TocPayloadCopyWithImpl<TocPayload>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TocPayload&&(identical(other.rule, rule) || other.rule == rule)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&const DeepCollectionEquality().equals(other.extra, _extra));
}


@override
int get hashCode {
    return Object.hash(runtimeType,rule,serialNumber,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'RulePayload.toc(rule: $rule, serialNumber: $serialNumber, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $TocPayloadCopyWith<$Res> implements $RulePayloadCopyWith<$Res> {
  factory $TocPayloadCopyWith(TocPayload value, $Res Function(TocPayload) _then) = _$TocPayloadCopyWithImpl;
@useResult
$Res call({
 String rule, int? serialNumber, Map<String, Object?> extra
});




}
/// @nodoc
class _$TocPayloadCopyWithImpl<$Res>
    implements $TocPayloadCopyWith<$Res> {
  _$TocPayloadCopyWithImpl(this._self, this._then);

  final TocPayload _self;
  final $Res Function(TocPayload) _then;

/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? rule = null,Object? serialNumber = freezed,Object? extra = null,}) {
  return _then(TocPayload(
rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,serialNumber: freezed == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as int?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

/// @nodoc


class DictPayload implements RulePayload {
  const DictPayload({required this.urlRule, required this.showRule, this.ruleGroupType,  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  

 final  String urlRule;
 final  String showRule;
 final  String? ruleGroupType;
 final  Map<String, Object?> _extra;
@JsonKey() Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DictPayloadCopyWith<DictPayload> get copyWith => _$DictPayloadCopyWithImpl<DictPayload>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DictPayload&&(identical(other.urlRule, urlRule) || other.urlRule == urlRule)&&(identical(other.showRule, showRule) || other.showRule == showRule)&&(identical(other.ruleGroupType, ruleGroupType) || other.ruleGroupType == ruleGroupType)&&const DeepCollectionEquality().equals(other.extra, _extra));
}


@override
int get hashCode {
    return Object.hash(runtimeType,urlRule,showRule,ruleGroupType,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'RulePayload.dict(urlRule: $urlRule, showRule: $showRule, ruleGroupType: $ruleGroupType, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $DictPayloadCopyWith<$Res> implements $RulePayloadCopyWith<$Res> {
  factory $DictPayloadCopyWith(DictPayload value, $Res Function(DictPayload) _then) = _$DictPayloadCopyWithImpl;
@useResult
$Res call({
 String urlRule, String showRule, String? ruleGroupType, Map<String, Object?> extra
});




}
/// @nodoc
class _$DictPayloadCopyWithImpl<$Res>
    implements $DictPayloadCopyWith<$Res> {
  _$DictPayloadCopyWithImpl(this._self, this._then);

  final DictPayload _self;
  final $Res Function(DictPayload) _then;

/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? urlRule = null,Object? showRule = null,Object? ruleGroupType = freezed,Object? extra = null,}) {
  return _then(DictPayload(
urlRule: null == urlRule ? _self.urlRule : urlRule // ignore: cast_nullable_to_non_nullable
as String,showRule: null == showRule ? _self.showRule : showRule // ignore: cast_nullable_to_non_nullable
as String,ruleGroupType: freezed == ruleGroupType ? _self.ruleGroupType : ruleGroupType // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

/// @nodoc


class HighlightPayload implements RulePayload {
  const HighlightPayload({required this.pattern, this.colorHex, this.group,  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  

 final  String pattern;
 final  String? colorHex;
 final  String? group;
 final  Map<String, Object?> _extra;
@JsonKey() Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HighlightPayloadCopyWith<HighlightPayload> get copyWith => _$HighlightPayloadCopyWithImpl<HighlightPayload>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HighlightPayload&&(identical(other.pattern, pattern) || other.pattern == pattern)&&(identical(other.colorHex, colorHex) || other.colorHex == colorHex)&&(identical(other.group, group) || other.group == group)&&const DeepCollectionEquality().equals(other.extra, _extra));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pattern,colorHex,group,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'RulePayload.highlight(pattern: $pattern, colorHex: $colorHex, group: $group, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $HighlightPayloadCopyWith<$Res> implements $RulePayloadCopyWith<$Res> {
  factory $HighlightPayloadCopyWith(HighlightPayload value, $Res Function(HighlightPayload) _then) = _$HighlightPayloadCopyWithImpl;
@useResult
$Res call({
 String pattern, String? colorHex, String? group, Map<String, Object?> extra
});




}
/// @nodoc
class _$HighlightPayloadCopyWithImpl<$Res>
    implements $HighlightPayloadCopyWith<$Res> {
  _$HighlightPayloadCopyWithImpl(this._self, this._then);

  final HighlightPayload _self;
  final $Res Function(HighlightPayload) _then;

/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pattern = null,Object? colorHex = freezed,Object? group = freezed,Object? extra = null,}) {
  return _then(HighlightPayload(
pattern: null == pattern ? _self.pattern : pattern // ignore: cast_nullable_to_non_nullable
as String,colorHex: freezed == colorHex ? _self.colorHex : colorHex // ignore: cast_nullable_to_non_nullable
as String?,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

/// @nodoc


class MalformedPayload implements RulePayload {
  const MalformedPayload({required this.raw});
  

 final  String raw;

/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MalformedPayloadCopyWith<MalformedPayload> get copyWith => _$MalformedPayloadCopyWithImpl<MalformedPayload>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MalformedPayload&&(identical(other.raw, raw) || other.raw == raw));
}


@override
int get hashCode {
    return Object.hash(runtimeType,raw);
}

@override
String toString() {
    return 'RulePayload.malformed(raw: $raw)';
}


}

/// @nodoc
abstract mixin class $MalformedPayloadCopyWith<$Res> implements $RulePayloadCopyWith<$Res> {
  factory $MalformedPayloadCopyWith(MalformedPayload value, $Res Function(MalformedPayload) _then) = _$MalformedPayloadCopyWithImpl;
@useResult
$Res call({
 String raw
});




}
/// @nodoc
class _$MalformedPayloadCopyWithImpl<$Res>
    implements $MalformedPayloadCopyWith<$Res> {
  _$MalformedPayloadCopyWithImpl(this._self, this._then);

  final MalformedPayload _self;
  final $Res Function(MalformedPayload) _then;

/// Create a copy of RulePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? raw = null,}) {
  return _then(MalformedPayload(
raw: null == raw ? _self.raw : raw // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
