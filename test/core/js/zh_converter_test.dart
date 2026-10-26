import 'package:flutter_reader/core/js/zh_converter.dart';
import 'package:flutter_reader/core/js/zh_tables.dart';
import 'package:flutter_test/flutter_test.dart';

/// A miniature table with a phrase key longer than any character key.
const String _table = '''
# 注释行
瞭=了
一目瞭然=一目了然
著=着
著名=著名
''';

void main() {
  group('ZhConverter', () {
    test('ZhConverter_givenACommentAndBadRows_skipsThem', () {
      final ZhConverter converter = ZhConverter.parse(
        '# comment\nno-separator\n=empty key\nempty value=\n瞭=了\n',
      );

      expect(converter.length, 1);
      expect(converter.convert('瞭'), '了');
    });

    test('ZhConverter_givenAPhrase_matchesTheLongestKey', () {
      final ZhConverter converter = ZhConverter.parse(_table);

      // `瞭` 单字命中「了」，但「一目瞭然」整条短语更长，必须整条换。
      expect(converter.convert('一目瞭然'), '一目了然');
      expect(converter.convert('瞭'), '了');
      expect(converter.longestKey, 4);
    });

    test('ZhConverter_givenUnknownCharacters_copiesThemThrough', () {
      final ZhConverter converter = ZhConverter.parse(_table);

      expect(converter.convert('a瞭b-c'), 'a了b-c');
      expect(converter.convert(''), '');
    });

    test(
      'ZhConverter_givenCRLFTable_parsesTheKeysWithoutTheCarriageReturn',
      () {
        final ZhConverter converter = ZhConverter.parse('瞭=了\r\n著=着\r\n');

        expect(converter.convert('瞭著'), '了着');
      },
    );
  });

  group('ZhTables', () {
    test('ZhTables_givenText_parsesOnlyTheNeededTable', () {
      final ZhTables tables = ZhTables(t2sText: _table, s2tText: _table);

      expect(tables.t2s(needed: false), isNull);
      expect(tables.s2t(needed: false), isNull);
      expect(tables.t2s()?.convert('一目瞭然'), '一目了然');
      // 没有要求 s2t，它仍未被解析。
      expect(tables.s2t(needed: false), isNull);
    });

    test('ZhTables_givenNoText_answersNull', () {
      final ZhTables tables = ZhTables();

      expect(tables.t2s(), isNull);
      expect(tables.s2t(), isNull);
    });

    test('ZhTables_givenAScript_answersWhichTablesItMightNeed', () {
      expect(ZhTables.needsOf('java.t2s(tag)', null).t2s, isTrue);
      expect(ZhTables.needsOf('java.t2s(tag)', null).s2t, isFalse);
      // 库脚本里用到也算。
      expect(
        ZhTables.needsOf('tag', 'function f(){ return java.s2t(tag); }').s2t,
        isTrue,
      );
      expect(ZhTables.needsOf('1 + 1', null), (t2s: false, s2t: false));
    });
  });
}
