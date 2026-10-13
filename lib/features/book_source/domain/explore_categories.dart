import 'dart:convert';

import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';

/// The categories one `exploreUrl` declaration yields, plus the entries it had to reject.
///
/// Both halves travel together on purpose: `docs/dev/book-source.md` §4.2 keeps the good entries
/// **and** requires every rejected one to be recorded (C-SRC-4 — a dropped category must never be
/// silent). The reasons are short, non-sensitive summaries; the caller adds the book source and
/// the field path when it logs them (C-ERR-8).
typedef ExploreCategoryParse = ({
  List<ExploreCategory> categories,
  List<String> rejected,
});

/// Parses what a whole-field `exploreUrl` expression produced (`book-source.md` §4.2).
///
/// Upstream accepts **both** shapes from the same script (`BookSourceExtensions.kt:82-92`): a JSON
/// array of category objects, or the separated `标题::URL` string. An array wins when the text
/// decodes to one; anything else is read as the separated form, which is also what a plain
/// (non-script) `exploreUrl` is.
ExploreCategoryParse parseExploreSource(String source) {
  final Object? decoded = _tryDecode(source);
  if (decoded is List<Object?>) {
    return _parseJsonCategories(decoded);
  }

  return parseExploreString(source);
}

/// Parses the separated `标题::URL` form, i.e. what a plain `exploreUrl` carries.
///
/// Entries are split on runs of `&&` or newlines — upstream's `(&&|\n)+` regex
/// (`BookSourceExtensions.kt:90`), which keeps a single `&` inside a URL intact. Each entry is
/// split at its **first** `::`; a blank title or a missing URL is a rejection rather than a
/// category, and the remaining entries are still returned (ADR-0035 §决策 3).
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

/// Parses the JSON-array form a whole-field script may return (`book-source.md` §4.2).
///
/// An element must be an object with a non-blank `title`, a non-blank `url`, and either no `type`
/// or `type == "url"`. Everything else is rejected by name — in particular a form category
/// (`text` / `button` / `toggle` / `select`), which is out of M1's scope (ADR-0035 §决策 4/6).
ExploreCategoryParse _parseJsonCategories(List<Object?> entries) {
  final List<ExploreCategory> categories = <ExploreCategory>[];
  final List<String> rejected = <String>[];

  for (final Object? entry in entries) {
    if (entry is! Map<Object?, Object?>) {
      rejected.add('not an object (${entry.runtimeType})');

      continue;
    }

    final Object? type = entry['type'];
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

/// Decodes [source] as JSON, or answers `null` when it is not JSON at all.
///
/// A plain `exploreUrl` is usually a separated string, so failing to decode is the ordinary path,
/// not an error: that is why this is a private probe rather than a `try`/`catch` at every caller.
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
