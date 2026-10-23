import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';

/// The marker `JsBridge` appends to a rule path when a script threw (`book-source.md` §6).
const String _jsErrorMarker = ':js:error';

/// The marker `JsBridge` appends to a rule path when a script ran out of budget (`book-source.md` §6).
const String _jsTimeoutMarker = ':js:timeout';

/// Whether [rulePath] says the failure came from a `@js:` rule (`book-source.md` §6).
///
/// The markers are the bridge's own contract, so this is the **one** place that reads them: a
/// check must be able to tell "the source's script is broken" from "the site is broken", and
/// adding a `ParseFailureKind` for it would change the core contract for information the path
/// already carries (ADR-0043 §决策 4).
bool isJsFailure(String rulePath) =>
    rulePath.endsWith(_jsErrorMarker) || rulePath.endsWith(_jsTimeoutMarker);

/// The group token that describes a stage failure (ADR-0043 §决策 4).
///
/// The precedence is deliberate:
///
/// 1. a `@js:` failure is a script problem ([jsInvalidGroup]) no matter which stage it broke,
///    because that is the thing the user has to fix;
/// 2. a **list rule** that matched nothing is 「搜索失效」/「发现失效」 — upstream reports a search
///    that returned no book that way, and `PageFetchService.list` calls the same situation
///    `parseFailed` (`book-source.md` §7), so the two must be reconciled here rather than in the
///    UI;
/// 3. an empty table of contents or body is 「搜索目录失效」/「搜索正文失效」, i.e. the rules no
///    longer fit the page;
/// 4. a network timeout is [checkTimeoutGroup];
/// 5. everything else is [siteInvalidGroup]: the site answered, but not in a way the rules read.
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
    // 发现阶段会整条回落到 `searchRule`（ADR-0035 §决策 2），所以两个前缀都要认。
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
