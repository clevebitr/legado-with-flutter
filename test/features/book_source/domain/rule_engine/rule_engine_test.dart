import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:logger/logger.dart';

import '../../../../support/fake_log_printer.dart';

/// A search result page shaped like the target of default-rule selectors
/// (matrix #1 / #2): three list items with a title link and an author.
const String _listHtml =
    '<ul class="result-list">'
    '<li class="result"><a class="title" href="/book/1">One</a> '
    '<span class="author">Author A</span></li>'
    '<li class="result"><a class="title" href="/book/2">Two</a> '
    '<span class="author">Author B</span></li>'
    '<li class="result"><a class="title" href="/book/3">Three</a> '
    '<span class="author">Author C</span></li>'
    '</ul>';

/// A chapter page: nested text, a script, a style, a blank attribute, duplicate
/// attribute values and an element without text.
const String _chapterHtml =
    '<div id="content">'
    '<p class="line">First <b>bold</b> tail</p>'
    '<p class="line">Second</p>'
    '<script>var x = 1;</script><style>.a{color:red}</style>'
    '<img src="/img/1.png" alt=" "/>'
    '<i class="empty"></i>'
    '<span class="dupe" data-x="same"></span>'
    '<span class="dupe" data-x="same"></span>'
    '</div>';

/// A page whose text is used to exercise the `##` replacement (matrix #9).
const String _countHtml =
    '<p class="count">共 123 字</p><p class="raw">xa(by</p>';

/// Rules that must be reported as `unsupportedRule` whichever method evaluates
/// them, with the syntax name `rulePath` has to carry
/// (`docs/dev/book-source.md` §7).
const Map<String, String> _unsupportedRules = <String, String>{
  '@js:result': 'unsupported:@js:',
  '@json:\$.data': 'unsupported:@json:',
  '@xpath://div': 'unsupported:@xpath:',
  '@put:{a:1}': 'unsupported:@put:',
  '@get:{a}': 'unsupported:@get:',
  '@webJs': 'unsupported:@webJs',
  '@@class.a': 'unsupported:@@',
  '{{result}}': 'unsupported:{{',
  '//div': 'unsupported://',
  r'$.data.list': r'unsupported:$.',
  r'{$.data}': 'unsupported:{',
  ':regex': 'unsupported::',
  'class.a||class.b': 'unsupported:||',
  'class.a&&class.b': 'unsupported:&&',
  'class.a%%class.b': 'unsupported:%%',
  // 矩阵 #7 的 `-` 先摘掉再识别标志头，所以标志头的报错保持原样（不能被 `-` 顶掉）。
  '-@js:result': 'unsupported:@js:',
  // 矩阵 #15：中段 `@@`（`@` 切分后留空段，必须在切段前判掉，否则误报畸形）。
  'class.a@@class.b@text': 'unsupported:@@',
};

/// Selector segments that carry syntax a later phase of the matrix owns.
///
/// The tests wrap them into a list rule and into a value rule, because the last
/// segment of a value rule is the extraction and is therefore never a selector.
const Map<String, String> _unsupportedSelectors = <String, String>{
  // 段内（非规则开头）的标志头：body 级检查只覆盖规则开头，中间段由选择器层拒绝。
  'json:\$.data': 'unsupported:@json:',
  // 字母段里的 `!` 不是索引写法（矩阵 #6 的 `!` 只跟在名称后）：整段退化成未知类型。
  'li!0': 'unsupported:li!0',
  // 名称里的 `:` 不属于任何已实现写法（矩阵 #6 的 `:` 只在 `!` 列表与位置段内）。
  'tag.a:b': 'unsupported::',
  'div.item': 'unsupported:div',
};

/// Selector segments that are structurally broken, so `rulePath` stays the field
/// path (matrix #1 / #5).
///
/// A single-segment *value* rule is an attribute name, not a broken selector, so
/// these are wrapped into a multi-segment rule where that distinction matters.
const List<String> _malformedSelectors = <String>[
  'class.',
  'tag',
  'class.a.b',
  'class.a.0.1',
  // 矩阵 #3：`text` 必须带名称（第二段是文本内容的一部分）。
  'text.',
  // 矩阵 #6 / #26 的结构性畸形：空列表、未闭合、非整数、步长为 0、
  // `!` 写在位置段（上游在那里抛 NumberFormatException，issue #432）、
  // 两种位置写法同时出现、只有 `-` 而没有选择器。
  'tag.li!',
  'tag.li!x',
  'tag.dl.!0',
  'tag.li[]',
  'tag.li[x]',
  'tag.li[0',
  'tag.li[0:1:2:3]',
  'tag.li[0:1:x]',
  'tag.li[0:2:0]',
  'tag.div[-1].0',
  // 矩阵 #28 的结构性畸形：空类型但不是索引、索引里混进字符、未闭合、多段索引。
  '.',
  '.li',
  '.1.2',
  '[1',
  '[x]',
  '!x',
  // `]` 而没有 `[`（`div]` 会被当作挂在类型上的索引写法，另归 unsupported）。
  'tag.div]',
  '-',
];

/// An engine with a capturing logger, so a test can assert the C-SRC-4 record.
RuleEngine _engine([FakeLogPrinter? printer]) => RuleEngine(
  logger: AppLogger(
    level: LogLevel.debug,
    printer: printer ?? FakeLogPrinter(),
  ),
);

/// Parses [html]; every rule below is evaluated against the result.
Document _document(String html) => parser.parse(html);

/// Returns the data of a successful element result, failing the test otherwise.
List<Element> _elements(ParseResult<List<Element>> result) => switch (result) {
  ParseSuccess<List<Element>>(:final List<Element> data) => data,
  ParseFailure<List<Element>>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns the data of a successful value result, failing the test otherwise.
List<String> _values(ParseResult<List<String>> result) => switch (result) {
  ParseSuccess<List<String>>(:final List<String> data) => data,
  ParseFailure<List<String>>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns the data of a successful single-value result.
String? _first(ParseResult<String?> result) => switch (result) {
  ParseSuccess<String?>(:final String? data) => data,
  ParseFailure<String?>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns the failure of [result], failing the test when it succeeded.
///
/// Rebuilt as `ParseFailure<Never>` so one helper serves every result type.
ParseFailure<Never> _failure<T>(ParseResult<T> result) => switch (result) {
  ParseFailure<T>(:final ParseFailureKind kind, :final String rulePath) =>
    ParseFailure<Never>(kind: kind, rulePath: rulePath),
  ParseSuccess<T>() => fail('Expected a failure.'),
};

/// The `href` of every match of `class.result-list@<segment>@tag.a`.
///
/// The list page has three items, so a position test can tell an index list's
/// authored order (matrix #26) from an ascending sort.
List<String?> _hrefsFor(String segment) => _elements(
  _engine().selectAll(
    'class.result-list@$segment@tag.a',
    _document(_listHtml),
    rulePath: 'searchRule.bookUrl',
  ),
).map((Element element) => element.attributes['href']).toList();

/// The `href` of every match of `class.result-list@tag.li<position>@tag.a`.
List<String?> _hrefsForList(String position) => _hrefsFor('tag.li$position');

void main() {
  group('RuleEngine selectAll', () {
    test('selectAll_givenClassThenTagRule_returnsEveryMatch', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          'class.result-list@tag.li',
          _document(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(3));
      expect(
        elements.map((Element element) => element.localName),
        everyElement('li'),
      );
    });

    test('selectAll_givenTagRule_returnsEveryMatchInTheDocument', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          'tag.li',
          _document(_listHtml),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(3));
    });

    test('selectAll_givenIdRule_returnsTheElementWithThatId', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          'id.content@tag.p',
          _document(_chapterHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(2));
      expect(elements.first.text, contains('First'));
    });

    test('selectAll_givenPositiveIndex_returnsThatMatch', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          'class.result-list@tag.li.0',
          _document(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.text, contains('One'));
    });

    test('selectAll_givenNegativeIndex_returnsTheLastMatch', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          'class.result-list@tag.li.-1',
          _document(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.text, contains('Three'));
    });

    test('selectAll_givenIndexBeyondTheMatches_returnsNothing', () {
      final Document document = _document(_listHtml);

      expect(
        _elements(
          _engine().selectAll(
            'class.result-list@tag.li.9',
            document,
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
      expect(
        _elements(
          _engine().selectAll(
            'class.result-list@tag.li.-9',
            document,
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
    });

    test('selectAll_givenScopeMatchingTheSelector_includesTheScopeItself', () {
      final Element scope = _document(_listHtml).querySelectorAll('li').first;

      final List<Element> elements = _elements(
        _engine().selectAll(
          'class.result',
          scope,
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single, same(scope));
    });

    test('selectAll_givenBlankRule_returnsNoElements', () {
      expect(
        _elements(
          _engine().selectAll(
            '   ',
            _document(_listHtml),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
    });

    test('selectAll_givenRuleWithoutMatch_succeedsWithNoElements', () {
      expect(
        _elements(
          _engine().selectAll(
            'class.absent@tag.li',
            _document(_listHtml),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
    });

    test('selectAll_givenUnsupportedSyntax_returnsUnsupportedRule', () {
      final Document document = _document(_listHtml);
      final Map<String, String> rules = <String, String>{
        ..._unsupportedRules,
        for (final MapEntry<String, String> entry
            in _unsupportedSelectors.entries)
          'class.a@${entry.key}': entry.value,
      };

      for (final MapEntry<String, String> entry in rules.entries) {
        final ParseFailure<Never> failure = _failure(
          _engine().selectAll(
            entry.key,
            document,
            rulePath: 'searchRule.bookList',
          ),
        );

        expect(
          failure.kind,
          ParseFailureKind.unsupportedRule,
          reason: entry.key,
        );
        expect(failure.rulePath, entry.value, reason: entry.key);
      }
    });

    test('selectAll_givenMalformedSelector_returnsParseFailedAtTheField', () {
      final Document document = _document(_listHtml);

      for (final String rule in <String>[..._malformedSelectors, 'class.a@']) {
        final ParseFailure<Never> failure = _failure(
          _engine().selectAll(rule, document, rulePath: 'searchRule.bookList'),
        );

        expect(failure.kind, ParseFailureKind.parseFailed, reason: rule);
        expect(failure.rulePath, 'searchRule.bookList', reason: rule);
      }
    });

    test('selectAll_givenRejectedRule_logsTheFieldAndTheSyntax', () {
      final FakeLogPrinter printer = FakeLogPrinter();

      _engine(printer).selectAll(
        '@js:result',
        _document(_listHtml),
        rulePath: 'searchRule.name',
      );

      expect(printer.events, hasLength(1));
      expect(printer.events.single.level, Level.warning);
      expect(
        printer.events.single.message.toString(),
        contains('searchRule.name'),
      );
      expect(
        printer.events.single.message.toString(),
        contains('unsupported:@js:'),
      );
    });
  });

  group('RuleEngine extractAll', () {
    test('extractAll_givenTextExtraction_collapsesWhitespace', () {
      final List<String> values = _values(
        _engine().extractAll(
          'class.result-list@tag.li.0@text',
          _document(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, <String>['One Author A']);
    });

    test('extractAll_givenTextNodesExtraction_returnsDirectTextNodes', () {
      final List<String> values = _values(
        _engine().extractAll(
          'class.line.0@textNodes',
          _document(_chapterHtml),
          rulePath: 'contentRule.content',
        ),
      );

      expect(values, <String>['First\ntail']);
    });

    test('extractAll_givenOwnTextExtraction_ignoresNestedText', () {
      final List<String> values = _values(
        _engine().extractAll(
          'class.line.0@ownText',
          _document(_chapterHtml),
          rulePath: 'contentRule.content',
        ),
      );

      expect(values, <String>['First tail']);
    });

    test('extractAll_givenHtmlExtraction_dropsScriptAndStyle', () {
      final List<String> values = _values(
        _engine().extractAll(
          'id.content@html',
          _document(_chapterHtml),
          rulePath: 'contentRule.content',
        ),
      );

      expect(
        values.single,
        contains('<p class="line">First <b>bold</b> tail</p>'),
      );
      expect(values.single, isNot(contains('<script>')));
      expect(values.single, isNot(contains('<style>')));
    });

    test('extractAll_givenAllExtraction_keepsScriptAndStyle', () {
      final List<String> values = _values(
        _engine().extractAll(
          'id.content@all',
          _document(_chapterHtml),
          rulePath: 'contentRule.content',
        ),
      );

      expect(values.single, contains('<script>'));
      expect(values.single, contains('<style>'));
    });

    test('extractAll_givenHtmlExtraction_leavesTheDocumentUntouched', () {
      final Document document = _document(_chapterHtml);

      _values(
        _engine().extractAll(
          'id.content@html',
          document,
          rulePath: 'contentRule.content',
        ),
      );

      // 上游是在活 DOM 上删 script/style；引擎必须只改副本（C-SRC-9）。
      expect(document.querySelectorAll('script'), hasLength(1));
      expect(document.querySelectorAll('style'), hasLength(1));
    });

    test('extractAll_givenAttributeExtraction_returnsEveryValue', () {
      final List<String> values = _values(
        _engine().extractAll(
          'tag.a@href',
          _document(_listHtml),
          rulePath: 'searchRule.bookUrl',
        ),
      );

      expect(values, <String>['/book/1', '/book/2', '/book/3']);
    });

    test('extractAll_givenMissingAttribute_returnsNothing', () {
      expect(
        _values(
          _engine().extractAll(
            'tag.a@src',
            _document(_listHtml),
            rulePath: 'searchRule.coverUrl',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenBlankAttribute_returnsNothing', () {
      expect(
        _values(
          _engine().extractAll(
            'tag.img@alt',
            _document(_chapterHtml),
            rulePath: 'searchRule.coverUrl',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenDuplicateAttributeValues_dropsDuplicates', () {
      final List<String> values = _values(
        _engine().extractAll(
          'class.dupe@data-x',
          _document(_chapterHtml),
          rulePath: 'searchRule.bookUrl',
        ),
      );

      expect(values, <String>['same']);
    });

    test('extractAll_givenElementWithoutText_skipsTheEmptyValue', () {
      expect(
        _values(
          _engine().extractAll(
            'class.empty@text',
            _document(_chapterHtml),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenExtractionOnlyRule_extractsFromTheScope', () {
      final Element scope = _document(_listHtml).querySelectorAll('a').first;

      final List<String> values = _values(
        _engine().extractAll('href', scope, rulePath: 'searchRule.bookUrl'),
      );

      expect(values, <String>['/book/1']);
    });

    test('extractAll_givenRuleWithoutMatch_succeedsWithNoValues', () {
      expect(
        _values(
          _engine().extractAll(
            'class.absent@text',
            _document(_listHtml),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenUnsupportedSyntax_returnsUnsupportedRule', () {
      final Document document = _document(_listHtml);
      final Map<String, String> rules = <String, String>{
        ..._unsupportedRules,
        for (final MapEntry<String, String> entry
            in _unsupportedSelectors.entries)
          'class.a@${entry.key}@text': entry.value,
      };

      for (final MapEntry<String, String> entry in rules.entries) {
        final ParseFailure<Never> failure = _failure(
          _engine().extractAll(
            entry.key,
            document,
            rulePath: 'searchRule.name',
          ),
        );

        expect(
          failure.kind,
          ParseFailureKind.unsupportedRule,
          reason: entry.key,
        );
        expect(failure.rulePath, entry.value, reason: entry.key);
      }
    });

    test('extractAll_givenANestedRuleInTheExtractionPosition_returnsUnsupportedRule', () {
      // 值规则的末段是提取段，上游在那里允许嵌套规则（矩阵 #30，M2/暂不实现）。
      // 它必须报**可区分**的名字：中段的 `@css:` 已支持，末段仍未支持（F3）。
      final ParseFailure<Never> failure = _failure(
        _engine().extractAll(
          'class.a@css:.b',
          _document(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:nested-rule');
    });

    test('extractAll_givenMalformedRule_returnsParseFailedAtTheField', () {
      final Document document = _document(_listHtml);
      final List<String> rules = <String>[
        for (final String selector in _malformedSelectors) '$selector@text',
        // 末段为空：上游同样取不到值，但那是畸形而不是「不支持的语法」。
        'class.a@',
      ];

      for (final String rule in rules) {
        final ParseFailure<Never> failure = _failure(
          _engine().extractAll(rule, document, rulePath: 'searchRule.name'),
        );

        expect(failure.kind, ParseFailureKind.parseFailed, reason: rule);
        expect(failure.rulePath, 'searchRule.name', reason: rule);
      }
    });

    test('extractAll_givenSingleSegmentRule_treatsItAsAnAttributeName', () {
      // 上游语义：值规则的末段永远是提取段，所以单段规则是属性名而不是选择器；
      // 取不到值时是「成功但为空」，不能报成畸形规则。
      expect(
        _values(
          _engine().extractAll(
            'class.a.b',
            _document(_listHtml),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('RuleEngine ## replacement', () {
    test('extractAll_givenReplacementWithoutItsSecondPart_deletesTheMatch', () {
      final List<String> values = _values(
        _engine().extractAll(
          r'class.count@text##共\s*',
          _document(_countHtml),
          rulePath: 'searchRule.wordCount',
        ),
      );

      expect(values, <String>['123 字']);
    });

    test(
      'extractAll_givenGroupReferenceInTheReplacement_substitutesTheGroup',
      () {
        final List<String> values = _values(
          _engine().extractAll(
            r'class.count@text##共\s*(\d+)\s*字##$1',
            _document(_countHtml),
            rulePath: 'searchRule.wordCount',
          ),
        );

        expect(values, <String>['123']);
      },
    );

    test('extractAll_givenNamedGroupReference_substitutesTheNamedGroup', () {
      final List<String> values = _values(
        _engine().extractAll(
          r'class.count@text##(?<n>\d+)##[${n}]',
          _document(_countHtml),
          rulePath: 'searchRule.wordCount',
        ),
      );

      expect(values, <String>['共 [123] 字']);
    });

    test(
      'extractAll_givenEscapedCharacterInTheReplacement_keepsItLiterally',
      () {
        final List<String> values = _values(
          _engine().extractAll(
            r'class.count@text##(\d+)##\1',
            _document(_countHtml),
            rulePath: 'searchRule.wordCount',
          ),
        );

        expect(values, <String>['共 1 字']);
      },
    );

    test('extractAll_givenUncompilablePattern_replacesLiterally', () {
      final List<String> values = _values(
        _engine().extractAll(
          'class.raw@text##a(b##X',
          _document(_countHtml),
          rulePath: 'searchRule.wordCount',
        ),
      );

      expect(values, <String>['xXy']);
    });

    test('extractAll_givenDollarThatIsNotAReference_keepsItLiterally', () {
      final Document document = _document(_countHtml);

      expect(
        _values(
          _engine().extractAll(
            r'class.count@text##123##$',
            document,
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>[r'共 $ 字'],
      );
      expect(
        _values(
          _engine().extractAll(
            r'class.count@text##123##${}',
            document,
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>[r'共 ${} 字'],
      );
      expect(
        _values(
          _engine().extractAll(
            r'class.count@text##123##${',
            document,
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>[r'共 ${ 字'],
      );
      expect(
        _values(
          _engine().extractAll(
            r'class.count@text##123##$a',
            document,
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>[r'共 $a 字'],
      );
    });

    test('extractAll_givenReplacement_appliesItToEveryValue', () {
      final List<String> values = _values(
        _engine().extractAll(
          r'class.result-list@tag.li@text##\s*Author [ABC]',
          _document(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, <String>['One', 'Two', 'Three']);
    });

    test('extractAll_givenFourPartReplacement_returnsTheFirstMatchOnly', () {
      // 上游 `##match##replace###`（AnalyzeRule.kt:497）不是「替换整串里的第一个」：
      // 它取第一个**匹配**，只在该匹配内部做替换，因此结果是 `123` 而不是 `共 123 字`。
      expect(
        _values(
          _engine().extractAll(
            r'class.count@text##共\s*(\d+)\s*字##$1###',
            _document(_countHtml),
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>['123'],
      );
    });

    test(
      'extractAll_givenFourPartReplacementWithoutMatch_keepsAnEmptyValue',
      () {
        // 上游：无匹配时该分支返回空串；空串是「替换后的结果」，不再是提取阶段能丢掉的东西。
        expect(
          _values(
            _engine().extractAll(
              'class.count@text##absent##X###',
              _document(_countHtml),
              rulePath: 'searchRule.wordCount',
            ),
          ),
          <String>[''],
        );
      },
    );

    test('extractAll_givenFourPartReplacementWithAnUncompilablePattern_returnsTheReplacement', () {
      // 上游：正则不可编译时，`replaceFirst` 分支直接返回替换串本身。
      expect(
        _values(
          _engine().extractAll(
            'class.raw@text##a(b##X###',
            _document(_countHtml),
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>['X'],
      );
    });
  });

  group('RuleEngine extractFirst', () {
    test('extractFirst_givenSeveralMatches_returnsTheFirstValue', () {
      expect(
        _first(
          _engine().extractFirst(
            'tag.a@href',
            _document(_listHtml),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        '/book/1',
      );
    });

    test('extractFirst_givenNoMatch_returnsNullData', () {
      expect(
        _first(
          _engine().extractFirst(
            'class.absent@text',
            _document(_listHtml),
            rulePath: 'searchRule.intro',
          ),
        ),
        isNull,
      );
    });

    test('extractFirst_givenRejectedRule_returnsTheSameFailure', () {
      final ParseFailure<Never> failure = _failure(
        _engine().extractFirst(
          '@js:result',
          _document(_listHtml),
          rulePath: 'searchRule.intro',
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@js:');
    });
  });

  group('RuleEngine matrix #3 (text)', () {
    test('selectAll_givenTextRule_matchesTheElementHoldingThatText', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          'text.Second',
          _document(_chapterHtml),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.localName, 'p');
    });

    test('selectAll_givenTextRule_matchesOwnTextNotTheParentsText', () {
      // `b` 的自身文本是 `bold`，它的祖先（`p` / `#content`）自身文本里没有它，
      // 所以只命中 `b` 本身——上游用的是 getElementsContainingOwnText，
      // getElementsContainingText 会额外命中祖先。
      final List<Element> elements = _elements(
        _engine().selectAll(
          'text.bold',
          _document(_chapterHtml),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.localName, 'b');
    });

    test('selectAll_givenTextRuleAndAnElementScope_includesTheScopeItself', () {
      final Element scope = _document(_chapterHtml).querySelectorAll('p').first;

      final List<Element> elements = _elements(
        _engine().selectAll(
          'text.First',
          scope,
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single, same(scope));
    });

    test('selectAll_givenTextRule_isCaseInsensitive', () {
      expect(
        _elements(
          _engine().selectAll(
            'text.SECOND',
            _document(_chapterHtml),
            rulePath: 'tocRule.chapterList',
          ),
        ),
        hasLength(1),
      );
    });

    test('selectAll_givenTextRuleWithAPosition_takesThatMatch', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          'text.Author.-1',
          _document(_listHtml),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.text, 'Author C');
    });

    test('selectAll_givenTextRuleWithoutItsName_returnsParseFailed', () {
      // 矩阵 #3 的第二段是文本内容的一部分；只写 `text` 没有任何内容可匹配。
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          'text',
          _document(_chapterHtml),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'tocRule.chapterList');
    });
  });

  group('RuleEngine matrix #4 (children)', () {
    test('selectAll_givenChildrenRule_returnsTheDirectChildrenOnly', () {
      final Element scope = _document(_listHtml).querySelectorAll('ul').single;

      final List<Element> elements = _elements(
        _engine().selectAll('children', scope, rulePath: 'tocRule.chapterList'),
      );

      expect(elements, hasLength(3));
      expect(
        elements.map((Element element) => element.localName),
        everyElement('li'),
      );
      // 孙元素（`a` / `span`）不在结果里，范围元素自身也不在。
      expect(elements, isNot(contains(scope)));
    });

    test('selectAll_givenChildrenRuleWithExtraSegments_ignoresThem', () {
      final Element scope = _document(_listHtml).querySelectorAll('ul').single;

      // 矩阵 #4：`children` 取全部子标签，忽略第二、三段。
      expect(
        _elements(
          _engine().selectAll(
            'children.li.0',
            scope,
            rulePath: 'tocRule.chapterList',
          ),
        ),
        hasLength(3),
      );
    });

    test('extractAll_givenChildrenRule_chainsIntoTheNextSelector', () {
      final Element scope = _document(_listHtml).querySelectorAll('ul').single;

      expect(
        _values(
          _engine().extractAll(
            'children@tag.a@href',
            scope,
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/1', '/book/2', '/book/3'],
      );
    });
  });

  group('RuleEngine matrix #6 (! exclusion)', () {
    test('selectAll_givenExcludedIndex_dropsThatMatch', () {
      expect(_hrefsForList('!0'), <String?>['/book/2', '/book/3']);
    });

    test('selectAll_givenSeveralExcludedIndices_dropsThemAll', () {
      // 矩阵 #6：`!` 后面的序号用 `:` 隔开，负数为倒数序号。
      expect(_hrefsForList('!0:2'), <String?>['/book/2']);
      expect(_hrefsForList('!-1'), <String?>['/book/1', '/book/2']);
    });

    test('selectAll_givenExcludedIndexBeyondTheMatches_keepsEveryMatch', () {
      expect(_hrefsForList('!9'), <String?>['/book/1', '/book/2', '/book/3']);
    });

    test('extractAll_givenExclusionAndAnExtraction_returnsTheRest', () {
      expect(
        _values(
          _engine().extractAll(
            'class.result-list@tag.li!1@tag.a@href',
            _document(_listHtml),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/1', '/book/3'],
      );
    });
  });

  group('RuleEngine matrix #7 (leading dash)', () {
    test('selectAll_givenLeadingDash_reversesTheResultList', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          '-class.result-list@tag.li',
          _document(_listHtml),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(
        elements.map(
          (Element element) => element.querySelector('a')?.attributes['href'],
        ),
        <String?>['/book/3', '/book/2', '/book/1'],
      );
    });

    test('extractAll_givenLeadingDash_reversesTheValues', () {
      expect(
        _values(
          _engine().extractAll(
            '-class.result-list@tag.a@href',
            _document(_listHtml),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/3', '/book/2', '/book/1'],
      );
    });

    test('extractFirst_givenLeadingDash_returnsTheLastMatch', () {
      expect(
        _first(
          _engine().extractFirst(
            '-class.result-list@tag.a@href',
            _document(_listHtml),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        '/book/3',
      );
    });
  });

  group('RuleEngine matrix #26 (index list)', () {
    test('selectAll_givenABracketIndex_returnsThatMatch', () {
      expect(_hrefsForList('[-1]'), <String?>['/book/3']);
    });

    test('selectAll_givenSeveralBracketIndices_keepsTheAuthoredOrder', () {
      // 矩阵 #26：`[index,index,...]`，顺序按写法，不是升序。
      expect(_hrefsForList('[2,0]'), <String?>['/book/3', '/book/1']);
    });

    test('selectAll_givenABracketRange_returnsEveryIndexInsideIt', () {
      expect(_hrefsForList('[0:1]'), <String?>['/book/1', '/book/2']);
      // 上游规则文档：start 为 0 时可省略，end 为 -1 时可省略。
      expect(_hrefsForList('[:1]'), <String?>['/book/1', '/book/2']);
      expect(_hrefsForList('[1:]'), <String?>['/book/2', '/book/3']);
    });

    test('selectAll_givenABracketRangeWithStep_returnsEveryStep', () {
      expect(_hrefsForList('[0:2:2]'), <String?>['/book/1', '/book/3']);
      expect(_hrefsForList('[2:0:-1]'), <String?>[
        '/book/3',
        '/book/2',
        '/book/1',
      ]);
    });

    test('selectAll_givenADescendingRange_reversesTheMatches', () {
      // 上游规则文档的 `tag.div[-1:0]`：不写 step 时方向由两端决定。
      expect(_hrefsForList('[-1:0]'), <String?>[
        '/book/3',
        '/book/2',
        '/book/1',
      ]);
    });

    test('selectAll_givenExcludedBracketIndices_dropsThem', () {
      expect(_hrefsForList('[!0]'), <String?>['/book/2', '/book/3']);
      expect(_hrefsForList('[!1:2]'), <String?>['/book/1']);
    });

    test('selectAll_givenABracketIndexBeyondTheMatches_returnsNothing', () {
      expect(_hrefsForList('[9]'), isEmpty);
      expect(_hrefsForList('[-9]'), isEmpty);
    });

    test('selectAll_givenARangeStartingBeforeTheList_keepsTheRangeInside', () {
      // 负索引落到列表之前：端点会被夹到列表外一格，越界的部分直接丢掉。
      expect(_hrefsForList('[-9:0]'), <String?>['/book/1']);
    });

    test('selectAll_givenABracketRangeBeyondTheMatches_stopsAtTheListEnd', () {
      // 区间端点被夹到列表之外一格，书源写超大区间也不能把解析卡住（C-SRC-9）。
      expect(_hrefsForList('[0:999999]'), <String?>[
        '/book/1',
        '/book/2',
        '/book/3',
      ]);
    });
  });

  group('RuleEngine matrix #28 (index as the first rule of a segment)', () {
    test('selectAll_givenABareIndexSegment_usesTheDirectChildren', () {
      // 上游 doc：索引作为分段首规则时，相当于前面是 `children`。
      expect(_hrefsFor('[1]'), <String?>['/book/2']);
      expect(_hrefsFor('.1'), <String?>['/book/2']);
      expect(_hrefsFor('children[1]'), <String?>['/book/2']);
    });

    test('selectAll_givenTheThreeSpellings_agreeWithEachOther', () {
      // `.1` ≡ `[1]` ≡ `children[1]`（上游 doc 的等价式），也与 `children.1` 一致。
      expect(_hrefsFor('.1'), _hrefsFor('[1]'));
      expect(_hrefsFor('children[1]'), _hrefsFor('[1]'));
      expect(_hrefsFor('children.1'), _hrefsFor('[1]'));
    });

    test('selectAll_givenAnExcludedIndexSegment_dropsThatChild', () {
      expect(_hrefsFor('!0'), <String?>['/book/2', '/book/3']);
      expect(_hrefsFor('[!0]'), <String?>['/book/2', '/book/3']);
    });

    test('selectAll_givenAnIndexListSegment_keepsTheAuthoredOrder', () {
      expect(_hrefsFor('.0:2'), <String?>['/book/1', '/book/3']);
      expect(_hrefsFor('[0:1]'), <String?>['/book/1', '/book/2']);
    });

    test(
      'selectAll_givenChildrenWithASegmentName_keepsMatrixFourBehaviour',
      () {
        // `children.li.0` 不是索引写法：矩阵 #4 规定第二、三段被忽略。
        expect(_hrefsFor('children.li.0'), _hrefsFor('children'));
      },
    );
  });

  group('RuleEngine matrix #12 (@css:)', () {
    test('selectAll_givenCssRule_returnsEveryMatch', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          '@css:ul.result-list > li',
          _document(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(3));
      expect(
        elements.map((Element element) => element.localName),
        everyElement('li'),
      );
    });

    test('selectAll_givenAnUppercaseFlag_isTheSameRule', () {
      // book-source.md §3：前缀大小写不敏感。
      expect(
        _elements(
          _engine().selectAll(
            '@CSS:ul.result-list > li',
            _document(_listHtml),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(3),
      );
    });

    test('extractAll_givenCssRule_chainsIntoDefaultSegments', () {
      // `@css:` 段与默认规则段可以混用：先按 CSS 选中条目，再在其内部取属性。
      expect(
        _values(
          _engine().extractAll(
            '@css:ul.result-list > li@tag.a@href',
            _document(_listHtml),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/1', '/book/2', '/book/3'],
      );
    });

    test('extractAll_givenAnAttributeSelector_usesCascadia', () {
      expect(
        _values(
          _engine().extractAll(
            '@css:a[href="/book/2"]@text',
            _document(_listHtml),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['Two'],
      );
    });

    test('extractAll_givenAPseudoClassCascadiaSupports_matches', () {
      // 真实语料用的 `:contains` / `:containsOwn` 都在 cascadia 里，可直接用。
      // 注意：cascadia 不接受**带空格的不加引号参数**（`containsOwn(Author B)` 会报
      // Invalid argument），jsoup 则接受；真实语料的 `containsOwn(下一页)` 不带空格。
      expect(
        _values(
          _engine().extractAll(
            '@css:li:contains(Three)@tag.a@href',
            _document(_listHtml),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/3'],
      );
      expect(
        _values(
          _engine().extractAll(
            '@css:span:containsOwn(Author)@text',
            _document(_listHtml),
            rulePath: 'searchRule.author',
          ),
        ),
        <String>['Author A', 'Author B', 'Author C'],
      );
    });

    test('selectAll_givenAnIndexPseudo_matchesTheSiblingIndex', () {
      // 矩阵 #29：jsoup 的 `:eq(n)` 是**兄弟索引**，不是结果集索引。镜像 jsoup 自己的
      // SelectorTest.testPseudoEquals（`div p:eq(0)` 每个 div 各取一个 p）。
      final Document document = _document(
        '<div><p>One</p><p>Two</p></div><div><p>Four</p></div>',
      );

      expect(
        _values(
          _engine().extractAll(
            '@css:div p:eq(0)@text',
            document,
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One', 'Four'],
      );
    });

    test('selectAll_givenTheGreaterAndLessThanPseudos_takeTheSiblingRange', () {
      // jsoup 文档：`td:lt(3)` = 每行的前三个单元格，`td:gt(1)` = 跳过前两个。
      final Document document = _document(
        '<table><tr><td>1</td><td>2</td><td>3</td><td>4</td></tr></table>',
      );

      expect(
        _values(
          _engine().extractAll('@css:td:lt(3)@text', document, rulePath: 'x'),
        ),
        <String>['1', '2', '3'],
      );
      expect(
        _values(
          _engine().extractAll('@css:td:gt(1)@text', document, rulePath: 'x'),
        ),
        <String>['3', '4'],
      );
    });

    test('selectAll_givenANegativeIndexPseudo_returnsUnsupportedRule', () {
      // jsoup 文档把索引伪类定义为 0-based 且未定义负索引 → 本仓不猜，点名拒绝。
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          '@css:li:eq(-1)',
          _document(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported::eq(-1)');
    });

    test('selectAll_givenAnUnparsableIndexArgument_returnsParseFailed', () {
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          '@css:li:eq(99999999999999999999)',
          _document(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test(
      'selectAll_givenAStandardPseudoStartingWithTheSameLetters_isNotMisread',
      () {
        // `:first-child` 不能被当成 jsoup 的 `:first`（cascadia 支持标准伪类）。
        expect(
          _elements(
            _engine().selectAll(
              '@css:li:first-child',
              _document(_listHtml),
              rulePath: 'searchRule.bookList',
            ),
          ),
          hasLength(1),
        );
      },
    );

    test('selectAll_givenMalformedCss_returnsParseFailedAtTheField', () {
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          '@css:ul >',
          _document(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test('selectAll_givenAnEmptyCssSelector_returnsParseFailed', () {
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          '@css:',
          _document(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test('extractAll_givenTheFlagInAMiddleSegment_chainsThroughIt', () {
      // 中段的 `@css:`（`class.x@css:.y@text`）本次从 unsupported 变为可用：F1。
      expect(
        _values(
          _engine().extractAll(
            'class.result-list@css:li@tag.a@href',
            _document(_listHtml),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/1', '/book/2', '/book/3'],
      );
    });

    test('selectAll_givenAStatePseudoClass_succeedsWithNoMatch', () {
      // 静态 DOM 下没有元素处于 hover：cascadia 解析成功、匹配恒为 false。这是「正确
      // 答案」而不是错误，故登记为成功且为空（矩阵 #12 注记，架构师裁决 5）。
      expect(
        _elements(
          _engine().selectAll(
            '@css:a:hover',
            _document(_listHtml),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
    });
  });
}
