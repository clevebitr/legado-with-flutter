import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitGroups', () {
    test('splitGroups_givenNothing_returnsNoGroups', () {
      expect(splitGroups(null), isEmpty);
    });

    test('splitGroups_givenEverySeparator_splitsAndTrims', () {
      // 分隔符集取自上游 `AppPattern.kt:39`：`,` `;` `，` `；`。
      expect(splitGroups(' 精选 ， 玄幻;完结 ，精选 '), <String>['精选', '玄幻', '完结']);
    });

    test('splitGroups_givenOnlySeparators_returnsNoGroups', () {
      expect(splitGroups(' , ; '), isEmpty);
    });
  });

  group('isInvalidGroup', () {
    test('isInvalidGroup_givenAFailureGroup_isTrue', () {
      expect(isInvalidGroup(searchInvalidGroup), isTrue);
      expect(isInvalidGroup('翻译失效'), isTrue);
      expect(isInvalidGroup(checkTimeoutGroup), isTrue);
    });

    test('isInvalidGroup_givenAUserGroup_isFalse', () {
      expect(isInvalidGroup('精选'), isFalse);
    });
  });

  group('withoutInvalidGroups', () {
    test('withoutInvalidGroups_givenAMixedList_keepsTheUsersGroups', () {
      // 「重新校验前先清掉」只清校验自己写的那几个 token，用户手工分组要留下（ADR-0043 §后果）。
      expect(withoutInvalidGroups('精选, 搜索失效, 校验超时, 玄幻'), '精选, 玄幻');
    });

    test('withoutInvalidGroups_givenOnlyInvalidGroups_returnsNull', () {
      expect(withoutInvalidGroups('搜索失效, 搜索目录失效'), isNull);
    });

    test('withoutInvalidGroups_givenNothing_returnsNull', () {
      expect(withoutInvalidGroups(null), isNull);
    });
  });

  group('withGroups', () {
    test('withGroups_givenAnExistingList_appendsWithoutDuplicates', () {
      expect(
        withGroups('精选', <String>[searchInvalidGroup, searchInvalidGroup]),
        '精选, 搜索失效',
      );
    });

    test('withGroups_givenNothing_addsTheGroup', () {
      expect(withGroups(null, <String>[exploreInvalidGroup]), '发现失效');
    });

    test('withGroups_givenNoGroups_keepsTheList', () {
      expect(withGroups('精选', const <String>[]), '精选');
    });
  });

  group('withoutGroups', () {
    test('withoutGroups_givenTheGroup_dropsIt', () {
      expect(withoutGroups('精选, 搜索失效', <String>[searchInvalidGroup]), '精选');
    });

    test('withoutGroups_givenEveryGroup_returnsNull', () {
      expect(withoutGroups('搜索失效', <String>[searchInvalidGroup]), isNull);
    });
  });

  group('withErrorComment', () {
    test('withErrorComment_givenNoComment_writesTheMarkerLine', () {
      expect(withErrorComment(null, '搜索失效'), '// Error: 搜索失效');
    });

    test('withErrorComment_givenAnOldNote_replacesItAndKeepsTheUsersText', () {
      // 上游 `addErrorComment` 用空行分段（`BookSource.kt:215-226`）：一条本轮结论 + 用户原文。
      expect(
        withErrorComment('// Error: 旧结论\n\n我自己的说明', '搜索正文失效'),
        '// Error: 搜索正文失效\n\n我自己的说明',
      );
    });

    test('withErrorComment_givenAUserCommentOnly_appendsBelowIt', () {
      expect(withErrorComment('我自己的说明', 'js失效'), '// Error: js失效\n\n我自己的说明');
    });
  });

  group('withoutErrorComment', () {
    test('withoutErrorComment_givenNothing_returnsNull', () {
      expect(withoutErrorComment(null), isNull);
    });

    test('withoutErrorComment_givenOnlyTheNote_returnsNull', () {
      expect(withoutErrorComment('// Error: 搜索失效'), isNull);
    });

    test('withoutErrorComment_givenTheUsersText_keepsIt', () {
      expect(
        withoutErrorComment('// Error: 搜索失效\n\n我的说明\n\n// Error: js失效'),
        '我的说明',
      );
    });
  });
}
