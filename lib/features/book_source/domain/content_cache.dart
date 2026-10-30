/// How long one cached chapter body stays usable for a book **that is not on the shelf**.
///
/// Three days (ADR-0097 §决策 1): long enough that a book opened twice in a week costs one round of
/// requests, short enough that a source which fixed its chapter pages shows the fix. A book **on the
/// shelf** ignores this bound entirely — its bodies are kept until the user clears that book's cache.
const Duration chapterCacheTtl = Duration(days: 3);

/// Remembers one chapter body so a second visit costs no request.
///
/// The stored text is finished: paging is joined and `replaceRegex` is applied. Reads and
/// writes never throw, so a lost entry costs one request and never a chapter.
abstract interface class ContentCache {
  /// The stored body of [url] under [sourceId], or `null` when it is missing or expired.
  Future<String?> read({required String sourceId, required String url});

  /// Stores [body] for ([sourceId], [url]) with [chapterCacheTtl], or without an expiry when
  /// [persistent] is set (ADR-0097 §决策 1).
  ///
  /// [persistent] is for a book **on the shelf**: the body then lives until the user clears that
  /// book's cache, which is what «加入到书架就一直留着» means to the user.
  ///
  /// [bookUrl] scopes the entry but is not part of the key.
  Future<void> write({
    required String sourceId,
    required String url,
    required String body,
    String? bookUrl,
    bool persistent = false,
  });

  /// How many cached chapter bodies belong to one book.
  Future<int> countForBook({required String sourceId, required String bookUrl});

  /// Deletes one book's cached chapter bodies and answers how many went away.
  Future<int> clearForBook({required String sourceId, required String bookUrl});

  /// How many cached bodies belong to one book source (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
  Future<int> countForSource(String sourceId);

  /// Deletes one book source's cached bodies and answers how many went away.
  Future<int> clearForSource(String sourceId);

  /// How many entries the cache holds in total, chapters and charset probes alike.
  Future<int> countAll();

  /// Drops the entries whose TTL has passed and answers how many went away.
  Future<int> clearExpired();

  /// Deletes **every** cached entry.
  ///
  /// Used when the user's purge rules change: the stored bodies are finished text with the old
  /// rules already applied, so they are all stale at once (ADR-0070 增补 §7). It cannot be narrowed
  /// to the bodies alone — the key is a digest, so the shared TTL table cannot tell a chapter body
  /// from a charset probe without a new column — and re-probing a charset is cheap.
  Future<void> clearAll();
}
