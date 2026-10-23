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

  @override
  void openBookshelf(BuildContext context) => shelfCalls++;

  @override
  void openSettings(BuildContext context) => settingsCalls++;

  @override
  void openBookSources(BuildContext context) => bookSourcesCalls++;

  @override
  void openAbout(BuildContext context) => aboutCalls++;

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
