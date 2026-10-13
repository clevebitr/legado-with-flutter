import 'dart:async';

import 'package:flutter_reader/core/network/concurrent_rate.dart';
import 'package:flutter_reader/core/utils/clock.dart';

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
/// It holds **two gates** for one key (ADR-0036 §决策 3): the **rate** gate a source declares
/// through `concurrentRate` ([applyRate]), and the **concurrency** gate of
/// [maxConcurrent]. They are dimensionally different — requests per window versus requests in
/// flight — and a request has to pass both. The order is fixed: the rate permit is taken
/// **before** the slot, because a request that waited while holding a slot would keep the
/// three slots busy with waiters and stall the whole source.
///
/// A caller over either gate **waits** instead of failing — C-SRC-9 requires the parsing
/// path to be safe to call concurrently, so “busy” is not an acceptable answer. Waiters are
/// served in call order, so a batch of chapter downloads reaches the site in the order it was
/// asked for.
///
/// The limiter holds no timer and no isolate: it is two counters (plus the rate window's
/// recent permits) and a FIFO of completers, which is what keeps it usable from `core/`
/// without a dependency on Flutter or the platform (C-ARCH-7). Time comes from an injected
/// [Clock] and waiting from an injected delay, so a unit test can move time instead of
/// waiting for it (`docs/dev/testing.md` §4).
final class RequestLimiter {
  /// Creates a limiter that lets [maxConcurrent] requests per key run at once.
  RequestLimiter({
    required this.maxConcurrent,
    Clock? clock,
    Future<void> Function(Duration duration)? delay,
  }) : assert(maxConcurrent > 0, 'A concurrency budget must be positive.'),
       _clock = clock ?? const SystemClock(),
       _delay = delay ?? _wait;

  /// How many requests one key may have in flight.
  final int maxConcurrent;

  final Clock _clock;

  /// Waits for the requested duration; injected so a test never sleeps for real.
  final Future<void> Function(Duration duration) _delay;

  final Map<String, int> _inFlight = <String, int>{};
  final Map<String, List<Completer<void>>> _waiting =
      <String, List<Completer<void>>>{};

  /// The rate gate each key declares, or nothing when the key is not rate limited.
  final Map<String, ConcurrentRate> _rates = <String, ConcurrentRate>{};

  /// Times (milliseconds since the epoch) of the permits granted to each key inside its
  /// current window, oldest first, at most `times` of them.
  final Map<String, List<int>> _permits = <String, List<int>>{};

  /// Registers the rate gate [key] declares (`book-source.md` §8, ADR-0036).
  ///
  /// `null` means the source declares none (absent / blank / `"0"`), so the key is not rate
  /// limited — the concurrency gate still applies. Registering the **same** declaration again
  /// is a no-op on purpose: a use case re-applies a source's declaration on every operation,
  /// and resetting the window there would let a batch of chapter downloads start over
  /// whenever the next stage began.
  void applyRate(String key, ConcurrentRate? rate) {
    if (rate == null) {
      _rates.remove(key);
      _permits.remove(key);

      return;
    }
    if (_rates[key] == rate) {
      return;
    }

    _rates[key] = rate;
    // 声明变了（M1 只会读到同一个模型值）：从头计窗，不把旧声明的许可带进新窗口。
    _permits.remove(key);
  }

  /// Runs [action] once [key] has a rate permit **and** a free slot, and frees the slot
  /// afterwards.
  ///
  /// The slot is released even when [action] throws, so one broken request cannot
  /// shrink the budget for the rest of the session; a rate permit is spent by the request
  /// itself and is never given back (a request that reached the site counted).
  Future<T> run<T>(String key, Future<T> Function() action) async {
    await _acquireRate(key);
    await _acquireSlot(key);
    try {
      return await action();
    } finally {
      _releaseSlot(key);
    }
  }

  /// Waits until [key]'s rate window has room, then spends one permit.
  ///
  /// The window is **sliding**: the last `times` permits must all be older than the interval,
  /// which is what makes `n/m` mean “at most `n` in any `m` milliseconds”. Upstream instead
  /// resets a fixed window once it expires (`ConcurrentRateLimiter.kt:88-108`), which lets a
  /// burst of `n` sit at the end of one window and another `n` at the start of the next; the
  /// stricter reading is the one ADR-0036 §决策 3 prescribes and `book-source.md` §8 states
  /// (registered there as a deliberate difference).
  Future<void> _acquireRate(String key) async {
    final ConcurrentRate? rate = _rates[key];
    if (rate == null) {
      return;
    }

    final List<int> permits = _permits.putIfAbsent(key, () => <int>[]);
    while (true) {
      final int now = _clock.now().millisecondsSinceEpoch;
      if (permits.length < rate.times) {
        permits.add(now);

        return;
      }

      final int wait = permits.first + rate.intervalMilliseconds - now;
      if (wait <= 0) {
        permits.removeAt(0);
        permits.add(now);

        return;
      }

      // 这里**不** await 别的许可：下面重新读一次时间，所以同一个窗口里同时醒来的多个
      // 调用者会被逐个排进后续窗口，而不是一起放行。
      await _delay(Duration(milliseconds: wait));
    }
  }

  /// Takes a slot for [key], or queues until a running request hands one over.
  Future<void> _acquireSlot(String key) {
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
  void _releaseSlot(String key) {
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

/// The default way the limiter waits for a rate window: real time.
///
/// It is a top-level function so [RequestLimiter]'s constructor can keep a `const`-able
/// default while a test passes its own; the unit tests never sleep
/// (`docs/dev/testing.md` §4).
Future<void> _wait(Duration duration) => Future<void>.delayed(duration);
