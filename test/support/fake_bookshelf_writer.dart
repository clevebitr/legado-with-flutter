import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';

/// [BookshelfWriter] double recording every call (`docs/dev/testing.md` §4).
///
/// The detail page's M19 actions (group / cover) are asserted through **what the page asked the
/// port for**, not through a shelf row: that is what keeps `book_source` free of `bookshelf`
/// (ADR-0066 §决策 5).
final class FakeBookshelfWriter implements BookshelfWriter {
  /// Every draft handed to [addToShelf], in order.
  final List<ShelfBookDraft> drafts = <ShelfBookDraft>[];

  /// What [membership] answers; the default is 「not on the shelf」.
  ShelfMembership membershipValue = ShelfMembership.absent;

  /// What the writes answer; the default is success.
  ParseResult<void> writeResult = const ParseSuccess<void>(null);

  /// What [chooseCustomCover] answers; the default is “cancelled”.
  ParseResult<String?> coverResult = const ParseSuccess<String?>(null);

  /// The `groupId` of every [assignGroup] call, in order (`null` = 未分组).
  final List<int?> assignedGroups = <int?>[];

  /// How many times a cover was picked.
  int chooseCoverCalls = 0;

  /// How many times the cover was reset.
  int resetCoverCalls = 0;

  /// When set, every write throws it (the notifier's absorption path).
  Exception? throwOnWrite;

  @override
  Future<ParseResult<void>> addToShelf(ShelfBookDraft draft) async {
    drafts.add(draft);

    return writeResult;
  }

  @override
  Future<ShelfMembership> membership({
    required String sourceUrl,
    required String bookUrl,
  }) async => membershipValue;

  @override
  Future<ParseResult<void>> assignGroup({
    required String sourceUrl,
    required String bookUrl,
    required int? groupId,
  }) async {
    assignedGroups.add(groupId);
    final Exception? failure = throwOnWrite;
    if (failure != null) {
      throw failure;
    }

    return writeResult;
  }

  @override
  Future<ParseResult<String?>> chooseCustomCover({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    chooseCoverCalls++;
    final Exception? failure = throwOnWrite;
    if (failure != null) {
      throw failure;
    }

    return coverResult;
  }

  @override
  Future<ParseResult<void>> resetCustomCover({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    resetCoverCalls++;
    final Exception? failure = throwOnWrite;
    if (failure != null) {
      throw failure;
    }

    return writeResult;
  }
}
