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
      'flutter: ${details.exceptionAsString()}${_whereOf(details)}',
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

/// The widget a widget error came from, as a ` — ` suffix on the record.
///
/// A `RenderFlex overflowed by 31 pixels` with fourteen identical `paint` stack traces says nothing
/// about *which* widget was too tall; Flutter puts that in its first information node (the creator
/// chain). Only the **first node shorter than [_maxWhereLength]** is taken — the rest of the list is
/// the render-tree dump, and a record stays one line (ADR-0084). `''` when there is nothing to add.
String _whereOf(FlutterErrorDetails details) {
  final Iterable<DiagnosticsNode>? information = details.informationCollector
      ?.call();
  if (information == null) {
    return '';
  }
  for (final DiagnosticsNode node in information) {
    final String text = node.toString().replaceAll('\n', ' ').trim();
    if (text.isEmpty) {
      continue;
    }
    if (text.length > _maxWhereLength) {
      // 渲染树转储：几 KB 一条，跳过它去找下一条短的（通常就是 creator 链）。
      continue;
    }

    return '  where=$text';
  }

  return '';
}

/// How long the `where=` part of a widget-error record may get.
const int _maxWhereLength = 400;

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
