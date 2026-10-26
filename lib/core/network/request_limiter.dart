import 'dart:async';

import 'package:flutter_reader/core/network/concurrent_rate.dart';
import 'package:flutter_reader/core/utils/clock.dart';

/// Requests one book source may have in flight at once.
const int defaultMaxConcurrentRequestsPerSource = 3;

/// Caps how many requests one key may have in flight, queueing the rest in order.
/// A request must also pass the rate gate registered by [applyRate].
final class RequestLimiter {
  /// Creates a limiter that lets [maxConcurrent] requests per key run at once.
  RequestLimiter({
    required this.maxConcurrent,
    Clock? clock,
    Future<void> Function(Duration duration)? delay,
  }) : assert(maxConcurrent > 0, 'A concurrency budget must be positive.'),
       _clock = clock ?? const SystemClock(),
       _delay = delay ?? Future<void>.delayed;

  /// How many requests one key may have in flight.
  final int maxConcurrent;

  final Clock _clock;

  // 等待可注入，测试无需真的睡过去。
  final Future<void> Function(Duration duration) _delay;

  final Map<String, int> _inFlight = <String, int>{};
  final Map<String, List<Completer<void>>> _waiting =
      <String, List<Completer<void>>>{};

  // key 声明的速率闸门，没有则不参与速率限制。
  final Map<String, ConcurrentRate> _rates = <String, ConcurrentRate>{};

  // 当前窗口内已发放的许可时间戳，最旧的在前。
  final Map<String, List<int>> _permits = <String, List<int>>{};

  /// Registers the rate gate [key] declares; `null` means none.
  ///
  /// Registering the same declaration again is a no-op so the window is not reset.
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
    _permits.remove(key);
  }

  /// Runs [action] once [key] has a rate permit and a free slot.
  ///
  /// The slot is released even when [action] throws; a rate permit is never given back.
  Future<T> run<T>(String key, Future<T> Function() action) async {
    await _acquireRate(key);
    await _acquireSlot(key);
    try {
      return await action();
    } finally {
      _releaseSlot(key);
    }
  }

  // 滑动窗口：最近 times 次许可都必须早于一个 interval。
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

      await _delay(Duration(milliseconds: wait));
    }
  }

  Future<void> _acquireSlot(String key) {
    final int active = _inFlight[key] ?? 0;
    if (active < maxConcurrent) {
      _inFlight[key] = active + 1;

      return Future<void>.value();
    }

    final Completer<void> waiter = Completer<void>();
    (_waiting[key] ??= <Completer<void>>[]).add(waiter);

    return waiter.future;
  }

  // 空出的槽位先交给最早的等待者。
  void _releaseSlot(String key) {
    final List<Completer<void>>? queue = _waiting[key];
    if (queue != null && queue.isNotEmpty) {
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
