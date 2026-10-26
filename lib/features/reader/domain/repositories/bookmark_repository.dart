// coverage:ignore-file
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';

/// Persistence for the reader's bookmarks (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
///
/// The port is **total** in the same sense as `ReadingProgressStore`: every read answers with data,
/// and there is no expected per-row failure — a bookmark carries no rule and no payload. Storage
/// failures travel as exceptions to the presentation Notifier, the one boundary C-ERR-2 allows to
/// catch them.
///
/// 本文件只有抽象方法签名（无可测量行），已按 ADR-0019 §2 登记在 `tool/coverage_allowlist.txt`；
/// 契约由 `BookmarkRepositoryImpl` 与其测试行使。
abstract interface class BookmarkRepository {
  /// Every bookmark across books, newest first.
  Future<List<Bookmark>> getAll();

  /// The bookmarks of one book, in chapter order.
  Future<List<Bookmark>> getForBook({
    required String sourceUrl,
    required String bookUrl,
  });

  /// Adds [draft], or removes the mark that already sits at its position, and reports which.
  ///
  /// `true` = the position is now bookmarked, `false` = it was bookmarked and no longer is. The
  /// decision lives here because the toolbar button is a toggle and the table's unique position
  /// key (ADR-0066 §决策 3) would reject a second identical add.
  Future<bool> toggle(BookmarkDraft draft);

  /// Removes bookmark [id]; an unknown id is a no-op.
  Future<void> remove(int id);
}
