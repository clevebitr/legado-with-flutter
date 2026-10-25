import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Separator that cannot occur inside the key parts, so `('ab', 'c')` and
/// `('a', 'bc')` can never collide.
const String _fieldSeparator = '\u0000';

/// Builds the stable cache key for one request.
///
/// A SHA-256 digest, so a cache dump cannot leak the URL or a search keyword.
String cacheKeyFor({
  required String sourceId,
  required String ruleField,
  required String url,
  required int page,
}) => sha256
    .convert(
      utf8.encode(
        <String>[sourceId, ruleField, url, '$page'].join(_fieldSeparator),
      ),
    )
    .toString();

/// Builds the **scope key** that groups the cache entries of one book.
///
/// A digest of `(书源 ID, 书籍地址)`; per-book counts need no cleartext URL.
String cacheScopeKeyFor({required String sourceId, required String bookUrl}) =>
    sha256
        .convert(utf8.encode(<String>[sourceId, bookUrl].join(_fieldSeparator)))
        .toString();

/// Builds the **source key** that groups the cache entries of one book source.
///
/// A digest of the source id alone; the per-source cache view counts by it without keeping the
/// cleartext URL, and it deliberately does **not** take part in the lookup key.
String cacheSourceKeyFor(String sourceId) =>
    sha256.convert(utf8.encode(sourceId)).toString();
