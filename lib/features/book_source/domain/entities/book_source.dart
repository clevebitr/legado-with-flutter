import 'dart:convert';

import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_source.freezed.dart';
part 'book_source.g.dart';

/// Kind of content a Legado book source serves (`bookSourceType`).
enum BookSourceType {
  /// Text content.
  @JsonValue(0)
  text,

  /// Audio content.
  @JsonValue(1)
  audio,

  /// Image content.
  @JsonValue(2)
  image,

  /// File content.
  @JsonValue(3)
  file,

  /// Video content (Legado value 4).
  @JsonValue(4)
  video,
}

/// One imported Legado book source: the rules that drive search, book info, TOC and content parsing.
/// `@JsonKey` maps fields to the original Legado keys, and everything unmodelled survives in [extra].
@freezed
abstract class BookSource with _$BookSource {
  /// Creates a book source.
  const factory BookSource({
    @JsonKey(name: 'bookSourceName') required String name,
    @JsonKey(name: 'bookSourceUrl') required String url,
    @JsonKey(name: 'bookSourceGroup') String? group,
    @JsonKey(name: 'bookSourceType')
    @Default(BookSourceType.text)
    BookSourceType sourceType,
    @JsonKey(name: 'enabled') @Default(true) bool isEnabled,
    @JsonKey(name: 'header')
    @_HeaderJsonConverter()
    Map<String, String>? headers,

    /// The source's `header` when it holds a rule rather than a JSON object; evaluated before
    /// each request and parsed as a JSON object.
    @JsonKey(includeFromJson: false, includeToJson: false) String? headerRule,
    String? searchUrl,
    @JsonKey(name: 'exploreUrl') String? exploreUrl,
    @JsonKey(name: 'ruleSearch') required SearchRule searchRule,
    @JsonKey(name: 'ruleExplore') ExploreRule? exploreRule,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    @JsonKey(name: 'variableComment') String? variableComment,

    /// The address (or a script defining `login()`) a source signs in at (`loginUrl`).
    ///
    /// It is a **URL rule**, so it may carry the `,{…}` suffix of `book-source.md` §4.3, and it is
    /// opened in the visible WebView by hand (ADR-0068 §决策 3, addendum of 2026-10-24); its cookies
    /// land in the v8 cookie jar like a verification page's.
    String? loginUrl,

    /// The login form description (`loginUi`), kept verbatim.
    ///
    /// Upstream renders it as a native form (a JSON array of field descriptors). This repository
    /// models it so an import/export round trip does not lose it, and the form itself belongs to the
    /// login/Cookie management UI of M21b (`docs/dev/ui-gap.md` U15, ADR-0068 §决策 1).
    String? loginUi,

    /// The **response interceptor** a source runs after every page request (`loginCheckJs`).
    ///
    /// It is not a `true`/`false` check: upstream hands the script a `result` response object and
    /// replaces the response with whatever the script returns (see `book-source.md` §6 and the
    /// ADR-0068 addendum). Blank means "no interceptor".
    String? loginCheckJs,
    @JsonKey(name: 'ruleBookInfo') BookInfoRule? bookInfoRule,
    @JsonKey(name: 'ruleToc') required TocRule tocRule,
    @JsonKey(name: 'ruleContent') required ContentRule contentRule,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String, Object?>{})
    Map<String, Object?> extra,
  }) = _BookSource;

  /// Parses one book source object, dropping keys the model does not know.
  factory BookSource.fromJson(Map<String, Object?> json) =>
      _$BookSourceFromJson(json);

  /// Parses one book source object and keeps every unrecognised key in [extra].
  /// Nested rule objects are re-parsed so their unknown keys survive too.
  factory BookSource.fromLegadoJson(Map<String, Object?> json) {
    final String? headerRule = headerRuleOf(json['header']);
    // 规则形式的 header 由 [headerRule] 承载，不进转换器。
    // 括号不能省：级联 `..remove` 的优先级低于条件表达式，否则会改掉调用方传入的 map。
    final BookSource source = _$BookSourceFromJson(
      headerRule == null
          ? json
          : (Map<String, Object?>.of(json)..remove('header')),
    );
    final Object? bookInfoJson = json['ruleBookInfo'];
    final Object? exploreJson = json['ruleExplore'];

    return source.copyWith(
      headerRule: headerRule,
      searchRule: SearchRule.fromLegadoJson(_nestedObject(json, 'ruleSearch')),
      exploreRule: exploreJson == null
          ? null
          : ExploreRule.fromLegadoJson(_nestedObject(json, 'ruleExplore')),
      bookInfoRule: bookInfoJson == null
          ? null
          : BookInfoRule.fromLegadoJson(_nestedObject(json, 'ruleBookInfo')),
      tocRule: TocRule.fromLegadoJson(_nestedObject(json, 'ruleToc')),
      contentRule: ContentRule.fromLegadoJson(
        _nestedObject(json, 'ruleContent'),
      ),
      extra: _unrecognisedKeys(json, source.toJson()),
    );
  }
}

/// Rules that parse one search result page (`ruleSearch`); every field is raw rule text,
/// and `null` means the source does not declare that field.
/// [updateTime] is display text only; [checkKeyWord] is a keyword, not a rule, and is never evaluated.
@freezed
abstract class SearchRule with _$SearchRule {
  /// Creates a search rule set.
  const factory SearchRule({
    String? bookList,
    String? name,
    String? author,
    String? kind,
    String? wordCount,
    String? lastChapter,
    String? intro,
    String? coverUrl,
    String? bookUrl,
    String? updateTime,
    String? checkKeyWord,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String, Object?>{})
    Map<String, Object?> extra,
  }) = _SearchRule;

  /// Parses one `ruleSearch` object, dropping keys the model does not know.
  factory SearchRule.fromJson(Map<String, Object?> json) =>
      _$SearchRuleFromJson(json);

  /// Parses one `ruleSearch` object and keeps every unrecognised key in [extra].
  factory SearchRule.fromLegadoJson(Map<String, Object?> json) {
    final SearchRule rule = _$SearchRuleFromJson(json);

    return rule.copyWith(extra: _unrecognisedKeys(json, rule.toJson()));
  }
}

/// Rules that parse one explore (discover) result page (`ruleExplore`).
/// A missing object or a blank `bookList` makes the explore stage fall back to [BookSource.searchRule].
@freezed
abstract class ExploreRule with _$ExploreRule {
  /// Creates an explore rule set.
  const factory ExploreRule({
    String? bookList,
    String? name,
    String? author,
    String? kind,
    String? wordCount,
    String? lastChapter,
    String? intro,
    String? coverUrl,
    String? bookUrl,
    String? updateTime,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String, Object?>{})
    Map<String, Object?> extra,
  }) = _ExploreRule;

  /// Parses one `ruleExplore` object, dropping keys the model does not know.
  factory ExploreRule.fromJson(Map<String, Object?> json) =>
      _$ExploreRuleFromJson(json);

  /// Parses one `ruleExplore` object and keeps every unrecognised key in [extra].
  factory ExploreRule.fromLegadoJson(Map<String, Object?> json) {
    final ExploreRule rule = _$ExploreRuleFromJson(json);

    return rule.copyWith(extra: _unrecognisedKeys(json, rule.toJson()));
  }
}

/// Rules that parse the book detail page (`ruleBookInfo`); the whole object may be absent,
/// in which case the search page supplies the fields it already returned.
/// [canReName] is only checked for being non-blank and is never evaluated as a rule.
@freezed
abstract class BookInfoRule with _$BookInfoRule {
  /// Creates a book info rule set.
  const factory BookInfoRule({
    String? init,
    String? name,
    String? author,
    String? kind,
    String? lastChapter,
    String? intro,
    String? coverUrl,
    String? tocUrl,
    String? wordCount,
    String? updateTime,
    String? canReName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String, Object?>{})
    Map<String, Object?> extra,
  }) = _BookInfoRule;

  /// Parses one `ruleBookInfo` object, dropping keys the model does not know.
  factory BookInfoRule.fromJson(Map<String, Object?> json) =>
      _$BookInfoRuleFromJson(json);

  /// Parses one `ruleBookInfo` object and keeps every unrecognised key in
  /// [extra].
  factory BookInfoRule.fromLegadoJson(Map<String, Object?> json) {
    final BookInfoRule rule = _$BookInfoRuleFromJson(json);

    return rule.copyWith(extra: _unrecognisedKeys(json, rule.toJson()));
  }
}

/// Rules that parse the table of contents (`ruleToc`).
/// [isVip] marks paid chapters; [nextTocUrl] names the page(s) that continue the list.
@freezed
abstract class TocRule with _$TocRule {
  /// Creates a table of contents rule set.
  const factory TocRule({
    String? chapterList,
    String? chapterName,
    String? chapterUrl,
    String? isVip,
    String? updateTime,
    String? nextTocUrl,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String, Object?>{})
    Map<String, Object?> extra,
  }) = _TocRule;

  /// Parses one `ruleToc` object, dropping keys the model does not know.
  factory TocRule.fromJson(Map<String, Object?> json) =>
      _$TocRuleFromJson(json);

  /// Parses one `ruleToc` object and keeps every unrecognised key in [extra].
  factory TocRule.fromLegadoJson(Map<String, Object?> json) {
    final TocRule rule = _$TocRuleFromJson(json);

    return rule.copyWith(extra: _unrecognisedKeys(json, rule.toJson()));
  }
}

/// Rules that parse the chapter body (`ruleContent`).
/// [nextContentUrl] continues the body; [replaceRegex] is a standalone `##regex##replacement`
/// applied to the joined text after every page has been read.
@freezed
abstract class ContentRule with _$ContentRule {
  /// Creates a content rule set.
  const factory ContentRule({
    String? content,
    String? nextContentUrl,
    String? replaceRegex,

    /// A regex that cuts the wanted payload out of the **raw** page before the rules run
    /// (`docs/dev/roadmap.md` M21a, ADR-0068 §决策 7).
    String? sourceRegex,

    /// A script evaluated **inside a WebView** after the page loaded; its result is the body
    /// (`webJs`, ADR-0068 §决策 6/7).
    String? webJs,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String, Object?>{})
    Map<String, Object?> extra,
  }) = _ContentRule;

  /// Parses one `ruleContent` object, dropping keys the model does not know.
  factory ContentRule.fromJson(Map<String, Object?> json) =>
      _$ContentRuleFromJson(json);

  /// Parses one `ruleContent` object and keeps every unrecognised key in [extra].
  factory ContentRule.fromLegadoJson(Map<String, Object?> json) {
    final ContentRule rule = _$ContentRuleFromJson(json);

    return rule.copyWith(extra: _unrecognisedKeys(json, rule.toJson()));
  }
}

// 把 Legado 的 header 字段（JSON 字符串或对象）转成请求头 map；空字符串与缺失都算「无额外头」。
final class _HeaderJsonConverter
    implements JsonConverter<Map<String, String>?, Object?> {
  const _HeaderJsonConverter();

  @override
  Map<String, String>? fromJson(Object? json) => switch (json) {
    null => null,
    // 规则形式的 header（`@js:` / `<js>`）不是 JSON，由 [BookSource.headerRule] 承载。
    final String raw when headerRuleOf(raw) != null => null,
    final String raw => _parseHeaderString(raw),
    final Map<Object?, Object?> raw => _toStringMap(raw),
    _ => throw FormatException(
      'The Legado "header" field must be a JSON string or an object, '
      'but was ${json.runtimeType}.',
    ),
  };

  @override
  Object? toJson(Map<String, String>? object) =>
      object == null ? null : jsonEncode(object);
}

/// The rule a source wrote in its `header` field, or `null` when it is a JSON object.
String? headerRuleOf(Object? header) {
  if (header is! String) {
    return null;
  }
  final String trimmed = header.trim();

  return trimmed.toLowerCase().startsWith('@js:') ||
          trimmed.toLowerCase().startsWith('<js>')
      ? trimmed
      : null;
}

// 解码 header 字符串；仅在文本完全没有双引号时容忍单引号对象，其余格式错误照常抛出。
Object? _decodeHeaderObject(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    if (raw.contains('"')) {
      rethrow;
    }

    return jsonDecode(raw.replaceAll("'", '"'));
  }
}

Map<String, String>? _parseHeaderString(String raw) {
  if (raw.trim().isEmpty) {
    return null;
  }

  final Object? decoded = _decodeHeaderObject(raw);
  if (decoded is! Map<Object?, Object?>) {
    throw FormatException(
      'The Legado "header" string must decode to a JSON object, '
      'but decoded to ${decoded.runtimeType}.',
    );
  }

  return _toStringMap(decoded);
}

Map<String, String> _toStringMap(Map<Object?, Object?> raw) {
  final Map<String, String> headers = <String, String>{};

  for (final MapEntry<Object?, Object?> entry in raw.entries) {
    final Object? key = entry.key;
    final Object? value = entry.value;
    if (key is! String || value is! String) {
      throw FormatException(
        'Legado header entries must be string pairs, but got '
        '${key.runtimeType}: ${value.runtimeType}.',
      );
    }
    headers[key] = value;
  }

  return headers;
}

/// The sandbox view of a book source; only `name`, `url` and `group` are exposed.
extension BookSourceJsView on BookSource {
  /// The read-only object the sandbox receives as `source`.
  JsSourceInfo get jsSourceInfo =>
      JsSourceInfo(name: name, url: url, group: group);
}

// 用序列化后的 Legado 键名比对，才能正确判断哪些键未被建模。
Map<String, Object?> _unrecognisedKeys(
  Map<String, Object?> json,
  Map<String, Object?> known,
) => <String, Object?>{
  for (final MapEntry<String, Object?> entry in json.entries)
    if (!known.containsKey(entry.key)) entry.key: entry.value,
};

// 调用方已校验该键存在且是对象，故用 as 而非 !（禁止空断言）。
Map<String, Object?> _nestedObject(Map<String, Object?> json, String key) =>
    Map<String, Object?>.from(json[key] as Map<Object?, Object?>);
