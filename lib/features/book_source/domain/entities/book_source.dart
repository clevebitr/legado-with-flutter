import 'dart:convert';

import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_source.freezed.dart';
part 'book_source.g.dart';

/// Kind of content a Legado book source serves (`bookSourceType`).
enum BookSourceType {
  /// Text content (Legado `bookSourceType` 0).
  @JsonValue(0)
  text,

  /// Audio content (Legado `bookSourceType` 1).
  @JsonValue(1)
  audio,

  /// Image content (Legado `bookSourceType` 2).
  @JsonValue(2)
  image,

  /// File content (Legado `bookSourceType` 3).
  @JsonValue(3)
  file,
}

/// One imported Legado book source: the rule set that drives search, book info,
/// table of contents and content parsing (C-SRC-7).
///
/// Field names follow `docs/dev/book-source.md` §2; `@JsonKey` maps them back to
/// the original Legado keys (`bookSourceName`, `ruleSearch`, ...), so an imported
/// file round-trips without a translation table.
///
/// Only the fields the implemented stages consume are modelled; the display-only
/// counters (`lastUpdateTime` / `respondTime` / `weight` / `customOrder`) arrive
/// with Phase 5 (`PLAN.md` 5.4). Everything unmodelled survives in [extra].
///
/// Import user-supplied files with [BookSource.fromLegadoJson]: it is the only
/// entry point that keeps unrecognised keys, so a later export cannot lose data.
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
    String? searchUrl,
    @JsonKey(name: 'ruleSearch') required SearchRule searchRule,
    @JsonKey(name: 'ruleExplore') ExploreRule? exploreRule,
    @JsonKey(name: 'ruleBookInfo') BookInfoRule? bookInfoRule,
    @JsonKey(name: 'ruleToc') required TocRule tocRule,
    @JsonKey(name: 'ruleContent') required ContentRule contentRule,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String, Object?>{})
    Map<String, Object?> extra,
  }) = _BookSource;

  /// Parses one book source object, dropping keys the model does not know.
  ///
  /// Prefer [BookSource.fromLegadoJson] for imported files; this factory exists
  /// because C-SRC-7 requires the generated mapping to stay the single
  /// implementation of the field mapping.
  factory BookSource.fromJson(Map<String, Object?> json) =>
      _$BookSourceFromJson(json);

  /// Parses one book source object and keeps every unrecognised key in [extra].
  ///
  /// The nested rule objects are parsed a second time through their own
  /// `fromLegadoJson`: the generated mapping would parse them with their plain
  /// `fromJson` and drop *their* unrecognised keys. The first parse still owns
  /// validation (a malformed or missing rule object throws there), and importing
  /// happens once per file, so the repeated parse is irrelevant next to keeping
  /// the retention rule in one obvious place.
  factory BookSource.fromLegadoJson(Map<String, Object?> json) {
    final BookSource source = _$BookSourceFromJson(json);
    final Object? bookInfoJson = json['ruleBookInfo'];
    final Object? exploreJson = json['ruleExplore'];

    return source.copyWith(
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

/// Rules that parse one search result page (`ruleSearch`).
///
/// Every field holds the raw Legado rule text; the `RuleEngine` compiles it
/// (`docs/dev/book-source.md` §3). `null` means the source does not declare that
/// field, which is different from declaring an empty rule.
///
/// [updateTime] is a **display** string: the rule's result is kept as it was read and never
/// parsed as a date (`docs/dev/book-source.md` §2); a chapter rule may produce it through
/// `java.timeFormat` (§6).
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
///
/// Upstream fixes the shape of a list rule in its `BookListRule` interface
/// (`BookListRule.kt:6-18`), so this object carries exactly the fields [SearchRule] carries
/// for the nine list fields — the two must grow and shrink in the same batch
/// (`docs/dev/book-source.md` §2, ADR-0035 §决策 1). There is no `checkKeyWord` here:
/// upstream declares that one on the search rule alone.
///
/// A source may omit the object, or declare it with a blank `bookList`: the explore stage then
/// falls back to the **whole** [BookSource.searchRule] (ADR-0035 §决策 2, `book-source.md`
/// §4.2). The fallback itself belongs to the explore use case, not to this model.
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

/// Rules that parse the book detail page (`ruleBookInfo`).
///
/// Legado allows the whole object to be absent: the search page then supplies
/// the fields it already returned (`docs/dev/book-source.md` §2).
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
///
/// [isVip] marks the chapters a source sells, and [nextTocUrl] names the page(s)
/// that continue the list; both are rule text, evaluated by the use case
/// (`docs/dev/book-source.md` §4.1).
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
///
/// [nextContentUrl] names the page(s) that continue one chapter's body, and
/// [replaceRegex] is a **standalone** `##regex##replacement` rule applied to the
/// joined text after every page has been read (`docs/dev/book-source.md` §4.1).
@freezed
abstract class ContentRule with _$ContentRule {
  /// Creates a content rule set.
  const factory ContentRule({
    String? content,
    String? nextContentUrl,
    String? replaceRegex,
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

/// Converts the Legado `header` field into a request-header map.
///
/// Legado stores headers as a **JSON string** (`"{\"User-Agent\":\"...\"}"`), and
/// some sources already ship an object; an empty string and an absent key both
/// mean "no extra headers", which is why the result stays nullable instead of
/// defaulting to an empty map.
///
/// Anything that is neither an object nor a JSON string of one, and any entry
/// whose key or value is not a string, throws [FormatException] instead of being
/// silently dropped: the import layer maps that onto
/// `ParseFailureKind.invalidBookSource` (`docs/dev/book-source.md` §7).
final class _HeaderJsonConverter
    implements JsonConverter<Map<String, String>?, Object?> {
  const _HeaderJsonConverter();

  @override
  Map<String, String>? fromJson(Object? json) => switch (json) {
    null => null,
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

/// Parses a `header` JSON string, or returns `null` when it declares nothing.
Map<String, String>? _parseHeaderString(String raw) {
  if (raw.trim().isEmpty) {
    return null;
  }

  final Object? decoded = jsonDecode(raw);
  if (decoded is! Map<Object?, Object?>) {
    throw FormatException(
      'The Legado "header" string must decode to a JSON object, '
      'but decoded to ${decoded.runtimeType}.',
    );
  }

  return _toStringMap(decoded);
}

/// Copies [raw] into a `Map<String, String>`, rejecting non-string entries.
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

/// The sandbox view of a book source (`docs/dev/book-source.md` §6).
///
/// The whitelist exposes `name` / `url` / `group` only, so the mapping lives next to the model
/// instead of being rebuilt by every use case that has to fill a [JsJob].
extension BookSourceJsView on BookSource {
  /// The read-only object the sandbox receives as `source`.
  JsSourceInfo get jsSourceInfo =>
      JsSourceInfo(name: name, url: url, group: group);
}

/// Returns the entries of [json] that [known] does not describe.
///
/// The comparison uses the **serialised** keys (`bookSourceName` and friends)
/// rather than the Dart field names, because only `toJson` reproduces the keys of
/// a Legado file (`docs/dev/book-source.md` §2).
Map<String, Object?> _unrecognisedKeys(
  Map<String, Object?> json,
  Map<String, Object?> known,
) => <String, Object?>{
  for (final MapEntry<String, Object?> entry in json.entries)
    if (!known.containsKey(entry.key)) entry.key: entry.value,
};

/// Returns the nested JSON object stored under [key] of a book source file.
///
/// Every call site sits behind `_$BookSourceFromJson`, which has already
/// validated that [key] exists and holds an object, so the explicit conversion
/// cannot fail; it is written as `as` instead of `!` because C-TYPE-2 forbids the
/// null-assertion operator.
Map<String, Object?> _nestedObject(Map<String, Object?> json, String key) =>
    Map<String, Object?>.from(json[key] as Map<Object?, Object?>);
