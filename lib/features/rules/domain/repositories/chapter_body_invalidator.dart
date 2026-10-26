import 'package:flutter_reader/core/logging/app_logger.dart';

/// Lets the rules feature retire chapter bodies that a purge-rule edit made stale
/// (`docs/dev/roadmap.md` M20, ADR-0070 增补 §7).
///
/// A cached chapter body is **finished** text: paging joined, `replaceRegex` and the purge rules
/// already applied. Purging is applied before the write, so editing a purge rule would otherwise
/// keep serving the old text until the 12-hour cache expires. The rules feature therefore asks the
/// chapter cache to drop its bodies after any successful purge-rule write.
///
/// The port lives here (the rules feature is the caller) and is bound at the composition root to
/// `book_source`'s `ContentCache`, so neither feature imports the other (C-ARCH-2, ADR-0041 §决策 2).
abstract interface class ChapterBodyInvalidator {
  /// Drops every cached chapter body; other cache entries (book info, table of contents) are kept.
  Future<void> invalidateChapterBodies();
}

/// The invalidator used when a binding is missing: nothing is dropped, and a warning says so.
///
/// Dropping nothing is the safe degradation: stale text is a smaller failure than a chapter that
/// cannot be read at all, and the next request still re-reads the chapter once the cache expires.
final class UnboundChapterBodyInvalidator implements ChapterBodyInvalidator {
  /// Creates the invalidator; a bound logger reports the missing binding.
  const UnboundChapterBodyInvalidator({this.logger});

  /// Where the warning goes, when anyone is listening.
  final AppLogger? logger;

  @override
  Future<void> invalidateChapterBodies() async {
    logger?.warning(
      'Chapter-body invalidation is unbound: cached bodies stay stale',
    );
  }
}
