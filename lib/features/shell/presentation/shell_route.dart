import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/features/shell/presentation/pages/about_page.dart';
import 'package:flutter_reader/features/shell/presentation/pages/legal_notices_page.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'shell_route.freezed.dart';

/// The typed routes the shell's pages push (ADR-0011, ADR-0055 §决策 5).
///
/// They live with the shell rather than in `core/router/`: `core/` may not import `features/`
/// (`docs/dev/architecture.md` §2), and typed parameters belong to the feature that builds the page.
@freezed
sealed class ShellRoute with _$ShellRoute {
  /// The about page.
  const factory ShellRoute.about() = AboutRoute;

  /// The legal notices page.
  const factory ShellRoute.legalNotices() = LegalNoticesRoute;

  const ShellRoute._();

  /// Path of this route in the app's route table.
  String get path => switch (this) {
    AboutRoute() => '/about',
    LegalNoticesRoute() => '/about/legal',
  };
}

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushShellRoute(BuildContext context, ShellRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);

/// The page for a shell route (the composition root's page table calls this).
Widget shellPageFor(ShellRoute route) => switch (route) {
  AboutRoute() => const AboutPage(),
  LegalNoticesRoute() => const LegalNoticesPage(),
};
