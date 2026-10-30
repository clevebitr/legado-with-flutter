import 'package:flutter_reader/features/book_source/domain/html_to_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('htmlToText', () {
    test('htmlToText_givenPlainText_returnsItUnchanged', () {
      // `@text` / `@textNodes` 的源不该为这次转换付任何代价（也不该被改写）。
      const String text = '第一段\n第二段';

      expect(htmlToText(text), text);
      expect(htmlToText(''), '');
    });

    test('htmlToText_givenParagraphs_answersOneLineEach', () {
      // 语料最常见的 `@html` 正文：`<p>` 段落 + `<br>` 换行。
      expect(
        htmlToText('<div id="content"><p>第一段</p><p>第二段<br>第三行</p></div>'),
        '第一段\n第二段\n第三行',
      );
    });

    test('htmlToText_givenInlineMarkup_stripsItAndKeepsTheText', () {
      expect(htmlToText('<p>他<b>很</b>高兴<em>地</em>说</p>'), '他很高兴地说');
    });

    test('htmlToText_givenScriptAndStyle_dropsTheirContent', () {
      // 脚本内容不是正文：留着会把 JS 代码印在页面上。
      expect(
        htmlToText(
          '<p>正文</p><script>var a = "<p>假的</p>";</script>'
          '<style>.a{color:red}</style>',
        ),
        '正文',
      );
    });

    test('htmlToText_givenCommentsAndDoctype_dropsThem', () {
      expect(htmlToText('<!DOCTYPE html><!-- 广告 --><p>正文</p>'), '正文');
    });

    test('htmlToText_givenEntities_decodesThem', () {
      expect(htmlToText('<p>&nbsp;第一段&amp;第二段&hellip;</p>'), '第一段&第二段…');
      expect(htmlToText('<p>&#32;&#x4E2D;</p>'), ' 中'.trim());
      expect(htmlToText('<p>&unknown;</p>'), '&unknown;');
    });

    test('htmlToText_givenIndentedMarkup_collapsesBlankLines', () {
      // 源站的缩进与空行是排版噪音，阅读端自己加段距（`readerBodyText`）。
      expect(htmlToText('  <p>  第一段  </p>\n\n\n  <p>第二段</p>  '), '第一段\n第二段');
    });

    test('htmlToText_givenAnUnclosedAngleBracket_keepsItAsText', () {
      expect(htmlToText('1 < 2 且 3 > 2'), '1 < 2 且 3 > 2');
      expect(htmlToText('<p>a < b</p>'), 'a < b');
    });

    test('htmlToText_givenAnAttributeWithAngleBrackets_doesNotBreak', () {
      expect(htmlToText('<p title="a>b">正文</p>'), '正文');
    });

    test('htmlToText_givenImages_dropsThem', () {
      // 阅读端是纯文本，图片没有落点（S6c 的字节通道才有）。
      expect(htmlToText('<p>前<img src="cover.jpg" alt="封面">后</p>'), '前后');
    });
  });
}
