import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/crash_handlers.dart';
import 'package:flutter_reader/core/logging/log_file.dart';
import 'package:flutter_reader/core/platform/install_id.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/presentation/notifiers/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Application entry point.
///
/// The cookie jar is hydrated **before** `runApp` (ADR-0068 §决策 4): the first request has to see
/// the stored login, and the HTTP client reads the jar synchronously (C-NET-5). It is one awaited
/// call, so bootstrap stays bootstrap: no widget, no route, no business logic.
///
/// 日志文件与崩溃处理器也在这里装配（`ADR-0082`）：崩溃处理器必须早于第一帧，日志目录来自
/// `path_provider`（`core/logging` 不碰平台通道）；用户设置里的日志级别在启动时套到门上。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final LogFile logFile = await _openLogFile();
  final ProviderContainer container = ProviderContainer(
    // 跨 feature 端口的绑定只发生在装配根（ADR-0041 §决策 2、ADR-0042）。
    overrides: appProviderOverrides()
      ..add(logFileProvider.overrideWithValue(logFile)),
  );
  final AppLogger logger = container.read(appLoggerProvider);
  installCrashHandlers(logger);
  await container.read(cookieManagerProvider).hydrate();
  // 安装 id 同理：`java.androidId` 在规则里是同步读的，生成 + 落库必须在第一帧之前完成
  // （M25/S3b；值存在轻量开关里，一次读一次写）。
  await container
      .read(installIdProvider)
      .hydrate(
        PreferenceInstallIdStore(
          await container.read(preferenceStoreProvider.future),
        ),
      );
  // 用户选的级别优先于 `--dart-define`：设置页改的就是它（`ADR-0082`）。
  final AsyncValue<AppSettings> settings = container.read(settingsProvider);
  logger.setLevel(settings.value?.logLevel ?? defaultLogLevel);
  logger.info(
    'app start: platform=${Platform.operatingSystem} '
    'log=${logFile.currentFile.path} level=${logger.level.name}',
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const ReaderApp()),
  );
}

/// Opens today's log file and applies the retention rule before anything is written.
Future<LogFile> _openLogFile() async {
  final Directory support = await getApplicationSupportDirectory();
  final LogFile file = LogFile(directory: Directory('${support.path}/logs'));
  // 先剪再写：上次运行留下的过期文件不该在第一行日志之前占着空间。
  await file.prune();

  return file;
}
