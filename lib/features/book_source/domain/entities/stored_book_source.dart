import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';

/// One imported book source as it is stored (`PLAN.md` 5.1, ADR-0040).
///
/// It pairs the parsed [source] — what the engine consumes — with the columns the user can
/// change, so a caller never has to read the user state back out of the payload: `enabled` and
/// `customOrder` are columns, and an import never overwrites them (ADR-0040 §决策 3).
final class StoredBookSource {
  /// Creates a stored source.
  const StoredBookSource({
    required this.id,
    required this.source,
    required this.isEnabled,
    required this.customOrder,
    required this.importedAt,
  });

  /// The synthetic primary key; stable across re-imports, which is what lets the UI hold on to
  /// "the current source" (ADR-0040 §决策 1).
  final int id;

  /// The parsed book source, with [BookSource.isEnabled] already copied onto it and the row's
  /// own `customOrder` alongside (the model has no such field, `PLAN.md` 5.5 owns its display).
  final BookSource source;

  /// Whether the source takes part in search and explore.
  final bool isEnabled;

  /// The manual sort order the user gave it.
  final int customOrder;

  /// When the row was first imported.
  final DateTime importedAt;
}

/// What one `BookSourceRepository.saveAll` call did (ADR-0040 §决策 3).
///
/// `inserted + refreshed` is what the import summary reports as "imported"; the split is kept
/// because a re-import that only refreshed is not a new source for the user.
final class BookSourceSaveReport {
  /// Creates a save report.
  const BookSourceSaveReport({required this.inserted, required this.refreshed});

  /// How many entries were new identities.
  final int inserted;

  /// How many entries were the same identity as a stored row and only refreshed its payload.
  final int refreshed;
}
