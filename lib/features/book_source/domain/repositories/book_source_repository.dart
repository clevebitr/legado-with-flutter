import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';

/// Persistence for the imported book sources (`PLAN.md` 5.1, ADR-0040).
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
  Future<List<StoredBookSource>> getAll();

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

  /// Deletes [id].
  Future<void> delete(int id);
}
