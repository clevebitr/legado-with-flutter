import 'dart:async';

import 'package:flutter_reader/core/network/concurrent_rate.dart';
import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

void main() {
  group('RequestLimiter', () {
    test('run_givenRoomInTheBudget_runsTheActionsConcurrently', () async {
      final RequestLimiter limiter = RequestLimiter(maxConcurrent: 2);
      var running = 0;
      var maxRunning = 0;

      final List<Future<int>> calls = <Future<int>>[
        for (var index = 0; index < 2; index++)
          limiter.run('source', () async {
            running++;
            if (running > maxRunning) {
              maxRunning = running;
            }
            await Future<void>.delayed(Duration.zero);
            running--;

            return index;
          }),
      ];

      expect(await Future.wait(calls), <int>[0, 1]);
      // 预算够用时不得串行化：两个动作真的重叠过。
      expect(maxRunning, 2);
      expect(limiter.maxConcurrent, 2);
    });

    test('run_givenMoreCallersThanTheBudget_queuesTheExcess', () async {
      final RequestLimiter limiter = RequestLimiter(maxConcurrent: 2);
      final List<String> started = <String>[];
      final List<Completer<void>> gates = <Completer<void>>[
        Completer<void>(),
        Completer<void>(),
        Completer<void>(),
      ];

      final List<Future<void>> running = <Future<void>>[
        for (var index = 0; index < gates.length; index++)
          limiter.run('source', () async {
            started.add('#$index');
            await gates[index].future;
          }),
      ];

      await pumpEventQueue();

      // §8：超限的第三个请求在排队，既没有并发发出，也没有以 busy 失败（C-SRC-9）。
      expect(started, <String>['#0', '#1']);

      gates[0].complete();
      await running[0];
      await pumpEventQueue();
      expect(started, <String>['#0', '#1', '#2']);

      gates[1].complete();
      gates[2].complete();
      await Future.wait(running);
      expect(started, <String>['#0', '#1', '#2']);
    });

    test('run_givenQueuedCallers_servesThemInCallOrder', () async {
      final RequestLimiter limiter = RequestLimiter(maxConcurrent: 1);
      final List<String> started = <String>[];
      final List<Completer<void>> gates = <Completer<void>>[
        Completer<void>(),
        Completer<void>(),
        Completer<void>(),
      ];

      final List<Future<void>> running = <Future<void>>[
        for (var index = 0; index < gates.length; index++)
          limiter.run('source', () async {
            started.add('#$index');
            await gates[index].future;
          }),
      ];

      await pumpEventQueue();
      expect(started, <String>['#0']);

      for (var index = 0; index < gates.length; index++) {
        gates[index].complete();
        await running[index];
        await pumpEventQueue();
      }

      // 排队者按调用顺序接班：一批章节下载必须按请求顺序到站。
      expect(started, <String>['#0', '#1', '#2']);
    });

    test('run_givenDifferentKeys_spendsTheirBudgetsSeparately', () async {
      final RequestLimiter limiter = RequestLimiter(maxConcurrent: 1);
      final List<String> started = <String>[];
      final List<Completer<void>> gates = <Completer<void>>[
        Completer<void>(),
        Completer<void>(),
      ];

      final Future<void> first = limiter.run('source-a', () async {
        started.add('a');
        await gates[0].future;
      });
      await pumpEventQueue();

      final Future<void> second = limiter.run('source-b', () async {
        started.add('b');
        await gates[1].future;
      });
      await pumpEventQueue();

      // 换一个 key 就是另一份预算：不能被别的书源占住。
      expect(started, <String>['a', 'b']);

      gates[0].complete();
      gates[1].complete();
      await Future.wait(<Future<void>>[first, second]);
    });

    test('run_givenAnActionThatThrows_releasesItsSlot', () async {
      final RequestLimiter limiter = RequestLimiter(maxConcurrent: 1);

      await expectLater(
        limiter.run('source', () async => throw StateError('boom')),
        throwsStateError,
      );

      // 槽位没有泄漏：若泄漏，预算已被占满，这一句会一直挂着；超时让失败可见。
      await limiter
          .run('source', () async {})
          .timeout(const Duration(seconds: 2));
    });

    test('RequestLimiter_whenTheBudgetIsNotPositive_throwsAssertionError', () {
      expect(() => RequestLimiter(maxConcurrent: 0), throwsAssertionError);
    });
  });

  group('RequestLimiter rate gate', () {
    /// A limiter whose clock moves with the waits it is asked for.
    ///
    /// The rate window is measured in milliseconds (`book-source.md` §8), so a test records
    /// the waits instead of experiencing them (`docs/dev/testing.md` §4 forbids `sleep`).
    ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
    limiterWithRate({int maxConcurrent = 3, required ConcurrentRate rate}) {
      final FakeClock clock = FakeClock();
      final List<Duration> waits = <Duration>[];
      final RequestLimiter limiter = RequestLimiter(
        maxConcurrent: maxConcurrent,
        clock: clock,
        delay: (Duration duration) async {
          waits.add(duration);
          clock.advance(duration);
        },
      )..applyRate('source', rate);

      return (limiter: limiter, clock: clock, waits: waits);
    }

    test('run_givenRoomInsideTheWindow_doesNotWait', () async {
      final ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
      fixture = limiterWithRate(
        rate: const ConcurrentRate(times: 2, intervalMilliseconds: 1000),
      );

      await fixture.limiter.run('source', () async {});
      await fixture.limiter.run('source', () async {});

      // `2/1000` 给两次许可：前两次都得立刻走。
      expect(fixture.waits, isEmpty);
    });

    test('run_givenTheWindowIsFull_waitsForTheOldestPermitToExpire', () async {
      final ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
      fixture = limiterWithRate(
        rate: const ConcurrentRate(times: 2, intervalMilliseconds: 1000),
      );

      for (var index = 0; index < 3; index++) {
        await fixture.limiter.run('source', () async {});
      }

      // 第三次必须等第一个许可超出一个窗口，而且**只**等那么多（滑窗）。
      expect(fixture.waits, <Duration>[const Duration(milliseconds: 1000)]);
    });

    test('run_givenMoreCallersThanTheWindow_serialisesThemThroughIt', () async {
      final ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
      fixture = limiterWithRate(
        rate: const ConcurrentRate(times: 1, intervalMilliseconds: 500),
      );

      await Future.wait(<Future<void>>[
        for (var index = 0; index < 4; index++)
          fixture.limiter.run('source', () async {}),
      ]);

      // `1/500` 下四个调用者是四个连续的窗口：三次等待，每次一个窗口。
      expect(fixture.waits, <Duration>[
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 500),
      ]);
    });

    test('run_givenAnActionThatThrows_stillSpendsThePermit', () async {
      final ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
      fixture = limiterWithRate(
        rate: const ConcurrentRate(times: 1, intervalMilliseconds: 1000),
      );

      await expectLater(
        fixture.limiter.run<void>(
          'source',
          () async => throw StateError('boom'),
        ),
        throwsStateError,
      );
      await fixture.limiter.run('source', () async {});

      // 失败的请求**也**占掉了一个许可：它确实上过线，把许可还回去就等于放超额请求出去。
      expect(fixture.waits, <Duration>[const Duration(milliseconds: 1000)]);
    });

    test('applyRate_givenTheSameDeclarationAgain_keepsTheWindow', () async {
      final ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
      fixture = limiterWithRate(
        rate: const ConcurrentRate(times: 1, intervalMilliseconds: 1000),
      );

      await fixture.limiter.run('source', () async {});
      // 每个 use case 都会重新把同一个声明交上来：那不能把窗口清零，否则批量下载会重新开闸。
      fixture.limiter.applyRate(
        'source',
        const ConcurrentRate(times: 1, intervalMilliseconds: 1000),
      );
      await fixture.limiter.run('source', () async {});

      expect(fixture.waits, <Duration>[const Duration(milliseconds: 1000)]);
    });

    test('applyRate_givenANewDeclaration_startsAFreshWindow', () async {
      final ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
      fixture = limiterWithRate(
        rate: const ConcurrentRate(times: 1, intervalMilliseconds: 1000),
      );

      await fixture.limiter.run('source', () async {});
      fixture.limiter.applyRate(
        'source',
        const ConcurrentRate(times: 5, intervalMilliseconds: 1000),
      );
      for (var index = 0; index < 5; index++) {
        await fixture.limiter.run('source', () async {});
      }

      // 声明变了就从新窗口计起（M1 只会读到同一个模型值；这条钉住的是不复用旧许可）。
      expect(fixture.waits, isEmpty);
    });

    test('applyRate_givenNull_removesTheGate', () async {
      final ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
      fixture = limiterWithRate(
        rate: const ConcurrentRate(times: 1, intervalMilliseconds: 1000),
      );

      await fixture.limiter.run('source', () async {});
      fixture.limiter.applyRate('source', null);
      await fixture.limiter.run('source', () async {});

      // 「声明被删掉 / 改成 0」等于不再限速：并发门照旧。
      expect(fixture.waits, isEmpty);
    });

    test('run_givenNoInjectedDelay_waitsOnRealTime', () async {
      // 默认等待就是 `Future.delayed`（生产路径）：这里用一个毫秒级窗口把它跑一遍，
      // 不依赖秒级等待（`docs/dev/testing.md` §6 的毫秒级口径）。窗口取值让第二次调用
      // **通常**真的等到窗口过期；但覆盖率不依赖这一点——默认值是 `Future.delayed`
      // 的 tear-off，本文件没有「只有等待时才执行」的行（这正是此前 1 毫秒窗口会
      // 随机让 `core` 掉到 100% 以下的原因，见 PLAN §3.7）。
      final RequestLimiter limiter = RequestLimiter(maxConcurrent: 3)
        ..applyRate(
          'source',
          const ConcurrentRate(times: 1, intervalMilliseconds: 20),
        );

      await limiter.run('source', () async {});
      await limiter
          .run('source', () async {})
          .timeout(const Duration(seconds: 2));

      // 两把门都放行了：真的等到窗口过期，而不是挂着。
      expect(limiter.maxConcurrent, 3);
    });

    test('run_givenARateGateAndABusySlot_waitsOnBothGates', () async {
      final ({RequestLimiter limiter, FakeClock clock, List<Duration> waits})
      fixture = limiterWithRate(
        maxConcurrent: 1,
        rate: const ConcurrentRate(times: 2, intervalMilliseconds: 1000),
      );
      final Completer<void> running = Completer<void>();
      final List<String> finished = <String>[];

      final Future<void> first = fixture.limiter.run('source', () async {
        await running.future;
        finished.add('first');
      });
      final Future<void> second = fixture.limiter.run('source', () async {
        finished.add('second');
      });
      final Future<void> third = fixture.limiter.run('source', () async {
        finished.add('third');
      });

      // 第三个卡在速率门（许可已满）而前两个卡在并发门；速率门不占槽位，所以这里能到达。
      await pumpEventQueue();
      expect(finished, isEmpty);
      expect(fixture.waits, <Duration>[const Duration(milliseconds: 1000)]);

      running.complete();
      await Future.wait(<Future<void>>[first, second, third]);

      // 两把门都过了才轮到动作，且槽位交接仍是 FIFO。
      expect(finished, <String>['first', 'second', 'third']);
    });
  });
}
