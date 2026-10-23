// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookSource {

@JsonKey(name: 'bookSourceName') String get name;@JsonKey(name: 'bookSourceUrl') String get url;@JsonKey(name: 'bookSourceGroup') String? get group;@JsonKey(name: 'bookSourceType') BookSourceType get sourceType;@JsonKey(name: 'enabled') bool get isEnabled;@JsonKey(name: 'header')@_HeaderJsonConverter() Map<String, String>? get headers;/// The source's `header` when it is a **rule** rather than a JSON object
/// (`docs/dev/book-source.md` §2, M12-A2).
///
/// Upstream evaluates it before every request and parses its result as a JSON object
/// (`BaseSource.getHeaderMap`). The text is kept here rather than dropped, because a
/// source that signs its requests cannot be used at all without it; the evaluation itself
/// belongs to the fetch (`PageFetchService.headersOf`), which is where the sandbox is.
@JsonKey(includeFromJson: false, includeToJson: false) String? get headerRule; String? get searchUrl;@JsonKey(name: 'exploreUrl') String? get exploreUrl;@JsonKey(name: 'ruleSearch') SearchRule get searchRule;@JsonKey(name: 'ruleExplore') ExploreRule? get exploreRule;@JsonKey(name: 'concurrentRate') String? get concurrentRate;@JsonKey(name: 'variableComment') String? get variableComment;@JsonKey(name: 'ruleBookInfo') BookInfoRule? get bookInfoRule;@JsonKey(name: 'ruleToc') TocRule get tocRule;@JsonKey(name: 'ruleContent') ContentRule get contentRule;@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra;
/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSourceCopyWith<BookSource> get copyWith => _$BookSourceCopyWithImpl<BookSource>(this as BookSource, _$identity);

  /// Serializes this BookSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSource&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.group, _this.group) || other.group == _this.group)&&(identical(other.sourceType, _this.sourceType) || other.sourceType == _this.sourceType)&&(identical(other.isEnabled, _this.isEnabled) || other.isEnabled == _this.isEnabled)&&const DeepCollectionEquality().equals(other.headers, _this.headers)&&(identical(other.headerRule, _this.headerRule) || other.headerRule == _this.headerRule)&&(identical(other.searchUrl, _this.searchUrl) || other.searchUrl == _this.searchUrl)&&(identical(other.exploreUrl, _this.exploreUrl) || other.exploreUrl == _this.exploreUrl)&&(identical(other.searchRule, _this.searchRule) || other.searchRule == _this.searchRule)&&(identical(other.exploreRule, _this.exploreRule) || other.exploreRule == _this.exploreRule)&&(identical(other.concurrentRate, _this.concurrentRate) || other.concurrentRate == _this.concurrentRate)&&(identical(other.variableComment, _this.variableComment) || other.variableComment == _this.variableComment)&&(identical(other.bookInfoRule, _this.bookInfoRule) || other.bookInfoRule == _this.bookInfoRule)&&(identical(other.tocRule, _this.tocRule) || other.tocRule == _this.tocRule)&&(identical(other.contentRule, _this.contentRule) || other.contentRule == _this.contentRule)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookSource;
  return Object.hash(runtimeType,_this.name,_this.url,_this.group,_this.sourceType,_this.isEnabled,const DeepCollectionEquality().hash(_this.headers),_this.headerRule,_this.searchUrl,_this.exploreUrl,_this.searchRule,_this.exploreRule,_this.concurrentRate,_this.variableComment,_this.bookInfoRule,_this.tocRule,_this.contentRule,const DeepCollectionEquality().hash(_this.extra));
}

@override
String toString() {
  final _this = this as BookSource;
  return 'BookSource(name: ${_this.name}, url: ${_this.url}, group: ${_this.group}, sourceType: ${_this.sourceType}, isEnabled: ${_this.isEnabled}, headers: ${_this.headers}, headerRule: ${_this.headerRule}, searchUrl: ${_this.searchUrl}, exploreUrl: ${_this.exploreUrl}, searchRule: ${_this.searchRule}, exploreRule: ${_this.exploreRule}, concurrentRate: ${_this.concurrentRate}, variableComment: ${_this.variableComment}, bookInfoRule: ${_this.bookInfoRule}, tocRule: ${_this.tocRule}, contentRule: ${_this.contentRule}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $BookSourceCopyWith<$Res>  {
  factory $BookSourceCopyWith(BookSource value, $Res Function(BookSource) _then) = _$BookSourceCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'bookSourceName') String name,@JsonKey(name: 'bookSourceUrl') String url,@JsonKey(name: 'bookSourceGroup') String? group,@JsonKey(name: 'bookSourceType') BookSourceType sourceType,@JsonKey(name: 'enabled') bool isEnabled,@JsonKey(name: 'header')@_HeaderJsonConverter() Map<String, String>? headers,@JsonKey(includeFromJson: false, includeToJson: false) String? headerRule, String? searchUrl,@JsonKey(name: 'exploreUrl') String? exploreUrl,@JsonKey(name: 'ruleSearch') SearchRule searchRule,@JsonKey(name: 'ruleExplore') ExploreRule? exploreRule,@JsonKey(name: 'concurrentRate') String? concurrentRate,@JsonKey(name: 'variableComment') String? variableComment,@JsonKey(name: 'ruleBookInfo') BookInfoRule? bookInfoRule,@JsonKey(name: 'ruleToc') TocRule tocRule,@JsonKey(name: 'ruleContent') ContentRule contentRule,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});


$SearchRuleCopyWith<$Res> get searchRule;$ExploreRuleCopyWith<$Res>? get exploreRule;$BookInfoRuleCopyWith<$Res>? get bookInfoRule;$TocRuleCopyWith<$Res> get tocRule;$ContentRuleCopyWith<$Res> get contentRule;

}
/// @nodoc
class _$BookSourceCopyWithImpl<$Res>
    implements $BookSourceCopyWith<$Res> {
  _$BookSourceCopyWithImpl(this._self, this._then);

  final BookSource _self;
  final $Res Function(BookSource) _then;

/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,Object? group = freezed,Object? sourceType = null,Object? isEnabled = null,Object? headers = freezed,Object? headerRule = freezed,Object? searchUrl = freezed,Object? exploreUrl = freezed,Object? searchRule = null,Object? exploreRule = freezed,Object? concurrentRate = freezed,Object? variableComment = freezed,Object? bookInfoRule = freezed,Object? tocRule = null,Object? contentRule = null,Object? extra = null,}) {
  return _then(BookSource(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as BookSourceType,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,headers: freezed == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,headerRule: freezed == headerRule ? _self.headerRule : headerRule // ignore: cast_nullable_to_non_nullable
as String?,searchUrl: freezed == searchUrl ? _self.searchUrl : searchUrl // ignore: cast_nullable_to_non_nullable
as String?,exploreUrl: freezed == exploreUrl ? _self.exploreUrl : exploreUrl // ignore: cast_nullable_to_non_nullable
as String?,searchRule: null == searchRule ? _self.searchRule : searchRule // ignore: cast_nullable_to_non_nullable
as SearchRule,exploreRule: freezed == exploreRule ? _self.exploreRule : exploreRule // ignore: cast_nullable_to_non_nullable
as ExploreRule?,concurrentRate: freezed == concurrentRate ? _self.concurrentRate : concurrentRate // ignore: cast_nullable_to_non_nullable
as String?,variableComment: freezed == variableComment ? _self.variableComment : variableComment // ignore: cast_nullable_to_non_nullable
as String?,bookInfoRule: freezed == bookInfoRule ? _self.bookInfoRule : bookInfoRule // ignore: cast_nullable_to_non_nullable
as BookInfoRule?,tocRule: null == tocRule ? _self.tocRule : tocRule // ignore: cast_nullable_to_non_nullable
as TocRule,contentRule: null == contentRule ? _self.contentRule : contentRule // ignore: cast_nullable_to_non_nullable
as ContentRule,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}
/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SearchRuleCopyWith<$Res> get searchRule {
  
  return $SearchRuleCopyWith<$Res>(_self.searchRule, (value) {
    return _then(_self.copyWith(searchRule: value));
  });
}/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExploreRuleCopyWith<$Res>? get exploreRule {
    if (_self.exploreRule == null) {
    return null;
  }

  return $ExploreRuleCopyWith<$Res>(_self.exploreRule!, (value) {
    return _then(_self.copyWith(exploreRule: value));
  });
}/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookInfoRuleCopyWith<$Res>? get bookInfoRule {
    if (_self.bookInfoRule == null) {
    return null;
  }

  return $BookInfoRuleCopyWith<$Res>(_self.bookInfoRule!, (value) {
    return _then(_self.copyWith(bookInfoRule: value));
  });
}/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TocRuleCopyWith<$Res> get tocRule {
  
  return $TocRuleCopyWith<$Res>(_self.tocRule, (value) {
    return _then(_self.copyWith(tocRule: value));
  });
}/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentRuleCopyWith<$Res> get contentRule {
  
  return $ContentRuleCopyWith<$Res>(_self.contentRule, (value) {
    return _then(_self.copyWith(contentRule: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookSource].
extension BookSourcePatterns on BookSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookSource value)  $default,){
final _that = this;
switch (_that) {
case _BookSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookSource value)?  $default,){
final _that = this;
switch (_that) {
case _BookSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'bookSourceName')  String name, @JsonKey(name: 'bookSourceUrl')  String url, @JsonKey(name: 'bookSourceGroup')  String? group, @JsonKey(name: 'bookSourceType')  BookSourceType sourceType, @JsonKey(name: 'enabled')  bool isEnabled, @JsonKey(name: 'header')@_HeaderJsonConverter()  Map<String, String>? headers, @JsonKey(includeFromJson: false, includeToJson: false)  String? headerRule,  String? searchUrl, @JsonKey(name: 'exploreUrl')  String? exploreUrl, @JsonKey(name: 'ruleSearch')  SearchRule searchRule, @JsonKey(name: 'ruleExplore')  ExploreRule? exploreRule, @JsonKey(name: 'concurrentRate')  String? concurrentRate, @JsonKey(name: 'variableComment')  String? variableComment, @JsonKey(name: 'ruleBookInfo')  BookInfoRule? bookInfoRule, @JsonKey(name: 'ruleToc')  TocRule tocRule, @JsonKey(name: 'ruleContent')  ContentRule contentRule, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookSource() when $default != null:
return $default(_that.name,_that.url,_that.group,_that.sourceType,_that.isEnabled,_that.headers,_that.headerRule,_that.searchUrl,_that.exploreUrl,_that.searchRule,_that.exploreRule,_that.concurrentRate,_that.variableComment,_that.bookInfoRule,_that.tocRule,_that.contentRule,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'bookSourceName')  String name, @JsonKey(name: 'bookSourceUrl')  String url, @JsonKey(name: 'bookSourceGroup')  String? group, @JsonKey(name: 'bookSourceType')  BookSourceType sourceType, @JsonKey(name: 'enabled')  bool isEnabled, @JsonKey(name: 'header')@_HeaderJsonConverter()  Map<String, String>? headers, @JsonKey(includeFromJson: false, includeToJson: false)  String? headerRule,  String? searchUrl, @JsonKey(name: 'exploreUrl')  String? exploreUrl, @JsonKey(name: 'ruleSearch')  SearchRule searchRule, @JsonKey(name: 'ruleExplore')  ExploreRule? exploreRule, @JsonKey(name: 'concurrentRate')  String? concurrentRate, @JsonKey(name: 'variableComment')  String? variableComment, @JsonKey(name: 'ruleBookInfo')  BookInfoRule? bookInfoRule, @JsonKey(name: 'ruleToc')  TocRule tocRule, @JsonKey(name: 'ruleContent')  ContentRule contentRule, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _BookSource():
return $default(_that.name,_that.url,_that.group,_that.sourceType,_that.isEnabled,_that.headers,_that.headerRule,_that.searchUrl,_that.exploreUrl,_that.searchRule,_that.exploreRule,_that.concurrentRate,_that.variableComment,_that.bookInfoRule,_that.tocRule,_that.contentRule,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'bookSourceName')  String name, @JsonKey(name: 'bookSourceUrl')  String url, @JsonKey(name: 'bookSourceGroup')  String? group, @JsonKey(name: 'bookSourceType')  BookSourceType sourceType, @JsonKey(name: 'enabled')  bool isEnabled, @JsonKey(name: 'header')@_HeaderJsonConverter()  Map<String, String>? headers, @JsonKey(includeFromJson: false, includeToJson: false)  String? headerRule,  String? searchUrl, @JsonKey(name: 'exploreUrl')  String? exploreUrl, @JsonKey(name: 'ruleSearch')  SearchRule searchRule, @JsonKey(name: 'ruleExplore')  ExploreRule? exploreRule, @JsonKey(name: 'concurrentRate')  String? concurrentRate, @JsonKey(name: 'variableComment')  String? variableComment, @JsonKey(name: 'ruleBookInfo')  BookInfoRule? bookInfoRule, @JsonKey(name: 'ruleToc')  TocRule tocRule, @JsonKey(name: 'ruleContent')  ContentRule contentRule, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _BookSource() when $default != null:
return $default(_that.name,_that.url,_that.group,_that.sourceType,_that.isEnabled,_that.headers,_that.headerRule,_that.searchUrl,_that.exploreUrl,_that.searchRule,_that.exploreRule,_that.concurrentRate,_that.variableComment,_that.bookInfoRule,_that.tocRule,_that.contentRule,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookSource implements BookSource {
  const _BookSource({@JsonKey(name: 'bookSourceName') required this.name, @JsonKey(name: 'bookSourceUrl') required this.url, @JsonKey(name: 'bookSourceGroup') this.group, @JsonKey(name: 'bookSourceType') this.sourceType = BookSourceType.text, @JsonKey(name: 'enabled') this.isEnabled = true, @JsonKey(name: 'header')@_HeaderJsonConverter()  Map<String, String>? headers, @JsonKey(includeFromJson: false, includeToJson: false) this.headerRule, this.searchUrl, @JsonKey(name: 'exploreUrl') this.exploreUrl, @JsonKey(name: 'ruleSearch') required this.searchRule, @JsonKey(name: 'ruleExplore') this.exploreRule, @JsonKey(name: 'concurrentRate') this.concurrentRate, @JsonKey(name: 'variableComment') this.variableComment, @JsonKey(name: 'ruleBookInfo') this.bookInfoRule, @JsonKey(name: 'ruleToc') required this.tocRule, @JsonKey(name: 'ruleContent') required this.contentRule, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra = const <String, Object?>{}}): _headers = headers,_extra = extra;
  factory _BookSource.fromJson(Map<String, dynamic> json) => _$BookSourceFromJson(json);

@override@JsonKey(name: 'bookSourceName') final  String name;
@override@JsonKey(name: 'bookSourceUrl') final  String url;
@override@JsonKey(name: 'bookSourceGroup') final  String? group;
@override@JsonKey(name: 'bookSourceType') final  BookSourceType sourceType;
@override@JsonKey(name: 'enabled') final  bool isEnabled;
 final  Map<String, String>? _headers;
@override@JsonKey(name: 'header')@_HeaderJsonConverter() Map<String, String>? get headers {
  final value = _headers;
  if (value == null) return null;
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// The source's `header` when it is a **rule** rather than a JSON object
/// (`docs/dev/book-source.md` §2, M12-A2).
///
/// Upstream evaluates it before every request and parses its result as a JSON object
/// (`BaseSource.getHeaderMap`). The text is kept here rather than dropped, because a
/// source that signs its requests cannot be used at all without it; the evaluation itself
/// belongs to the fetch (`PageFetchService.headersOf`), which is where the sandbox is.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? headerRule;
@override final  String? searchUrl;
@override@JsonKey(name: 'exploreUrl') final  String? exploreUrl;
@override@JsonKey(name: 'ruleSearch') final  SearchRule searchRule;
@override@JsonKey(name: 'ruleExplore') final  ExploreRule? exploreRule;
@override@JsonKey(name: 'concurrentRate') final  String? concurrentRate;
@override@JsonKey(name: 'variableComment') final  String? variableComment;
@override@JsonKey(name: 'ruleBookInfo') final  BookInfoRule? bookInfoRule;
@override@JsonKey(name: 'ruleToc') final  TocRule tocRule;
@override@JsonKey(name: 'ruleContent') final  ContentRule contentRule;
 final  Map<String, Object?> _extra;
@override@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookSourceCopyWith<_BookSource> get copyWith => __$BookSourceCopyWithImpl<_BookSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookSourceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookSource&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.group, group) || other.group == group)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&const DeepCollectionEquality().equals(other.headers, _headers)&&(identical(other.headerRule, headerRule) || other.headerRule == headerRule)&&(identical(other.searchUrl, searchUrl) || other.searchUrl == searchUrl)&&(identical(other.exploreUrl, exploreUrl) || other.exploreUrl == exploreUrl)&&(identical(other.searchRule, searchRule) || other.searchRule == searchRule)&&(identical(other.exploreRule, exploreRule) || other.exploreRule == exploreRule)&&(identical(other.concurrentRate, concurrentRate) || other.concurrentRate == concurrentRate)&&(identical(other.variableComment, variableComment) || other.variableComment == variableComment)&&(identical(other.bookInfoRule, bookInfoRule) || other.bookInfoRule == bookInfoRule)&&(identical(other.tocRule, tocRule) || other.tocRule == tocRule)&&(identical(other.contentRule, contentRule) || other.contentRule == contentRule)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,url,group,sourceType,isEnabled,const DeepCollectionEquality().hash(_headers),headerRule,searchUrl,exploreUrl,searchRule,exploreRule,concurrentRate,variableComment,bookInfoRule,tocRule,contentRule,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'BookSource(name: $name, url: $url, group: $group, sourceType: $sourceType, isEnabled: $isEnabled, headers: $headers, headerRule: $headerRule, searchUrl: $searchUrl, exploreUrl: $exploreUrl, searchRule: $searchRule, exploreRule: $exploreRule, concurrentRate: $concurrentRate, variableComment: $variableComment, bookInfoRule: $bookInfoRule, tocRule: $tocRule, contentRule: $contentRule, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$BookSourceCopyWith<$Res> implements $BookSourceCopyWith<$Res> {
  factory _$BookSourceCopyWith(_BookSource value, $Res Function(_BookSource) _then) = __$BookSourceCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'bookSourceName') String name,@JsonKey(name: 'bookSourceUrl') String url,@JsonKey(name: 'bookSourceGroup') String? group,@JsonKey(name: 'bookSourceType') BookSourceType sourceType,@JsonKey(name: 'enabled') bool isEnabled,@JsonKey(name: 'header')@_HeaderJsonConverter() Map<String, String>? headers,@JsonKey(includeFromJson: false, includeToJson: false) String? headerRule, String? searchUrl,@JsonKey(name: 'exploreUrl') String? exploreUrl,@JsonKey(name: 'ruleSearch') SearchRule searchRule,@JsonKey(name: 'ruleExplore') ExploreRule? exploreRule,@JsonKey(name: 'concurrentRate') String? concurrentRate,@JsonKey(name: 'variableComment') String? variableComment,@JsonKey(name: 'ruleBookInfo') BookInfoRule? bookInfoRule,@JsonKey(name: 'ruleToc') TocRule tocRule,@JsonKey(name: 'ruleContent') ContentRule contentRule,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});


@override $SearchRuleCopyWith<$Res> get searchRule;@override $ExploreRuleCopyWith<$Res>? get exploreRule;@override $BookInfoRuleCopyWith<$Res>? get bookInfoRule;@override $TocRuleCopyWith<$Res> get tocRule;@override $ContentRuleCopyWith<$Res> get contentRule;

}
/// @nodoc
class __$BookSourceCopyWithImpl<$Res>
    implements _$BookSourceCopyWith<$Res> {
  __$BookSourceCopyWithImpl(this._self, this._then);

  final _BookSource _self;
  final $Res Function(_BookSource) _then;

/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,Object? group = freezed,Object? sourceType = null,Object? isEnabled = null,Object? headers = freezed,Object? headerRule = freezed,Object? searchUrl = freezed,Object? exploreUrl = freezed,Object? searchRule = null,Object? exploreRule = freezed,Object? concurrentRate = freezed,Object? variableComment = freezed,Object? bookInfoRule = freezed,Object? tocRule = null,Object? contentRule = null,Object? extra = null,}) {
  return _then(_BookSource(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as BookSourceType,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,headers: freezed == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,headerRule: freezed == headerRule ? _self.headerRule : headerRule // ignore: cast_nullable_to_non_nullable
as String?,searchUrl: freezed == searchUrl ? _self.searchUrl : searchUrl // ignore: cast_nullable_to_non_nullable
as String?,exploreUrl: freezed == exploreUrl ? _self.exploreUrl : exploreUrl // ignore: cast_nullable_to_non_nullable
as String?,searchRule: null == searchRule ? _self.searchRule : searchRule // ignore: cast_nullable_to_non_nullable
as SearchRule,exploreRule: freezed == exploreRule ? _self.exploreRule : exploreRule // ignore: cast_nullable_to_non_nullable
as ExploreRule?,concurrentRate: freezed == concurrentRate ? _self.concurrentRate : concurrentRate // ignore: cast_nullable_to_non_nullable
as String?,variableComment: freezed == variableComment ? _self.variableComment : variableComment // ignore: cast_nullable_to_non_nullable
as String?,bookInfoRule: freezed == bookInfoRule ? _self.bookInfoRule : bookInfoRule // ignore: cast_nullable_to_non_nullable
as BookInfoRule?,tocRule: null == tocRule ? _self.tocRule : tocRule // ignore: cast_nullable_to_non_nullable
as TocRule,contentRule: null == contentRule ? _self.contentRule : contentRule // ignore: cast_nullable_to_non_nullable
as ContentRule,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SearchRuleCopyWith<$Res> get searchRule {
  
  return $SearchRuleCopyWith<$Res>(_self.searchRule, (value) {
    return _then(_self.copyWith(searchRule: value));
  });
}/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExploreRuleCopyWith<$Res>? get exploreRule {
    if (_self.exploreRule == null) {
    return null;
  }

  return $ExploreRuleCopyWith<$Res>(_self.exploreRule!, (value) {
    return _then(_self.copyWith(exploreRule: value));
  });
}/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookInfoRuleCopyWith<$Res>? get bookInfoRule {
    if (_self.bookInfoRule == null) {
    return null;
  }

  return $BookInfoRuleCopyWith<$Res>(_self.bookInfoRule!, (value) {
    return _then(_self.copyWith(bookInfoRule: value));
  });
}/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TocRuleCopyWith<$Res> get tocRule {
  
  return $TocRuleCopyWith<$Res>(_self.tocRule, (value) {
    return _then(_self.copyWith(tocRule: value));
  });
}/// Create a copy of BookSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentRuleCopyWith<$Res> get contentRule {
  
  return $ContentRuleCopyWith<$Res>(_self.contentRule, (value) {
    return _then(_self.copyWith(contentRule: value));
  });
}
}


/// @nodoc
mixin _$SearchRule {

 String? get bookList; String? get name; String? get author; String? get kind; String? get wordCount; String? get lastChapter; String? get intro; String? get coverUrl; String? get bookUrl; String? get updateTime; String? get checkKeyWord;@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra;
/// Create a copy of SearchRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchRuleCopyWith<SearchRule> get copyWith => _$SearchRuleCopyWithImpl<SearchRule>(this as SearchRule, _$identity);

  /// Serializes this SearchRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SearchRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchRule&&(identical(other.bookList, _this.bookList) || other.bookList == _this.bookList)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.wordCount, _this.wordCount) || other.wordCount == _this.wordCount)&&(identical(other.lastChapter, _this.lastChapter) || other.lastChapter == _this.lastChapter)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime)&&(identical(other.checkKeyWord, _this.checkKeyWord) || other.checkKeyWord == _this.checkKeyWord)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SearchRule;
  return Object.hash(runtimeType,_this.bookList,_this.name,_this.author,_this.kind,_this.wordCount,_this.lastChapter,_this.intro,_this.coverUrl,_this.bookUrl,_this.updateTime,_this.checkKeyWord,const DeepCollectionEquality().hash(_this.extra));
}

@override
String toString() {
  final _this = this as SearchRule;
  return 'SearchRule(bookList: ${_this.bookList}, name: ${_this.name}, author: ${_this.author}, kind: ${_this.kind}, wordCount: ${_this.wordCount}, lastChapter: ${_this.lastChapter}, intro: ${_this.intro}, coverUrl: ${_this.coverUrl}, bookUrl: ${_this.bookUrl}, updateTime: ${_this.updateTime}, checkKeyWord: ${_this.checkKeyWord}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $SearchRuleCopyWith<$Res>  {
  factory $SearchRuleCopyWith(SearchRule value, $Res Function(SearchRule) _then) = _$SearchRuleCopyWithImpl;
@useResult
$Res call({
 String? bookList, String? name, String? author, String? kind, String? wordCount, String? lastChapter, String? intro, String? coverUrl, String? bookUrl, String? updateTime, String? checkKeyWord,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class _$SearchRuleCopyWithImpl<$Res>
    implements $SearchRuleCopyWith<$Res> {
  _$SearchRuleCopyWithImpl(this._self, this._then);

  final SearchRule _self;
  final $Res Function(SearchRule) _then;

/// Create a copy of SearchRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookList = freezed,Object? name = freezed,Object? author = freezed,Object? kind = freezed,Object? wordCount = freezed,Object? lastChapter = freezed,Object? intro = freezed,Object? coverUrl = freezed,Object? bookUrl = freezed,Object? updateTime = freezed,Object? checkKeyWord = freezed,Object? extra = null,}) {
  return _then(SearchRule(
bookList: freezed == bookList ? _self.bookList : bookList // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,bookUrl: freezed == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,checkKeyWord: freezed == checkKeyWord ? _self.checkKeyWord : checkKeyWord // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchRule].
extension SearchRulePatterns on SearchRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchRule value)  $default,){
final _that = this;
switch (_that) {
case _SearchRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchRule value)?  $default,){
final _that = this;
switch (_that) {
case _SearchRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? bookList,  String? name,  String? author,  String? kind,  String? wordCount,  String? lastChapter,  String? intro,  String? coverUrl,  String? bookUrl,  String? updateTime,  String? checkKeyWord, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchRule() when $default != null:
return $default(_that.bookList,_that.name,_that.author,_that.kind,_that.wordCount,_that.lastChapter,_that.intro,_that.coverUrl,_that.bookUrl,_that.updateTime,_that.checkKeyWord,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? bookList,  String? name,  String? author,  String? kind,  String? wordCount,  String? lastChapter,  String? intro,  String? coverUrl,  String? bookUrl,  String? updateTime,  String? checkKeyWord, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _SearchRule():
return $default(_that.bookList,_that.name,_that.author,_that.kind,_that.wordCount,_that.lastChapter,_that.intro,_that.coverUrl,_that.bookUrl,_that.updateTime,_that.checkKeyWord,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? bookList,  String? name,  String? author,  String? kind,  String? wordCount,  String? lastChapter,  String? intro,  String? coverUrl,  String? bookUrl,  String? updateTime,  String? checkKeyWord, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _SearchRule() when $default != null:
return $default(_that.bookList,_that.name,_that.author,_that.kind,_that.wordCount,_that.lastChapter,_that.intro,_that.coverUrl,_that.bookUrl,_that.updateTime,_that.checkKeyWord,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SearchRule implements SearchRule {
  const _SearchRule({this.bookList, this.name, this.author, this.kind, this.wordCount, this.lastChapter, this.intro, this.coverUrl, this.bookUrl, this.updateTime, this.checkKeyWord, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  factory _SearchRule.fromJson(Map<String, dynamic> json) => _$SearchRuleFromJson(json);

@override final  String? bookList;
@override final  String? name;
@override final  String? author;
@override final  String? kind;
@override final  String? wordCount;
@override final  String? lastChapter;
@override final  String? intro;
@override final  String? coverUrl;
@override final  String? bookUrl;
@override final  String? updateTime;
@override final  String? checkKeyWord;
 final  Map<String, Object?> _extra;
@override@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of SearchRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchRuleCopyWith<_SearchRule> get copyWith => __$SearchRuleCopyWithImpl<_SearchRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SearchRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchRule&&(identical(other.bookList, bookList) || other.bookList == bookList)&&(identical(other.name, name) || other.name == name)&&(identical(other.author, author) || other.author == author)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.wordCount, wordCount) || other.wordCount == wordCount)&&(identical(other.lastChapter, lastChapter) || other.lastChapter == lastChapter)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime)&&(identical(other.checkKeyWord, checkKeyWord) || other.checkKeyWord == checkKeyWord)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bookList,name,author,kind,wordCount,lastChapter,intro,coverUrl,bookUrl,updateTime,checkKeyWord,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'SearchRule(bookList: $bookList, name: $name, author: $author, kind: $kind, wordCount: $wordCount, lastChapter: $lastChapter, intro: $intro, coverUrl: $coverUrl, bookUrl: $bookUrl, updateTime: $updateTime, checkKeyWord: $checkKeyWord, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$SearchRuleCopyWith<$Res> implements $SearchRuleCopyWith<$Res> {
  factory _$SearchRuleCopyWith(_SearchRule value, $Res Function(_SearchRule) _then) = __$SearchRuleCopyWithImpl;
@override @useResult
$Res call({
 String? bookList, String? name, String? author, String? kind, String? wordCount, String? lastChapter, String? intro, String? coverUrl, String? bookUrl, String? updateTime, String? checkKeyWord,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class __$SearchRuleCopyWithImpl<$Res>
    implements _$SearchRuleCopyWith<$Res> {
  __$SearchRuleCopyWithImpl(this._self, this._then);

  final _SearchRule _self;
  final $Res Function(_SearchRule) _then;

/// Create a copy of SearchRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookList = freezed,Object? name = freezed,Object? author = freezed,Object? kind = freezed,Object? wordCount = freezed,Object? lastChapter = freezed,Object? intro = freezed,Object? coverUrl = freezed,Object? bookUrl = freezed,Object? updateTime = freezed,Object? checkKeyWord = freezed,Object? extra = null,}) {
  return _then(_SearchRule(
bookList: freezed == bookList ? _self.bookList : bookList // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,bookUrl: freezed == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,checkKeyWord: freezed == checkKeyWord ? _self.checkKeyWord : checkKeyWord // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$ExploreRule {

 String? get bookList; String? get name; String? get author; String? get kind; String? get wordCount; String? get lastChapter; String? get intro; String? get coverUrl; String? get bookUrl; String? get updateTime;@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra;
/// Create a copy of ExploreRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExploreRuleCopyWith<ExploreRule> get copyWith => _$ExploreRuleCopyWithImpl<ExploreRule>(this as ExploreRule, _$identity);

  /// Serializes this ExploreRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ExploreRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreRule&&(identical(other.bookList, _this.bookList) || other.bookList == _this.bookList)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.wordCount, _this.wordCount) || other.wordCount == _this.wordCount)&&(identical(other.lastChapter, _this.lastChapter) || other.lastChapter == _this.lastChapter)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.bookUrl, _this.bookUrl) || other.bookUrl == _this.bookUrl)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ExploreRule;
  return Object.hash(runtimeType,_this.bookList,_this.name,_this.author,_this.kind,_this.wordCount,_this.lastChapter,_this.intro,_this.coverUrl,_this.bookUrl,_this.updateTime,const DeepCollectionEquality().hash(_this.extra));
}

@override
String toString() {
  final _this = this as ExploreRule;
  return 'ExploreRule(bookList: ${_this.bookList}, name: ${_this.name}, author: ${_this.author}, kind: ${_this.kind}, wordCount: ${_this.wordCount}, lastChapter: ${_this.lastChapter}, intro: ${_this.intro}, coverUrl: ${_this.coverUrl}, bookUrl: ${_this.bookUrl}, updateTime: ${_this.updateTime}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $ExploreRuleCopyWith<$Res>  {
  factory $ExploreRuleCopyWith(ExploreRule value, $Res Function(ExploreRule) _then) = _$ExploreRuleCopyWithImpl;
@useResult
$Res call({
 String? bookList, String? name, String? author, String? kind, String? wordCount, String? lastChapter, String? intro, String? coverUrl, String? bookUrl, String? updateTime,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class _$ExploreRuleCopyWithImpl<$Res>
    implements $ExploreRuleCopyWith<$Res> {
  _$ExploreRuleCopyWithImpl(this._self, this._then);

  final ExploreRule _self;
  final $Res Function(ExploreRule) _then;

/// Create a copy of ExploreRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookList = freezed,Object? name = freezed,Object? author = freezed,Object? kind = freezed,Object? wordCount = freezed,Object? lastChapter = freezed,Object? intro = freezed,Object? coverUrl = freezed,Object? bookUrl = freezed,Object? updateTime = freezed,Object? extra = null,}) {
  return _then(ExploreRule(
bookList: freezed == bookList ? _self.bookList : bookList // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,bookUrl: freezed == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [ExploreRule].
extension ExploreRulePatterns on ExploreRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExploreRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExploreRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExploreRule value)  $default,){
final _that = this;
switch (_that) {
case _ExploreRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExploreRule value)?  $default,){
final _that = this;
switch (_that) {
case _ExploreRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? bookList,  String? name,  String? author,  String? kind,  String? wordCount,  String? lastChapter,  String? intro,  String? coverUrl,  String? bookUrl,  String? updateTime, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExploreRule() when $default != null:
return $default(_that.bookList,_that.name,_that.author,_that.kind,_that.wordCount,_that.lastChapter,_that.intro,_that.coverUrl,_that.bookUrl,_that.updateTime,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? bookList,  String? name,  String? author,  String? kind,  String? wordCount,  String? lastChapter,  String? intro,  String? coverUrl,  String? bookUrl,  String? updateTime, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _ExploreRule():
return $default(_that.bookList,_that.name,_that.author,_that.kind,_that.wordCount,_that.lastChapter,_that.intro,_that.coverUrl,_that.bookUrl,_that.updateTime,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? bookList,  String? name,  String? author,  String? kind,  String? wordCount,  String? lastChapter,  String? intro,  String? coverUrl,  String? bookUrl,  String? updateTime, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _ExploreRule() when $default != null:
return $default(_that.bookList,_that.name,_that.author,_that.kind,_that.wordCount,_that.lastChapter,_that.intro,_that.coverUrl,_that.bookUrl,_that.updateTime,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExploreRule implements ExploreRule {
  const _ExploreRule({this.bookList, this.name, this.author, this.kind, this.wordCount, this.lastChapter, this.intro, this.coverUrl, this.bookUrl, this.updateTime, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  factory _ExploreRule.fromJson(Map<String, dynamic> json) => _$ExploreRuleFromJson(json);

@override final  String? bookList;
@override final  String? name;
@override final  String? author;
@override final  String? kind;
@override final  String? wordCount;
@override final  String? lastChapter;
@override final  String? intro;
@override final  String? coverUrl;
@override final  String? bookUrl;
@override final  String? updateTime;
 final  Map<String, Object?> _extra;
@override@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of ExploreRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExploreRuleCopyWith<_ExploreRule> get copyWith => __$ExploreRuleCopyWithImpl<_ExploreRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExploreRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExploreRule&&(identical(other.bookList, bookList) || other.bookList == bookList)&&(identical(other.name, name) || other.name == name)&&(identical(other.author, author) || other.author == author)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.wordCount, wordCount) || other.wordCount == wordCount)&&(identical(other.lastChapter, lastChapter) || other.lastChapter == lastChapter)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bookList,name,author,kind,wordCount,lastChapter,intro,coverUrl,bookUrl,updateTime,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'ExploreRule(bookList: $bookList, name: $name, author: $author, kind: $kind, wordCount: $wordCount, lastChapter: $lastChapter, intro: $intro, coverUrl: $coverUrl, bookUrl: $bookUrl, updateTime: $updateTime, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$ExploreRuleCopyWith<$Res> implements $ExploreRuleCopyWith<$Res> {
  factory _$ExploreRuleCopyWith(_ExploreRule value, $Res Function(_ExploreRule) _then) = __$ExploreRuleCopyWithImpl;
@override @useResult
$Res call({
 String? bookList, String? name, String? author, String? kind, String? wordCount, String? lastChapter, String? intro, String? coverUrl, String? bookUrl, String? updateTime,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class __$ExploreRuleCopyWithImpl<$Res>
    implements _$ExploreRuleCopyWith<$Res> {
  __$ExploreRuleCopyWithImpl(this._self, this._then);

  final _ExploreRule _self;
  final $Res Function(_ExploreRule) _then;

/// Create a copy of ExploreRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookList = freezed,Object? name = freezed,Object? author = freezed,Object? kind = freezed,Object? wordCount = freezed,Object? lastChapter = freezed,Object? intro = freezed,Object? coverUrl = freezed,Object? bookUrl = freezed,Object? updateTime = freezed,Object? extra = null,}) {
  return _then(_ExploreRule(
bookList: freezed == bookList ? _self.bookList : bookList // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,bookUrl: freezed == bookUrl ? _self.bookUrl : bookUrl // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$BookInfoRule {

 String? get init; String? get name; String? get author; String? get kind; String? get lastChapter; String? get intro; String? get coverUrl; String? get tocUrl; String? get wordCount; String? get updateTime; String? get canReName;@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra;
/// Create a copy of BookInfoRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookInfoRuleCopyWith<BookInfoRule> get copyWith => _$BookInfoRuleCopyWithImpl<BookInfoRule>(this as BookInfoRule, _$identity);

  /// Serializes this BookInfoRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookInfoRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookInfoRule&&(identical(other.init, _this.init) || other.init == _this.init)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.lastChapter, _this.lastChapter) || other.lastChapter == _this.lastChapter)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.tocUrl, _this.tocUrl) || other.tocUrl == _this.tocUrl)&&(identical(other.wordCount, _this.wordCount) || other.wordCount == _this.wordCount)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime)&&(identical(other.canReName, _this.canReName) || other.canReName == _this.canReName)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookInfoRule;
  return Object.hash(runtimeType,_this.init,_this.name,_this.author,_this.kind,_this.lastChapter,_this.intro,_this.coverUrl,_this.tocUrl,_this.wordCount,_this.updateTime,_this.canReName,const DeepCollectionEquality().hash(_this.extra));
}

@override
String toString() {
  final _this = this as BookInfoRule;
  return 'BookInfoRule(init: ${_this.init}, name: ${_this.name}, author: ${_this.author}, kind: ${_this.kind}, lastChapter: ${_this.lastChapter}, intro: ${_this.intro}, coverUrl: ${_this.coverUrl}, tocUrl: ${_this.tocUrl}, wordCount: ${_this.wordCount}, updateTime: ${_this.updateTime}, canReName: ${_this.canReName}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $BookInfoRuleCopyWith<$Res>  {
  factory $BookInfoRuleCopyWith(BookInfoRule value, $Res Function(BookInfoRule) _then) = _$BookInfoRuleCopyWithImpl;
@useResult
$Res call({
 String? init, String? name, String? author, String? kind, String? lastChapter, String? intro, String? coverUrl, String? tocUrl, String? wordCount, String? updateTime, String? canReName,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class _$BookInfoRuleCopyWithImpl<$Res>
    implements $BookInfoRuleCopyWith<$Res> {
  _$BookInfoRuleCopyWithImpl(this._self, this._then);

  final BookInfoRule _self;
  final $Res Function(BookInfoRule) _then;

/// Create a copy of BookInfoRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? init = freezed,Object? name = freezed,Object? author = freezed,Object? kind = freezed,Object? lastChapter = freezed,Object? intro = freezed,Object? coverUrl = freezed,Object? tocUrl = freezed,Object? wordCount = freezed,Object? updateTime = freezed,Object? canReName = freezed,Object? extra = null,}) {
  return _then(BookInfoRule(
init: freezed == init ? _self.init : init // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,tocUrl: freezed == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,canReName: freezed == canReName ? _self.canReName : canReName // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [BookInfoRule].
extension BookInfoRulePatterns on BookInfoRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookInfoRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookInfoRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookInfoRule value)  $default,){
final _that = this;
switch (_that) {
case _BookInfoRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookInfoRule value)?  $default,){
final _that = this;
switch (_that) {
case _BookInfoRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? init,  String? name,  String? author,  String? kind,  String? lastChapter,  String? intro,  String? coverUrl,  String? tocUrl,  String? wordCount,  String? updateTime,  String? canReName, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookInfoRule() when $default != null:
return $default(_that.init,_that.name,_that.author,_that.kind,_that.lastChapter,_that.intro,_that.coverUrl,_that.tocUrl,_that.wordCount,_that.updateTime,_that.canReName,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? init,  String? name,  String? author,  String? kind,  String? lastChapter,  String? intro,  String? coverUrl,  String? tocUrl,  String? wordCount,  String? updateTime,  String? canReName, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _BookInfoRule():
return $default(_that.init,_that.name,_that.author,_that.kind,_that.lastChapter,_that.intro,_that.coverUrl,_that.tocUrl,_that.wordCount,_that.updateTime,_that.canReName,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? init,  String? name,  String? author,  String? kind,  String? lastChapter,  String? intro,  String? coverUrl,  String? tocUrl,  String? wordCount,  String? updateTime,  String? canReName, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _BookInfoRule() when $default != null:
return $default(_that.init,_that.name,_that.author,_that.kind,_that.lastChapter,_that.intro,_that.coverUrl,_that.tocUrl,_that.wordCount,_that.updateTime,_that.canReName,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookInfoRule implements BookInfoRule {
  const _BookInfoRule({this.init, this.name, this.author, this.kind, this.lastChapter, this.intro, this.coverUrl, this.tocUrl, this.wordCount, this.updateTime, this.canReName, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  factory _BookInfoRule.fromJson(Map<String, dynamic> json) => _$BookInfoRuleFromJson(json);

@override final  String? init;
@override final  String? name;
@override final  String? author;
@override final  String? kind;
@override final  String? lastChapter;
@override final  String? intro;
@override final  String? coverUrl;
@override final  String? tocUrl;
@override final  String? wordCount;
@override final  String? updateTime;
@override final  String? canReName;
 final  Map<String, Object?> _extra;
@override@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of BookInfoRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookInfoRuleCopyWith<_BookInfoRule> get copyWith => __$BookInfoRuleCopyWithImpl<_BookInfoRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookInfoRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookInfoRule&&(identical(other.init, init) || other.init == init)&&(identical(other.name, name) || other.name == name)&&(identical(other.author, author) || other.author == author)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.lastChapter, lastChapter) || other.lastChapter == lastChapter)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl)&&(identical(other.wordCount, wordCount) || other.wordCount == wordCount)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime)&&(identical(other.canReName, canReName) || other.canReName == canReName)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,init,name,author,kind,lastChapter,intro,coverUrl,tocUrl,wordCount,updateTime,canReName,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'BookInfoRule(init: $init, name: $name, author: $author, kind: $kind, lastChapter: $lastChapter, intro: $intro, coverUrl: $coverUrl, tocUrl: $tocUrl, wordCount: $wordCount, updateTime: $updateTime, canReName: $canReName, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$BookInfoRuleCopyWith<$Res> implements $BookInfoRuleCopyWith<$Res> {
  factory _$BookInfoRuleCopyWith(_BookInfoRule value, $Res Function(_BookInfoRule) _then) = __$BookInfoRuleCopyWithImpl;
@override @useResult
$Res call({
 String? init, String? name, String? author, String? kind, String? lastChapter, String? intro, String? coverUrl, String? tocUrl, String? wordCount, String? updateTime, String? canReName,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class __$BookInfoRuleCopyWithImpl<$Res>
    implements _$BookInfoRuleCopyWith<$Res> {
  __$BookInfoRuleCopyWithImpl(this._self, this._then);

  final _BookInfoRule _self;
  final $Res Function(_BookInfoRule) _then;

/// Create a copy of BookInfoRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? init = freezed,Object? name = freezed,Object? author = freezed,Object? kind = freezed,Object? lastChapter = freezed,Object? intro = freezed,Object? coverUrl = freezed,Object? tocUrl = freezed,Object? wordCount = freezed,Object? updateTime = freezed,Object? canReName = freezed,Object? extra = null,}) {
  return _then(_BookInfoRule(
init: freezed == init ? _self.init : init // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,lastChapter: freezed == lastChapter ? _self.lastChapter : lastChapter // ignore: cast_nullable_to_non_nullable
as String?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,tocUrl: freezed == tocUrl ? _self.tocUrl : tocUrl // ignore: cast_nullable_to_non_nullable
as String?,wordCount: freezed == wordCount ? _self.wordCount : wordCount // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,canReName: freezed == canReName ? _self.canReName : canReName // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$TocRule {

 String? get chapterList; String? get chapterName; String? get chapterUrl; String? get isVip; String? get updateTime; String? get nextTocUrl;@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra;
/// Create a copy of TocRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TocRuleCopyWith<TocRule> get copyWith => _$TocRuleCopyWithImpl<TocRule>(this as TocRule, _$identity);

  /// Serializes this TocRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TocRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TocRule&&(identical(other.chapterList, _this.chapterList) || other.chapterList == _this.chapterList)&&(identical(other.chapterName, _this.chapterName) || other.chapterName == _this.chapterName)&&(identical(other.chapterUrl, _this.chapterUrl) || other.chapterUrl == _this.chapterUrl)&&(identical(other.isVip, _this.isVip) || other.isVip == _this.isVip)&&(identical(other.updateTime, _this.updateTime) || other.updateTime == _this.updateTime)&&(identical(other.nextTocUrl, _this.nextTocUrl) || other.nextTocUrl == _this.nextTocUrl)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TocRule;
  return Object.hash(runtimeType,_this.chapterList,_this.chapterName,_this.chapterUrl,_this.isVip,_this.updateTime,_this.nextTocUrl,const DeepCollectionEquality().hash(_this.extra));
}

@override
String toString() {
  final _this = this as TocRule;
  return 'TocRule(chapterList: ${_this.chapterList}, chapterName: ${_this.chapterName}, chapterUrl: ${_this.chapterUrl}, isVip: ${_this.isVip}, updateTime: ${_this.updateTime}, nextTocUrl: ${_this.nextTocUrl}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $TocRuleCopyWith<$Res>  {
  factory $TocRuleCopyWith(TocRule value, $Res Function(TocRule) _then) = _$TocRuleCopyWithImpl;
@useResult
$Res call({
 String? chapterList, String? chapterName, String? chapterUrl, String? isVip, String? updateTime, String? nextTocUrl,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class _$TocRuleCopyWithImpl<$Res>
    implements $TocRuleCopyWith<$Res> {
  _$TocRuleCopyWithImpl(this._self, this._then);

  final TocRule _self;
  final $Res Function(TocRule) _then;

/// Create a copy of TocRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapterList = freezed,Object? chapterName = freezed,Object? chapterUrl = freezed,Object? isVip = freezed,Object? updateTime = freezed,Object? nextTocUrl = freezed,Object? extra = null,}) {
  return _then(TocRule(
chapterList: freezed == chapterList ? _self.chapterList : chapterList // ignore: cast_nullable_to_non_nullable
as String?,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,chapterUrl: freezed == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String?,isVip: freezed == isVip ? _self.isVip : isVip // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,nextTocUrl: freezed == nextTocUrl ? _self.nextTocUrl : nextTocUrl // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [TocRule].
extension TocRulePatterns on TocRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TocRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TocRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TocRule value)  $default,){
final _that = this;
switch (_that) {
case _TocRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TocRule value)?  $default,){
final _that = this;
switch (_that) {
case _TocRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? chapterList,  String? chapterName,  String? chapterUrl,  String? isVip,  String? updateTime,  String? nextTocUrl, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TocRule() when $default != null:
return $default(_that.chapterList,_that.chapterName,_that.chapterUrl,_that.isVip,_that.updateTime,_that.nextTocUrl,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? chapterList,  String? chapterName,  String? chapterUrl,  String? isVip,  String? updateTime,  String? nextTocUrl, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _TocRule():
return $default(_that.chapterList,_that.chapterName,_that.chapterUrl,_that.isVip,_that.updateTime,_that.nextTocUrl,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? chapterList,  String? chapterName,  String? chapterUrl,  String? isVip,  String? updateTime,  String? nextTocUrl, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _TocRule() when $default != null:
return $default(_that.chapterList,_that.chapterName,_that.chapterUrl,_that.isVip,_that.updateTime,_that.nextTocUrl,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TocRule implements TocRule {
  const _TocRule({this.chapterList, this.chapterName, this.chapterUrl, this.isVip, this.updateTime, this.nextTocUrl, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  factory _TocRule.fromJson(Map<String, dynamic> json) => _$TocRuleFromJson(json);

@override final  String? chapterList;
@override final  String? chapterName;
@override final  String? chapterUrl;
@override final  String? isVip;
@override final  String? updateTime;
@override final  String? nextTocUrl;
 final  Map<String, Object?> _extra;
@override@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of TocRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TocRuleCopyWith<_TocRule> get copyWith => __$TocRuleCopyWithImpl<_TocRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TocRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TocRule&&(identical(other.chapterList, chapterList) || other.chapterList == chapterList)&&(identical(other.chapterName, chapterName) || other.chapterName == chapterName)&&(identical(other.chapterUrl, chapterUrl) || other.chapterUrl == chapterUrl)&&(identical(other.isVip, isVip) || other.isVip == isVip)&&(identical(other.updateTime, updateTime) || other.updateTime == updateTime)&&(identical(other.nextTocUrl, nextTocUrl) || other.nextTocUrl == nextTocUrl)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,chapterList,chapterName,chapterUrl,isVip,updateTime,nextTocUrl,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'TocRule(chapterList: $chapterList, chapterName: $chapterName, chapterUrl: $chapterUrl, isVip: $isVip, updateTime: $updateTime, nextTocUrl: $nextTocUrl, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$TocRuleCopyWith<$Res> implements $TocRuleCopyWith<$Res> {
  factory _$TocRuleCopyWith(_TocRule value, $Res Function(_TocRule) _then) = __$TocRuleCopyWithImpl;
@override @useResult
$Res call({
 String? chapterList, String? chapterName, String? chapterUrl, String? isVip, String? updateTime, String? nextTocUrl,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class __$TocRuleCopyWithImpl<$Res>
    implements _$TocRuleCopyWith<$Res> {
  __$TocRuleCopyWithImpl(this._self, this._then);

  final _TocRule _self;
  final $Res Function(_TocRule) _then;

/// Create a copy of TocRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chapterList = freezed,Object? chapterName = freezed,Object? chapterUrl = freezed,Object? isVip = freezed,Object? updateTime = freezed,Object? nextTocUrl = freezed,Object? extra = null,}) {
  return _then(_TocRule(
chapterList: freezed == chapterList ? _self.chapterList : chapterList // ignore: cast_nullable_to_non_nullable
as String?,chapterName: freezed == chapterName ? _self.chapterName : chapterName // ignore: cast_nullable_to_non_nullable
as String?,chapterUrl: freezed == chapterUrl ? _self.chapterUrl : chapterUrl // ignore: cast_nullable_to_non_nullable
as String?,isVip: freezed == isVip ? _self.isVip : isVip // ignore: cast_nullable_to_non_nullable
as String?,updateTime: freezed == updateTime ? _self.updateTime : updateTime // ignore: cast_nullable_to_non_nullable
as String?,nextTocUrl: freezed == nextTocUrl ? _self.nextTocUrl : nextTocUrl // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$ContentRule {

 String? get content; String? get nextContentUrl; String? get replaceRegex;@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra;
/// Create a copy of ContentRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContentRuleCopyWith<ContentRule> get copyWith => _$ContentRuleCopyWithImpl<ContentRule>(this as ContentRule, _$identity);

  /// Serializes this ContentRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ContentRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContentRule&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.nextContentUrl, _this.nextContentUrl) || other.nextContentUrl == _this.nextContentUrl)&&(identical(other.replaceRegex, _this.replaceRegex) || other.replaceRegex == _this.replaceRegex)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ContentRule;
  return Object.hash(runtimeType,_this.content,_this.nextContentUrl,_this.replaceRegex,const DeepCollectionEquality().hash(_this.extra));
}

@override
String toString() {
  final _this = this as ContentRule;
  return 'ContentRule(content: ${_this.content}, nextContentUrl: ${_this.nextContentUrl}, replaceRegex: ${_this.replaceRegex}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $ContentRuleCopyWith<$Res>  {
  factory $ContentRuleCopyWith(ContentRule value, $Res Function(ContentRule) _then) = _$ContentRuleCopyWithImpl;
@useResult
$Res call({
 String? content, String? nextContentUrl, String? replaceRegex,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class _$ContentRuleCopyWithImpl<$Res>
    implements $ContentRuleCopyWith<$Res> {
  _$ContentRuleCopyWithImpl(this._self, this._then);

  final ContentRule _self;
  final $Res Function(ContentRule) _then;

/// Create a copy of ContentRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = freezed,Object? nextContentUrl = freezed,Object? replaceRegex = freezed,Object? extra = null,}) {
  return _then(ContentRule(
content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,nextContentUrl: freezed == nextContentUrl ? _self.nextContentUrl : nextContentUrl // ignore: cast_nullable_to_non_nullable
as String?,replaceRegex: freezed == replaceRegex ? _self.replaceRegex : replaceRegex // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [ContentRule].
extension ContentRulePatterns on ContentRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContentRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContentRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContentRule value)  $default,){
final _that = this;
switch (_that) {
case _ContentRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContentRule value)?  $default,){
final _that = this;
switch (_that) {
case _ContentRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? content,  String? nextContentUrl,  String? replaceRegex, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContentRule() when $default != null:
return $default(_that.content,_that.nextContentUrl,_that.replaceRegex,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? content,  String? nextContentUrl,  String? replaceRegex, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _ContentRule():
return $default(_that.content,_that.nextContentUrl,_that.replaceRegex,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? content,  String? nextContentUrl,  String? replaceRegex, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _ContentRule() when $default != null:
return $default(_that.content,_that.nextContentUrl,_that.replaceRegex,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ContentRule implements ContentRule {
  const _ContentRule({this.content, this.nextContentUrl, this.replaceRegex, @JsonKey(includeFromJson: false, includeToJson: false)  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra;
  factory _ContentRule.fromJson(Map<String, dynamic> json) => _$ContentRuleFromJson(json);

@override final  String? content;
@override final  String? nextContentUrl;
@override final  String? replaceRegex;
 final  Map<String, Object?> _extra;
@override@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of ContentRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContentRuleCopyWith<_ContentRule> get copyWith => __$ContentRuleCopyWithImpl<_ContentRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContentRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContentRule&&(identical(other.content, content) || other.content == content)&&(identical(other.nextContentUrl, nextContentUrl) || other.nextContentUrl == nextContentUrl)&&(identical(other.replaceRegex, replaceRegex) || other.replaceRegex == replaceRegex)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,content,nextContentUrl,replaceRegex,const DeepCollectionEquality().hash(_extra));
}

@override
String toString() {
    return 'ContentRule(content: $content, nextContentUrl: $nextContentUrl, replaceRegex: $replaceRegex, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$ContentRuleCopyWith<$Res> implements $ContentRuleCopyWith<$Res> {
  factory _$ContentRuleCopyWith(_ContentRule value, $Res Function(_ContentRule) _then) = __$ContentRuleCopyWithImpl;
@override @useResult
$Res call({
 String? content, String? nextContentUrl, String? replaceRegex,@JsonKey(includeFromJson: false, includeToJson: false) Map<String, Object?> extra
});




}
/// @nodoc
class __$ContentRuleCopyWithImpl<$Res>
    implements _$ContentRuleCopyWith<$Res> {
  __$ContentRuleCopyWithImpl(this._self, this._then);

  final _ContentRule _self;
  final $Res Function(_ContentRule) _then;

/// Create a copy of ContentRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = freezed,Object? nextContentUrl = freezed,Object? replaceRegex = freezed,Object? extra = null,}) {
  return _then(_ContentRule(
content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,nextContentUrl: freezed == nextContentUrl ? _self.nextContentUrl : nextContentUrl // ignore: cast_nullable_to_non_nullable
as String?,replaceRegex: freezed == replaceRegex ? _self.replaceRegex : replaceRegex // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on
