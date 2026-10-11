import 'dart:async';

import 'package:flutter/material.dart';

/// The app's route table (ADR-0011).
///
/// The table is split in three so that no layer boundary is crossed:
///
/// * this class owns the **mechanism** — a [RouteSettings] becomes a page, and every
///   push goes through one entry point instead of a `Navigator.push` per page;
/// * the composition root (`lib/app.dart`) owns the **page table**, i.e. which typed
///   route builds which page, because `core/` must not import `features/`
///   (`docs/dev/architecture.md` §2);
/// * each feature owns its **typed route arguments and their paths**, for example
///   `BookSourceRoute` in `features/book_source/presentation/`.
///
/// Route arguments are typed `freezed` objects, never a bare
/// `Map<String, Object?>` (ADR-0011 §2).
final class AppRouter {
  /// Creates the router.
  const AppRouter();

  /// Path of the landing route, i.e. the name that carries no typed arguments.
  static const String homePath = '/';

  /// Builds the route for [settings], letting [pageFor] turn the pushed arguments
  /// into a page.
  ///
  /// [pageFor] is handed `RouteSettings.arguments` unchanged — a typed route object
  /// (ADR-0011) — and is responsible for the fallback page when it does not
  /// recognise the arguments.
  Route<void> onGenerateRoute(
    RouteSettings settings, {
    required Widget Function(Object? arguments) pageFor,
  }) => MaterialPageRoute<void>(
    settings: settings,
    builder: (BuildContext context) => pageFor(settings.arguments),
  );

  /// Pushes [arguments] under [path] through the app's route table.
  ///
  /// A page calls this instead of `Navigator.push` so the next hop stays a typed
  /// route of the table (ADR-0011 §4); [path] is taken from the route object itself
  /// and never written as a literal at the call site. The returned navigation future
  /// has no caller to report to, hence the explicit `unawaited` (C-ERR-6).
  static void push(
    BuildContext context, {
    required String path,
    required Object arguments,
  }) {
    unawaited(
      Navigator.of(context).pushNamed<void>(path, arguments: arguments),
    );
  }
}
