import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/utils/clock.dart';

/// The time **one book source** may take for one operation (`docs/dev/roadmap.md` §3.7-B7).
///
/// Two batches already have such a number and used to spell it out themselves: the aggregate
/// search waits 60 s per source (ADR-0046 §决策 5) and the source check 180 s per source
/// (ADR-0043). Both mean the same thing — "this source has had its turn, move on with the
/// others" — and both had their own `.timeout(...)` wrapper, so a third caller would have
/// written a third one.
///
/// The budget is **cooperative and one-way**: it never cancels a request that is in flight
/// (the HTTP layer has no cancellation primitive, the same reason pause/cancel are cooperative
/// there), it only stops *waiting*. The abandoned request finishes on its own policy timeout,
/// which is what the checks already document (ADR-0043 §后果).
///
/// The clock is injected so a test spends a budget by moving time instead of sleeping
/// (`docs/dev/testing.md` §8).
final class SourceBudget {
  /// Starts a budget of [limit] from "now".
  SourceBudget(this.limit, {Clock clock = const SystemClock()})
    : _clock = clock,
      _started = clock.now();

  /// How long the source has in total.
  final Duration limit;

  final Clock _clock;
  final DateTime _started;

  /// How much of the budget is left; never negative.
  ///
  /// It is computed from the clock on every read, so a stage that spent its time leaves the rest
  /// of the chain with the remainder instead of with a fresh [limit].
  Duration get remaining {
    final Duration left = _started.add(limit).difference(_clock.now());

    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the budget is spent.
  bool get isExpired => remaining <= Duration.zero;

  /// Runs [operation] while the budget lasts and answers its result.
  ///
  /// Running out of budget is [ParseFailureKind.networkTimeout] carrying [rulePath] — the same
  /// kind the two batches recorded before, because "we stopped waiting" is what a user sees as a
  /// timeout (the taxonomy has no closer bucket, `book-source.md` §7).
  ///
  /// A failure of [operation] is returned as it is: the budget only decides **how long**, never
  /// **whether**.
  Future<ParseResult<T>> run<T>(
    Future<ParseResult<T>> Function() operation, {
    required String rulePath,
  }) async {
    if (isExpired) {
      return failureAt<T>(
        kind: ParseFailureKind.networkTimeout,
        rulePath: rulePath,
      );
    }

    try {
      return await operation().timeout(remaining);
    } on TimeoutException {
      return failureAt<T>(
        kind: ParseFailureKind.networkTimeout,
        rulePath: rulePath,
      );
    }
  }
}
