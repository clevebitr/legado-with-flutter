import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_file.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger_provider.g.dart';

// 编译期常量，可用 `--dart-define=LOG_LEVEL=debug` 覆盖。用户设置里的级别在启动时覆盖它
// （`ADR-0082`），所以这里只是**默认值**。
const String _rawLogLevel = String.fromEnvironment(
  'LOG_LEVEL',
  defaultValue: 'info',
);

/// The on-disk log, or `null` when the assembly root did not wire one (tests).
///
/// `main()` resolves the platform directory (it already awaits the cookie jar and the install id)
/// and overrides this provider, which keeps `appLogger` synchronous and keeps `core/logging` free of
/// `path_provider`.
@Riverpod(keepAlive: true)
LogFile? logFile(Ref ref) => null;

/// Provides the application logger, the only log entry point.
///
/// Tests override it with a capturing printer; production attaches the [LogFile] above.
@Riverpod(keepAlive: true)
AppLogger appLogger(Ref ref) => AppLogger(
  level: LogLevel.parse(_rawLogLevel),
  file: ref.watch(logFileProvider),
);
