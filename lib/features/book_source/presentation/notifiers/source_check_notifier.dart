import 'dart:async';

import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_settings.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'source_check_notifier.freezed.dart';
part 'source_check_notifier.g.dart';

/// One row of the batch: the source, where its check stands and what it found.
@freezed
abstract class SourceCheckEntry with _$SourceCheckEntry {
  /// Creates one row.
  const factory SourceCheckEntry({
    /// The stored row's id, so the run can write its verdict back (`ADR-0043`).
    required int sourceId,

    /// The source's name, snapshotted because the row may be gone by the time the check ends.
    required String name,

    /// Where this source's check stands.
    required SourceCheckStatus status,

    /// Why it did not pass, when [status] is [SourceCheckStatus.failed].
    SourceCheckFailure? failure,

    /// What each stage did, in the order the run reached them.
    @Default(<SourceCheckStageOutcome>[]) List<SourceCheckStageOutcome> stages,

    /// How long the check took, which is also what `respondTime` stores.
    int? elapsedMillis,

    /// The failure of the whole call when it never produced a report (a thrown storage error).
    ParseFailureKind? failureKind,

    /// The rule path of [failureKind], when there is one.
    String? rulePath,
  }) = _SourceCheckEntry;
}

/// The whole batch: what it is doing and one row per selected source.
@freezed
abstract class SourceCheckState with _$SourceCheckState {
  /// Creates the batch state.
  const factory SourceCheckState({
    /// Whether a batch is running right now.
    @Default(false) bool isRunning,

    /// The settings the next run will use (stage switches, keyword, timeout).
    @Default(SourceCheckSettings()) SourceCheckSettings settings,

    /// One row per source of the current run, in the order the user selected them.
    @Default(<SourceCheckEntry>[]) List<SourceCheckEntry> entries,
  }) = _SourceCheckState;
}

/// Derived facts about a [SourceCheckState] the page shows.
extension SourceCheckStateX on SourceCheckState {
  /// How many sources have a terminal verdict.
  int get completed => entries
      .where(
        (SourceCheckEntry entry) =>
            entry.status != SourceCheckStatus.pending &&
            entry.status != SourceCheckStatus.running,
      )
      .length;
}

/// Runs the batch check (`docs/dev/roadmap.md` §5.10) and writes each verdict back.
///
/// The notifier owns three things the domain does not:
///
/// * **concurrency**: at most the user's per-source budget runs at once
///   (`concurrencySettingProvider`, the same number the request layer honours), because a batch of
///   ten sources must not open ten times the connections one source is allowed;
/// * **the long-task marker**: `LongRunningTask` is acquired for the whole batch and released in
///   `finally`, so Android keeps the process awake without the UI having to know about it
///   (ADR-0043 §决策 3);
/// * **write-back and its two failures**: a deleted row becomes [SourceCheckFailure.sourceMissing]
///   and a failed write becomes [SourceCheckFailure.saveFailed]; a **cancelled** report writes
///   nothing at all (ADR-0043 §后果).
///
/// It is `keepAlive` so walking to the debug console and back does not lose a running batch: a
/// check is minutes of work and must not be tied to one screen's lifetime.
@Riverpod(keepAlive: true)
class SourceCheck extends _$SourceCheck {
  TaskCancellation? _cancellation;

  @override
  SourceCheckState build() => const SourceCheckState();

  /// Replaces the settings the next run uses.
  void updateSettings(SourceCheckSettings settings) {
    if (state.isRunning) {
      return;
    }
    state = state.copyWith(settings: settings);
  }

  /// Asks the running batch to stop between stages.
  void cancel() => _cancellation?.cancel();

  /// Checks [sources] and writes every verdict back.
  ///
  /// An empty [sources] does nothing: the page decides how to say "nothing selected", and a run
  /// that reports "0 of 0 done" would look like a finished check.
  Future<void> start(List<StoredBookSource> sources) async {
    if (state.isRunning || sources.isEmpty) {
      return;
    }

    final TaskCancellation cancellation = TaskCancellation();
    _cancellation = cancellation;
    state = state.copyWith(
      isRunning: true,
      entries: <SourceCheckEntry>[
        for (final StoredBookSource source in sources)
          SourceCheckEntry(
            sourceId: source.id,
            name: source.source.name,
            status: SourceCheckStatus.pending,
          ),
      ],
    );

    final int budget = budgetOrDefault(
      ref.read(concurrencySettingProvider),
      ref.read(appLoggerProvider),
    );
    final int workers = budget < 1 ? 1 : budget;

    await ref.read(longRunningTaskProvider).acquire();
    try {
      var next = 0;
      Future<void> worker() async {
        while (true) {
          final int index = next++;
          if (index >= sources.length) {
            return;
          }
          await _check(index, sources[index], state.settings, cancellation);
        }
      }

      await Future.wait(<Future<void>>[
        for (var workerIndex = 0; workerIndex < workers; workerIndex++)
          worker(),
      ]);
    } finally {
      await ref.read(longRunningTaskProvider).release();
      _cancellation = null;
      state = state.copyWith(isRunning: false);
    }
  }

  /// Checks one source and folds its verdict into the state.
  ///
  /// The unexpected-failure boundary is deliberate: storage failures surface as exceptions (the
  /// repository port is total only where it can be), and C-ERR-2 allows exactly one `on Exception`
  /// in a presentation Notifier to turn that into a failure state instead of an unhandled error.
  Future<void> _check(
    int index,
    StoredBookSource stored,
    SourceCheckSettings settings,
    TaskCancellation cancellation,
  ) async {
    if (cancellation.isCancelled) {
      _patch(
        index,
        (SourceCheckEntry entry) =>
            entry.copyWith(status: SourceCheckStatus.cancelled),
      );

      return;
    }

    _patch(
      index,
      (SourceCheckEntry entry) =>
          entry.copyWith(status: SourceCheckStatus.running),
    );

    final ParseResult<SourceCheckReport> result;
    try {
      result = await ref
          .read(checkBookSourceProvider)
          .execute(stored.source, settings, cancellation: cancellation);
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'Book source check threw: source=${stored.source.url}',
            error,
            stackTrace,
          );
      _patch(
        index,
        (SourceCheckEntry entry) => entry.copyWith(
          status: SourceCheckStatus.failed,
          failure: SourceCheckFailure.checkFailed,
        ),
      );

      return;
    }

    switch (result) {
      case ParseFailure<SourceCheckReport>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        ref
            .read(appLoggerProvider)
            .warning(
              'Book source check could not run: source=${stored.source.url} '
              'kind=${kind.name}',
            );
        _patch(
          index,
          (SourceCheckEntry entry) => entry.copyWith(
            status: SourceCheckStatus.failed,
            failure: SourceCheckFailure.checkFailed,
            failureKind: kind,
            rulePath: rulePath,
          ),
        );
      case ParseSuccess<SourceCheckReport>(:final SourceCheckReport data):
        await _apply(index, stored, data);
    }
  }

  /// Writes [report] back and records the resulting status.
  Future<void> _apply(
    int index,
    StoredBookSource stored,
    SourceCheckReport report,
  ) async {
    if (report.status == SourceCheckStatus.cancelled) {
      // 取消不算结论：不写回，也不报失败（ADR-0043 §后果）。
      _patch(
        index,
        (SourceCheckEntry entry) => entry.copyWith(
          status: SourceCheckStatus.cancelled,
          stages: report.stages,
          elapsedMillis: report.elapsedMillis,
        ),
      );

      return;
    }

    final bool applied;
    try {
      applied = await ref
          .read(bookSourceRepositoryProvider)
          .applyCheckReport(id: stored.id, report: report);
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'Book source check result could not be saved: '
            'source=${stored.source.url}',
            error,
            stackTrace,
          );
      _patch(
        index,
        (SourceCheckEntry entry) => entry.copyWith(
          status: SourceCheckStatus.failed,
          failure: SourceCheckFailure.saveFailed,
          stages: report.stages,
          elapsedMillis: report.elapsedMillis,
        ),
      );

      return;
    }

    // 状态灯读的是列表里的投影（ADR-0052 §决策 1）：写完一条就让列表重读，而不是等用户重进。
    ref.invalidate(bookSourceListDataProvider);
    if (!applied) {
      _patch(
        index,
        (SourceCheckEntry entry) => entry.copyWith(
          status: SourceCheckStatus.failed,
          failure: SourceCheckFailure.sourceMissing,
          stages: report.stages,
          elapsedMillis: report.elapsedMillis,
        ),
      );

      return;
    }

    _patch(
      index,
      (SourceCheckEntry entry) => entry.copyWith(
        status: report.status,
        failure: report.status == SourceCheckStatus.failed
            ? SourceCheckFailure.checkFailed
            : null,
        stages: report.stages,
        elapsedMillis: report.elapsedMillis,
      ),
    );
    // 分组与注释已写进书源，列表页读的是同一批行，所以让它重新读一次（5.5 的展示会用到）。
    ref.invalidate(bookSourceListProvider);
  }

  /// Rebuilds one row, leaving the batch's own fields alone.
  void _patch(
    int index,
    SourceCheckEntry Function(SourceCheckEntry entry) update,
  ) {
    if (index >= state.entries.length) {
      return;
    }
    final List<SourceCheckEntry> entries = <SourceCheckEntry>[...state.entries];
    entries[index] = update(entries[index]);
    state = state.copyWith(entries: entries);
  }
}
