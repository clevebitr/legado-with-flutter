// coverage:ignore-file
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_qjs_next/flutter_qjs.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';

/// Starts the real worker: one dedicated isolate owning one **reused** QuickJS runtime
/// (`docs/dev/book-source.md` §6, ADR-0030 §决策 1).
///
/// This file is exempt from the coverage gate under ADR-0019's second category: it is
/// the only place that reaches the `flutter_qjs_next` native library, which cannot be
/// loaded from `flutter test`'s host VM (only a real device build provides it), so its
/// queueing and budget policy deliberately lives in
/// `quickjs_worker_bridge.dart` instead. **Its only automated verification is
/// `integration_test/js_bridge_test.dart`**, which runs it on Windows / Android with
/// the plugin built; how to run that is in `docs/dev/test-environment.md` §4.
///
/// The two budgets come from the bridge, never from here: the runtime interrupt
/// ([timeout]) and the heap limit ([memoryLimit]) are `book-source.md` §6's numbers,
/// defined once in `quickjs_worker_bridge.dart`.
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
  ], debugName: 'js-worker');

  return _IsolateWorkerHandle(
    isolate: isolate,
    toWorker: await ready.future,
    fromWorker: fromWorker,
    subscription: subscription,
    messages: messages,
  );
}

/// One worker isolate as a [JsWorkerHandle].
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

/// The worker's main loop: build the runtime once, then serve messages until closed.
///
/// Deliberately free of `try`/`catch`: a native failure is an `Error`, which ADR-0022
/// forbids catching. An isolate that dies leaves the bridge's hard budget to notice,
/// kill (a no-op by then) and rebuild — which is exactly the fallback ADR-0030
/// §决策 3 describes. The same budget covers the failure a `Future` cannot report up
/// from the worker (a native `Error` inside `evaluate` leaves the job unanswered).
Future<void> _quickJsWorkerMain(List<Object?> bootstrap) async {
  final Object? port = bootstrap.isNotEmpty ? bootstrap[0] : null;
  final Object? timeoutMs = bootstrap.length > 1 ? bootstrap[1] : null;
  final Object? memoryLimit = bootstrap.length > 2 ? bootstrap[2] : null;
  if (port is! SendPort || timeoutMs is! int || memoryLimit is! int) {
    return;
  }

  final ReceivePort fromBridge = ReceivePort();
  port.send(<String, Object?>{'type': 'ready', 'port': fromBridge.sendPort});

  final JavascriptRuntime runtime = getJavascriptRuntime(
    timeout: timeoutMs,
    memoryLimit: memoryLimit,
    // §6 禁止定时器、`console` 与原生态；`JsWebApis.none()` 就是「什么都不装」
    // （库自己的描述：no console, no timers, plain ECMAScript），比装完再 delete 干净。
    // 剩下的重绑防护由 `_evaluationSource` 在每个 job 前重跑沙箱完成。
    webApis: const JsWebApis.none(),
  );
  final _Worker worker = _Worker(runtime, port);
  worker.installBindings();

  await for (final Object? raw in fromBridge) {
    if (raw is! Map) {
      continue;
    }
    final Map<String, Object?> envelope = Map<String, Object?>.from(raw);
    switch (envelope['type']) {
      case 'evaluate':
        // 这里**不能** await：一个 `@js:` 脚本可以停在 `await http.get(...)` /
        // `await parse.*` 上（§6 的 Promise 绑定），而它的答复正是由这条循环继续分发的。
        // 桥按 FIFO 一次只派一个 job，所以同一时刻至多一个求值在跑。
        unawaited(worker.evaluate(envelope['job']));
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

/// The worker's own state: one reused runtime plus the binding calls in flight (§6).
///
/// One job runs at a time (the bridge's FIFO queue), so the calls a script is waiting on
/// live in one map keyed by the call number the reply has to name.
final class _Worker {
  _Worker(this._runtime, this._toBridge);

  final JavascriptRuntime _runtime;
  final SendPort _toBridge;

  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextCallId = 0;

  /// The variables of the job being evaluated (`book-source.md` §6, ADR-0034 §决策 1).
  ///
  /// Seeded from the job's snapshot and reported back with the result, so `java.get` /
  /// `java.put` are answered without leaving this isolate — which is what keeps them
  /// synchronous — while the host stays the single writer of the store. A **null** value
  /// means the script cleared the variable (`java.put(key, null)`), which the bridge turns
  /// back into a removal instead of the text "null".
  Map<String, String?> _variables = <String, String?>{};

  /// The book / chapter a `java.get('bookName')` / `java.get('title')` reads answer with
  /// (`book-source.md` §6, ADR-0049); empty when the stage does not know them.
  Map<String, String> _named = const <String, String>{};

  /// Registers §6's binding channels.
  ///
  /// The sync bindings (`crypto.*`, `log.*`) complete inside this isolate, so JavaScript
  /// gets a value. The two host bindings (`http.*`, `parse.*`) cannot: their handler
  /// returns a [Future], which the engine turns into the Promise §6 requires the rule to
  /// `await`.
  void installBindings() {
    _runtime.onMessage('crypto', (Object? args) {
      if (args is! Map) {
        return null;
      }
      final Object? operation = args['operation'];
      final Object? value = args['value'];
      if (operation is! String || value is! String) {
        return null;
      }

      return applyCryptoOperation(operation, value);
    });
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
      (Object? args) => _callHost(jsParseBinding, args),
    );
    // 矩阵 #17：`java.*` 在本 isolate 内完成，所以 JS 同步拿到值（§6 的形态列）。
    _runtime.onMessage(jsJavaBinding, _applyJava);
  }

  /// Answers one `java.*` call from the running script (§6, matrix #17).
  ///
  /// The value is a JSON envelope ([applyJsJavaCall]) rather than a bare value: a write has
  /// no value to return, so `null` cannot serve as “failed” here. The variable map is this
  /// job's snapshot, which the result envelope carries back to the host (ADR-0034 §决策 1).
  Object? _applyJava(Object? args) =>
      applyJsJavaCall(_variables, args, named: _named);

  /// Runs one job and reports its result envelope.
  Future<void> evaluate(Object? job) async {
    // 上一个 job 的未答复调用（脚本没 await 就结束了）不再有意义，桥也已经不再认它。
    _pending.clear();
    _variables = <String, String?>{};
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
    _variables = decodeJsVariables(fields['variables']);
    _named = decodeJsNamedContext(fields);
    final Stopwatch stopwatch = Stopwatch()..start();
    JsEvalResult result = _runtime.evaluate(_evaluationSource(fields));
    if (result.rawResult is Future) {
      // 脚本停在 Promise 上（`await http.get(...)` / `await parse.*`）：这套引擎把 JS
      // Promise 换成 Dart Future，`handlePromise` 边等边抽干作业队列（库的 async-bridge
      // recipe 同形）。答复由主循环的 [answerHostCall] 分发，所以这里能安全地等。
      result = await _runtime.handlePromise(result);
    }
    stopwatch.stop();

    if (result.isError) {
      _toBridge.send(<String, Object?>{
        'type': 'result',
        'ok': false,
        'error': result.stringResult,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        // 脚本可能在报错前已经 `java.put` 过：上游的写入是立即生效的，所以失败也回传。
        'variables': _variables,
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
      });

      return;
    }

    _toBridge.send(<String, Object?>{
      'type': 'result',
      'ok': decoded['ok'] == true,
      'value': decoded['value'],
      'error': decoded['error'],
      'elapsedMs': stopwatch.elapsedMilliseconds,
      'variables': _variables,
    });
  }

  /// Answers one binding call with the bridge's reply (§6).
  ///
  /// A failure rejects the script's Promise, which is what a rule can `catch`; whether it
  /// also fails the job is the bridge's decision ([JsHostReply.fatal]).
  void answerHostCall(Map<String, Object?> message) {
    final JsHostReply? reply = JsHostReply.fromJson(message);
    final Completer<Object?>? pending = reply == null
        ? null
        : _pending.remove(reply.callId);
    if (reply == null || pending == null) {
      // 畸形或无人等待的答复不得静默丢弃（C-SRC-4 的同口径）：送回宿主记一条。
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

  /// Runs one binding call that has to leave this isolate and waits for its answer.
  ///
  /// The envelope is built by [JsHostCall], which the bridge decodes with the same type, so
  /// the two sides cannot drift; the reply is matched by [JsHostCall.callId].
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

/// Builds the script one job runs: the sandbox (re-applied every job), the §6
/// variables, then the rule through the helper.
///
/// **The whole sandbox is re-applied per job on purpose.** The runtime is reused and
/// `globalThis` is shared, so a rule could otherwise leave `globalThis.crypto` or
/// `globalThis.log` pointing somewhere else (freezing the object does not protect the
/// property name) and the *next* job — possibly another book source — would inherit it.
/// Re-running the prelude costs a re-parse of about 1.5 KB next to a 5 s budget and
/// repairs every whitelisted name; the belt-and-braces `delete` list inside it also
/// clears the names §6 forbids, in case a rule defined them again.
///
/// `eval` inside the helper is what gives the rule its **completion value** semantics:
/// `result.replace(...)` and `var x = 1; x + 1` both produce a value, so a source can
/// keep using either spelling. The script text is passed as a JSON string literal, so
/// nothing in the rule can break out of it.
String _evaluationSource(Map<String, Object?> fields) {
  final Object? key = fields['key'];
  final StringBuffer buffer = StringBuffer()
    ..writeln(_prelude)
    ..writeln('var baseUrl = ${jsonEncode(fields['baseUrl'])};')
    ..writeln('var result = ${jsonEncode(fields['result'])};')
    ..writeln('var page = ${jsonEncode(fields['page'])};')
    ..writeln('var source = Object.freeze(${jsonEncode(fields['source'])});');
  final Object? book = fields['book'];
  buffer.writeln(
    'var book = __sandboxBook(${book == null ? 'null' : jsonEncode(book)});',
  );
  // `key` 只有 URL 规则才有（上游 `AnalyzeUrl.evalJS`，AnalyzeUrl.kt:377）。缺席时用
  // `globalThis` 删掉而不是 `var` 声明，因为 `var` 建的属性删不掉，上一个 job 的词就会漏进来。
  if (key != null) {
    buffer.writeln('globalThis.key = ${jsonEncode(key)};');
  }
  buffer.write('__runRule(${jsonEncode(_asString(fields['script']))})');

  return buffer.toString();
}

/// Reads one envelope field as a [String], or an empty string.
String _asString(Object? value) => value is String ? value : '';

/// Decodes the JSON envelope the sandbox helper returns, or `null` when it is not one.
///
/// A JS syntax error makes the helper itself unparsable, so this is the second place a
/// broken script surfaces; the caller reports both as `js:error`.
Map<String, Object?>? _decodeEnvelope(String raw) {
  try {
    final Object? decoded = jsonDecode(raw);

    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// The sandbox surface: the §6 variables helper, the sync `log.*` / `crypto.*` and the two
/// host bindings `http.*` / `parse.*`.
///
/// Every `sendMessage` payload is a `JSON.stringify` object: the bridge decodes it with
/// `jsonDecode` before the handler sees it (`tool/spike/README.md` §4), so a bare
/// string would not survive.
///
/// It is re-evaluated before every job (see `_evaluationSource`), so every statement
/// here must be idempotent. The first block closes the holes F1 of the 3.3 review
/// found: the names §6 forbids are deleted even though `JsWebApis.none()` should never
/// have installed them, because a rule can define them itself and the next job must not
/// inherit that.
///
/// `__runRule` returns a **Promise** for an `await`-ing rule and a plain string
/// otherwise, because §6's `http.*` / `parse.*` are Promises (ADR-0029 §决策 3): the
/// whole promise is settled inside JavaScript, so the engine always receives the same
/// JSON envelope and a rejected promise can never escape as an unhandled rejection.
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

// 具名拒绝族（ADR-0037 §决策 5）：命中即给可读错误，不落到 `undefined is not a function`。
globalThis.__javaRejected = function (name) {
  return function () {
    throw new Error('java.' + name + ' is not supported (M2): see book-source.md §11');
  };
};

// 沙箱的 `book` 对象（ADR-0061 §决策 5 的数据面 + ADR-0062 §决策 2 的方法面）。
//
// 数据字段从 `JsBookInfo` 的 JSON 拷来，方法分两类：
// * `getVariable` / `putVariable` 是**规则变量**，与 `java.get` / `java.put` 同一张表——
//   上游 AnalyzeUrl 的 javaPut/javaGet 也是先写 book 的 variableMap（AnalyzeUrl.kt:390-406）；
// * `setType` / `setReverseToc` 在本仓没有对应的书籍状态：它们在本 job 内可读回，但**不影响**
//   宿主（章节顺序 / 书籍类型不变），差异登记在 ADR-0062 §决策 2。
// 每次 job 重建，所以这里不再 `Object.freeze`：规则自己的写入不会漏到下一份规则。
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
// 定义为**变量**读写（ADR-0034），它们的名字被占用；上游那套同步 HTTP 的 `get(url)` / `post(url)`
// 因此没有可用的拼写，只能靠 `ajax` 这一族具名拒绝（ADR-0037 §决策 5）。
globalThis.__javaRejectedNames = [
  'ajax', 'post', 'head', 'ajaxAll', 'connect',
  'webView', 'webViewGetString', 'webViewGetElements', 'startBrowser', 'startBrowserAwait',
  'downloadFile', 'cacheFile', 'importScript', 'getVerificationCode', 'getCookie',
  'setContent', 'toast', 'longToast',
  'base64DecodeToByteArray', 'hexDecodeToByteArray',
  'createSymmetricCrypto', 'aesBase64DecodeToString', 'aesEncodeToString', 'aesDecodeToString',
  'desBase64DecodeToString', 'HMacHex', 'HMacBase64',
  'md5Encode16', 'htmlFormat', 'refreshBookUrl'
];

globalThis.__javaInteropNames = ['lang', 'security', 'util', 'net', 'io', 'nio', 'math', 'text'];

// Rhino 的另一条互操作入口 `Packages.java.lang.…`（ADR-0037 §决策 5）：具名拒绝，
// 不让它落到 `Packages is not defined` 那种更难懂的错误。
globalThis.Packages = new Proxy({}, {
  get: function () {
    throw new Error('Packages.* interop is not supported (M2): see book-source.md §11');
  }
});

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
    encodeURI: function (value) {
      if (arguments.length > 1) {
        throw new Error('java.encodeURI(str) takes one argument');
      }
      return __java({ operation: 'encodeUri', value: String(value) });
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
    getStringList: function (rule) {
      return __parse('getElements', rule, null);
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
  var allowed = ['headers', 'body'];
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
      ? null : String(options.body)
  };
};

globalThis.__http = function (operation, url, options) {
  return __hostCall('http', {
    operation: operation,
    url: String(url),
    options: __httpOptions(operation, options)
  });
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
