import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';

/// [AppNavigation] double that records every destination a page asked for
/// (`docs/dev/testing.md` §4).
///
/// The port exists so a page never imports another feature (ADR-0042); a test therefore asserts on
/// **what the page asked for** — which chapter, which book — instead of on a pushed route.
final class FakeAppNavigation implements AppNavigation {
  /// One `openReader` call's arguments, in the order the real port takes them.
  final List<
    ({
      String sourceUrl,
      String bookUrl,
      String bookName,
      String tocUrl,
      String? chapterUrl,
    })
  >
  readerCalls =
      <
        ({
          String sourceUrl,
          String bookUrl,
          String bookName,
          String tocUrl,
          String? chapterUrl,
        })
      >[];

  /// How many times the shelf was opened.
  int shelfCalls = 0;

  /// How many times the settings page was opened.
  int settingsCalls = 0;

  /// How many times the book-source management page was opened.
  int bookSourcesCalls = 0;

  /// How many times the about page was opened.
  int aboutCalls = 0;

  /// How many times the bookmark list was opened.
  int bookmarksCalls = 0;

  /// How many times the reading records were opened.
  int readingRecordsCalls = 0;

  /// How many times the per-source cache page was opened.
  int cacheCalls = 0;

  /// How many times the cookie jar was opened.
  int cookieCalls = 0;

  /// How many times each rule list was opened, keyed by the stored `kind` value.
  final Map<String, int> ruleCalls = <String, int>{};

  /// Every `openBookReadingRecords` call's arguments, in the order the port takes them.
  final List<({String sourceUrl, String bookUrl, String bookName})>
  bookReadingRecordsCalls =
      <({String sourceUrl, String bookUrl, String bookName})>[];

  @override
  void openBookshelf(BuildContext context) => shelfCalls++;

  @override
  void openSettings(BuildContext context) => settingsCalls++;

  @override
  void openBookSources(BuildContext context) => bookSourcesCalls++;

  @override
  void openAbout(BuildContext context) => aboutCalls++;

  @override
  void openBookmarks(BuildContext context) => bookmarksCalls++;

  @override
  void openReadingRecords(BuildContext context) => readingRecordsCalls++;

  @override
  void openCacheManage(BuildContext context) => cacheCalls++;

  @override
  void openCookies(BuildContext context) => cookieCalls++;

  @override
  void openReplaceRules(BuildContext context) => _countRule('replace');

  @override
  void openTocRules(BuildContext context) => _countRule('toc');

  @override
  void openDictRules(BuildContext context) => _countRule('dict');

  @override
  void openHighlightRules(BuildContext context) => _countRule('highlight');

  void _countRule(String kind) =>
      ruleCalls.update(kind, (int count) => count + 1, ifAbsent: () => 1);

  @override
  void openBookReadingRecords(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
  }) => bookReadingRecordsCalls.add((
    sourceUrl: sourceUrl,
    bookUrl: bookUrl,
    bookName: bookName,
  ));

  @override
  void openReader(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    required String tocUrl,
    String? chapterUrl,
  }) => readerCalls.add((
    sourceUrl: sourceUrl,
    bookUrl: bookUrl,
    bookName: bookName,
    tocUrl: tocUrl,
    chapterUrl: chapterUrl,
  ));
}
