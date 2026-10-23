/// How long one chapter body stays usable (`docs/dev/book-source.md` §5, `docs/dev/roadmap.md` 5.2).
///
/// A body changes only when the site rewrites the page, so the bound is about **staleness**, not
/// about size: half a day covers a reading session and coming back to the same chapter the same
/// day, while a corrected chapter reappears within a day. The number is defined once, here;
/// `CacheDao` owns the expiry column, and `docs/dev/roadmap.md` 5.7 is what will call `deleteExpired` for the
/// physical cleanup (until then an expired entry is simply a miss).
const Duration chapterCacheTtl = Duration(hours: 12);

/// Remembers one chapter **body** so a second visit costs no request (`docs/dev/roadmap.md` 5.2, C-NET-6).
///
/// The key is the book source id plus the chapter URL, so two sources that publish the same URL
/// never share a body, and what is stored is the **finished** text: paging is already joined and
/// `replaceRegex` is already applied (`FetchContent`), which is why a hit can skip the whole
/// engine.
///
/// **The port is total**, exactly like `CharsetCache`: [read] answers `null` for a miss *and* for a
/// failure, [write] never throws, and the adapter absorbs the database's failure surface
/// (`CacheDaoContentCache` via `absorbCacheFailure`, ADR-0033 §决策 1). A lost entry therefore
/// costs one request and never a chapter (C-ERR-1) — which is what lets the use case call this
/// without an exception boundary of its own.
abstract interface class ContentCache {
  /// The stored body of [url] under [sourceId], or `null` when it is missing or expired.
  ///
  /// [sourceId] is the book source URL.
  Future<String?> read({required String sourceId, required String url});

  /// Stores [body] for ([sourceId], [url]) with [chapterCacheTtl].
  Future<void> write({
    required String sourceId,
    required String url,
    required String body,
  });
}
