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

/// The text of [bytes] in [charset] (upstream's `String(bytes, charset)`).
///
/// The tolerant counterpart of [charsetBytes]: an unknown label falls back to UTF-8, and bytes that
/// the declared encoding cannot decode fall back to UTF-8 as well, with the offending sequences
/// replaced by U+FFFD. Java's `String(byte[], Charset)` never throws either, so a rule reading a
/// half-broken body still gets text instead of losing the whole paragraph.
String charsetText(List<int> bytes, {String? charset}) {
  final Encoding? encoding = charset == null || charset.isEmpty
      ? null
      : Charset.getByName(charset);
  if (encoding == null) {
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  }
  try {
    return encoding.decode(bytes);
  } on FormatException {
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  }
}
