import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';

/// The four states the list's status light can show (`docs/dev/roadmap.md` §3.10 V1).
///
/// [unchecked] is not an error: a source nobody checked has no verdict, which is exactly what the
/// grey light says. The enum lives in `domain/` because two consumers share it (the row's light and
/// the list's healthy/failing filter), and colours do **not**: those are the UI's tokens
/// (ADR-0052 §决策 2).
enum SourceCheckLight {
  /// No verdict yet: never checked, or only cancelled runs.
  unchecked,

  /// The last run finished without a failure group.
  passed,

  /// The last run found a failure that is the source's own problem.
  failed,

  /// The last run failed only with `校验超时` / `js失效`: retryable or fixable elsewhere.
  degraded,
}

/// The light of [source], from its newest non-cancelled record (ADR-0052 §决策 1).
///
/// A v5 database has no history, so a source whose columns still carry a check note falls back to
/// [SourceCheckLight.failed]; the fallback is deliberately **not** "green", because that would
/// present an old, unknown verdict as a fresh pass. Any source with neither history nor a note is
/// [SourceCheckLight.unchecked].
SourceCheckLight sourceCheckLightOf(StoredBookSource source) {
  final SourceCheckRecord? record = source.lastCheck;
  if (record == null) {
    return _legacyColumnsFailed(source)
        ? SourceCheckLight.failed
        : SourceCheckLight.unchecked;
  }

  return switch (record.status) {
    SourceCheckStatus.succeeded => SourceCheckLight.passed,
    // 取消不构成结论（ADR-0052 §决策 1）：DAO 取最近一条非取消记录，这里再兜一层。
    SourceCheckStatus.cancelled => SourceCheckLight.unchecked,
    SourceCheckStatus.pending ||
    SourceCheckStatus.running => SourceCheckLight.unchecked,
    SourceCheckStatus.failed =>
      _degradedOnly(record.invalidGroups)
          ? SourceCheckLight.degraded
          : SourceCheckLight.failed,
  };
}

/// Whether [source]'s last check found something wrong.
///
/// It reads the record first and the **columns** second (ADR-0043 §决策 1, ADR-0045 §决策 1):
/// the note or a group token the check owns. The group tokens come from `source_check_group.dart`,
/// which stays their only source of truth.
bool hasCheckFailure(StoredBookSource source) {
  final SourceCheckLight light = sourceCheckLightOf(source);

  return light == SourceCheckLight.failed || light == SourceCheckLight.degraded;
}

/// Whether every group in [groups] is a retryable / fixable-elsewhere bucket.
bool _degradedOnly(List<String> groups) {
  if (groups.isEmpty) {
    return false;
  }

  return groups.every(
    (String group) => group == checkTimeoutGroup || group == jsInvalidGroup,
  );
}

/// Whether the **columns** of [source] still carry a check note or an owned failure group.
///
/// This is the v5 fallback only: it must not call [sourceCheckLightOf], which calls it when there
/// is no history (that recursion is what the first version of this file did).
bool _legacyColumnsFailed(StoredBookSource source) =>
    (source.comment ?? '').isNotEmpty ||
    splitGroups(source.groupName)
        .any((String name) => checkOwnedGroups.contains(name));
