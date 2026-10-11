import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('currentBookSource', () {
    test('read_givenThePhase25Seam_returnsNullSoThePagesShowAnEmptyState', () {
      // 书源导入与仓储属于 Phase 5（ADR-0025 §后果）；在该 seam 被填充之前，
      // 页面必须走空态，而不是拿一个空规则集去请求（PLAN.md 2.5）。
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(currentBookSourceProvider), isNull);
    });
  });
}
