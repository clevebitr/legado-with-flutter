import 'dart:async';

import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/quickjs_worker.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'js_bridge_provider.g.dart';

/// Provides the `@js:` sandbox every rule evaluation shares (C-SRC-2, C-SRC-3).
///
/// The worker is created **lazily** by the bridge on the first `@js:` rule and released
/// with this provider (ADR-0030 §决策 6), so an app that never meets a JS rule never
/// pays for an isolate or a QuickJS runtime. Everything the bridge needs — the isolate,
/// the engine and the JS prelude — stays behind the launcher, which is why `domain/`
/// only ever sees [JsBridge] (ADR-0029 §决策 2).
///
/// The bridge also gets the app-wide HTTP client, because §6 binds `http.*` to the rule
/// sandbox and C-NET-1 makes that client the only door to the network: a rule's request
/// shares the same cookies and the same per-source concurrency budget (`book-source.md`
/// §8) as the page that carried the rule.
///
/// The provider is autoDispose: the budget dies with the scope, so one operation's
/// batch shares one worker (see `PLAN.md` §3.7 for the batch-download follow-up).
@riverpod
JsBridge jsBridge(Ref ref) {
  final JsBridge bridge = QuickJsWorkerBridge(
    logger: ref.watch(appLoggerProvider),
    launch: launchQuickJsWorker,
    http: ref.watch(httpClientProvider),
  );
  ref.onDispose(() => unawaited(bridge.dispose()));

  return bridge;
}
