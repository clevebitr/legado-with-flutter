import 'dart:convert';
import 'dart:io';

import 'package:flutter_reader/core/error/parse_failure_arb_key.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParseResult', () {
    test('success_whenPatternMatched_carriesData', () {
      const ParseResult<int> result = ParseResult.success(7);

      // 无 default 分支：密封层级的穷尽性由编译器保证（ADR-0002）。
      final String description = switch (result) {
        ParseSuccess<int>(:final int data) => 'success:$data',
        ParseFailure<int>(:final ParseFailureKind kind) =>
          'failure:${kind.name}',
      };

      expect(description, 'success:7');
    });

    test('failure_whenPatternMatched_carriesRulePath', () {
      const ParseResult<int> result = ParseResult.failure(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'searchRule.bookList',
      );

      final String description = switch (result) {
        ParseSuccess<int>() => 'success',
        ParseFailure<int>(:final String rulePath) => 'failure:$rulePath',
      };

      expect(description, 'failure:searchRule.bookList');
    });

    test('failure_whenDiagnosticsAreRecorded_keepsCauseAndTrace', () {
      const ParseResult<String> result = ParseResult.failure(
        kind: ParseFailureKind.networkTimeout,
        rulePath: r'$.searchUrl',
        cause: FormatException('broken payload'),
        stackTrace: StackTrace.empty,
      );

      final ParseFailure<String> failure = switch (result) {
        final ParseFailure<String> value => value,
        ParseSuccess<String>() => fail('Expected a failure result.'),
      };

      expect(failure.kind, ParseFailureKind.networkTimeout);
      expect(failure.rulePath, r'$.searchUrl');
      expect(failure.cause, isA<FormatException>());
      expect(failure.stackTrace, StackTrace.empty);
    });

    test('success_whenComparedByValue_isEqual', () {
      const ParseResult<int> first = ParseResult.success(1);
      const ParseResult<int> second = ParseResult.success(1);
      const ParseResult<int> other = ParseResult.success(2);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(other));
    });

    test('failure_whenKindRulePathAndCauseMatch_isEqual', () {
      final FormatException cause = _brokenPayload('broken payload');
      final ParseResult<int> first = ParseResult.failure(
        kind: ParseFailureKind.notFound,
        rulePath: 'tocRule.chapterList',
        cause: cause,
      );
      final ParseResult<int> second = ParseResult.failure(
        kind: ParseFailureKind.notFound,
        rulePath: 'tocRule.chapterList',
        cause: cause,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('failure_whenCauseDiffers_isNotEqual', () {
      // cause 参与结构化相等：异常实例不同则结果不同，故 ParseResult 不能当去重
      // 或缓存键使用（缓存键见 C-NET-6）。
      final ParseResult<int> first = ParseResult.failure(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'searchRule.bookList',
        cause: _brokenPayload('broken payload'),
      );
      final ParseResult<int> second = ParseResult.failure(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'searchRule.bookList',
        cause: _brokenPayload('broken payload'),
      );

      expect(first, isNot(second));
    });

    test('dataOrNull_whenSuccess_returnsWrappedData', () {
      const ParseResult<int> result = ParseResult.success(3);

      expect(result.dataOrNull, 3);
    });

    test('dataOrNull_whenFailure_returnsNull', () {
      const ParseResult<int> result = ParseResult.failure(
        kind: ParseFailureKind.networkFailed,
        rulePath: 'searchUrl',
      );

      expect(result.dataOrNull, isNull);
    });

    test('whenSuccess_whenSuccess_invokesCallbackWithData', () {
      const ParseResult<int> result = ParseResult.success(5);
      final List<int> collected = <int>[];

      result.whenSuccess(collected.add);

      expect(collected, <int>[5]);
    });

    test('whenSuccess_whenFailure_doesNotInvokeCallback', () {
      const ParseResult<int> result = ParseResult.failure(
        kind: ParseFailureKind.cancelled,
        rulePath: 'searchUrl',
      );
      final List<int> collected = <int>[];

      result.whenSuccess(collected.add);

      expect(collected, isEmpty);
    });
  });

  group('ParseFailureKind', () {
    test('values_whenEnumerated_containsNineKinds', () {
      expect(ParseFailureKind.values, hasLength(9));
    });

    test('isRetryable_whenKindIsTransient_isTrue', () {
      expect(ParseFailureKind.networkTimeout.isRetryable, isTrue);
      expect(ParseFailureKind.networkFailed.isRetryable, isTrue);
    });

    test('isRetryable_whenKindIsPermanent_isFalse', () {
      const List<ParseFailureKind> permanent = <ParseFailureKind>[
        ParseFailureKind.networkForbidden,
        ParseFailureKind.notFound,
        ParseFailureKind.encodingFailed,
        ParseFailureKind.parseFailed,
        ParseFailureKind.unsupportedRule,
        ParseFailureKind.invalidBookSource,
        ParseFailureKind.cancelled,
      ];

      expect(
        permanent.map((ParseFailureKind kind) => kind.isRetryable),
        everyElement(isFalse),
      );
    });
  });

  group('failureAt', () {
    test('failureAt_givenAnEmptyRulePath_throwsAssertionError', () {
      // C-SRC-8：没有 rulePath 的失败无法定位，因此这是编程错误而不是运行时状况。
      expect(
        () => failureAt<void>(kind: ParseFailureKind.parseFailed, rulePath: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('failureAt_givenAFailure_carriesKindPathAndCause', () {
      final ParseFailure<void> failure = failureAt<void>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'unsupported:@css:',
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'unsupported:@css:');
      expect(failure.cause, isNull);
      expect(failure.stackTrace, isNull);
    });
  });

  group('firstFailure', () {
    test('firstFailure_givenOnlySuccesses_returnsNull', () {
      final ParseFailure<String>? failure = firstFailure<String>(
        <ParseResult<Object?>>[
          const ParseSuccess<String?>('§1'),
          const ParseSuccess<String?>(null),
        ],
      );

      expect(failure, isNull);
    });

    test('firstFailure_givenNoResults_returnsNull', () {
      expect(firstFailure<String>(const <ParseResult<Object?>>[]), isNull);
    });

    test(
      'firstFailure_givenAFailureAfterSuccesses_returnsItForTheCallerType',
      () {
        final ParseFailure<String>? failure = firstFailure<String>(
          <ParseResult<Object?>>[
            const ParseSuccess<String?>('§1'),
            const ParseFailure<String?>(
              kind: ParseFailureKind.unsupportedRule,
              rulePath: 'unsupported:@css:',
            ),
          ],
        );

        expect(failure, isNotNull);
        expect(failure!.kind, ParseFailureKind.unsupportedRule);
        expect(failure.rulePath, 'unsupported:@css:');
      },
    );

    test('firstFailure_givenSeveralFailures_returnsTheFirstOne', () {
      // 一个条目有多个字段时，报告最先把搜索打断的那个字段才有定位价值。
      final ParseFailure<String>? failure = firstFailure<String>(
        <ParseResult<Object?>>[
          const ParseFailure<String?>(
            kind: ParseFailureKind.parseFailed,
            rulePath: 'searchRule.name',
          ),
          const ParseFailure<String?>(
            kind: ParseFailureKind.unsupportedRule,
            rulePath: 'unsupported:@css:',
          ),
        ],
      );

      expect(failure?.rulePath, 'searchRule.name');
    });

    test('firstFailure_givenDiagnostics_doesNotCarryThemOver', () {
      final ParseFailure<String>? failure = firstFailure<String>(
        <ParseResult<Object?>>[
          const ParseFailure<String?>(
            kind: ParseFailureKind.networkTimeout,
            rulePath: 'searchUrl',
            cause: FormatException('broken payload'),
            stackTrace: StackTrace.empty,
          ),
        ],
      );

      expect(failure?.kind, ParseFailureKind.networkTimeout);
      expect(failure?.cause, isNull);
      expect(failure?.stackTrace, isNull);
    });
  });

  group('resolveFailureArbKey', () {
    test('resolveFailureArbKey_whenEveryNonSilentKindIsMapped_producesDistinctKeys', () {
      final List<String> keys = ParseFailureKind.values
          .map(resolveFailureArbKey)
          .whereType<String>()
          .toList();

      expect(keys, hasLength(8));
      expect(keys.toSet(), hasLength(8));
    });

    test(
      'resolveFailureArbKey_whenKindIsNotSilent_followsFailurePascalCaseRule',
      () {
        for (final ParseFailureKind kind in ParseFailureKind.values) {
          final String? key = resolveFailureArbKey(kind);
          if (key == null) {
            continue;
          }
          final String pascalCase =
              '${kind.name[0].toUpperCase()}${kind.name.substring(1)}';

          expect(key, 'failure$pascalCase');
        }
      },
    );

    test('resolveFailureArbKey_whenKindIsCancelled_returnsNull', () {
      expect(resolveFailureArbKey(ParseFailureKind.cancelled), isNull);
    });

    test('resolveFailureArbKey_whenEnglishTemplateIsChecked_hasKeyAndDescriptionPerKind', () {
      final Map<String, Object?> arb = _readArb('en');

      for (final ParseFailureKind kind in ParseFailureKind.values) {
        final String? key = resolveFailureArbKey(kind);
        if (key == null) {
          continue;
        }
        expect(
          arb.containsKey(key),
          isTrue,
          reason: 'app_en.arb is missing the message key "$key".',
        );
        expect(
          arb.containsKey('@$key'),
          isTrue,
          reason: 'app_en.arb is missing the placeholder metadata "@$key".',
        );
      }
    });

    test(
      'resolveFailureArbKey_whenChineseTranslationIsChecked_hasKeyPerKind',
      () {
        final Map<String, Object?> arb = _readArb('zh');

        for (final ParseFailureKind kind in ParseFailureKind.values) {
          final String? key = resolveFailureArbKey(kind);
          if (key == null) {
            continue;
          }
          expect(
            arb[key],
            isA<String>().having((String text) => text, 'text', isNotEmpty),
            reason: 'app_zh.arb is missing a translation for "$key".',
          );
        }
      },
    );

    test(
      'resolveFailureArbKey_whenKindIsCancelled_hasNoMessageKeyInEitherLocale',
      () {
        // ADR-0002：cancelled 由 UI 静默处理，不提供文案键。
        for (final String locale in <String>['en', 'zh']) {
          expect(
            _readArb(locale).containsKey('failureCancelled'),
            isFalse,
            reason: 'app_$locale.arb must not define a key for cancelled.',
          );
        }
      },
    );
  });
}

// 每次调用都返回一个新的异常实例；cause 的相等性依赖实例身份，因此这里故意不用
// const 异常（否则两处引用会被规范化成同一实例，测试就失去意义）。
FormatException _brokenPayload(String payload) => FormatException(payload);

/// 读取 ARB；从 pubspec.yaml 定位包根，使测试不依赖进程的当前工作目录。
Map<String, Object?> _readArb(String locale) {
  final File file = File('${_packageRoot().path}/lib/l10n/app_$locale.arb');
  final Object? decoded = jsonDecode(file.readAsStringSync());

  return decoded as Map<String, Object?>;
}

/// 从当前目录向上查找包含 pubspec.yaml 的目录，作为包根。
Directory _packageRoot() {
  Directory directory = Directory.current;
  while (!File('${directory.path}/pubspec.yaml').existsSync()) {
    final Directory parent = directory.parent;
    if (parent.path == directory.path) {
      fail('Could not locate the package root (pubspec.yaml).');
    }
    directory = parent;
  }
  return directory;
}
