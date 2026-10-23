import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:logger/logger.dart';

import '../../../../support/fake_js_bridge.dart';
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
  '@xpath://div': 'unsupported:@xpath:',
  '@webJs': 'unsupported:@webJs',
  '//div': 'unsupported://',
  ':regex': 'unsupported::',
  // 矩阵 #7 的 `-` 先摘掉再识别标志头，所以标志头的报错保持原样（不能被 `-` 顶掉）。
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
///
/// [variables] is injectable so a test can share one store with the fake bridge, which is
/// how a `java.put` of matrix #17 reaches `@get:` / `{{name}}` of a later rule.
RuleEngine _engine([
  FakeLogPrinter? printer,
  JsBridge? jsBridge,
  JsVariableStore? variables,
]) => RuleEngine(
  logger: AppLogger(
    level: LogLevel.debug,
    printer: printer ?? FakeLogPrinter(),
  ),
  variables: variables ?? JsVariableStore(),
  jsBridge: jsBridge ?? FakeJsBridge(),
);

/// Parses [html]; every rule below is evaluated against the result.
Document _document(String html) => parser.parse(html);

/// Parses [html] into a page scope that carries a JS context (`book-source.md` §6), so a
/// `@js:` rule has a `baseUrl` / `page` / `source` to bind.
RuleScope _pageWithContext(String html) => RuleScope.dom(
  parser.parse(html),
  body: html,
  jsContext: const JsPageContext(
    baseUrl: 'https://example-novel.test/book/1/',
    page: 2,
    source: JsSourceInfo(
      name: '示例书源',
      url: 'https://example-novel.test',
      group: '分组',
    ),
  ),
);

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
///
/// Every helper below takes the **unawaited** engine call and awaits it, so a test body
/// only has to `await` the helper — the engine's API is asynchronous since ADR-0029
/// §决策 1 (`@js:` rules cross an isolate).
Future<List<Element>> _elements(
  Future<ParseResult<List<RuleScope>>> result,
) async => switch (await result) {
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
Future<List<RuleScope>> _matches(
  Future<ParseResult<List<RuleScope>>> result,
) async => switch (await result) {
  ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) => data,
  ParseFailure<List<RuleScope>>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns the data of a successful value result, failing the test otherwise.
Future<List<String>> _values(Future<ParseResult<List<String>>> result) async =>
    switch (await result) {
      ParseSuccess<List<String>>(:final List<String> data) => data,
      ParseFailure<List<String>>(:final ParseFailureKind kind) => fail(
        'Expected a success but got $kind.',
      ),
    };

/// Returns the data of a successful single-value result.
Future<String?> _first(Future<ParseResult<String?>> result) async =>
    switch (await result) {
      ParseSuccess<String?>(:final String? data) => data,
      ParseFailure<String?>(:final ParseFailureKind kind) => fail(
        'Expected a success but got $kind.',
      ),
    };

/// Returns the data of a successful single-value result, failing the test otherwise.
Future<String> _text(Future<ParseResult<String>> result) async =>
    switch (await result) {
      ParseSuccess<String>(:final String data) => data,
      ParseFailure<String>(:final ParseFailureKind kind) => fail(
        'Expected a success but got $kind.',
      ),
    };

/// Returns the failure of [result], failing the test when it succeeded.
///
/// Rebuilt as `ParseFailure<Never>` so one helper serves every result type.
Future<ParseFailure<Never>> _failure<T>(Future<ParseResult<T>> result) async =>
    switch (await result) {
      ParseFailure<T>(:final ParseFailureKind kind, :final String rulePath) =>
        ParseFailure<Never>(kind: kind, rulePath: rulePath),
      ParseSuccess<T>() => fail('Expected a failure.'),
    };

/// The `href` of every match of `class.result-list@<segment>@tag.a`.
///
/// The list page has three items, so a position test can tell an index list's
/// authored order (matrix #26) from an ascending sort.
Future<List<String?>> _hrefsFor(String segment) async {
  final List<Element> elements = await _elements(
    _engine().selectAll(
      'class.result-list@$segment@tag.a',
      _scope(_document(_listHtml)),
      rulePath: 'searchRule.bookUrl',
    ),
  );

  return elements.map((Element element) => element.attributes['href']).toList();
}

/// The `href` of every match of `class.result-list@tag.li<position>@tag.a`.
Future<List<String?>> _hrefsForList(String position) =>
    _hrefsFor('tag.li$position');

void main() {
  group('RuleEngine selectAll', () {
    test('selectAll_givenClassThenTagRule_returnsEveryMatch', () async {
      final List<Element> elements = await _elements(
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

    test('selectAll_givenTagRule_returnsEveryMatchInTheDocument', () async {
      final List<Element> elements = await _elements(
        _engine().selectAll(
          'tag.li',
          _scope(_document(_listHtml)),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(3));
    });

    test('selectAll_givenIdRule_returnsTheElementWithThatId', () async {
      final List<Element> elements = await _elements(
        _engine().selectAll(
          'id.content@tag.p',
          _scope(_document(_chapterHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(2));
      expect(elements.first.text, contains('First'));
    });

    test('selectAll_givenPositiveIndex_returnsThatMatch', () async {
      final List<Element> elements = await _elements(
        _engine().selectAll(
          'class.result-list@tag.li.0',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.text, contains('One'));
    });

    test('selectAll_givenNegativeIndex_returnsTheLastMatch', () async {
      final List<Element> elements = await _elements(
        _engine().selectAll(
          'class.result-list@tag.li.-1',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.text, contains('Three'));
    });

    test('selectAll_givenIndexBeyondTheMatches_returnsNothing', () async {
      final Document document = _document(_listHtml);

      expect(
        await _elements(
          _engine().selectAll(
            'class.result-list@tag.li.9',
            _scope(document),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
      expect(
        await _elements(
          _engine().selectAll(
            'class.result-list@tag.li.-9',
            _scope(document),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
    });

    test(
      'selectAll_givenScopeMatchingTheSelector_includesTheScopeItself',
      () async {
        final Element scope = _document(_listHtml).querySelectorAll('li').first;

        final List<Element> elements = await _elements(
          _engine().selectAll(
            'class.result',
            _scope(scope),
            rulePath: 'searchRule.bookList',
          ),
        );

        expect(elements, hasLength(1));
        expect(elements.single, same(scope));
      },
    );

    test('selectAll_givenBlankRule_returnsNoElements', () async {
      expect(
        await _elements(
          _engine().selectAll(
            '   ',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
    });

    test('selectAll_givenRuleWithoutMatch_succeedsWithNoElements', () async {
      expect(
        await _elements(
          _engine().selectAll(
            'class.absent@tag.li',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        isEmpty,
      );
    });

    test('selectAll_givenUnsupportedSyntax_returnsUnsupportedRule', () async {
      final Document document = _document(_listHtml);
      final Map<String, String> rules = <String, String>{
        ..._unsupportedRules,
        for (final MapEntry<String, String> entry
            in _unsupportedSelectors.entries)
          'class.a@${entry.key}': entry.value,
      };

      for (final MapEntry<String, String> entry in rules.entries) {
        final ParseFailure<Never> failure = await _failure(
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

    test(
      'selectAll_givenMalformedSelector_returnsParseFailedAtTheField',
      () async {
        final Document document = _document(_listHtml);

        for (final String rule in <String>[
          ..._malformedSelectors,
          'class.a@',
        ]) {
          final ParseFailure<Never> failure = await _failure(
            _engine().selectAll(
              rule,
              _scope(document),
              rulePath: 'searchRule.bookList',
            ),
          );

          expect(failure.kind, ParseFailureKind.parseFailed, reason: rule);
          expect(failure.rulePath, 'searchRule.bookList', reason: rule);
        }
      },
    );

    test('selectAll_givenRejectedRule_logsTheFieldAndTheSyntax', () async {
      final FakeLogPrinter printer = FakeLogPrinter();

      await _engine(printer).selectAll(
        '@xpath://div',
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
        contains('unsupported:@xpath:'),
      );
    });

    test('selectAll_givenAJavaScriptListRule_returnsElementScopes', () async {
      // 列表规则上的 JS（上游 `getElements` 的 `Mode.Js`）：脚本返回一列 HTML 片段，
      // 每个片段是一个 DOM 条目，后面的逐项字段照旧用选择器读（book-source.md §3, #14/#31）。
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = <Object?>[
          '<li class="result"><a class="title">One</a></li>',
          '<li class="result"><a class="title">Two</a></li>',
        ];

      final ParseResult<List<RuleScope>> result = await _engine(null, bridge)
          .selectAll(
            '@js:result.data.items',
            _scope(_document('<ul></ul>')),
            rulePath: 'searchRule.bookList',
          );

      expect((result as ParseSuccess<List<RuleScope>>).data, hasLength(2));
      expect(bridge.jobs.single.script, 'result.data.items');
    });

    test('selectAll_givenAScriptThenASelector_readsEachItem', () async {
      // `<js>` 之后还能跟选择器段：脚本产出的 HTML 片段成为条目，下一段在**每个条目**上跑
      // 一次，结果按条目顺序拼接。
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = <Object?>[
          '<li class="result"><a class="title">One</a></li>',
          '<li class="result"><a class="title">Two</a></li>',
        ];

      final ParseResult<List<RuleScope>> result = await _engine(null, bridge)
          .selectAll(
            '<js>fragments()</js>class.title',
            _scope(_document('<ul></ul>')),
            rulePath: 'searchRule.bookList',
          );

      expect((result as ParseSuccess<List<RuleScope>>).data, hasLength(2));
    });

    test('selectAll_givenTwoScripts_handsTheFirstScopesToTheSecond', () async {
      // 两段脚本：第二段的 `result` 是第一段产出的条目（元素给 outerHtml）。
      final FakeJsBridge bridge = FakeJsBridge()
        ..results.addAll(<Object?>[
          <Object?>['<li class="result">One</li>'],
          'done',
        ]);

      final ParseResult<List<RuleScope>> result = await _engine(null, bridge)
          .selectAll(
            '<js>split()</js><js>result.length</js>',
            _scope(_document('<ul></ul>')),
            rulePath: 'searchRule.bookList',
          );

      // 第二段脚本返回字符串 `done`，它被当**一个**条目（DOM scope）。
      expect((result as ParseSuccess<List<RuleScope>>).data, hasLength(1));
      expect(bridge.jobs.last.result, isA<List<Object?>>());
    });

    test('selectAll_givenAFailingListScript_failsTheRule', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = const ParseFailure<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'js:error',
        );

      final Future<ParseFailure<Never>> result = _failure(
        _engine(null, bridge).selectAll(
          '@js:boom()',
          _scope(_document('<ul></ul>')),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect((await result).rulePath, 'js:error');
    });

    test(
      'selectAll_givenAJavaScriptListRuleOfObjects_returnsJsonScopes',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..result = <Object?>[
            <String, Object?>{'name': 'One'},
          ];

        final ParseResult<List<RuleScope>> result = await _engine(null, bridge)
            .selectAll(
              r'@json:$.data<js>result</js>',
              RuleScope.json(<String, Object?>{'data': <Object?>[]}),
              rulePath: 'searchRule.bookList',
            );

        expect((result as ParseSuccess<List<RuleScope>>).data, hasLength(1));
      },
    );
  });

  group('RuleEngine extractAll', () {
    test('extractAll_givenTextExtraction_collapsesWhitespace', () async {
      final List<String> values = await _values(
        _engine().extractAll(
          'class.result-list@tag.li.0@text',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, <String>['One Author A']);
    });

    test(
      'extractAll_givenTextNodesExtraction_returnsDirectTextNodes',
      () async {
        final List<String> values = await _values(
          _engine().extractAll(
            'class.line.0@textNodes',
            _scope(_document(_chapterHtml)),
            rulePath: 'contentRule.content',
          ),
        );

        expect(values, <String>['First\ntail']);
      },
    );

    test('extractAll_givenOwnTextExtraction_ignoresNestedText', () async {
      final List<String> values = await _values(
        _engine().extractAll(
          'class.line.0@ownText',
          _scope(_document(_chapterHtml)),
          rulePath: 'contentRule.content',
        ),
      );

      expect(values, <String>['First tail']);
    });

    test('extractAll_givenHtmlExtraction_dropsScriptAndStyle', () async {
      final List<String> values = await _values(
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

    test('extractAll_givenAllExtraction_keepsScriptAndStyle', () async {
      final List<String> values = await _values(
        _engine().extractAll(
          'id.content@all',
          _scope(_document(_chapterHtml)),
          rulePath: 'contentRule.content',
        ),
      );

      expect(values.single, contains('<script>'));
      expect(values.single, contains('<style>'));
    });

    test('extractAll_givenHtmlExtraction_leavesTheDocumentUntouched', () async {
      final Document document = _document(_chapterHtml);

      await _values(
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

    test('extractAll_givenAttributeExtraction_returnsEveryValue', () async {
      final List<String> values = await _values(
        _engine().extractAll(
          'tag.a@href',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookUrl',
        ),
      );

      expect(values, <String>['/book/1', '/book/2', '/book/3']);
    });

    test('extractAll_givenMissingAttribute_returnsNothing', () async {
      expect(
        await _values(
          _engine().extractAll(
            'tag.a@src',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.coverUrl',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenBlankAttribute_returnsNothing', () async {
      expect(
        await _values(
          _engine().extractAll(
            'tag.img@alt',
            _scope(_document(_chapterHtml)),
            rulePath: 'searchRule.coverUrl',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenDuplicateAttributeValues_dropsDuplicates', () async {
      final List<String> values = await _values(
        _engine().extractAll(
          'class.dupe@data-x',
          _scope(_document(_chapterHtml)),
          rulePath: 'searchRule.bookUrl',
        ),
      );

      expect(values, <String>['same']);
    });

    test('extractAll_givenElementWithoutText_skipsTheEmptyValue', () async {
      expect(
        await _values(
          _engine().extractAll(
            'class.empty@text',
            _scope(_document(_chapterHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenExtractionOnlyRule_extractsFromTheScope', () async {
      final Element scope = _document(_listHtml).querySelectorAll('a').first;

      final List<String> values = await _values(
        _engine().extractAll(
          'href',
          _scope(scope),
          rulePath: 'searchRule.bookUrl',
        ),
      );

      expect(values, <String>['/book/1']);
    });

    test('extractAll_givenRuleWithoutMatch_succeedsWithNoValues', () async {
      expect(
        await _values(
          _engine().extractAll(
            'class.absent@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenUnsupportedSyntax_returnsUnsupportedRule', () async {
      final Document document = _document(_listHtml);
      final Map<String, String> rules = <String, String>{
        ..._unsupportedRules,
        for (final MapEntry<String, String> entry
            in _unsupportedSelectors.entries)
          'class.a@${entry.key}@text': entry.value,
      };

      for (final MapEntry<String, String> entry in rules.entries) {
        final ParseFailure<Never> failure = await _failure(
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

    test('extractAll_givenANestedRuleInTheExtractionPosition_returnsUnsupportedRule', () async {
      // 值规则的末段是提取段，上游在那里允许嵌套规则（矩阵 #30，M2/暂不实现）。
      // 它必须报**可区分**的名字：中段的 `@css:` 已支持，末段仍未支持（F3）。
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          'class.a@css:.b',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:nested-rule');
    });

    test(
      'extractAll_givenMalformedRule_returnsParseFailedAtTheField',
      () async {
        final Document document = _document(_listHtml);
        final List<String> rules = <String>[
          for (final String selector in _malformedSelectors) '$selector@text',
          // 末段为空：上游同样取不到值，但那是畸形而不是「不支持的语法」。
          'class.a@',
        ];

        for (final String rule in rules) {
          final ParseFailure<Never> failure = await _failure(
            _engine().extractAll(
              rule,
              _scope(document),
              rulePath: 'searchRule.name',
            ),
          );

          expect(failure.kind, ParseFailureKind.parseFailed, reason: rule);
          expect(failure.rulePath, 'searchRule.name', reason: rule);
        }
      },
    );

    test(
      'extractAll_givenSingleSegmentRule_treatsItAsAnAttributeName',
      () async {
        // 上游语义：值规则的末段永远是提取段，所以单段规则是属性名而不是选择器；
        // 取不到值时是「成功但为空」，不能报成畸形规则。
        expect(
          await _values(
            _engine().extractAll(
              'class.a.b',
              _scope(_document(_listHtml)),
              rulePath: 'searchRule.name',
            ),
          ),
          isEmpty,
        );
      },
    );
  });

  group('RuleEngine ## replacement', () {
    test(
      'extractAll_givenReplacementWithoutItsSecondPart_deletesTheMatch',
      () async {
        final List<String> values = await _values(
          _engine().extractAll(
            r'class.count@text##共\s*',
            _scope(_document(_countHtml)),
            rulePath: 'searchRule.wordCount',
          ),
        );

        expect(values, <String>['123 字']);
      },
    );

    test(
      'extractAll_givenGroupReferenceInTheReplacement_substitutesTheGroup',
      () async {
        final List<String> values = await _values(
          _engine().extractAll(
            r'class.count@text##共\s*(\d+)\s*字##$1',
            _scope(_document(_countHtml)),
            rulePath: 'searchRule.wordCount',
          ),
        );

        expect(values, <String>['123']);
      },
    );

    test(
      'extractAll_givenNamedGroupReference_substitutesTheNamedGroup',
      () async {
        final List<String> values = await _values(
          _engine().extractAll(
            r'class.count@text##(?<n>\d+)##[${n}]',
            _scope(_document(_countHtml)),
            rulePath: 'searchRule.wordCount',
          ),
        );

        expect(values, <String>['共 [123] 字']);
      },
    );

    test(
      'extractAll_givenEscapedCharacterInTheReplacement_keepsItLiterally',
      () async {
        final List<String> values = await _values(
          _engine().extractAll(
            r'class.count@text##(\d+)##\1',
            _scope(_document(_countHtml)),
            rulePath: 'searchRule.wordCount',
          ),
        );

        expect(values, <String>['共 1 字']);
      },
    );

    test('extractAll_givenUncompilablePattern_replacesLiterally', () async {
      final List<String> values = await _values(
        _engine().extractAll(
          'class.raw@text##a(b##X',
          _scope(_document(_countHtml)),
          rulePath: 'searchRule.wordCount',
        ),
      );

      expect(values, <String>['xXy']);
    });

    test(
      'extractAll_givenDollarThatIsNotAReference_keepsItLiterally',
      () async {
        final Document document = _document(_countHtml);

        expect(
          await _values(
            _engine().extractAll(
              r'class.count@text##123##$',
              _scope(document),
              rulePath: 'searchRule.wordCount',
            ),
          ),
          <String>[r'共 $ 字'],
        );
        expect(
          await _values(
            _engine().extractAll(
              r'class.count@text##123##${}',
              _scope(document),
              rulePath: 'searchRule.wordCount',
            ),
          ),
          <String>[r'共 ${} 字'],
        );
        expect(
          await _values(
            _engine().extractAll(
              r'class.count@text##123##${',
              _scope(document),
              rulePath: 'searchRule.wordCount',
            ),
          ),
          <String>[r'共 ${ 字'],
        );
        expect(
          await _values(
            _engine().extractAll(
              r'class.count@text##123##$a',
              _scope(document),
              rulePath: 'searchRule.wordCount',
            ),
          ),
          <String>[r'共 $a 字'],
        );
      },
    );

    test('extractAll_givenReplacement_appliesItToEveryValue', () async {
      final List<String> values = await _values(
        _engine().extractAll(
          r'class.result-list@tag.li@text##\s*Author [ABC]',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, <String>['One', 'Two', 'Three']);
    });

    test(
      'extractAll_givenFourPartReplacement_returnsTheFirstMatchOnly',
      () async {
        // 上游 `##match##replace###`（AnalyzeRule.kt:497）不是「替换整串里的第一个」：
        // 它取第一个**匹配**，只在该匹配内部做替换，因此结果是 `123` 而不是 `共 123 字`。
        expect(
          await _values(
            _engine().extractAll(
              r'class.count@text##共\s*(\d+)\s*字##$1###',
              _scope(_document(_countHtml)),
              rulePath: 'searchRule.wordCount',
            ),
          ),
          <String>['123'],
        );
      },
    );

    test(
      'extractAll_givenFourPartReplacementWithoutMatch_keepsAnEmptyValue',
      () async {
        // 上游：无匹配时该分支返回空串；空串是「替换后的结果」，不再是提取阶段能丢掉的东西。
        expect(
          await _values(
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

    test('extractAll_givenFourPartReplacementWithAnUncompilablePattern_returnsTheReplacement', () async {
      // 上游：正则不可编译时，`replaceFirst` 分支直接返回替换串本身。
      expect(
        await _values(
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
    test('applyReplaceRule_givenStandaloneForm_deletesEveryMatch', () async {
      // `ruleContent.replaceRegex` 的真实写法（test/fixtures/book_sources/
      // legado_export_sanitized.json）：只有替换段，没有选择器。
      expect(
        await _text(
          _engine().applyReplaceRule(
            '##本章未完，点击下一页继续阅读。',
            '正文。本章未完，点击下一页继续阅读。后续。本章未完，点击下一页继续阅读。',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '正文。后续。',
      );
    });

    test('applyReplaceRule_givenTheExplicitAllBody_appliesIt', () async {
      // 上游文档：「独立使用相当于 `all##正则##替换`」。
      expect(
        await _text(
          _engine().applyReplaceRule(
            r'all##\s+##',
            '第一段   第二段',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '第一段第二段',
      );
    });

    test('applyReplaceRule_givenGroupReference_expandsTheGroup', () async {
      expect(
        await _text(
          _engine().applyReplaceRule(
            r'##(\d+)##[$1]',
            '共 123 字',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '共 [123] 字',
      );
    });

    test(
      'applyReplaceRule_givenTheFourPartForm_returnsTheFirstMatchOnly',
      () async {
        // 矩阵 #25：`###` 取第一个匹配并在其内部替换，不是替换整串里的第一处。
        expect(
          await _text(
            _engine().applyReplaceRule(
              '##a##b###',
              'xax ax',
              rulePath: 'contentRule.replaceRegex',
            ),
          ),
          'b',
        );
      },
    );

    test('applyReplaceRule_givenNoReplacement_passesTheTextThrough', () async {
      expect(
        await _text(
          _engine().applyReplaceRule(
            'all',
            '正文。',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '正文。',
      );
    });

    test('applyReplaceRule_givenDeferredFlag_reportsUnsupportedRule', () async {
      // 标志头按规则原文保留大小写（book-source.md §3 前缀大小写不敏感）。
      expect(
        (await _failure(
          _engine().applyReplaceRule(
            '@XPath://div',
            '正文。',
            rulePath: 'contentRule.replaceRegex',
          ),
        )).rulePath,
        'unsupported:@XPath:',
      );
      expect(
        (await _failure(
          _engine().applyReplaceRule(
            '@xpath://div',
            '正文。',
            rulePath: 'contentRule.replaceRegex',
          ),
        )).kind,
        ParseFailureKind.unsupportedRule,
      );
    });

    test(
      'applyReplaceRule_givenSelectorBody_reportsParseFailedAtTheField',
      () async {
        // 带选择器的规则体在纯文本上没有可读的节点：报畸形（带字段路径），不静默丢掉选择器。
        final ParseFailure<Never> failure = await _failure(
          _engine().applyReplaceRule(
            'class.a@text##x##y',
            '正文。',
            rulePath: 'contentRule.replaceRegex',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'contentRule.replaceRegex');
      },
    );
  });

  group('RuleEngine extractFirst', () {
    test('extractFirst_givenSeveralMatches_returnsTheFirstValue', () async {
      expect(
        await _first(
          _engine().extractFirst(
            'tag.a@href',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        '/book/1',
      );
    });

    test('extractFirst_givenNoMatch_returnsNullData', () async {
      expect(
        await _first(
          _engine().extractFirst(
            'class.absent@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.intro',
          ),
        ),
        isNull,
      );
    });

    test('extractFirst_givenRejectedRule_returnsTheSameFailure', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractFirst(
          '@xpath://div',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.intro',
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@xpath:');
    });
  });

  group('RuleEngine matrix #3 (text)', () {
    test('selectAll_givenTextRule_matchesTheElementHoldingThatText', () async {
      final List<Element> elements = await _elements(
        _engine().selectAll(
          'text.Second',
          _scope(_document(_chapterHtml)),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.localName, 'p');
    });

    test('selectAll_givenTextRule_matchesOwnTextNotTheParentsText', () async {
      // `b` 的自身文本是 `bold`，它的祖先（`p` / `#content`）自身文本里没有它，
      // 所以只命中 `b` 本身——上游用的是 getElementsContainingOwnText，
      // getElementsContainingText 会额外命中祖先。
      final List<Element> elements = await _elements(
        _engine().selectAll(
          'text.bold',
          _scope(_document(_chapterHtml)),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.localName, 'b');
    });

    test(
      'selectAll_givenTextRuleAndAnElementScope_includesTheScopeItself',
      () async {
        final Element scope = _document(_chapterHtml)
            .querySelectorAll('p')
            .first;

        final List<Element> elements = await _elements(
          _engine().selectAll(
            'text.First',
            _scope(scope),
            rulePath: 'tocRule.chapterList',
          ),
        );

        expect(elements, hasLength(1));
        expect(elements.single, same(scope));
      },
    );

    test('selectAll_givenTextRule_isCaseInsensitive', () async {
      expect(
        await _elements(
          _engine().selectAll(
            'text.SECOND',
            _scope(_document(_chapterHtml)),
            rulePath: 'tocRule.chapterList',
          ),
        ),
        hasLength(1),
      );
    });

    test('selectAll_givenTextRuleWithAPosition_takesThatMatch', () async {
      final List<Element> elements = await _elements(
        _engine().selectAll(
          'text.Author.-1',
          _scope(_document(_listHtml)),
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(elements, hasLength(1));
      expect(elements.single.text, 'Author C');
    });

    test('selectAll_givenTextRuleWithoutItsName_returnsParseFailed', () async {
      // 矩阵 #3 的第二段是文本内容的一部分；只写 `text` 没有任何内容可匹配。
      final ParseFailure<Never> failure = await _failure(
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
    test('selectAll_givenChildrenRule_returnsTheDirectChildrenOnly', () async {
      final Element scope = _document(_listHtml).querySelectorAll('ul').single;

      final List<Element> elements = await _elements(
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

    test('selectAll_givenChildrenRuleWithExtraSegments_ignoresThem', () async {
      final Element scope = _document(_listHtml).querySelectorAll('ul').single;

      // 矩阵 #4：`children` 取全部子标签，忽略第二、三段。
      expect(
        await _elements(
          _engine().selectAll(
            'children.li.0',
            _scope(scope),
            rulePath: 'tocRule.chapterList',
          ),
        ),
        hasLength(3),
      );
    });

    test('extractAll_givenChildrenRule_chainsIntoTheNextSelector', () async {
      final Element scope = _document(_listHtml).querySelectorAll('ul').single;

      expect(
        await _values(
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
    test('selectAll_givenExcludedIndex_dropsThatMatch', () async {
      expect(await _hrefsForList('!0'), <String?>['/book/2', '/book/3']);
    });

    test('selectAll_givenSeveralExcludedIndices_dropsThemAll', () async {
      // 矩阵 #6：`!` 后面的序号用 `:` 隔开，负数为倒数序号。
      expect(await _hrefsForList('!0:2'), <String?>['/book/2']);
      expect(await _hrefsForList('!-1'), <String?>['/book/1', '/book/2']);
    });

    test(
      'selectAll_givenExcludedIndexBeyondTheMatches_keepsEveryMatch',
      () async {
        expect(await _hrefsForList('!9'), <String?>[
          '/book/1',
          '/book/2',
          '/book/3',
        ]);
      },
    );

    test('extractAll_givenExclusionAndAnExtraction_returnsTheRest', () async {
      expect(
        await _values(
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
    test('selectAll_givenLeadingDash_reversesTheResultList', () async {
      final List<Element> elements = await _elements(
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

    test('extractAll_givenLeadingDash_reversesTheValues', () async {
      expect(
        await _values(
          _engine().extractAll(
            '-class.result-list@tag.a@href',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/3', '/book/2', '/book/1'],
      );
    });

    test('extractFirst_givenLeadingDash_returnsTheLastMatch', () async {
      expect(
        await _first(
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
    test('selectAll_givenABracketIndex_returnsThatMatch', () async {
      expect(await _hrefsForList('[-1]'), <String?>['/book/3']);
    });

    test(
      'selectAll_givenSeveralBracketIndices_keepsTheAuthoredOrder',
      () async {
        // 矩阵 #26：`[index,index,...]`，顺序按写法，不是升序。
        expect(await _hrefsForList('[2,0]'), <String?>['/book/3', '/book/1']);
      },
    );

    test('selectAll_givenABracketRange_returnsEveryIndexInsideIt', () async {
      expect(await _hrefsForList('[0:1]'), <String?>['/book/1', '/book/2']);
      // 上游规则文档：start 为 0 时可省略，end 为 -1 时可省略。
      expect(await _hrefsForList('[:1]'), <String?>['/book/1', '/book/2']);
      expect(await _hrefsForList('[1:]'), <String?>['/book/2', '/book/3']);
    });

    test('selectAll_givenABracketRangeWithStep_returnsEveryStep', () async {
      expect(await _hrefsForList('[0:2:2]'), <String?>['/book/1', '/book/3']);
      expect(await _hrefsForList('[2:0:-1]'), <String?>[
        '/book/3',
        '/book/2',
        '/book/1',
      ]);
    });

    test('selectAll_givenADescendingRange_reversesTheMatches', () async {
      // 上游规则文档的 `tag.div[-1:0]`：不写 step 时方向由两端决定。
      expect(await _hrefsForList('[-1:0]'), <String?>[
        '/book/3',
        '/book/2',
        '/book/1',
      ]);
    });

    test('selectAll_givenExcludedBracketIndices_dropsThem', () async {
      expect(await _hrefsForList('[!0]'), <String?>['/book/2', '/book/3']);
      expect(await _hrefsForList('[!1:2]'), <String?>['/book/1']);
    });

    test(
      'selectAll_givenABracketIndexBeyondTheMatches_returnsNothing',
      () async {
        expect(await _hrefsForList('[9]'), isEmpty);
        expect(await _hrefsForList('[-9]'), isEmpty);
      },
    );

    test(
      'selectAll_givenARangeStartingBeforeTheList_keepsTheRangeInside',
      () async {
        // 负索引落到列表之前：端点会被夹到列表外一格，越界的部分直接丢掉。
        expect(await _hrefsForList('[-9:0]'), <String?>['/book/1']);
      },
    );

    test(
      'selectAll_givenABracketRangeBeyondTheMatches_stopsAtTheListEnd',
      () async {
        // 区间端点被夹到列表之外一格，书源写超大区间也不能把解析卡住（C-SRC-9）。
        expect(await _hrefsForList('[0:999999]'), <String?>[
          '/book/1',
          '/book/2',
          '/book/3',
        ]);
      },
    );
  });

  group('RuleEngine matrix #28 (index as the first rule of a segment)', () {
    test('selectAll_givenABareIndexSegment_usesTheDirectChildren', () async {
      // 上游 doc：索引作为分段首规则时，相当于前面是 `children`。
      expect(await _hrefsFor('[1]'), <String?>['/book/2']);
      expect(await _hrefsFor('.1'), <String?>['/book/2']);
      expect(await _hrefsFor('children[1]'), <String?>['/book/2']);
    });

    test('selectAll_givenTheThreeSpellings_agreeWithEachOther', () async {
      // `.1` ≡ `[1]` ≡ `children[1]`（上游 doc 的等价式），也与 `children.1` 一致。
      expect(await _hrefsFor('.1'), await _hrefsFor('[1]'));
      expect(await _hrefsFor('children[1]'), await _hrefsFor('[1]'));
      expect(await _hrefsFor('children.1'), await _hrefsFor('[1]'));
    });

    test('selectAll_givenAnExcludedIndexSegment_dropsThatChild', () async {
      expect(await _hrefsFor('!0'), <String?>['/book/2', '/book/3']);
      expect(await _hrefsFor('[!0]'), <String?>['/book/2', '/book/3']);
    });

    test('selectAll_givenAnIndexListSegment_keepsTheAuthoredOrder', () async {
      expect(await _hrefsFor('.0:2'), <String?>['/book/1', '/book/3']);
      expect(await _hrefsFor('[0:1]'), <String?>['/book/1', '/book/2']);
    });

    test(
      'selectAll_givenChildrenWithASegmentName_keepsMatrixFourBehaviour',
      () async {
        // `children.li.0` 不是索引写法：矩阵 #4 规定第二、三段被忽略。
        expect(await _hrefsFor('children.li.0'), await _hrefsFor('children'));
      },
    );
  });

  group('RuleEngine connectors (#10 || / #11 && / #27 %%)', () {
    test(
      'extractAll_givenDoublePipe_takesTheFirstCandidateWithValues',
      () async {
        // 矩阵 #10：依次尝试，首个非空即成功。
        expect(
          await _values(
            _engine().extractAll(
              'class.absent@text||class.result-list@tag.li.0@text',
              _scope(_document(_listHtml)),
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['One Author A'],
        );
      },
    );

    test('extractAll_givenOnlyEmptyCandidates_succeedsWithNoValues', () async {
      expect(
        await _values(
          _engine().extractAll(
            'class.absent@text||class.alsoAbsent@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test(
      'extractAll_givenDoubleAmpersand_mergesBothBranchesInRuleOrder',
      () async {
        // 矩阵 #11：`&&` 合并两侧结果（并集、非串联）。
        expect(
          await _values(
            _engine().extractAll(
              'class.result-list@tag.li.0@text'
              '&&class.result-list@tag.li.1@text',
              _scope(_document(_listHtml)),
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['One Author A', 'Two Author B'],
        );
      },
    );

    test('selectAll_givenDoubleAmpersand_concatenatesTheElements', () async {
      expect(
        await _elements(
          _engine().selectAll(
            'class.result-list@tag.li.0&&class.result-list@tag.li.2',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(2),
      );
    });

    test('extractAll_givenDoublePercent_interleavesTheBranches', () async {
      // 矩阵 #27：`%%` 交叉取数（依次从各列表取）。
      expect(
        await _values(
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

    test('extractAll_givenMixedConnectors_groupsAmpersandFirst', () async {
      // `a&&b||c` = `(a&&b)||c`：`||` 最松先切（book-source.md §3.2）。
      expect(
        await _values(
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

    test(
      'extractAll_givenAConnectorInsideBracketsOrQuotes_keepsItLiteral',
      () async {
        // `[...]` / `(...)` / 引号内的分隔符属于选择器：若被切开，选择器会残缺而报
        // parseFailed，所以「成功且为空」恰好证明保护生效。
        final Document document = _document(_listHtml);

        expect(
          await _values(
            _engine().extractAll(
              '@css:a[href="x&&y"]@text',
              _scope(document),
              rulePath: 'searchRule.name',
            ),
          ),
          isEmpty,
        );
        expect(
          await _values(
            _engine().extractAll(
              '@css:a:matches(/x&&y/)@text',
              _scope(document),
              rulePath: 'searchRule.name',
            ),
          ),
          isEmpty,
        );
      },
    );

    test(
      'extractAll_givenASeparatorAfterABracketedSelector_stillSplits',
      () async {
        // 扫描器必须跳过 `[...]` 与引号内的字符，但仍在它们之后的连接符处切分。
        expect(
          await _values(
            _engine().extractAll(
              'class.result-list@tag.li.0@text&&@css:a[href="/book/2"]@text',
              _scope(_document(_listHtml)),
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['One Author A', 'Two'],
        );
      },
    );

    test('selectAll_givenAValueBranchInAListRule_returnsParseFailed', () async {
      // 跨类型合并必须显式失败，不得静默拼成异构列表。
      final ParseFailure<Never> failure = await _failure(
        _engine().selectAll(
          'class.result-list&&class.result-list@text',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test('selectAll_givenAnUnknownTypeInAListRule_matchesItAsCss', () async {
      // ADR-0032 改变了这里的语义：`href` 不再是「不支持的类型」，而是原始 CSS 选择器
      //（`doc.select("href")`，匹配不到任何元素）。列表规则里写取值段仍然不是
      // 跨类型检测——上一条 `text` 借道「段结构畸形」报 parseFailed，这里则是空匹配。
      expect(
        await _elements(
          _engine().selectAll(
            'class.result-list&&class.result-list@href',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(1),
      );
    });

    test('extractAll_givenAnEmptyBranch_returnsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          'class.result-list@text||',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('selectAll_givenADeferredFlagInALaterCandidate_reportsIt', () async {
      // body 级标志检查只覆盖规则开头；后续候选的标志头由选择器层拒绝。
      final ParseFailure<Never> failure = await _failure(
        _engine().selectAll(
          'class.result-list||@xpath://div',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@xpath:');
    });
  });

  group('RuleEngine matrix #12 (@css:)', () {
    test('selectAll_givenCssRule_returnsEveryMatch', () async {
      final List<Element> elements = await _elements(
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

    test('selectAll_givenAnUppercaseFlag_isTheSameRule', () async {
      // book-source.md §3：前缀大小写不敏感。
      expect(
        await _elements(
          _engine().selectAll(
            '@CSS:ul.result-list > li',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(3),
      );
    });

    test('extractAll_givenCssRule_chainsIntoDefaultSegments', () async {
      // `@css:` 段与默认规则段可以混用：先按 CSS 选中条目，再在其内部取属性。
      expect(
        await _values(
          _engine().extractAll(
            '@css:ul.result-list > li@tag.a@href',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/1', '/book/2', '/book/3'],
      );
    });

    test('extractAll_givenAnAttributeSelector_usesCascadia', () async {
      expect(
        await _values(
          _engine().extractAll(
            '@css:a[href="/book/2"]@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['Two'],
      );
    });

    test('extractAll_givenAPseudoClassCascadiaSupports_matches', () async {
      // 真实语料用的 `:contains` / `:containsOwn` 都在 cascadia 里，可直接用。
      // 注意：cascadia 不接受**带空格的不加引号参数**（`containsOwn(Author B)` 会报
      // Invalid argument），jsoup 则接受；真实语料的 `containsOwn(下一页)` 不带空格。
      expect(
        await _values(
          _engine().extractAll(
            '@css:li:contains(Three)@tag.a@href',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/3'],
      );
      expect(
        await _values(
          _engine().extractAll(
            '@css:span:containsOwn(Author)@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.author',
          ),
        ),
        <String>['Author A', 'Author B', 'Author C'],
      );
    });

    test('extractAll_givenAnIndexPseudo_matchesTheSiblingIndex', () async {
      // 矩阵 #29：jsoup 的 `:eq(n)` 是**兄弟索引**，不是结果集索引。镜像 jsoup 自己的
      // SelectorTest.testPseudoEquals（`div p:eq(0)` 每个 div 各取一个 p）。
      final Document document = _document(
        '<div><p>One</p><p>Two</p></div><div><p>Four</p></div>',
      );

      expect(
        await _values(
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
      () async {
        // jsoup 文档：`td:lt(3)` = 每行的前三个单元格，`td:gt(1)` = 跳过前两个。
        final Document document = _document(
          '<table><tr><td>1</td><td>2</td><td>3</td><td>4</td></tr></table>',
        );

        expect(
          await _values(
            _engine().extractAll(
              '@css:td:lt(3)@text',
              _scope(document),
              rulePath: 'x',
            ),
          ),
          <String>['1', '2', '3'],
        );
        expect(
          await _values(
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

    test(
      'selectAll_givenANegativeIndexPseudo_returnsUnsupportedRule',
      () async {
        // jsoup 文档把索引伪类定义为 0-based 且未定义负索引 → 本仓不猜，点名拒绝。
        final ParseFailure<Never> failure = await _failure(
          _engine().selectAll(
            '@css:li:eq(-1)',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        );

        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported::eq(-1)');
      },
    );

    test(
      'selectAll_givenAnUnparsableIndexArgument_returnsParseFailed',
      () async {
        final ParseFailure<Never> failure = await _failure(
          _engine().selectAll(
            '@css:li:eq(99999999999999999999)',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'searchRule.bookList');
      },
    );

    test(
      'selectAll_givenAStandardPseudoStartingWithTheSameLetters_isNotMisread',
      () async {
        // `:first-child` 不能被当成 jsoup 的 `:first`（cascadia 支持标准伪类）。
        expect(
          await _elements(
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

    test('selectAll_givenMalformedCss_returnsParseFailedAtTheField', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().selectAll(
          '@css:ul >',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test('selectAll_givenAnEmptyCssSelector_returnsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().selectAll(
          '@css:',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test('extractAll_givenTheFlagInAMiddleSegment_chainsThroughIt', () async {
      // 中段的 `@css:`（`class.x@css:.y@text`）本次从 unsupported 变为可用：F1。
      expect(
        await _values(
          _engine().extractAll(
            'class.result-list@css:li@tag.a@href',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/1', '/book/2', '/book/3'],
      );
    });

    test('selectAll_givenAStatePseudoClass_succeedsWithNoMatch', () async {
      // 静态 DOM 下没有元素处于 hover：cascadia 解析成功、匹配恒为 false。这是「正确
      // 答案」而不是错误，故登记为成功且为空（矩阵 #12 注记，架构师裁决 5）。
      expect(
        await _elements(
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
    test('extractAll_givenAJsonFlag_returnsTheValueAtThePath', () async {
      expect(
        await _values(
          _engine().extractAll(
            r'@json:$.data.name',
            _page(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One'],
      );
    });

    test('extractAll_givenABareDollarPath_returnsTheValueAtThePath', () async {
      // 矩阵 #13：以 `$.` 开头时可省略 `@json:` 标志。
      expect(
        await _values(
          _engine().extractAll(
            r'$.data.name',
            _page(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One'],
      );
    });

    test(
      'extractAll_givenAnUpperCasedJsonFlag_returnsTheValueAtThePath',
      () async {
        expect(
          await _values(
            _engine().extractAll(
              r'@Json:$.data.name',
              _page(_jsonBody),
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['One'],
        );
      },
    );

    test(
      'extractAll_givenAJsonPathFilter_keepsItsAtSignAndAmpersands',
      () async {
        // 过滤器里有 `@`（若按 `@` 切段会被吃掉）与 `&&`（若按连接符切分会被当成合并），
        // 所以整条分支必须在切段与切分之前就被识别成 JSONPath。
        expect(
          await _values(
            _engine().extractAll(
              r'$.rows[?(@.a==1 && @.b==2)].b',
              _page(_jsonBody),
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['2'],
        );
      },
    );

    test('extractAll_givenJsonScalars_returnsTheirJsonText', () async {
      final RuleScope page = _page(_jsonBody);

      expect(
        await _values(
          _engine().extractAll(
            r'$.data.count',
            page,
            rulePath: 'searchRule.wordCount',
          ),
        ),
        <String>['3'],
      );
      expect(
        await _values(
          _engine().extractAll(
            r'$.data.adult',
            page,
            rulePath: 'searchRule.kind',
          ),
        ),
        <String>['false'],
      );
    });

    test('extractAll_givenAJsonListValue_expandsItIntoValues', () async {
      // 上游把「path 命中一个列表」展开成逐元素的值（`AnalyzeByJSonPath.kt:83-87`），
      // 所以 `$.data.tags` 给 `a` / `b` 两个值，而不是一段 JSON 文本。
      expect(
        await _values(
          _engine().extractAll(
            r'$.data.tags',
            _page(_jsonBody),
            rulePath: 'searchRule.kind',
          ),
        ),
        <String>['a', 'b'],
      );
    });

    test('extractAll_givenAJsonObjectValue_returnsItAsJsonText', () async {
      expect(
        await _values(
          _engine().extractAll(
            r'$.data.list[0]',
            _page(_jsonBody),
            rulePath: 'searchRule.intro',
          ),
        ),
        <String>['{"name":"One","url":"/book/1"}'],
      );
    });

    test('extractAll_givenAnEmptyOrNullJsonValue_returnsNoValue', () async {
      // 与矩阵 #8 的空提取同口径：空字符串与 null 都不产生值，不报失败。
      final RuleScope page = _page(_jsonBody);

      expect(
        await _values(
          _engine().extractAll(
            r'$.data.empty',
            page,
            rulePath: 'searchRule.intro',
          ),
        ),
        isEmpty,
      );
      expect(
        await _values(
          _engine().extractAll(
            r'$.data.none',
            page,
            rulePath: 'searchRule.intro',
          ),
        ),
        isEmpty,
      );
    });

    test('extractAll_givenAMalformedJsonPath_returnsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          r'@json:$[',
          _page(_jsonBody),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenAnEmptyJsonPath_returnsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          '@json:',
          _page(_jsonBody),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenANonJsonBody_returnsParseFailed', () async {
      // 页面根本不是 JSON：规则本身没错，是这一页回答不了它（≠ 成功且为空）。
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          r'$.data.name',
          _page(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenAJsonRuleOnAnElement_returnsParseFailed', () async {
      // 元素 scope 没有原始 body：元素内部的 JSON 需要提取段嵌套规则（矩阵 #30）。
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          r'$.data.name',
          _scope(_document(_listHtml).querySelectorAll('li').first),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenMixedScopeOr_returnsParseFailed', () async {
      // 已裁决行为，本用例用来**钉住**它：`||` 的候选一旦**失败**就整条终止，不会去试后面的
      // DOM 候选，也不会回退。HTML 页的 body 不是 JSON，所以 `$.a` 失败、`class.b@text` 根本
      // 不会被求值。若有人把它「修」成能回退，这里会红。
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          r'$.a||class.b@text',
          _page(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenADomRuleOnAJsonScope_returnsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          'class.result@text',
          const JsonScope(<String, Object?>{'name': 'One'}),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenADomRuleOnAJsonPage_returnsAnEmptySuccess', () async {
      // 方向不对称，且是有意的：DOM 规则打在 **JSON 页** 上不是失败——页面仍然是一份解析出来
      // 的文档，选择器零匹配就是矩阵 #8 的「成功但为空」。只有上面那种「匹配项本身是 JSON 值」
      // 才连 DOM 都没有，才报 parseFailed。
      expect(
        await _values(
          _engine().extractAll(
            'class.result@text',
            _page(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        isEmpty,
      );
    });

    test('selectAll_givenAJsonListRule_returnsOneScopePerValue', () async {
      final List<RuleScope> items = await _matches(
        _engine().selectAll(
          r'$.data.list[*]',
          _page(_jsonBody),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(items, hasLength(2));
      // 列表规则的每个匹配都是下一级的 scope，字段规则在它上面读。
      expect(
        await _values(
          _engine().extractAll(
            r'$.name',
            items.first,
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One'],
      );
      expect(
        await _values(
          _engine().extractAll(
            r'@json:$.url',
            items.last,
            rulePath: 'searchRule.bookUrl',
          ),
        ),
        <String>['/book/2'],
      );
    });

    test(
      'selectAll_givenAJsonRuleMatchingAnArray_returnsOneScopePerElement',
      () async {
        // 上游把命中的列表本身当作元素列表（`AnalyzeByJSonPath.kt:137` 的
        // `read<ArrayList<Any>>`），所以 `$.data.list`（无 `[*]`）也必须给两个条目——
        // 真实 JSON API 源就是这么写的（docs/dev/roadmap.md 3.7 在 猫耳FM 的 `searchRule.bookList` 上核对）。
        final List<RuleScope> items = await _matches(
          _engine().selectAll(
            r'$.data.list',
            _page(_jsonBody),
            rulePath: 'searchRule.bookList',
          ),
        );

        expect(items, hasLength(2));
        expect(
          await _values(
            _engine().extractAll(
              r'$.name',
              items.first,
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['One'],
        );
        expect(
          await _values(
            _engine().extractAll(
              r'$.url',
              items.last,
              rulePath: 'searchRule.bookUrl',
            ),
          ),
          <String>['/book/2'],
        );
      },
    );

    test(
      'selectAll_givenAJsonRuleMatchingAScalar_returnsThatOneScope',
      () async {
        // 非列表的命中仍然是「一个 scope」，展开只针对列表。
        final List<RuleScope> items = await _matches(
          _engine().selectAll(
            r'$.data.name',
            _page(_jsonBody),
            rulePath: 'searchRule.bookList',
          ),
        );

        expect(items, hasLength(1));
        expect(switch (items.single) {
          JsonScope(:final Object? value) => value,
          DomScope() => fail('Expected a JSON scope.'),
        }, 'One');
      },
    );

    test('selectAll_givenAReversedJsonListRule_reversesTheMatches', () async {
      final List<RuleScope> items = await _matches(
        _engine().selectAll(
          r'-$.data.list[*]',
          _page(_jsonBody),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(
        await _values(
          _engine().extractAll(
            r'$.name',
            items.first,
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['Two'],
      );
    });

    test('selectAll_givenADomRuleOnAJsonScope_returnsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
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
      () async {
        // `book-source.md` §3 的 `&&` 注记：连接符只合并同种规则，跨 scope 合并语义未定义。
        final ParseFailure<Never> failure = await _failure(
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

    test('selectAll_givenAJsonRuleInAListScope_returnsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().selectAll(
          r'$.data.list[*]',
          _page(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.bookList');
    });

    test(
      'extractAll_givenABracketFollowedByAMemberName_readsItLikeUpstream',
      () async {
        // b5：Legado 接受 `]` 后直接跟成员名（漫客栈的正文规则就是
        // `$.data.page[*]image`），RFC 9535 只认 `[*].image`。
        expect(
          await _values(
            _engine().extractAll(
              r'$.data.page[*]image',
              _page('{"data":{"page":[{"image":"a.jpg"},{"image":"b.jpg"}]}}'),
              rulePath: 'contentRule.content',
            ),
          ),
          <String>['a.jpg', 'b.jpg'],
        );
      },
    );

    test('extractAll_givenADotBeforeASubscript_readsItLikeUpstream', () async {
      // M12-A6：`$.[*]` 是 Legado 的写法（宜搜小说 / 有声听书网的 `bookList`），
      // RFC 9535 的下标前不允许那个点。
      expect(
        await _values(
          _engine().extractAll(
            r'$.[*]',
            _page('[{"name":"a"},{"name":"b"}]'),
            rulePath: 'searchRule.bookList',
          ),
        ),
        <String>['{"name":"a"}', '{"name":"b"}'],
      );
    });

    test(
      'extractAll_givenABracketFollowedByAMemberNameAtTheRoot_readsIt',
      () async {
        // `$[0]b`（裸 `$[` 头）也要归一成 `$[0].b`。
        expect(
          await _values(
            _engine().extractAll(
              r'$[0]b',
              _page('[{"b":"v"}]'),
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['v'],
        );
      },
    );

    test(
      'extractAll_givenAClosedBracketInsideAQuotedMember_keepsItIntact',
      () async {
        // 边界：引号里的 `]` 不是括号，只在真正的 `]` 后面补点。
        expect(
          await _values(
            _engine().extractAll(
              r"$['a]']b",
              _page('{"a]":{"b":"v"}}'),
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['v'],
        );
      },
    );

    test('extractAll_givenABracketFollowedByANonAsciiMember_readsIt', () async {
      // 边界：非 ASCII 成员名（中文键）也算标识符开头。
      expect(
        await _values(
          _engine().extractAll(
            r'$.data.列表[0]名称',
            _page('{"data":{"列表":[{"名称":"v"}]}}'),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['v'],
      );
    });

    test(
      'extractAll_givenAnAlreadyDottedOrBracketedPath_leavesItAlone',
      () async {
        // 边界：`].` 与 `][` 那些写法一个字符也不动。
        expect(
          await _values(
            _engine().extractAll(
              r'$.data.list[0][1]',
              _page('{"data":{"list":[[1,2,3]]}}'),
              rulePath: 'searchRule.name',
            ),
          ),
          <String>['2'],
        );
      },
    );

    test(
      'extractAll_givenAMemberNameAfterWhitespace_leavesItToTheParser',
      () async {
        // 边界：`]` 后是空白时不补点（本仓不猜它对不对），仍然由解析器报错。
        final ParseFailure<Never> failure = await _failure(
          _engine().extractAll(
            r'$.data.page[*] image',
            _page('{"data":{"page":[{"image":"a.jpg"}]}}'),
            rulePath: 'contentRule.content',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
      },
    );
  });

  group('RuleEngine ADR-0032 (unknown type degrades to CSS)', () {
    test('selectAll_givenABareTagType_matchesEveryElementOfThatTag', () async {
      // 真实语料里最高频的形态：`li` / `dd` / `p` 直接当类型写。
      expect(
        await _elements(
          _engine().selectAll(
            'li',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(3),
      );
    });

    test('selectAll_givenALeadingDotType_matchesThatClass', () async {
      // `.searchresult`：空类型不是畸形，而是一段原始 CSS。
      expect(
        await _elements(
          _engine().selectAll(
            '.result-list',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookList',
          ),
        ),
        hasLength(1),
      );
    });

    test('selectAll_givenAHashType_matchesThatId', () async {
      expect(
        await _elements(
          _engine().selectAll(
            '#content',
            _scope(_document(_chapterHtml)),
            rulePath: 'bookInfoRule.init',
          ),
        ),
        hasLength(1),
      );
    });

    test('selectAll_givenAnUnknownTypeWithExclusion_dropsThatIndex', () async {
      // `li!0`：`!` 后缀仍按位置解析（`tr!0` 不是合法 CSS，不能整段丢给 cascadia）。
      expect(
        await _elements(
          _engine().selectAll(
            'li!0',
            _scope(_document(_listHtml)),
            rulePath: 'tocRule.chapterList',
          ),
        ),
        hasLength(2),
      );
    });

    test(
      'extractAll_givenADegradedSelectorWithAClassQualifier_extractsIt',
      () async {
        expect(
          await _values(
            _engine().extractAll(
              'span.dupe@data-x',
              _scope(_document(_chapterHtml)),
              rulePath: 'bookInfoRule.kind',
            ),
          ),
          <String>['same'],
        );
      },
    );

    test('selectAll_givenAJsonPseudoInADegradedSelector_rewritesIt', () async {
      // 矩阵 #29 的改写对退化段同样生效：`:eq` 是兄弟索引，不是结果集索引。
      expect(
        await _elements(
          _engine().selectAll(
            'p.line:eq(1)',
            _scope(_document(_chapterHtml)),
            rulePath: 'contentRule.content',
          ),
        ),
        hasLength(1),
      );
    });

    test(
      'selectAll_givenAnUnknownTypeWithABracketPosition_takesThatMatch',
      () async {
        // 退化段的位置后缀走同一套解析：`li[0]` = 原始 CSS `li` + 位置 0。
        expect(
          await _elements(
            _engine().selectAll(
              'li[0]',
              _scope(_document(_listHtml)),
              rulePath: 'tocRule.chapterList',
            ),
          ),
          hasLength(1),
        );
      },
    );

    test(
      'extractAll_givenADegradedSelectorThatIsNotCss_returnsParseFailed',
      () async {
        final ParseFailure<Never> failure = await _failure(
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

  group('RuleEngine matrix #31 (<js> wrapper)', () {
    test('extractFirst_givenABareJsBlock_runsItOnThePageBody', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'ok';

      final String? value = await _first(
        _engine(null, bridge).extractFirst(
          '<js>result.length</js>',
          _pageWithContext(_countHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(value, 'ok');
      expect(bridge.jobs.single.result, _countHtml);
    });

    test('extractFirst_givenJsThenText_feedsTheResultIntoTheTemplate', () async {
      // 真实写法：`<js>java.put('cid', …)</js>https://…/{{result}}/info.html` —— 脚本的产出
      // 通过 `{{result}}` 拼进后面的文本，整段就是这一条规则的值。
      final FakeJsBridge bridge = FakeJsBridge()..result = '42';

      final String? value = await _first(
        _engine(null, bridge).extractFirst(
          '<js>java.put("cid", 42)</js>https://infos.test/{{result}}/info.html',
          _pageWithContext(_countHtml),
          rulePath: 'searchRule.bookUrl',
        ),
      );

      expect(value, 'https://infos.test/42/info.html');
      // 第一段是脚本，第二段的 `{{result}}` 是又一次沙箱调用，拿到的正是第一段的产出。
      expect(bridge.jobs, hasLength(2));
      expect(bridge.jobs.last.result, '42');
      expect(bridge.jobs.first.rulePath, 'searchRule.bookUrl');
    });

    test('extractFirst_givenTextThenJs_passesTheExtractedValues', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'done';

      final String? value = await _first(
        _engine(null, bridge).extractFirst(
          'class.title@text<js>result.length</js>',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.kind',
        ),
      );

      expect(value, 'done');
      // 选择器段的产出就是脚本的 `result`（单值字段传第一个值，§4.1）。
      expect(bridge.jobs.single.result, 'One');
    });

    test('extractFirst_givenAFailingScript_failsTheWholeRule', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = const ParseFailure<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'js:error',
        );

      final Future<ParseFailure<Never>> result = _failure(
        _engine(null, bridge).extractFirst(
          '<js>boom()</js>https://x.test/{{result}}',
          _pageWithContext(_countHtml),
          rulePath: 'searchRule.bookUrl',
        ),
      );

      expect((await result).rulePath, 'js:error');
    });

    test('extractFirst_givenJsBlockAndTrailingJsFlag_chainsBoth', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..results.addAll(<Object?>['mid', 'end']);

      final String? value = await _first(
        _engine(null, bridge).extractFirst(
          '<js>"mid"</js>@js:result + "!"',
          _pageWithContext(_countHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(value, 'end');
      // 第二段拿到的是第一段的产出。
      expect(bridge.jobs.last.result, 'mid');
    });
  });

  group('RuleEngine book context (ADR-0049)', () {
    test(
      'extractFirst_givenAPageContextWithNames_carriesThemOnTheJob',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ok';

        await _first(
          _engine(null, bridge).extractFirst(
            '@js:java.get("bookName") + java.get("title")',
            RuleScope.dom(
              parser.parse(_countHtml),
              body: _countHtml,
              jsContext: const JsPageContext(
                baseUrl: 'https://example-novel.test/book/1/2.html',
                source: JsSourceInfo(
                  name: '示例书源',
                  url: 'https://example-novel.test',
                ),
                bookName: '示例书',
                chapterTitle: '第一章',
              ),
            ),
            rulePath: 'contentRule.content',
          ),
        );

        expect(bridge.jobs.single.bookName, '示例书');
        expect(bridge.jobs.single.chapterTitle, '第一章');
      },
    );

    test('extractFirst_givenAPageContextWithoutNames_leavesThemNull', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'ok';

      await _first(
        _engine(null, bridge).extractFirst(
          '@js:1',
          _pageWithContext(_countHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(bridge.jobs.single.bookName, isNull);
      expect(bridge.jobs.single.chapterTitle, isNull);
    });
  });

  group('RuleEngine result binding', () {
    test('extractFirst_givenABareJsRuleOnANullJsonScope_passesNull', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'ok';

      final String? value = await _first(
        _engine(null, bridge).extractFirst(
          '@js:result',
          RuleScope.json(null),
          rulePath: 'searchRule.name',
        ),
      );

      expect(value, 'ok');
      // 空 JSON 值就是 `null`（上游把 `content` 原样绑给 `result`）。
      expect(bridge.jobs.single.result, isNull);
    });
  });

  group('RuleEngine matrix #14 (@js:)', () {
    test('extractFirst_givenABareJsRule_runsItOnThePageBody', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = '正文尾';

      final String? value = await _first(
        _engine(null, bridge).extractFirst(
          "@js:result + '尾'",
          _pageWithContext(_countHtml),
          rulePath: 'contentRule.content',
        ),
      );

      expect(value, '正文尾');
      expect(bridge.jobs.single.script, "result + '尾'");
      // 独立 `@js:` 的 `result` 是整页 responseBody（§6 的 result 绑定）。
      expect(bridge.jobs.single.result, _countHtml);
      expect(bridge.jobs.single.rulePath, 'contentRule.content');
    });

    test(
      'extractFirst_givenJsAfterSelectors_passesTheExtractedValue',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = '共 123 字';

        final String? value = await _first(
          _engine(null, bridge).extractFirst(
            'class.count@text@js:result.trim()',
            _pageWithContext(_countHtml),
            rulePath: 'searchRule.wordCount',
          ),
        );

        expect(value, '共 123 字');
        // 上游 `getString` 读单值时 result 是**字符串**：`result.replace(...)` 才能成立。
        expect(bridge.jobs.single.result, '共 123 字');
      },
    );

    test('extractAll_givenJsAfterSelectors_passesTheWholeList', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = <Object?>['One Author A', 'Two Author B', 'Three Author C'];

      final List<String> values = await _values(
        _engine(null, bridge).extractAll(
          'class.result-list@tag.li@text@js:result',
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      // 上游 `getStringList` 读多值时 result 是**列表**，返回列表也保持列表。
      // `tag.li` 的 text 含作者 span，所以列表就是这三个串——重点在 result 是**列表**。
      expect(values, <String>[
        'One Author A',
        'Two Author B',
        'Three Author C',
      ]);
      expect(bridge.jobs.single.result, <String>[
        'One Author A',
        'Two Author B',
        'Three Author C',
      ]);
    });

    test('extractFirst_givenJsReturnsAList_takesTheFirstValue', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = <Object?>['toc_2.html', 'toc_3.html'];

      expect(
        await _first(
          _engine(null, bridge).extractFirst(
            "@css:a.next @href@js:['toc_2.html', 'toc_3.html']",
            _pageWithContext(_listHtml),
            rulePath: 'tocRule.nextTocUrl',
          ),
        ),
        'toc_2.html',
      );
    });

    test('extractFirst_givenTheScriptReturnsNothing_returnsNull', () async {
      // 默认 result 为 null：`@js:` 什么都没返回就是「没有值」，与矩阵 #8 的空提取同口径。
      expect(
        await _first(
          _engine(null, FakeJsBridge()).extractFirst(
            '@js:undefined',
            _pageWithContext(_countHtml),
            rulePath: 'searchRule.name',
          ),
        ),
        isNull,
      );
    });

    test(
      'extractFirst_givenTheScriptTimesOut_propagatesTheMarkedFailure',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..failure = const ParseFailure<Never>(
            kind: ParseFailureKind.parseFailed,
            rulePath: 'searchRule.name:js:timeout',
          );

        final ParseFailure<Never> failure = await _failure(
          _engine(null, bridge).extractFirst(
            '@js:while (true) {}',
            _pageWithContext(_countHtml),
            rulePath: 'searchRule.name',
          ),
        );

        // §6：超时/异常由桥报 parseFailed，rulePath 带 js:timeout 标记（可定位到字段）。
        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'searchRule.name:js:timeout');
      },
    );

    test('extractAll_givenJsWithAmpersand_keepsItInsideTheScript', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'yes';

      await _values(
        _engine(null, bridge).extractAll(
          "@js:result && 'yes'",
          _pageWithContext(_countHtml),
          rulePath: 'searchRule.name',
        ),
      );

      // `@js:` 贪婪吞掉剩余部分（上游 JS_PATTERN），所以 `&&` 属于脚本而不是 `#11` 连接符。
      expect(bridge.jobs.single.script, "result && 'yes'");
    });

    test(
      'extractFirst_givenJsAndReplacement_appliesTheReplacementAfter',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'aXa';

        expect(
          await _first(
            _engine(null, bridge).extractFirst(
              '@js:result##a##b',
              _pageWithContext(_countHtml),
              rulePath: 'searchRule.name',
            ),
          ),
          'bXb',
        );
      },
    );

    test('extractFirst_givenAContextScope_fillsTheSandboxBindings', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'x';

      await _first(
        _engine(null, bridge).extractFirst(
          '@js:baseUrl',
          RuleScope.dom(
            _document(_countHtml),
            body: _countHtml,
            jsContext: const JsPageContext(
              baseUrl: 'https://example-novel.test/book/1/',
              page: 3,
              source: JsSourceInfo(
                name: '示例书源',
                url: 'https://example-novel.test',
                group: '分组',
              ),
            ),
          ),
          rulePath: 'searchRule.name',
        ),
      );

      expect(bridge.jobs.single.baseUrl, 'https://example-novel.test/book/1/');
      expect(bridge.jobs.single.page, 3);
      expect(bridge.jobs.single.source.name, '示例书源');
      expect(bridge.jobs.single.source.url, 'https://example-novel.test');
      expect(bridge.jobs.single.source.group, '分组');
    });

    test('selectAll_givenJsOnAListRule_reportsTheListBoundary', () async {
      final FakeJsBridge bridge = FakeJsBridge();

      final ParseFailure<Never> failure = await _failure(
        _engine(null, bridge).selectAll(
          'class.result-list@js:result',
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      // 3.4 只实现值规则上的 `@js:`；列表规则需要「JS 返回一列元素」的契约，显式拒绝。
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@js:list');
      expect(bridge.jobs, isEmpty);
    });

    test('applyReplaceRule_givenAJsRule_runsItOnTheText', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = '正文（净化）';

      expect(
        await _text(
          _engine(null, bridge).applyReplaceRule(
            '@js:result.replace("（", "（净化")',
            '正文（',
            rulePath: 'contentRule.replaceRegex',
          ),
        ),
        '正文（净化）',
      );
      expect(bridge.jobs.single.result, '正文（');
    });
    test(
      'extractFirst_givenABareJsRuleOnAJsonScope_passesTheJsonText',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ok';

        await _first(
          _engine(null, bridge).extractFirst(
            '@js:result',
            RuleScope.json(<String, Object?>{'a': 1}),
            rulePath: 'searchRule.name',
          ),
        );

        // JSON 条目上的裸 `@js:` 拿到的是**条目对象**（上游 `evalJS` 的 `result` 就是
        // NativeObject，book-source.md §6 / M12-A1）；页面才是 JSON 文本。
        expect(bridge.jobs.single.result, <String, Object?>{'a': 1});
        expect(bridge.jobs.single.baseUrl, isEmpty);
        expect(bridge.jobs.single.page, 1);
      },
    );

    test('applyReplaceRule_givenAJsRuleAndAContext_bindsThePage', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'x';

      await _text(
        _engine(null, bridge).applyReplaceRule(
          '@js:baseUrl',
          '正文',
          rulePath: 'contentRule.replaceRegex',
          jsContext: const JsPageContext(
            baseUrl: 'https://example-novel.test/book/1/9.html',
            source: JsSourceInfo(
              name: '示例书源',
              url: 'https://example-novel.test',
            ),
          ),
        ),
      );

      // 上下文必须真的传到沙箱：否则净化规则里的 baseUrl 会默默变成空串。
      expect(
        bridge.jobs.single.baseUrl,
        'https://example-novel.test/book/1/9.html',
      );
      expect(bridge.jobs.single.source.name, '示例书源');
    });

    test(
      'applyReplaceRule_givenTheScriptTimesOut_propagatesTheMarkedFailure',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..failure = const ParseFailure<Never>(
            kind: ParseFailureKind.parseFailed,
            rulePath: 'contentRule.replaceRegex:js:timeout',
          );

        final ParseFailure<Never> failure = await _failure(
          _engine(null, bridge).applyReplaceRule(
            '@js:while (true) {}',
            '正文',
            rulePath: 'contentRule.replaceRegex',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'contentRule.replaceRegex:js:timeout');
      },
    );

    test(
      'extractFirst_givenABareJsRuleOnAnElementScope_passesTheOuterHtml',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ok';
        final Element element = _document(_listHtml)
            .querySelectorAll('li')
            .first;

        await _first(
          _engine(null, bridge).extractFirst(
            '@js:result',
            _scope(element),
            rulePath: 'searchRule.name',
          ),
        );

        // 沙箱里没有 DOM 句柄（ADR-0029 §决策 5），所以逐项字段的 `@js:` 拿到的是该项的
        // outerHtml——否则它只能看到一个空串，整个字段就不可能用 JS 写。
        expect(bridge.jobs.single.result, startsWith('<li class="result">'));
        expect(bridge.jobs.single.result, contains('One'));
      },
    );

    test('extractAll_givenABareJsRule_passesThePageBodyAsAString', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = <Object?>['toc_2.html'];

      await _values(
        _engine(null, bridge).extractAll(
          '@js:result.match(/a/)',
          _pageWithContext(_countHtml),
          rulePath: 'tocRule.nextTocUrl',
        ),
      );

      // 上游 `getStringList` 在 JS 独立成规则时也把整页当作 result（而不是只有一个元素的
      // 列表）：`nextTocUrl` 的脚本要对页面文本做 `match` / `split`。
      expect(bridge.jobs.single.result, _countHtml);
    });

    test('extractFirst_givenAParseCall_evaluatesTheRuleOnThePage', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..parseRequests.add(
          const JsParseRequest(rule: 'class.count@text', wantsList: false),
        );

      expect(
        await _first(
          _engine(null, bridge).extractFirst(
            "@js:parse.getString('class.count@text', result)",
            _pageWithContext(_countHtml),
            rulePath: 'contentRule.content',
          ),
        ),
        '共 123 字',
      );
      expect(bridge.jobs.single.parseEvaluator, isNotNull);
    });

    test('extractAll_givenAParseElementsCall_answersTheMatches', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..parseRequests.add(
          const JsParseRequest(
            rule: 'class.result-list@tag.li',
            wantsList: true,
          ),
        );

      final List<String> values = await _values(
        _engine(null, bridge).extractAll(
          "@js:parse.getElements('class.result-list@tag.li', result)",
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.bookList',
        ),
      );

      // `parse.getElements` 把每个匹配交给沙箱：DOM 匹配是它的 outerHtml，JSON 匹配是值本身。
      expect(values, hasLength(3));
      expect(values.first, startsWith('<li class="result">'));
    });

    test(
      'extractFirst_givenAParseCallOnAnElementScope_failsWithTheScopeMarker',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..parseRequests.add(
            const JsParseRequest(rule: 'tag.a@href', wantsList: false),
          );
        final Element element = _document(_listHtml)
            .querySelectorAll('li')
            .first;

        final ParseFailure<Never> failure = await _failure(
          _engine(null, bridge).extractFirst(
            "@js:parse.getString('tag.a@href', result)",
            _scope(element),
            rulePath: 'tocRule.chapterUrl',
          ),
        );

        // ADR-0029 §决策 5：只承诺页级 scope，元素级命中必须显式失败并带 rulePath。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'tocRule.chapterUrl:js:parse-scope');
      },
    );

    test(
      'extractFirst_givenAParseCallWithAnotherDoc_failsWithTheScopeMarker',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..parseRequests.add(
            const JsParseRequest(
              rule: 'class.count@text',
              wantsList: false,
              doc: '<p>另一页</p>',
            ),
          );

        final ParseFailure<Never> failure = await _failure(
          _engine(null, bridge).extractFirst(
            "@js:parse.getString('class.count@text', result)",
            _pageWithContext(_countHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // `doc` 只认本 job 的页 body：脚本自己拼出来的片段没有 scope 可读。
        expect(failure.rulePath, 'contentRule.content:js:parse-scope');
      },
    );

    test(
      'extractFirst_givenANestedJsRuleInParse_failsWithTheRecursionMarker',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..parseRequests.add(
            const JsParseRequest(
              rule: 'class.count@text@js:result',
              wantsList: false,
            ),
          );

        final ParseFailure<Never> failure = await _failure(
          _engine(null, bridge).extractFirst(
            "@js:parse.getString('class.count@text@js:result', result)",
            _pageWithContext(_countHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // 单 worker 正在跑的就是这个 job（ADR-0030 §决策 1/3），所以嵌套的 evaluate 会排在自己
        // 的队后面；必须显式拒绝而不是静静死锁。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'contentRule.content:js:parse-recursion');
      },
    );

    test(
      'extractAll_givenANestedJsRuleInParse_failsWithTheListBoundary',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..parseRequests.add(
            const JsParseRequest(
              rule: 'class.count@js:result',
              wantsList: true,
            ),
          );

        final ParseFailure<Never> failure = await _failure(
          _engine(null, bridge).extractAll(
            "@js:parse.getElements('class.count@js:result', result)",
            _pageWithContext(_countHtml),
            rulePath: 'searchRule.bookList',
          ),
        );

        // 元素形状由列表规则的柜口拒绝：矩阵 #14 还没有「JS 返回一列元素」的契约，
        // 所以它的名字是 `unsupported:@js:list`（与顶层列表规则上的 `@js:` 同口径）。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@js:list');
      },
    );

    test('extractFirst_givenAParseRuleThatIsRejected_propagatesIt', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..parseRequests.add(
          const JsParseRequest(rule: '@xpath://div', wantsList: false),
        );

      final ParseFailure<Never> failure = await _failure(
        _engine(null, bridge).extractFirst(
          "@js:parse.getString('@xpath://div', result)",
          _pageWithContext(_countHtml),
          rulePath: 'contentRule.content',
        ),
      );

      // 嵌套规则的失败就是该 job 的失败（C-SRC-4），并且按 §7 的写法定位到语法。
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@xpath:');
    });

    test('extractFirst_givenASourceWithHeaders_passesThemIntoTheJob', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'ok';
      final RuleScope scope = RuleScope.dom(
        parser.parse(_countHtml),
        body: _countHtml,
        jsContext: const JsPageContext(
          baseUrl: 'https://example-novel.test/book/1/',
          headers: <String, String>{'Referer': 'https://book.test/'},
        ),
      );

      await _first(
        _engine(
          null,
          bridge,
        ).extractFirst('@js:result', scope, rulePath: 'searchRule.name'),
      );

      // 书源自带的 header 是规则里 `http.*` 的默认值（C-NET-4），但不得变成 JS 可见的绑定。
      expect(bridge.jobs.single.sourceHeaders, <String, String>{
        'Referer': 'https://book.test/',
      });
      expect(bridge.jobs.single.toJson().containsKey('sourceHeaders'), isFalse);
      expect(
        bridge.jobs.single.toJson().containsKey('parseEvaluator'),
        isFalse,
      );
    });

    test(
      'extractAll_givenAParseElementsRuleThatIsRejected_propagatesIt',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..parseRequests.add(
            const JsParseRequest(rule: '@xpath://div', wantsList: true),
          );

        final ParseFailure<Never> failure = await _failure(
          _engine(null, bridge).extractAll(
            "@js:parse.getElements('@xpath://div', result)",
            _pageWithContext(_countHtml),
            rulePath: 'searchRule.bookList',
          ),
        );

        // 两种形状（getString / getElements）的失败都要原样上抛，不得被吞成空值。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@xpath:');
      },
    );

    test(
      'extractFirst_givenAParseCallOnAJsonItem_failsWithTheScopeMarker',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..parseRequests.add(
            const JsParseRequest(rule: 'name', wantsList: false),
          );

        final ParseFailure<Never> failure = await _failure(
          _engine(null, bridge).extractFirst(
            "@js:parse.getString('name', result)",
            RuleScope.json(<String, Object?>{'name': 'One'}),
            rulePath: 'searchRule.name',
          ),
        );

        // JSON 条目也不是页 scope：拿不到规则要读的那一份文档，只能显式失败。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'searchRule.name:js:parse-scope');
      },
    );

    test(
      'extractAll_givenAParseElementsCallOnAJsonPage_answersTheValues',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()
          ..parseRequests.add(
            const JsParseRequest(rule: r'$.data.list[*]', wantsList: true),
          );

        final List<String> values = await _values(
          _engine(null, bridge).extractAll(
            r"@js:parse.getElements('$.data.list[*]', result)",
            _pageWithContext(_jsonBody),
            rulePath: 'searchRule.bookList',
          ),
        );

        // JSON 页上的 `parse.getElements` 把每个匹配的 JSON 值本身交给脚本（无 DOM 句柄）。
        expect(values, hasLength(2));
        expect(values.first, contains('One'));
      },
    );
  });

  group('RuleEngine matrix #15 (@@ default rule flag)', () {
    test(
      'extractFirst_givenTheDefaultRuleFlag_matchesLikeTheBareRule',
      () async {
        expect(
          await _first(
            _engine().extractFirst(
              '@@class.result.0@tag.a@text',
              _scope(_document(_listHtml)),
              rulePath: 'searchRule.name',
            ),
          ),
          'One',
        );
      },
    );

    test(
      'extractFirst_givenTheFlagAfterTheDash_stillCountsAsReverse',
      () async {
        // 矩阵 #7 的 `-` 先摘，矩阵 #15 的 `@@` 后摘，两者可以叠加。
        final List<String> values = await _values(
          _engine().extractAll(
            '-@@class.result@tag.a@href',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.bookUrl',
          ),
        );

        expect(values, <String>['/book/3', '/book/2', '/book/1']);
      },
    );

    test('extractAll_givenTheFlagInTheMiddleOfARule_isUnsupported', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          'class.result.0@@class.result.1@text',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      // 上游的 `@@` 只认规则体开头；中段那个 `@@` 不是任何已实现写法。
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@@');
    });
  });

  group('RuleEngine matrix #16 (@put: / @get:)', () {
    test('extractAll_givenAPutThenAGet_readsTheWrittenValue', () async {
      final JsVariableStore variables = JsVariableStore();

      final List<String> values = await _values(
        _engine(null, null, variables).extractAll(
          '@put:{a:class.result.0@tag.a@text}@get:{a}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      // `@get` 是替换：替换过的规则按上游的 Regex 模式读，整段替换结果就是它的值。
      expect(values, <String>['One']);
      expect(variables.read('', 'a'), 'One');
    });

    test('extractAll_givenAnUppercaseFlag_isTheSameRule', () async {
      // `book-source.md` §3 的前缀大小写不敏感：`@PUT:` / `@GET:` 与 `@put:` / `@get:`
      // 等价（上游的 `putPattern` / `getPattern` 都带 CASE_INSENSITIVE）。
      final JsVariableStore variables = JsVariableStore();

      final List<String> values = await _values(
        _engine(null, null, variables).extractAll(
          '@PUT:{a:class.result.0@tag.a@text}@GET:{a}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, <String>['One']);
      expect(variables.read('', 'a'), 'One');
    });

    test(
      'extractAll_givenAMixedCaseFlagInsideATemplate_isTheSameRule',
      () async {
        // 模板里的内层也是规则头，大小写不影响它的识别。
        final JsVariableStore variables = JsVariableStore();

        final List<String> values = await _values(
          _engine(null, null, variables).extractAll(
            '@Put:{a:class.result.1@tag.a@text}第{{@Get:{a}}}章',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        );

        expect(values, <String>['第Two章']);
      },
    );

    test('extractFirst_givenAQuotedPutValue_stripsTheQuotes', () async {
      final JsVariableStore variables = JsVariableStore();

      final String? value = await _first(
        _engine(null, null, variables).extractFirst(
          '@put:{a:"class.result.2@tag.a@text"}@get:{a}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(value, 'Three');
    });

    test(
      'extractFirst_givenAnUnquotedJsonPathPutValue_writesTheJsonValue',
      () async {
        final JsVariableStore variables = JsVariableStore();

        // 矩阵 #13 / #16：`@put` 的值本身是一条规则，JSONPath 按原写法不带引号。
        final String? value = await _first(
          _engine(null, null, variables).extractFirst(
            r'@put:{a:$.data.count}@get:{a}',
            _pageWithContext(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        );

        expect(value, '3');
      },
    );

    test('extractFirst_givenAnUnknownGet_rendersAnEmptyString', () async {
      final List<String> values = await _values(
        _engine().extractAll(
          '@get:{missing}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      // §4：未定义的变量渲染为空串，不保留 `{{…}}` / `@get:{…}` 原文。
      expect(values, isEmpty);
    });

    test('extractAll_givenAFlagOnlyPutRule_writesTheVariable', () async {
      final JsVariableStore variables = JsVariableStore();
      final RuleEngine engine = _engine(null, null, variables);

      final List<String> values = await _values(
        engine.extractAll(
          '@put:{a:class.result.1@tag.a@text}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );
      final String? read = await _first(
        engine.extractFirst(
          '@get:{a}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      // 只剩 `@put:` 的规则没有选择器可跑，上游读成空值；写入照常发生。
      expect(values, isEmpty);
      expect(read, 'Two');
    });

    test('extractFirst_givenARejectedPutValue_failsTheWholeRule', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractFirst(
          '@put:{a://div}class.result.0@tag.a@text',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      // 写入失败了就没有“后半个规则”可言：按 C-SRC-4 显式失败，不静默跳过。
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported://');
    });

    test('extractFirst_givenAMalformedPutBody_isIgnored', () async {
      // 上游对解析不了的 `@put` 体只记一条 debug 并继续（putMap 为空）。
      expect(
        await _first(
          _engine().extractFirst(
            '@put:{nocolon}class.result.0@tag.a@text',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        ),
        'One',
      );
    });
  });

  group('RuleEngine matrix #17 (java.put / java.get)', () {
    test('extractFirst_givenAJavaPutThenAGet_readsItThroughTheStore', () async {
      final JsVariableStore variables = JsVariableStore();
      // 假桥代表 worker 的回报：`java.put` 写下的变量随 job 结果回到桥，再落到同一份表里
      // （ADR-0034 §决策 1）。
      final FakeJsBridge bridge = FakeJsBridge()
        ..variables = variables
        ..javaPuts['token'] = 'abc';
      final RuleEngine engine = _engine(null, bridge, variables);

      await _values(
        engine.extractAll(
          "@js:java.put('token', 'abc')",
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );
      final String? value = await _first(
        engine.extractFirst(
          '@get:{token}',
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(value, 'abc');
    });

    test('extractAll_givenAJavaCall_handsTheSourceSnapshotToTheJob', () async {
      const String sourceUrl = 'https://example-novel.test';
      final JsVariableStore variables = JsVariableStore()
        ..write(sourceUrl, 'token', 'abc');
      final FakeJsBridge bridge = FakeJsBridge();

      await _values(
        _engine(null, bridge, variables).extractAll(
          "@js:java.get('token')",
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      // 变量按**书源**键控：同一个源的另一条规则看得到它，别的源看不到（C-SRC-9）。
      expect(bridge.jobs.single.variables, <String, String>{'token': 'abc'});
    });

    test(
      'extractAll_givenAZoneWithoutAVariable_carriesAnEmptySnapshot',
      () async {
        final FakeJsBridge bridge = FakeJsBridge();

        await _values(
          _engine(null, bridge).extractAll(
            '@js:1 + 1',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        );

        expect(bridge.jobs.single.variables, isEmpty);
      },
    );
  });

  group('RuleEngine matrix #18 ({{…}} templates)', () {
    test('extractAll_givenATemplate_runsItInTheSandbox', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'templated';

      final List<String> values = await _values(
        _engine(null, bridge).extractAll(
          '{{result}}',
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, <String>['templated']);
      // §6 的绑定与 `result` 形态：整页 scope 给 responseBody。
      expect(bridge.jobs.single.script, 'result');
      expect(bridge.jobs.single.result, _listHtml);
      expect(bridge.jobs.single.baseUrl, 'https://example-novel.test/book/1/');
    });

    test(
      'extractFirst_givenARuleHeadInsideATemplate_evaluatesItAsARule',
      () async {
        final JsVariableStore variables = JsVariableStore();

        // `{{…}}` 内直接写默认规则必须带 `@@`（矩阵 #15）：不带标志头时它是 JS。
        final String? value = await _first(
          _engine(null, null, variables).extractFirst(
            '{{@@class.result.0@tag.a@text}}',
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        );

        expect(value, 'One');
      },
    );

    test(
      'extractFirst_givenATemplateInsideALargerRule_returnsTheSubstitutedText',
      () async {
        // 上游把带替换的规则读成 Regex 模式（AnalyzeRule.kt:674-680）：替换后的整段
        // 文本就是这条规则的值，不会再当选择器解析。
        final String? value = await _first(
          _engine(null, null, JsVariableStore()).extractFirst(
            '@put:{a:class.result.0@tag.a@text}第{{@get:{a}}}章',
            _scope(_document(_listHtml)),
            rulePath: 'tocRule.chapterName',
          ),
        );

        expect(value, '第One章');
      },
    );

    test('extractAll_givenAnEmptyTemplateResult_yieldsNoValue', () async {
      // 假桥默认答 null：上游把 null 结果当空串插入，空串不产生值（矩阵 #8 同口径）。
      final List<String> values = await _values(
        _engine(null, FakeJsBridge()).extractAll(
          '{{result}}',
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, isEmpty);
    });

    test('extractAll_givenAFailingTemplate_returnsTheSandboxFailure', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'searchRule.name:js:error',
        );

      final ParseFailure<Never> failure = await _failure(
        _engine(null, bridge).extractAll(
          '{{result}}',
          _pageWithContext(_listHtml),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name:js:error');
    });

    test('extractAll_givenAnUnbalancedTemplate_yieldsNoValue', () async {
      // 括号不平衡时上游的 `{{[\w\W]*?}}` 逐不上（`innerRule` 不动它），所以它退回成
      // 提取段的一部分；此处没有名为 `text{{` 的属性，于是“成功但无值”（矩阵 #8 口径）。
      final List<String> values = await _values(
        _engine().extractAll(
          'class.result.0@tag.a@text{{',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(values, isEmpty);
    });

    test('extractAll_givenATemplateInsideAScript_isLeftToTheScript', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'ran';

      final List<String> values = await _values(
        _engine(null, bridge).extractAll(
          "@js:result.replace(/x/, '{{y}}')",
          _pageWithContext(_listHtml),
          rulePath: 'contentRule.content',
        ),
      );

      // `@js:` 贪婪吞掉剩余部分（矩阵 #14）：脚本里的 `{{…}}` 是脚本文本，不是模板。
      expect(values, <String>['ran']);
      expect(bridge.jobs.single.script, "result.replace(/x/, '{{y}}')");
    });

    test('extractAll_givenReplacementMarkersInsideATemplate_keepsThemInTheTemplate', () async {
      // b5：`{{$.a##x##y}}` 是**一条**内嵌规则，里面的 `##` 属于矩阵 #9。外层规则不能在
      // 那里切开：切开会把模板截成 `{{$.a`，模板被判不平衡 → 该字段 `parseFailed`（腾讯
      // 搜索系真源的 `{{$.tag_views##\s+##,}}` 就是这种形状）。
      expect(
        await _values(
          _engine().extractAll(
            r'{{$.a##x##y}}',
            RuleScope.json(const <String, Object?>{'a': '1x2x'}),
            rulePath: 'tocRule.updateTime',
          ),
        ),
        <String>['1y2y'],
      );
    });

    test(
      'extractAll_givenATemplateWithItsOwnReplacement_takesTheOuterMarker',
      () async {
        // 边界：模板内、外各有一个 `##`，分界必须落在**外层**那个上。
        expect(
          await _values(
            _engine().extractAll(
              r'{{$.a##x##y}}##/##-',
              RuleScope.json(const <String, Object?>{'a': '1/2'}),
              rulePath: 'tocRule.updateTime',
            ),
          ),
          <String>['1-2'],
        );
      },
    );

    test(
      'extractAll_givenATemplateOfPlainScript_handsTheMarkersToTheSandbox',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ran';

        final List<String> values = await _values(
          _engine(null, bridge).extractAll(
            '{{a##b##c}}',
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // 模板内不是规则头，所以整段是 JS：`##` 原样交给沙箱（旧写法会先在这里切开，模板
        // 被判不平衡，根本到不了沙箱）。
        expect(values, <String>['ran']);
        expect(bridge.jobs.single.script, 'a##b##c');
      },
    );

    test(
      'extractAll_givenAnUnclosedTemplateWithAMarker_leavesItToTheParser',
      () async {
        // 边界：未闭合的 `{{…` 不做替换分界（与本仓一直以来的“留给解析器报错”一致）。
        final ParseFailure<Never> failure = await _failure(
          _engine().extractAll(
            r'{{$.a##x',
            RuleScope.json(const <String, Object?>{'a': '1'}),
            rulePath: 'tocRule.updateTime',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
      },
    );
  });

  group('RuleEngine matrix #19 ({} legacy JSONPath)', () {
    test('extractAll_givenTheLegacyRule_readsThePath', () async {
      expect(
        await _values(
          _engine().extractAll(
            r'{$.data.name}',
            _pageWithContext(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['One'],
      );
    });

    test(
      'extractFirst_givenATemplateInsideLiteralText_returnsTheText',
      () async {
        // 上游在内嵌替换成功时返回整段拼接结果（AnalyzeByJSonPath.kt:79-90）。
        expect(
          await _first(
            _engine().extractFirst(
              r'第{$.data.count}章',
              _pageWithContext(_jsonBody),
              rulePath: 'tocRule.chapterName',
            ),
          ),
          '第3章',
        );
      },
    );

    test('extractAll_givenALegacyRuleOnAListRule_readsTheElements', () async {
      final List<RuleScope> matches = await _matches(
        _engine().selectAll(
          r'{$.data.list[*]}',
          _pageWithContext(_jsonBody),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(matches, hasLength(2));
      expect(matches.first, isA<JsonScope>());
    });

    test('extractAll_givenAnUnbalancedLegacyRule_reportsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          r'{$.data.name',
          _pageWithContext(_jsonBody),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenAnInvalidLegacyPath_reportsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          r'{$[}',
          _pageWithContext(_jsonBody),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test('extractAll_givenTheLegacyTemplateForm_normalizesThePath', () async {
      // 边界：b5 的归一化在 `{$…}` 模板里也生效（同一个 `_asJsonPathPiece` 入口）。
      expect(
        await _values(
          _engine().extractAll(
            r'{$[0]b}',
            _page('[{"b":"v"}]'),
            rulePath: 'searchRule.name',
          ),
        ),
        <String>['v'],
      );
    });
  });

  group('RuleEngine renderUrl (matrix #18 in URLs)', () {
    const JsPageContext context = JsPageContext(
      baseUrl: 'https://example-novel.test',
      page: 1,
      source: JsSourceInfo(name: '示例书源', url: 'https://example-novel.test'),
    );

    test('renderUrl_givenM0Variables_encodesTheKeywordOnce', () async {
      final String url = await _text(
        _engine().renderUrl(
          'https://example-novel.test/search?q={{key}}&page={{page}}',
          rulePath: 'searchUrl',
          params: <String, String>{'key': '中文 书', 'page': '2'},
          context: context,
        ),
      );

      expect(
        url,
        'https://example-novel.test/search?q=%E4%B8%AD%E6%96%87+%E4%B9%A6&page=2',
      );
    });

    test('renderUrl_givenAnUnknownTemplate_runsItWithTheKeyBinding', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'ENCODED';

      final String url = await _text(
        _engine(null, bridge).renderUrl(
          'https://example-novel.test/search?q={{key.toUpperCase()}}',
          rulePath: 'searchUrl',
          params: <String, String>{'key': 'abc', 'page': '1'},
          context: context,
        ),
      );

      expect(url, 'https://example-novel.test/search?q=ENCODED');
      // 上游只在 URL 里绑 `key`（AnalyzeUrl.kt:377），所以模板拿不到的关键词从绑定走。
      expect(bridge.jobs.single.key, 'abc');
      expect(bridge.jobs.single.script, 'key.toUpperCase()');
    });

    test('renderUrl_givenAnIntegralNumber_writesItWithoutDecimals', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 2.0;

      expect(
        await _text(
          _engine(null, bridge).renderUrl(
            'https://example-novel.test/page/{{page + 1}}',
            rulePath: 'searchUrl',
            params: <String, String>{'page': '1'},
            context: context,
          ),
        ),
        'https://example-novel.test/page/2',
      );
    });

    test('renderUrl_givenARuleHead_reportsUnsupportedRule', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().renderUrl(
          'https://example-novel.test/{{@@class.a@text}}',
          rulePath: 'searchUrl',
          params: const <String, String>{},
          context: context,
        ),
      );

      // §4：搜索 / 发现 URL 里的 `{{…}}` 只允许 JS，规则头按名拒绝（C-SRC-4）。
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@@');
    });

    test('renderUrl_givenAnXpathHead_reportsUnsupportedRule', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().renderUrl(
          'https://example-novel.test/{{//div}}',
          rulePath: 'searchUrl',
          params: const <String, String>{},
          context: context,
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported://');
    });

    test('renderUrl_givenACssHead_reportsUnsupportedRule', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().renderUrl(
          'https://example-novel.test/{{@css:.a}}',
          rulePath: 'searchUrl',
          params: const <String, String>{},
          context: context,
        ),
      );

      // 带标志的规则头（`@css:` 等）在 URL 里同样不允许：只能写 JS。
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@css:');
    });

    test('renderUrl_givenTheM0BaseUrl_rendersItWithoutTheSandbox', () async {
      final FakeJsBridge bridge = FakeJsBridge();

      // §4：`page` / `baseUrl` 是 M0 变量，走同步渲染器；只有名字不在参数表里时才需要
      // 沙箱，所以这里一个 job 都不应该产生。
      final String url = await _text(
        _engine(null, bridge).renderUrl(
          '{{baseUrl}}/page/{{page}}',
          rulePath: 'searchUrl',
          params: <String, String>{
            'baseUrl': 'https://example-novel.test',
            'page': '2',
          },
          context: context,
        ),
      );

      expect(url, 'https://example-novel.test/page/2');
      expect(bridge.jobs, isEmpty);
    });

    test('renderUrl_givenAnUnbalancedTemplate_reportsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().renderUrl(
          'https://example-novel.test/{{page',
          rulePath: 'searchUrl',
          params: <String, String>{'page': '2'},
          context: context,
        ),
      );

      // §4：未渲染的 `{{…}}` 不得交给请求层，所以在 URL 里它是显式失败。
      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchUrl');
    });

    test('renderUrl_givenAFailingScript_returnsTheSandboxFailure', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'searchUrl:js:error',
        );

      final ParseFailure<Never> failure = await _failure(
        _engine(null, bridge).renderUrl(
          'https://example-novel.test/{{nope()}}',
          rulePath: 'searchUrl',
          params: const <String, String>{},
          context: context,
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchUrl:js:error');
    });
  });

  group('RuleEngine expansion guards', () {
    test('selectAll_givenAFailingExpansion_returnsTheFailure', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().selectAll(
          '@put:{a://div}class.result',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.bookList',
        ),
      );

      // 列表规则同样先过展开（矩阵 #16）：展开失败就是整条规则失败（C-SRC-4）。
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported://');
    });

    test(
      'extractAll_givenDeeplyNestedTemplates_stopsAtTheDepthBound',
      () async {
        // 每层 `{{@@…}}` 都会再递归一次求值；深处那一层超过最大展开深度，必须以可定位的
        // `parseFailed` 收场，而不是把解析卡死（C-SRC-4）。
        final String rule = '${'{{@@' * 10}{{x}}${'}}' * 10}';

        final ParseFailure<Never> failure = await _failure(
          _engine().extractAll(
            rule,
            _scope(_document(_listHtml)),
            rulePath: 'searchRule.name',
          ),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'searchRule.name');
      },
    );

    test(
      'extractAll_givenAFailingPrefixBeforeAScript_returnsTheFailure',
      () async {
        final ParseFailure<Never> failure = await _failure(
          _engine().extractAll(
            '@put:{a://div}@js:result',
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // `@js:` 之前的展开失败与脚本无关，仍然是这条规则的失败。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported://');
      },
    );

    test(
      'extractAll_givenAReplacementPartThatNeedsExpansion_expandsIt',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'page';

        final List<String> values = await _values(
          _engine(null, bridge).extractAll(
            '@js:result##{{x}}##y',
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // 脚本区不展开，但 `##` 之后的替换段要展开（上游在 `##` 切分前做替换）。
        expect(values, <String>['y']);
      },
    );

    test('extractAll_givenAFailingReplacementPart_returnsTheFailure', () async {
      final FakeJsBridge bridge = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'contentRule.content:js:error',
        );

      final ParseFailure<Never> failure = await _failure(
        _engine(null, bridge).extractAll(
          '@js:result##{{x}}##y',
          _pageWithContext(_listHtml),
          rulePath: 'contentRule.content',
        ),
      );

      // 替换段里的模板也要展开（矩阵 #18）：它报错时整条规则失败。
      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'contentRule.content:js:error');
    });

    test('extractAll_givenAnUnclosedGetFlag_reportsParseFailed', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          '@get:{unclosed',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'searchRule.name');
    });

    test(
      'extractAll_givenAQuotedTemplateBody_keepsTheBracesInsideIt',
      () async {
        final FakeJsBridge bridge = FakeJsBridge();

        await _values(
          _engine(null, bridge).extractAll(
            '{{"}}"+result}}',
            _pageWithContext(_listHtml),
            rulePath: 'searchRule.name',
          ),
        );

        // 引号里的 `}}` 不结束模板（上游 `chompCodeBalanced` 同口径）。
        expect(bridge.jobs.single.script, '"}}"+result');
      },
    );

    test('extractAll_givenAQuotedPutValue_spansCommasAndBrackets', () async {
      final JsVariableStore variables = JsVariableStore();

      await _values(
        _engine(null, null, variables).extractAll(
          r'@put:{a:"x,y",b:"$.data.list[0].name"}@get:{b}',
          _pageWithContext(_jsonBody),
          rulePath: 'searchRule.name',
        ),
      );

      // 值里的逗号与方括号都不切分 `@put` 体：`a` 是整串 `x,y`（无匹配→空值）。
      expect(variables.read('https://example-novel.test', 'a'), '');
      expect(variables.read('https://example-novel.test', 'b'), 'One');
    });

    test('extractAll_givenAQuotedPutKey_keepsTheColonInsideIt', () async {
      final JsVariableStore variables = JsVariableStore();

      final String? value = await _first(
        _engine(null, null, variables).extractFirst(
          r'@put:{"a:b":"class.result.0@tag.a@text"}@get:{a:b}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      // `_topLevelColon` 只认引号外的第一个 `:`，所以带 `:` 的键要加引号。
      expect(value, 'One');
    });

    test('extractAll_givenABracketedPutKey_keepsTheColonInsideIt', () async {
      final JsVariableStore variables = JsVariableStore();

      final String? value = await _first(
        _engine(null, null, variables).extractFirst(
          r'@put:{[a:b]:"class.result.0@tag.a@text"}@get:{[a:b]}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      // 方括号里的 `:` 同样不是键值分隔符（位置语法的键也能用）。
      expect(value, 'One');
    });

    test(
      'extractAll_givenAnUnquotedPutPathWithBrackets_keepsItWhole',
      () async {
        final JsVariableStore variables = JsVariableStore();

        final String? value = await _first(
          _engine(null, null, variables).extractFirst(
            r'@put:{a:$.data.list[0].name}@get:{a}',
            _pageWithContext(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        );

        // 矩阵 #16 的「`@put` 内 JSONPath 不加引号」：键与值都带位置语法时要整段读走。
        expect(value, 'One');
      },
    );

    test('extractAll_givenAnEscapedQuoteInAPutValue_unescapesIt', () async {
      final String? value = await _first(
        _engine(null, null, JsVariableStore()).extractFirst(
          '@put:{a:"class.result.0@tag.a@text##One##Tw\\"o"}@get:{a}',
          _scope(_document(_listHtml)),
          rulePath: 'searchRule.name',
        ),
      );

      // 上游用 JSON 解析做这件事（`GSONStrict`）；本仓只做 `\x` → `x` 的去转义。
      expect(value, 'Tw"o');
    });

    test(
      'extractAll_givenALegacyTemplateWithAQuotedBrace_keepsItInside',
      () async {
        final List<String> values = await _values(
          _engine().extractAll(
            r"{$['a}b']}",
            _pageWithContext(_jsonBody),
            rulePath: 'searchRule.name',
          ),
        );

        // 引号里的 `}` 不结束矩阵 #19 的模板；路径解不出来（无该属性）就是无值。
        expect(values, isEmpty);
      },
    );
  });
  group('RuleEngine java.* rule evaluation (M1-b1b)', () {
    test(
      'extractAll_givenALiteralJavaGetString_inlinesItBeforeTheSandbox',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ran';

        final List<String> values = await _values(
          _engine(null, bridge).extractAll(
            "@js:java.getString('class.result.0@tag.a@text') + '|' + page",
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // ADR-0037 §决策 3①：字面量首参在构造 job 之前就被求值并内联。假桥不会真的执行 JS，
        // 所以可观察的是**交给沙箱的脚本**——那个调用已经被它的值替掉了（`jsonEncode` 给
        // 双引号字面量），因此表达式拿到的是同步值，而不是 Promise。
        expect(bridge.jobs.single.script, '"One" + \'|\' + page');
        expect(values, <String>['ran']);
      },
    );

    test('extractAll_givenTheMainstreamTemplateSpelling_inlinesTheGetStringInsideIt', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = '2023/11/15 06:13';

      // 验收项点名的写法：`{{java.timeFormat(java.getString('…')*1000)}}`。语料里
      // 377/379 个字面量嵌套调用就是这样写的（**`{{…}}` 模板**，不是 `@js:` 段）——
      // 两条路径共用同一个内联实现点，所以这一条必须与 `@js:` 版的一起过。
      final List<String> values = await _values(
        _engine(null, bridge).extractAll(
          r"{{java.timeFormat(java.getString('$.change_time')*1000)}}",
          RuleScope.json(<String, Object?>{'change_time': 1700000000}),
          rulePath: 'tocRule.updateTime',
        ),
      );

      // `java.getString` 已被内联成它的值的字面量（上游返回 String，所以是带引号的
      // `"1700000000"`，表达式里的 `*1000` 靠 JS 的数值强转），`java.timeFormat` 保持
      // worker 内的同步调用（§6）。
      expect(bridge.jobs.single.script, 'java.timeFormat("1700000000"*1000)');
      expect(values, <String>['2023/11/15 06:13']);
    });

    test('extractAll_givenALiteralJavaGetStringList_inlinesAnArray', () async {
      final FakeJsBridge bridge = FakeJsBridge()..result = 'ok';

      final List<String> values = await _values(
        _engine(null, bridge).extractAll(
          "@js:java.getStringList('class.result@tag.a@href').length",
          _pageWithContext(_listHtml),
          rulePath: 'contentRule.content',
        ),
      );

      // `getStringList` 内联成 JSON 数组字面量（3 个 `<a>` 的 outerHtml），上游的
      // `.toArray()` 垫片在沙箱里：这里钉的是「调用已被数组字面量替掉」。
      expect(bridge.jobs.single.script, startsWith('['));
      expect(bridge.jobs.single.script, contains('.length'));
      expect(bridge.jobs.single.script, isNot(contains('java.getStringList')));
      expect(values, <String>['ok']);
    });

    test(
      'extractAll_givenANonLiteralJavaGetString_leavesItForTheSandbox',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'async-value';

        final List<String> values = await _values(
          _engine(null, bridge).extractAll(
            r'@js:java.getString(variable)',
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // 非字面量首参留给沙箱：绑定回 Promise（本仓用假桥，所以直接答结果）。
        expect(values, <String>['async-value']);
        expect(bridge.jobs.single.script, 'java.getString(variable)');
      },
    );

    test(
      'extractAll_givenALiteralWhoseRuleNeedsTheSandbox_skipsTheFastPath',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'async-value';

        await _values(
          _engine(null, bridge).extractAll(
            "@js:java.getString('@js:1+1')",
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // 内层规则自己要沙箱（含 `@js:`）：快路径不接手（否则会在本 job 之前再跑一个 job），
        // 交给沙箱走 `js:parse-recursion` 那条既有边界。
        expect(
          bridge.jobs.single.script,
          contains("java.getString('@js:1+1')"),
        );
      },
    );

    test('extractAll_givenALiteralWhoseRuleFails_failsTheWholeRule', () async {
      final ParseFailure<Never> failure = await _failure(
        _engine().extractAll(
          r"@js:java.getString('@xpath://div')",
          _pageWithContext(_listHtml),
          rulePath: 'contentRule.content',
        ),
      );

      // 半个脚本拿着空值比失败更糟：内联失败即整条规则失败（ADR-0037 §决策 3）。
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@xpath:');
    });

    test(
      'extractAll_givenALiteralListRuleThatFails_failsTheWholeRule',
      () async {
        final ParseFailure<Never> failure = await _failure(
          _engine().extractAll(
            r"@js:java.getStringList('@xpath://div').length",
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // 列表形态的内联失败同样整条规则失败（ADR-0037 §决策 3）。
        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@xpath:');
      },
    );

    test(
      'extractAll_givenALiteralJavaGetStringWithNoMatch_inlinesAnEmptyString',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ran';

        await _values(
          _engine(null, bridge).extractAll(
            r"@js:java.getString('class.missing@text') + '|'",
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // 无匹配时快路径内联空串——异步路径（`parse.getString`）就是这个形状，两条必须一致
        // （ADR-0037 §决策 3；复核发现原本内联 `null`）。
        expect(bridge.jobs.single.script, startsWith('"" +'));
      },
    );

    test(
      'extractAll_givenALiteralJavaGetElement_inlinesTheFirstMatchOnly',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ran';

        await _values(
          _engine(null, bridge).extractAll(
            "@js:java.getElement('class.result@tag.a')",
            _pageWithContext(_listHtml),
            rulePath: 'contentRule.content',
          ),
        );

        // `getElement` 是**单值**形态：内联的是第一个匹配的 `outerHtml`（一个 JSON 字符串），
        // 不是数组——异步路径同样只取第一个。
        final String script = bridge.jobs.single.script;
        expect(script, startsWith('"'));
        expect(script, isNot(startsWith('[')));
        expect(script, contains('href=\\"/book/1\\"'));
      },
    );

    test(
      'extractAll_givenALiteralJavaGetStringListOnJsonScope_keepsTheValueTypes',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ran';

        await _values(
          _engine(null, bridge).extractAll(
            r"@js:java.getStringList('$.data.page[*].image')",
            RuleScope.json(<String, Object?>{
              'data': {
                'page': <Object?>[
                  <String, Object?>{'image': 'a.jpg'},
                  <String, Object?>{'image': 7},
                  <String, Object?>{'image': true},
                ],
              },
            }),
            rulePath: 'contentRule.content',
          ),
        );

        // 快路径内联的是 **JSON 值本身**，不是 `toString()` 后的字符串：异步路径
        // （`parse.getElements` → `_jsDocOf`，§6「JSON 匹配给值本身」）给 `7` / `true`，
        // 内联若写成 `"7"` / `"true"` 就会让同一个调用在两条路径上得到不同类型
        // （ADR-0037 §决策 3）。所以这里断言字面量里**没有引号包着的数字/布尔**。
        expect(bridge.jobs.single.script, '["a.jpg",7,true]');
      },
    );

    test(
      'extractAll_givenALiteralJavaGetElementOnJsonScope_inlinesTheTypedValue',
      () async {
        final FakeJsBridge bridge = FakeJsBridge()..result = 'ran';

        await _values(
          _engine(null, bridge).extractAll(
            r"@js:java.getElement('$.data.page[*].image')",
            RuleScope.json(<String, Object?>{
              'data': {
                'page': <Object?>[
                  <String, Object?>{'image': 7},
                ],
              },
            }),
            rulePath: 'contentRule.content',
          ),
        );

        // 单值形态同样保类型：异步路径的 `getElement` 是 `list[0]`（原值），不是字符串。
        expect(bridge.jobs.single.script, '7');
      },
    );
  });
}
