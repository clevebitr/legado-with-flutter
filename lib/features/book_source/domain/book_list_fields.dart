import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_rule.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// The fields one **result page** yields, whichever rule set produced it.
///
/// `SearchRule` and `ExploreRule` carry exactly these ten fields because upstream fixes the shape
/// of a list rule in one interface (`BookListRule.kt:6-18`; the constraint is written down in
/// `docs/dev/book-source.md` §2). The search and explore stages therefore read them through one
/// reader ([readBooks]) instead of two copies that could drift apart — the drift `docs/dev/roadmap.md` §6
/// warns about, and the reason the two rule types must grow together.
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

  /// The rule that reads a hit's update time — a display string, never parsed
  /// (`book-source.md` §2).
  final String? updateTime;
}

/// Reads one [Book] per item of a result page.
///
/// [listRule] is the `bookList` rule that produced the items and [fieldPrefix] the rule set it
/// belongs to (`searchRule` or `exploreRule`), so every failure and every warning points at the
/// field that really produced the value (C-SRC-8): the explore stage falls back to the **whole**
/// search rule (ADR-0035 §决策 2), and the bookkeeping has to say so.
///
/// A field whose rule matched nothing falls back to `null` (and the name to an empty string),
/// because only the URL is required to open a hit; a **rejected** optional field degrades the same
/// way with a warning (ADR-0026 §决策 2). An item without a usable URL is dropped with a warning
/// instead of failing the page (`book-source.md` §9), and [noun] names what was dropped
/// (`Search hit` / `Explore item`) so the log stays readable.
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
      // §9：单条失败不中断整页结果，只跳过它并记录。
      pages.warn('$noun without URL skipped: source=$sourceId');
      continue;
    }

    books.add(
      Book(
        name: name.dataOrNull ?? '',
        // 书籍地址同样可能带 `,{webView:…}`（真实语料常见）：保留选项原文。
        url: resolveUrlRule(url, baseUrl),
        author: author.dataOrNull,
        kind: kind.dataOrNull,
        coverUrl: resolveAbsoluteUrlOrNull(coverUrl.dataOrNull, baseUrl),
        intro: intro.dataOrNull,
        lastChapter: lastChapter.dataOrNull,
        wordCount: wordCount.dataOrNull,
        // 展示用字符串：规则结果原文，不做日期解析（book-source.md §2）。
        updateTime: updateTime.dataOrNull,
      ),
    );
  }

  return ParseSuccess<List<Book>>(books);
}
