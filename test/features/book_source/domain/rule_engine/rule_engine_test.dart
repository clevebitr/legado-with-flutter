import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:logger/logger.dart';

import '../../../../support/capturing_log_printer.dart';

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
  '@css:.a@text': 'unsupported:@css:',
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
  '-class.a@text': 'unsupported:-',
  'class.a@text##x##y###z': 'unsupported:###',
};

/// Selector segments that carry syntax a later phase of the matrix owns.
///
/// The tests wrap them into a list rule and into a value rule, because the last
/// segment of a value rule is the extraction and is therefore never a selector.
const Map<String, String> _unsupportedSelectors = <String, String>{
  'css:.b': 'unsupported:@css:',
  'tag.li!0': 'unsupported:!',
  'tag.li.-1:2': 'unsupported:!',
  'tag.li[-1]': 'unsupported:[]',
  'children': 'unsupported:children',
  'text.x': 'unsupported:text',
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
];

/// An engine with a capturing logger, so a test can assert the C-SRC-4 record.
RuleEngine _engine([CapturingLogPrinter? printer]) => RuleEngine(
  logger: AppLogger(
    level: LogLevel.debug,
    printer: printer ?? CapturingLogPrinter(),
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
      final CapturingLogPrinter printer = CapturingLogPrinter();

      _engine(printer).selectAll(
        '@css:.a@text',
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
        contains('unsupported:@css:'),
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

    test(
      'extractAll_givenFlagInTheExtractionPosition_returnsUnsupportedRule',
      () {
        // 值规则的末段是提取段，上游在那里允许嵌套规则，所以带标志的末段必须拒绝，
        // 而不能被当成属性名静默取空（C-SRC-4）。
        final ParseFailure<Never> failure = _failure(
          _engine().extractAll(
            'class.a@css:.b',
            _document(_listHtml),
            rulePath: 'searchRule.name',
          ),
        );

        expect(failure.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@css:');
      },
    );

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
          '@css:.a@text',
          _document(_listHtml),
          rulePath: 'searchRule.intro',
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@css:');
    });
  });
}
