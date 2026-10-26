import 'dart:convert';
import 'dart:typed_data';

import 'package:betto_charset_detector/betto_charset_detector.dart';
import 'package:charset/charset.dart';
import 'package:enough_convert/big5.dart' show Big5Codec;

/// Number of leading bytes scanned for an HTML `<meta>` charset declaration.
const int metaScanLimit = 2048;

// 匹配 `<meta charset=…>` 以及 content 属性里的 `charset=…`。
final RegExp _metaCharset = RegExp(
  r'''<meta[^>]+charset\s*=\s*["']?([^"'>/\s;]+)''',
  caseSensitive: false,
);

// 匹配 `Content-Type` 头里的 charset 参数。
final RegExp _charsetParameter = RegExp(
  r'''charset\s*=\s*["']?([^"';\s]+)''',
  caseSensitive: false,
);

/// A response body decoded by [decodeBody].
final class DecodedBody {
  /// Creates a decoded body.
  const DecodedBody({
    required this.text,
    required this.charset,
    required this.malformedByteCount,
    this.isDetected = false,
  });

  /// The decoded text.
  final String text;

  /// The charset used to decode [text].
  final String charset;

  /// Whether [charset] came from byte detection rather than a declaration.
  final bool isDetected;

  /// How many U+FFFD replacements the decode inserted; `0` means a strict decode.
  final int malformedByteCount;

  /// Whether illegal bytes were replaced instead of failing the decode.
  bool get toleratedMalformedBytes => malformedByteCount > 0;
}

/// Decodes [bytes] using, in order, [declaredCharset], [contentType]'s charset, an HTML
/// `<meta>` declaration, [sniffedCharset], then byte detection; unknown labels fall back to
/// UTF-8. Declared charsets decode tolerantly, while a sniffed one throws [FormatException].
DecodedBody decodeBody(
  List<int> bytes, {
  String? contentType,
  String? sniffedCharset,
  String? declaredCharset,
}) {
  final String? declared =
      _normalizeLabel(declaredCharset) ??
      _charsetFromContentType(contentType) ??
      _charsetFromMeta(bytes);

  // 声明优先：服务端显式说了编码就用它，没说才去嗅探。
  if (declared == null) {
    final String detected =
        sniffedCharset ?? detectCharset(Uint8List.fromList(bytes));

    return DecodedBody(
      text: _decodeWith(detected, bytes),
      charset: detected,
      malformedByteCount: 0,
      isDetected: true,
    );
  }

  try {
    return DecodedBody(
      text: _decodeWith(declared, bytes),
      charset: declared,
      malformedByteCount: 0,
    );
  } on FormatException {
    final String? tolerant = _decodeTolerantly(declared, bytes);
    if (tolerant == null) {
      rethrow;
    }

    return DecodedBody(
      text: tolerant,
      charset: declared,
      malformedByteCount: _replacementsIn(tolerant),
    );
  }
}

// 统计替换符数量，即非法字节的位置数。
int _replacementsIn(String text) => '\uFFFD'.allMatches(text).length;

// 空标签视为未声明，否则会压过响应自身的声明。
String? _normalizeLabel(String? label) {
  final String trimmed = label?.trim().toLowerCase() ?? '';

  return trimmed.isEmpty ? null : trimmed;
}

// `charset` 不认识的 Big5 家族，交给 `enough_convert`。
// `big5-hkscs` 复用同一张表，扩展区退化为 U+FFFD。
const Set<String> _big5Labels = <String>{
  'big5',
  'big5-hkscs',
  'cp950',
  'csbig5',
};

// `charset` 为主，只把缺失的 Big5 交给 `enough_convert`。
Encoding? _encodingOf(String label) {
  final Encoding? known = Charset.getByName(label);
  if (known != null) {
    return known;
  }

  return _big5Labels.contains(label) ? const Big5Codec() : null;
}

// 未知标签按 UTF-8 处理。
String _decodeWith(String label, List<int> bytes) =>
    (_encodingOf(label) ?? utf8).decode(bytes);

// 只有这三种解码器支持宽容模式；其余声明编码遇到坏字节就该显式失败。
String? _decodeTolerantly(String label, List<int> bytes) => switch (_encodingOf(
  label,
)) {
  final Utf8Codec _ => const Utf8Decoder(allowMalformed: true).convert(bytes),
  final GbkCodec _ => const GbkCodec(allowMalformed: true).decode(bytes),
  final Big5Codec _ => const Big5Codec(allowInvalid: true).decode(bytes),
  _ => null,
};

String? _charsetFromContentType(String? contentType) => contentType == null
    ? null
    : _charsetParameter.firstMatch(contentType)?.group(1);

// 头部按 latin1 解码：永不失败，且能保留 ASCII 标记。
String? _charsetFromMeta(List<int> bytes) {
  final List<int> head = bytes.length <= metaScanLimit
      ? bytes
      : bytes.sublist(0, metaScanLimit);

  return _metaCharset.firstMatch(latin1.decode(head))?.group(1);
}
