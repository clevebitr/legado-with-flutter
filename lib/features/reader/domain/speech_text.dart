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
}) {
  final List<String> chunks = <String>[];
  for (final String line in text.split('\n')) {
    final String paragraph = line.trim();
    var start = 0;
    while (start < paragraph.length) {
      final int end = _chunkEnd(paragraph, start, maxLength);
      final String chunk = paragraph.substring(start, end).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      start = end;
    }
  }

  return chunks;
}

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
