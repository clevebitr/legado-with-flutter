import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'stored_book_source.freezed.dart';

/// One imported book source as it is stored (`PLAN.md` 5.1, ADR-0040).
///
/// It pairs the parsed [source] — what the engine consumes — with the columns the user can
/// change, so a caller never has to read the user state back out of the payload: `enabled` and
/// `customOrder` are columns, and an import never overwrites them (ADR-0040 §决策 3).
///
/// `@freezed` rather than a hand-written class: C-ARCH-5 asks for "`freezed`, or `final` fields
/// plus `copyWith`", and the UI will copy this value around when it flips a source on or off
/// (`PLAN.md` 5.1), so the generated `copyWith` is part of the contract rather than surplus.
@freezed
abstract class StoredBookSource with _$StoredBookSource {
  /// Creates a stored source.
  const factory StoredBookSource({
    /// The synthetic primary key; stable across re-imports, which is what lets the UI hold on
    /// to "the current source" (ADR-0040 §决策 1).
    required int id,

    /// The parsed book source, with [BookSource.isEnabled] already copied onto it and the row's
    /// own `customOrder` alongside (the model has no such field; `PLAN.md` 5.5 owns its display).
    required BookSource source,

    /// Whether the source takes part in search and explore.
    required bool isEnabled,

    /// The manual sort order the user gave it.
    required int customOrder,

    /// When the row was first imported.
    required DateTime importedAt,
  }) = _StoredBookSource;
}

/// What one `BookSourceRepository.saveAll` call did (ADR-0040 §决策 3).
///
/// `inserted + refreshed` is what an import reports as "imported"; the split is kept because a
/// re-import that only refreshed is not a new source for the user. The *skipped* count belongs to
/// the import use case, not here: the repository only ever sees entries the caller accepted.
///
/// `copyWith` is off for the same reason `ParseResult` turns it off: a report is a result value
/// nobody derives a variant of, so generating the methods would be unused API (C-BAN-1).
@Freezed(copyWith: false)
abstract class BookSourceSaveReport with _$BookSourceSaveReport {
  /// Creates a save report.
  const factory BookSourceSaveReport({
    /// How many entries were new identities.
    required int inserted,

    /// How many entries were the same identity as a stored row and only refreshed its payload.
    required int refreshed,
  }) = _BookSourceSaveReport;
}
