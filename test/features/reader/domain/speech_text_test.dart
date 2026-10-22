import 'package:flutter_reader/features/reader/domain/speech_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitSpeechText', () {
    test('splitSpeechText_givenEmptyText_returnsNothing', () {
      expect(splitSpeechText(''), isEmpty);
      expect(splitSpeechText('  \n\n  '), isEmpty);
    });

    test('splitSpeechText_givenAShortParagraph_keepsItWhole', () {
      expect(splitSpeechText('  第一句话。  '), <String>['第一句话。']);
    });

    test('splitSpeechText_givenBlanks_betweenParagraphs', () {
      // 空行与行首缩进会被 TTS 读成不该有的停顿：清理掉，不产生空块。
      expect(splitSpeechText('第一段\n\n  第二段  \n'), <String>['第一段', '第二段']);
    });

    test('splitSpeechText_givenAnOverlongSentence_splitsAtTheLimit', () {
      final String text = '字' * 25;
      final List<String> chunks = splitSpeechText(text, maxLength: 10);

      expect(chunks, hasLength(3));
      expect(chunks[0], '字' * 10);
      expect(chunks[1], '字' * 10);
      expect(chunks[2], '字' * 5);
    });

    test('splitSpeechText_givenSentenceEndings_prefersTheBoundary', () {
      final List<String> chunks = splitSpeechText(
        '这是第一句。这是第二句。',
        maxLength: 10,
      );

      // 边界只在窗口后半段里找：块不会短到每句一块。
      expect(chunks.first, '这是第一句。');
      expect(chunks, hasLength(2));
    });

    test('splitSpeechText_givenOnlyClauseEndings_prefersTheClause', () {
      final List<String> chunks = splitSpeechText(
        '第一段没有句号，后面还有内容',
        maxLength: 10,
      );

      expect(chunks.first, '第一段没有句号，');
    });

    test('splitSpeechText_givenASurrogatePairAtTheLimit_doesNotSplitIt', () {
      // 硬切点落在低代理项上时整体后移一格：否则一个字被拆成两个替换字符。
      final String text = '${'a' * 9}😀${'b' * 5}';
      final List<String> chunks = splitSpeechText(text, maxLength: 10);

      expect(chunks.first, '${'a' * 9}😀');
      expect(chunks.last, 'b' * 5);
      expect(chunks.first.runes.length, 10);
    });

    test('splitSpeechText_givenTypicalChapterText_coversEveryCharacter', () {
      final String text = <String>[
        for (var index = 0; index < 30; index++) '第$index段：正文内容，用来测试切分。',
      ].join('\n');
      final List<String> chunks = splitSpeechText(text, maxLength: 60);

      expect(chunks.length, greaterThan(1));
      expect(
        chunks.every((String chunk) => chunk.length <= 61),
        isTrue,
        reason: 'chunks stay near the limit',
      );
      expect(chunks.join().replaceAll('\n', ''), contains('第29段'));
    });
  });
}
