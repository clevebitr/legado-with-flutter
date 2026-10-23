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
  }) async {
    writes.add('$sourceId|$url');
    entries['$sourceId|$url'] = body;
  }
}
