import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
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

/// A search response shaped like the target of `@json:` rules (matrix #13).
///
/// It carries a string, a number, a boolean, an empty string, `null`, a nested list
/// and a list of objects, so one fixture reaches every value a JSON rule can return.
const String _jsonBody =
    '{"data":{"name":"One","count":3,"adult":false,"tags":["a","b"],'
    '"empty":"","none":null,"list":[{"name":"One","url":"/book/1"},'
    '{"name":"Two","url":"/book/2"}]},'
    '"rows":[{"a":1,"b":2},{"a":1,"b":3}]}';

/// Rules that must be reported as `unsupportedRule` whichever method evaluates
/// them, with the syntax name `rulePath` has to carry
/// (`docs/dev/book-source.md` §7).
const Map<String, String> _unsupportedRules = <String, String>{
  '@js:result': 'unsupported:@js:',
  '@xpath://div': 'unsupported:@xpath:',
  '@put:{a:1}': 'unsupported:@put:',
  '@get:{a}': 'unsupported:@get:',
  '@webJs': 'unsupported:@webJs',
  '@@class.a': 'unsupported:@@',
  '{{result}}': 'unsupported:{{',
  '//div': 'unsupported://',
  r'{$.data}': 'unsupported:{',
  ':regex': 'unsupported::',
  // 矩阵 #7 的 `-` 先摘掉再识别标志头，所以标志头的报错保持原样（不能被 `-` 顶掉）。
  '-@js:result': 'unsupported:@js:',
  // 矩阵 #15：中段 `@@`（`@` 切分后留空段，必须在切段前判掉，否则误报畸形）。
  'class.a@@class.b@text': 'unsupported:@@',
  // `<js>` 包装不是矩阵里的标志：语义（整条规则写成 JS）本仓未实现，按名字拒绝，
  // 不得当成未知类型交给 cascadia（ADR-0032 §决策 3）。
  '<js>result</js>': 'unsupported:<js>',
};

/// Selector segments that carry syntax a later phase of the matrix owns.
///
/// The tests wrap them into a list rule and into a value rule, because the last
/// segment of a value rule is the extraction and is therefore never a selector.
const Map<String, String> _unsupportedSelectors = <String, String>{
  // 段内（非规则开头）的标志头：body 级检查只覆盖规则开头，中间段由选择器层拒绝。
  'json:\$.data': 'unsupported:@json:',
  // 名称里的 `:` 不属于任何已实现写法（矩阵 #6 的 `:` 只在 `!` 列表与位置段内）。
  'tag.a:b': 'unsupported::',
  // 裸 `//` 是矩阵 #21 的 XPath（M2）：即使写在选择器位置也不能当 CSS 退（ADR-0032 §决策 3）。
  '//div': 'unsupported://',
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
  '.1.2',
  '[1',
  '[x]',
  '!x',
  // `]` 而没有 `[`（`div]` 会被当作挂在类型上的索引写法，另归 unsupported）。
  'tag.div]',
  // 退化段（ADR-0032）的同类畸形：`]` 没有 `[`、未闭合、排除列表里混进字符。
  'li]',
  'li[0',
  'li!x',
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

/// Wraps [node] as the DOM scope the default rules and `@css:` read
/// (matrix #1..#12).
RuleScope _scope(Node node) => RuleScope.dom(node);

/// Wraps [body] as a whole-page scope: the parsed DOM **plus** the raw body, which is
/// what a `@json:` rule reads (matrix #13).
RuleScope _page(String body) => RuleScope.dom(parser.parse(body), body: body);

/// Returns the data of a successful element result, failing the test otherwise.
///
/// The engine returns scopes, so a DOM match is unwrapped back to its node for the
/// assertions that read attributes and text.
List<Element> _elements(ParseResult<List<RuleScope>> result) =>
    switch (result) {
      ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) => <Element>[
        for (final RuleScope match in data)
          switch (match) {
            DomScope(node: final Element element) => element,
            DomScope() => fail('Expected an element match, got another node.'),
            JsonScope() => fail('Expected a DOM match but got a JSON one.'),
          },
      ],
      ParseFailure<List<RuleScope>>(:final ParseFailureKind kind) => fail(
        'Expected a success but got $kind.',
      ),
    };

/// Returns the scopes of a successful list result, failing the test otherwise.
///
/// Used where the matches are JSON values rather than elements (matrix #13).
List<RuleScope> _matches(ParseResult<List<RuleScope>> result) =>
    switch (result) {
      ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) => data,
      ParseFailure<List<RuleScope>>(:final ParseFailureKind kind) => fail(
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
/// Returns the data of a successful single-value result, failing the test otherwise.
String _text(ParseResult<String> result) => switch (result) {
  ParseSuccess<String>(:final String data) => data,
  ParseFailure<String>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

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
    _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(3));
    });

    test('selectAll_givenIdRule_returnsTheElementWithThatId', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          'id.content@tag.p',
          _scope(_document(_chapterHtml)),
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
          _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
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
            _scope(document),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
      expect(
        _elements(
          _engine().selectAll(
            'class.result-list@tag.li.-9',
            _scope(document),
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
          _scope(scope),
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
            _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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
            _scope(document),
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
          _engine().selectAll(
            rule,
            _scope(document),
            rulePath: 'searchRule.bookList',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed, reason: rule);
        expect(failure.rulePath, 'searchRule.bookList', reason: rule);
      }
    });

    test('selectAll_givenRejectedRule_logsTheFieldAndTheSyntax', () {
      final FakeLogPrinter printer = FakeLogPrinter();

      _engine(printer).selectAll(
        '@js:result',
        _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, <String>['One Author A']);
    });

    test('extractAll_givenTextNodesExtraction_returnsDirectTextNodes', () {
      final List<String> values = _values(
        _engine().extractAll(
          'class.line.0@textNodes',
          _scope(_document(_chapterHtml)),
          rulePath: 'contentRule.content',
        ),
      );

      expect(values, <String>['First\ntail']);
    });

    test('extractAll_givenOwnTextExtraction_ignoresNestedText', () {
      final List<String> values = _values(
        _engine().extractAll(
          'class.line.0@ownText',
          _scope(_document(_chapterHtml)),
          rulePath: 'contentRule.content',
        ),
      );

      expect(values, <String>['First tail']);
    });

    test('extractAll_givenHtmlExtraction_dropsScriptAndStyle', () {
      final List<String> values = _values(
        _engine().extractAll(
          'id.content@html',
          _scope(_document(_chapterHtml)),
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
          _scope(_document(_chapterHtml)),
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
          _scope(document),
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
          _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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
            _scope(_document(_chapterHtml)),
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
          _scope(_document(_chapterHtml)),
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
            _scope(_document(_chapterHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenExtractionOnlyRule_extractsFromTheScope', () {
      final Element scope = _document(_listHtml).querySelectorAll('a').first;

      final List<String> values = _values(
        _engine().extractAll(
          'href',
          _scope(scope),
          rulePath: 'searchRule.bookUrl',
        ),
      );

      expect(values, <String>['/book/1']);
    });

    test('extractAll_givenRuleWithoutMatch_succeedsWithNoValues', () {
      expect(
        _values(
          _engine().extractAll(
            'class.absent@text',
            _scope(_document(_listHtml)),
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
            _scope(document),
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
          _scope(_document(_listHtml)),
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
          _engine().extractAll(
            rule,
            _scope(document),
            rulePath: 'searchRule.name',
          ),
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
            _scope(_document(_listHtml)),
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
          _scope(_document(_countHtml)),
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
            _scope(_document(_countHtml)),
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
          _scope(_document(_countHtml)),
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
            _scope(_document(_countHtml)),
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
          _scope(_document(_countHtml)),
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
            _scope(document),
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>[r'共 $ 字'],
      );
      expect(
        _values(
          _engine().extractAll(
            r'class.count@text##123##${}',
            _scope(document),
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>[r'共 ${} 字'],
      );
      expect(
        _values(
          _engine().extractAll(
            r'class.count@text##123##${',
            _scope(document),
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>[r'共 ${ 字'],
      );
      expect(
        _values(
          _engine().extractAll(
            r'class.count@text##123##$a',
            _scope(document),
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
          _scope(_document(_listHtml)),
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
            _scope(_document(_countHtml)),
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
              _scope(_document(_countHtml)),
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
            _scope(_document(_countHtml)),
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>['X'],
      );
    });
  });

  group('RuleEngine applyReplaceRule', () {
    test('applyReplaceRule_givenStandaloneForm_deletesEveryMatch', () {
      // `ruleContent.replaceRegex` 的真实写法（test/fixtures/book_sources/
      // legado_export_sanitized.json）：只有替换段，没有选择器。
      expect(
        _text(
          _engine().applyReplaceRule(
            '##本章未完，点击下一页继续阅读。',
            '正文。本章未完，点击下一页继续阅读。后续。本章未完，点击下一页继续阅读。',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '正文。后续。',
      );
    });

    test('applyReplaceRule_givenTheExplicitAllBody_appliesIt', () {
      // 上游文档：「独立使用相当于 `all##正则##替换`」。
      expect(
        _text(
          _engine().applyReplaceRule(
            r'all##\s+##',
            '第一段   第二段',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '第一段第二段',
      );
    });

    test('applyReplaceRule_givenGroupReference_expandsTheGroup', () {
      expect(
        _text(
          _engine().applyReplaceRule(
            r'##(\d+)##[$1]',
            '共 123 字',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '共 [123] 字',
      );
    });

    test('applyReplaceRule_givenTheFourPartForm_returnsTheFirstMatchOnly', () {
      // 矩阵 #25：`###` 取第一个匹配并在其内部替换，不是替换整串里的第一处。
      expect(
        _text(
          _engine().applyReplaceRule(
            '##a##b###',
            'xax ax',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        'b',
      );
    });

    test('applyReplaceRule_givenNoReplacement_passesTheTextThrough', () {
      expect(
        _text(
          _engine().applyReplaceRule(
            'all',
            '正文。',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '正文。',
      );
    });

    test('applyReplaceRule_givenDeferredFlag_reportsUnsupportedRule', () {
      // 标志头按规则原文保留大小写（book-source.md §3 前缀大小写不敏感）。
      expect(
        _failure(
          _engine().applyReplaceRule(
            '@JS:result',
            '正文。',
            rulePath: 'contentRule.replaceRegex',
          ),
        ).rulePath,
        'unsupported:@JS:',
      );
      expect(
        _failure(
          _engine().applyReplaceRule(
            '@xpath://div',
            '正文。',
            rulePath: 'contentRule.replaceRegex',
          ),
        ).kind,
        ParseFailureKind.unsupportedRule,
      );
    });

    test('applyReplaceRule_givenSelectorBody_reportsParseFailedAtTheField', () {
      // 带选择器的规则体在纯文本上没有可读的节点：报畸形（带字段路径），不静默丢掉选择器。
      final ParseFailure<Never> failure = _failure(
        _engine().applyReplaceRule(
          'class.a@text##x##y',
          '正文。',
          rulePath: 'contentRule.replaceRegex',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'contentRule.replaceRegex');
    });
  });

  group('RuleEngine extractFirst', () {
    test('extractFirst_givenSeveralMatches_returnsTheFirstValue', () {
      expect(
        _first(
          _engine().extractFirst(
            'tag.a@href',
            _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
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
          _scope(_document(_chapterHtml)),
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
          _scope(_document(_chapterHtml)),
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
          _scope(scope),
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
            _scope(_document(_chapterHtml)),
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
          _scope(_document(_listHtml)),
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
          _scope(_document(_chapterHtml)),
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
        _engine().selectAll(
          'children',
          _scope(scope),
          rulePath: 'tocRule.chapterList',
        ),
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
            _scope(scope),
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
            _scope(scope),
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
            _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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

  group('RuleEngine connectors (#10 || / #11 && / #27 %%)', () {
    test('extractAll_givenDoublePipe_takesTheFirstCandidateWithValues', () {
      // 矩阵 #10：依次尝试，首个非空即成功。
      expect(
        _values(
          _engine().extractAll(
            'class.absent@text||class.result-list@tag.li.0@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One Author A'],
      );
    });

    test('extractAll_givenOnlyEmptyCandidates_succeedsWithNoValues', () {
      expect(
        _values(
          _engine().extractAll(
            'class.absent@text||class.alsoAbsent@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenDoubleAmpersand_mergesBothBranchesInRuleOrder', () {
      // 矩阵 #11：`&&` 合并两侧结果（并集、非串联）。
      expect(
        _values(
          _engine().extractAll(
            'class.result-list@tag.li.0@text'
            '&&class.result-list@tag.li.1@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One Author A', 'Two Author B'],
      );
    });

    test('selectAll_givenDoubleAmpersand_concatenatesTheElements', () {
      expect(
        _elements(
          _engine().selectAll(
            'class.result-list@tag.li.0&&class.result-list@tag.li.2',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(2),
      );
    });

    test('extractAll_givenDoublePercent_interleavesTheBranches', () {
      // 矩阵 #27：`%%` 交叉取数（依次从各列表取）。
      expect(
        _values(
          _engine().extractAll(
            'tag.a@href%%class.result-list@tag.li@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>[
          '/book/1',
          'One Author A',
          '/book/2',
          'Two Author B',
          '/book/3',
          'Three Author C',
        ],
      );
    });

    test('extractAll_givenMixedConnectors_groupsAmpersandFirst', () {
      // `a&&b||c` = `(a&&b)||c`：`||` 最松先切（book-source.md §3.2）。
      expect(
        _values(
          _engine().extractAll(
            'class.absent@text&&class.alsoAbsent@text'
            '||class.result-list@tag.li.-1@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['Three Author C'],
      );
    });

    test('extractAll_givenAConnectorInsideBracketsOrQuotes_keepsItLiteral', () {
      // `[...]` / `(...)` / 引号内的分隔符属于选择器：若被切开，选择器会残缺而报
      // parseFailed，所以「成功且为空」恰好证明保护生效。
      final Document document = _document(_listHtml);

      expect(
        _values(
          _engine().extractAll(
            '@css:a[href="x&&y"]@text',
            _scope(document),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
      expect(
        _values(
          _engine().extractAll(
            '@css:a:matches(/x&&y/)@text',
            _scope(document),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenASeparatorAfterABracketedSelector_stillSplits', () {
      // 扫描器必须跳过 `[...]` 与引号内的字符，但仍在它们之后的连接符处切分。
      expect(
        _values(
          _engine().extractAll(
            'class.result-list@tag.li.0@text&&@css:a[href="/book/2"]@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One Author A', 'Two'],
      );
    });

    test('selectAll_givenAValueBranchInAListRule_returnsParseFailed', () {
      // 跨类型合并必须显式失败，不得静默拼成异构列表。
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          'class.result-list&&class.result-list@text',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test('selectAll_givenAnUnknownTypeInAListRule_matchesItAsCss', () {
      // ADR-0032 改变了这里的语义：`href` 不再是「不支持的类型」，而是原始 CSS 选择器
      //（`doc.select("href")`，匹配不到任何元素）。列表规则里写取值段仍然不是
      // 跨类型检测——上一条 `text` 借道「段结构畸形」报 parseFailed，这里则是空匹配。
      expect(
        _elements(
          _engine().selectAll(
            'class.result-list&&class.result-list@href',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(1),
      );
    });

    test('extractAll_givenAnEmptyBranch_returnsParseFailed', () {
      final ParseFailure<Never> failure = _failure(
        _engine().extractAll(
          'class.result-list@text||',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('selectAll_givenADeferredFlagInALaterCandidate_reportsIt', () {
      // body 级标志检查只覆盖规则开头；后续候选的标志头由选择器层拒绝。
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          'class.result-list||@js:result',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@js:');
    });
  });

  group('RuleEngine matrix #12 (@css:)', () {
    test('selectAll_givenCssRule_returnsEveryMatch', () {
      final List<Element> elements = _elements(
        _engine().selectAll(
          '@css:ul.result-list > li',
          _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/3'],
      );
      expect(
        _values(
          _engine().extractAll(
            '@css:span:containsOwn(Author)@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.author',
          ),
        ),
        <String>['Author A', 'Author B', 'Author C'],
      );
    });

    test('extractAll_givenAnIndexPseudo_matchesTheSiblingIndex', () {
      // 矩阵 #29：jsoup 的 `:eq(n)` 是**兄弟索引**，不是结果集索引。镜像 jsoup 自己的
      // SelectorTest.testPseudoEquals（`div p:eq(0)` 每个 div 各取一个 p）。
      final Document document = _document(
        '<div><p>One</p><p>Two</p></div><div><p>Four</p></div>',
      );

      expect(
        _values(
          _engine().extractAll(
            '@css:div p:eq(0)@text',
            _scope(document),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One', 'Four'],
      );
    });

    test(
      'extractAll_givenTheGreaterAndLessThanPseudos_takeTheSiblingRange',
      () {
        // jsoup 文档：`td:lt(3)` = 每行的前三个单元格，`td:gt(1)` = 跳过前两个。
        final Document document = _document(
          '<table><tr><td>1</td><td>2</td><td>3</td><td>4</td></tr></table>',
        );

        expect(
          _values(
            _engine().extractAll(
              '@css:td:lt(3)@text',
              _scope(document),
              rulePath: 'x',
            ),
          ),
          <String>['1', '2', '3'],
        );
        expect(
          _values(
            _engine().extractAll(
              '@css:td:gt(1)@text',
              _scope(document),
              rulePath: 'x',
            ),
          ),
          <String>['3', '4'],
        );
      },
    );

    test('selectAll_givenANegativeIndexPseudo_returnsUnsupportedRule', () {
      // jsoup 文档把索引伪类定义为 0-based 且未定义负索引 → 本仓不猜，点名拒绝。
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          '@css:li:eq(-1)',
          _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
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
              _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
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
          _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
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
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('RuleEngine @json: (matrix #13)', () {
    test('extractAll_givenAJsonFlag_returnsTheValueAtThePath', () {
      expect(
        _values(
          _engine().extractAll(
            r'@json:$.data.name',
            _page(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One'],
      );
    });

    test('extractAll_givenABareDollarPath_returnsTheValueAtThePath', () {
      // 矩阵 #13：以 `$.` 开头时可省略 `@json:` 标志。
      expect(
        _values(
          _engine().extractAll(
            r'$.data.name',
            _page(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One'],
      );
    });

    test('extractAll_givenAnUpperCasedJsonFlag_returnsTheValueAtThePath', () {
      expect(
        _values(
          _engine().extractAll(
            r'@Json:$.data.name',
            _page(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One'],
      );
    });

    test('extractAll_givenAJsonPathFilter_keepsItsAtSignAndAmpersands', () {
      // 过滤器里有 `@`（若按 `@` 切段会被吃掉）与 `&&`（若按连接符切分会被当成合并），
      // 所以整条分支必须在切段与切分之前就被识别成 JSONPath。
      expect(
        _values(
          _engine().extractAll(
            r'$.rows[?(@.a==1 && @.b==2)].b',
            _page(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['2'],
      );
    });

    test('extractAll_givenJsonScalars_returnsTheirJsonText', () {
      final RuleScope page = _page(_jsonBody);

      expect(
        _values(
          _engine().extractAll(
            r'$.data.count',
            page,
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>['3'],
      );
      expect(
        _values(
          _engine().extractAll(
            r'$.data.adult',
            page,
            rulePath: 'searchRule.kind',
          ),
        ),
        <String>['false'],
      );
    });

    test('extractAll_givenAJsonListValue_returnsItAsJsonText', () {
      expect(
        _values(
          _engine().extractAll(
            r'$.data.tags',
            _page(_jsonBody),
            rulePath: 'searchRule.kind',
          ),
        ),
        <String>['["a","b"]'],
      );
    });

    test('extractAll_givenAJsonObjectValue_returnsItAsJsonText', () {
      expect(
        _values(
          _engine().extractAll(
            r'$.data.list[0]',
            _page(_jsonBody),
            rulePath: 'searchRule.intro',
          ),
        ),
        <String>['{"name":"One","url":"/book/1"}'],
      );
    });

    test('extractAll_givenAnEmptyOrNullJsonValue_returnsNoValue', () {
      // 与矩阵 #8 的空提取同口径：空字符串与 null 都不产生值，不报失败。
      final RuleScope page = _page(_jsonBody);

      expect(
        _values(
          _engine().extractAll(
            r'$.data.empty',
            page,
            rulePath: 'searchRule.intro',
          ),
        ),
        isEmpty,
      );
      expect(
        _values(
          _engine().extractAll(
            r'$.data.none',
            page,
            rulePath: 'searchRule.intro',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenAMalformedJsonPath_returnsParseFailed', () {
      final ParseFailure<Never> failure = _failure(
        _engine().extractAll(
          r'@json:$[',
          _page(_jsonBody),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenAnEmptyJsonPath_returnsParseFailed', () {
      final ParseFailure<Never> failure = _failure(
        _engine().extractAll(
          '@json:',
          _page(_jsonBody),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenANonJsonBody_returnsParseFailed', () {
      // 页面根本不是 JSON：规则本身没错，是这一页回答不了它（≠ 成功且为空）。
      final ParseFailure<Never> failure = _failure(
        _engine().extractAll(
          r'$.data.name',
          _page(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenAJsonRuleOnAnElement_returnsParseFailed', () {
      // 元素 scope 没有原始 body：元素内部的 JSON 需要提取段嵌套规则（矩阵 #30）。
      final ParseFailure<Never> failure = _failure(
        _engine().extractAll(
          r'$.data.name',
          _scope(_document(_listHtml).querySelectorAll('li').first),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenMixedScopeOr_returnsParseFailed', () {
      // 已裁决行为，本用例用来**钉住**它：`||` 的候选一旦**失败**就整条终止，不会去试后面的
      // DOM 候选，也不会回退。HTML 页的 body 不是 JSON，所以 `$.a` 失败、`class.b@text` 根本
      // 不会被求值。若有人把它「修」成能回退，这里会红。
      final ParseFailure<Never> failure = _failure(
        _engine().extractAll(
          r'$.a||class.b@text',
          _page(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenADomRuleOnAJsonScope_returnsParseFailed', () {
      final ParseFailure<Never> failure = _failure(
        _engine().extractAll(
          'class.result@text',
          const JsonScope(<String, Object?>{'name': 'One'}),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenADomRuleOnAJsonPage_returnsAnEmptySuccess', () {
      // 方向不对称，且是有意的：DOM 规则打在 **JSON 页** 上不是失败——页面仍然是一份解析出来
      // 的文档，选择器零匹配就是矩阵 #8 的「成功但为空」。只有上面那种「匹配项本身是 JSON 值」
      // 才连 DOM 都没有，才报 parseFailed。
      expect(
        _values(
          _engine().extractAll(
            'class.result@text',
            _page(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('selectAll_givenAJsonListRule_returnsOneScopePerValue', () {
      final List<RuleScope> items = _matches(
        _engine().selectAll(
          r'$.data.list[*]',
          _page(_jsonBody),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(items, hasLength(2));
      // 列表规则的每个匹配都是下一级的 scope，字段规则在它上面读。
      expect(
        _values(
          _engine().extractAll(
            r'$.name',
            items.first,
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One'],
      );
      expect(
        _values(
          _engine().extractAll(
            r'@json:$.url',
            items.last,
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/2'],
      );
    });

    test('selectAll_givenAReversedJsonListRule_reversesTheMatches', () {
      final List<RuleScope> items = _matches(
        _engine().selectAll(
          r'-$.data.list[*]',
          _page(_jsonBody),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(
        _values(
          _engine().extractAll(
            r'$.name',
            items.first,
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['Two'],
      );
    });

    test('selectAll_givenADomRuleOnAJsonScope_returnsParseFailed', () {
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          'class.result',
          const JsonScope(<String, Object?>{'name': 'One'}),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test(
      'selectAll_givenAJsonBranchMergedWithADomBranch_returnsParseFailed',
      () {
        // `book-source.md` §3 的 `&&` 注记：连接符只合并同种规则，跨 scope 合并语义未定义。
        final ParseFailure<Never> failure = _failure(
          _engine().selectAll(
            r'$.data.list[*]&&class.result',
            _page(_jsonBody),
            rulePath: 'searchRule.bookList',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'searchRule.bookList');
      },
    );

    test('selectAll_givenAJsonRuleInAListScope_returnsParseFailed', () {
      final ParseFailure<Never> failure = _failure(
        _engine().selectAll(
          r'$.data.list[*]',
          _page(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });
  });

  group('RuleEngine ADR-0032 (unknown type degrades to CSS)', () {
    test('selectAll_givenABareTagType_matchesEveryElementOfThatTag', () {
      // 真实语料里最高频的形态：`li` / `dd` / `p` 直接当类型写。
      expect(
        _elements(
          _engine().selectAll(
            'li',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(3),
      );
    });

    test('selectAll_givenALeadingDotType_matchesThatClass', () {
      // `.searchresult`：空类型不是畸形，而是一段原始 CSS。
      expect(
        _elements(
          _engine().selectAll(
            '.result-list',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(1),
      );
    });

    test('selectAll_givenAHashType_matchesThatId', () {
      expect(
        _elements(
          _engine().selectAll(
            '#content',
            _scope(_document(_chapterHtml)),
            rulePath: 'bookInfoRule.init',
          ),
        ),
        hasLength(1),
      );
    });

    test('selectAll_givenAnUnknownTypeWithExclusion_dropsThatIndex', () {
      // `li!0`：`!` 后缀仍按位置解析（`tr!0` 不是合法 CSS，不能整段丢给 cascadia）。
      expect(
        _elements(
          _engine().selectAll(
            'li!0',
            _scope(_document(_listHtml)),
            rulePath: 'tocRule.chapterList',
          ),
        ),
        hasLength(2),
      );
    });

    test('extractAll_givenADegradedSelectorWithAClassQualifier_extractsIt', () {
      expect(
        _values(
          _engine().extractAll(
            'span.dupe@data-x',
            _scope(_document(_chapterHtml)),
            rulePath: 'bookInfoRule.kind',
          ),
        ),
        <String>['same'],
      );
    });

    test('selectAll_givenAJsonPseudoInADegradedSelector_rewritesIt', () {
      // 矩阵 #29 的改写对退化段同样生效：`:eq` 是兄弟索引，不是结果集索引。
      expect(
        _elements(
          _engine().selectAll(
            'p.line:eq(1)',
            _scope(_document(_chapterHtml)),
            rulePath: 'contentRule.content',
          ),
        ),
        hasLength(1),
      );
    });

    test('selectAll_givenAnUnknownTypeWithABracketPosition_takesThatMatch', () {
      // 退化段的位置后缀走同一套解析：`li[0]` = 原始 CSS `li` + 位置 0。
      expect(
        _elements(
          _engine().selectAll(
            'li[0]',
            _scope(_document(_listHtml)),
            rulePath: 'tocRule.chapterList',
          ),
        ),
        hasLength(1),
      );
    });

    test(
      'extractAll_givenADegradedSelectorThatIsNotCss_returnsParseFailed',
      () {
        final ParseFailure<Never> failure = _failure(
          _engine().extractAll(
            'li..b@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'searchRule.name');
      },
    );
  });
}
