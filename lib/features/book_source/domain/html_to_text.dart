/// Turns the HTML a `content` rule can produce (`@html`, `@all`, a script's `outerHTML`) into the
/// **plain text** the reader renders.
///
/// Upstream keeps the chapter body as HTML and renders it with its own rich-text view; this
/// repository's reader is plain text (`readerBodyText` splits on `\n`), so the content boundary is
/// where markup has to go away — otherwise 83 of the 249 `content` rules in the 2026-10-27 corpus
/// (everything ending in `@html` / `@all`) would show raw tags (`book-source.md` §4.3).
///
/// It is a **scanner, not a DOM**: the body was already parsed once to run the rule, and parsing
/// it again per chapter (or per page of a paged chapter) only to throw the tree away is the kind of
/// work M26 is trying to remove. Text without `<` or `&` returns unchanged, so a rule that already
/// yields text (`@text`, `@textNodes`) pays nothing.
library;

/// Tags whose boundaries are paragraph breaks for a text reader.
///
/// Both the opening and the closing tag contribute one, and [htmlToText] collapses the runs, so
/// `<p>a</p><p>b</p>` and `<p>a<p>b` both become two lines.
const Set<String> _blockTags = <String>{
  'address',
  'article',
  'aside',
  'blockquote',
  'br',
  'dd',
  'div',
  'dl',
  'dt',
  'figcaption',
  'figure',
  'footer',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'tbody',
  'td',
  'tfoot',
  'th',
  'thead',
  'tr',
  'ul',
};

/// The named entities worth decoding.
///
/// HTML allows hundreds; these are the ones book pages actually use. An unknown entity is left
/// as written (it is part of the author's text, not markup), which is also what a browser shows
/// for anything it does not know.
const Map<String, String> _entities = <String, String>{
  'amp': '&',
  'apos': "'",
  'bull': '·',
  'copy': '©',
  'deg': '°',
  'divide': '÷',
  'emdash': '—',
  'hellip': '…',
  'ldquo': '“',
  'lsquo': '‘',
  'lt': '<',
  'mdash': '—',
  'middot': '·',
  'nbsp': ' ',
  'ndash': '–',
  'quot': '"',
  'rdquo': '”',
  'reg': '®',
  'rsquo': '’',
  'sup2': '²',
  'sup3': '³',
  'times': '×',
  'gt': '>',
  'zwsp': '\u200b',
};

/// [html] as plain text: block boundaries become paragraph breaks, markup and scripts disappear,
/// entities are decoded and blank lines are collapsed.
String htmlToText(String html) {
  if (html.isEmpty || (!html.contains('<') && !html.contains('&'))) {
    return html;
  }

  final StringBuffer buffer = StringBuffer();
  final String lower = html.toLowerCase();
  var index = 0;
  while (index < html.length) {
    final String char = html[index];
    if (char == '<' && _isTagStart(html, index)) {
      if (lower.startsWith('<!--', index)) {
        final int commentEnd = html.indexOf('-->', index + 4);
        index = commentEnd < 0 ? html.length : commentEnd + 3;

        continue;
      }
      final int tagEnd = _tagEnd(html, index);
      if (tagEnd < 0) {
        // 一个没闭合的 `<`：按文本留下，别把后面整段吞掉。
        buffer.write(char);
        index++;

        continue;
      }
      final String tag = html.substring(index + 1, tagEnd).trim();
      final String name = _tagNameOf(tag);
      final bool closing = tag.startsWith('/');
      if (!closing && (name == 'script' || name == 'style')) {
        // 脚本/样式的**内容**是代码，不是正文：跳到闭合标签之后。
        final int closingStart = lower.indexOf('</$name', tagEnd);
        index = closingStart < 0 ? html.length : closingStart;

        continue;
      }
      if (_blockTags.contains(name)) {
        buffer.write('\n');
      }
      index = tagEnd + 1;

      continue;
    }
    if (char == '&') {
      final _EntityMatch? entity = _entityAt(html, index);
      if (entity != null) {
        buffer.write(entity.text);
        index += entity.length;

        continue;
      }
    }
    buffer.write(char);
    index++;
  }

  return _normalize(buffer.toString());
}

/// Whether the `<` at [index] opens a tag rather than being a literal less-than sign.
///
/// `1 < 2` is text: after `<` a tag has a letter, or `/` / `!` / `?` (closing tag, comment,
/// doctype / processing instruction).
bool _isTagStart(String html, int index) {
  if (index + 1 >= html.length) {
    return false;
  }
  final String next = html[index + 1];
  final int code = next.codeUnitAt(0);
  if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)) {
    return true;
  }
  if (next == '!' || next == '?') {
    return true;
  }

  return next == '/' && index + 2 < html.length;
}

/// The index of the `>` closing the tag that starts at [start], skipping quoted attributes
/// (`<p title="a>b">`), or `-1` when the tag never closes.
int _tagEnd(String html, int start) {
  String? quote;
  for (var index = start + 1; index < html.length; index++) {
    final String char = html[index];
    if (quote != null) {
      if (char == quote) {
        quote = null;
      }

      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
    } else if (char == '>') {
      return index;
    }
  }

  return -1;
}

/// The lower-cased element name of [tag] (the text between `<` and `>`), without `/` or attributes.
String _tagNameOf(String tag) {
  final String withoutSlash = tag.startsWith('/') ? tag.substring(1) : tag;
  var end = 0;
  while (end < withoutSlash.length) {
    final String char = withoutSlash[end];
    if (char == ' ' ||
        char == '\t' ||
        char == '\n' ||
        char == '\r' ||
        char == '/' ||
        char == '>') {
      break;
    }
    end++;
  }

  return withoutSlash.substring(0, end).toLowerCase();
}

final class _EntityMatch {
  const _EntityMatch(this.text, this.length);

  /// The decoded text.
  final String text;

  /// How many source characters the entity spans.
  final int length;
}

/// Decodes the entity starting at [start] (which is `&`), or `null` when there is none.
///
/// An entity nobody knows is left **as written**: it is then part of the author's text, not
/// markup, which is also what a browser shows.
_EntityMatch? _entityAt(String source, int start) {
  final int semicolon = source.indexOf(';', start + 1);
  if (semicolon < 0 || semicolon - start > 10) {
    return null;
  }
  final String body = source.substring(start + 1, semicolon);
  if (body.isEmpty) {
    return null;
  }
  final String header = source.substring(start, semicolon + 1);
  final int length = header.length;
  if (body.startsWith('#')) {
    final bool hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
    final int? code = int.tryParse(
      hex ? body.substring(2) : body.substring(1),
      radix: hex ? 16 : 10,
    );
    if (code == null || code <= 0 || code > 0x10FFFF) {
      return _EntityMatch(header, length);
    }

    return _EntityMatch(String.fromCharCode(code), length);
  }
  final String? decoded = _entities[body.toLowerCase()];

  return decoded == null
      ? _EntityMatch(header, length)
      : _EntityMatch(decoded, length);
}

/// Collapses indentation, drops markup-only blank lines and keeps at most one blank line between
/// paragraphs.
String _normalize(String text) {
  final List<String> lines = <String>[
    for (final String line in text.split('\n'))
      if (line.replaceAll('\t', ' ').trim().isNotEmpty) line.trim(),
  ];
  final StringBuffer buffer = StringBuffer();
  for (var index = 0; index < lines.length; index++) {
    if (index > 0) {
      buffer.write('\n');
    }
    buffer.write(lines[index]);
  }

  return buffer.toString();
}
