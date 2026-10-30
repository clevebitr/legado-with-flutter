import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_settings.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_keyword.dart';
import 'package:flutter_reader/features/book_source/domain/task_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceCheckSettings', () {
    test(
      'SourceCheckSettings_whenDefault_runsEveryStageWithUpstreamDefaults',
      () {
        const SourceCheckSettings settings = SourceCheckSettings();

        for (final SourceCheckStage stage in SourceCheckStage.values) {
          expect(settings.runs(stage), isTrue, reason: '$stage 默认开着');
        }
        // 默认词与超时都是上游的值（ADR-0043 §决策 2）。
        expect(settings.keyword, defaultCheckKeyword);
        expect(settings.timeout, defaultSourceCheckTimeout);
        expect(defaultSourceCheckTimeout, const Duration(seconds: 180));
      },
    );

    test('runs_givenAStageThatIsOff_isFalse', () {
      const SourceCheckSettings settings = SourceCheckSettings(
        stages: <SourceCheckStage>{SourceCheckStage.search},
      );

      expect(settings.runs(SourceCheckStage.search), isTrue);
      expect(settings.runs(SourceCheckStage.content), isFalse);
    });

    test('equality_givenTheSameStagesInAnotherOrder_isEqual', () {
      // Set 的 `==` 是同一性比较，所以相等要显式实现：否则页面会因一个没变的开关重算。
      const SourceCheckSettings left = SourceCheckSettings(
        stages: <SourceCheckStage>{
          SourceCheckStage.search,
          SourceCheckStage.toc,
        },
      );
      const SourceCheckSettings right = SourceCheckSettings(
        stages: <SourceCheckStage>{
          SourceCheckStage.toc,
          SourceCheckStage.search,
        },
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });
  });

  group('TaskCancellation', () {
    test('cancel_whenCalled_latches', () {
      final TaskCancellation cancellation = TaskCancellation();

      expect(cancellation.isCancelled, isFalse);
      cancellation.cancel();
      cancellation.cancel();

      expect(cancellation.isCancelled, isTrue);
    });
  });
}
