import 'dart:async';

import 'package:flutter/material.dart';

/// The app's route table: turns [RouteSettings] into pages and centralizes
/// pushes.
final class AppRouter {
  /// Creates the router.
  // 常量实例会被折叠，这一行在 lcov 中没有执行点。
  const AppRouter(); // coverage:ignore-line

  /// Path of the landing route, which carries no typed arguments.
  static const String homePath = '/';

  /// Builds the route for [settings], letting [pageFor] turn its arguments into
  /// a page.
  Route<void> onGenerateRoute(
    RouteSettings settings, {
    required Widget Function(Object? arguments) pageFor,
  }) => MaterialPageRoute<void>(
    settings: settings,
    builder: (BuildContext context) => pageFor(settings.arguments),
  );

  /// Pushes [arguments] under [path] through the route table.
  ///
  /// Use this instead of `Navigator.push` so the next hop stays a typed route.
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
