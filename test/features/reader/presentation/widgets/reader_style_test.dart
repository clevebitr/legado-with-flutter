import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
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

  group('readerEyeProtectionMatrix', () {
    test('readerEyeProtectionMatrix_givenZero_staysOff', () {
      // 0 = 关：不套滤镜，正文颜色与主题完全一致。
      expect(readerEyeProtectionMatrix(0), isNull);
      expect(readerEyeProtectionFilter(0), isNull);
    });

    test('readerEyeProtectionMatrix_givenAFullStrength_warmsThePage', () {
      final List<double>? matrix = readerEyeProtectionMatrix(100);

      expect(matrix, isNotNull);
      // 暖光 = 红保持、绿略降、蓝压得最狠（上游的色温方向，ADR-0086 §决策 2）。
      expect(matrix![0], 1);
      expect(matrix[6], lessThan(1));
      expect(matrix[12], lessThan(matrix[6]));
    });

    test('readerEyeProtectionMatrix_givenMoreStrength_coolsMore', () {
      final List<double> weak = readerEyeProtectionMatrix(30)!;
      final List<double> strong = readerEyeProtectionMatrix(90)!;

      // 强度越大蓝通道掉得越多，单调且可预测。
      expect(strong[12], lessThan(weak[12]));
    });

    test('readerEyeProtectionMatrix_givenAnOutOfRangeStrength_clampsIt', () {
      expect(readerEyeProtectionMatrix(-10), isNull);
      expect(readerEyeProtectionMatrix(500), readerEyeProtectionMatrix(100));
    });

    test('readerEyeProtectionFilter_givenAStrength_answersAfilter', () {
      expect(readerEyeProtectionFilter(50), isNotNull);
    });
  });

  group('readerTextStyle', () {
    testWidgets(
      'readerTextStyle_givenAHostileAmbient_paintsTheHeightItMeasured',
      (WidgetTester tester) async {
        // 页表按**量到**的高度给每一页定高，而 `Text` 默认会把样式并到环境的
        // `DefaultTextStyle` 上：环境给的字距会改变换行，量出来与画出来的行数就不一样了。
        // 真机上正是这样整页溢出（日志里 15 条 `RenderFlex overflowed by 31 pixels`）。
        late TextStyle style;
        late TextScaler scaler;
        await _pumpThemed(
          tester,
          Builder(
            builder: (BuildContext context) {
              style = readerTextStyle(
                tokens: context.m3e,
                fontScale: 1,
                lineHeight: 1.5,
                foreground: const Color(0xFF000000),
              );
              scaler = MediaQuery.textScalerOf(context);

              return const SizedBox.shrink();
            },
          ),
        );

        final String body = <String>[
          for (var index = 0; index < 12; index++)
            '　　“这世道，人心不古。”老人叹了口气，抬起袖子擦了擦脸上的雨水。',
        ].join('\n');
        const double width = 320;
        final double measured = readerTextHeight(
          text: body,
          style: style,
          width: width,
          textScaler: scaler,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  // 环境样式故意与量高的样式完全不同；`Text` 不该从它那里继承任何东西。
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: 30,
                      height: 3,
                      letterSpacing: 8,
                    ),
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: Text(body, style: style),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // 画出来的高度必须就是量出来的高度（页表用的就是这个数）。
        expect(
          tester.getSize(find.byType(Text)).height,
          closeTo(measured, 0.5),
        );
        expect(style.inherit, isFalse);
      },
    );
  });

  group('readerStripDuplicateTitle', () {
    test('readerStripDuplicateTitle_givenTheTitleOnTheFirstLine_dropsIt', () {
      // 源站常见形状：正文第一行就是章节名（上游 `ContentProcessor` 也删这一行）。
      final String body = readerStripDuplicateTitle(
        '第1章 开端\n第一段正文\n第二段正文',
        title: '第1章 开端',
        bookName: '剑来',
      );

      expect(body, '第一段正文\n第二段正文');
    });

    test(
      'readerStripDuplicateTitle_givenPunctuationAndSpaces_stillDropsIt',
      () {
        final String body = readerStripDuplicateTitle(
          '  【第1章 开端】  \n第一段正文',
          title: '第 1 章 开端',
          bookName: '剑来',
        );

        expect(body, '第一段正文');
      },
    );

    test('readerStripDuplicateTitle_givenTheBookNameInFront_dropsIt', () {
      final String body = readerStripDuplicateTitle(
        '剑来 第1章 开端\n第一段正文',
        title: '第1章 开端',
        bookName: '剑来',
      );

      expect(body, '第一段正文');
    });

    test('readerStripDuplicateTitle_givenBlankLinesFirst_dropsTheTitleToo', () {
      final String body = readerStripDuplicateTitle(
        '\n\n第1章 开端\n第一段正文',
        title: '第1章 开端',
        bookName: '剑来',
      );

      expect(body.trim(), '第一段正文');
    });

    test('readerStripDuplicateTitle_givenADifferentFirstLine_keepsTheBody', () {
      const String body = '第一段正文\n第1章 开端';
      expect(
        readerStripDuplicateTitle(body, title: '第1章 开端', bookName: '剑来'),
        body,
      );
    });

    test(
      'readerStripDuplicateTitle_givenALineStartingWithTheTitle_keepsIt',
      () {
        // 只是以标题开头的一行正文：留着比吃掉安全。
        const String body = '第1章 开端那一天下着雨\n第一段正文';
        expect(
          readerStripDuplicateTitle(body, title: '第1章 开端', bookName: '剑来'),
          body,
        );
      },
    );

    test('readerStripDuplicateTitle_givenNoTitle_keepsTheBody', () {
      const String body = '第一段正文';
      expect(
        readerStripDuplicateTitle(body, title: '   ', bookName: '剑来'),
        body,
      );
      expect(
        readerStripDuplicateTitle(body, title: '第1章', bookName: '剑来'),
        body,
      );
    });

    test('readerStripDuplicateTitle_givenAnEmptyBody_keepsIt', () {
      expect(readerStripDuplicateTitle('', title: '第1章', bookName: '剑来'), '');
    });
  });

  group('readerChapterTitleStyle', () {
    testWidgets('readerChapterTitleStyle_givenTheTheme_takesItsColourOnly', (
      WidgetTester tester,
    ) async {
      const Color foreground = Color(0xFF112233);
      late TextStyle style;
      late double gap;
      await _pumpThemed(
        tester,
        Builder(
          builder: (BuildContext context) {
            final M3ETheme tokens = context.m3e;
            style = readerChapterTitleStyle(
              tokens: tokens,
              foreground: foreground,
              bodyFontSize: 16,
            );
            gap = readerChapterTitleGap(tokens);

            return const SizedBox.shrink();
          },
        ),
      );

      // 章头只换色：字号/字重仍由主题给，页表也是按这个样式量的（ADR-0087 §决策 3）。
      expect(style.color, foreground);
      expect(style.fontWeight, tokensTitleWeight(tester));
      expect(gap, greaterThan(0));
      // 样式必须是**已定型**的：`Text` 不再去并环境里的 `DefaultTextStyle`，否则量到的高度与
      // 画出来的高度会差一行（真机上就是整页 RenderFlex 溢出）。
      expect(style.inherit, isFalse);
      expect(style.fontSize, isNotNull);
    });
  });
}

/// The weight the theme gives the chapter heading.
FontWeight? tokensTitleWeight(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(Scaffold));

  return context.m3e.typography.base.titleMedium?.fontWeight;
}
