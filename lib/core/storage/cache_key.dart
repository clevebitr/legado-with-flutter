import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Separator that cannot occur inside the key parts, so `('ab', 'c')` and
/// `('a', 'bc')` can never collide.
const String _fieldSeparator = '\u0000';

/// Builds the stable cache key for one request (C-NET-6, `book-source.md` §8).
///
/// The key is the SHA-256 digest of「书源 ID + 规则字段 + URL + 页码」. It is stable
/// across runs and never stores the URL or a search keyword in cleartext, so a
/// cache dump cannot leak what the user searched for.
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
