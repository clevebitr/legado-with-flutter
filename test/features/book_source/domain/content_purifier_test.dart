import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/content_purifier.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logger/logger.dart' show Level;

import '../../../support/fake_js_bridge.dart';
import '../../../support/fake_log_printer.dart';

/// The page a purge runs against; most rules never read it, a `@js:` one may.
const JsPageContext _context = JsPageContext(
  baseUrl: 'https://source.test/book/1/1.html',
);

/// A [PurgeRuleSource] answering a fixed list.
final class _FixedRules implements PurgeRuleSource {
  const _FixedRules(this._rules);

  final List<PurgeRule> _rules;

  @override
  Future<List<PurgeRule>> purgeRules() async => _rules;
}

/// A purifier over one literal rule.
ContentPurifier _literal(String pattern, String replacement) => ContentPurifier(
  rules: _FixedRules(<PurgeRule>[
    PurgeRule(pattern: pattern, replacement: replacement, isRegex: false),
  ]),
);

void main() {
  group('ContentPurifier', () {
    test('purge_givenNoRules_returnsTheTextUnchanged', () async {
      const ContentPurifier purifier = ContentPurifier(
        rules: _FixedRules(<PurgeRule>[]),
      );

      expect(await purifier.purgeContent('正文', context: _context), '正文');
    });

    test('purge_givenEmptyText_returnsItWithoutApplyingAnything', () async {
      // 空正文没什么可替换的；也不该为它去读一次规则表。
      expect(await _literal('a', 'b').purgeContent('', context: _context), '');
    });

    test('purge_givenALiteralRule_replacesEveryOccurrence', () async {
      expect(
        await _literal('广告', ' ').purgeContent('开头广告中间广告结尾', context: _context),
        '开头 中间 结尾',
      );
    });

    test('purge_givenSeveralRules_appliesThemInOrder', () async {
      // 顺序有意义：第二条规则吃的是第一条的输出。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'a', replacement: 'b', isRegex: false),
            PurgeRule(pattern: 'b', replacement: 'c', isRegex: false),
          ]),
        ).purgeContent('a', context: _context),
        'c',
      );
    });

    test('purge_givenARegularExpression_keepsTheTextBetweenMatches', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: r'\d+', replacement: 'N', isRegex: true),
          ]),
        ).purgeContent('第1章 共12段', context: _context),
        '第N章 共N段',
      );
    });

    test('purge_givenAGroupReference_inlinesTheCapturedText', () async {
      // 上游走 Java 的 `appendReplacement`，`$1` 是分组引用；Dart 的字面量替换必须自己展开。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: r'第(\d+)章', replacement: r'[$1]', isRegex: true),
          ]),
        ).purgeContent('第12章 开始', context: _context),
        '[12] 开始',
      );
    });

    test('purge_givenANamedGroupReference_inlinesTheNamedText', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(
              pattern: r'(?<word>[a-z]+)!',
              replacement: r'${word}?',
              isRegex: true,
            ),
          ]),
        ).purgeContent('hey! ho!', context: _context),
        'hey? ho?',
      );
    });

    test('purge_givenAnEscapedDollar_writesALiteralDollar', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'x', replacement: r'\$1', isRegex: true),
          ]),
        ).purgeContent('x', context: _context),
        r'$1',
      );
    });

    test('purge_givenAnOutOfRangeGroup_writesNothingForIt', () async {
      // 越界组号上游会抛错；这里退化成空串，与「这个组没参与匹配」同一结果，正文不至于整章失败。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: '(a)', replacement: r'<$3>', isRegex: true),
          ]),
        ).purgeContent('a', context: _context),
        '<>',
      );
    });

    test('purge_givenAnUnmatchedGroup_writesNothingForIt', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: '(a)|(b)', replacement: r'<$2>', isRegex: true),
          ]),
        ).purgeContent('a', context: _context),
        '<>',
      );
    });

    test('purge_givenALoneDollar_keepsItLiterally', () async {
      // 三种孤立形态：重复的 `$`、后面是普通字母、`{` 没闭合。Java 会抛错，这里按字面保留更宽容。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'x', replacement: r'$$', isRegex: true),
          ]),
        ).purgeContent('x', context: _context),
        r'$$',
      );
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'x', replacement: r'$a', isRegex: true),
          ]),
        ).purgeContent('x', context: _context),
        r'$a',
      );
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'x', replacement: r'${open', isRegex: true),
          ]),
        ).purgeContent('x', context: _context),
        r'${open',
      );
    });

    test('purge_givenBackslashesThatEscapeNothing_keepsThem', () async {
      // 反斜杠只有在紧跟 `$` 时才是转义，其余原样写回（`\n` 不会变成换行）。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: '(x)', replacement: r'a\nb$1', isRegex: true),
          ]),
        ).purgeContent('x', context: _context),
        r'a\nbx',
      );
    });

    test('purge_givenAnEmptyPattern_keepsTheText', () async {
      // 空 pattern 在正则里命中「每个位置」，会把正文整段吃掉；上游同样直接跳过。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: '', replacement: '-', isRegex: true),
          ]),
        ).purgeContent('正文', context: _context),
        '正文',
      );
    });

    test('purgeContent_givenAJsRuleWithoutASandbox_skipsIt', () async {
      // 没有沙箱时不能按字面量替换——那会把脚本文本写进正文（ADR-0026 §决策 2）。
      final FakeLogPrinter printer = FakeLogPrinter();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(
            pattern: 'a',
            replacement: '@js:result.toUpperCase()',
            isRegex: true,
          ),
        ]),
        logger: AppLogger(printer: printer),
      ).purgeContent('a', context: _context);

      expect(result, 'a');
      expect(printer.events.single.message, contains('no sandbox'));
    });

    test('purgeContent_givenAJsRule_evaluatesItOnceForEveryMatch', () async {
      // 一条规则一章**一个** job：一章上千个匹配也只是一次跨 isolate 往返
      // （ADR-0071 §决策 5）。
      final FakeJsBridge js = FakeJsBridge()..result = <Object?>['X', 'Y'];
      final FakeLogPrinter printer = FakeLogPrinter();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(
            pattern: r'\d',
            replacement: '@js:rule(result)',
            isRegex: true,
          ),
        ]),
        logger: AppLogger(printer: printer),
        js: js,
      ).purgeContent('1 和 2', context: _context);

      expect(result, 'X 和 Y');
      expect(js.jobs, hasLength(1));
      // 匹配文本按顺序塞进脚本，`result` 仍是上游那一条绑定。
      expect(js.jobs.single.script, contains('var __matches = ["1","2"]'));
      expect(js.jobs.single.script, contains('eval("rule(result)")'));
      expect(js.jobs.single.bookName, isNull);
    });

    test('purgeContent_givenAJSFailure_keepsTheTextAndWarns', () async {
      final FakeJsBridge js = FakeJsBridge()
        ..failure = failureAt<Never>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'js.rule',
        );
      final FakeLogPrinter printer = FakeLogPrinter();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(pattern: 'a', replacement: '@js:x', isRegex: true),
        ]),
        logger: AppLogger(printer: printer),
        js: js,
      ).purgeContent('a', context: _context);

      expect(result, 'a');
      expect(printer.events, isNotEmpty);
    });

    test('purgeContent_givenAScriptAnsweringNoList_keepsTheText', () async {
      final FakeJsBridge js = FakeJsBridge()..result = 42;
      final FakeLogPrinter printer = FakeLogPrinter();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(pattern: 'a', replacement: '@js:x', isRegex: true),
        ]),
        logger: AppLogger(printer: printer),
        js: js,
      ).purgeContent('a', context: _context);

      expect(result, 'a');
      expect(printer.events.single.message, contains('no list'));
    });

    test(
      'purgeContent_givenAScriptAnsweringTheWrongCount_keepsTheText',
      () async {
        // 少一条、多一条都对不上位置：宁可整条规则不生效（ADR-0026 §决策 2）。
        final FakeJsBridge js = FakeJsBridge()..result = <Object?>['X'];
        final FakeLogPrinter printer = FakeLogPrinter();

        final String result = await ContentPurifier(
          rules: const _FixedRules(<PurgeRule>[
            PurgeRule(pattern: r'\d', replacement: '@js:x', isRegex: true),
          ]),
          logger: AppLogger(printer: printer),
          js: js,
        ).purgeContent('1 和 2', context: _context);

        expect(result, '1 和 2');
        expect(printer.events.single.message, contains('wrong count'));
      },
    );

    test('purgeContent_givenAJSBreakingRegex_keepsTheText', () async {
      final FakeJsBridge js = FakeJsBridge();
      final FakeLogPrinter printer = FakeLogPrinter();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(pattern: '(', replacement: '@js:x', isRegex: true),
        ]),
        logger: AppLogger(printer: printer),
        js: js,
      ).purgeContent('a', context: _context);

      expect(result, 'a');
      expect(js.jobs, isEmpty);
    });

    test('purgeContent_givenAJSWithNoMatch_neverStartsTheSandbox', () async {
      final FakeJsBridge js = FakeJsBridge();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(pattern: 'zzz', replacement: '@js:x', isRegex: true),
        ]),
        js: js,
      ).purgeContent('abc', context: _context);

      expect(result, 'abc');
      expect(js.jobs, isEmpty);
    });

    test('purgeTitles_givenAJSWithATimeout_skipsTheRule', () async {
      // `timeoutMs` 是上游那条逐规则上限：跑不完就跳过（ADR-0071 §决策 5）。
      // 假桥立即返回，所以用一个 0 毫秒（= 未设置）以外的极小值配合 `Future.delayed` 不可行；
      // 这里用「桥永远不答」的形态：借 `FakeJsBridge` 的顺序队列之外的一条自定义桥。
      final _SlowBridge js = _SlowBridge();

      final List<String> titles = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(
            pattern: 'a',
            replacement: '@js:x',
            isRegex: true,
            appliesToTitle: true,
            timeoutMs: 1,
          ),
        ]),
        js: js,
      ).purgeTitles(<String>['a'], context: _context);

      expect(titles, <String>['a']);
    });

    test('purgeContent_givenATitleOnlyRule_leavesTheBodyAlone', () async {
      // 只作用于标题的规则（上游 scopeTitle: true / scopeContent: false）不该改正文，
      // 否则「数字标题」这种规则会把正文章节号一起改花（ADR-0071 §决策 4）。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(
              pattern: '第',
              replacement: 'Chapter ',
              isRegex: false,
              appliesToContent: false,
              appliesToTitle: true,
            ),
          ]),
        ).purgeContent('第1章 开端', context: _context),
        '第1章 开端',
      );
    });

    test('purgeContent_givenBothScopes_appliesToTheBody', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(
              pattern: '第',
              replacement: 'Chapter ',
              isRegex: false,
              appliesToContent: true,
              appliesToTitle: true,
            ),
          ]),
        ).purgeContent('第1章', context: _context),
        'Chapter 1章',
      );
    });

    test('purgeTitles_givenATitleRule_rewritesEveryTitle', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(
              pattern: r'第(\d+)章',
              replacement: r'[$1]',
              isRegex: true,
              appliesToContent: false,
              appliesToTitle: true,
            ),
          ]),
        ).purgeTitles(<String>['第1章 开端', '第2章 继续'], context: _context),
        <String>['[1] 开端', '[2] 继续'],
      );
    });

    test('purgeTitles_givenAContentOnlyRule_answersThemUnchanged', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'a', replacement: 'b', isRegex: false),
          ]),
        ).purgeTitles(<String>['第1章'], context: _context),
        <String>['第1章'],
      );
    });

    test('purgeTitles_givenNoTitles_answersAnEmptyList', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(
              pattern: 'a',
              replacement: 'b',
              isRegex: false,
              appliesToTitle: true,
            ),
          ]),
        ).purgeTitles(const <String>[], context: _context),
        isEmpty,
      );
    });

    test('purgeTitles_givenSeveralRules_appliesThemInOrder', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(
              pattern: 'a',
              replacement: 'b',
              isRegex: false,
              appliesToContent: false,
              appliesToTitle: true,
            ),
            PurgeRule(
              pattern: 'b',
              replacement: 'c',
              isRegex: false,
              appliesToContent: false,
              appliesToTitle: true,
            ),
          ]),
        ).purgeTitles(<String>['a'], context: _context),
        <String>['c'],
      );
    });

    test('purge_givenABrokenRegularExpression_keepsTheTextAndWarns', () async {
      final FakeLogPrinter printer = FakeLogPrinter();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(pattern: '(', replacement: '-', isRegex: true),
        ]),
        logger: AppLogger(printer: printer),
      ).purgeContent('正文', context: _context);

      expect(result, '正文');
      expect(printer.events.single.level, Level.warning);
      expect(
        printer.events.single.message,
        contains('invalid regular expression'),
      );
    });

    test('purge_givenABarePipeAtTheEnd_keepsTheTextAndWarns', () async {
      final FakeLogPrinter printer = FakeLogPrinter();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(pattern: 'a|', replacement: '-', isRegex: true),
        ]),
        logger: AppLogger(printer: printer),
      ).purgeContent('a', context: _context);

      expect(result, 'a');
      expect(printer.events.single.message, contains('bare "|"'));
    });

    test('purge_givenAnEscapedPipeAtTheEnd_stillApplies', () async {
      // `a\|` 是「字面竖线」，不是空分支：上游的检查也只在未转义时拒绝。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: r'a\|', replacement: '-', isRegex: true),
          ]),
        ).purgeContent('a|b', context: _context),
        '-b',
      );
    });

    test('purge_givenDegradationsWithoutALogger_stillKeepsTheText', () async {
      // logger 是可选的：没有日志也照样降级，不因为「没地方记」就抛。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: '(', replacement: '-', isRegex: true),
          ]),
        ).purgeContent('正文', context: _context),
        '正文',
      );
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'a|', replacement: '-', isRegex: true),
          ]),
        ).purgeContent('a', context: _context),
        'a',
      );
    });
  });
}

/// A [JsBridge] that never answers, so a rule's `timeoutMs` is the only thing that ends the wait.
final class _SlowBridge implements JsBridge {
  @override
  Future<ParseResult<Object?>> evaluate(JsJob job) =>
      Completer<ParseResult<Object?>>().future;

  @override
  Future<void> dispose() async {}
}
