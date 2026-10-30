import 'package:flutter_reader/features/book_source/domain/book_source_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

/// One raw book source object with at least one field of every kind the fingerprint sees.
Map<String, Object?> _entry() => <String, Object?>{
  'bookSourceName': '示例书源',
  'bookSourceUrl': 'https://a.test',
  'searchUrl': 'https://a.test/search?q={{key}}',
  'header': '{"User-Agent":"x"}',
  'ruleSearch': <String, Object?>{'bookList': 'class.item', 'name': 'class.n'},
  'ruleBookInfo': <String, Object?>{'name': 'class.b'},
  'ruleToc': <String, Object?>{'chapterList': 'class.c'},
  'ruleContent': <String, Object?>{'content': 'class.body'},
  'ruleExplore': <String, Object?>{'bookList': 'class.e'},
};

void main() {
  group('bookSourceFingerprint', () {
    test('bookSourceFingerprint_givenTheSameEntryTwice_isStable', () {
      expect(bookSourceFingerprint(_entry()), bookSourceFingerprint(_entry()));
    });

    test('bookSourceFingerprint_givenReorderedKeys_isTheSame', () {
      // 快照里的「重复条目」大多是重新导出造成的键序差异（1012 个 URL）——它们必须是同一条。
      final Map<String, Object?> reversed = <String, Object?>{
        for (final MapEntry<String, Object?> entry
            in _entry().entries.toList().reversed)
          entry.key: entry.value,
      };

      expect(bookSourceFingerprint(reversed), bookSourceFingerprint(_entry()));
    });

    test('bookSourceFingerprint_givenChangedJsLib_differs', () {
      // 库脚本决定每条 `@js:` 规则跑出来的值（ADR-0078 S1），所以它属于行为字段。
      final Map<String, Object?> changed = _entry()
        ..['jsLib'] = 'function sign(u) { return u; }';

      expect(
        bookSourceFingerprint(changed),
        isNot(bookSourceFingerprint(_entry())),
      );
    });

    test('bookSourceFingerprint_givenChangedRuleText_differs', () {
      final Map<String, Object?> changed = _entry()
        ..['ruleContent'] = <String, Object?>{'content': 'class.other'};

      expect(
        bookSourceFingerprint(changed),
        isNot(bookSourceFingerprint(_entry())),
      );
    });

    test('bookSourceFingerprint_givenChangedName_differs', () {
      final Map<String, Object?> changed = _entry()
        ..['bookSourceName'] = '另一个名字';

      expect(
        bookSourceFingerprint(changed),
        isNot(bookSourceFingerprint(_entry())),
      );
    });

    test('bookSourceFingerprint_givenOnlyUserStateOrMetadata_differsNot', () {
      // ADR-0040 §决策 2：用户态与展示字段不属于身份，否则用户一改开关就会多出一行。
      final Map<String, Object?> changed = _entry()
        ..['enabled'] = false
        ..['customOrder'] = 42
        ..['weight'] = 7
        ..['lastUpdateTime'] = 1612777312843
        ..['respondTime'] = 12
        ..['bookSourceGroup'] = '精选'
        ..['bookSourceType'] = 1;

      expect(bookSourceFingerprint(changed), bookSourceFingerprint(_entry()));
    });

    test(
      'bookSourceFingerprint_givenMissingFields_differsFromAnEntryWithThem',
      () {
        final Map<String, Object?> withoutHeader = _entry()..remove('header');

        expect(
          bookSourceFingerprint(withoutHeader),
          isNot(bookSourceFingerprint(_entry())),
        );
      },
    );
  });

  group('canonicalJson', () {
    test('canonicalJson_givenNestedMaps_sortsEveryLevel', () {
      expect(
        canonicalJson(<String, Object?>{
          'b': <String, Object?>{'y': 1, 'x': 2},
          'a': <Object?>[3, 1],
        }),
        '{"a":[3,1],"b":{"x":2,"y":1}}',
      );
    });

    test('canonicalJson_givenScalars_encodesThemAsJson', () {
      expect(canonicalJson(null), 'null');
      expect(canonicalJson('a"b'), '"a\\"b"');
      expect(canonicalJson(true), 'true');
      expect(canonicalJson(7), '7');
    });
  });
}
