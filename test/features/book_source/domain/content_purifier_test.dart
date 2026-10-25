import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/content_purifier.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logger/logger.dart' show Level;

import '../../../support/fake_log_printer.dart';

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

      expect(await purifier.purge('正文'), '正文');
    });

    test('purge_givenEmptyText_returnsItWithoutApplyingAnything', () async {
      // 空正文没什么可替换的；也不该为它去读一次规则表。
      expect(await _literal('a', 'b').purge(''), '');
    });

    test('purge_givenALiteralRule_replacesEveryOccurrence', () async {
      expect(await _literal('广告', ' ').purge('开头广告中间广告结尾'), '开头 中间 结尾');
    });

    test('purge_givenSeveralRules_appliesThemInOrder', () async {
      // 顺序有意义：第二条规则吃的是第一条的输出。
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'a', replacement: 'b', isRegex: false),
            PurgeRule(pattern: 'b', replacement: 'c', isRegex: false),
          ]),
        ).purge('a'),
        'c',
      );
    });

    test('purge_givenARegularExpression_keepsTheTextBetweenMatches', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: r'\d+', replacement: 'N', isRegex: true),
          ]),
        ).purge('第1章 共12段'),
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
        ).purge('第12章 开始'),
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
        ).purge('hey! ho!'),
        'hey? ho?',
      );
    });

    test('purge_givenAnEscapedDollar_writesALiteralDollar', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'x', replacement: r'\$1', isRegex: true),
          ]),
        ).purge('x'),
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
        ).purge('a'),
        '<>',
      );
    });

    test('purge_givenAnUnmatchedGroup_writesNothingForIt', () async {
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: '(a)|(b)', replacement: r'<$2>', isRegex: true),
          ]),
        ).purge('a'),
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
        ).purge('x'),
        r'$$',
      );
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'x', replacement: r'$a', isRegex: true),
          ]),
        ).purge('x'),
        r'$a',
      );
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'x', replacement: r'${open', isRegex: true),
          ]),
        ).purge('x'),
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
        ).purge('x'),
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
        ).purge('正文'),
        '正文',
      );
    });

    test('purge_givenAJsReplacement_skipsTheRuleAndWarns', () async {
      // 上游的 `@js:` 替换是「每个匹配跑一段脚本」；本仓没有这条通道，按字面替换会把脚本源码
      // 写进正文，所以显式跳过并记 warning（ADR-0026 §决策 2、ADR-0070 增补 §7）。
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
      ).purge('a');

      expect(result, 'a');
      expect(printer.events.single.message, contains('@js: replacements'));
    });

    test('purge_givenABrokenRegularExpression_keepsTheTextAndWarns', () async {
      final FakeLogPrinter printer = FakeLogPrinter();

      final String result = await ContentPurifier(
        rules: const _FixedRules(<PurgeRule>[
          PurgeRule(pattern: '(', replacement: '-', isRegex: true),
        ]),
        logger: AppLogger(printer: printer),
      ).purge('正文');

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
      ).purge('a');

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
        ).purge('a|b'),
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
        ).purge('正文'),
        '正文',
      );
      expect(
        await const ContentPurifier(
          rules: _FixedRules(<PurgeRule>[
            PurgeRule(pattern: 'a|', replacement: '-', isRegex: true),
          ]),
        ).purge('a'),
        'a',
      );
    });
  });
}
