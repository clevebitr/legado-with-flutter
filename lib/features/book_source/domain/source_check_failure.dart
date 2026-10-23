import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';

// JsBridge 在规则路径后面追加的失败标记。
const String _jsErrorMarker = ':js:error';
const String _jsTimeoutMarker = ':js:timeout';

/// Whether [rulePath] says the failure came from a `@js:` rule.
bool isJsFailure(String rulePath) =>
    rulePath.endsWith(_jsErrorMarker) || rulePath.endsWith(_jsTimeoutMarker);

/// The group token that describes a stage failure.
///
/// A `@js:` failure wins, then an empty search/explore list, table of contents and body;
/// a timeout and everything else fall back to the site token.
String checkGroupForFailure({
  required SourceCheckStage stage,
  required bool isFromSearch,
  required ParseFailureKind kind,
  required String rulePath,
}) {
  if (isJsFailure(rulePath)) {
    return jsInvalidGroup;
  }

  if (kind == ParseFailureKind.parseFailed &&
      (rulePath.startsWith('searchRule') ||
          rulePath.startsWith('exploreRule'))) {
    // 发现阶段会整条回落到 searchRule，所以两个前缀都要认。
    return stage == SourceCheckStage.explore
        ? exploreInvalidGroup
        : searchInvalidGroup;
  }

  if (stage == SourceCheckStage.toc &&
      kind == ParseFailureKind.parseFailed &&
      rulePath.startsWith('tocRule')) {
    return isFromSearch ? searchTocInvalidGroup : exploreTocInvalidGroup;
  }

  if (stage == SourceCheckStage.content &&
      kind == ParseFailureKind.parseFailed &&
      rulePath.startsWith('contentRule')) {
    return isFromSearch
        ? searchContentInvalidGroup
        : exploreContentInvalidGroup;
  }

  if (kind == ParseFailureKind.networkTimeout) {
    return checkTimeoutGroup;
  }

  return siteInvalidGroup;
}
