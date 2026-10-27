import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// The marker every crash record starts with, so `grep CRASH` finds them all.
const String crashMarker = 'CRASH';

/// Installs the Dart-side crash handlers (`ADR-0082`).
///
/// Three doors, one record shape: a widget/build error, an error that reached the platform
/// dispatcher, and an uncaught error inside an isolate (the JS worker's isolate included). Every
/// one of them is written **synchronously** through the logger's file sink, because a crash path
/// may not get another turn of the event loop.
///
/// Native crashes (NDK / SIGSEGV on iOS) are **out of scope**: they need a native handler and an
/// upload channel, which is a separate decision (`ADR-0082` §后果).
///
/// [onCrash] is called after the record is written; the app's own reporting (or a test) can hook
/// there. Returning `true` from the platform handler means "handled": the process keeps running
/// with whatever state it has, which is what a reading app should do for a single bad rule.
void installCrashHandlers(
  AppLogger logger, {
  void Function(String record, Object error, StackTrace stackTrace)? onCrash,
}) {
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final StackTrace stack = details.stack ?? StackTrace.current;
    _record(
      logger,
      'flutter: ${details.exceptionAsString()}',
      details.exception,
      stack,
      onCrash,
    );
    // 失去渲染时上游必须还能照常报错：控制台 / 上游 handler 都留着。
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _record(logger, 'platform: $error', error, stack, onCrash);

    return true;
  };

  // isolate 里的未捕获异常（JS worker 每次超时被杀，脚本里的错都在这里冒出来）。
  final RawReceivePort port = RawReceivePort((Object? message) {
    if (message is! List || message.length < 2) {
      return;
    }
    final Object? error = message.first;
    final Object? stack = message.length > 1 ? message[1] : null;
    _record(
      logger,
      'isolate: $error',
      error ?? 'unknown isolate error',
      stack is StackTrace ? stack : StackTrace.current,
      onCrash,
    );
  });
  Isolate.current.addErrorListener(port.sendPort);
  _ports.add(port);
}

final List<RawReceivePort> _ports = <RawReceivePort>[];

/// Closes the isolate listeners (tests and hot restart; a release app keeps them for its lifetime).
void uninstallCrashHandlerPorts() {
  for (final RawReceivePort port in _ports) {
    port.close();
  }
  _ports.clear();
}

void _record(
  AppLogger logger,
  String what,
  Object error,
  StackTrace stackTrace,
  void Function(String record, Object error, StackTrace stackTrace)? onCrash,
) {
  final String record = '$crashMarker $what\n$stackTrace';
  // 同步写：崩溃路径上没有下一次事件循环。
  logger.error('$crashMarker $what', error, stackTrace);
  onCrash?.call(record, error, stackTrace);
}
