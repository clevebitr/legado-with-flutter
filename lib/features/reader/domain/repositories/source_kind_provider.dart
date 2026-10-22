import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_media_kind.dart';

/// Tells the reader which body to build for a book source
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 1).
///
/// `book_source` owns `BookSourceType`, so the reader cannot look it up itself (C-ARCH-2). The
/// composition root binds this port to the source repository; a source that no longer exists
/// answers [ReaderMediaKind.text], because the chapter list will then fail with
/// `invalidBookSource` and the reader shows a retryable failure either way.
abstract interface class SourceKindProvider {
  /// What [sourceUrl] serves.
  Future<ReaderMediaKind> kindOf({required String sourceUrl});
}

/// The answer when nothing bound [SourceKindProvider]: text, plus one warning.
///
/// Text is the safe default — an unbound port must not make every book look like an audio book
/// and hide the chapter body (ADR-0041 §决策 2).
final class UnboundSourceKindProvider implements SourceKindProvider {
  /// Creates the unbound port; [_logger] receives the warning.
  const UnboundSourceKindProvider({required this._logger});

  final AppLogger _logger;

  @override
  Future<ReaderMediaKind> kindOf({required String sourceUrl}) async {
    _logger.warning(
      'No SourceKindProvider is bound: the reader assumes text content.',
    );

    return ReaderMediaKind.text;
  }
}
