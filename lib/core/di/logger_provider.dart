import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger_provider.g.dart';

// 编译期常量，可用 `--dart-define=LOG_LEVEL=debug` 覆盖。
const String _rawLogLevel = String.fromEnvironment(
  'LOG_LEVEL',
  defaultValue: 'info',
);

/// Provides the application logger, the only log entry point.
///
/// Tests override it with a capturing printer.
@Riverpod(keepAlive: true)
AppLogger appLogger(Ref ref) => AppLogger(level: LogLevel.parse(_rawLogLevel));
