// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_position.freezed.dart';

/// Where the reader stopped in one book (`docs/dev/roadmap.md` 5.3).
///
/// It is the reader's own value object: the table belongs to `bookshelf` and its
/// `ReadingProgressPosition` carries a timestamp the reader does not need, so the two types are
/// mapped at the composition root like every other cross-feature value (ADR-0041 §决策 3).
///
/// [charOffset] is an **estimate**, not an anchor: it is the scroll (or page) fraction times the
/// body length, because a character-exact anchor would have to be versioned inside the chapter
/// text (ADR-0044 §决策 4).
@freezed
abstract class ReadingPosition with _$ReadingPosition {
  /// Creates a reading position.
  const factory ReadingPosition({
    /// The chapter the reader was on.
    required String chapterUrl,

    /// Its title, kept so a list can show «reading: chapter» without fetching anything.
    String? chapterName,

    /// The estimated character offset inside that chapter's body.
    @Default(0) int charOffset,
  }) = _ReadingPosition;
}
