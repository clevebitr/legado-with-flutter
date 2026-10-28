import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
import 'package:flutter_test/flutter_test.dart';

/// A body long enough to need several pages at the size the tests use.
String _longText([int lines = 120]) => <String>[
  for (var index = 0; index < lines; index++) '第${index + 1}行：正文内容用于分页测量。',
].join('\n');

/// The page size the cases measure against.
const Size _size = Size(300, 400);

/// The style the cases measure with.
const TextStyle _style = TextStyle(fontSize: 16, height: 1.5);

void main() {
  group('readerPageStarts', () {
    test('readerPageStarts_givenAnEmptyText_answersOnlyTheFirstPage', () {
      expect(
        readerPageStarts(
          text: '',
          style: _style,
          size: _size,
          textScaler: TextScaler.noScaling,
        ),
        <int>[0],
      );
    });

    test('readerPageStarts_givenAShortText_answersOnlyTheFirstPage', () {
      // 一页装得下的正文不该被切出第二页。
      expect(
        readerPageStarts(
          text: '短短一行',
          style: _style,
          size: _size,
          textScaler: TextScaler.noScaling,
        ),
        <int>[0],
      );
    });

    test('readerPageStarts_givenALongText_splitsItIntoIncreasingPages', () {
      final String text = _longText();
      final List<int> starts = readerPageStarts(
        text: text,
        style: _style,
        size: _size,
        textScaler: TextScaler.noScaling,
      );

      expect(starts.length, greaterThan(1));
      expect(starts.first, 0);
      // 每页起点严格递增且落在正文范围内：既不会倒着切，也不会越界。
      for (var index = 1; index < starts.length; index++) {
        expect(starts[index], greaterThan(starts[index - 1]));
        expect(starts[index], lessThan(text.length));
      }
    });

    test('readerPageStarts_givenAZeroSizedBox_answersOnlyTheFirstPage', () {
      // 布局还没算出来时（宽或高为 0）不能死循环，也不能声称切出了页。
      expect(
        readerPageStarts(
          text: _longText(),
          style: _style,
          size: Size.zero,
          textScaler: TextScaler.noScaling,
        ),
        <int>[0],
      );
    });

    test('readerPageStarts_givenALargerTextScale_makesMorePages', () {
      // 字号变大页面变多：分页是按布局量出来的，不是按字符数估的（ADR-0044 §决策 4）。
      final String text = _longText();
      final int plain = readerPageStarts(
        text: text,
        style: _style,
        size: _size,
        textScaler: TextScaler.noScaling,
      ).length;
      final int scaled = readerPageStarts(
        text: text,
        style: _style,
        size: _size,
        textScaler: const TextScaler.linear(2),
      ).length;

      expect(scaled, greaterThan(plain));
    });
  });

  group('readerTextHeight', () {
    test('readerTextHeight_givenAnEmptyText_answersZero', () {
      expect(
        readerTextHeight(
          text: '',
          style: _style,
          width: _size.width,
          textScaler: TextScaler.noScaling,
        ),
        0,
      );
    });

    test('readerTextHeight_givenNoWidth_answersZero', () {
      // 布局还没算出来时不能量出一个「一列排下来」的假高度。
      expect(
        readerTextHeight(
          text: _longText(),
          style: _style,
          width: 0,
          textScaler: TextScaler.noScaling,
        ),
        0,
      );
    });

    test('readerTextHeight_givenMoreLines_answersMoreHeight', () {
      final double short = readerTextHeight(
        text: _longText(4),
        style: _style,
        width: _size.width,
        textScaler: TextScaler.noScaling,
      );
      final double tall = readerTextHeight(
        text: _longText(40),
        style: _style,
        width: _size.width,
        textScaler: TextScaler.noScaling,
      );

      expect(short, greaterThan(0));
      expect(tall, greaterThan(short));
    });

    test('readerTextHeight_givenALargerTextScale_answersMoreHeight', () {
      final double plain = readerTextHeight(
        text: _longText(10),
        style: _style,
        width: _size.width,
        textScaler: TextScaler.noScaling,
      );
      final double scaled = readerTextHeight(
        text: _longText(10),
        style: _style,
        width: _size.width,
        textScaler: const TextScaler.linear(2),
      );

      expect(scaled, greaterThan(plain));
    });
  });

  group('readerPageOf', () {
    test('readerPageOf_givenAnOffsetOnTheFirstPage_answersZero', () {
      expect(readerPageOf(<int>[0, 100, 200], 0), 0);
      expect(readerPageOf(<int>[0, 100, 200], 99), 0);
    });

    test('readerPageOf_givenAnOffsetOnALaterPage_answersThatPage', () {
      expect(readerPageOf(<int>[0, 100, 200], 100), 1);
      expect(readerPageOf(<int>[0, 100, 200], 250), 2);
    });

    test('readerPageOf_givenAnOffsetPastTheEnd_answersTheLastPage', () {
      expect(readerPageOf(<int>[0, 100, 200], 9999), 2);
    });
  });
}
