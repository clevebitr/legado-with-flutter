import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_route.freezed.dart';

/// The typed routes of the settings feature (ADR-0011, ADR-0041 §决策 5).
@freezed
sealed class SettingsRoute with _$SettingsRoute {
  const SettingsRoute._();

  /// The route that shows the settings page.
  const factory SettingsRoute.settings() = SettingsPageRoute;

  /// The cookie jar view (`docs/dev/roadmap.md` M22, ADR-0072 §决策 2).
  const factory SettingsRoute.cookies() = SettingsCookiesRoute;

  /// The path this route is served under.
  String get path => switch (this) {
    SettingsPageRoute() => _settingsPath,
    SettingsCookiesRoute() => _cookiesPath,
  };
}

/// Path of [SettingsPageRoute].
const String _settingsPath = '/settings';

/// Path of [SettingsCookiesRoute].
const String _cookiesPath = '/settings/cookies';

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushSettingsRoute(BuildContext context, SettingsRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);
