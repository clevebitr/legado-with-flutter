import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger_provider.g.dart';

/// Verbosity supplied at build time, e.g. `--dart-define=LOG_LEVEL=debug`.
///
/// Read through `String.fromEnvironment` so the value is baked in at compile
/// time; `info` is the documented default for both debug and release builds
/// (ADR-0006).
const String _rawLogLevel = String.fromEnvironment(
  'LOG_LEVEL',
  defaultValue: 'info',
);

/// Provides the application logger, the only log entry point (ADR-0006).
///
/// Tests inject a capturing printer with
/// `appLoggerProvider.overrideWithValue(...)`.
@Riverpod(keepAlive: true)
AppLogger appLogger(Ref ref) => AppLogger(level: LogLevel.parse(_rawLogLevel));
