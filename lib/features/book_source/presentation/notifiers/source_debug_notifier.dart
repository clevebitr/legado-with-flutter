import 'dart:async';

import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_debug.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'source_debug_notifier.freezed.dart';
part 'source_debug_notifier.g.dart';

/// How many lines the console keeps; older ones fall off the top.
///
/// A runaway rule can report hundreds of URLs, and a `ListView` of unbounded length is a leak the
/// user never asked for — upstream caps its log the same way (`MAX_LOG_ENTRIES`).
const int maxSourceDebugEvents = 200;

/// The state of the debug console (`docs/dev/roadmap.md` §5.10).
@freezed
abstract class SourceDebugState with _$SourceDebugState {
  /// Creates the console state.
  const factory SourceDebugState({
    /// The target the next run uses.
    @Default(SourceDebugTarget.search) SourceDebugTarget target,

    /// The query the next run sends; its meaning depends on [target].
    @Default('') String query,

    /// Where the last run stands; [SourceDebugStatus.idle] until one has been started.
    @Default(SourceDebugStatus.idle) SourceDebugStatus status,

    /// The event stream, oldest first, capped at [maxSourceDebugEvents].
    @Default(<SourceDebugEvent>[]) List<SourceDebugEvent> events,
  }) = _SourceDebugState;
}

/// Drives one debug console: the target / query the user picked and the event stream of the run.
///
/// The notifier is a thin adapter on purpose — the chain itself is `RunSourceDebug` in `domain/`,
/// and every line it reports is already a typed [SourceDebugEvent]. What lives here is the state
/// machine the UI needs: which target is selected, whether a run is in flight, and the two ways a
/// run ends (its own status, or a stop the user asked for).
///
/// A stop is cooperative like the batch check's (ADR-0043 §后果): the token is set and the run
/// ends between two steps, so the console reports `cancelled` instead of a failure.
@Riverpod(keepAlive: true)
class SourceDebug extends _$SourceDebug {
  TaskCancellation? _cancellation;

  @override
  SourceDebugState build() => const SourceDebugState();

  /// Selects the target; the query is kept so switching back does not lose what was typed.
  void selectTarget(SourceDebugTarget target) {
    if (state.status == SourceDebugStatus.running) {
      return;
    }
    state = state.copyWith(target: target);
  }

  /// Replaces the query text.
  void setQuery(String query) => state = state.copyWith(query: query);

  /// Empties the event stream, keeping the selection.
  void clear() => state = state.copyWith(events: const <SourceDebugEvent>[]);

  /// Asks the running console to stop between steps.
  void stop() => _cancellation?.cancel();

  /// Runs [target] with [query] against [source] and streams its events into the state.
  ///
  /// A blank query does nothing: the page disables its run button in that case, and a run that
  /// answered "invalid" would be a failure the user did not ask for.
  Future<void> start({
    required BookSource source,
    required SourceDebugTarget target,
    required String query,
  }) async {
    if (state.status == SourceDebugStatus.running || query.trim().isEmpty) {
      return;
    }

    final TaskCancellation cancellation = TaskCancellation();
    _cancellation = cancellation;
    state = SourceDebugState(
      target: target,
      query: query,
      status: SourceDebugStatus.running,
    );

    final ParseResult<SourceDebugStatus> result;
    try {
      result = await ref
          .read(runSourceDebugProvider)
          .execute(
            source,
            target: target,
            query: query,
            onEvent: _append,
            cancellation: cancellation,
          );
    } on Exception catch (error, stackTrace) {
      // 唯一允许的兜底位置（C-ERR-2）：把异常变成失败状态并记录，而不是让页面卡在「运行中」。
      ref
          .read(appLoggerProvider)
          .error(
            'Book source debug threw: source=${source.url} '
            'target=${target.name}',
            error,
            stackTrace,
          );
      _cancellation = null;
      state = state.copyWith(status: SourceDebugStatus.failed);

      return;
    }

    _cancellation = null;
    state = state.copyWith(
      status: switch (result) {
        ParseSuccess<SourceDebugStatus>(:final SourceDebugStatus data) => data,
        ParseFailure<SourceDebugStatus>() => SourceDebugStatus.failed,
      },
    );
  }

  /// Appends one event, dropping the oldest line once the cap is reached.
  void _append(SourceDebugEvent event) {
    final List<SourceDebugEvent> events = <SourceDebugEvent>[
      ...state.events,
      event,
    ];
    state = state.copyWith(
      events: events.length > maxSourceDebugEvents
          ? events.sublist(events.length - maxSourceDebugEvents)
          : events,
    );
  }
}
