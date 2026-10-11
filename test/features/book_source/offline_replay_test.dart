import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;

import '../../support/capturing_log_printer.dart';

/// Offline replay of one **real** default-rule book source (G2, `PLAN.md` §4).
///
/// Drives the four stages the vertical slice needs — search → book info → table of
/// contents → chapter body — through [RuleEngine] only. `PLAN.md` 2.4's UseCases
/// will drive the same corpus; this test is what makes the gate reachable before
/// they exist. No test touches the network (C-NET-8); provenance of both fixtures
/// is in `test/fixtures/**/README.md`.
const String _sourceFixture =
    'test/fixtures/book_sources/legado_default_rules_source.json';

/// Loads one page of the offline corpus.
Document _page(String name) =>
    parser.parse(File('test/fixtures/html/$name').readAsStringSync());

/// Returns the data of a successful element result, failing the test otherwise.
List<Element> _elements(ParseResult<List<Element>> result) => switch (result) {
  ParseSuccess<List<Element>>(:final List<Element> data) => data,
  ParseFailure<List<Element>>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns the single value of [result], failing when there is none.
String _single(ParseResult<String?> result) => switch (result) {
  ParseSuccess<String?>(:final String? data) =>
    data ?? fail('Expected a value.'),
  ParseFailure<String?>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns [rule], failing the test when the fixture does not declare it.
String _rule(String? rule, String field) =>
    rule ?? fail('$field is absent from the fixture.');

void main() {
  late BookSource source;
  late RuleEngine engine;

  setUpAll(() {
    source = BookSource.fromLegadoJson(
      jsonDecode(File(_sourceFixture).readAsStringSync())
          as Map<String, Object?>,
    );
    engine = RuleEngine(
      logger: AppLogger(
        level: LogLevel.warning,
        printer: CapturingLogPrinter(),
      ),
    );
  });

  group('default-rule offline replay', () {
    test('replay_givenSearchPage_selectsEveryResultItem', () {
      final List<Element> items = _elements(
        engine.selectAll(
          _rule(source.searchRule.bookList, 'bookList'),
          _page('search_result.html'),
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(items, hasLength(2));
    });

    test('replay_givenSearchPage_extractsTheFieldsOfEveryItem', () {
      final Document document = _page('search_result.html');
      final List<Element> items = _elements(
        engine.selectAll(
          _rule(source.searchRule.bookList, 'bookList'),
          document,
          rulePath: 'searchRule.bookList',
        ),
      );

      expect(
        items.map(
          (Element item) => _single(
            engine.extractFirst(
              _rule(source.searchRule.name, 'name'),
              item,
              rulePath: 'searchRule.name',
            ),
          ),
        ),
        <String>['书名一', '书名二'],
      );
      expect(
        items.map(
          (Element item) => _single(
            engine.extractFirst(
              _rule(source.searchRule.bookUrl, 'bookUrl'),
              item,
              rulePath: 'searchRule.bookUrl',
            ),
          ),
        ),
        <String>['/book/1/', '/book/2/'],
      );
      expect(
        items.map(
          (Element item) => _single(
            engine.extractFirst(
              _rule(source.searchRule.author, 'author'),
              item,
              rulePath: 'searchRule.author',
            ),
          ),
        ),
        <String>['作者甲', '作者乙'],
      );
      expect(
        items.map(
          (Element item) => _single(
            engine.extractFirst(
              _rule(source.searchRule.coverUrl, 'coverUrl'),
              item,
              rulePath: 'searchRule.coverUrl',
            ),
          ),
        ),
        <String>['/img/1.jpg', '/img/2.jpg'],
      );
      expect(
        items.map(
          (Element item) => _single(
            engine.extractFirst(
              _rule(source.searchRule.lastChapter, 'lastChapter'),
              item,
              rulePath: 'searchRule.lastChapter',
            ),
          ),
        ),
        <String>['第3章 结尾', '第9章 终章'],
      );
      // `##小说` 替换生效：`玄幻小说` → `玄幻`、`都市小说` → `都市`。
      expect(
        items.map(
          (Element item) => _single(
            engine.extractFirst(
              _rule(source.searchRule.kind, 'kind'),
              item,
              rulePath: 'searchRule.kind',
            ),
          ),
        ),
        <String>['玄幻', '都市'],
      );
    });

    test('replay_givenBookPage_extractsTheBookInfo', () {
      final Document document = _page('book_page.html');

      expect(
        _single(
          engine.extractFirst(
            _rule(source.bookInfoRule?.name, 'name'),
            document,
            rulePath: 'bookInfoRule.name',
          ),
        ),
        '书名一',
      );
      // 页面里是 `作&nbsp;&nbsp;者：`，上游 `text` 会归一化空白，因此断言单空格形式。
      expect(
        _single(
          engine.extractFirst(
            _rule(source.bookInfoRule?.author, 'author'),
            document,
            rulePath: 'bookInfoRule.author',
          ),
        ),
        '作 者：作者甲',
      );
      expect(
        _single(
          engine.extractFirst(
            _rule(source.bookInfoRule?.intro, 'intro'),
            document,
            rulePath: 'bookInfoRule.intro',
          ),
        ),
        '这是简介第一段。',
      );
      expect(
        _single(
          engine.extractFirst(
            _rule(source.bookInfoRule?.coverUrl, 'coverUrl'),
            document,
            rulePath: 'bookInfoRule.coverUrl',
          ),
        ),
        '/img/1.jpg',
      );
    });

    test('replay_givenBookPage_extractsTheChapterList', () {
      final Document document = _page('book_page.html');
      final List<Element> chapters = _elements(
        engine.selectAll(
          _rule(source.tocRule.chapterList, 'chapterList'),
          document,
          rulePath: 'tocRule.chapterList',
        ),
      );

      expect(chapters, hasLength(3));
      expect(
        chapters.map(
          (Element chapter) => _single(
            engine.extractFirst(
              _rule(source.tocRule.chapterName, 'chapterName'),
              chapter,
              rulePath: 'tocRule.chapterName',
            ),
          ),
        ),
        <String>['第1章 开端', '第2章 继续', '第3章 结尾'],
      );
      expect(
        chapters.map(
          (Element chapter) => _single(
            engine.extractFirst(
              _rule(source.tocRule.chapterUrl, 'chapterUrl'),
              chapter,
              rulePath: 'tocRule.chapterUrl',
            ),
          ),
        ),
        <String>['/book/1/1.html', '/book/1/2.html', '/book/1/3.html'],
      );
    });

    test('replay_givenChapterPage_extractsTheContent', () {
      expect(
        _single(
          engine.extractFirst(
            _rule(source.contentRule.content, 'content'),
            _page('chapter_page.html'),
            rulePath: 'contentRule.content',
          ),
        ),
        '正文第一段。\n正文第二段。\n正文第三段。',
      );
    });

    test('replay_givenEveryRuleOfTheSource_isAcceptedByTheEngine', () {
      // G2 的前提：这份真实书源的**每条**规则都不得被 C-SRC-4 的拒绝面命中。
      final Map<String, String> listRules = <String, String>{
        'searchRule.bookList': _rule(source.searchRule.bookList, 'bookList'),
        'tocRule.chapterList': _rule(source.tocRule.chapterList, 'chapterList'),
      };
      final Map<String, String> valueRules = <String, String>{
        'searchRule.name': _rule(source.searchRule.name, 'name'),
        'searchRule.author': _rule(source.searchRule.author, 'author'),
        'searchRule.kind': _rule(source.searchRule.kind, 'kind'),
        'searchRule.lastChapter': _rule(
          source.searchRule.lastChapter,
          'lastChapter',
        ),
        'searchRule.coverUrl': _rule(source.searchRule.coverUrl, 'coverUrl'),
        'searchRule.bookUrl': _rule(source.searchRule.bookUrl, 'bookUrl'),
        'bookInfoRule.name': _rule(source.bookInfoRule?.name, 'name'),
        'bookInfoRule.author': _rule(source.bookInfoRule?.author, 'author'),
        'bookInfoRule.intro': _rule(source.bookInfoRule?.intro, 'intro'),
        'bookInfoRule.coverUrl': _rule(
          source.bookInfoRule?.coverUrl,
          'coverUrl',
        ),
        'tocRule.chapterName': _rule(source.tocRule.chapterName, 'chapterName'),
        'tocRule.chapterUrl': _rule(source.tocRule.chapterUrl, 'chapterUrl'),
        'contentRule.content': _rule(source.contentRule.content, 'content'),
      };
      final Document document = _page('search_result.html');

      for (final MapEntry<String, String> entry in listRules.entries) {
        expect(
          engine.selectAll(entry.value, document, rulePath: entry.key),
          isA<ParseSuccess<List<Element>>>(),
          reason: entry.key,
        );
      }
      for (final MapEntry<String, String> entry in valueRules.entries) {
        expect(
          engine.extractAll(entry.value, document, rulePath: entry.key),
          isA<ParseSuccess<List<String>>>(),
          reason: entry.key,
        );
      }
    });
  });
}
