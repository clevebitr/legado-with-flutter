// coverage:ignore-file
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_qjs_next/flutter_qjs.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_fonts.dart';

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
  ], debugName: 'js-worker');

  return _IsolateWorkerHandle(
    isolate: isolate,
    toWorker: await ready.future,
    fromWorker: fromWorker,
    subscription: subscription,
    messages: messages,
  );
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
  if (port is! SendPort || timeoutMs is! int || memoryLimit is! int) {
    return;
  }

  final ReceivePort fromBridge = ReceivePort();
  port.send(<String, Object?>{'type': 'ready', 'port': fromBridge.sendPort});

  final JavascriptRuntime runtime = getJavascriptRuntime(
    timeout: timeoutMs,
    memoryLimit: memoryLimit,
    // 不装 console / 定时器等 Web API，只留纯 ECMAScript；重绑防护靠每个 job 重跑前奏。
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
        // 不能 await：脚本可能停在 `await http.get(...)` 上，答复要靠这条循环继续分发。
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

// 一个 worker 的状态：复用的运行时，加上在途的绑定调用。
final class _Worker {
  _Worker(this._runtime, this._toBridge);

  final JavascriptRuntime _runtime;
  final SendPort _toBridge;

  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextCallId = 0;

  // 当前 job 的变量表：从快照播种，随结果回传；null 表示脚本删除了该变量。
  Map<String, String?> _variables = <String, String?>{};

  // bookName / title 的内置值；阶段不知道时为空。
  Map<String, String> _named = const <String, String>{};

  // 本 job 查询过的字体（`java.queryTTF` 的句柄表，ADR-0068 增补决策 9）。
  // 字体不进脚本、也不跨 job：一个 job 结束时清空，句柄 id 不复用。
  final JsFontRegistry _fonts = JsFontRegistry();

  // sync 绑定在本隔离体内直接答复；http / parse 返回 Future，由引擎转成 Promise。
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
    // 验证族（ADR-0068 §决策 5）：等的是人，桥会暂停硬预算并免掉调用额度。
    _runtime.onMessage(
      jsVerifyBinding,
      (Object? args) => _callHost(jsVerifyBinding, args),
    );
    // java.* 在本 isolate 内完成，所以 JS 同步拿到值。
    _runtime.onMessage(jsJavaBinding, _applyJava);
  }

  Object? _applyJava(Object? args) =>
      applyJsJavaCall(_variables, args, named: _named, fonts: _fonts);

  Future<void> evaluate(Object? job) async {
    // 上一个 job 未答复的调用不再有意义，桥也已经不再认它。
    _pending.clear();
    _variables = <String, String?>{};
    _fonts.clear();
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
      // 脚本停在 Promise 上：引擎把 JS Promise 换成 Dart Future，等待期间主循环继续
      // 分发 hostResult，所以这里可以安全地等。
      result = await _runtime.handlePromise(result);
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
  // key 只有 URL 规则才有；缺席时删掉 globalThis 属性（var 建的属性删不掉，会漏到下一个 job）。
  if (key != null) {
    buffer.writeln('globalThis.key = ${jsonEncode(key)};');
  }
  buffer.write('__runRule(${jsonEncode(_asString(fields['script']))})');

  return buffer.toString();
}

String _asString(Object? value) => value is String ? value : '';

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
  return Object.freeze(source);
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
// 定义为**变量**读写（ADR-0034），它们的名字被占用；上游那套同步 HTTP 的 `get(url)` / `post(url)`
// 因此没有可用的拼写，只能靠 `ajax` 这一族具名拒绝（ADR-0037 §决策 5）。
globalThis.__javaRejectedNames = [
  'ajax', 'post', 'head', 'ajaxAll', 'connect',
  'webViewGetElements',
  'downloadFile', 'cacheFile', 'importScript', 'getCookie',
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
