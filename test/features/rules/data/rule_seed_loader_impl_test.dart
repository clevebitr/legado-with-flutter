import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/rules/data/rule_seed_loader_impl.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_log_printer.dart';

/// An [AssetBundle] answering from a map, missing keys included.
final class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._files);

  final Map<String, String> _files;

  @override
  Future<ByteData> load(String key) async {
    final String? text = _files[key];
    if (text == null) {
      throw FlutterError('missing asset $key');
    }

    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

const String _tocAsset = 'assets/rules/txt_toc_rule.json';
const String _dictAsset = 'assets/rules/dict_rule.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetRuleSeedLoader', () {
    test('load_givenTheBundledAssets_answersTocAndDictDrafts', () async {
      final AssetRuleSeedLoader loader = AssetRuleSeedLoader(
        logger: AppLogger(printer: FakeLogPrinter()),
      );

      final ParseResult<List<RuleDraft>> loaded = await loader.load();
      final List<RuleDraft> drafts = switch (loaded) {
        ParseSuccess<List<RuleDraft>>(:final List<RuleDraft> data) => data,
        ParseFailure<List<RuleDraft>>() => fail('the bundled assets must load'),
      };

      // 上游 defaultData 里的两类数据：27 条目录规则、2 条字典规则（净化/高亮不随包）。
      expect(
        drafts.where((RuleDraft draft) => draft.kind == RuleKind.toc),
        hasLength(27),
      );
      expect(
        drafts.where((RuleDraft draft) => draft.kind == RuleKind.dict),
        hasLength(2),
      );
      expect(
        drafts.every((RuleDraft draft) => draft.isBuiltIn),
        isTrue,
        reason: '内置标记只表示来源（ADR-0070 §决策 4）',
      );

      final RuleDraft firstToc = drafts.first;
      final TocPayload toc = firstToc.payload as TocPayload;
      expect(firstToc.name, isNotEmpty);
      expect(toc.rule, isNotEmpty);
      // 上游的 txt 导入还要读 volumeRule / example：payload 没有这两个字段，留在 extra 里。
      expect(toc.extra, contains('volumeRule'));
      expect(toc.extra, contains('example'));

      final DictPayload dict = drafts.last.payload as DictPayload;
      expect(dict.urlRule, startsWith('https://'));
      expect(dict.showRule, isNotEmpty);
    });

    test('load_givenATextAssetThatIsNotJson_skipsItAndLoadsTheNext', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final AssetRuleSeedLoader loader = AssetRuleSeedLoader(
        logger: AppLogger(printer: printer),
        bundle: _FakeBundle(<String, String>{
          _tocAsset: 'not json',
          _dictAsset: '[{"name":"d","urlRule":"u","showRule":"s"}]',
        }),
      );

      final ParseResult<List<RuleDraft>> loaded = await loader.load();

      expect((loaded as ParseSuccess<List<RuleDraft>>).data.single.name, 'd');
      expect(printer.events, hasLength(1));
    });

    test('load_givenAnAssetThatIsNotAnArray_skipsIt', () async {
      final AssetRuleSeedLoader loader = AssetRuleSeedLoader(
        logger: AppLogger(printer: FakeLogPrinter()),
        bundle: _FakeBundle(<String, String>{
          _tocAsset: '{"name":"x"}',
          _dictAsset: '[]',
        }),
      );

      expect(
        (await loader.load() as ParseSuccess<List<RuleDraft>>).data,
        isEmpty,
      );
    });

    test('load_givenEntriesMissingFields_keepsTheGoodOnes', () async {
      final AssetRuleSeedLoader loader = AssetRuleSeedLoader(
        logger: AppLogger(printer: FakeLogPrinter()),
        bundle: _FakeBundle(<String, String>{
          // 三条目录规则：一条缺 chapterRule、一条用上游的备用键 `rule`、一条干脆不是对象。
          _tocAsset:
              '[{"name":"bad"},{"name":"alt","rule":"^第","enable":false},42]',
          _dictAsset: '[{"name":"d","urlRule":"u"}]',
        }),
      );

      final List<RuleDraft> drafts =
          (await loader.load() as ParseSuccess<List<RuleDraft>>).data;

      expect(drafts, hasLength(1));
      expect(drafts.single.name, 'alt');
      expect(drafts.single.isEnabled, isFalse);
      expect((drafts.single.payload as TocPayload).rule, '^第');
    });

    test('load_givenAnEntryWithoutAName_skipsIt', () async {
      final AssetRuleSeedLoader loader = AssetRuleSeedLoader(
        logger: AppLogger(printer: FakeLogPrinter()),
        bundle: _FakeBundle(<String, String>{
          _tocAsset: '[]',
          _dictAsset: '[{"urlRule":"u","showRule":"s"}]',
        }),
      );

      expect(
        (await loader.load() as ParseSuccess<List<RuleDraft>>).data,
        isEmpty,
      );
    });
  });
}
