import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';

/// Offline book source corpus; no test touches the network (C-NET-8,
/// `docs/dev/book-source.md` §10). Provenance and sanitising are recorded in
/// `test/fixtures/book_sources/README.md`.
const String _fixturePath =
    'test/fixtures/book_sources/legado_export_sanitized.json';

/// Loads the fixture as the import layer would receive it.
Map<String, Object?> _loadFixture() =>
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, Object?>;

/// The smallest JSON that satisfies the required fields
/// (`docs/dev/book-source.md` §2).
Map<String, Object?> _minimalJson() => <String, Object?>{
  'bookSourceName': '最小书源',
  'bookSourceUrl': 'https://example-novel.test',
  'ruleSearch': <String, Object?>{'bookList': 'class.result-list@tag.li'},
  'ruleToc': <String, Object?>{'chapterList': 'id.chapter-list@tag.li'},
  'ruleContent': <String, Object?>{'content': 'id.content@tag.p@text'},
};

/// Returns [_minimalJson] with [key] set to [value].
Map<String, Object?> _minimalJsonWith(String key, Object? value) =>
    <String, Object?>{..._minimalJson(), key: value};

/// Matches the failure `json_serializable`'s checked mode reports for [key].
///
/// With `checked: true` (ADR-0022) every value and type error is wrapped in a
/// [CheckedFromJsonException] whose `key` names the failing field — the source of
/// the `rulePath` C-SRC-8 requires — and whose `innerError` keeps the cause
/// (`TypeError` for a missing key or a wrong type, `FormatException` from the
/// header converter, `ArgumentError` from an unknown enum value).
Matcher _failsAt(String key, {Matcher? because}) => throwsA(
  isA<CheckedFromJsonException>()
      .having((CheckedFromJsonException error) => error.key, 'key', key)
      .having(
        (CheckedFromJsonException error) => error.innerError,
        'innerError',
        because ?? anything,
      ),
);

/// Returns the top-level keys of the nested object stored under [key].
Iterable<String> _nestedKeys(Map<String, Object?> json, String key) =>
    (json[key]! as Map<String, Object?>).keys;

void main() {
  group('BookSource', () {
    test(
      'fromLegadoJson_givenSanitizedRealExport_mapsTheOriginalKeysToCamelCase',
      () {
        final BookSource source = BookSource.fromLegadoJson(_loadFixture());

        expect(source.name, '示例书源（真实导出结构，已脱敏）');
        expect(source.url, 'https://example-novel.test');
        // 真实导出把空分组写成 ""，而不是省略键，所以这里既不是 null 也不是非空值。
        expect(source.group, isEmpty);
        expect(source.sourceType, BookSourceType.text);
        expect(source.isEnabled, isTrue);
        // header 在真实导出里是空字符串，表示「没有额外请求头」。
        expect(source.headers, isNull);
        expect(source.searchUrl, '/search/?searchkey={{key}}');
        expect(source.searchRule.bookList, '@css:div.item');
        expect(source.searchRule.bookUrl, '@css:dl > dt > a @href');
        expect(
          source.searchRule.wordCount,
          '@css:dl > div.btm > em:eq(1) @text',
        );
        expect(source.bookInfoRule?.tocUrl, '@css:a.chapterlist @href');
        expect(
          source.bookInfoRule?.wordCount,
          '@css:div#info > p:eq(3) @text ##字数：',
        );
        expect(source.tocRule.chapterList, '@css:div#list a[rel="chapter"]');
        // 目录用默认规则语法（矩阵 #8）：只写提取段。
        expect(source.tocRule.chapterName, 'text');
        expect(source.tocRule.chapterUrl, 'href');
        expect(source.contentRule.content, '@css:div#booktxt @html');
      },
    );

    test('fromJson_givenMinimalLegadoExport_appliesTheDocumentedDefaults', () {
      final BookSource source = BookSource.fromJson(_minimalJson());

      expect(source.sourceType, BookSourceType.text);
      expect(source.isEnabled, isTrue);
      expect(source.group, isNull);
      expect(source.headers, isNull);
      expect(source.searchUrl, isNull);
      expect(source.bookInfoRule, isNull);
      expect(source.extra, isEmpty);
    });

    test('fromJson_givenBookSourceGroup_mapsItToGroup', () {
      final BookSource source = BookSource.fromJson(
        _minimalJsonWith('bookSourceGroup', '测试'),
      );

      expect(source.group, '测试');
    });

    test(
      'fromJson_givenEachBookSourceTypeValue_mapsToTheMatchingEnumValue',
      () {
        const Map<int, BookSourceType> expected = <int, BookSourceType>{
          0: BookSourceType.text,
          1: BookSourceType.audio,
          2: BookSourceType.image,
          3: BookSourceType.file,
        };

        for (final MapEntry<int, BookSourceType> entry in expected.entries) {
          final BookSource source = BookSource.fromJson(
            _minimalJsonWith('bookSourceType', entry.key),
          );

          expect(
            source.sourceType,
            entry.value,
            reason: 'bookSourceType ${entry.key}',
          );
        }
      },
    );

    test('fromJson_givenMissingRequiredKey_failsAtThatKey', () {
      expect(
        () => BookSource.fromJson(<String, Object?>{}),
        _failsAt('bookSourceName', because: isA<TypeError>()),
      );
    });

    test(
      'fromJson_givenUnknownBookSourceType_failsInsteadOfSilentlyChoosingOne',
      () {
        // 未知类型一律拒绝整份书源，而不是回落到 text：回落会把音频/图片源
        // 静默当成文本源，比导入失败更难排查（ADR-0022 §决策 5）。
        expect(
          () => BookSource.fromJson(_minimalJsonWith('bookSourceType', 4)),
          _failsAt('bookSourceType', because: isA<ArgumentError>()),
        );
      },
    );
  });

  group('BookSource header conversion', () {
    test('fromJson_givenHeaderJsonString_parsesTheHeaderMap', () {
      final BookSource source = BookSource.fromJson(
        _minimalJsonWith(
          'header',
          '{"User-Agent":"Mozilla/5.0","Referer":"https://example-novel.test"}',
        ),
      );

      expect(source.headers, <String, String>{
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://example-novel.test',
      });
    });

    test('fromJson_givenHeaderObject_parsesTheHeaderMap', () {
      final BookSource source = BookSource.fromJson(
        _minimalJsonWith('header', <String, Object?>{
          'Referer': 'https://example-novel.test',
        }),
      );

      expect(source.headers, <String, String>{
        'Referer': 'https://example-novel.test',
      });
    });

    test('fromJson_givenEmptyHeaderString_returnsNullHeaders', () {
      final BookSource source = BookSource.fromJson(
        _minimalJsonWith('header', '   '),
      );

      expect(source.headers, isNull);
    });

    test('fromJson_givenHeaderStringWithoutAnObject_failsAtTheHeaderKey', () {
      expect(
        () => BookSource.fromJson(_minimalJsonWith('header', '[]')),
        _failsAt('header', because: isA<FormatException>()),
      );
    });

    test(
      'fromJson_givenHeaderEntryThatIsNotAStringPair_failsAtTheHeaderKey',
      () {
        expect(
          () => BookSource.fromJson(_minimalJsonWith('header', '{"a":1}')),
          _failsAt('header', because: isA<FormatException>()),
        );
      },
    );

    test('fromJson_givenHeaderOfAnUnsupportedType_failsAtTheHeaderKey', () {
      expect(
        () => BookSource.fromJson(_minimalJsonWith('header', 42)),
        _failsAt('header', because: isA<FormatException>()),
      );
    });
  });

  group('BookSource extra retention', () {
    test('fromLegadoJson_givenRealExport_keepsTheUnmodelledTopLevelKeys', () {
      final BookSource source = BookSource.fromLegadoJson(_loadFixture());

      expect(
        source.extra.keys,
        unorderedEquals(<String>[
          'bookSourceComment',
          'bookUrlPattern',
          'concurrentRate',
          'customOrder',
          'enabledCookieJar',
          'enabledExplore',
          'enabledReview',
          'exploreUrl',
          'lastUpdateTime',
          'loginCheckJs',
          'loginUi',
          'loginUrl',
          'respondTime',
          'ruleExplore',
          'ruleReview',
          'weight',
        ]),
      );
      expect(source.extra['customOrder'], 60);
      expect(source.extra['lastUpdateTime'], 1676448109528);
      expect(source.extra['enabledReview'], isFalse);
      expect(source.extra['ruleExplore'], isEmpty);
    });

    test(
      'fromLegadoJson_givenUnrecognisedRuleKeys_keepsThemInTheRuleOwnExtra',
      () {
        final BookSource source = BookSource.fromLegadoJson(_loadFixture());

        // 这三个字段属 M0 但尚未建模（nextTocUrl / nextContentUrl 见 PLAN 3.5，
        // replaceRegex 见 PLAN 3.5），因此必须原样落在各自对象的 extra 里。
        expect(
          source.tocRule.extra.keys,
          unorderedEquals(<String>['nextTocUrl']),
        );
        expect(
          source.contentRule.extra.keys,
          unorderedEquals(<String>['nextContentUrl', 'replaceRegex']),
        );
        expect(source.searchRule.extra, isEmpty);
        expect(source.bookInfoRule?.extra, isEmpty);
      },
    );

    test('fromLegadoJson_givenRealExport_accountsForEveryKeyAtEveryLevel', () {
      final Map<String, Object?> json = _loadFixture();
      final BookSource source = BookSource.fromLegadoJson(json);
      final BookInfoRule? bookInfo = source.bookInfoRule;

      // 「不丢信息」的机器可判定形式：真实导出在每一层出现过的键，都必须能在
      // 「已建模字段 ∪ extra」里找到（book-source.md §2）。
      expect(<String>{
        ...source.toJson().keys,
        ...source.extra.keys,
      }, containsAll(json.keys));
      expect(<String>{
        ...source.searchRule.toJson().keys,
        ...source.searchRule.extra.keys,
      }, containsAll(_nestedKeys(json, 'ruleSearch')));
      expect(<String>{
        ...?bookInfo?.toJson().keys,
        ...?bookInfo?.extra.keys,
      }, containsAll(_nestedKeys(json, 'ruleBookInfo')));
      expect(<String>{
        ...source.tocRule.toJson().keys,
        ...source.tocRule.extra.keys,
      }, containsAll(_nestedKeys(json, 'ruleToc')));
      expect(<String>{
        ...source.contentRule.toJson().keys,
        ...source.contentRule.extra.keys,
      }, containsAll(_nestedKeys(json, 'ruleContent')));
    });

    test('fromJson_givenUnrecognisedKeys_dropsThem', () {
      // 与上一条对照：只有 fromLegadoJson 保留未识别键，生成的映射本身会丢弃它们
      // （C-SRC-7 要求 fromJson 保持生成形态）。
      final BookSource source = BookSource.fromJson(_loadFixture());

      expect(source.extra, isEmpty);
      expect(source.tocRule.extra, isEmpty);
    });
  });

  group('BookSource serialisation', () {
    test('toJson_givenImportedSource_reproducesTheLegadoKeys', () {
      final BookSource source = BookSource.fromLegadoJson(_loadFixture());
      final Map<String, Object?> encoded =
          jsonDecode(jsonEncode(source.toJson())) as Map<String, Object?>;

      expect(encoded['bookSourceName'], source.name);
      expect(encoded['bookSourceUrl'], source.url);
      expect(encoded['bookSourceType'], 0);
      expect(encoded['enabled'], isTrue);
      expect(encoded['searchUrl'], '/search/?searchkey={{key}}');
      expect(
        (encoded['ruleToc']! as Map<String, Object?>)['chapterName'],
        'text',
      );
      expect(
        (encoded['ruleSearch']! as Map<String, Object?>)['bookList'],
        '@css:div.item',
      );
    });

    test('toJson_givenHeaders_encodesThemAsAJsonString', () {
      // 归一化：对象形式的 header 回写时统一成 Legado 的字符串形式（ADR-0021）。
      final BookSource source = BookSource.fromJson(
        _minimalJsonWith('header', <String, Object?>{
          'User-Agent': 'Mozilla/5.0',
        }),
      );
      final Map<String, Object?> encoded =
          jsonDecode(jsonEncode(source.toJson())) as Map<String, Object?>;

      expect(encoded['header'], isA<String>());
      expect(jsonDecode(encoded['header']! as String), <String, Object?>{
        'User-Agent': 'Mozilla/5.0',
      });
    });

    test('toJson_givenRetainedExtra_omitsTheExtraKey', () {
      // extra 只保留在内存里：toJson 不写回未识别键，合并回写随导入/导出功能实现
      // （ADR-0021 §后果）。本断言钉住这一点，避免文档再次出现「已能导出」的假宣称。
      final BookSource source = BookSource.fromLegadoJson(_loadFixture());
      final Map<String, Object?> encoded =
          jsonDecode(jsonEncode(source.toJson())) as Map<String, Object?>;

      expect(source.extra, isNotEmpty);
      expect(encoded.containsKey('extra'), isFalse);
      expect(encoded.containsKey('bookSourceComment'), isFalse);
      expect(encoded.containsKey('loginUrl'), isFalse);
    });
  });
}
