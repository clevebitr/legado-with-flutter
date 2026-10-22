import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';

/// Tells the reader whether a source serves text or images
/// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053 §决策 1).
///
/// The reader must not import `book_source` (C-ARCH-2), and the source type is the one fact that
/// decides **which** reader page to build — so it travels through a port the composition root binds
/// to the stored source's `bookSourceType`.
abstract interface class ReaderSourceKindProvider {
  /// Answers the kind of [sourceUrl].
  Future<ParseResult<ReaderSourceKind>> of(String sourceUrl);
}

/// The answer when nothing bound [ReaderSourceKindProvider]: **text**, with a warning.
///
/// Unlike the other unbound ports this one does not fail: a reader that cannot answer "which kind"
/// must still open *something*, and the text reader is the long-standing behaviour of every source
/// this build knew before M16. A failure here would turn a missing binding into an unreadable book.
final class UnboundReaderSourceKindProvider
    implements ReaderSourceKindProvider {
  /// Creates the unbound port; `_logger` receives the warning.
  const UnboundReaderSourceKindProvider({required this._logger});

  final AppLogger _logger;

  @override
  Future<ParseResult<ReaderSourceKind>> of(String sourceUrl) async {
    _logger.warning(
      'No ReaderSourceKindProvider is bound: opening every book as text.',
    );

    return const ParseSuccess<ReaderSourceKind>(ReaderSourceKind.text);
  }
}
