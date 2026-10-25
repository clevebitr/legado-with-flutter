import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';

/// What one edit of a stored source did.
enum BookSourceEditOutcome {
  /// The row was rewritten.
  saved,

  /// Another row already has this `(url, fingerprint)`: the edit was not applied.
  identityConflict,

  /// The row is gone (deleted while the editor was open).
  sourceMissing,
}

/// Persistence for the imported book sources.
/// Total: a stored payload that no longer parses is skipped with a warning by the adapter, while
/// unexpected storage failures travel as exceptions to the presentation Notifier.
abstract interface class BookSourceRepository {
  /// Every stored source, in the list and default-pick order.
  /// [order] is the key the user picked; the fixed tie-breakers are the DAO's business.
  Future<List<StoredBookSource>> getAll({
    BookSourceSortOrder order = BookSourceSortOrder.defaultOrder,
    bool ascending = true,
  });

  /// The newest recorded verdict per source, keyed by `book_sources.id`.
  /// Cancelled runs are left out, so a source whose only runs were cancelled stays never checked.
  Future<Map<int, SourceCheckRecord>> latestChecks();

  /// Rewrites the manual order following [orderedIds].
  /// The whole list is renumbered `0..n-1` in one transaction.
  Future<void> reorder(List<int> orderedIds);

  /// The stored source with [id], or `null` when it was deleted meanwhile.
  Future<StoredBookSource?> findById(int id);

  /// Whether `(url, fingerprint)` is already stored.
  /// The import preview uses it to label an entry new or refresh; `saveAll` decides again.
  Future<bool> exists({required String url, required String fingerprint});

  /// Stores the raw imported [entries] under their `(url, fingerprint)` identity.
  /// Each entry is the raw JSON object as imported, and the fingerprint is computed from it.
  Future<BookSourceSaveReport> saveAll(List<Map<String, Object?>> entries);

  /// Enables or disables [id] — user state, so nothing else writes it.
  Future<void> setEnabled({required int id, required bool isEnabled});

  /// Writes what a batch check found back onto row [id].
  /// Answers `false` when the row is gone meanwhile; only the DAO columns are touched.
  Future<bool> applyCheckReport({
    required int id,
    required SourceCheckReport report,
  });

  /// Deletes [id].
  Future<void> delete(int id);

  /// The raw payload of [id] exactly as imported, or `null` when the row is gone.
  /// Export and the editor work from these bytes, so unmodelled keys survive.
  Future<String?> payloadOf(int id);

  /// The payloads of [ids] (every source when it is `null` or empty), in list order.
  ///
  /// Two keys are written over the imported values before they are answered: `enabled` from the
  /// row's user state and `customOrder` from its manual order. Everything else — including the keys
  /// this build never modelled — stays as imported, which is what makes a re-import lossless
  /// (ADR-0071 §决策 3). A row whose payload no longer parses is skipped with a warning.
  Future<List<String>> exportPayloads({Set<int>? ids});

  /// Enables or disables every id in [ids] in one transaction.
  Future<void> setEnabledFor(List<int> ids, {required bool isEnabled});

  /// Deletes every id in [ids] in one transaction.
  Future<void> deleteMany(List<int> ids);

  /// Puts every id in [ids] into [group] (`bookSourceGroup`), or clears it when [group] is `null`.
  /// It rewrites the payload and skips an unparsable one with a warning.
  Future<void> setGroupFor(List<int> ids, String? group);

  /// Enables or disables the discover page of every id in [ids] in one transaction.
  Future<void> setExploreEnabledFor(
    List<int> ids, {
    required bool isExploreEnabled,
  });

  /// Moves every id in [ids] to the top or the bottom of the manual order.
  Future<void> moveToEdge(List<int> ids, {required bool toTop});

  /// Renames [from] to [to] in every source's `bookSourceGroup`.
  /// Only the payload's user group changes; the identity stays untouched.
  Future<void> renameGroup(String from, String to);

  /// Removes [group] from every source's `bookSourceGroup`.
  Future<void> deleteGroup(String group);

  /// Removes [group] from the `bookSourceGroup` of every id in [ids].
  Future<void> removeFromGroup(List<int> ids, String group);

  /// Replaces the stored source [id] with [entry], validated by the caller.
  /// It rewrites the payload, recomputes the identity and keeps user state.
  Future<BookSourceEditOutcome> update({
    required int id,
    required Map<String, Object?> entry,
  });
}
