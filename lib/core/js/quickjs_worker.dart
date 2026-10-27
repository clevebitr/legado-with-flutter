// coverage:ignore-file
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter_qjs_next/flutter_qjs.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_cache.dart';
import 'package:flutter_reader/core/js/js_crypto.dart';
import 'package:flutter_reader/core/js/js_fonts.dart';
import 'package:flutter_reader/core/js/js_helpers.dart';
import 'package:flutter_reader/core/js/js_sync_call.dart';
import 'package:flutter_reader/core/js/zh_tables.dart';

/// Starts the real worker: one isolate owning one reused QuickJS runtime.
///
/// The budgets come from the bridge, which also owns queueing and timeouts.
Future<JsWorkerHandle> launchQuickJsWorker({
  required Duration timeout,
  required int memoryLimit,
}) async {
  final ReceivePort fromWorker = ReceivePort();
  final StreamController<Map<String, Object?>> messages =
      StreamController<Map<String, Object?>>();
  final Completer<SendPort> ready = Completer<SendPort>();

  final StreamSubscription<Object?> subscription = fromWorker.listen((
    Object? raw,
  ) {
    if (raw is! Map) {
      return;
    }
    final Map<String, Object?> message = Map<String, Object?>.from(raw);
    if (!ready.isCompleted && message['type'] == 'ready') {
      final Object? port = message['port'];
      if (port is SendPort) {
        ready.complete(port);
      }

      return;
    }
    if (!messages.isClosed) {
      messages.add(message);
    }
  });

  final Isolate isolate = await Isolate.spawn(_quickJsWorkerMain, <Object?>[
    fromWorker.sendPort,
    timeout.inMilliseconds,
    memoryLimit,
    // 简繁码表是 Flutter 资产（`assets/zh/`）且后台 isolate 读不了资产，所以在主 isolate 读好、
    // 随 bootstrap 一次性交给 worker（解析仍然懒：只有真用 `java.t2s/s2t` 的源才建表）。
    await _readZhTables(),
  ], debugName: 'js-worker');

  return _IsolateWorkerHandle(
    isolate: isolate,
    toWorker: await ready.future,
    fromWorker: fromWorker,
    subscription: subscription,
    messages: messages,
  );
}

// 后台 isolate 读不到 Flutter 资产，所以码表在主 isolate 读好、随 bootstrap 一次性交过去。
// 读失败不在这里吞：资产在 `pubspec.yaml` 里声明过，缺了就是构建问题，应该当场看得见。
Future<Map<String, String>> _readZhTables() async {
  final String t2s = await rootBundle.loadString('assets/zh/t2s.txt');
  final String s2t = await rootBundle.loadString('assets/zh/s2t.txt');

  return <String, String>{'t2s': t2s, 's2t': s2t};
}

final class _IsolateWorkerHandle implements JsWorkerHandle {
  _IsolateWorkerHandle({
    required this._isolate,
    required this._toWorker,
    required this._fromWorker,
    required this._subscription,
    required this._messages,
  });

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;
  final StreamSubscription<Object?> _subscription;
  final StreamController<Map<String, Object?>> _messages;

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  @override
  void send(Map<String, Object?> message) => _toWorker.send(message);

  @override
  void kill() {
    _isolate.kill(priority: Isolate.immediate);
    _fromWorker.close();
    unawaited(_subscription.cancel());
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }
}

// 主循环：建一次运行时，然后分发消息直到关闭。
// 不写 try/catch：原生错误交给桥的硬预算发现并重建 worker。
Future<void> _quickJsWorkerMain(List<Object?> bootstrap) async {
  final Object? port = bootstrap.isNotEmpty ? bootstrap[0] : null;
  final Object? timeoutMs = bootstrap.length > 1 ? bootstrap[1] : null;
  final Object? memoryLimit = bootstrap.length > 2 ? bootstrap[2] : null;
  final Object? zhAssets = bootstrap.length > 3 ? bootstrap[3] : null;
  if (port is! SendPort || timeoutMs is! int || memoryLimit is! int) {
    return;
  }
  final Map<Object?, Object?> tables = zhAssets is Map
      ? zhAssets
      : const <Object?, Object?>{};

  final ReceivePort fromBridge = ReceivePort();
  port.send(<String, Object?>{'type': 'ready', 'port': fromBridge.sendPort});

  final JavascriptRuntime runtime = getJavascriptRuntime(
    timeout: timeoutMs,
    memoryLimit: memoryLimit,
    // 不装 console / 定时器等 Web API，只留纯 ECMAScript；重绑防护靠每个 job 重跑前奏。
    webApis: const JsWebApis.none(),
  );
  final _Worker worker = _Worker(
    runtime,
    port,
    zhTables: ZhTables(
      t2sText: tables['t2s'] is String ? tables['t2s'] as String : null,
      s2tText: tables['s2t'] is String ? tables['s2t'] as String : null,
    ),
  );
  worker.installBindings();

  await for (final Object? raw in fromBridge) {
    if (raw is! Map) {
      continue;
    }
    final Map<String, Object?> envelope = Map<String, Object?>.from(raw);
    switch (envelope['type']) {
      case 'evaluate':
        // 不能 await：脚本可能停在 `await http.get(...)` 上，答复要靠这条循环继续分发。
        unawaited(worker.evaluate(envelope));
      case 'hostResult':
        worker.answerHostCall(envelope);
      case 'close':
        runtime.dispose();
        port.send(<String, Object?>{'type': 'closed'});
        fromBridge.close();

        return;
    }
  }
}

// 一个 worker 的状态：复用的运行时，加上在途的绑定调用。
final class _Worker {
  _Worker(this._runtime, this._toBridge, {required this._zhTables});

  final JavascriptRuntime _runtime;
  final SendPort _toBridge;

  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextCallId = 0;

  // 当前 job 的变量表：从快照播种，随结果回传；null 表示脚本删除了该变量。
  Map<String, String?> _variables = <String, String?>{};

  // 当前 job 的**每源**变量表（`source.getVariable`），同样从快照播种、随结果回传。
  Map<String, String?> _sourceVariables = <String, String?>{};

  // 当前 job 的登录头（`source.getLoginHeader` / `putLoginHeader`，M25/S3b）：随 job 进来，
  // 写过后随结果回传（桥据此写穿并合并 Cookie）。
  JsLoginHeaderSlot _loginHeader = JsLoginHeaderSlot(null);

  // 当前 job 是否拿到了 `infoMap`（M25/S3b）：没拿到就不该凭空造一个对象，也不必回传。
  bool _infoMapSeeded = false;

  // 一趟重放已经拿到的同步答案；下一趟从这里同步返回（ADR-0076 §决策 1）。
  final JsSyncCache _syncCache = JsSyncCache();

  // 本趟遇到但缓存里没有的同步调用；非 null 表示这趟作废、取页后重跑。
  JsSyncRequest? _pendingSync;

  // 本 job 已经取过几次页。
  int _passes = 0;

  // `java.setContent` 换掉的页级 scope；`parse.*` 携带它去宿主。每趟重置（重跑会再设一次）。
  String? _contentOverride;

  // bookName / title 的内置值；阶段不知道时为空。
  Map<String, String> _named = const <String, String>{};

  // 本 job 查询过的字体（`java.queryTTF` 的句柄表，ADR-0068 增补决策 9）。
  // 字体不进脚本、也不跨 job：一个 job 结束时清空，句柄 id 不复用。
  final JsFontRegistry _fonts = JsFontRegistry();

  // 本 job 创建的对称密码器（`java.createSymmetricCrypto` 的句柄表，M25/S3a）：同一套契约。
  final JsSymmetricRegistry _ciphers = JsSymmetricRegistry();

  // `cache.*`（M25/S3b）：上游是持久表，本仓只做内存 LRU，随 worker 存亡。
  final JsCacheStore _cacheStore = JsCacheStore();

  // 两张简繁码表（`java.t2s` / `java.s2t`）：随 worker 存亡，解析懒（M25/S3b）。
  final ZhTables _zhTables;

  // 本 job 的 helper 上下文；码表在 `evaluate` 里按脚本内容先行加载。
  JsHelperContext _helpers = const JsHelperContext();

  // sync 绑定在本隔离体内直接答复；http / parse 返回 Future，由引擎转成 Promise。
  void installBindings() {
    // `crypto.*` 与 `java.*` 的字节/密钥族是同一批纯计算：走同一个通道，由一个解码器分发
    // （M25/S3a）。载荷可能是 JSON 字符串（老的四个 `crypto.*` 动词）或对象（字节族要原样过桥）。
    _runtime.onMessage(
      'crypto',
      (Object? args) => applyJsCryptoCall(args, ciphers: _ciphers),
    );
    // 纯计算族（M25/S3b）：UUID / 时间格式化 / 章节号 / URL 拆解 / HTML 格式化 / 简繁转换。
    _runtime.onMessage(
      jsHelperBinding,
      (Object? args) => applyJsHelperCall(args, _helpers),
    );
    // `cache.*`（M25/S3b）：同一个 isolate 内的内存 LRU，同步回答。
    _runtime.onMessage(jsCacheBinding, _cacheStore.apply);
    _runtime.onMessage('log', (Object? args) {
      if (args is! Map) {
        return null;
      }

      _toBridge.send(<String, Object?>{
        'type': 'log',
        'level': args['level'],
        'message': args['message'],
      });

      return null;
    });
    _runtime.onMessage(
      jsHttpBinding,
      (Object? args) => _callHost(jsHttpBinding, args),
    );
    _runtime.onMessage(
      jsParseBinding,
      (Object? args) => _callHost(jsParseBinding, _withPageContent(args)),
    );
    // 验证族（ADR-0068 §决策 5）：等的是人，桥会暂停硬预算并免掉调用额度。
    _runtime.onMessage(
      jsVerifyBinding,
      (Object? args) => _callHost(jsVerifyBinding, args),
    );
    // java.* 在本 isolate 内完成，所以 JS 同步拿到值。
    _runtime.onMessage(jsJavaBinding, _applyJava);
    // toast 是单向的：转发给宿主后不等它，规则不会被一条提示挡住（ADR-0076 §决策 1）。
    _runtime.onMessage(jsToastBinding, (Object? args) {
      unawaited(_notify(jsToastBinding, args));

      return '';
    });
    // `java.openUrl` 同样单向：宿主弹确认框、开浏览器，规则不等（M25/S3b）。
    _runtime.onMessage(jsOpenUrlBinding, (Object? args) {
      unawaited(_notify(jsOpenUrlBinding, args));

      return '';
    });
    // 每源变量也只在 isolate 内转一图：快照进来、写入随结果出去。
    _runtime.onMessage(
      jsSourceBinding,
      (Object? args) =>
          applyJsSourceCall(_sourceVariables, args, loginHeader: _loginHeader),
    );
    // 同步族先问缓存；命中就当场答复，未命中就抛哨兵，由 evaluate 取页后重跑。
    _runtime.onMessage(jsSyncBinding, _applySync);
  }

  Object? _applySync(Object? args) {
    final JsSyncRequest? request = decodeJsSyncRequest(args);
    if (request == null) {
      return jsonEncode(<String, Object?>{
        'ok': false,
        'message': 'malformed synchronous call',
      });
    }
    final JsSyncEntry? cached = _syncCache.lookup(request);
    if (cached != null) {
      return jsonEncode(cached.toEnvelope());
    }
    // 第一次见到这个调用：记下来，答复一个失败信封让脚本停下（规则自己的 try/catch 也能拖住它，
    // 但 evaluate 在脚本结束后仍然会重跑，所以吞掉哨兵不会让结果错）。
    _pendingSync = request;

    return jsonEncode(<String, Object?>{
      'ok': false,
      'message': 'replay pending',
    });
  }

  Object? _applyJava(Object? args) {
    // `java.setContent(html)` 只是换掉本 job 的页级 scope，不离开 isolate、也不回传变量。
    if (args is Map && args['operation'] == 'setContent') {
      final Object? value = args['value'];
      if (value is! String) {
        return '{"ok":false}';
      }
      _contentOverride = value;

      return '{"ok":true}';
    }

    return applyJsJavaCall(_variables, args, named: _named, fonts: _fonts);
  }

  // `java.setContent` 之后的 `parse.*` 一律带覆盖后的正文：宿主据此重建页级 scope。
  Object? _withPageContent(Object? args) {
    final String? content = _contentOverride;
    if (content == null || args is! Map) {
      return args;
    }
    final Map<Object?, Object?> extended = Map<Object?, Object?>.of(args);
    extended['content'] = content;

    return extended;
  }

  Future<void> evaluate(Object? envelope) async {
    // 上一个 job 未答复的调用不再有意义，桥也已经不再认它。
    _pending.clear();
    _variables = <String, String?>{};
    _sourceVariables = <String, String?>{};
    _loginHeader = JsLoginHeaderSlot(null);
    _fonts.clear();
    _ciphers.clear();
    _syncCache.clear();
    _pendingSync = null;
    _passes = 0;
    final Object? job = envelope is Map ? envelope['job'] : null;
    if (job is! Map) {
      _toBridge.send(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': 'malformed job',
        'elapsedMs': 0,
      });

      return;
    }

    final Map<String, Object?> fields = Map<String, Object?>.from(job);
    // `infoMap`（M25/S3b）随**信封**下来（桥按源快照），落进 job 字段后由前奏绑成对象。
    final Object? seedInfoMap = envelope is Map ? envelope['infoMap'] : null;
    _infoMapSeeded = seedInfoMap is Map;
    if (seedInfoMap is Map) {
      fields['infoMap'] = seedInfoMap;
    }
    // 每趟重跑都从快照重新播种：只有取页成功的那一趟的写入才算数（ADR-0076 §决策 1）。
    final Map<String, String?> seedVariables = decodeJsVariables(
      fields['variables'],
    );
    final Map<String, String?> seedSourceVariables = decodeJsVariables(
      fields['sourceVariables'],
    );
    // 登录头同样从快照播种：每趟重跑都回到 job 开始时的那份值（写入只算最后一趟）。
    final Object? seedLoginHeader = envelope is Map
        ? envelope['loginHeader']
        : null;
    _named = decodeJsNamedContext(fields);
    // 简繁码表按需解析（`java.t2s` / `java.s2t`），并挂进本 job 的 helper 上下文。
    final String? scriptText = fields['script'] is String
        ? fields['script'] as String
        : null;
    final String? libText = fields['jsLib'] is String
        ? fields['jsLib'] as String
        : null;
    final ({bool t2s, bool s2t}) needs = ZhTables.needsOf(
      scriptText ?? '',
      libText,
    );
    _helpers = JsHelperContext(
      t2s: _zhTables.t2s(needed: needs.t2s),
      s2t: _zhTables.s2t(needed: needs.s2t),
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    JsEvalResult result;
    while (true) {
      _variables = Map<String, String?>.of(seedVariables);
      _sourceVariables = Map<String, String?>.of(seedSourceVariables);
      _loginHeader = JsLoginHeaderSlot(
        seedLoginHeader is String ? seedLoginHeader : null,
      );
      _contentOverride = null;
      _pendingSync = null;
      result = _runtime.evaluate(_evaluationSource(fields));
      if (result.rawResult is Future) {
        // 脚本停在 Promise 上：引擎把 JS Promise 换成 Dart Future，等待期间主循环继续
        // 分发 hostResult，所以这里可以安全地等。
        result = await _runtime.handlePromise(result);
      }
      final JsSyncRequest? pending = _pendingSync;
      if (pending == null) {
        break;
      }
      if (_passes >= defaultJsMaxReplayPasses) {
        // 超过上限就停：与其让规则重跑 16 次后超时，不如告诉调用方「这条源重放不了」。
        stopwatch.stop();
        _toBridge.send(<String, Object?>{
          'type': 'result',
          'ok': false,
          'error': 'replay limit exceeded',
          'replayLimit': true,
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'variables': _variables,
          'sourceVariables': _sourceVariables,
          ..._touchedLoginHeader(),
          ..._reportedInfoMap(),
        });

        return;
      }
      _passes++;
      _syncCache.store(pending, await _fetchSync(pending));
    }
    stopwatch.stop();

    if (result.isError) {
      _toBridge.send(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': result.stringResult,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        // 脚本报错前可能已经 java.put：上游的写入立即生效，失败也要回传。
        'variables': _variables,
        'sourceVariables': _sourceVariables,
        ..._touchedLoginHeader(),
        ..._reportedInfoMap(),
      });

      return;
    }

    final Map<String, Object?>? decoded = _decodeEnvelope(result.stringResult);
    if (decoded == null) {
      _toBridge.send(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': 'unreadable result envelope',
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'variables': _variables,
        'sourceVariables': _sourceVariables,
        ..._touchedLoginHeader(),
        ..._reportedInfoMap(),
      });

      return;
    }

    _toBridge.send(<String, Object?>{
      'type': 'result',
      'ok': decoded['ok'] == true,
      'value': decoded['value'],
      'error': decoded['error'],
      // 库脚本（`jsLib`）的失败要单独标记：桥据此把 rulePath 标成 js:lib（ADR-0078 S1）。
      'libError': decoded['libError'] == true,
      'elapsedMs': stopwatch.elapsedMilliseconds,
      'variables': _variables,
      'sourceVariables': _sourceVariables,
      ..._touchedLoginHeader(),
      ..._reportedInfoMap(),
    });
  }

  // 登录头只在规则**写过**时随结果回传：`source.getLoginHeader()` 一次不该触发一次落库。
  Map<String, Object?> _touchedLoginHeader() => _loginHeader.touched
      ? <String, Object?>{'loginHeader': _loginHeader.value}
      : const <String, Object?>{};

  // `infoMap` 是**可写**的小表（上游给规则的是同一个对象）：job 结束时把脚本里那份读回来，
  // 桥据此合并进内存 store，下一条探索规则就看得见这次写进去的值。
  //
  // 用一次独立的求值读，而不是在规则作用域里回传：规则可能把结果换成 Promise、也可能抛错，
  // 而这一个小对象两种情况下都得带回宿主。job 没拿到 `infoMap` 时一次求值都不做。
  Map<String, Object?> _reportedInfoMap() {
    if (!_infoMapSeeded) {
      return const <String, Object?>{};
    }
    final Map<String, String> values = <String, String>{};
    final String text = _readInfoMapJson();
    if (text.isEmpty || text == 'null') {
      return <String, Object?>{'infoMap': values};
    }
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is Map) {
        for (final MapEntry<Object?, Object?> entry in decoded.entries) {
          final Object? key = entry.key;
          final Object? value = entry.value;
          if (key is String && value != null) {
            // 上游的表是 `Map<String, String>`：数字 / 布尔一律按字符串收下。
            values[key] = value is String ? value : value.toString();
          }
        }
      }
    } on FormatException {
      // 规则把 `infoMap` 换成了不能序列化的东西：这一趟不合并，也不影响规则自己的答案。
      return const <String, Object?>{};
    }

    return <String, Object?>{'infoMap': values};
  }

  String _readInfoMapJson() {
    final JsEvalResult read = _runtime.evaluate(
      'JSON.stringify(typeof infoMap === "undefined" || infoMap === null '
      '? null : infoMap)',
    );
    if (read.isError) {
      return '';
    }

    return read.stringResult;
  }

  // 单向转发：答复到了也只是清掉 callId，规则不会等它。
  Future<void> _notify(String binding, Object? args) async {
    try {
      await _callHost(binding, args);
    } on Exception {
      // 宿主不收就不收：提示是一句可有可无的话，不该让规则失败。
    }
  }

  // 取一次页并把答案记进缓存。传输失败也是答案（规则自己的 try/catch 靠它工作）。
  Future<JsSyncEntry> _fetchSync(JsSyncRequest request) async {
    try {
      final Object? value = await _callHost(jsSyncBinding, request.toJson());

      return JsSyncEntry.value(value);
    } on Exception catch (error) {
      return JsSyncEntry.failure(_plainMessage(error));
    }
  }

  // 答复失败会拒绝脚本的 Promise；是否连 job 一起判失败由桥决定。
  void answerHostCall(Map<String, Object?> message) {
    final JsHostReply? reply = JsHostReply.fromJson(message);
    final Completer<Object?>? pending = reply == null
        ? null
        : _pending.remove(reply.callId);
    if (reply == null || pending == null) {
      // 畸形或无人等待的答复不得静默丢弃：送回宿主记一条。
      _toBridge.send(<String, Object?>{
        'type': 'log',
        'level': 'warn',
        'message': 'ignored a host reply that no binding call was waiting for',
      });

      return;
    }

    if (reply.isSuccess) {
      pending.complete(reply.value);

      return;
    }
    pending.completeError(Exception(reply.message));
  }

  // 需要离开隔离体的调用：发信封后按 callId 等答复。
  Future<Object?> _callHost(String binding, Object? args) {
    final int callId = _nextCallId++;
    final Completer<Object?> completer = Completer<Object?>();
    _pending[callId] = completer;
    _toBridge.send(
      JsHostCall(callId: callId, binding: binding, args: args).toJson(),
    );

    return completer.future;
  }
}

// 拼出一个 job 的脚本：沙箱、绑定，最后是规则本身。
// 沙箱每个 job 都重跑：运行时复用且 globalThis 共享，规则的重绑定会漏给下一个 job。
String _evaluationSource(Map<String, Object?> fields) {
  final Object? key = fields['key'];
  // 响应对象优先于普通 `result`：登录拦截器的 `result` 是响应，不是页面正文（ADR-0068 增补）。
  final Object? result = fields['response'] ?? fields['result'];
  final StringBuffer buffer = StringBuffer()
    ..writeln(_prelude)
    ..writeln('var baseUrl = ${jsonEncode(fields['baseUrl'])};')
    ..writeln('var result = __sandboxValue(${jsonEncode(result)});')
    ..writeln('var page = ${jsonEncode(fields['page'])};')
    ..writeln(
      'var source = __sandboxSource(${jsonEncode(fields['source'])}, '
      '${jsonEncode(fields['loginInfo'] ?? const <String, String>{})});',
    );
  final Object? book = fields['book'];
  buffer.writeln(
    'var book = __sandboxBook(${book == null ? 'null' : jsonEncode(book)});',
  );
  // M25/S3b 的五条全局绑定（上游 `AnalyzeRule.evalJS` / `AnalyzeUrl.evalJS`）：页正文、章节、
  // 下一章地址、阶段标记与探索分类变量。缺席一律给 `null` / `false`——上游那里也是这几个值，
  // 用 `undefined` 会让 `String(src)` 拼出 "undefined"。
  buffer.writeln('var src = ${jsonEncode(fields['src'])};');
  buffer.writeln(
    'var chapter = __sandboxChapter(${jsonEncode(fields['chapter'])});',
  );
  buffer.writeln(
    'var nextChapterUrl = ${jsonEncode(fields['nextChapterUrl'])};',
  );
  buffer.writeln(
    'var fromBookInfo = ${jsonEncode(fields['fromBookInfo'] == true)};',
  );
  buffer.writeln(
    'var infoMap = __sandboxInfoMap('
    '${jsonEncode(fields['infoMap'] ?? const <String, String>{})});',
  );
  // key 只有 URL 规则才有；缺席时删掉 globalThis 属性（var 建的属性删不掉，会漏到下一个 job）。
  if (key != null) {
    buffer.writeln('globalThis.key = ${jsonEncode(key)};');
  }
  // `java.getWebViewUA` / `java.androidId` 是随 job 进来的常量（M25/S3b）；缺席时给空串，
  // 而不是 `undefined`（规则拿它拼 header，空白比 `undefined` 更容易被发现）。
  buffer.writeln(
    'globalThis.__webViewUA = ${jsonEncode(fields['webViewUA'] ?? '')};',
  );
  buffer.writeln(
    'globalThis.__androidId = ${jsonEncode(fields['androidId'] ?? '')};',
  );
  final String script = _asString(fields['script']);
  if (fields['titleFormat'] == true) {
    // 标题格式化是「一条脚本跑 N 章」，不是「跑一次脚本」：不套 __runRule，直接进循环运行器。
    final Object? lib = fields['jsLib'];
    buffer.write(
      '__formatTitles('
      '${lib is String && lib.isNotEmpty ? jsonEncode(lib) : 'null'}, '
      '${jsonEncode(script)}, '
      '${jsonEncode(fields['titleFormatChapters'] ?? const <Object?>[])})',
    );

    return buffer.toString();
  }
  final Object? jsLib = fields['jsLib'];
  if (jsLib is String && jsLib.isNotEmpty) {
    buffer.write(
      '__runRuleWithLib(${jsonEncode(jsLib)}, ${jsonEncode(script)})',
    );
  } else {
    buffer.write('__runRule(${jsonEncode(script)})');
  }

  return buffer.toString();
}

String _asString(Object? value) => value is String ? value : '';

// 桥把失败写成 kind 名，包在 Exception 里；沙箱只该看到那个名字。
String _plainMessage(Exception error) =>
    error.toString().replaceFirst(RegExp(r'^Exception: '), '');

// 语法错误会让前奏本身不可解析，这里返回 null，由调用方报 js:error。
Map<String, Object?>? _decodeEnvelope(String raw) {
  try {
    final Object? decoded = jsonDecode(raw);

    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

// 沙箱面：变量助手、同步的 log.* / crypto.*，以及 http.* / parse.* 两个宿主绑定。
// 每个 job 前都会重跑，所以这里每条语句都必须幂等；sendMessage 的载荷统一是 JSON 字符串。
// __runRule 对 await 的规则返回 Promise，其余返回字符串，最终都收敛成同一个 JSON 信封。
const String _prelude = r'''
(function () {
  var forbidden = [
    'setTimeout', 'setInterval', 'clearTimeout', 'clearInterval',
    'queueMicrotask', 'setImmediate', 'console',
    'atob', 'btoa', 'structuredClone', 'performance',
    'require', 'process', 'XMLHttpRequest', 'fetch',
    'navigator', 'location', 'window', 'global', 'self',
    'key'
  ];
  for (var index = 0; index < forbidden.length; index++) {
    delete globalThis[forbidden[index]];
  }
})();

globalThis.__envelope = function (envelope) {
  try {
    return JSON.stringify(envelope);
  } catch (error) {
    return JSON.stringify({ ok: envelope.ok === true, value: String(envelope.value) });
  }
};

globalThis.__errorMessage = function (error) {
  return (error && error.message) ? String(error.message) : String(error);
};

globalThis.__runRule = function (scriptText) {
  var value;
  try {
    value = eval(scriptText);
  } catch (error) {
    return __envelope({ ok: false, error: __errorMessage(error) });
  }
  return __settle(value);
};

// `__runRule` 的收尾：Promise 的规则也要收敛成同一个信封。
globalThis.__settle = function (value) {
  if (value && typeof value.then === 'function') {
    return value.then(
      function (settled) {
        return __envelope({ ok: true, value: settled === undefined ? null : settled });
      },
      function (error) {
        return __envelope({ ok: false, error: __errorMessage(error) });
      }
    );
  }
  return __envelope({ ok: true, value: value === undefined ? null : value });
};

// 书源自带的 `jsLib`（ADR-0078 S1）：先把它跑进**本函数的变量环境**，再跑规则。
//
// 两次 `eval` 都在 `__runRuleWithLib` 的函数作用域里，所以库里的 `var` / `function`
// 对规则是可见的；反过来它们不会漏到 globalThis（上游用 `preventExtensions` 达到同一效果）。
// 差异：库顶层的 `let` / `const` 只属于第一次 eval 的词法环境，规则看不见——上游的 Rhino 是
// ES5，本来也不认它们（登记在 book-source.md §6）。
globalThis.__runRuleWithLib = function (libText, scriptText) {
  try {
    eval(libText);
  } catch (error) {
    // 库坏了就是这一条规则的失败，但错误要能一眼看出不是规则的错（rulePath 带 js:lib）。
    return __envelope({
      ok: false,
      error: __errorMessage(error),
      libError: true
    });
  }
  var value;
  try {
    value = eval(scriptText);
  } catch (error) {
    return __envelope({ ok: false, error: __errorMessage(error) });
  }
  return __settle(value);
};

// `tocRule.formatJs`（ADR-0078 S2）：一条脚本，**一个作用域里逐章跑**。
//
// 上游把 `index` / `chapter` / `title` 每轮重绑、`gInt` 只初始化一次（`BookChapterList.kt:141-163`），
// 所以计数器的自增会跨章累积。这里用同一函数的 `var` 兑现同一条语义；答案与输入等长：
// 非空字符串替换标题，`null` 表示「保持原标题」（脚本报错也按 null 处理，与上游 onFailure 一致）。
globalThis.__formatTitles = function (libText, scriptText, chapters) {
  if (libText) {
    try {
      // 库脚本与规则同一个函数作用域（同 __runRuleWithLib）；库坏了就是这一条规则的失败。
      eval(libText);
    } catch (error) {
      return __envelope({
        ok: false,
        error: __errorMessage(error),
        libError: true
      });
    }
  }
  var index = 0;
  var chapter = null;
  var title = '';
  var gInt = 0;
  var titles = [];
  for (var i = 0; i < chapters.length; i++) {
    chapter = chapters[i];
    index = i + 1;
    title = (chapter && chapter.title !== undefined && chapter.title !== null)
      ? String(chapter.title) : '';
    var value = null;
    try {
      value = eval(scriptText);
    } catch (error) {
      value = null;
    }
    if (value === null || value === undefined) {
      titles.push(null);
    } else {
      var text = String(value);
      titles.push(text === '' ? null : text);
    }
  }
  return __envelope({ ok: true, value: titles });
};

globalThis.__helper = function (payload) {
  var answer = sendMessage('helper', payload);
  if (answer !== null && typeof answer === 'object' && answer.__error !== undefined) {
    throw new Error(String(answer.__error));
  }
  return answer;
};

// `cache.*`（M25/S3b）：同一个 isolate 内的内存 LRU。上游是「内存 + 持久表」两层，
// 本仓只做内存（差异登记在 book-source.md §6）。
globalThis.cache = (function () {
  var call = function (payload) {
    var answer = sendMessage('cache', payload);
    if (answer !== null && typeof answer === 'object' && answer.__error !== undefined) {
      throw new Error(String(answer.__error));
    }
    return answer === undefined ? null : answer;
  };
  return Object.freeze({
    put: function (key, value, saveTime) {
      var payload = { operation: 'put', key: String(key), value: value };
      if (typeof saveTime === 'number') { payload.saveTime = saveTime; }
      return call(payload);
    },
    putMemory: function (key, value) {
      return call({ operation: 'putMemory', key: String(key), value: value });
    },
    get: function (key) { return call({ operation: 'get', key: String(key) }); },
    getFromMemory: function (key) {
      return call({ operation: 'getFromMemory', key: String(key) });
    },
    getInt: function (key) { return call({ operation: 'getInt', key: String(key) }); },
    getLong: function (key) { return call({ operation: 'getLong', key: String(key) }); },
    getDouble: function (key) { return call({ operation: 'getDouble', key: String(key) }); },
    delete: function (key) { return call({ operation: 'delete', key: String(key) }); },
    deleteMemory: function (key) {
      return call({ operation: 'deleteMemory', key: String(key) });
    }
  });
})();

globalThis.__crypto = function (operation, value) {
  var result = sendMessage(
    'crypto',
    JSON.stringify({ operation: operation, value: String(value) })
  );
  if (result === null || result === undefined) {
    throw new Error('crypto.' + operation + ' failed');
  }
  return result;
};

// 字节族与密钥族（M25/S3a）：同一通道，但载荷是**对象**而不是 JSON 字符串，于是 `Uint8Array`
// 原样过桥（宿主看到 Uint8List），回答也常常是 `Uint8Array`——`byte[]` 在沙箱里就是它。
//
// 失败用 `{__error: message}` 表达：字节/句柄族的失败原因（密钥长度、未知 transformation、
// 句柄过期）必须能被规则和调试者读到，不能退化成 `undefined is not a function`。
globalThis.__cryptoCall = function (payload) {
  var answer = sendMessage('crypto', payload);
  if (answer !== null && typeof answer === 'object' && answer.__error !== undefined) {
    throw new Error(String(answer.__error));
  }
  return answer;
};

// `null` 是「这条输入没有字节」（上游 `base64DecodeToByteArray('')` 也答 null），不是错误；
// 但反驳的是调用方要一个字节数组，所以这里照样抛。
globalThis.__cryptoBytes = function (payload) {
  var answer = __cryptoCall(payload);
  if (answer === null || answer === undefined) {
    throw new Error('java.' + payload.operation + ' cannot decode its input');
  }
  return answer;
};

globalThis.__b64Bytes = function (value) {
  return __cryptoBytes({ operation: 'base64DecodeToByteArray', value: String(value) });
};

globalThis.__textBytes = function (value, charset) {
  var payload = { operation: 'strToBytes', value: String(value) };
  if (charset !== undefined && charset !== null) {
    payload.charset = String(charset);
  }
  return __cryptoBytes(payload);
};

// `SymmetricCrypto` 句柄（M25/S3a）：与字体句柄同一套契约——密码器不进脚本，脚本只拿 id。
// 方法名与上游 `SymmetricCryptoAndroid` 一一对应；`setIv` 与上游一样返回自身，可以链式写。
globalThis.__symmetricApi = function (id) {
  var call = function (method, value, charset) {
    var payload = { operation: 'symmetricCall', id: id, method: method };
    if (value !== undefined && value !== null) {
      payload.value = value;
    }
    if (charset !== undefined && charset !== null) {
      payload.charset = String(charset);
    }
    return __cryptoCall(payload);
  };
  var api = {};
  api.setIv = function (iv) { call('setIv', iv); return api; };
  api.encrypt = function (data) { return call('encrypt', data); };
  api.encryptBase64 = function (data, charset) {
    return call('encryptBase64', data, charset);
  };
  api.encryptHex = function (data) { return call('encryptHex', data); };
  api.encryptStr = function (data) { return call('encryptStr', data); };
  api.decrypt = function (data) { return call('decrypt', data); };
  api.decryptStr = function (data) { return call('decryptStr', data); };
  api.decryptHex = function (data) { return call('decryptHex', data); };
  api.decryptBase64 = function (data) { return call('decryptBase64', data); };
  return api;
};

globalThis.__symmetricCreate = function (transformation, key, iv) {
  var payload = { operation: 'symmetricCreate', transformation: String(transformation) };
  if (key !== undefined && key !== null) {
    payload.key = key;
  }
  if (iv !== undefined && iv !== null) {
    payload.iv = iv;
  }
  var handle = __cryptoCall(payload);
  return __symmetricApi(handle.id);
};

globalThis.log = Object.freeze({
  debug: function (message) {
    sendMessage('log', JSON.stringify({ level: 'debug', message: String(message) }));
  },
  info: function (message) {
    sendMessage('log', JSON.stringify({ level: 'info', message: String(message) }));
  },
  warn: function (message) {
    sendMessage('log', JSON.stringify({ level: 'warn', message: String(message) }));
  },
  error: function (message) {
    sendMessage('log', JSON.stringify({ level: 'error', message: String(message) }));
  }
});

globalThis.crypto = Object.freeze({
  md5: function (value) { return __crypto('md5', value); },
  sha1: function (value) { return __crypto('sha1', value); },
  base64Encode: function (value) { return __crypto('base64Encode', value); },
  base64Decode: function (value) { return __crypto('base64Decode', value); }
});

globalThis.__java = function (call) {
  var envelope = null;
  try {
    envelope = JSON.parse(String(sendMessage('java', JSON.stringify(call))));
  } catch (error) {
    envelope = null;
  }
  if (!envelope || envelope.ok !== true) {
    // 写没有返回值，所以「拿不到值」不能当失败；畸形的那个由信封的 ok:false 表达（§6）。
    throw new Error('java.' + call.operation + ' failed');
  }
  return (envelope.value === null || envelope.value === undefined)
    ? '' : String(envelope.value);
};

// 与 __java 同一通道，但**不**把回答串成字符串：字体句柄之类的对象要原样交给脚本。
globalThis.__javaObject = function (call) {
  var envelope = null;
  try {
    envelope = JSON.parse(String(sendMessage('java', JSON.stringify(call))));
  } catch (error) {
    envelope = null;
  }
  if (!envelope || envelope.ok !== true) {
    throw new Error('java.' + call.operation + ' failed');
  }
  return (envelope.value === undefined) ? null : envelope.value;
};

// 具名拒绝族（ADR-0037 §决策 5）：命中即给可读错误，不落到 `undefined is not a function`。
globalThis.__javaRejected = function (name) {
  return function () {
    throw new Error('java.' + name + ' is not supported (M2): see book-source.md §11');
  };
};

// 同步族（ADR-0076 §决策 1）：上游在这里阻塞 Rhino 线程，本仓用「取页缓存 + 从头重跑」仿真。
// 命中缓存就当场返回；未命中则收到一个失败信封（worker 同时记下这次调用），脚本停在这一行，
// 宿主取完页后整条规则从头重跑，下一趟这个调用会同步拿到值。
globalThis.__sync = function (operation, payload) {
  var envelope = null;
  try {
    envelope = JSON.parse(String(sendMessage('sync', JSON.stringify(payload))));
  } catch (error) {
    envelope = null;
  }
  if (!envelope) {
    throw new Error('java.' + operation + ' failed');
  }
  if (envelope.ok === true) {
    return (envelope.value === undefined) ? null : envelope.value;
  }
  throw new Error('java.' + operation + ' failed: ' + String(envelope.message));
};

// 拼一次同步调用的信封：缺省的 body / key / headers 不送，与宿主的解码一一对应。
globalThis.__syncCall = function (operation, call) {
  var payload = { operation: operation, url: String(call.url) };
  if (call.body !== undefined && call.body !== null) {
    payload.body = String(call.body);
  }
  if (call.key !== undefined && call.key !== null) {
    payload.key = String(call.key);
  }
  if (call.headers !== undefined && call.headers !== null) {
    payload.headers = __headerMap(call.headers);
  }
  return payload;
};

globalThis.__headerMap = function (headers) {
  if (typeof headers !== 'object') {
    throw new Error('java.ajax: headers must be an object');
  }
  var map = {};
  for (var key in headers) {
    if (Object.prototype.hasOwnProperty.call(headers, key)) {
      map[key] = String(headers[key]);
    }
  }
  return map;
};

// 每源变量（`source.getVariable` / `setVariable`）：与 `java.get` 同一条 isolate 内通道，
// 但存的是**持久**表（随结果回传，由桥写穿存储）。
globalThis.__sourceCall = function (call) {
  var envelope = null;
  try {
    envelope = JSON.parse(String(sendMessage('source', JSON.stringify(call))));
  } catch (error) {
    envelope = null;
  }
  if (!envelope || envelope.ok !== true) {
    throw new Error('source.' + call.operation + ' failed');
  }
  return (envelope.value === null || envelope.value === undefined)
    ? '' : String(envelope.value);
};

// 登录头（`source.getLoginHeader` / `putLoginHeader`，M25/S3b）走同一个通道，但答案**原样**返回：
// 上游 `getLoginHeader()` 没有值时是 null，而 `getVariable` 是空串——两者用 `if (!x)` 都成立，
// 可是 `JSON.parse(null)` 与 `JSON.parse('')` 的报错长得不一样，调试时前者好认。
globalThis.__sourceRawCall = function (call) {
  var envelope = null;
  try {
    envelope = JSON.parse(String(sendMessage('source', JSON.stringify(call))));
  } catch (error) {
    envelope = null;
  }
  if (!envelope || envelope.ok !== true) {
    throw new Error('source.' + call.operation + ' failed');
  }
  return (envelope.value === undefined) ? null : envelope.value;
};

// 沙箱的 `book` 对象（ADR-0061 §决策 5 的数据面 + ADR-0062 §决策 2 的方法面）。
//
// 数据字段从 `JsBookInfo` 的 JSON 拷来，方法分两类：
// * `getVariable` / `putVariable` 是**规则变量**，与 `java.get` / `java.put` 同一张表——
//   上游 AnalyzeUrl 的 javaPut/javaGet 也是先写 book 的 variableMap（AnalyzeUrl.kt:390-406）；
// * `setType` / `setReverseToc` 在本仓没有对应的书籍状态：它们在本 job 内可读回，但**不影响**
//   宿主（章节顺序 / 书籍类型不变），差异登记在 ADR-0062 §决策 2。
// 每次 job 重建，所以这里不再 `Object.freeze`：规则自己的写入不会漏到下一份规则。
// 登录拦截器的响应对象（ADR-0068 增补）：`loginCheckJs` 的 `result` 不是页面正文，而是上游
// `StrResponse` 那一层——`body` 是属性（上游自己的 JS 助手就写 `getStrResponse().body`），
// `url()` / `code()` / `headers()` 是方法。Readori 风格的 `result.body()` 本仓不支持，命中会显式
// 报 `result.body is not a function`（差异登记在 book-source.md §6）。
//
// 方法不可枚举：脚本原样 `return result` 时，JSON 只带回 body / 状态码 / 头，宿主就能把它当作
// 替换后的响应。
globalThis.__sandboxStrResponse = function (data) {
  var url = (data.__url === undefined || data.__url === null) ? '' : String(data.__url);
  var body = (data.body === undefined || data.body === null) ? '' : String(data.body);
  var code = Number(data.__code) || 0;
  var headers = (data.__headers && typeof data.__headers === 'object') ? data.__headers : {};
  var response = {
    __strResponse: true,
    body: body,
    __url: url,
    __code: code,
    __headers: headers
  };
  var define = function (name, fn) {
    Object.defineProperty(response, name, { value: fn, enumerable: false });
  };
  define('url', function () { return url; });
  define('code', function () { return code; });
  define('headers', function () { return headers; });
  define('header', function (name) {
    var wanted = String(name).toLowerCase();
    for (var key in headers) {
      if (Object.prototype.hasOwnProperty.call(headers, key) &&
          key.toLowerCase() === wanted) {
        return headers[key];
      }
    }
    return null;
  });
  define('cookie', function () { return headers.cookie || ''; });
  define('contentType', function () { return headers['content-type'] || ''; });
  define('isSuccessful', function () { return code >= 200 && code < 300; });
  define('toString', function () { return body; });
  return response;
};

// 只有带标记的对象才是响应；其余（字符串 / 数组 / JSON 值）原样交给规则，`@js:` 的 result 语义不变。
globalThis.__sandboxValue = function (value) {
  if (value !== null && typeof value === 'object' && value.__strResponse === true) {
    return __sandboxStrResponse(value);
  }
  return value;
};

// `source` 对象：字段照旧冻结，另挂两个**登录信息**读取器（ADR-0072 §决策 3）。
// 它们是同步的纯读取：值随 job 进来（ADR-0034 的快照做法），不回写宿主。
globalThis.__sandboxSource = function (data, loginInfo) {
  var source = {};
  for (var field in data) {
    source[field] = data[field];
  }
  var info = loginInfo || {};
  source.getLoginInfoMap = function () {
    var copy = {};
    for (var key in info) {
      copy[key] = info[key];
    }
    return copy;
  };
  source.getLoginInfo = function () {
    return JSON.stringify(source.getLoginInfoMap());
  };
  // 每源持久变量（ADR-0076 §决策 1）：与 `java.get` / `java.put` 的规则变量不是同一张表，
  // 差别在持久性（`book-source.md` §6）。`putVariable` 是上游的另一种拼写，指同一件事。
  source.getVariable = function (key) {
    return __sourceCall({ operation: 'get', key: String(key) });
  };
  source.setVariable = function (key, value) {
    var call = { operation: 'put', key: String(key) };
    if (value !== undefined && value !== null) {
      call.value = String(value);
    }
    __sourceCall(call);
  };
  source.putVariable = source.setVariable;
  // 源身份（`BaseSource.getKey` / `getTag`）：上游分别答 `bookSourceUrl` / `bookSourceName`，
  // 两者本就在字段里，所以不需要过通道。
  source.getKey = function () {
    return source.url;
  };
  source.getTag = function () {
    return source.name;
  };
  // 登录头（M25/S3b）：值随 job 进来，写回的结果由桥写穿存储并把其中的 Cookie 合并进 Cookie 宗。
  source.getLoginHeader = function () {
    return __sourceRawCall({ operation: 'getLoginHeader' });
  };
  source.putLoginHeader = function (header) {
    if (typeof header !== 'string') {
      throw new Error('source.putLoginHeader: header must be a string');
    }
    __sourceRawCall({ operation: 'putLoginHeader', value: header });
  };
  // 规则内触发的登录：本仓把**同一段** `loginUrl` 脚本交给登录页（`SignIn`，ADR-0072 §决策 3），
  // 规则内部没有地方跑它（重入同一个 worker 会死锁），因此具名拒绝（book-source.md §11）。
  source.login = function () {
    throw new Error(
      'source.login() is not supported inside a rule (M25): ' +
      'use the sign-in page; see book-source.md §11');
  };
  return Object.freeze(source);
};

// 沙箱的 `chapter` 对象（上游 `AnalyzeRule.evalJS` 绑的 `BookChapter`）：字段来自 `JsChapterInfo`，
// 方法只有 `getVariable` / `putVariable`。上游把它们写在**章自己的**变量表里，本仓与 `book` 同样
// 落规则变量表（差异登记在 book-source.md §6）；`tocRule.formatJs` 的循环另有自己的 `chapter`。
// 沙箱的 `infoMap`（上游 `InfoMap.kt:10-40`）：**同一个对象**跨规则共享的小表，探索规则用它
// 记住 token / 分类参数。值随 job 下来、job 结束时宿主把整份读回去（`_reportedInfoMap`），所以
// 直接写属性的规则也能生效；`save()` / `saveNow()` 只是上游的持久化开关，本仓的值本来就在会话里
// （差异登记在 book-source.md §6），方法保留是为了让规则不报 "not a function"。
globalThis.__sandboxInfoMap = function (seed) {
  var data = seed || {};
  var define = function (name, fn) {
    Object.defineProperty(data, name, { value: fn, enumerable: false });
  };
  define('save', function () {});
  define('saveNow', function () {});
  define('get', function () { return data; });
  define('set', function (value) {
    if (value && typeof value === 'object') {
      for (var key in value) {
        if (Object.prototype.hasOwnProperty.call(value, key)) {
          data[key] = String(value[key]);
        }
      }
    }
  });
  return data;
};

globalThis.__sandboxChapter = function (data) {
  if (data === null || data === undefined) {
    return null;
  }
  var chapter = {};
  for (var field in data) {
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      chapter[field] = data[field];
    }
  }
  chapter.getVariable = function (key) {
    return __java({ operation: 'get', key: String(key) });
  };
  chapter.putVariable = function (key, value) {
    var call = { operation: 'put', key: String(key) };
    if (value !== undefined && value !== null) {
      call.value = String(value);
    }
    __java(call);
  };
  return chapter;
};

globalThis.__sandboxBook = function (data) {
  if (data === null || data === undefined) {
    return null;
  }
  var book = {};
  for (var field in data) {
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      book[field] = data[field];
    }
  }
  var state = { type: 0, reverseToc: false };
  book.type = state.type;
  book.getVariable = function (key) {
    return __java({ operation: 'get', key: String(key) });
  };
  book.putVariable = function (key, value) {
    var call = { operation: 'put', key: String(key) };
    if (value !== undefined && value !== null) {
      call.value = String(value);
    }
    __java(call);
  };
  book.setType = function (type) {
    state.type = Number(type) || 0;
    book.type = state.type;
  };
  book.getType = function () {
    return state.type;
  };
  book.setReverseToc = function (reverseToc) {
    state.reverseToc = reverseToc === true;
  };
  book.getReverseToc = function () {
    return state.reverseToc;
  };
  return book;
};

// 注意：`get` / `put` **不在**这个列表里——`book-source.md` §6 把 `java.get(key)` / `java.put(key,value)`
// 定义为**变量**读写（ADR-0034），它们的名字被占用；上游那套同步 HTTP 的 `get(url)` 仍然没有可用
// 拼写，只能走 `ajax` 这一族（ADR-0076 §决策 1）。
globalThis.__javaRejectedNames = [
  'downloadFile', 'cacheFile', 'importScript',
  // 非对称与签名：上游有，但语料里没有；连模式都不在支持面内（book-source.md §11）。
  'createAsymmetricCrypto', 'createSign'
];

globalThis.__javaInteropNames = ['lang', 'security', 'util', 'net', 'io', 'nio', 'math', 'text'];

// Rhino 的另一条互操作入口 `Packages.java.lang.…`（ADR-0037 §决策 5）：具名拒绝，
// 不让它落到 `Packages is not defined` 那种更难懂的错误。
globalThis.Packages = new Proxy({}, {
  get: function () {
    throw new Error('Packages.* interop is not supported (M2): see book-source.md §11');
  }
});

// 验证族（ADR-0068 §决策 5）：这些调用等的是**人**，所以走独立的 host 频道，返回 Promise。
// 上游是「同步阻塞」，本仓的沙箱不可能阻塞 QuickJS 去等宿主，因此规则里要 `await`（差异登记在
// book-source.md §6）。`startBrowser` 上游返回 void，这里同样不等结果（浮空 Promise 的错误吞掉，
// 页面本身已经打开）。
globalThis.__verify = function (operation, url, title, refetchAfterSuccess, html, script) {
  var payload = { operation: operation, url: String(url) };
  if (title !== undefined && title !== null) {
    payload.title = String(title);
  }
  if (refetchAfterSuccess !== undefined && refetchAfterSuccess !== null) {
    payload.refetchAfterSuccess = refetchAfterSuccess !== false;
  }
  if (html !== undefined && html !== null) {
    payload.html = String(html);
  }
  if (script !== undefined && script !== null) {
    payload.script = String(script);
  }
  return sendMessage('verify', JSON.stringify(payload));
};

// `cookie` 对象（ADR-0076 §决策 1）：与 `java.getCookie` 同一通道，只是上游的另一种拼写。
globalThis.cookie = Object.freeze({
  getCookie: function (url, key) {
    return __sync('cookieGet', __syncCall('cookieGet', { url: url, key: key }));
  },
  setCookie: function (url, value) {
    return __sync('cookieSet', __syncCall('cookieSet', { url: url, body: value }));
  },
  removeCookie: function (url, key) {
    return __sync('cookieRemove', __syncCall('cookieRemove', { url: url, key: key }));
  }
});

// 查询一个字体并拿回句柄；不是字体/认不出 cmap 时抛错（规则可以 catch 后保留原文）。
globalThis.__queryTtf = function (data) {
  return __javaObject({ operation: 'queryTtf', value: String(data) });
};

globalThis.java = (function () {
  var surface = {
    put: function (key, value) {
      var call = { operation: 'put', key: String(key) };
      if (value !== undefined && value !== null) {
        call.value = String(value);
      }
      __java(call);
    },
    get: function (key) {
      return __java({ operation: 'get', key: String(key) });
    },
    // 同步族（ADR-0076 §决策 1）：上游在这里同步拿页面 / 响应 / Cookie。
    // `ajax` 答正文；`post` / `head` 答响应对象（规则读 `header('Location')`）；
    // 传输失败抛错，规则自己的 try/catch 照常可用。
    ajax: function (url, headers) {
      return __sync('ajax', __syncCall('ajax', { url: url, headers: headers }));
    },
    // `java.connect(url[, header[, callTimeout]])`：与 `ajax` 的区别是**答响应对象**，而且失败
    // 也是「答案」（上游 runCatching 后把错误正文塞进响应），规则自己看 `code()` 判断。
    connect: function (url, header) {
      // 上游还有第三个参数 `callTimeout`：本仓的超时归请求层（book-source.md §8），不按规则给。
      return __sandboxValue(
        __sync('connect', __syncCall('connect', { url: url, headers: header }))
      );
    },
    // `java.ajaxAll(urlList[, skipRateLimit])`：并发取多页，答响应对象数组。任一页失败整次调用
    // 抛错（上游 `mapAsync` 不吞异常），`skipRateLimit` 本仓收下但**不绕过**单源预算（book-source.md §8）。
    ajaxAll: function (urlList, skipRateLimit) {
      var urls = [];
      if (urlList && typeof urlList.length === 'number') {
        for (var index = 0; index < urlList.length; index++) {
          urls.push(String(urlList[index]));
        }
      }
      var value = __sync('ajaxAll', {
        operation: 'ajaxAll',
        urls: urls,
        skipRateLimit: skipRateLimit === true
      });
      if (!value || typeof value.length !== 'number') {
        return [];
      }
      var responses = [];
      for (var i = 0; i < value.length; i++) {
        responses.push(__sandboxValue(value[i]));
      }
      return responses;
    },
    // `java.openUrl(url[, mimeType])`：单向事件（规则不等人）。上游起一个确认页再开浏览器；
    // 本仓把地址交给 `ExternalUrlOpener`，确认与打开都在 UI 层完成。
    openUrl: function (url, mimeType) {
      var payload = { url: String(url) };
      if (mimeType !== undefined && mimeType !== null) {
        payload.mimeType = String(mimeType);
      }
      sendMessage('openUrl', JSON.stringify(payload));
    },
    post: function (url, body, headers) {
      return __sandboxValue(__sync('post', __syncCall('post', {
        url: url, body: body, headers: headers
      })));
    },
    head: function (url) {
      return __sandboxValue(__sync('head', __syncCall('head', { url: url })));
    },
    getCookie: function (url, key) {
      return __sync('getCookie', __syncCall('getCookie', { url: url, key: key }));
    },
    // `java.setContent(html)`：把页级 scope 换成这份 HTML（同一 job 内后续规则读它）。
    // 与重放无关：只是在 worker 里记一个值，`parse.*` 调用会带着它去宿主。
    setContent: function (content) {
      __java({
        operation: 'setContent',
        value: (content === undefined || content === null) ? '' : String(content)
      });
    },
    // 提示族（ADR-0076 §决策 1）：一次性 UI 事件，不等结果、不占额度。
    toast: function (message) {
      sendMessage('toast', JSON.stringify({ message: String(message), long: false }));
    },
    longToast: function (message) {
      sendMessage('toast', JSON.stringify({ message: String(message), long: true }));
    },
    timeFormat: function (time) {
      // 时间戳原样送（数字保持数字、字符串保持字符串）：能不能读出来由宿主定（§6）。
      return __java({
        operation: 'timeFormat',
        value: (time === undefined ? null : time)
      });
    },
    // 别名族（ADR-0037 §决策 2）：语义按上游照抄，全部在 worker 内同步完成。
    md5Encode: function (value) {
      return __crypto('md5', value);
    },
    base64Encode: function (value) {
      if (arguments.length > 1) {
        throw new Error('java.base64Encode(str, flags) is not supported: ' +
          'this repository has no flags semantics (book-source.md §6)');
      }
      return __crypto('base64Encode', value);
    },
    base64Decode: function (value) {
      if (arguments.length > 1) {
        throw new Error('java.base64Decode(str, charset) is not supported: ' +
          'this repository has no charset semantics (book-source.md §6)');
      }
      return __crypto('base64Decode', value);
    },
    // 上游两个重载：`encodeURI(str)` 与 `encodeURI(str, enc)`。真实语料用后者给老 PHP 站点
    // 编 GBK 关键词（美女图片网的 searchUrl），所以第二个参数是**字符集**，不是 flags。
    encodeURI: function (value, charset) {
      if (arguments.length > 2) {
        throw new Error('java.encodeURI(str[, charset]) takes at most two arguments');
      }
      var call = { operation: 'encodeUri', value: String(value) };
      if (charset !== undefined && charset !== null) {
        call.charset = String(charset);
      }
      return __java(call);
    },
    // 字节族与密钥族（M25/S3a）：上游 `JsEncodeUtils` 的一半。`byte[]` 在沙箱里是
    // `Uint8Array`（`length` / `[i]` / `Array.from` / `slice` 都能用），`createSymmetricCrypto`
    // 答一个不透明句柄。
    md5Encode16: function (value) {
      return __cryptoCall({ operation: 'md5Encode16', value: String(value) });
    },
    base64DecodeToByteArray: function (value, flags) {
      var payload = { operation: 'base64DecodeToByteArray', value: String(value) };
      if (typeof flags === 'number') {
        payload.flags = flags;
      }
      return __cryptoBytes(payload);
    },
    hexDecodeToByteArray: function (value) {
      return __cryptoBytes({ operation: 'hexDecodeToByteArray', value: String(value) });
    },
    hexEncodeToString: function (value) {
      return __cryptoCall({ operation: 'hexEncodeToString', value: String(value) });
    },
    hexDecodeToString: function (value) {
      return __cryptoCall({ operation: 'hexDecodeToString', value: String(value) });
    },
    // 上游 `JsEncodeUtils.strToBytes/bytesToStr` 是公开方法，Rhino 下规则直接可见。
    strToBytes: function (value, charset) {
      return __textBytes(value, charset);
    },
    bytesToStr: function (value, charset) {
      var payload = { operation: 'bytesToStr', value: value };
      if (charset !== undefined && charset !== null) {
        payload.charset = String(charset);
      }
      return __cryptoCall(payload);
    },
    digestHex: function (data, algorithm) {
      return __cryptoCall({
        operation: 'digestHex',
        value: String(data),
        algorithm: String(algorithm)
      });
    },
    digestBase64Str: function (data, algorithm) {
      return __cryptoCall({
        operation: 'digestBase64Str',
        value: String(data),
        algorithm: String(algorithm)
      });
    },
    HMacHex: function (data, algorithm, key) {
      return __cryptoCall({
        operation: 'HMacHex',
        value: String(data),
        algorithm: String(algorithm),
        key: String(key)
      });
    },
    HMacBase64: function (data, algorithm, key) {
      return __cryptoCall({
        operation: 'HMacBase64',
        value: String(data),
        algorithm: String(algorithm),
        key: String(key)
      });
    },
    createSymmetricCrypto: function (transformation, key, iv) {
      return __symmetricCreate(transformation, key, iv);
    },
    // 上游已弃用（@Deprecated）的那一大族：真实语料仍在用，所以照样绑定。它们的语义都是
    // 「组一个密码器再调一个方法」，因此实现在 JS 侧，只有 cipher 本体在宿主。
    aesDecodeToByteArray: function (str, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).decrypt(String(str));
    },
    aesDecodeToString: function (str, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).decryptStr(String(str));
    },
    // 上游这个重载的 key/iv 是 base64（`JsEncodeUtils.kt:150-168`）。
    aesDecodeArgsBase64Str: function (data, key, mode, padding, iv) {
      return __symmetricCreate('AES/' + mode + '/' + padding, __b64Bytes(key), __b64Bytes(iv))
        .decryptStr(String(data));
    },
    // 名字里带 Base64 的两个族与上面两个逐字相同：上游实现里 `aesBase64DecodeToByteArray`
    // 也调 `decrypt(str)`，编码是靠 `decrypt(String)` 自己猜 hex/base64。
    aesBase64DecodeToByteArray: function (str, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).decrypt(String(str));
    },
    aesBase64DecodeToString: function (str, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).decryptStr(String(str));
    },
    aesEncodeToByteArray: function (data, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).encrypt(String(data));
    },
    // 上游这里写成了 `decryptStr`（`JsEncodeUtils.kt:241-245` 的历史 bug）：本仓按名字的意图
    // （加密后当字符串）实现，差异登记在 book-source.md §6。
    aesEncodeToString: function (data, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).encryptStr(String(data));
    },
    aesEncodeToBase64ByteArray: function (data, key, transformation, iv) {
      return __textBytes(__symmetricCreate(transformation, key, iv).encryptBase64(String(data)));
    },
    aesEncodeToBase64String: function (data, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).encryptBase64(String(data));
    },
    // 注意与上一条的不对称：上游 `aesEncodeArgsBase64Str` 把 key/iv 当**明文**传
    // （`JsEncodeUtils.kt:303-315`），而 `aesDecodeArgsBase64Str` 当 base64。照抄这个不对称。
    aesEncodeArgsBase64Str: function (data, key, mode, padding, iv) {
      return __symmetricCreate('AES/' + mode + '/' + padding, key, iv)
        .encryptBase64(String(data));
    },
    desDecodeToString: function (data, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).decryptStr(String(data));
    },
    desBase64DecodeToString: function (data, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).decryptStr(String(data));
    },
    desEncodeToString: function (data, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).encryptStr(String(data));
    },
    desEncodeToBase64String: function (data, key, transformation, iv) {
      return __symmetricCreate(transformation, key, iv).encryptBase64(String(data));
    },
    tripleDESDecodeStr: function (data, key, mode, padding, iv) {
      return __symmetricCreate('DESede/' + mode + '/' + padding, key, iv)
        .decryptStr(String(data));
    },
    // 上游这一族：key 是 base64，iv 是明文（`JsEncodeUtils.kt:378-395`）。
    tripleDESDecodeArgsBase64Str: function (data, key, mode, padding, iv) {
      return __symmetricCreate('DESede/' + mode + '/' + padding, __b64Bytes(key), iv)
        .decryptStr(String(data));
    },
    tripleDESEncodeBase64Str: function (data, key, mode, padding, iv) {
      return __symmetricCreate('DESede/' + mode + '/' + padding, key, iv)
        .encryptBase64(String(data));
    },
    tripleDESEncodeArgsBase64Str: function (data, key, mode, padding, iv) {
      return __symmetricCreate('DESede/' + mode + '/' + padding, __b64Bytes(key), iv)
        .encryptBase64(String(data));
    },
    // 纯计算族（M25/S3b）。`getWebViewUA` / `androidId` 是随 job 进来的常量（上游同样不读实时状态）。
    randomUUID: function () {
      return __helper({ operation: 'randomUUID' });
    },
    timeFormatUTC: function (time, format, sh) {
      return __helper({
        operation: 'timeFormatUTC',
        value: (time === undefined || time === null) ? '' : time,
        format: String(format),
        sh: typeof sh === 'number' ? sh : Number(sh) || 0
      });
    },
    toNumChapter: function (value) {
      return __helper({ operation: 'toNumChapter', value: String(value) });
    },
    toURL: function (url, baseUrl) {
      var payload = { operation: 'toURL', value: String(url) };
      if (baseUrl !== undefined && baseUrl !== null) {
        payload.baseUrl = String(baseUrl);
      }
      return __helper(payload);
    },
    htmlFormat: function (value) {
      return __helper({ operation: 'htmlFormat', value: String(value) });
    },
    t2s: function (value) {
      return __helper({ operation: 't2s', value: String(value) });
    },
    s2t: function (value) {
      return __helper({ operation: 's2t', value: String(value) });
    },
    getWebViewUA: function () {
      return globalThis.__webViewUA || '';
    },
    androidId: function () {
      return globalThis.__androidId || '';
    },
    log: function (message) {
      sendMessage('log', JSON.stringify({ level: 'info', message: String(message) }));
    },
    // 规则求值族（ADR-0037 §决策 3）：字面量首参已由宿主内联，这里只剩异步兜底；
    // 内层规则走的是同一条宿主求值通道，scope 就是当前 job 的页级 scope。
    getString: function (rule, unescape) {
      if (arguments.length > 2 || unescape === true) {
        // 上游 `unescape = true`（默认）会对结果做 HTML 实体反转义，本仓不做（ADR-0037 §后果）。
        throw new Error('java.getString(rule, unescape) supports at most (rule, false)');
      }
      return __parse('getString', rule, null);
    },
    // 上游 `java.getStringList` 求的是**值**（含提取段），不是元素：`@css:.box img@src`
    // 要回 URL 列表。元素形态是 `parse.getElements` 的事（ADR-0037 §决策 3）。
    getStringList: function (rule) {
      return __parse('getStringList', rule, null);
    },
    getElement: function (rule) {
      // 单值形态：异步路径也只答第一个（与快路径内联的第一个匹配同形）——否则同一个调用在
      // 两条路径上会是「单值 vs 数组」（ADR-0037 §决策 3）。
      return __parse('getElements', rule, null).then(function (list) {
        return (list && list.length) ? list[0] : null;
      });
    },
    getElements: function (rule) {
      return __parse('getElements', rule, null);
    },
    // 验证族（ADR-0068 §决策 5）。`startBrowser` 与上游一样不返回页面；带 Await 的那个返回
    // `{url, body}`（上游 `StrResponse` 的两个字段）。
    startBrowser: function (url, title, html) {
      __verify('startBrowser', url, title, null, html, null).catch(function () {});
    },
    startBrowserAwait: function (url, title, refetchAfterSuccess, html) {
      return __verify('startBrowserAwait', url, title, refetchAfterSuccess, html, null)
        .then(function (payload) {
          if (payload === null || payload === undefined) {
            return { url: String(url), body: '' };
          }
          return { url: String(payload.url), body: String(payload.body) };
        });
    },
    getVerificationCode: function (imageUrl) {
      return __verify('imageCode', imageUrl, null, null, null, null).then(function (code) {
        return code === null || code === undefined ? '' : String(code);
      });
    },
    webView: function (url, js) {
      return __verify('webView', url, null, null, null, js);
    },
    webViewGetString: function (url, js) {
      return __verify('webView', url, null, null, null, js);
    },
    // 字体反解族（ADR-0068 增补决策 9）：`QueryTTF` 在本仓是不透明句柄 `{__ttf:true,id}`，
    // 规则只要把它的返回值交回 `replaceFont`。字体不跨进脚本，所以一次正文替换只花一个
    // 小信封，而不是几万个字形的 JSON。
    queryBase64TTF: function (data) {
      return __queryTtf(data);
    },
    queryTTF: function (data) {
      var text = String(data);
      // 上游自动判断 url / 本地文件 / base64；本仓只多认 url（网络必须异步，与 http.* 同规矩）。
      if (/^https?:\/\//i.test(text)) {
        return __hostCall('http', { operation: 'getBytes', url: text })
          .then(function (base64) { return __queryTtf(base64); });
      }
      return __queryTtf(text);
    },
    replaceFont: function (text, errorFont, correctFont, start, end) {
      var payload = { text: String(text) };
      if (errorFont && errorFont.__ttf === true) {
        payload.from = errorFont.id;
      }
      if (correctFont && correctFont.__ttf === true) {
        payload.to = correctFont.id;
      }
      // 旧语料的 (text, f1, f2, start, end) 形态：只替换给定码位区间。
      if (typeof start === 'number') { payload.start = start; }
      if (typeof end === 'number') { payload.end = end; }
      return __java({ operation: 'replaceFont', value: payload });
    }
  };
  for (var rejectedIndex = 0; rejectedIndex < __javaRejectedNames.length; rejectedIndex++) {
    surface[__javaRejectedNames[rejectedIndex]] = __javaRejected(
      __javaRejectedNames[rejectedIndex]
    );
  }
  for (var interopIndex = 0; interopIndex < __javaInteropNames.length; interopIndex++) {
    surface[__javaInteropNames[interopIndex]] = new Proxy({}, {
      get: function () {
        throw new Error('java.* interop is not supported (M2): see book-source.md §11');
      }
    });
  }
  return Object.freeze(surface);
})();

// 上游习惯写 Java `List.toArray()`（语料 38 处，ADR-0037 §决策 4）：能力中性的垫片，只返回自身。
if (Array.prototype.toArray === undefined) {
  Object.defineProperty(Array.prototype, 'toArray', {
    value: function () { return this; },
    enumerable: false,
    writable: true,
    configurable: true
  });
}

// 上游返回的是 Java `List`，真实语料两种写法都有：`list.size`（属性，美女图片网）与
// `list.size()`（方法，同一份导出里的另一条正文脚本）。JS 里一个值不能既是数字又是函数，
// 所以 `size` 取回来的是一个**可调用对象**：
//   * `list.size()` → 调用它，闭包记住的数组长度；
//   * `list.size` 参与算术/比较 → `valueOf()` 给出长度（`i < list.size` 成立）。
// 只有严格相等（`list.size === 3`）会失败，语料里没有这种写法（ADR-0069 G14）。
if (Object.getOwnPropertyDescriptor(Array.prototype, 'size') === undefined) {
  Object.defineProperty(Array.prototype, 'size', {
    get: function () {
      var array = this;
      var accessor = function () { return array.length; };
      Object.defineProperty(accessor, 'valueOf', {
        value: function () { return array.length; }
      });
      Object.defineProperty(accessor, 'toString', {
        value: function () { return String(array.length); }
      });
      return accessor;
    },
    enumerable: false,
    configurable: true
  });
}

globalThis.__hostCall = function (binding, args) {
  return sendMessage(binding, JSON.stringify(args));
};

globalThis.__httpOptions = function (operation, options) {
  if (options === undefined || options === null) {
    return null;
  }
  if (typeof options !== 'object') {
    throw new Error('http.' + operation + ': options must be an object');
  }
  var allowed = ['headers', 'body', 'response'];
  for (var key in options) {
    if (allowed.indexOf(key) < 0) {
      // 听不懂的键会让这次调用答非所问（`webView` 会拿回未渲染的页面），所以显式拒绝，
      // 而不是悄悄丢掉它（book-source.md §6）。
      throw new Error('http.' + operation + ': unsupported option ' + key);
    }
  }
  return {
    headers: (options.headers === undefined || options.headers === null)
      ? null : options.headers,
    body: (options.body === undefined || options.body === null)
      ? null : String(options.body),
    // `response: true` 要的是整个响应（body / url / code / headers），不是只有正文。
    response: options.response === true
  };
};

globalThis.__http = function (operation, url, options) {
  var opts = __httpOptions(operation, options);
  var call = { operation: operation, url: String(url), options: opts };
  if (opts !== null && opts.response === true) {
    // 宿主回的是响应信封；__sandboxValue 把 url() / code() / headers() 方法挂回去，
    // 形状与 loginCheckJs 看到的 `result` 相同（book-source.md §6）。
    return __hostCall('http', call).then(function (reply) {
      return __sandboxValue(reply);
    });
  }
  return __hostCall('http', call);
};

globalThis.http = Object.freeze({
  get: function (url, options) { return __http('get', url, options); },
  post: function (url, options) { return __http('post', url, options); }
});

globalThis.__parse = function (operation, rule, doc) {
  return __hostCall('parse', {
    operation: operation,
    rule: String(rule),
    doc: (doc === undefined || doc === null) ? null : String(doc)
  });
};

globalThis.parse = Object.freeze({
  getString: function (rule, doc) { return __parse('getString', rule, doc); },
  getElements: function (rule, doc) { return __parse('getElements', rule, doc); }
});
''';
