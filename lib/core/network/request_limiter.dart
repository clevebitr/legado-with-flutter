import 'dart:async';

/// Requests one book source may have in flight at once (`book-source.md` §8).
///
/// It is what the network policy starts from (the settings phase overrides it there),
/// and the number itself is owned by §8. A batch of chapter downloads therefore cannot
/// pile an unbounded number of requests onto one site.
const int defaultMaxConcurrentRequestsPerSource = 3;

/// Caps how many requests one key may have in flight, queueing the rest in order.
///
/// `docs/dev/book-source.md` §8 fixes the budget for one book source, and ADR-0030
/// §决策 2 rules that the budget belongs to the **request layer** and is not part of
/// the `JsBridge` contract. This is that layer's mechanism: `DioHttpClient` runs every
/// wire request through one instance, keyed by book source.
///
/// A caller over the budget **waits** instead of failing — C-SRC-9 requires the parsing
/// path to be safe to call concurrently, so “busy” is not an acceptable answer. Waiters
/// are served in call order, so a batch of chapter downloads reaches the site in the
/// order it was asked for.
///
/// The limiter holds no timer and no isolate: it is a counter plus a FIFO of
/// completers, which is what keeps it usable from `domain/` without a dependency on
/// Flutter or the platform (C-ARCH-7).
final class RequestLimiter {
  /// Creates a limiter that lets [maxConcurrent] requests per key run at once.
  RequestLimiter({required this.maxConcurrent})
    : assert(maxConcurrent > 0, 'A concurrency budget must be positive.');

  /// How many requests one key may have in flight.
  final int maxConcurrent;

  final Map<String, int> _inFlight = <String, int>{};
  final Map<String, List<Completer<void>>> _waiting =
      <String, List<Completer<void>>>{};

  /// Runs [action] once [key] has a free slot, and frees the slot afterwards.
  ///
  /// The slot is released even when [action] throws, so one broken request cannot
  /// shrink the budget for the rest of the session.
  Future<T> run<T>(String key, Future<T> Function() action) async {
    await _acquire(key);
    try {
      return await action();
    } finally {
      _release(key);
    }
  }

  /// Takes a slot for [key], or queues until a running request hands one over.
  Future<void> _acquire(String key) {
    final int active = _inFlight[key] ?? 0;
    if (active < maxConcurrent) {
      _inFlight[key] = active + 1;

      return Future<void>.value();
    }

    final Completer<void> waiter = Completer<void>();
    // 队列从尾部追加、从头取出，因此是调用顺序（FIFO）；这也是「并发调用不得报 busy」
    // 的落点：超限者在这里等，而不是拿到 ParseFailure。
    (_waiting[key] ??= <Completer<void>>[]).add(waiter);

    return waiter.future;
  }

  /// Frees one slot for [key], handing it to the oldest waiter instead of idling.
  void _release(String key) {
    final List<Completer<void>>? queue = _waiting[key];
    if (queue != null && queue.isNotEmpty) {
      // 排队者**继承**这个槽位：计数既不先减也不后加，否则交接的空隙里会多放一个请求。
      queue.removeAt(0).complete();

      return;
    }

    final int active = _inFlight[key] ?? 0;
    if (active <= 1) {
      _inFlight.remove(key);
      _waiting.remove(key);

      return;
    }

    _inFlight[key] = active - 1;
  }
}
