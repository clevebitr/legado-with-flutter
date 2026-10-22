import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';

/// What one edit of a stored source did (ADR-0050 §决策 3).
enum BookSourceEditOutcome {
  /// The row was rewritten.
  saved,

  /// Another row already has this `(url, fingerprint)`: the edit was **not** applied.
  identityConflict,

  /// The row is gone (deleted while the editor was open).
  sourceMissing,
}

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
    bool ascending = true,
  });

  /// The newest recorded verdict per source, keyed by `book_sources.id` (`docs/dev/roadmap.md`
  /// §3.10 V1).
  ///
  /// Cancelled runs are left out: they prove nothing about the source (ADR-0043 §后果), so a
  /// source whose only runs were cancelled stays "never checked" (ADR-0052 §决策 1).
  Future<Map<int, SourceCheckRecord>> latestChecks();

  /// Rewrites the manual order following [orderedIds] (ADR-0045 §决策 3).
  ///
  /// The whole list is renumbered `0..n-1` in one transaction, so dragging is idempotent and a
  /// row that vanished meanwhile cannot fail the write.
  Future<void> reorder(List<int> orderedIds);

  /// The stored source with [id], or `null` when it was deleted meanwhile.
  Future<StoredBookSource?> findById(int id);

  /// Whether `(url, fingerprint)` is already stored (`docs/dev/roadmap.md` §3.10 V5).
  ///
  /// The import preview uses it to label an entry **new** or **refresh** before anything is
  /// written; `saveAll` then makes the same decision again, so the label is a prediction and the
  /// store stays the authority (ADR-0052 §决策 5).
  Future<bool> exists({required String url, required String fingerprint});

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

  /// The **raw payload** of [id] exactly as imported, or `null` when the row is gone
  /// (ADR-0050 §决策 4).
  ///
  /// Export and the editor both work from these bytes: a model round-trip would drop unmodelled
  /// keys and reorder the rest (`docs/dev/roadmap.md` §3.7's `extra` note).
  Future<String?> payloadOf(int id);

  /// Enables or disables every id in [ids] in one transaction (ADR-0050 §决策 2).
  ///
  /// A batch touches **user state only**, so it never invalidates the payload or the identity.
  Future<void> setEnabledFor(List<int> ids, {required bool isEnabled});

  /// Deletes every id in [ids] in one transaction (ADR-0050 §决策 2).
  ///
  /// The selection fallback (a deleted row that happened to be the current source) is the
  /// caller's, exactly as it is for a single delete (5.1).
  Future<void> deleteMany(List<int> ids);

  /// Puts every id in [ids] into [group] (`bookSourceGroup`), or clears it when [group] is `null`.
  ///
  /// It rewrites the **payload** (ADR-0050 §决策 1: the user's group lives there) and leaves the
  /// check columns alone; the fingerprint does not include the group, so the identity is unchanged.
  /// A row whose payload does not parse is skipped with a warning rather than failing the batch.
  Future<void> setGroupFor(List<int> ids, String? group);

  /// Enables or disables the discover page of every id in [ids] in one transaction
  /// (ADR-0052 §决策 3).
  Future<void> setExploreEnabledFor(
    List<int> ids, {
    required bool isExploreEnabled,
  });

  /// Moves every id in [ids] to the top or the bottom of the manual order (ADR-0052 §决策 4).
  Future<void> moveToEdge(List<int> ids, {required bool toTop});

  /// Renames [from] to [to] in every source's `bookSourceGroup` (ADR-0052 §决策 4).
  ///
  /// Only the payload's user group changes; the identity is untouched because the fingerprint does
  /// not include the group (ADR-0050 §决策 1/3).
  Future<void> renameGroup(String from, String to);

  /// Removes [group] from every source's `bookSourceGroup` (ADR-0052 §决策 4).
  Future<void> deleteGroup(String group);

  /// Removes [group] from the `bookSourceGroup` of every id in [ids] (ADR-0052 §决策 4).
  Future<void> removeFromGroup(List<int> ids, String group);

  /// Replaces the stored source [id] with [entry], validated by the caller
  /// (ADR-0050 §决策 3).
  ///
  /// It rewrites the payload, recomputes the identity and keeps user state. It answers
  /// [BookSourceEditOutcome.identityConflict] when the new `(url, fingerprint)` already belongs to
  /// **another** row — a collision is reported, never merged — and
  /// [BookSourceEditOutcome.sourceMissing] when the row vanished meanwhile.
  Future<BookSourceEditOutcome> update({
    required int id,
    required Map<String, Object?> entry,
  });
}
