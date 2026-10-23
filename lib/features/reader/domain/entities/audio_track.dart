import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_track.freezed.dart';

/// One playable address of an audio chapter, as the reader sees it
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 2).
///
/// It is the reader's own value object: the parsed `AudioTrack` belongs to `book_source`, and
/// crossing that boundary is what `docs/dev/architecture.md` §2 forbids (C-ARCH-2). The
/// composition root maps one to the other, exactly like `Chapter` → `ReadingChapter`.
@freezed
abstract class ReaderAudioTrack with _$ReaderAudioTrack {
  /// Creates one audio track.
  const factory ReaderAudioTrack({
    /// The absolute address the player loads.
    required String url,

    /// Request headers the source declared; empty when it declared none.
    @Default(<String, String>{}) Map<String, String> headers,
  }) = _ReaderAudioTrack;
}
