import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// What the detail page hands to the shelf when the user adds a book.
/// Primitives only: the shelf is another feature, so this port may not name `Book` or `BookInfo`.
final class ShelfBookDraft {
  /// Creates a draft; an empty [sourceUrl] or [bookUrl] is a programming error, not a failure.
  ShelfBookDraft({
    required this.sourceUrl,
    required this.bookUrl,
    required this.name,
    this.tocUrl,
    this.canReName = false,
    this.author,
    this.kind,
    this.coverUrl,
    this.intro,
    this.lastChapter,
  }) {
    if (sourceUrl.isEmpty) {
      throw ArgumentError.value(sourceUrl, 'sourceUrl', 'must not be empty');
    }
    if (bookUrl.isEmpty) {
      throw ArgumentError.value(bookUrl, 'bookUrl', 'must not be empty');
    }
  }

  /// `bookSourceUrl` of the source the book was found through.
  final String sourceUrl;

  /// The book's detail page URL.
  final String bookUrl;

  /// The table-of-contents URL the detail stage resolved, so the shelf need not guess it.
  final String? tocUrl;

  /// Whether the source declares `ruleBookInfo.canReName`, i.e. whether an existing shelf entry's
  /// title and author may be overwritten.
  final bool canReName;

  /// The title to show on the shelf.
  final String name;

  /// The author, when the detail page carried one.
  final String? author;

  /// The category, when the detail page carried one.
  final String? kind;

  /// The cover URL, when the detail page carried one.
  final String? coverUrl;

  /// The introduction, when the detail page carried one.
  final String? intro;

  /// The latest chapter, when the detail page carried one.
  final String? lastChapter;
}

/// One shelf group the detail page can move a book into.
/// Primitives plus a name, so the shelf's own group entity does not leak into `book_source`.
final class ShelfGroupOption {
  /// Creates one group option.
  const ShelfGroupOption({required this.id, required this.name});

  /// The group's id, which is what a write takes.
  final int id;

  /// The name the sheet shows.
  final String name;
}

/// What the detail page knows about this book's shelf membership.
/// [onShelf] is false for a book the user has not added; grouping and covers are shelf state only.
final class ShelfMembership {
  /// Creates a membership snapshot.
  const ShelfMembership({
    required this.onShelf,
    this.groupId,
    this.customCoverPath,
    this.groups = const <ShelfGroupOption>[],
  });

  /// The answer for a book that is not on the shelf: no group, no cover, no options.
  static const ShelfMembership absent = ShelfMembership(onShelf: false);

  /// Whether the book has a shelf row at all.
  final bool onShelf;

  /// The group the row is in, or `null` for 「未分组」.
  final int? groupId;

  /// Absolute path of the user's own cover, or `null` when the source's cover is shown.
  final String? customCoverPath;

  /// Every group the book could be moved into.
  final List<ShelfGroupOption> groups;
}

/// The one shelf capability `book_source` needs: putting a book on the shelf.
/// It answers [ParseResult] rather than throwing, because a failure here is an ordinary outcome.
abstract interface class BookshelfWriter {
  /// Puts [draft] on the shelf, or refreshes the stored entry when it is already there.
  Future<ParseResult<void>> addToShelf(ShelfBookDraft draft);

  /// The membership of `(sourceUrl, bookUrl)`; [ShelfMembership.absent] when it has no row.
  Future<ShelfMembership> membership({
    required String sourceUrl,
    required String bookUrl,
  });

  /// Moves the shelf row of `(sourceUrl, bookUrl)` into [groupId] (`null` = 未分组).
  Future<ParseResult<void>> assignGroup({
    required String sourceUrl,
    required String bookUrl,
    required int? groupId,
  });

  /// Lets the user pick a cover and stores it for that row.
  /// A success carries the new path, or `null` when the dialog was cancelled.
  Future<ParseResult<String?>> chooseCustomCover({
    required String sourceUrl,
    required String bookUrl,
  });

  /// Goes back to the source's cover and deletes the stored file.
  Future<ParseResult<void>> resetCustomCover({
    required String sourceUrl,
    required String bookUrl,
  });
}

/// The answer when nothing bound [BookshelfWriter]: an observable failure, never a throw.
/// It is the default of `bookshelfWriterProvider`, so a forgotten binding shows a failure message.
final class UnboundBookshelfWriter implements BookshelfWriter {
  /// Creates the unbound port; the injected logger receives the warning.
  const UnboundBookshelfWriter({required this._logger});

  final AppLogger _logger;

  @override
  Future<ParseResult<void>> addToShelf(ShelfBookDraft draft) async {
    _logger.warning(
      'No BookshelfWriter is bound: the add-to-shelf action did nothing.',
    );

    return const ParseFailure<void>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'shelf.writer',
    );
  }

  @override
  Future<ShelfMembership> membership({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    // 读取侧是 total 的：未绑定端口时回答「不在书架上」，页面只是把那几个动作置灰。
    return ShelfMembership.absent;
  }

  @override
  Future<ParseResult<void>> assignGroup({
    required String sourceUrl,
    required String bookUrl,
    required int? groupId,
  }) {
    _logger.warning(
      'No BookshelfWriter is bound: the group assignment did nothing.',
    );

    return Future<ParseResult<void>>.value(
      const ParseFailure<void>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'shelf.writer.group',
      ),
    );
  }

  @override
  Future<ParseResult<String?>> chooseCustomCover({
    required String sourceUrl,
    required String bookUrl,
  }) {
    _logger.warning(
      'No BookshelfWriter is bound: choosing a cover did nothing.',
    );

    return Future<ParseResult<String?>>.value(
      const ParseSuccess<String?>(null),
    );
  }

  @override
  Future<ParseResult<void>> resetCustomCover({
    required String sourceUrl,
    required String bookUrl,
  }) {
    _logger.warning(
      'No BookshelfWriter is bound: resetting the cover did nothing.',
    );

    return Future<ParseResult<void>>.value(
      const ParseFailure<void>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'shelf.writer.cover',
      ),
    );
  }
}
