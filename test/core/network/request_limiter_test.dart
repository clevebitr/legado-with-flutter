import 'dart:async';

import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
