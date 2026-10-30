/// The persisted side of a book source's **login info** (`source.putLoginInfo` /
/// `source.removeLoginInfo`, M25/S5a).
///
/// Upstream keeps it in `CacheManager` under `userInfo_<bookSourceUrl>`, AES-encrypted with the
/// install id (`BaseSource.kt:172-243`); this repository keeps the same map in the
/// `book_sources.login_info` column, which is where the login form reads its values from
/// (ADR-0072 §决策 3).
///
/// Only the write half is here: a job still receives its values as a **snapshot** (`JsJob.loginInfo`),
/// so there is nothing to read back mid-script — the sandbox's own slot answers reads inside the job
/// and the bridge persists whatever the rule wrote when the job ends.
abstract interface class SourceLoginInfoWriter {
  /// Stores [info] for [sourceUrl]; `null` clears it.
  ///
  /// The unit is the source **URL**, not the row, the same as the login header: upstream's cache key
  /// is the URL, and two imports of the same URL are one source to upstream.
  Future<void> write(String sourceUrl, Map<String, String>? info);
}

/// A writer that keeps the values in memory, for tests and for a build without storage.
final class InMemorySourceLoginInfoWriter implements SourceLoginInfoWriter {
  /// Creates an empty writer.
  InMemorySourceLoginInfoWriter();

  /// Every write, by source URL; `null` means the login info was cleared.
  final Map<String, Map<String, String>?> written =
      <String, Map<String, String>?>{};

  @override
  Future<void> write(String sourceUrl, Map<String, String>? info) async {
    written[sourceUrl] = info == null
        ? null
        : Map<String, String>.unmodifiable(info);
  }
}
