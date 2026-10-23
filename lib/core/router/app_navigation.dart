import 'package:flutter/material.dart';

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
  void openReader(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    required String tocUrl,
    String? chapterUrl,
  }) => _warn('No AppNavigation is bound: the reader entry does nothing.');
}
