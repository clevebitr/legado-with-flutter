import 'package:flutter_reader/features/book_source/domain/content_cache.dart';

/// In-memory [ContentCache] double: records what the use case asked for
/// (`docs/dev/testing.md` §4).
///
/// The port is total, so there is no failure mode to fake here: an adapter is what absorbs a broken
/// database, and that is `CacheDaoContentCache`'s own test.
final class FakeContentCache implements ContentCache {
  /// Stored bodies, keyed by `sourceId|url`.
  final Map<String, String> entries = <String, String>{};

  /// The keys read, in order.
  final List<String> reads = <String>[];

  /// The keys written, in order.
  final List<String> writes = <String>[];

  /// Per-source counts the page reads (`countForSource`).
  final Map<String, int> sourceCounts = <String, int>{};

  /// When set, [countForSource] throws it (a broken database).
  Exception? sourceCountFailure;

  /// What [countAll] answers.
  int totalCount = 0;

  /// The `bookUrl` of every write, in order (`null` for an unscoped write).
  final List<String?> writeScopes = <String?>[];

  /// The per-book counts/clears asked for, in order.
  final List<String> scopeCalls = <String>[];

  @override
  Future<String?> read({required String sourceId, required String url}) async {
    reads.add('$sourceId|$url');

    return entries['$sourceId|$url'];
  }

  @override
  Future<void> write({
    required String sourceId,
    required String url,
    required String body,
    String? bookUrl,
  }) async {
    writes.add('$sourceId|$url');
    writeScopes.add(bookUrl);
    entries['$sourceId|$url'] = body;
  }

  @override
  Future<int> countForBook({
    required String sourceId,
    required String bookUrl,
  }) async {
    scopeCalls.add('count|$sourceId|$bookUrl');

    return entries.length;
  }

  @override
  Future<int> clearForBook({
    required String sourceId,
    required String bookUrl,
  }) async {
    scopeCalls.add('clear|$sourceId|$bookUrl');
    final int removed = entries.length;
    entries.clear();

    return removed;
  }

  @override
  Future<int> countForSource(String sourceId) async {
    scopeCalls.add('sourceCount|$sourceId');
    final Exception? failure = sourceCountFailure;
    if (failure != null) {
      throw failure;
    }

    return sourceCounts[sourceId] ?? 0;
  }

  @override
  Future<int> clearForSource(String sourceId) async {
    scopeCalls.add('sourceClear|$sourceId');
    final int removed = entries.length;
    entries.clear();

    return removed;
  }

  @override
  Future<int> countAll() async => totalCount;

  @override
  Future<int> clearExpired() async {
    scopeCalls.add('clearExpired');
    final int removed = entries.length;
    entries.clear();

    return removed;
  }

  @override
  Future<void> clearAll() async {
    scopeCalls.add('clearAll');
    entries.clear();
  }
}
