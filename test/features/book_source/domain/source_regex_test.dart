import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/source_regex.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the data of [result], failing the test when it failed.
String _data(ParseResult<String> result) => switch (result) {
  ParseSuccess<String>(:final String data) => data,
  ParseFailure<String>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure(ParseResult<String> result) => switch (result) {
  ParseFailure<String>(:final ParseFailureKind kind, :final String rulePath) =>
    ParseFailure<Never>(kind: kind, rulePath: rulePath),
  ParseSuccess<String>() => fail('Expected a failure.'),
};

void main() {
  group('cutBySourceRegex', () {
    test('givenACaptureGroup_answersThatGroup', () {
      // 语料最常见的形态：把正文从壳里抠出来（ADR-0068 §决策 7）。
      final String body = _data(
        cutBySourceRegex(
          '<div class="content">([\\s\\S]*?)</div>',
          '<html><body><div class="content">正文</div></body></html>',
          rulePath: 'contentRule.sourceRegex',
        ),
      );

      expect(body, '正文');
    });

    test('givenNoCaptureGroup_answersTheWholeMatch', () {
      final String body = _data(
        cutBySourceRegex(
          '"content":"(?:[^"]*)',
          '<script>{"content":"正文"}</script>',
          rulePath: 'contentRule.sourceRegex',
        ),
      );

      expect(body, '"content":"正文');
    });

    test('givenAGroupThatMatchedEmpty_answersEmptyNotTheWholeMatch', () {
      // `()` 命中了空串：`group(1)` 是 ''，不是 null，所以不能退回去用整个匹配。
      final String body = _data(
        cutBySourceRegex('x()y', 'axyb', rulePath: 'contentRule.sourceRegex'),
      );

      expect(body, isEmpty);
    });

    test('givenNoMatch_failsTheStage', () {
      final ParseFailure<Never> failure = _failure(
        cutBySourceRegex(
          '<div class="content">([\\s\\S]*?)</div>',
          '<html><body>登录后可见</body></html>',
          rulePath: 'contentRule.sourceRegex',
        ),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'contentRule.sourceRegex');
    });

    test('givenAnInvalidPattern_failsTheStageWithTheCause', () {
      // 规则写坏了和「页面上没有这段」对调用方是同一件事：这个字段产不出正文。
      final ParseResult<String> result = cutBySourceRegex(
        '([unclosed',
        '<html></html>',
        rulePath: 'contentRule.sourceRegex',
      );

      expect(_failure(result).kind, ParseFailureKind.parseFailed);
      expect((result as ParseFailure<String>).cause, isA<FormatException>());
    });

    test('givenATrimmedFragment_isTheBodysOwnStart', () {
      // 截取的是页面片段本身：`@css:` 与 `$.` 都从它开始读，所以首尾空白原样保留。
      final String body = _data(
        cutBySourceRegex(
          r'\{"data".*\}',
          'prefix {"data":[1]} suffix',
          rulePath: 'contentRule.sourceRegex',
        ),
      );

      expect(body, '{"data":[1]}');
    });
  });
}
