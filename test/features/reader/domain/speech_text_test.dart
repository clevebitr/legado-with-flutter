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

  group('splitSpeechSegments', () {
    test(
      'splitSpeechSegments_givenATrimmedParagraph_keepsTheSourceOffsets',
      () {
        // ADR-0057 §决策 5：偏移必须回到**渲染后的正文**，行首缩进与空行都不能算进 chunk 里。
        const String text = '  第一段。\n\n第二段。';
        final List<SpeechSegment> segments = splitSpeechSegments(text);

        expect(segments.map((SpeechSegment s) => s.text), <String>[
          '第一段。',
          '第二段。',
        ]);
        expect(segments[0].start, 2);
        expect(segments[0].end, 6);
        expect(text.substring(segments[0].start, segments[0].end), '第一段。');
        expect(text.substring(segments[1].start, segments[1].end), '第二段。');
      },
    );

    test('splitSpeechSegments_givenAnOverlongParagraph_pointsEveryChunk', () {
      final String text = '字' * 25;
      final List<SpeechSegment> segments = splitSpeechSegments(
        text,
        maxLength: 10,
      );

      for (final SpeechSegment segment in segments) {
        expect(text.substring(segment.start, segment.end), segment.text);
      }
      expect(segments.last.end, text.length);
    });

    test('splitSpeechSegments_andSplitSpeechText_agreeOnTheText', () {
      const String text = '第一句。第二句。\n第三行，还有内容';

      expect(
        splitSpeechSegments(
          text,
          maxLength: 5,
        ).map((SpeechSegment s) => s.text),
        splitSpeechText(text, maxLength: 5),
      );
    });
  });

  group('speechSentenceAt', () {
    test('speechSentenceAt_givenAnOffset_answersTheWholeSentence', () {
      const String text = '第一句。第二句！第三句？';

      final SpeechSegment sentence = speechSentenceAt(text, 5);

      expect(sentence.text, '第二句！');
      expect(text.substring(sentence.start, sentence.end), '第二句！');
    });

    test('speechSentenceAt_givenAParagraphBreak_stopsAtTheLine', () {
      // 句号之外，换行也是句界：高亮不能跨过一段。
      const String text = '第一段没有标点\n第二段。';

      expect(speechSentenceAt(text, 3).text, '第一段没有标点');
    });

    test('speechSentenceAt_givenTheLastCharacter_answersTheLastSentence', () {
      const String text = '开头。结尾';

      final SpeechSegment sentence = speechSentenceAt(text, text.length - 1);

      expect(sentence.text, '结尾');
      expect(sentence.end, text.length);
    });

    test('speechSentenceAt_givenEmptyText_answersAnEmptySegment', () {
      final SpeechSegment sentence = speechSentenceAt('', 0);

      expect(sentence.text, isEmpty);
      expect(sentence.start, 0);
      expect(sentence.end, 0);
      expect(sentence.contains(0), isFalse);
    });

    test('speechSentenceAt_givenSpacesAfterABreak_dropsThem', () {
      // 排版后的正文里句号后面可能跟空格（英文正文更常见）：高亮不该从空格开始。
      const String text = '第一句。 第二句。';

      final SpeechSegment sentence = speechSentenceAt(text, 6);

      expect(sentence.text, '第二句。');
      expect(sentence.start, 5);
      expect(text.substring(sentence.start, sentence.end), '第二句。');
    });

    test('speechSentenceAt_givenTrailingSpaces_trimsThem', () {
      // 行尾空格同样不该进高亮：读者看到的是句子，不是空白。
      const String text = '第一段  \n第二段。';

      final SpeechSegment sentence = speechSentenceAt(text, 1);

      expect(sentence.text, '第一段');
      expect(sentence.end, 3);
    });

    test('speechSentenceAt_givenAnOffsetPastTheEnd_clampsIt', () {
      const String text = '只有一句。';

      expect(speechSentenceAt(text, 999).text, '只有一句。');
    });
  });
}
