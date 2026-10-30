import 'package:flutter/material.dart';

import 'package:flutter_reader/core/router/change_source_contract.dart';

/// The app-level destinations any page may open.
///
/// Features never import each other's routes; the composition root binds this
/// port, and the default implementation logs instead of throwing.
abstract interface class AppNavigation {
  /// Opens the bookshelf page.
  void openBookshelf(BuildContext context);

  /// Opens the settings page.
  void openSettings(BuildContext context);

  /// Opens the book-source management page.
  void openBookSources(BuildContext context);

  /// Opens the about page.
  void openAbout(BuildContext context);

  /// Opens the bookmark list.
  void openBookmarks(BuildContext context);

  /// Opens the reading records, grouped by day.
  void openReadingRecords(BuildContext context);

  /// Opens the 替换净化 rule list (`docs/dev/roadmap.md` M20).
  ///
  /// Four methods instead of one with a kind parameter: the port carries primitives only
  /// (ADR-0042), and a stringly-typed kind would move a switch into every implementation.
  void openReplaceRules(BuildContext context);

  /// Opens the 目录规则 list.
  void openTocRules(BuildContext context);

  /// Opens the 字典规则 list.
  void openDictRules(BuildContext context);

  /// Opens the 高亮标签 list.
  void openHighlightRules(BuildContext context);

  /// Opens the per-source cache page (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
  void openCacheManage(BuildContext context);

  /// Opens the cookie jar view (`docs/dev/roadmap.md` M22, ADR-0072 §决策 2).
  void openCookies(BuildContext context);

  /// Opens the backup and restore page (`docs/dev/roadmap.md` M22, ADR-0073).
  void openBackup(BuildContext context);

  /// Opens the reading records of one book.
  void openBookReadingRecords(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
  });

  /// Opens the reader on one book, optionally at a specific chapter.
  ///
  /// Parameters are primitives only, and a `null` [chapterUrl] resumes where the
  /// reader stopped.
  void openReader(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    required String tocUrl,
    String? chapterUrl,
  });

  /// Opens the shelf's book editor for the row with [bookId] (M33, ADR-0092).
  ///
  /// The editor belongs to `bookshelf`, which owns the row; a caller that only knows
  /// `(sourceUrl, bookUrl)` asks that feature for the id (the detail page gets it from
  /// `ShelfMembership`).
  void openShelfBookEdit(BuildContext context, int bookId);

  /// Opens the change-source flow and answers where the caller continues.
  ///
  /// Answers `null` when the user backs out. The flow itself (candidate search, progress, chapter
  /// pick, shelf-identity migration) belongs to `book_source`; the caller only learns the new
  /// identity and the aligned chapter (ADR-0091, ADR-0042 §决策 2).
  Future<ChangeSourceOutcome?> openChangeSource(
    BuildContext context,
    ChangeSourceLaunch launch,
  );
}

/// The answer when nothing bound [AppNavigation]: log and do nothing.
final class UnboundAppNavigation implements AppNavigation {
  /// Creates the unbound port; the callback receives one line per missed
  /// navigation.
  const UnboundAppNavigation({required this._warn});

  final void Function(String message) _warn;

  @override
  void openBookshelf(BuildContext context) =>
      _warn('No AppNavigation is bound: the bookshelf entry does nothing.');

  @override
  void openSettings(BuildContext context) =>
      _warn('No AppNavigation is bound: the settings entry does nothing.');

  @override
  void openBookSources(BuildContext context) =>
      _warn('No AppNavigation is bound: the book-source entry does nothing.');

  @override
  void openAbout(BuildContext context) =>
      _warn('No AppNavigation is bound: the about entry does nothing.');

  @override
  void openBookmarks(BuildContext context) =>
      _warn('No AppNavigation is bound: the bookmark entry does nothing.');

  @override
  void openReadingRecords(BuildContext context) => _warn(
    'No AppNavigation is bound: the reading-record entry does nothing.',
  );

  @override
  void openBookReadingRecords(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
  }) => _warn(
    'No AppNavigation is bound: the book reading-record entry does nothing.',
  );

  @override
  void openShelfBookEdit(BuildContext context, int bookId) =>
      _warn('No AppNavigation is bound: the book editor does nothing.');

  @override
  Future<ChangeSourceOutcome?> openChangeSource(
    BuildContext context,
    ChangeSourceLaunch launch,
  ) async {
    _warn('No AppNavigation is bound: the change-source entry does nothing.');

    return null;
  }

  @override
  void openReplaceRules(BuildContext context) =>
      _warn('No AppNavigation is bound: the replace-rule entry does nothing.');

  @override
  void openTocRules(BuildContext context) =>
      _warn('No AppNavigation is bound: the toc-rule entry does nothing.');

  @override
  void openDictRules(BuildContext context) =>
      _warn('No AppNavigation is bound: the dict-rule entry does nothing.');

  @override
  void openHighlightRules(BuildContext context) => _warn(
    'No AppNavigation is bound: the highlight-rule entry does nothing.',
  );

  @override
  void openCacheManage(BuildContext context) =>
      _warn('No AppNavigation is bound: the cache entry does nothing.');

  @override
  void openCookies(BuildContext context) =>
      _warn('No AppNavigation is bound: the cookie entry does nothing.');

  @override
  void openBackup(BuildContext context) =>
      _warn('No AppNavigation is bound: the backup entry does nothing.');

  @override
  void openReader(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    required String tocUrl,
    String? chapterUrl,
  }) => _warn('No AppNavigation is bound: the reader entry does nothing.');
}
