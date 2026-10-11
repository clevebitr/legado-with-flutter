import 'dart:convert';

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
/// Only the fields the Phase 2 vertical slice consumes are modelled; the paging
/// rules, `isVip` and the display-only counters arrive with Phase 3
/// (`PLAN.md` 2.1 and 3.5). Everything unmodelled survives in [extra].
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

    return source.copyWith(
      searchRule: SearchRule.fromLegadoJson(_nestedObject(json, 'ruleSearch')),
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
@freezed
abstract class TocRule with _$TocRule {
  /// Creates a table of contents rule set.
  const factory TocRule({
    String? chapterList,
    String? chapterName,
    String? chapterUrl,
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
@freezed
abstract class ContentRule with _$ContentRule {
  /// Creates a content rule set.
  const factory ContentRule({
    String? content,
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
