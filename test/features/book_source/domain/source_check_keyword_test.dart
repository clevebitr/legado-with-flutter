import 'package:flutter_reader/features/book_source/domain/source_check_keyword.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveCheckKeyword', () {
    test('resolveCheckKeyword_givenAKeyword_returnsIt', () {
      // 真实语料里 `checkKeyWord` 多数就是一个书名（`tool/spot_check/README.md` §3 的普查）。
      expect(resolveCheckKeyword(checkKeyWord: '万族之劫', fallback: '我的'), '万族之劫');
    });

    test('resolveCheckKeyword_givenSurroundingSpaces_trimsThem', () {
      expect(resolveCheckKeyword(checkKeyWord: '  剑来  ', fallback: '我的'), '剑来');
    });

    test('resolveCheckKeyword_givenNothing_fallsBack', () {
      expect(resolveCheckKeyword(checkKeyWord: null, fallback: '我的'), '我的');
    });

    test('resolveCheckKeyword_givenBlank_fallsBack', () {
      expect(resolveCheckKeyword(checkKeyWord: '   ', fallback: '我的'), '我的');
    });

    test('resolveCheckKeyword_givenARule_fallsBack', () {
      // 上游的四个排除前缀（`BookSource.kt:228-238`）是行为依据，本仓把它们写成显式判据：
      // 搜规则文本既浪费一次请求，又会把「规则没跑」误报成「搜索失效」。
      for (final String rule in <String>[
        'https://a.test/s?q=1',
        '@css:class.name@text',
        '@@class.name',
        r'$.data.name',
        '搜索::class.name',
        '第一页++https://a.test/1',
        '正文--https://a.test/1',
        'class.body##',
        'https://a.test/search?q={{key}}',
      ]) {
        expect(
          resolveCheckKeyword(checkKeyWord: rule, fallback: '我的'),
          '我的',
          reason: '$rule 应被当成规则',
        );
      }
    });

    test('resolveCheckKeyword_givenHttpInAnyCase_fallsBack', () {
      expect(
        resolveCheckKeyword(checkKeyWord: 'HTTP://a.test', fallback: '我的'),
        '我的',
      );
    });
  });

  group('looksLikeRule', () {
    test('looksLikeRule_givenABlankValue_isFalse', () {
      expect(looksLikeRule('   '), isFalse);
    });

    test('looksLikeRule_givenAPlainKeyword_isFalse', () {
      expect(looksLikeRule('三体'), isFalse);
      expect(looksLikeRule('my book'), isFalse);
    });
  });
}
