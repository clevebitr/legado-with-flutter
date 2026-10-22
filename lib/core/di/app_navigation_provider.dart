import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_navigation_provider.g.dart';

/// Provides the cross-feature destinations (ADR-0042).
///
/// The composition root overrides this with the real implementation
/// (`appProviderOverrides` in `lib/app.dart`); the default is the unbound no-op, so a page can
/// always call it and tests that do not care about navigation need no override.
@Riverpod(keepAlive: true)
AppNavigation appNavigation(Ref ref) {
  final logger = ref.watch(appLoggerProvider);

  return UnboundAppNavigation(warn: logger.warning);
}
