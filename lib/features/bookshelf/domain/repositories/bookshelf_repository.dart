// coverage:ignore-file
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';

/// Persistence for the shelf and the reading progress (`docs/dev/roadmap.md` 5.4).
///
/// The port is **total** in the same sense as `BookSourceRepository` (ADR-0033 §决策 1):
/// every read answers with data, and there is no expected per-row failure to report — a shelf
/// row carries no rule and no payload that could have gone stale. Unexpected storage failures
/// therefore travel as exceptions to the `presentation` Notifier, the one layer C-ERR-2 lets
/// catch `Exception`.
///
/// 本文件只有抽象方法签名（无可测量行），已按 ADR-0019 §2 登记在 `tool/coverage_allowlist.txt`；
/// 契约由 `BookshelfRepositoryImpl` 与其测试行使。
abstract interface class BookshelfRepository {
  /// Every shelf entry, in the order the shelf page shows it (pinned, then recently read).
  Future<List<ShelvedBook>> getAll();

  /// Puts [candidate] on the shelf, or refreshes it when it is already there.
  ///
  /// Re-adding is a refresh of the page-derived columns only: `status` and `isPinned` are user
  /// state and stay as they are (the rule of ADR-0040 §决策 3, applied to the shelf).
  Future<void> add(ShelfCandidate candidate);

  /// Writes the two user-state columns of entry [id] in one go.
  ///
  /// They are written together because the UI toggles them from one menu and two separate
  /// writes would produce two `updatedAt` values and a visible jump in the «recently read»
  /// order.
  Future<void> updateUserState({
    required int id,
    required ShelfStatus status,
    required bool isPinned,
  });

  /// Deletes entry [id] together with its reading progress.
  Future<void> remove(int id);

  /// The stored position of `(sourceUrl, bookUrl)`, or `null` when the book was never opened.
  ///
  /// The reader needs it to **restore** a session (ADR-0044 §决策 2): without a read side, the
  /// position would have to be passed in through the route, pushing the progress semantics into
  /// every caller.
  Future<ReadingProgressPosition?> findProgress({
    required String sourceUrl,
    required String bookUrl,
  });

  /// Remembers where the reader stopped in `(sourceUrl, bookUrl)`.
  Future<void> saveProgress({
    required String sourceUrl,
    required String bookUrl,
    required String chapterUrl,
    String? chapterName,
    int charOffset = 0,
  });
}
