import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';

/// Persistence for the imported book sources (`docs/dev/roadmap.md` 5.1, ADR-0040).
///
/// The port is **total**, in the same sense `CacheDao` is (ADR-0033 §决策 1): every method
/// answers with data, and the only expected "failure" — a stored payload that no longer parses —
/// is absorbed by the adapter (the row is skipped with a warning) instead of turning the source
/// list into an error screen. Unexpected storage failures therefore travel as exceptions to the
/// `presentation` Notifier, which is the one layer C-ERR-2 allows to catch `Exception` and turn it
/// into a failure state.
///
/// The interface lives in `domain/` and the implementation in `data/` (C-NET-8), and the
/// implementation consumes the `domain/` model directly — the review note in ADR-0021 confirms
/// there is no second, DTO-shaped model.
abstract interface class BookSourceRepository {
  /// Every stored source, in the order the list and the default pick use
  /// (`BookSourceDao.findAll`).
  ///
  /// [order] is the key the user picked on the list (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 2);
  /// the fixed tie-breakers behind it are the DAO's business, not the caller's.
  Future<List<StoredBookSource>> getAll({
    BookSourceSortOrder order = BookSourceSortOrder.defaultOrder,
  });

  /// Rewrites the manual order following [orderedIds] (ADR-0045 §决策 3).
  ///
  /// The whole list is renumbered `0..n-1` in one transaction, so dragging is idempotent and a
  /// row that vanished meanwhile cannot fail the write.
  Future<void> reorder(List<int> orderedIds);

  /// The stored source with [id], or `null` when it was deleted meanwhile.
  Future<StoredBookSource?> findById(int id);

  /// Stores the raw imported [entries] under their `(url, fingerprint)` identity.
  ///
  /// Each entry is the **raw JSON object** of one book source, not a parsed model: the payload
  /// column stores it as it came (ADR-0040 §决策 4), and the fingerprint is computed from the
  /// same map, so the stored bytes and the identity can never disagree.
  ///
  /// The caller has already rejected the entries it cannot accept
  /// (`ImportBookSources`); this method only decides insert-versus-refresh.
  Future<BookSourceSaveReport> saveAll(List<Map<String, Object?>> entries);

  /// Enables or disables [id] — user state, so nothing else writes it.
  Future<void> setEnabled({required int id, required bool isEnabled});

  /// Writes what a batch check found back onto row [id] (`docs/dev/roadmap.md` §5.10).
  ///
  /// The merge rules are the domain's ([report] carries the groups and the note the run produced;
  /// `source_check_group.dart` decides what replaces what), and this method only persists the
  /// result. It answers `false` when the row is gone meanwhile, which the caller reports as
  /// [SourceCheckFailure.sourceMissing] rather than as an exception — a source deleted while a
  /// batch is running is an expected race, not a crash (ADR-0043 §决策 1).
  Future<bool> applyCheckReport({
    required int id,
    required SourceCheckReport report,
  });

  /// Deletes [id].
  Future<void> delete(int id);
}
