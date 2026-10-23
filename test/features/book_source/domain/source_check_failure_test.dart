import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_failure.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isJsFailure', () {
    test('isJsFailure_givenTheBridgeMarkers_isTrue', () {
      // `book-source.md` §6 的既有约定：`@js:` 失败在 rulePath 上带标记。
      expect(isJsFailure('searchRule.name:js:error'), isTrue);
      expect(isJsFailure('contentRule.content:js:timeout'), isTrue);
    });

    test('isJsFailure_givenAPlainRulePath_isFalse', () {
      expect(isJsFailure('ruleToc'), isFalse);
    });
  });

  group('checkGroupForFailure', () {
    test('checkGroupForFailure_givenAJsonScriptError_isJsInvalid', () {
      // JS 失效优先于阶段：要改的是脚本，而不是目录规则。
      expect(
        checkGroupForFailure(
          stage: SourceCheckStage.toc,
          isFromSearch: true,
          kind: ParseFailureKind.parseFailed,
          rulePath: 'tocRule.chapterList:js:error',
        ),
        jsInvalidGroup,
      );
    });

    test('checkGroupForFailure_givenAnEmptySearchToc_isTheSearchToken', () {
      expect(
        checkGroupForFailure(
          stage: SourceCheckStage.toc,
          isFromSearch: true,
          kind: ParseFailureKind.parseFailed,
          rulePath: 'tocRule.chapterList',
        ),
        searchTocInvalidGroup,
      );
    });

    test('checkGroupForFailure_givenAnEmptyExploreToc_isTheExploreToken', () {
      expect(
        checkGroupForFailure(
          stage: SourceCheckStage.toc,
          isFromSearch: false,
          kind: ParseFailureKind.parseFailed,
          rulePath: 'tocRule.chapterList',
        ),
        exploreTocInvalidGroup,
      );
    });

    test('checkGroupForFailure_givenAnEmptySearchContent_isTheSearchToken', () {
      expect(
        checkGroupForFailure(
          stage: SourceCheckStage.content,
          isFromSearch: true,
          kind: ParseFailureKind.parseFailed,
          rulePath: 'contentRule.content',
        ),
        searchContentInvalidGroup,
      );
    });

    test(
      'checkGroupForFailure_givenAnEmptyExploreContent_isTheExploreToken',
      () {
        expect(
          checkGroupForFailure(
            stage: SourceCheckStage.content,
            isFromSearch: false,
            kind: ParseFailureKind.parseFailed,
            rulePath: 'contentRule.content',
          ),
          exploreContentInvalidGroup,
        );
      },
    );

    test('checkGroupForFailure_givenATimeout_isTheTimeoutToken', () {
      expect(
        checkGroupForFailure(
          stage: SourceCheckStage.info,
          isFromSearch: true,
          kind: ParseFailureKind.networkTimeout,
          rulePath: 'ruleBookInfo',
        ),
        checkTimeoutGroup,
      );
    });

    test('checkGroupForFailure_givenAnythingElse_isTheSiteToken', () {
      expect(
        checkGroupForFailure(
          stage: SourceCheckStage.search,
          isFromSearch: true,
          kind: ParseFailureKind.networkFailed,
          rulePath: 'searchUrl',
        ),
        siteInvalidGroup,
      );
      // 目录阶段因为网络失败而不是「目录为空」时，同样归到站点失效。
      expect(
        checkGroupForFailure(
          stage: SourceCheckStage.toc,
          isFromSearch: true,
          kind: ParseFailureKind.encodingFailed,
          rulePath: 'tocRule.chapterList',
        ),
        siteInvalidGroup,
      );
    });
  });
}
