import 'dart:convert';

import 'package:charset/charset.dart';

/// The bytes of [text] in [charset] (upstream's `String.getBytes(charset)`).
///
/// `null`, an empty label or a label this build does not know falls back to UTF-8: a source that
/// misspells `GBK` still sends *something* the site may accept, and no caller can do better than
/// the fallback (ADR-0068's tolerant stance for broken declarations).
List<int> charsetBytes(String text, {String? charset}) {
  final Encoding? encoding = charset == null || charset.isEmpty
      ? null
      : Charset.getByName(charset);

  return (encoding ?? utf8).encode(text);
}
