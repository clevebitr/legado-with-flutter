/// How long one cached chapter body stays usable.
///
/// The bound is about staleness, not size: half a day covers a reading session.
const Duration chapterCacheTtl = Duration(hours: 12);

/// Remembers one chapter body so a second visit costs no request.
///
/// The stored text is finished: paging is joined and `replaceRegex` is applied. Reads and
/// writes never throw, so a lost entry costs one request and never a chapter.
abstract interface class ContentCache {
  /// The stored body of [url] under [sourceId], or `null` when it is missing or expired.
  Future<String?> read({required String sourceId, required String url});

  /// Stores [body] for ([sourceId], [url]) with [chapterCacheTtl].
  ///
  /// [bookUrl] scopes the entry but is not part of the key.
  Future<void> write({
    required String sourceId,
    required String url,
    required String body,
    String? bookUrl,
  });

  /// How many cached chapter bodies belong to one book.
  Future<int> countForBook({required String sourceId, required String bookUrl});

  /// Deletes one book's cached chapter bodies and answers how many went away.
  Future<int> clearForBook({required String sourceId, required String bookUrl});

  /// Deletes **every** cached entry.
  ///
  /// Used when the user's purge rules change: the stored bodies are finished text with the old
  /// rules already applied, so they are all stale at once (ADR-0070 增补 §7). It cannot be narrowed
  /// to the bodies alone — the key is a digest, so the shared TTL table cannot tell a chapter body
  /// from a charset probe without a new column — and re-probing a charset is cheap.
  Future<void> clearAll();
}
