import 'dart:async';

import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/di/user_messages_provider.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_lib.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/quickjs_worker.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/js/source_info_map.dart';
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
    // 登录头（`source.putLoginHeader`，M25/S3b）：随 job 下传、写过就写穿并合并其中的 Cookie。
    loginHeaders: ref.watch(sourceLoginHeaderStoreProvider),
    // 登录信息（`source.putLoginInfo` / `removeLoginInfo`，M25/S5a）：只在规则写过时写穿 `login_info`。
    loginInfos: ref.watch(sourceLoginInfoWriterProvider),
    // 探索规则读写的 `infoMap`（M25/S3b）：内存表，随 worker 的会话活着。
    infoMaps: ref.watch(sourceInfoMapStoreProvider),
    // `java.openUrl`（M25/S3b）：确认弹窗 + 系统浏览器，由装配根绑定（`core/` 不认识 widget）。
    externalUrlOpener: ref.watch(externalUrlOpenerProvider),
    // `java.androidId`（M25/S3b）：`main()` 在第一帧之前 hydrate 出来的安装 id。
    androidId: ref.watch(installIdProvider).value,
    userMessages: ref.watch(userMessagesProvider),
  );
  ref.onDispose(() => unawaited(bridge.dispose()));

  return bridge;
}

/// Provides the per-source `infoMap` (`book-source.md` §6, M25/S3b).
///
/// In memory only, like `cache.*`: it is explore state, not a record, and it is read and written by
/// every job, so a rebuild between two stages must not wipe it — hence `keepAlive`.
@Riverpod(keepAlive: true)
SourceInfoMapStore sourceInfoMapStore(Ref ref) => SourceInfoMapStore();

/// Provides the rule variables shared by `@put:` / `@get:` and `java.put` /
/// `java.get`.
///
/// One store per provider scope; nothing survives the operation that created it.
@Riverpod(keepAlive: true)
JsVariableStore jsVariableStore(Ref ref) => JsVariableStore();

/// Provides the resolver for a book source's own JavaScript library (`jsLib`, ADR-0078 S1).
///
/// `keepAlive` matters: the store caches the resolved text per library, so one page with twenty
/// `@js:` fields downloads the library once — and a rebuild between stages would throw that away.
@Riverpod(keepAlive: true)
JsLibStore jsLibStore(Ref ref) => JsLibStore(
  http: ref.watch(httpClientProvider),
  logger: ref.watch(appLoggerProvider),
);
