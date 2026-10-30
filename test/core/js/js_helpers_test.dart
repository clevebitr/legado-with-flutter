import 'package:flutter_reader/core/js/js_helpers.dart';
import 'package:flutter_reader/core/js/zh_converter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Calls one helper op with the given tables.
Object? _call(
  Map<String, Object?> args, {
  ZhConverter? t2s,
  ZhConverter? s2t,
}) => applyJsHelperCall(args, JsHelperContext(t2s: t2s, s2t: s2t));

String _text(Object? answer) => answer as String;

/// The message of a failure envelope; fails the test when [answer] is not one.
String _error(Object? answer) {
  expect(answer, isA<Map<Object?, Object?>>());
  final Map<Object?, Object?> envelope = answer as Map<Object?, Object?>;

  return envelope[jsHelperErrorKey] as String;
}

void main() {
  group('randomUuid', () {
    test('randomUuid_givenNoInput_looksLikeAVersion4Uuid', () {
      final String uuid = randomUuid();

      expect(
        uuid,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(uuid, isNot(randomUuid()));
    });

    test('applyJsHelperCall_givenRandomUuid_answersTheSameShape', () {
      expect(
        _text(_call(<String, Object?>{'operation': 'randomUUID'})),
        hasLength(36),
      );
    });
  });

  group('timeFormatUTC', () {
    test('formatUtcTime_givenAnOffset_shiftsTheClock', () {
      // 2026-10-26T00:30:00Z：+8 就是 08:30。
      final int ms = DateTime.utc(2026, 10, 26, 0, 30).millisecondsSinceEpoch;

      expect(formatUtcTime('$ms', 'yyyy/MM/dd HH:mm', 8), '2026/10/26 08:30');
      expect(formatUtcTime('$ms', 'yyyy-MM-dd', -5), '2026-10-25');
    });

    test('formatUtcTime_givenSingleLetterPatterns_doesNotPad', () {
      final int ms = DateTime.utc(2026, 1, 2, 3, 4, 5).millisecondsSinceEpoch;

      expect(formatUtcTime('$ms', 'y/M/d H:m:s', 0), '2026/1/2 3:4:5');
      expect(formatUtcTime('$ms', 'HH:mm:ss', 0), '03:04:05');
    });

    test('formatUtcTime_givenAMonthPattern_padsToThePatternWidth', () {
      final int ms = DateTime.utc(2026, 1, 2, 3, 4, 5).millisecondsSinceEpoch;

      expect(formatUtcTime('$ms', 'MM', 0), '01');
      expect(formatUtcTime('$ms', 'yy', 0), '26');
    });

    test('formatUtcTime_givenQuotedLiteral_keepsItVerbatim', () {
      final int ms = DateTime.utc(2026, 10, 26, 0, 0).millisecondsSinceEpoch;

      expect(formatUtcTime('$ms', "'第'yyyy'年'", 0), '第2026年');
      expect(formatUtcTime('$ms', "''yyyy", 0), "'2026");
    });

    test('formatUtcTime_givenAnUnknownLetter_copiesItThrough', () {
      final int ms = DateTime.utc(2026, 10, 26, 0, 0).millisecondsSinceEpoch;

      expect(formatUtcTime('$ms', 'yyyy Q', 0), '2026 Q');
    });

    test('applyJsHelperCall_givenATimestamp_formatsIt', () {
      final int ms = DateTime.utc(2026, 10, 26, 0, 30).millisecondsSinceEpoch;

      expect(
        _call(<String, Object?>{
          'operation': 'timeFormatUTC',
          'value': '$ms',
          'format': 'yyyy/MM/dd HH:mm',
          'sh': 8,
        }),
        '2026/10/26 08:30',
      );
    });

    test('applyJsHelperCall_givenGarbage_reportsIt', () {
      expect(
        _error(
          _call(<String, Object?>{
            'operation': 'timeFormatUTC',
            'value': 'yesterday',
            'format': 'yyyy',
            'sh': 0,
          }),
        ),
        contains('expects a timestamp'),
      );
    });
  });

  group('toNumChapter', () {
    test('toNumChapter_givenChineseNumerals_rewritesTheNumber', () {
      expect(toNumChapter('第一百二十三章 风起'), '第123章 风起');
      expect(toNumChapter('第12章'), '第12章');
      expect(toNumChapter('第十二章'), '第12章');
      expect(toNumChapter('第两千零一章'), '第2001章');
    });

    test('toNumChapter_givenFullWidthDigits_convertsThem', () {
      expect(toNumChapter('第１２３章'), '第123章');
    });

    test('toNumChapter_givenNoChapterMarker_keepsTheText', () {
      expect(toNumChapter('序章 开始'), '序章 开始');
      expect(toNumChapter('第x章'), '第x章');
    });

    test('chineseNumeralToInt_givenUnits_answersTheValue', () {
      expect(chineseNumeralToInt('一'), 1);
      expect(chineseNumeralToInt('十'), 10);
      expect(chineseNumeralToInt('十二'), 12);
      expect(chineseNumeralToInt('二十'), 20);
      expect(chineseNumeralToInt('一百零五'), 105);
      expect(chineseNumeralToInt('一万二千三百'), 12300);
      expect(chineseNumeralToInt('一亿'), 100000000);
      // 纯数字不是「中文数字」：`toNumChapter` 会先试 `int.parse`，这个函数只管汉字。
      expect(chineseNumeralToInt('123'), isNull);
      expect(chineseNumeralToInt('abc'), isNull);
      expect(chineseNumeralToInt(''), isNull);
    });
  });

  group('toURL', () {
    test('parseSandboxUrl_givenAUrl_answersItsParts', () {
      final Map<String, Object?> parts = parseSandboxUrl(
        'https://a.test:8443/path/x?k=1&v=%E4%B8%AD&flag',
      );

      expect(parts['host'], 'a.test');
      expect(parts['origin'], 'https://a.test:8443');
      expect(parts['pathname'], '/path/x');
      expect(parts['searchParams'], <String, String>{
        'k': '1',
        'v': '中',
        'flag': '',
      });
    });

    test('parseSandboxUrl_givenNoPort_answersTheBareOrigin', () {
      expect(parseSandboxUrl('https://a.test/x')['origin'], 'https://a.test');
    });

    test('parseSandboxUrl_givenARelativePathAndABase_resolvesIt', () {
      final Map<String, Object?> parts = parseSandboxUrl(
        '/search?q=1',
        baseUrl: 'https://a.test/books/index.html',
      );

      expect(parts['host'], 'a.test');
      expect(parts['pathname'], '/search');
    });

    test('parseSandboxUrl_givenRelativeWithoutABase_reportsIt', () {
      expect(() => parseSandboxUrl('/search'), throwsA(isA<FormatException>()));
    });

    test('parseSandboxUrl_givenABrokenEscape_keepsTheRawValue', () {
      expect(
        parseSandboxUrl('https://a.test/?q=%E4')['searchParams'],
        <String, String>{'q': '%E4'},
      );
    });

    test('applyJsHelperCall_givenAUrl_answersTheParts', () {
      final Object? answer = _call(<String, Object?>{
        'operation': 'toURL',
        'value': 'https://a.test/x?k=v',
      });

      expect((answer as Map<Object?, Object?>)['host'], 'a.test');
    });
  });

  group('htmlFormat', () {
    test('formatKeepImg_givenTags_dropsThemAndKeepsParagraphs', () {
      expect(formatKeepImg('<div>第一段</div><p>第二段</p>'), '　　第一段\n　　第二段');
    });

    test('formatKeepImg_givenAnImage_keepsOnlyItsSrc', () {
      expect(
        formatKeepImg(
          '<p>前<img data-src="https://a.test/1.jpg" class="x">后</p>',
        ),
        '　　前<img src="https://a.test/1.jpg">后',
      );
    });

    test('formatKeepImg_givenAnImageWithOptions_keepsTheSuffix', () {
      expect(
        formatKeepImg(
          '<img src="https://a.test/1.jpg,{"headers":{"Referer":"x"}}">',
        ),
        '<img src="https://a.test/1.jpg,{"headers":{"Referer":"x"}}">',
      );
    });

    test('formatKeepImg_givenAnImageWithoutSrc_dropsIt', () {
      // 空 `<img>` 不留段落分隔（上游没有占位符，删标签后同样只剩正文）。
      expect(formatKeepImg('<img class="lazy"><p>正文</p>'), '　　正文');
    });

    test('formatKeepImg_givenEntitiesAndComments_normalisesThem', () {
      expect(
        formatKeepImg('&nbsp;&nbsp;甲<!-- 注释 --><br/>乙&thinsp;'),
        '　　甲\n　　乙',
      );
    });

    test('formatKeepImg_givenPlainText_copiesItThroughWithoutAnIndent', () {
      // 上游的缩进规则只作用于**行首空白**：纯文本没有段落结构，就原样返回。
      expect(formatKeepImg('正文'), '正文');
      expect(formatKeepImg(''), '');
    });
  });

  group('t2s / s2t', () {
    final ZhConverter table = ZhConverter.parse('瞭=了\n著=着\n裏=里\n');

    test('applyJsHelperCall_givenT2s_convertsIt', () {
      expect(
        _call(<String, Object?>{'operation': 't2s', 'value': '瞭著'}, t2s: table),
        '了着',
      );
    });

    test('applyJsHelperCall_givenS2t_convertsIt', () {
      expect(
        _call(<String, Object?>{'operation': 's2t', 'value': '里'}, s2t: table),
        '里',
      );
    });

    test('applyJsHelperCall_givenNoTable_reportsIt', () {
      expect(
        _error(_call(<String, Object?>{'operation': 't2s', 'value': '瞭'})),
        contains('conversion table did not load'),
      );
    });
  });

  group('protocol', () {
    test('applyJsHelperCall_givenMalformedInput_reportsIt', () {
      expect(
        _error(applyJsHelperCall('nope', const JsHelperContext())),
        contains('malformed'),
      );
      expect(
        _error(_call(<String, Object?>{'operation': 5})),
        contains('malformed'),
      );
      expect(
        _error(_call(<String, Object?>{'operation': 'nope'})),
        contains('is not a sandbox helper'),
      );
    });

    test('applyJsHelperCall_givenNonStringValue_stringifiesIt', () {
      expect(
        _call(<String, Object?>{'operation': 'toNumChapter', 'value': 12}),
        '12',
      );
    });
  });
}
