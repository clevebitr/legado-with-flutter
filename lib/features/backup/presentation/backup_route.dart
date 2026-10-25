import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_route.freezed.dart';

/// The typed routes of the backup feature (`docs/dev/roadmap.md` M22, ADR-0073).
@freezed
sealed class BackupRoute with _$BackupRoute {
  const BackupRoute._();

  /// The route that shows the backup page.
  const factory BackupRoute.page() = BackupPageRoute;

  /// The path this route is served under.
  String get path => switch (this) {
    BackupPageRoute() => _pagePath,
  };
}

/// Path of [BackupPageRoute].
const String _pagePath = '/backup';

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushBackupRoute(BuildContext context, BackupRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);
