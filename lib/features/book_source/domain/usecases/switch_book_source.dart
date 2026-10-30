import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/change_source_search.dart';

/// The candidate and chapter the change-source page answers (ADR-0091 §决策 1).
///
/// It carries the chapter list the page already read, so the caller does not fetch the same table
/// of contents twice just to learn which chapter was picked.
final class ChangeSourceSelection {
  /// Creates a selection.
  const ChangeSourceSelection({
    required this.candidate,
    required this.chapters,
    required this.chapterIndex,
  });

  /// The source the user picked.
  final ChangeSourceCandidate candidate;

  /// That source's chapters, as the page read them.
  final List<Chapter> chapters;

  /// The chapter the user aligned to.
  final int chapterIndex;

  /// The chapter at [chapterIndex].
  Chapter get chapter => chapters[chapterIndex];
}

/// The outcome of switching to another source.
final class SourceSwitchResult {
  /// Creates the result.
  const SourceSwitchResult({
    required this.sourceUrl,
    required this.sourceName,
    required this.bookUrl,
    required this.bookName,
    required this.tocUrl,
    required this.chapterUrl,
    required this.chapterName,
    required this.chapterIndex,
    required this.author,
    required this.coverUrl,
    required this.lastChapter,
  });

  /// The new source's URL.
  final String sourceUrl;

  /// The new source's display name.
  final String sourceName;

  /// The book's URL inside the new source — the new half of its shelf identity.
  final String bookUrl;

  /// The book's title as the new source spells it.
  final String bookName;

  /// The new table-of-contents URL.
  final String tocUrl;

  /// The chapter the reader should open: the one the user aligned to.
  final String chapterUrl;

  /// The aligned chapter's title.
  final String chapterName;

  /// The aligned chapter's index in the new book.
  final int chapterIndex;

  /// The author as the new source spells it.
  final String? author;

  /// The cover as the new source spells it.
  final String? coverUrl;

  /// The latest chapter as the new source spells it.
  final String? lastChapter;
}

/// Turns "this candidate, that chapter" into the new identity (ADR-0091 §决策 1).
///
/// The search itself is [ChangeSourceSearch] and the page that collects the choice is
/// `ChangeSourcePage`; this class is the last, pure step: no I/O, no storage, no UI. Whether the
/// switch is applied to the shelf (and which source becomes the selected one) stays the caller's
/// job, because only it knows which side of the app it is on (ADR-0051 §决策 3).
final class SwitchBookSource {
  /// Creates the use case.
  const SwitchBookSource();

  /// The switch result for the chapter the user picked on the change-source page.
  SourceSwitchResult withChapters({
    required BookSource target,
    required ChangeSourceSelection selection,
  }) {
    final ChangeSourceCandidate candidate = selection.candidate;
    final Chapter chapter = selection.chapter;

    return SourceSwitchResult(
      sourceUrl: target.url,
      sourceName: target.name,
      bookUrl: candidate.book.url,
      bookName: candidate.book.name,
      tocUrl: candidate.tocUrl ?? candidate.book.url,
      chapterUrl: chapter.url,
      chapterName: chapter.name,
      chapterIndex: selection.chapterIndex,
      author: candidate.book.author,
      coverUrl: candidate.book.coverUrl,
      lastChapter: candidate.book.lastChapter,
    );
  }

  /// The index of the chapter matching [name], or [fallbackIndex] clamped into [chapters].
  ///
  /// Alignment tries an equal name, then a contained one, then the same index — the three-step
  /// fallback of ADR-0051 §决策 3. The page uses it to pre-select the chapter it will propose.
  int alignChapterIndex(
    List<Chapter> chapters,
    String name, {
    required int fallbackIndex,
  }) {
    final String wanted = name.trim().toLowerCase();
    if (wanted.isNotEmpty) {
      for (var index = 0; index < chapters.length; index++) {
        if (chapters[index].name.trim().toLowerCase() == wanted) {
          return index;
        }
      }
      for (var index = 0; index < chapters.length; index++) {
        final String candidate = chapters[index].name.trim().toLowerCase();
        if (candidate.contains(wanted) || wanted.contains(candidate)) {
          return index;
        }
      }
    }

    return fallbackIndex.clamp(0, chapters.length - 1);
  }
}
