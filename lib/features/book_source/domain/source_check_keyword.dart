/// The keyword a check or a debug run falls back to when the source declares none.
///
/// It is **data, not UI copy**: the value is rendered into `searchUrl` and sent to the site, so it
/// must not follow the interface language — an English UI would otherwise search Chinese sites for
/// an English word. The value is upstream's own default (`BookSourceCheckRepository.kt:69`,
/// `keyword.ifBlank { "我的" }`), which is what makes the same source behave the same way here.
/// UI labels stay in ARB (C-UI-5); a keyword is a request parameter.
const String defaultCheckKeyword = '我的';

/// Returns the keyword a check or a debug run should search with (ADR-0043 §决策 2).
///
/// [checkKeyWord] is the source's `ruleSearch.checkKeyWord` (`book-source.md` §2). It wins when it
/// is a usable keyword and falls back to [fallback] when it is blank or **looks like a rule** —
/// upstream's behaviour (`BookSource.kt:228-238`), with the predicate spelled out in [looksLikeRule]
/// instead of being copied as four `contains` calls.
String resolveCheckKeyword({
  required String? checkKeyWord,
  required String fallback,
}) {
  final String? word = checkKeyWord?.trim();
  if (word == null || word.isEmpty || looksLikeRule(word)) {
    return fallback;
  }

  return word;
}

/// Whether [value] was meant as a **rule** rather than as a search keyword.
///
/// A source that writes a rule into `checkKeyWord` (real corpus: 2 of 85 sources) is not offering a
/// keyword, and searching with the rule text would cost a request and a misleading failure. The
/// shape is judged by the syntax markers a Legado rule uses, not by trying to evaluate it:
///
/// * a URL or an HTTP call — `http` (either case) or `://`;
/// * a rule separator — `::` (`@css:` / `@json:` chains), `++` / `--` (upstream's debug target
///   prefixes), `##` (a replacement rule);
/// * a URL template — `{{`;
/// * a rule head — the value starts with `@` (`@css:`, `@json:`, `@@`), `$` (JSONPath) or `$..`.
bool looksLikeRule(String value) {
  final String text = value.trim();
  if (text.isEmpty) {
    return false;
  }

  final String lower = text.toLowerCase();
  for (final String marker in _ruleMarkers) {
    if (lower.contains(marker)) {
      return true;
    }
  }

  return _ruleHeads.any(text.startsWith);
}

/// Substrings that can only belong to a rule, never to something a user types as a keyword.
const List<String> _ruleMarkers = <String>[
  'http',
  '://',
  '::',
  '++',
  '--',
  '##',
  '{{',
];

/// The prefixes that start a rule (`@css:` / `@json:` / `@@` / JSONPath).
const List<String> _ruleHeads = <String>['@', r'$'];
