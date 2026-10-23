import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';

/// One recorded check of one book source (`docs/dev/roadmap.md` §3.10 V1, ADR-0052 §决策 1).
///
/// It is a **projection of the `source_checks` row**, not a second verdict model: [status],
/// [invalidGroups], [errorComment] and [elapsedMillis] are exactly what [SourceCheckReport] carried
/// when the run was written back, so the history and the source's columns can never tell two
/// different stories about the same run.
///
/// [checkedAt] comes from the injected clock, which is what makes "上次校验 2 分钟前" testable
/// (`docs/dev/testing.md` §4).
final class SourceCheckRecord {
  /// Creates one record.
  const SourceCheckRecord({
    required this.sourceId,
    required this.checkedAt,
    required this.status,
    required this.elapsedMillis,
    this.invalidGroups = const <String>[],
    this.errorComment,
  });

  /// The `book_sources.id` the run belongs to.
  final int sourceId;

  /// When the run finished.
  final DateTime checkedAt;

  /// The verdict: `succeeded`, `failed` or `cancelled`.
  final SourceCheckStatus status;

  /// How long the run took.
  final int elapsedMillis;

  /// The failure group tokens the run wrote (`source_check_group.dart` owns the vocabulary).
  final List<String> invalidGroups;

  /// The error note the run wrote, or `null` when healthy.
  final String? errorComment;
}
