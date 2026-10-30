import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/search_match_mode.dart';

/// How many merged books one search keeps before evicting the least valuable rows.
const int maxRetainedSearchBooks = 1000;

/// The bucket a hit falls into; the order of the values is the display order.
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
/// Under [SearchMatchMode.exact] only an equal name or author survives.
SearchHitBucket? searchBucketOf(
  Book book,
  String keyword,
  SearchMatchMode mode,
) {
  final String key = mergeKeyOf(keyword);
  if (key.isEmpty) {
    // 空关键词没有匹配语义，直接不算命中。
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

/// Merges the hits of many sources into one ordered, de-duplicated list.
///
/// It is stateful on purpose: each result page adds to the same list, and [books] is what
/// the user sees. The class owns no I/O and no clock.
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

  /// The merged rows as they should be shown, best bucket first.
  List<SearchBook> get books => <SearchBook>[
    ..._sorted(_equal),
    ..._sorted(_tags),
    ..._sorted(_contains),
    // 上游的 `other` 桶不按来源数排序，保持插入序。
    ..._other.values,
  ];

  /// How many rows are merged so far (before eviction).
  int get count =>
      _equal.length + _tags.length + _contains.length + _other.length;

  /// Whether the eviction bound has thrown rows away.
  bool get resultLimitReached => _limitReached;
  bool _limitReached = false;

  /// Adds [hits] from [sourceUrl] and answers whether anything visible changed.
  ///
  /// A hit already known — same `(name, author)` or same `bookUrl` — only gains [sourceUrl]
  /// in its `origins`, which is what the "N sources" marker counts.
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
        // 每源一份快照：M31 的「选择来源」只读它，不重新发请求（ADR-0091 §决策 6）。
        final SearchBook merged = existing.copyWith(
          origins: <String>[...existing.origins, sourceUrl],
          hits: <OriginHit>[...existing.hits, ...candidate.hits],
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
    // 同一个 (name, author) 可能换桶：先从旧桶摘掉。
    for (final Map<SearchBookKey, SearchBook> bucketMap
        in <Map<SearchBookKey, SearchBook>>[_equal, _tags, _contains, _other]) {
      bucketMap.remove(key);
    }
    target[key] = book;
  }

  SearchBook? _find(SearchBookKey key) =>
      _equal[key] ?? _tags[key] ?? _contains[key] ?? _other[key];

  /// [bucket]'s rows ordered by origin count descending, insertion order for ties.
  List<SearchBook> _sorted(Map<SearchBookKey, SearchBook> bucket) {
    final List<SearchBook> rows = bucket.values.toList();
    // `List.sort` 不保证稳定，所以用插入序做第二关键字。
    final Map<SearchBook, int> order = <SearchBook, int>{
      for (var index = 0; index < rows.length; index++) rows[index]: index,
    };
    rows.sort((SearchBook left, SearchBook right) {
      final int byOrigins = right.origins.length.compareTo(left.origins.length);

      return byOrigins != 0 ? byOrigins : order[left]!.compareTo(order[right]!);
    });

    return rows;
  }

  // 淘汰顺序：other → tags → origins 最少的 contains → origins 最少的 equal。
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

  bool _removeLast(Map<SearchBookKey, SearchBook> bucket) {
    if (bucket.isEmpty) {
      return false;
    }
    bucket.remove(bucket.keys.last);

    return true;
  }

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
