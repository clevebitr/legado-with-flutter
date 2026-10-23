import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';

/// Reads the audio addresses of one chapter for the player (`docs/dev/roadmap.md` §3.10).
///
/// The reader declares the port and the composition root binds it to `book_source`'s
/// `FetchAudioTracks` (ADR-0041 §决策 2), so the reader never imports that feature (C-ARCH-2).
/// The source URL travels with the request because the adapter resolves the source from it — a
/// book opened from the shelf may belong to a source that is not the selected one.
abstract interface class AudioTrackProvider {
  /// Reads the tracks of [chapterUrl] in [sourceUrl].
  ///
  /// [bookName] / [chapterTitle] answer `java.get('bookName')` / `java.get('title')` for the
  /// source's rules (`docs/dev/book-source.md` §6, ADR-0049).
  Future<ParseResult<List<ReaderAudioTrack>>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
    String bookUrl = '',
    String tocUrl = '',
  });
}

/// The answer when nothing bound [AudioTrackProvider]: an observable failure, never a throw.
///
/// It is the provider's default, so a forgotten binding shows the retryable failure state plus
/// one warning instead of crashing the player (ADR-0041 §决策 2).
final class UnboundAudioTrackProvider implements AudioTrackProvider {
  /// Creates the unbound port; [_logger] receives the warning.
  const UnboundAudioTrackProvider({required this._logger});

  final AppLogger _logger;

  @override
  Future<ParseResult<List<ReaderAudioTrack>>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
    String bookUrl = '',
    String tocUrl = '',
  }) async {
    _logger.warning(
      'No AudioTrackProvider is bound: the reader cannot play an audio chapter.',
    );

    return const ParseFailure<List<ReaderAudioTrack>>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'reader.audioTracks',
    );
  }
}
