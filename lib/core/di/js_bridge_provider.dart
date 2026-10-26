import 'dart:async';

import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/di/user_messages_provider.dart';
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
    // 验证族与 `webView` 需要平台能力（ADR-0068 §决策 5/6）：端口在 core/platform，
    // 实现在装配根绑定，沙箱本身不认识页面。
    verification: ref.watch(sourceVerificationProvider),
    webPages: ref.watch(webPageFetcherProvider),
    // 同步族读写的是 App 的同一份 Cookie 宗（`http.*` 与 WebView 也用它），每源变量写穿数据库，
    // toast 交给装配根绑定的提示通道（ADR-0076 §决策 1）。
    cookies: ref.watch(cookieManagerProvider),
    sourceVariables: ref.watch(sourceVariableStoreProvider),
    userMessages: ref.watch(userMessagesProvider),
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
