import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_design/m3e_design.dart';

/// Pumps one widget inside the app's theme, so `context.m3e` answers.
Future<void> _pumpThemed(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[
          M3ETheme.defaults(
            ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
          ),
        ],
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('readerBodyText', () {
    test(
      'readerBodyText_givenDefaults_indentsEveryParagraphAndAddsSpacing',
      () {
        // 默认段距 0.5 → 空行数 = 1 + round(0.5*2) = 2 个换行（即段间一个空行）；
        // 默认缩进 2 em，中文正文用全角空格（ADR-0051 §决策 4）。
        final String laidOut = readerBodyText(
          '第一段\n第二段',
          ReaderSettings.defaults,
        );

        expect(laidOut, '\u3000\u3000第一段\n\n\u3000\u3000第二段');
      },
    );

    test('readerBodyText_givenNoIndentAndSpacing_keepsTheParagraphsTight', () {
      final String laidOut = readerBodyText(
        '第一段\n第二段',
        ReaderSettings(paragraphSpacing: 0, firstLineIndent: 0),
      );

      expect(laidOut, '第一段\n第二段');
    });

    test('readerBodyText_givenALatinBody_indentsWithSpaces', () {
      // 非 CJK 正文用四个半角空格当 1 em，避免字体缺全角空格时出现空框。
      final String laidOut = readerBodyText(
        'Hello\nWorld',
        ReaderSettings(firstLineIndent: 1),
      );

      expect(laidOut, startsWith('    Hello'));
    });

    test('readerBodyText_givenBlankLines_dropsTheIndentOnThem', () {
      final String laidOut = readerBodyText(
        '第一段\n\n第二段',
        ReaderSettings.defaults,
      );

      expect(laidOut, isNot(contains('\u3000\u3000\n')));
      expect('\n\n\n'.allMatches(laidOut), isEmpty);
    });
  });

  group('readingSpan', () {
    const TextStyle style = TextStyle(fontSize: 16);
    const TextStyle highlight = TextStyle(backgroundColor: Color(0xFF000000));

    test('readingSpan_givenNoHighlight_answersOnePlainSpan', () {
      final TextSpan span = readingSpan(
        body: '第一句。第二句。',
        style: style,
        highlightStyle: highlight,
        highlight: null,
      );

      expect(span.text, '第一句。第二句。');
      expect(span.children, isNull);
    });

    test('readingSpan_givenARange_splitsTheTextInThree', () {
      final TextSpan span = readingSpan(
        body: '第一句。第二句。',
        style: style,
        highlightStyle: highlight,
        highlight: (start: 4, end: 8),
      );

      expect(
        span.children!.map((InlineSpan child) => (child as TextSpan).text),
        <String>['第一句。', '第二句。'],
      );
      expect((span.children!.last as TextSpan).style, highlight);
    });

    test('readingSpan_givenARangeThatOverlapsThePage_clipsIt', () {
      // 分页模式下传来的窗口是整页：句子可能从上一页开始，也可能延续到下一页。
      final TextSpan span = readingSpan(
        body: '0123456789',
        start: 4,
        end: 8,
        style: style,
        highlightStyle: highlight,
        highlight: (start: 2, end: 6),
      );

      expect(
        span.children!.map((InlineSpan child) => (child as TextSpan).text),
        <String>['45', '67'],
      );
      expect((span.children!.first as TextSpan).style, highlight);
    });

    test('readingSpan_givenARangeOutsideThePage_paintsNothing', () {
      final TextSpan span = readingSpan(
        body: '0123456789',
        start: 4,
        end: 8,
        style: style,
        highlightStyle: highlight,
        highlight: (start: 8, end: 10),
      );

      expect(span.text, '4567');
      expect(span.children, isNull);
    });
  });

  group('readingText', () {
    test('readingText_givenNoHighlight_keepsTheStyleOnTheText', () {
      final Widget widget = readingText(
        body: '正文',
        style: const TextStyle(fontSize: 16),
        highlightStyle: const TextStyle(backgroundColor: Color(0xFF000000)),
        highlight: null,
      );

      // 高亮之外的路径必须是普通 `Text`：`Text.rich` 会把样式挪到 span 上，
      // 阅读页的排版测试正是从 widget 上读回字号的。
      expect(widget, isA<Text>());
      expect((widget as Text).style?.fontSize, 16);
      expect(widget.style?.backgroundColor, isNull);
    });

    testWidgets('readingText_givenAHighlight_paintsTheSentence', (
      WidgetTester tester,
    ) async {
      await _pumpThemed(
        tester,
        readingText(
          body: '第一句。第二句。',
          style: const TextStyle(fontSize: 16),
          highlightStyle: const TextStyle(backgroundColor: Color(0xFF123456)),
          highlight: (start: 0, end: 4),
        ),
      );

      final Text widget = tester.widget<Text>(find.byType(Text));
      expect(widget.textSpan, isNotNull);
      final List<InlineSpan> spans = (widget.textSpan! as TextSpan).children!;
      expect((spans.first as TextSpan).text, '第一句。');
      expect(
        (spans.first as TextSpan).style?.backgroundColor,
        const Color(0xFF123456),
      );
    });

    testWidgets('spokenSentenceStyle_givenATextStyle_keepsItsMetrics', (
      WidgetTester tester,
    ) async {
      const TextStyle style = TextStyle(fontSize: 18, height: 1.6);
      late TextStyle spoken;

      await _pumpThemed(
        tester,
        Builder(
          builder: (BuildContext context) {
            spoken = spokenSentenceStyle(context, style);

            return const SizedBox.shrink();
          },
        ),
      );

      // 只换颜色：字重与字号一旦变化，分页测量出来的页界就和正文不一致了。
      expect(spoken.fontSize, 18);
      expect(spoken.height, 1.6);
      expect(spoken.backgroundColor, isNotNull);
      expect(spoken.color, isNotNull);
    });
  });
}
