import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_session.freezed.dart';

/// Sessions shorter than this are not recorded (`docs/dev/roadmap.md` M19, ADR-0066 §决策 4).
///
/// A mis-tap that opens the reader, a failed source switch that reopens it, a glance at the
/// chapter title — none of that is "reading", and a record page full of ten-second rows is noise.
/// The threshold is a domain constant rather than a user-visible string, so it stays out of the ARB.
const int minimumRecordedSeconds = 60;

/// One reader session between two clock readings (`docs/dev/roadmap.md` M19).
///
/// It is the pure part of recording: the page says when the reader opened and when it closed, and
/// this value object decides the duration and whether the session is worth a row. Keeping it here
/// (instead of in `ReaderPage.dispose`) is what makes the rule testable without a widget.
@freezed
abstract class ReadingSession with _$ReadingSession {
  /// Creates a session bounded by [startedAt] and [endedAt].
  const factory ReadingSession({
    /// `bookSourceUrl` of the source the book came from.
    required String sourceUrl,

    /// The book's detail page URL.
    required String bookUrl,

    /// The book title as the reader knew it.
    required String bookName,

    /// The chapter the session ended on, when the list had loaded.
    String? chapterUrl,

    /// Its title, when known.
    String? chapterName,
    required DateTime startedAt,
    required DateTime endedAt,
  }) = _ReadingSession;

  const ReadingSession._();

  /// Wall-clock length of the session, never negative.
  ///
  /// A clock that jumped backwards (an NTP correction, a user changing the system time) would
  /// otherwise produce a negative duration and a row that sorts before its own start.
  int get durationSeconds {
    final int seconds = endedAt.difference(startedAt).inSeconds;

    return seconds < 0 ? 0 : seconds;
  }

  /// Whether this session deserves a row: at least [minimumRecordedSeconds] of reading.
  bool get shouldRecord => durationSeconds >= minimumRecordedSeconds;
}
