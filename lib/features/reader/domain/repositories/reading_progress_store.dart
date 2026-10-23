import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';

/// Remembers where the reader stopped, and hands it back on the next visit
/// (`docs/dev/roadmap.md` 5.3, ADR-0044 §决策 2).
///
/// It is **read + write** on purpose. ADR-0041 §决策 2 listed only a writer, but restoring a
/// position has to read one, and the alternative — passing it in through the route — would push
/// the progress semantics into every caller.
///
/// The table belongs to `bookshelf` (ADR-0041 §决策 4); the reader only ever sees this port, so the
/// two features stay independent (C-ARCH-2).
abstract interface class ReadingProgressStore {
  /// The stored position for `(sourceUrl, bookUrl)`, or `null` when the book was never opened.
  Future<ReadingPosition?> read({
    required String sourceUrl,
    required String bookUrl,
  });

  /// Stores [position] for `(sourceUrl, bookUrl)`, replacing any previous one.
  Future<void> write({
    required String sourceUrl,
    required String bookUrl,
    required ReadingPosition position,
  });
}

/// The answer when nothing bound [ReadingProgressStore].
///
/// Reading answers `null` (the reader starts at the first chapter) and writing does nothing plus
/// logs one warning: a forgotten binding must not stop the user from reading (ADR-0041 §决策 2).
final class UnboundReadingProgressStore implements ReadingProgressStore {
  /// Creates the unbound port; `_logger` receives the warning.
  const UnboundReadingProgressStore({required this._logger});

  final AppLogger _logger;

  @override
  Future<ReadingPosition?> read({
    required String sourceUrl,
    required String bookUrl,
  }) async {
    _logger.warning(
      'No ReadingProgressStore is bound: the reader restarts at the first chapter.',
    );

    return null;
  }

  @override
  Future<void> write({
    required String sourceUrl,
    required String bookUrl,
    required ReadingPosition position,
  }) async {
    _logger.warning(
      'No ReadingProgressStore is bound: the reading position was not saved.',
    );
  }
}
