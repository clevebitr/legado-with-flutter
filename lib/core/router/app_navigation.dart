import 'package:flutter/material.dart';

/// The app-level destinations any page may open (ADR-0042).
///
/// Cross-feature navigation cannot be a direct import: `features/A` must not import
/// `features/B` (C-ARCH-2), and ADR-0041 的端口方案只覆盖 `domain/`（端口收发原语与实体），
/// while opening a page needs a [BuildContext]. This is therefore the presentation-side twin of
/// that mechanism: the **consumer** declares the port, the composition root binds it, and the
/// port carries nothing but a context — never a route object of another feature.
///
/// The default implementation is an unbound no-op that logs a warning (never throws), so a
/// forgotten binding shows up as an unresponsive button plus a log line instead of a crash
/// (ADR-0041 §决策 2 的同一条理由).
abstract interface class AppNavigation {
  /// Opens the shelf page.
  void openBookshelf(BuildContext context);

  /// Opens the settings page.
  void openSettings(BuildContext context);

  /// Opens the book-source management page (M18's 「我的」entry).
  void openBookSources(BuildContext context);

  /// Opens the about page (M18).
  void openAbout(BuildContext context);

  /// Opens the reader on one book, optionally at a specific chapter (ADR-0042 §决策 2).
  ///
  /// The parameters are **primitives only**: the reader's own route object and its `ReaderBook`
  /// belong to another feature, and passing them here would make this port a second cross-feature
  /// interface (C-ARCH-2). A `null` [chapterUrl] means "resume where the reader stopped"; a
  /// concrete one means "open this chapter", which is what a chapter row in the detail page means.
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
  /// Creates the unbound port; `_warn` receives one line per missed navigation.
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
  void openReader(
    BuildContext context, {
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    required String tocUrl,
    String? chapterUrl,
  }) => _warn('No AppNavigation is bound: the reader entry does nothing.');
}
