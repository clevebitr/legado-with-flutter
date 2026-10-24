import 'package:flutter_reader/core/error/parse_result.dart';

/// Cuts the wanted payload out of a page body with `ruleContent.sourceRegex`.
///
/// Upstream runs this inside its WebView fetcher (`BackstageWebView`'s `sourceRegex`), so the
/// **page the rules read** is the cut fragment rather than the whole document — a site that wraps
/// its content in a shell (`<div id="app">…</div>` plus megabytes of scripts) parses correctly once
/// the shell is gone (`docs/dev/book-source.md` §2, ADR-0068 §决策 7).
///
/// The fragment is the first capture group when the pattern has one and the whole match otherwise,
/// which is what the corpus writes (`<div class="content">([\s\S]*?)</div>`).
///
/// A pattern that matches nothing is a **failure**, not an empty body: the rule said where the
/// payload is, and a page that no longer has it is a stale rule (ADR-0026 §决策 1 — `sourceRegex`
/// is top-level, so it does not degrade to "no value"). A pattern that does not compile is the
/// same failure, because both mean "this rule cannot produce a body".
ParseResult<String> cutBySourceRegex(
  String pattern,
  String body, {
  required String rulePath,
}) {
  final RegExp regex;
  try {
    regex = RegExp(pattern);
  } on FormatException catch (error) {
    return failureAt<String>(
      kind: ParseFailureKind.parseFailed,
      rulePath: rulePath,
      cause: error,
    );
  }

  final RegExpMatch? match = regex.firstMatch(body);
  if (match == null) {
    return failureAt<String>(
      kind: ParseFailureKind.parseFailed,
      rulePath: rulePath,
    );
  }
  if (match.groupCount > 0) {
    final String? group = match.group(1);
    if (group != null) {
      return ParseSuccess<String>(group);
    }
  }
  // 整个匹配直接按位置切：`group(0)` 的类型是可空的，而这段文本必然存在。
  return ParseSuccess<String>(body.substring(match.start, match.end));
}
