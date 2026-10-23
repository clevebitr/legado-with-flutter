import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_navigation_provider.g.dart';

/// Provides the cross-feature destinations.
///
/// Defaults to the unbound no-op; the composition root may override it.
@Riverpod(keepAlive: true)
AppNavigation appNavigation(Ref ref) {
  final logger = ref.watch(appLoggerProvider);

  return UnboundAppNavigation(warn: logger.warning);
}
