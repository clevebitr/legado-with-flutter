/// The keyword a check or a debug run falls back to when the source declares none.
///
/// It is request data, not UI copy, so it never follows the interface language.
const String defaultCheckKeyword = '我的';

/// Returns the keyword a check or a debug run should search with.
///
/// A blank `checkKeyWord`, or one that holds a rule, falls back to [fallback].
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

/// Whether [value] was meant as a rule rather than as a search keyword.
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

/// Substrings that can only belong to a rule, never to a typed keyword.
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
