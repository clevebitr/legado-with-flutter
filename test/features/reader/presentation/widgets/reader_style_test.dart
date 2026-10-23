import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
