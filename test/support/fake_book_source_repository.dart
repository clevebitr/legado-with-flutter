import 'package:flutter_reader/features/book_source/domain/book_source_fingerprint.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';

/// In-memory [BookSourceRepository] double for the notifier and widget tests
/// (`docs/dev/testing.md` §4).
///
/// It keeps the three parts of the port's contract the UI depends on, so a test that passes here
/// says something about production:
///
/// * rows come back in the shared order — enabled first, then `customOrder`, then `id`
///   (ADR-0040 §决策 3);
/// * re-importing the same identity refreshes instead of adding a row, and the identity is the
///   **real** `bookSourceFingerprint`, so the double cannot invent a rule the domain does not have;
/// * `enabled` / `customOrder` are user state that an import never overwrites.
final class FakeBookSourceRepository implements BookSourceRepository {
  final Map<int, StoredBookSource> _rows = <int, StoredBookSource>{};

  /// Identity (`url|fingerprint`) to row id, the in-memory stand-in for the unique key.
  final Map<String, int> _identities = <String, int>{};

  int _nextId = 1;

  /// The timestamps new rows get; a test can pin them for an assertion.
  DateTime importedAt = DateTime.utc(2026, 10, 14);

  /// When true, [getAll] throws, so a test can pin the pages' load-failure state
  /// (a storage failure is the one thing the port lets through as an exception).
  bool failReads = false;

  /// Seeds one stored source and returns it.
  StoredBookSource add({
    required BookSource source,
    bool isEnabled = true,
    int customOrder = 0,
  }) {
    final StoredBookSource stored = StoredBookSource(
      id: _nextId++,
      source: source,
      isEnabled: isEnabled,
      customOrder: customOrder,
      importedAt: importedAt,
    );
    _rows[stored.id] = stored;

    return stored;
  }

  /// Every row, in the order the port promises.
  @override
  Future<List<StoredBookSource>> getAll() async {
    if (failReads) {
      throw Exception('stored book sources could not be read');
    }
    final List<StoredBookSource> rows = _rows.values.toList()
      ..sort((StoredBookSource a, StoredBookSource b) {
        if (a.isEnabled != b.isEnabled) {
          return a.isEnabled ? -1 : 1;
        }
        if (a.customOrder != b.customOrder) {
          return a.customOrder.compareTo(b.customOrder);
        }

        return a.id.compareTo(b.id);
      });

    return rows;
  }

  @override
  Future<StoredBookSource?> findById(int id) async => _rows[id];

  @override
  Future<BookSourceSaveReport> saveAll(
    List<Map<String, Object?>> entries,
  ) async {
    var inserted = 0;
    var refreshed = 0;

    for (final Map<String, Object?> entry in entries) {
      final String url = '${entry['bookSourceUrl']}';
      final String identity = '$url|${bookSourceFingerprint(entry)}';
      final int? existingId = _identities[identity];

      if (existingId == null) {
        final StoredBookSource stored = add(
          source: BookSource.fromLegadoJson(entry),
          isEnabled: entry['enabled'] is bool ? entry['enabled'] as bool : true,
          customOrder: entry['customOrder'] is int
              ? entry['customOrder'] as int
              : 0,
        );
        _identities[identity] = stored.id;
        inserted++;
      } else {
        // 身份相同 ⇒ 行为字段相同；只刷新时间，用户态不动（与 ADR-0040 §决策 3 一致）。
        final StoredBookSource row = _rows[existingId]!;
        _rows[existingId] = StoredBookSource(
          id: row.id,
          source: row.source,
          isEnabled: row.isEnabled,
          customOrder: row.customOrder,
          importedAt: row.importedAt,
        );
        refreshed++;
      }
    }

    return BookSourceSaveReport(inserted: inserted, refreshed: refreshed);
  }

  @override
  Future<void> setEnabled({required int id, required bool isEnabled}) async {
    final StoredBookSource? row = _rows[id];
    if (row == null) {
      return;
    }
    _rows[id] = StoredBookSource(
      id: row.id,
      source: row.source,
      isEnabled: isEnabled,
      customOrder: row.customOrder,
      importedAt: row.importedAt,
    );
  }

  @override
  Future<void> delete(int id) async {
    _rows.remove(id);
    _identities.removeWhere((String _, int rowId) => rowId == id);
  }
}
