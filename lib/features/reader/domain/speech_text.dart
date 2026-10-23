/// The longest text one TTS utterance may carry (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// Android's `TextToSpeech.getMaxSpeechInputLength()` is 4000 characters and some engines are
/// stricter; 800 keeps every chunk well below that while still being long enough that the engine's
/// prosody is not reset at every sentence.
const int maxSpeechChunkLength = 800;

/// Sentence boundaries a chunk prefers to end on, in the order they are considered.
const String _sentenceEndings = '。！？!?；;';

/// Softer boundaries, used when no sentence ending is close enough to the chunk limit.
const String _clauseEndings = '，,、：:';

/// One utterance together with the slice of the source text it was cut from
/// (`docs/dev/roadmap.md` §3.10, ADR-0062 §决策 5).
///
/// [start] / [end] are UTF-16 offsets into the string handed to [splitSpeechSegments], so a progress
/// report from the engine can be turned back into a range of what the reader displays. They
/// describe the **trimmed** text: the whitespace the split drops is not part of either range.
final class SpeechSegment {
  /// Creates a segment.
  const SpeechSegment({
    required this.text,
    required this.start,
    required this.end,
  });

  /// The text to speak.
  final String text;

  /// The offset of [text]'s first character in the source text.
  final int start;

  /// The offset just past [text]'s last character in the source text.
  final int end;

  /// Whether [offset] (a source-text offset) falls inside this segment.
  bool contains(int offset) => offset >= start && offset < end;
}

/// Splits [text] into utterance-sized chunks (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// Every line is treated as a paragraph: blank lines and leading indentation disappear, because a
/// TTS engine reading `\n    ` produces an audible pause that the reader did not intend. A chunk
/// ends at a sentence boundary when one exists in the second half of the window, otherwise at a
/// clause boundary, otherwise at the hard limit — never in the middle of a UTF-16 surrogate pair
/// (an emoji or a rare CJK character would otherwise become two replacement characters).
///
/// The result never contains an empty chunk, so `speak` is never called with nothing to say.
List<String> splitSpeechText(
  String text, {
  int maxLength = maxSpeechChunkLength,
}) => <String>[
  for (final SpeechSegment segment in splitSpeechSegments(
    text,
    maxLength: maxLength,
  ))
    segment.text,
];

/// [splitSpeechText] with the source range of every chunk kept (`ADR-0062 §决策 5`).
///
/// The offsets are what makes sentence-level highlighting possible without re-searching the text:
/// the engine reports progress **within one utterance**, and [SpeechSegment.start] turns it back
/// into an offset of the chapter body the reader rendered.
List<SpeechSegment> splitSpeechSegments(
  String text, {
  int maxLength = maxSpeechChunkLength,
}) {
  final List<SpeechSegment> segments = <SpeechSegment>[];
  var lineStart = 0;
  for (final String line in text.split('\n')) {
    final String paragraph = line.trim();
    // 每一行的缩进在切块时被 trim 掉，但偏移必须回到**原文**（渲染后的正文）里的位置。
    final int paragraphStart =
        lineStart + (line.length - line.trimLeft().length);
    var start = 0;
    while (start < paragraph.length) {
      final int end = _chunkEnd(paragraph, start, maxLength);
      final String raw = paragraph.substring(start, end);
      final int leading = raw.length - raw.trimLeft().length;
      final String chunk = raw.trim();
      if (chunk.isNotEmpty) {
        final int chunkStart = paragraphStart + start + leading;
        segments.add(
          SpeechSegment(
            text: chunk,
            start: chunkStart,
            end: chunkStart + chunk.length,
          ),
        );
      }
      start = end;
    }
    lineStart += line.length + 1;
  }

  return segments;
}

/// The sentence of [text] that contains [offset] (`ADR-0062 §决策 5`).
///
/// A sentence ends at one of [_sentenceEndings] or at a line break, and never crosses a paragraph:
/// the body the reader shows separates paragraphs with `\n`, so a highlight that ran across one
/// would cover two paragraphs at once. An [offset] past the end answers the last sentence… and an
/// empty text answers an empty segment, so the caller needs no guard.
SpeechSegment speechSentenceAt(String text, int offset) {
  if (text.isEmpty) {
    return const SpeechSegment(text: '', start: 0, end: 0);
  }
  final int position = offset.clamp(0, text.length - 1);
  var start = 0;
  for (var index = position - 1; index >= 0; index--) {
    if (_isBreak(text, index)) {
      start = index + 1;
      break;
    }
  }
  var end = text.length;
  for (var index = position; index < text.length; index++) {
    if (_isNewline(text[index])) {
      end = index;
      break;
    }
    if (_sentenceEndings.contains(text[index])) {
      end = index + 1;
      break;
    }
  }
  while (start < end && _isSpace(text[start])) {
    start++;
  }
  while (end > start && _isSpace(text[end - 1])) {
    end--;
  }

  return SpeechSegment(
    text: text.substring(start, end),
    start: start,
    end: end,
  );
}

/// Whether the character at [index] ends the sentence **before** it.
bool _isBreak(String text, int index) =>
    _sentenceEndings.contains(text[index]) || _isNewline(text[index]);

/// Whether [char] separates paragraphs in the rendered body.
bool _isNewline(String char) => char == '\n' || char == '\r';

/// Whether [char] is whitespace the highlight may drop at its edges.
///
/// It defers to Dart's own notion of whitespace, so the ideographic space the reader indents
/// paragraphs with (`readerBodyText`) is trimmed too — a highlight that began on the indent would
/// look like it started one character late.
bool _isSpace(String char) => char.trim().isEmpty;

/// The index just past the chunk that starts at [start].
int _chunkEnd(String text, int start, int maxLength) {
  final int limit = start + maxLength;
  if (limit >= text.length) {
    return text.length;
  }
  // 先找句末，再找子句：两者都只在窗口后半段里找，否则每句话都会被切成过短的块。
  final int sentence = _lastBoundary(text, start, limit, _sentenceEndings);
  if (sentence > 0) {
    return sentence;
  }
  final int clause = _lastBoundary(text, start, limit, _clauseEndings);
  if (clause > 0) {
    return clause;
  }

  return _avoidSplittingSurrogatePair(text, limit);
}

/// The index just past the last boundary character in `(start, limit]`, or `-1`.
///
/// The window only looks at the second half of the allowed length, so a chunk is at least half a
/// chunk long; a boundary before that is ignored in favour of the hard split.
int _lastBoundary(String text, int start, int limit, String endings) {
  final int floor = start + ((limit - start) ~/ 2);
  for (var index = limit - 1; index >= floor; index--) {
    if (endings.contains(text[index])) {
      return index + 1;
    }
  }

  return -1;
}

/// [index], moved one code unit forward when it would split a surrogate pair.
///
/// [index] is always inside [text]: the caller only asks after `start + maxLength < length`.
int _avoidSplittingSurrogatePair(String text, int index) {
  final int unit = text.codeUnitAt(index);
  final bool isLowSurrogate = unit >= 0xDC00 && unit <= 0xDFFF;

  return isLowSurrogate ? index + 1 : index;
}
