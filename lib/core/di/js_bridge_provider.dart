import 'dart:async';

import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/quickjs_worker.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'js_bridge_provider.g.dart';

/// Provides the shared `@js:` sandbox for rule evaluation.
///
/// The worker is created on first use, and scripts share the app HTTP client's
/// cookies and per-source concurrency budget.
@Riverpod(keepAlive: true)
JsBridge jsBridge(Ref ref) {
  final JsBridge bridge = QuickJsWorkerBridge(
    logger: ref.watch(appLoggerProvider),
    launch: launchQuickJsWorker,
    http: ref.watch(httpClientProvider),
    variables: ref.watch(jsVariableStoreProvider),
  );
  ref.onDispose(() => unawaited(bridge.dispose()));

  return bridge;
}

/// Provides the rule variables shared by `@put:` / `@get:` and `java.put` /
/// `java.get`.
///
/// One store per provider scope; nothing survives the operation that created it.
@Riverpod(keepAlive: true)
JsVariableStore jsVariableStore(Ref ref) => JsVariableStore();
