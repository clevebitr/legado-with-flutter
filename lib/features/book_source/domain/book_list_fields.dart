import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_rule.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// The fields one result page yields, whichever rule set produced it.
///
/// `SearchRule` and `ExploreRule` share this shape, so both stages read them through one
/// reader instead of two copies that could drift apart.
final class BookListFields {
  /// Creates a field set.
  const BookListFields({
    required this.name,
    required this.author,
    required this.kind,
    required this.wordCount,
    required this.lastChapter,
    required this.intro,
    required this.coverUrl,
    required this.bookUrl,
    required this.updateTime,
  });

  /// Reads the fields of a search rule (`ruleSearch`).
  factory BookListFields.ofSearch(SearchRule rule) => BookListFields(
    name: rule.name,
    author: rule.author,
    kind: rule.kind,
    wordCount: rule.wordCount,
    lastChapter: rule.lastChapter,
    intro: rule.intro,
    coverUrl: rule.coverUrl,
    bookUrl: rule.bookUrl,
    updateTime: rule.updateTime,
  );

  /// Reads the fields of an explore rule (`ruleExplore`).
  factory BookListFields.ofExplore(ExploreRule rule) => BookListFields(
    name: rule.name,
    author: rule.author,
    kind: rule.kind,
    wordCount: rule.wordCount,
    lastChapter: rule.lastChapter,
    intro: rule.intro,
    coverUrl: rule.coverUrl,
    bookUrl: rule.bookUrl,
    updateTime: rule.updateTime,
  );

  /// The rule that reads a hit's name.
  final String? name;

  /// The rule that reads a hit's author.
  final String? author;

  /// The rule that reads a hit's categories.
  final String? kind;

  /// The rule that reads a hit's word count.
  final String? wordCount;

  /// The rule that reads a hit's newest chapter.
  final String? lastChapter;

  /// The rule that reads a hit's introduction.
  final String? intro;

  /// The rule that reads a hit's cover.
  final String? coverUrl;

  /// The rule that reads a hit's URL.
  final String? bookUrl;

  /// The rule that reads a hit's update time — a display string, never parsed.
  final String? updateTime;
}

/// Reads one [Book] per item of a result page.
///
/// [fieldPrefix] names the rule set the item came from, so every failure points at the field
/// that produced it. An item without a URL is skipped with a warning, and [noun] names what
/// was dropped so the log stays readable.
Future<ParseResult<List<Book>>> readBooks(
  PageFetchService pages,
  String? listRule,
  BookListFields fields,
  RuleScope pageScope, {
  required String baseUrl,
  required String sourceId,
  required String fieldPrefix,
  required String noun,
}) async {
  final ParseResult<List<RuleScope>> items = await pages.list(
    listRule,
    pageScope,
    '$fieldPrefix.bookList',
  );
  final List<RuleScope> scopes;
  switch (items) {
    case ParseFailure<List<RuleScope>>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ):
      return failureAt<List<Book>>(kind: kind, rulePath: rulePath);
    case ParseSuccess<List<RuleScope>>(:final List<RuleScope> data):
      scopes = data;
  }

  final List<Book> books = <Book>[];

  for (final RuleScope item in scopes) {
    final ParseResult<String?> name = await pages.field(
      fields.name,
      item,
      '$fieldPrefix.name',
      sourceId: sourceId,
    );
    final ParseResult<String?> bookUrl = await pages.field(
      fields.bookUrl,
      item,
      '$fieldPrefix.bookUrl',
      sourceId: sourceId,
    );
    final ParseResult<String?> author = await pages.field(
      fields.author,
      item,
      '$fieldPrefix.author',
      sourceId: sourceId,
    );
    final ParseResult<String?> kind = await pages.field(
      fields.kind,
      item,
      '$fieldPrefix.kind',
      sourceId: sourceId,
    );
    final ParseResult<String?> coverUrl = await pages.field(
      fields.coverUrl,
      item,
      '$fieldPrefix.coverUrl',
      sourceId: sourceId,
    );
    final ParseResult<String?> intro = await pages.field(
      fields.intro,
      item,
      '$fieldPrefix.intro',
      sourceId: sourceId,
    );
    final ParseResult<String?> lastChapter = await pages.field(
      fields.lastChapter,
      item,
      '$fieldPrefix.lastChapter',
      sourceId: sourceId,
    );
    final ParseResult<String?> wordCount = await pages.field(
      fields.wordCount,
      item,
      '$fieldPrefix.wordCount',
      sourceId: sourceId,
    );
    final ParseResult<String?> updateTime = await pages.field(
      fields.updateTime,
      item,
      '$fieldPrefix.updateTime',
      sourceId: sourceId,
    );

    final String? url = bookUrl.dataOrNull;
    if (url == null || url.isEmpty) {
      // 单条缺 URL 不中断整页结果，只跳过并记录。
      pages.warnThrottled(
        'no-url|$sourceId|$noun',
        '$noun without URL skipped: source=$sourceId',
      );
      continue;
    }

    books.add(
      Book(
        name: name.dataOrNull ?? '',
        // 书籍地址可能带 `,{webView:…}` 选项：保留原文。
        url: resolveUrlRule(url, baseUrl),
        author: author.dataOrNull,
        kind: kind.dataOrNull,
        coverUrl: resolveAbsoluteUrlOrNull(
          _coverOf(coverUrl.dataOrNull, pages, baseUrl),
          baseUrl,
        ),
        intro: intro.dataOrNull,
        lastChapter: lastChapter.dataOrNull,
        wordCount: wordCount.dataOrNull,
        // 更新时间是展示用字符串，不做日期解析。
        updateTime: updateTime.dataOrNull,
      ),
    );
  }

  return ParseSuccess<List<Book>>(books);
}

/// [value] with a `,{…}` URL-option suffix removed, or `null` when it is absent.
///
/// A cover address is a **URL rule** in the corpus (`img@src##$##,{"headers":{"Referer":…}}`), but
/// the cover loader sends no per-image headers yet, so the options are dropped with a warning
/// instead of becoming part of the address (ADR-0069 G4).
String? _coverOf(String? value, PageFetchService pages, String baseUrl) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final String clean = stripUrlOptions(value);
  if (clean != value) {
    pages.warnThrottled(
      'cover-options|$baseUrl',
      'Cover URL options dropped (covers carry no request headers): '
          'base=$baseUrl',
    );
  }

  return clean;
}
