import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/utils/clock.dart';

/// The time one book source may take for one operation.
///
/// The budget is cooperative and one-way: it never cancels a request in flight, it only
/// stops waiting. Running out is reported as [ParseFailureKind.networkTimeout].
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
  Duration get remaining {
    final Duration left = _started.add(limit).difference(_clock.now());

    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the budget is spent.
  bool get isExpired => remaining <= Duration.zero;

  /// Runs [operation] while the budget lasts and answers its result.
  ///
  /// A failure of [operation] is returned as it is: the budget decides how long, never
  /// whether.
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
