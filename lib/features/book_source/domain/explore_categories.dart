import 'dart:convert';

import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';

/// The categories one `exploreUrl` declaration yields, plus the entries it had to reject.
typedef ExploreCategoryParse = ({
  List<ExploreCategory> categories,
  List<String> rejected,
});

/// Parses a whole-field `exploreUrl` expression.
///
/// A JSON array of category objects wins; anything else is read as the separated form.
ExploreCategoryParse parseExploreSource(String source) {
  final Object? decoded = _tryDecode(source);
  if (decoded is List<Object?>) {
    return _parseJsonCategories(decoded);
  }

  return parseExploreString(source);
}

/// Parses the separated `标题::URL` form, i.e. what a plain `exploreUrl` carries.
///
/// A blank title or a missing URL rejects that entry only; the rest are still returned.
ExploreCategoryParse parseExploreString(String source) {
  final List<ExploreCategory> categories = <ExploreCategory>[];
  final List<String> rejected = <String>[];

  for (final String entry in source.split(_entrySeparator)) {
    final String text = entry.trim();
    if (text.isEmpty) {
      continue;
    }

    final int split = text.indexOf('::');
    if (split < 0) {
      rejected.add('missing "::" separator');

      continue;
    }

    final String title = text.substring(0, split).trim();
    final String url = text.substring(split + 2).trim();
    if (title.isEmpty) {
      rejected.add('blank title');
    } else if (url.isEmpty) {
      rejected.add('missing url (title=$title)');
    } else {
      categories.add(ExploreCategory(title: title, url: url));
    }
  }

  return (categories: categories, rejected: rejected);
}

/// Parses the JSON-array form a whole-field script may return.
///
/// An element needs a non-blank `title` and `url`, and either no `type` or `type == "url"`.
ExploreCategoryParse _parseJsonCategories(List<Object?> entries) {
  final List<ExploreCategory> categories = <ExploreCategory>[];
  final List<String> rejected = <String>[];

  for (final Object? entry in entries) {
    if (entry is! Map<Object?, Object?>) {
      rejected.add('not an object (${entry.runtimeType})');

      continue;
    }

    final Object? type = entry['type'];
    // 表单类分类（text / button / toggle / select）暂不支持，按名拒绝。
    if (type != null && type != 'url') {
      rejected.add('form category (type=$type)');

      continue;
    }

    final Object? title = entry['title'];
    final Object? url = entry['url'];
    if (title is! String || title.trim().isEmpty) {
      rejected.add('blank title');
    } else if (url is! String || url.trim().isEmpty) {
      rejected.add('missing url (title=${title.trim()})');
    } else {
      categories.add(ExploreCategory(title: title.trim(), url: url.trim()));
    }
  }

  return (categories: categories, rejected: rejected);
}

// 普通 exploreUrl 不是 JSON，解码失败是常态而不是错误。
Object? _tryDecode(String source) {
  final String text = source.trim();
  if (!text.startsWith('[') && !text.startsWith('{')) {
    return null;
  }

  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

/// Runs of `&&` or newlines that separate the entries of a category string.
final RegExp _entrySeparator = RegExp(r'(?:&&|\r?\n)+');
