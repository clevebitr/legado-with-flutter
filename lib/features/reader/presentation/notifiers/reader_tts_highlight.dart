import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_tts_highlight.freezed.dart';
part 'reader_tts_highlight.g.dart';

/// The sentence the read-aloud engine is voicing right now
/// (`docs/dev/roadmap.md` §3.10, ADR-0057 §决策 5).
///
/// [chapterUrl] names the chapter the range belongs to, because the reader may have moved on while
/// the engine still finishes its queue: a highlight without the chapter would land on the wrong
/// text.
@freezed
abstract class ReaderTtsHighlight with _$ReaderTtsHighlight {
  /// Creates a highlight.
  const factory ReaderTtsHighlight({
    /// The chapter the range belongs to.
    required String chapterUrl,

    /// The offset of the first highlighted character in the rendered chapter body.
    required int start,

    /// The offset just past the last highlighted character.
    required int end,
  }) = _ReaderTtsHighlight;
}

/// Publishes what the reader should highlight while reading aloud.
///
/// It is a **separate provider on purpose**: the reader body would otherwise have to build
/// the read-aloud notifier (and with it the system engine) just to ask whether anything is being
/// spoken. Watched without a value it costs one nullable read; that notifier is the only writer.
@Riverpod(keepAlive: true)
class ReaderTtsHighlighter extends _$ReaderTtsHighlighter {
  @override
  ReaderTtsHighlight? build() => null;

  /// Announces `[start, end)` of [chapterUrl].
  void show({
    required String chapterUrl,
    required int start,
    required int end,
  }) {
    if (start >= end) {
      clear();

      return;
    }
    state = ReaderTtsHighlight(chapterUrl: chapterUrl, start: start, end: end);
  }

  /// Removes the highlight.
  void clear() => state = null;
}
