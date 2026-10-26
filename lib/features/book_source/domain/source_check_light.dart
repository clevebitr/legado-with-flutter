import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';

/// The four states the list's status light can show.
///
/// [unchecked] is not an error: a source nobody checked has no verdict.
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

/// The light of [source], from its newest non-cancelled record.
///
/// Without history, a source whose columns still carry a check note counts as failed —
/// never as a fresh pass.
SourceCheckLight sourceCheckLightOf(StoredBookSource source) {
  final SourceCheckRecord? record = source.lastCheck;
  if (record == null) {
    return _legacyColumnsFailed(source)
        ? SourceCheckLight.failed
        : SourceCheckLight.unchecked;
  }

  return switch (record.status) {
    SourceCheckStatus.succeeded => SourceCheckLight.passed,
    // 取消与进行中都不构成结论。
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

// v5 旧库没有历史记录，只能看列上残留的结论。
bool _legacyColumnsFailed(StoredBookSource source) =>
    (source.comment ?? '').isNotEmpty ||
    splitGroups(source.groupName)
        .any((String name) => checkOwnedGroups.contains(name));
