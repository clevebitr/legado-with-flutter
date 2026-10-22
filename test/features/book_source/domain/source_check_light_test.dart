import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_light.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stored source with no check history and no check columns.
StoredBookSource _stored({
  SourceCheckRecord? lastCheck,
  String? groupName,
  String? comment,
}) => StoredBookSource(
  id: 1,
  source: const BookSource(
    name: '示例书源',
    url: 'https://a.test',
    searchRule: SearchRule(bookList: 'class.item'),
    tocRule: TocRule(chapterList: 'class.c'),
    contentRule: ContentRule(content: 'class.body'),
  ),
  isEnabled: true,
  customOrder: 0,
  importedAt: DateTime.utc(2026, 10, 22),
  groupName: groupName,
  comment: comment,
  lastCheck: lastCheck,
);

/// One recorded verdict for the source above.
SourceCheckRecord _record({
  SourceCheckStatus status = SourceCheckStatus.failed,
  List<String> invalidGroups = const <String>[],
  String? errorComment,
}) => SourceCheckRecord(
  sourceId: 1,
  checkedAt: DateTime.utc(2026, 10, 22, 12),
  status: status,
  elapsedMillis: 640,
  invalidGroups: invalidGroups,
  errorComment: errorComment,
);

void main() {
  group('sourceCheckLightOf', () {
    test('light_givenNoHistoryAndNoColumns_isUnchecked', () {
      expect(sourceCheckLightOf(_stored()), SourceCheckLight.unchecked);
    });

    test('light_givenLegacyColumnsWithAnOwnedGroup_isFailed', () {
      // v5 库没有历史：旧注释 / 旧分组是唯一证据，不能当成绿（ADR-0052 §决策 1）。
      expect(
        sourceCheckLightOf(_stored(groupName: searchInvalidGroup)),
        SourceCheckLight.failed,
      );
      expect(
        sourceCheckLightOf(_stored(comment: '$errorCommentMarker搜索失效')),
        SourceCheckLight.failed,
      );
    });

    test('light_givenALegacyUserGroup_isStillUnchecked', () {
      // 「玄幻」是用户分组，不是校验结论：旧库里的用户分组不许把灯染红。
      expect(
        sourceCheckLightOf(_stored(groupName: '玄幻')),
        SourceCheckLight.unchecked,
      );
    });

    test('light_givenASucceededRecord_isPassed', () {
      expect(
        sourceCheckLightOf(
          _stored(
            lastCheck: _record(
              status: SourceCheckStatus.succeeded,
              errorComment: null,
            ),
          ),
        ),
        SourceCheckLight.passed,
      );
    });

    test('light_givenAnOwnedFailureGroup_isFailed', () {
      expect(
        sourceCheckLightOf(
          _stored(
            lastCheck: _record(invalidGroups: <String>[searchTocInvalidGroup]),
          ),
        ),
        SourceCheckLight.failed,
      );
    });

    test('light_givenOnlyTimeoutOrJsGroups_isDegraded', () {
      expect(
        sourceCheckLightOf(
          _stored(
            lastCheck: _record(invalidGroups: <String>[checkTimeoutGroup]),
          ),
        ),
        SourceCheckLight.degraded,
      );
      expect(
        sourceCheckLightOf(
          _stored(lastCheck: _record(invalidGroups: <String>[jsInvalidGroup])),
        ),
        SourceCheckLight.degraded,
      );
    });

    test('light_givenADegradedGroupPlusARealOne_isFailed', () {
      // 只要有一条「源自己的问题」，就不是可重试的降级态。
      expect(
        sourceCheckLightOf(
          _stored(
            lastCheck: _record(
              invalidGroups: <String>[checkTimeoutGroup, searchInvalidGroup],
            ),
          ),
        ),
        SourceCheckLight.failed,
      );
    });

    test('light_givenACancelledRecord_isUnchecked', () {
      expect(
        sourceCheckLightOf(
          _stored(lastCheck: _record(status: SourceCheckStatus.cancelled)),
        ),
        SourceCheckLight.unchecked,
      );
    });

    test('hasCheckFailure_givenPassed_isFalseAndGivenDegraded_isTrue', () {
      expect(
        hasCheckFailure(
          _stored(lastCheck: _record(status: SourceCheckStatus.succeeded)),
        ),
        isFalse,
      );
      expect(
        hasCheckFailure(
          _stored(
            lastCheck: _record(invalidGroups: <String>[checkTimeoutGroup]),
          ),
        ),
        isTrue,
      );
    });
  });
}
