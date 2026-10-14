import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The fields that decide how a book source **behaves**, and therefore its identity
/// (ADR-0040 §决策 2).
///
/// User state (`enabled`, `customOrder`) and the display metadata (`bookSourceGroup`,
/// `bookSourceType`, `weight`, `lastUpdateTime`, `respondTime`) are deliberately absent: two
/// entries that differ only there are the *same* source, and an import must not create a second
/// row because the user toggled something.
const List<String> bookSourceFingerprintFields = <String>[
  'bookSourceName',
  'searchUrl',
  'header',
  'ruleSearch',
  'ruleBookInfo',
  'ruleToc',
  'ruleContent',
  'ruleExplore',
];

/// The identity half of a stored source's `(url, fingerprint)` key (ADR-0040 §决策 1).
///
/// The result is the sha256 of the behaviour fields' canonical JSON, so two imports of the same
/// source compare equal even when the file was re-exported with reordered keys; the tool census
/// that produced ADR-0040's numbers uses this same function (`tool/spot_check`), which is why the
/// rule lives here rather than in either caller.
String bookSourceFingerprint(Map<String, Object?> entry) => sha256
    .convert(
      utf8.encode(
        canonicalJson(<String, Object?>{
          for (final String field in bookSourceFingerprintFields)
            field: entry[field],
        }),
      ),
    )
    .toString();

/// Serialises [value] with map keys in a stable order.
///
/// `jsonEncode` keeps insertion order, so a re-export that only reorders keys would otherwise
/// look like a different source (the corpus census in `tool/spot_check/README.md` §3 would have
/// reported 1012 identical duplicates as differences).
String canonicalJson(Object? value) => switch (value) {
  final Map<String, Object?> map =>
    '{${(map.keys.toList()..sort()).map((String key) => '${jsonEncode(key)}:${canonicalJson(map[key])}').join(',')}}',
  final List<Object?> list => '[${list.map(canonicalJson).join(',')}]',
  _ => jsonEncode(value),
};
