/// The sandbox's pure helpers: `java.randomUUID` / `timeFormatUTC` / `toNumChapter` / `toURL` /
/// `htmlFormat` / `t2s` / `s2t` (M25/S3b).
///
/// Everything here runs **inside the worker isolate** and answers synchronously (`book-source.md` §6),
/// which is what makes `tag = java.t2s(tag)` work in a rule. The two conversion tables live in
/// `assets/zh/` and are loaded lazily (`ZhTables`); a call before the table is ready fails readably
/// instead of silently returning the input.
library;

import 'dart:math';

import 'package:flutter_reader/core/js/zh_converter.dart';

/// The binding name of the pure helper family.
const String jsHelperBinding = 'helper';

/// The key an envelope uses to report a failure the rule can read (same shape as the crypto family).
const String jsHelperErrorKey = '__error';

/// What the helpers need from the outside world: the two conversion tables, once loaded.
final class JsHelperContext {
  /// Creates a context; a `null` table means "not loaded yet" and answers a readable failure.
  const JsHelperContext({this.t2s, this.s2t});

  /// 繁 → 简.
  final ZhConverter? t2s;

  /// 简 → 繁.
  final ZhConverter? s2t;
}

/// Applies one helper call, answering a `String` / `int` / object / `{jsHelperErrorKey: message}`.
Object? applyJsHelperCall(Object? args, JsHelperContext context) {
  if (args is! Map) {
    return _failure('malformed helper call');
  }
  final Object? operation = args['operation'];
  if (operation is! String || operation.isEmpty) {
    return _failure('malformed helper call');
  }
  try {
    switch (operation) {
      case 'randomUUID':
        return randomUuid();
      case 'timeFormatUTC':
        return formatUtcTime(
          _requiredText(args['value']),
          _requiredText(args['format']),
          (args['sh'] as num?)?.toInt() ?? 0,
        );
      case 'toNumChapter':
        return toNumChapter(_requiredText(args['value']));
      case 'toURL':
        return parseSandboxUrl(
          _requiredText(args['value']),
          baseUrl: args['baseUrl'] is String ? args['baseUrl'] as String : null,
        );
      case 'htmlFormat':
        return formatKeepImg(_requiredText(args['value']));
      case 't2s':
        return _convert(context.t2s, 't2s', _requiredText(args['value']));
      case 's2t':
        return _convert(context.s2t, 's2t', _requiredText(args['value']));
      default:
        return _failure('java.$operation is not a sandbox helper');
    }
  } on FormatException catch (error) {
    return _failure(error.message);
  }
}

String _convert(ZhConverter? table, String name, String value) {
  if (table == null) {
    throw FormatException(
      'java.$name is unavailable: the conversion table did not load',
    );
  }

  return table.convert(value);
}

/// A random version-4 UUID in the canonical 8-4-4-4-12 form (upstream `Uuid.random()`).
String randomUuid() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // 版本号 4（随机 UUID），变体位按 RFC 4122 置 `10`。
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Formats one millisecond timestamp in a **fixed** offset zone with a Java `SimpleDateFormat` pattern.
///
/// Only the pattern letters real sources use are supported (`y`/`M`/`d`/`H`/`h`/`m`/`s`/`S`, quoted
/// literals with `'`); an unknown letter is copied through verbatim rather than throwing, because a
/// broken pattern should not cost a rule its date. This mirrors upstream `JsExtensions.timeFormatUTC`
/// (`SimpleTimeZone(sh, "UTC")`, `SimpleDateFormat(format)`), which also has no DST rules.
String formatUtcTime(String value, String format, int offsetHours) {
  final int? milliseconds =
      int.tryParse(value.trim()) ?? double.tryParse(value)?.toInt();
  if (milliseconds == null) {
    throw FormatException('timeFormatUTC expects a timestamp (got "$value")');
  }
  final DateTime shifted = DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).add(Duration(hours: offsetHours));
  final StringBuffer out = StringBuffer();
  int index = 0;
  while (index < format.length) {
    final String unit = format[index];
    if (unit == "'") {
      // `'…'` 是字面量；Java 用 `''` 表示一个引号本身（同样适用于字面量开头）。
      if (index + 1 < format.length && format[index + 1] == "'") {
        out.write("'");
        index += 2;
        continue;
      }
      int end = index + 1;
      final StringBuffer literal = StringBuffer();
      while (end < format.length) {
        if (format[end] == "'") {
          if (end + 1 < format.length && format[end + 1] == "'") {
            literal.write("'");
            end += 2;
            continue;
          }
          break;
        }
        literal.write(format[end]);
        end += 1;
      }
      out.write(literal);
      index = end + 1;
      continue;
    }
    int run = 1;
    while (index + run < format.length && format[index + run] == unit) {
      run += 1;
    }
    out.write(_formatField(shifted, unit, run));
    index += run;
  }

  return out.toString();
}

String _formatField(DateTime time, String unit, int width) {
  final int? value = switch (unit) {
    'y' => time.year,
    'M' => time.month,
    'd' => time.day,
    'H' => time.hour,
    'h' => time.hour % 12 == 0 ? 12 : time.hour % 12,
    'm' => time.minute,
    's' => time.second,
    'S' => time.millisecond,
    _ => null,
  };
  if (value == null) {
    return unit * width;
  }
  if (unit == 'y' && width == 2) {
    return (value % 100).toString().padLeft(2, '0');
  }

  return value.toString().padLeft(width, '0');
}

/// `java.toNumChapter`: rewrites the number inside `第…章` to digits.
///
/// Upstream uses `AppPattern.titleNumPattern` (`(第)(.+?)(章)`) plus `StringUtils.stringToInt`, which
/// parses half-width digits first and falls back to Chinese numerals; anything unreadable comes back
/// untouched, which is what keeps a source from losing a title to this helper.
String toNumChapter(String value) {
  final Match? match = RegExp('(第)(.+?)(章)').firstMatch(value);
  if (match == null) {
    return value;
  }
  final String body = match.group(2) ?? '';
  final int? number = _numberOf(body);
  if (number == null) {
    return value;
  }
  final String head = value.substring(0, match.start);
  final String tail = value.substring(match.end);

  return '$head第$number章$tail';
}

int? _numberOf(String text) {
  // 全角数字 → 半角，去空白（上游 `fullToHalf` + `replace("\\s+")`）。
  final StringBuffer normalised = StringBuffer();
  for (final int code in text.codeUnits) {
    if (code >= 0xFF10 && code <= 0xFF19) {
      normalised.writeCharCode(code - 0xFF10 + 0x30);
    } else if (code >= 0xFF21 && code <= 0xFF3A) {
      normalised.writeCharCode(code - 0xFF21 + 0x41);
    } else if (code >= 0xFF41 && code <= 0xFF5A) {
      normalised.writeCharCode(code - 0xFF41 + 0x61);
    } else if (code == 0x20 || code == 0x09 || code == 0x3000) {
      continue;
    } else {
      normalised.writeCharCode(code);
    }
  }
  final String plain = normalised.toString();
  final int? digits = int.tryParse(plain);
  if (digits != null) {
    return digits;
  }

  return chineseNumeralToInt(plain);
}

/// Reads a Chinese numeral (`一百二十三` → 123), or `null` when [text] is not one.
///
/// Covers the units that appear in chapter titles (`十百千万亿`) and the digits that sources use
/// (`一二三四五六七八九零〇两`); anything else returns `null` so the caller can keep the original text.
int? chineseNumeralToInt(String text) {
  if (text.isEmpty) {
    return null;
  }
  const Map<String, int> digits = <String, int>{
    '零': 0,
    '〇': 0,
    '一': 1,
    '壹': 1,
    '二': 2,
    '贰': 2,
    '两': 2,
    '俩': 2,
    '三': 3,
    '叁': 3,
    '四': 4,
    '肆': 4,
    '五': 5,
    '伍': 5,
    '六': 6,
    '陆': 6,
    '七': 7,
    '柒': 7,
    '八': 8,
    '捌': 8,
    '九': 9,
    '玖': 9,
  };
  const Map<String, int> units = <String, int>{
    '十': 10,
    '拾': 10,
    '百': 100,
    '佰': 100,
    '千': 1000,
    '仟': 1000,
    '万': 10000,
    '萬': 10000,
    '亿': 100000000,
    '億': 100000000,
  };
  int total = 0;
  int section = 0;
  int digit = 0;
  bool sawAny = false;
  for (final String char in text.split('')) {
    final int? value = digits[char];
    if (value != null) {
      digit = value;
      sawAny = true;
      continue;
    }
    final int? unit = units[char];
    if (unit == null) {
      return null;
    }
    sawAny = true;
    if (unit >= 10000) {
      section = (section + (digit == 0 && section == 0 ? 1 : digit)) * unit;
      // 万/亿 之后的数字重新从小节开始累计。
      total += section;
      section = 0;
      digit = 0;
    } else {
      // `十二` 这种省略了「一」的写法按 1 处理。
      final int count = digit == 0 ? 1 : digit;
      section += count * unit;
      digit = 0;
    }
  }
  if (!sawAny) {
    return null;
  }
  total += section + digit;

  return total;
}

/// `java.toURL`: the parts of a URL a rule reads (`host` / `origin` / `pathname` / `searchParams`).
///
/// Upstream builds a `JsURL`; its `origin` has a long-standing bug (it interpolates the whole URL
/// after `host:`), so this returns the intended `scheme://host[:port]` and registers the difference
/// in `book-source.md` §6. `searchParams` decodes values the way `URLDecoder.decode(value, "utf-8")`
/// does, with a space for `+`.
Map<String, Object?> parseSandboxUrl(String value, {String? baseUrl}) {
  final Uri? parsed = _resolveUrl(value, baseUrl);
  if (parsed == null) {
    throw FormatException('toURL: "${value.trim()}" is not a URL');
  }
  final Map<String, String> params = <String, String>{};
  for (final String pair in parsed.query.split('&')) {
    if (pair.isEmpty) {
      continue;
    }
    final int separator = pair.indexOf('=');
    final String key = separator < 0 ? pair : pair.substring(0, separator);
    final String rawValue = separator < 0 ? '' : pair.substring(separator + 1);
    params[_decodeQueryComponent(key)] = _decodeQueryComponent(rawValue);
  }

  return <String, Object?>{
    'host': parsed.host,
    'origin': parsed.hasPort
        ? '${parsed.scheme}://${parsed.host}:${parsed.port}'
        : '${parsed.scheme}://${parsed.host}',
    'pathname': parsed.path,
    'searchParams': params,
  };
}

Uri? _resolveUrl(String value, String? baseUrl) {
  final Uri? direct = Uri.tryParse(value.trim());
  if (baseUrl == null || baseUrl.isEmpty) {
    return direct?.hasScheme == true ? direct : null;
  }
  final Uri? base = Uri.tryParse(baseUrl.trim());
  if (base == null) {
    return direct?.hasScheme == true ? direct : null;
  }

  return base.resolve(value.trim());
}

String _decodeQueryComponent(String value) {
  try {
    return Uri.decodeQueryComponent(value);
  } on FormatException {
    // 坏百分号编码原样交回：`toURL` 是只读工具，不该因为一个畸形参数让整条规则失败。
    return value;
  }
}

/// `java.htmlFormat`: upstream's `HtmlFormatter.formatKeepImg` — tags become paragraph breaks, every
/// tag except `<img>` is dropped, whitespace is collapsed and paragraphs get the two-full-width-space
/// indent. `<img>` keeps its `src` (and a `,{…}` option suffix), which is what makes the result
/// renderable in the reader.
String formatKeepImg(String html) {
  if (html.isEmpty) {
    return '';
  }
  final List<String> images = <String>[];
  final StringBuffer withPlaceholders = StringBuffer();
  int cursor = 0;
  for (final RegExpMatch match in _imageTag.allMatches(html)) {
    withPlaceholders.write(html.substring(cursor, match.start));
    final String image = _normaliseImage(match.group(0) ?? '');
    // 拿不到地址的 `<img>` 直接丢掉：上游没有占位符，所以它也不会留下一次段落分隔。
    if (image.isNotEmpty) {
      // 占位符用不会被正文使用的一对标记，最后再换回规范化后的 <img>。
      withPlaceholders.write('\u0000${images.length}\u0000');
      images.add(image);
    }
    cursor = match.end;
  }
  withPlaceholders.write(html.substring(cursor));

  String text = withPlaceholders
      .toString()
      .replaceAll(RegExp('(&nbsp;)+'), ' ')
      .replaceAll(RegExp('&ensp;|&emsp;'), ' ')
      .replaceAll(RegExp('&thinsp;|&zwnj;|&zwj;|\u2009|\u200C|\u200D'), '')
      // 块级标签先变段落分隔，再删掉剩下的标签（`<img>` 已换成占位符）。
      .replaceAll(
        RegExp(
          '</?(?:div|p|br|hr|h\\d|article|dd|dl)[^>]*>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(RegExp('<!--[^>]*-->'), '')
      .replaceAll(RegExp('</?[a-zA-Z]+(?=[ >])[^<>]*>'), '');
  text = text
      .replaceAll(RegExp(r'\s*\n+\s*'), '\n　　')
      .replaceAll(RegExp(r'^[\n\s]+'), '　　')
      .replaceAll(RegExp(r'[\n\s]+$'), '');
  for (int index = 0; index < images.length; index++) {
    text = text.replaceAll('\u0000$index\u0000', images[index]);
  }

  return text;
}

/// `<img …>` excluding `<!--` comments and self-closing `<img/>`.
final RegExp _imageTag = RegExp('<img\\b[^>]*>', caseSensitive: false);

/// Rebuilds one `<img>` as `<img src="…">`, keeping the `,{…}` option suffix upstream supports.
///
/// Upstream also reads a mustache-ish `src="{…}"`; those are not absolutised here either (the JS call
/// passes no redirect URL), so the plain `data-src` / `src` / `data-*` order is enough.
String _normaliseImage(String tag) {
  final String? value =
      _attribute(tag, 'src') ??
      _attribute(tag, 'data-src') ??
      _firstDataAttribute(tag);
  if (value == null || value.isEmpty) {
    // 拿不到地址就整条丢掉：输出是给阅读器渲染的，`<img>` 没有 src 只会画一个占位框。
    return '';
  }
  final int suffixStart = value.indexOf(',{');
  final String url = suffixStart < 0 ? value : value.substring(0, suffixStart);
  final String suffix = suffixStart < 0 ? '' : value.substring(suffixStart);

  return '<img src="${_escapeAttribute(url)}$suffix">';
}

/// Reads one attribute value from [tag], tolerating quotes inside a `{…}` option blob.
///
/// Upstream's pattern for this is a brace-aware regex (`src="…{…}"`); a scanner is easier to keep
/// correct: quotes inside braces do not end the value, which is exactly the `,{"headers":{…}}` form
/// real sources put in `src`.
String? _attribute(String tag, String name) {
  final RegExpMatch? match = RegExp(
    r'\s' + RegExp.escape(name) + r'''\s*=\s*(["'])''',
    caseSensitive: false,
  ).firstMatch(tag);
  if (match == null) {
    return null;
  }
  final String quote = match.group(1) ?? '';
  if (quote.isEmpty) {
    return null;
  }
  int depth = 0;
  final StringBuffer value = StringBuffer();
  for (int index = match.end; index < tag.length; index++) {
    final String unit = tag[index];
    if (unit == '{') {
      depth += 1;
    } else if (unit == '}') {
      if (depth > 0) {
        depth -= 1;
      }
    } else if (unit == quote && depth == 0) {
      return value.toString();
    }
    value.write(unit);
  }

  return null;
}

/// The first `data-*` attribute with a value, upstream's last resort for lazy-loaded images.
String? _firstDataAttribute(String tag) {
  for (final RegExpMatch match in RegExp(
    r'\s(data-[^=\s>]+)\s*=',
    caseSensitive: false,
  ).allMatches(tag)) {
    final String? name = match.group(1);
    if (name == null) {
      continue;
    }
    final String? value = _attribute(tag, name);
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return null;
}

String _escapeAttribute(String value) =>
    value.replaceAll('&', '&amp;').replaceAll('"', '&quot;');

Map<String, Object?> _failure(String message) => <String, Object?>{
  jsHelperErrorKey: message,
};

String _requiredText(Object? value) {
  if (value is String) {
    return value;
  }
  if (value == null) {
    throw const FormatException('expected text');
  }

  return value.toString();
}
