import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/search_match_mode.dart';

/// How many merged books one search keeps (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 7).
///
/// Upstream's `MAX_RETAINED_SEARCH_RESULTS`: past this the merger evicts the least valuable rows
/// instead of growing the list without bound, and `hasMore` turns off.
const int maxRetainedSearchBooks = 1000;

/// The bucket a hit falls into; the order of the values **is** the display order
/// (ADR-0046 §决策 3).
enum SearchHitBucket {
  /// Name or author **equals** the keyword (kept in both modes).
  equal,

  /// The category contains the keyword (default mode only).
  tags,

  /// Name or author contains the keyword (default mode only).
  contains,

  /// Everything else the source returned (default mode only).
  other,
}

/// Which bucket [book] belongs in under [mode], or `null` when [mode] drops it.
///
/// The rules are upstream's `classifyBucket`, including the part that surprises: under
/// [SearchMatchMode.exact] the `tags` / `contains` / `other` buckets are **dropped**, so "exact"
/// means "name or author equals the keyword" and nothing else.
SearchHitBucket? searchBucketOf(
  Book book,
  String keyword,
  SearchMatchMode mode,
) {
  final String key = mergeKeyOf(keyword);
  if (key.isEmpty) {
    // 空关键词没有匹配语义：`''.contains('')` 会让一切落进某个桶，所以直接不算命中。
    // 聚合用例本来就会先拒绝空关键词，这里只是让分类函数自己也是安全的。
    return null;
  }
  final String name = mergeKeyOf(book.name);
  final String author = mergeKeyOf(book.author ?? '');
  if (name == key || (author.isNotEmpty && author == key)) {
    return SearchHitBucket.equal;
  }
  if (mode == SearchMatchMode.exact) {
    return null;
  }
  if (mergeKeyOf(book.kind ?? '').contains(key)) {
    return SearchHitBucket.tags;
  }
  if (name.contains(key) || (author.isNotEmpty && author.contains(key))) {
    return SearchHitBucket.contains;
  }

  return SearchHitBucket.other;
}

/// Merges the hits of many sources into one ordered, de-duplicated list
/// (`docs/dev/roadmap.md` 3.8, ADR-0046 §决策 3/4/7).
///
/// It is stateful on purpose: an aggregate search runs source by source and each result page adds
/// to the same list, so "what the user sees" is [books] after every [add]. The class owns no I/O and
/// no clock, which is what lets the bucket rules and the eviction order be tested directly.
final class SearchResultMerger {
  /// Creates a merger for [keyword] under [mode].
  SearchResultMerger({required this.keyword, required this.mode});

  /// The keyword every bucket decision is made against.
  final String keyword;

  /// The match mode the search was started with.
  final SearchMatchMode mode;

  final Map<SearchBookKey, SearchBook> _equal = <SearchBookKey, SearchBook>{};
  final Map<SearchBookKey, SearchBook> _tags = <SearchBookKey, SearchBook>{};
  final Map<SearchBookKey, SearchBook> _contains =
      <SearchBookKey, SearchBook>{};
  final Map<SearchBookKey, SearchBook> _other = <SearchBookKey, SearchBook>{};

  /// The merged rows as they should be shown, best bucket first, multi-source first inside a bucket.
  List<SearchBook> get books => <SearchBook>[
    ..._sorted(_equal),
    ..._sorted(_tags),
    ..._sorted(_contains),
    // 上游的 `other` 桶不按来源数排序，保持插入序；照抄而不是「顺手改好」（ADR-0046 §决策 3）。
    ..._other.values,
  ];

  /// How many rows are merged so far (before eviction).
  int get count =>
      _equal.length + _tags.length + _contains.length + _other.length;

  /// Whether the eviction bound has thrown rows away; `hasMore` uses it (ADR-0046 §决策 7).
  bool get resultLimitReached => _limitReached;
  bool _limitReached = false;

  /// Adds [hits] from [sourceUrl] and returns whether anything visible changed.
  ///
  /// A hit that is already known — same `(name, author)`, or the same `bookUrl` seen from another
  /// source — only gains [sourceUrl] in its `origins`, which is what the "N sources" marker on the
  /// row counts.
  bool add(List<Book> hits, {required String sourceUrl}) {
    var changed = false;
    for (final Book hit in hits) {
      final SearchHitBucket? bucket = searchBucketOf(hit, keyword, mode);
      if (bucket == null) {
        continue;
      }
      final SearchBook candidate = SearchBook.fromHit(
        hit,
        sourceUrl: sourceUrl,
      );
      final SearchBookKey key = searchBookKeyOf(candidate);
      final SearchBook? existing = _find(key);
      if (existing != null) {
        if (existing.origins.contains(sourceUrl)) {
          continue;
        }
        final SearchBook merged = existing.copyWith(
          origins: <String>[...existing.origins, sourceUrl],
        );
        _put(bucketOf(existing), key, merged);
        changed = true;

        continue;
      }
      _put(bucket, key, candidate);
      changed = true;
      _evict();
    }

    return changed;
  }

  /// The bucket [book] is filed under, or `other` when it is not filed yet.
  SearchHitBucket bucketOf(SearchBook book) =>
      _bucketOfKey(searchBookKeyOf(book));

  /// The bucket a key is filed under.
  SearchHitBucket _bucketOfKey(SearchBookKey key) {
    if (_equal.containsKey(key)) {
      return SearchHitBucket.equal;
    }
    if (_tags.containsKey(key)) {
      return SearchHitBucket.tags;
    }
    if (_contains.containsKey(key)) {
      return SearchHitBucket.contains;
    }

    return SearchHitBucket.other;
  }

  /// Files [book] under [bucket], replacing whatever was there for [key].
  void _put(SearchHitBucket bucket, SearchBookKey key, SearchBook book) {
    final Map<SearchBookKey, SearchBook> target = switch (bucket) {
      SearchHitBucket.equal => _equal,
      SearchHitBucket.tags => _tags,
      SearchHitBucket.contains => _contains,
      SearchHitBucket.other => _other,
    };
    // 同一个 (name, author) 换了桶（例如先被归到 contains，后来发现 kind 命中）：先从旧桶摘掉。
    for (final Map<SearchBookKey, SearchBook> bucketMap
        in <Map<SearchBookKey, SearchBook>>[_equal, _tags, _contains, _other]) {
      bucketMap.remove(key);
    }
    target[key] = book;
  }

  /// The row filed under [key] in any bucket, or `null`.
  SearchBook? _find(SearchBookKey key) =>
      _equal[key] ?? _tags[key] ?? _contains[key] ?? _other[key];

  /// [bucket]'s rows ordered by origin count descending, keeping insertion order for ties.
  List<SearchBook> _sorted(Map<SearchBookKey, SearchBook> bucket) {
    final List<SearchBook> rows = bucket.values.toList();
    // `List.sort` 在 Dart 里不保证稳定，所以用插入序做第二关键字。
    final Map<SearchBook, int> order = <SearchBook, int>{
      for (var index = 0; index < rows.length; index++) rows[index]: index,
    };
    rows.sort((SearchBook left, SearchBook right) {
      final int byOrigins = right.origins.length.compareTo(left.origins.length);

      return byOrigins != 0 ? byOrigins : order[left]!.compareTo(order[right]!);
    });

    return rows;
  }

  /// Drops the least valuable row once [maxRetainedSearchBooks] is exceeded.
  ///
  /// The order is upstream's `trimSearchBooks`: `other` → `tags` → the `contains` with the fewest
  /// origins → the `equal` with the fewest origins. Evicting an exact match is the last resort
  /// because it is the row the user asked for.
  void _evict() {
    while (count > maxRetainedSearchBooks) {
      _limitReached = true;
      final bool removed =
          _removeLast(_other) ||
          _removeLast(_tags) ||
          _removeFewestOrigins(_contains) ||
          _removeFewestOrigins(_equal);
      if (!removed) {
        return;
      }
    }
  }

  /// Removes the last (lowest priority) row of [bucket].
  bool _removeLast(Map<SearchBookKey, SearchBook> bucket) {
    if (bucket.isEmpty) {
      return false;
    }
    bucket.remove(bucket.keys.last);

    return true;
  }

  /// Removes the row of [bucket] with the fewest origins.
  bool _removeFewestOrigins(Map<SearchBookKey, SearchBook> bucket) {
    if (bucket.isEmpty) {
      return false;
    }
    SearchBookKey? lowest;
    for (final MapEntry<SearchBookKey, SearchBook> entry in bucket.entries) {
      if (lowest == null ||
          entry.value.origins.length < bucket[lowest]!.origins.length) {
        lowest = entry.key;
      }
    }
    bucket.remove(lowest);

    return true;
  }
}
