import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The fields that decide how a book source behaves, and therefore its identity.
///
/// User state and display metadata are absent: two entries that differ only there are the
/// same source, so toggling one must not create a second row.
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

/// The identity half of a stored source's `(url, fingerprint)` key.
///
/// It is the sha256 of the behaviour fields' canonical JSON, so key order does not matter.
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
/// `jsonEncode` keeps insertion order, so a re-export that only reorders keys would
/// otherwise look like a different source.
String canonicalJson(Object? value) => switch (value) {
  final Map<String, Object?> map =>
    '{${(map.keys.toList()..sort()).map((String key) => '${jsonEncode(key)}:${canonicalJson(map[key])}').join(',')}}',
  final List<Object?> list => '[${list.map(canonicalJson).join(',')}]',
  _ => jsonEncode(value),
};
