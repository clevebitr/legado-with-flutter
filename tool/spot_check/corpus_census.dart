// 语料静态普查：不联网、不跑引擎，只统计「缺口字段 / 规则语法 / 沙箱绑定成员」在真实书源合集里
// 出现多少个源、多少处。
//
// 为什么是独立脚本而不是 `batch_probe.dart` 的模式：`batch_probe` 跑的是**联网链路**（要真实 JS 引擎，
// 必须 `flutter run -d <device>`），而普查只读 JSON，用 `dart run` 就够——一次普查不该占一台设备
// （`docs/dev/testing.md` §1 的同一立场：静态统计与联网验证分开）。
//
// 用法：
//
//   dart run tool/spot_check/corpus_census.dart \
//     --source="C:/path/bookSource.json" --source="C:/path/bookSource (1).json"
//
// 输出分四段：语料概览、书源级字段、规则语法、沙箱绑定成员（`java.*` / `source.*` / 全局变量）。
// 每一行都是 `name<TAB>sources<TAB>hits`，可以直接抄进 `docs/dev/engine-parity.md` 的「语料命中」列。
//
// 判定口径（续）：`java.*` / `source.*` 的「已实现」名单**从沙箱前奏里读**（`lib/core/js/quickjs_worker.dart`
// 的 `java` surface 键与 `__javaRejectedNames`），所以新增绑定不需要同步这份工具——工具读到什么就是
// 什么；只有 `source` 对象与全局变量的名单是手写的（它们在前奏里不是「键: function」的形状）。
//
// 判定口径：
// * 「源数」按**合集内不同 URL** 计（同一本书源出现在两份合集里只算一次）；
// * 「处数」是原始出现次数（同一个源里出现两次算两处）；
// * 规则文本取自 JSON 里的**每一个字符串值**，因此 `ruleSearch.bookList` 与 `searchUrl` 都算；
// * 语法探测器只看**规则文本**，不猜语义（例如 `@css:` 出现在 URL 选项的 `body` 里也算）。
import 'dart:convert';
import 'dart:io';

/// 沙箱前奏的源码路径：`java.*` 的已实现名单从这里读，避免工具自己维护一份会漂移的清单。
const String _workerPath = 'lib/core/js/quickjs_worker.dart';

/// 一个统计项：出现过它的源（按 URL 去重）与总出现次数。
final class _Stat {
  final Set<String> sources = <String>{};
  int hits = 0;

  void add(String sourceUrl, [int count = 1]) {
    sources.add(sourceUrl);
    hits += count;
  }
}

/// 一份合集里的一条书源，连同它被读到的每个 `(路径, 文本)`。
final class _Source {
  _Source(this.url, this.json);

  final String url;
  final Map<String, Object?> json;
  final List<({String path, String text})> rules =
      <({String path, String text})>[];

  int get type => json['bookSourceType'] is int
      ? json['bookSourceType']! as int
      : int.tryParse('${json['bookSourceType']}') ?? 0;
}

void main(List<String> arguments) {
  final List<String> paths = _sourcesOf(arguments);
  if (paths.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/spot_check/corpus_census.dart --source=<collection.json> [...]',
    );
    exitCode = 2;

    return;
  }

  final Map<String, _Source> byUrl = <String, _Source>{};
  for (final String path in paths) {
    for (final _Source source in _load(path)) {
      // 同一 URL 以**第一次**出现为准（合集之间可能有重复条目）。
      byUrl.putIfAbsent(source.url, () => source);
    }
  }

  final List<_Source> corpus = byUrl.values.toList(growable: false);
  final Map<String, _Stat> fields = <String, _Stat>{};
  final Map<String, _Stat> syntax = <String, _Stat>{};
  final Map<String, _Stat> bindings = <String, _Stat>{};

  for (final _Source source in corpus) {
    _censusFields(source, fields);
    _censusRules(source, syntax, bindings);
  }

  _report(corpus: corpus, fields: fields, syntax: syntax, bindings: bindings);
}

/// Reads `--source=` options (repeatable) out of [arguments].
List<String> _sourcesOf(List<String> arguments) => <String>[
  for (final String argument in arguments)
    if (argument.startsWith('--source='))
      argument.substring('--source='.length),
];

/// Loads one export file (a JSON array of book sources) and flattens its rule strings.
List<_Source> _load(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('missing corpus: $path');
    exitCode = 2;

    return const <_Source>[];
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! List) {
    stderr.writeln('not a book source array: $path');
    exitCode = 2;

    return const <_Source>[];
  }

  final List<_Source> sources = <_Source>[];
  for (final Object? entry in decoded) {
    if (entry is! Map) {
      continue;
    }
    final Map<String, Object?> json = entry.map(
      (Object? key, Object? value) => MapEntry<String, Object?>('$key', value),
    );
    final String url = '${json['bookSourceUrl'] ?? ''}'.trim();
    final _Source source = _Source(
      url.isEmpty ? '<no-url>${sources.length}' : url,
      json,
    );
    _flatten(json, '', source.rules);
    sources.add(source);
  }

  return sources;
}

/// Collects every string value under [value] as a `(path, text)` rule candidate.
void _flatten(
  Object? value,
  String path,
  List<({String path, String text})> out,
) {
  if (value is String) {
    if (value.trim().isNotEmpty) {
      out.add((path: path, text: value));
    }

    return;
  }
  if (value is Map) {
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final String key = '${entry.key}';
      _flatten(entry.value, path.isEmpty ? key : '$path.$key', out);
    }

    return;
  }
  if (value is List) {
    for (var index = 0; index < value.length; index++) {
      _flatten(value[index], '$path[$index]', out);
    }
  }
}

/// Counts the **book source level** fields this repository models differently (or not at all).
void _censusFields(_Source source, Map<String, _Stat> stats) {
  void hit(String name) => stats.putIfAbsent(name, _Stat.new).add(source.url);

  void hitIf(String name, bool Function(Object?) test) {
    final List<String> segments = name.split('.');
    Object? value = source.json;
    for (final String segment in segments) {
      if (value is! Map) {
        return;
      }
      value = value[segment];
    }
    if (test(value)) {
      hit(name);
    }
  }

  bool nonBlank(Object? value) => value is String && value.trim().isNotEmpty;
  bool truthy(Object? value) => value == true || value == 'true';
  bool present(Object? value) => value != null;

  hitIf('jsLib', nonBlank);
  hitIf('coverDecodeJs', nonBlank);
  hitIf('ruleReview', present);
  hitIf('eventListener', truthy);
  hitIf('customButton', truthy);
  hitIf('homepageModules', nonBlank);
  hitIf('bookUrlPattern', nonBlank);
  hitIf('loginUrl', nonBlank);
  hitIf('loginUi', nonBlank);
  hitIf('loginCheckJs', nonBlank);
  hitIf('concurrentRate', nonBlank);
  hitIf('ruleContent.imageDecode', nonBlank);
  hitIf('ruleContent.imageStyle', nonBlank);
  hitIf('ruleContent.payAction', nonBlank);
  hitIf('ruleContent.callBackJs', nonBlank);
  hitIf('ruleContent.subContent', nonBlank);
  hitIf('ruleContent.title', nonBlank);
  hitIf('ruleContent.webJs', nonBlank);
  hitIf('ruleContent.sourceRegex', nonBlank);
  hitIf('ruleContent.nextContentUrl', nonBlank);
  hitIf('ruleBookInfo.downloadUrls', nonBlank);
  hitIf('ruleBookInfo.relatedBooks', nonBlank);
  hitIf('ruleBookInfo.init', nonBlank);
  hitIf('ruleToc.formatJs', nonBlank);
  hitIf('ruleToc.isVolume', nonBlank);
  hitIf('ruleToc.isPay', nonBlank);
  hitIf('ruleToc.wordCount', nonBlank);
  hitIf('ruleToc.preUpdateJs', nonBlank);
  hitIf('ruleToc.nextTocUrl', nonBlank);
  hitIf('ruleSearch.checkKeyWord', nonBlank);
  hitIf('ruleSearch.lastChapter', nonBlank);
  hitIf('ruleSearch.wordCount', nonBlank);
  hitIf('ruleExplore', present);
  hitIf('exploreUrl', nonBlank);

  stats.putIfAbsent('bookSourceType=${source.type}', _Stat.new).add(source.url);
  // `imageStyle` 的**取值**分布：上游是 `full` / `single` / `left` / `right` 这类字符串，
  // 而真实语料里的写法（含历史数字 `0`）决定「只支持 full/single」算不算缺口。
  final Object? style =
      (source.json['ruleContent'] as Map<Object?, Object?>?)?['imageStyle'];
  if (style is String && style.trim().isNotEmpty) {
    hit('imageStyle=${style.trim()}');
  }
}

/// Counts the rule-level syntaxes and the sandbox members a rule text mentions.
void _censusRules(
  _Source source,
  Map<String, _Stat> syntax,
  Map<String, _Stat> bindings,
) {
  void hit(Map<String, _Stat> stats, String name, [int count = 1]) =>
      stats.putIfAbsent(name, _Stat.new).add(source.url, count);

  int countOf(RegExp pattern, String text) => pattern.allMatches(text).length;

  final RegExp javaMember = RegExp(r'\bjava\.([A-Za-z_][A-Za-z0-9_]*)');
  final RegExp sourceMember = RegExp(r'\bsource\.([A-Za-z_][A-Za-z0-9_]*)');
  final RegExp cookieMember = RegExp(r'\bcookie\.([A-Za-z_][A-Za-z0-9_]*)');
  final RegExp cacheMember = RegExp(r'\bcache\.([A-Za-z_][A-Za-z0-9_]*)');
  final RegExp cryptoMember = RegExp(r'\bcrypto\.([A-Za-z_][A-Za-z0-9_]*)');
  final RegExp globalName = RegExp(
    r'(?<![.\w$])(src|chapter|nextChapterUrl|fromBookInfo|infoMap|speakText|speakSpeed|'
    r'result|baseUrl|page|key|book|title)\b',
  );

  for (final ({String path, String text}) rule in source.rules) {
    final String text = rule.text;
    final String lower = text.toLowerCase();
    // `@js:` 脚本与 `{{…}}` 模板里的 `//` / `@` 不是规则语法：注释里一个 `//`、模板里一个
    // `@css:` 都会让「裸 // 开头」「嵌套提取段」这类**位置敏感**的探测器误报。位置敏感的判定
    // 一律用这份「去掉脚本与模板之后的规则体」，其余（有没有用过某写法）仍看原文。
    final String body = _ruleHeadOf(text);

    // ── 规则语法 ────────────────────────────────────────────────────────────
    final int js = countOf(RegExp(r'@js:|<js>', caseSensitive: false), text);
    if (js > 0) {
      hit(syntax, '@js: / <js>（脚本段）', js);
    }
    if (RegExp(r'^\s*(?:[-+])?\s*@js:', caseSensitive: false).hasMatch(text)) {
      hit(syntax, '@js: 整条规则即脚本');
    }
    // 段链里的「再一个规则」（matrix #30）：**首段不空**、后面某段带选择器类标志头。
    // 首段为空说明是「整条规则以 `@css:` / `@json:` 开头」（matrix #12 / #13，已支持）；
    // `@js:` / `@put:` / `@get:` 是已支持的段（#14 / #16），不算缺口。
    if (_hasNestedRuleSegment(body)) {
      hit(syntax, '嵌套提取段（matrix #30 形状）');
    }
    if (lower.contains('@css:')) {
      hit(syntax, '@css:');
    }
    if (lower.contains('@json:')) {
      hit(syntax, '@json:');
    }
    if (lower.contains('@xpath:')) {
      hit(syntax, '@xpath:（matrix #21）');
    }
    if (RegExp(r'^(?:[-+])?\s*//').hasMatch(body)) {
      hit(syntax, '裸 // 开头（matrix #21）');
    }
    if (lower.contains('@webjs:')) {
      hit(syntax, '@webJs（matrix #22）');
    }
    if (RegExp(r'^\s*:').hasMatch(body) && !body.trimLeft().startsWith('::')) {
      hit(syntax, ':正则（matrix #20）');
    }
    if (lower.contains('@put:') ||
        lower.contains('@get:') ||
        lower.contains('{{')) {
      hit(syntax, '@put: / @get: / {{…}}');
    }
    if (text.contains('##')) {
      hit(syntax, '## 正则替换');
    }
    if (text.contains('||')) {
      hit(syntax, '|| 候选');
    }
    if (text.contains('&&')) {
      hit(syntax, '&& 合并');
    }
    if (text.contains('%%')) {
      hit(syntax, '%% 交叉');
    }
    if (RegExp(r':(eq|gt|lt)\(').hasMatch(text)) {
      hit(syntax, ':eq / :gt / :lt 伪类（matrix #29）');
    }
    if (RegExp(r'<[0-9]+(?:,[0-9]+)+>').hasMatch(text)) {
      hit(syntax, '<1,2,3> 页码列表');
    }
    if (text.contains('@result')) {
      hit(syntax, '@result 段链');
    }
    if (RegExp(r'''["']charset["']\s*:''').hasMatch(text)) {
      hit(syntax, 'URL 选项 charset');
    }
    if (RegExp(r'''["'](webView|bodyJs|webJs|retry|readTimeout)["']\s*:''')
        .hasMatch(text)) {
      hit(syntax, 'URL 选项 webView / bodyJs / webJs / retry / readTimeout');
    }
    if (RegExp(r'^\s*\+').hasMatch(body)) {
      hit(syntax, '+ 正序前缀');
    }
    if (RegExp(r'(?:bookList|chapterList)$').hasMatch(rule.path) &&
        text.contains('@js:') &&
        !RegExp(r'^\s*(?:[-+])?\s*@js:', caseSensitive: false).hasMatch(text)) {
      hit(syntax, '列表规则尾部 @js:（S4）');
    }

    // ── 沙箱绑定成员 ────────────────────────────────────────────────────────
    for (final RegExpMatch match in javaMember.allMatches(text)) {
      hit(bindings, 'java.${match.group(1)}');
    }
    for (final RegExpMatch match in sourceMember.allMatches(text)) {
      hit(bindings, 'source.${match.group(1)}');
    }
    for (final RegExpMatch match in cookieMember.allMatches(text)) {
      hit(bindings, 'cookie.${match.group(1)}');
    }
    for (final RegExpMatch match in cacheMember.allMatches(text)) {
      hit(bindings, 'cache.${match.group(1)}');
    }
    for (final RegExpMatch match in cryptoMember.allMatches(text)) {
      hit(bindings, 'crypto.${match.group(1)}');
    }
    // 全局变量只在**脚本体**里找：非 JS 规则里的 `key` / `page` 是模板变量，不是绑定。
    final String script = _scriptTextsOf(text).join('\n');
    if (script.isNotEmpty) {
      for (final RegExpMatch match in globalName.allMatches(script)) {
        hit(bindings, '全局 ${match.group(1)}');
      }
    }
  }
}

/// The rule body of [text] with `@js:` / `<js>` bodies and `{{…}}` templates removed.
///
/// Only the detectors that ask **where** a syntax sits may use it: a `//` that starts a script line
/// is a comment and a `@css:` inside `{{…}}` belongs to the inner rule, so neither says anything
/// about the outer rule's head or its segments.
String _ruleHeadOf(String text) {
  final String lower = text.toLowerCase();
  final StringBuffer buffer = StringBuffer();
  var index = 0;
  while (index < text.length) {
    if (lower.startsWith('@js:', index)) {
      break;
    }
    final String char = text[index];
    if (char == '<' || char == '{') {
      final Match? skipped = char == '<'
          ? _jsBlock.matchAsPrefix(text, index)
          : _template.matchAsPrefix(text, index);
      if (skipped != null) {
        index = skipped.end;

        continue;
      }
    }
    buffer.write(char);
    index++;
  }

  return buffer.toString();
}

/// `<js>…</js>`, the block part of a rule body.
final RegExp _jsBlock = RegExp(r'<js>[\w\W]*?</js>', caseSensitive: false);

/// One `{{…}}` template.
final RegExp _template = RegExp(r'\{\{[\w\W]*?\}\}');

/// Whether [rule] has a segment **(not the first) that is itself a flag-bearing rule**.
///
/// A leading `@css:` / `@json:` leaves an empty first segment, which is matrix #12 / #13 rather
/// than matrix #30. Segments are split on top-level `@` only: `[@class='a']` and `'a@b'` keep their
/// `@`.
bool _hasNestedRuleSegment(String rule) {
  final List<String> segments = _segmentsOf(rule);
  // 首段只剩下标志字符（`+` / `-` 正倒序、`@@` 默认规则）时，后面那个 `@css:` 其实是**整条规则
  // 的标志头**（matrix #12 / #13 / #15），不是段链里的第二条规则。
  final String first = segments.first.trim().replaceAll(RegExp('^[-+]+'), '');
  if (first.replaceAll('@', '').trim().isEmpty) {
    return false;
  }
  for (final String segment in segments.skip(1)) {
    final String body = segment.trim().toLowerCase();
    if (body.startsWith('css:') ||
        body.startsWith('json:') ||
        body.startsWith('xpath:') ||
        body.startsWith('webjs:')) {
      return true;
    }
  }

  return false;
}

/// Splits a rule on top-level `@`, i.e. outside quotes, brackets and parentheses.
List<String> _segmentsOf(String rule) {
  final List<String> segments = <String>[];
  final StringBuffer buffer = StringBuffer();
  var depth = 0;
  String? quote;
  for (var index = 0; index < rule.length; index++) {
    final String char = rule[index];
    if (quote != null) {
      buffer.write(char);
      if (char == quote) {
        quote = null;
      }

      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      buffer.write(char);

      continue;
    }
    if (char == '[' || char == '(') {
      depth++;
    } else if (char == ']' || char == ')') {
      depth = depth == 0 ? 0 : depth - 1;
    }
    if (char == '@' && depth == 0) {
      segments.add(buffer.toString());
      buffer.clear();

      continue;
    }
    buffer.write(char);
  }
  segments.add(buffer.toString());

  return segments;
}

/// The script bodies of [text] (`@js:…` to the end, `<js>…</js>` blocks).
List<String> _scriptTextsOf(String text) {
  final List<String> scripts = <String>[];
  for (final RegExpMatch match in RegExp(
    r'<js>([\w\W]*?)</js>|@js:([\w\W]*)',
    caseSensitive: false,
  ).allMatches(text)) {
    final String block = (match.group(1) ?? '').trim();
    scripts.add(block.isNotEmpty ? block : (match.group(2) ?? ''));
  }

  return scripts;
}

/// 沙箱前奏里 `java.*` 的成员名单（从源码读，避免工具自己漂移）。
///
/// `globalThis.java = (function () { var surface = { name: function … }` 这一段的键就是全部已实现的
/// 成员；`__javaRejectedNames` 里的名字是「具名拒绝」，同样不算缺口。
Set<String> _implementedJavaNames() {
  final File file = File(_workerPath);
  if (!file.existsSync()) {
    stderr.writeln('missing sandbox source: $_workerPath');

    return const <String>{};
  }
  final String source = file.readAsStringSync();
  final int start = source.indexOf('globalThis.java = (function () {');
  final int end = start < 0 ? -1 : source.indexOf('})();', start);
  final Set<String> names = <String>{};
  if (start >= 0 && end > start) {
    for (final RegExpMatch match in RegExp(
      r'^\s{4}([A-Za-z_$][A-Za-z0-9_$]*): function',
      multiLine: true,
    ).allMatches(source.substring(start, end))) {
      names.add(match.group(1) ?? '');
    }
  }
  // 具名拒绝的名字也算「见过了」——它们是**有意**拒绝，不是缺口。
  names.addAll(_preludeArray(source, '__javaRejectedNames'));
  names.addAll(_preludeArray(source, '__javaInteropNames'));

  return names;
}

/// Reads a flat string array literal (`['a', 'b']`) out of the sandbox prelude.
List<String> _preludeArray(String source, String name) {
  final int start = source.indexOf('$name = [');
  if (start < 0) {
    return const <String>[];
  }
  final int end = source.indexOf(']', start);
  final String literal = source.substring(start, end);

  return <String>[
    for (final RegExpMatch match in RegExp(
      "'([A-Za-z0-9_]+)'",
    ).allMatches(literal))
      match.group(1) ?? '',
  ];
}

/// 沙箱**已实现**的 `source.*` 成员。
const Set<String> _knownSource = <String>{
  // M25/S5a：`source` 对象的白名单字段（上游名 + 本仓的旧名）。
  'key',
  'bookSourceUrl',
  'bookSourceName',
  'bookSourceComment',
  'header',
  'loginUrl',
  'name',
  'url',
  'group',
  // 整份变量（上游无参形状）、按名键值、身份与登录门扇。
  'getVariable',
  'setVariable',
  'putVariable',
  'put',
  'get',
  'getKey',
  'getTag',
  'getLoginInfo',
  'getLoginInfoMap',
  'putLoginInfo',
  'removeLoginInfo',
  'getLoginHeader',
  'putLoginHeader',
  'getLoginHeaderMap',
  'removeLoginHeader',
  'login',
};

/// 沙箱**已实现**的全局变量。
const Set<String> _knownGlobals = <String>{
  'src',
  'chapter',
  'nextChapterUrl',
  'fromBookInfo',
  'infoMap',
  'result',
  'baseUrl',
  'page',
  'key',
  'book',
  'title',
  'source',
  'java',
  'cookie',
  'cache',
  'crypto',
  'log',
  'parse',
  'http',
};

void _report({
  required List<_Source> corpus,
  required Map<String, _Stat> fields,
  required Map<String, _Stat> syntax,
  required Map<String, _Stat> bindings,
}) {
  final StringBuffer out = StringBuffer();
  out.writeln('语料：${corpus.length} 个书源（按 URL 去重）');
  final Map<int, int> byType = <int, int>{};
  for (final _Source source in corpus) {
    byType[source.type] = (byType[source.type] ?? 0) + 1;
  }
  out.writeln(
    '按类型：${<String>[for (final int type in byType.keys.toList()..sort()) 'type=$type × ${byType[type]}'].join(' / ')}',
  );
  out.writeln();

  out.writeln('## 书源级字段（用到该字段的源数 / 处数）');
  _printStats(out, fields);
  out.writeln();
  out.writeln('## 规则语法');
  _printStats(out, syntax);
  out.writeln();
  out.writeln('## 沙箱绑定成员（按源数排序）');
  _printStats(out, bindings);
  out.writeln();

  final List<String> unknownJava = _unknown(
    bindings,
    'java.',
    _implementedJavaNames(),
  );
  final List<String> unknownSource = _unknown(
    bindings,
    'source.',
    _knownSource,
  );
  final List<String> unknownGlobals = <String>[
    for (final String name in _unknown(bindings, '全局 ', _knownGlobals))
      // 模板变量与脚本里常见的局部变量名不是绑定，这里只列真正没见过的。
      if (name != 'title') name,
  ];
  out.writeln('## 沙箱**未实现**、但语料里出现的成员（按源数排序）');
  out.writeln('java.*：${unknownJava.isEmpty ? '（无）' : unknownJava.join(', ')}');
  out.writeln(
    'source.*：${unknownSource.isEmpty ? '（无）' : unknownSource.join(', ')}',
  );
  out.writeln(
    '全局：${unknownGlobals.isEmpty ? '（无）' : unknownGlobals.join(', ')}',
  );

  stdout.write(out);
}

/// The names under [prefix] that are not in [known], worst first.
List<String> _unknown(
  Map<String, _Stat> stats,
  String prefix,
  Set<String> known,
) {
  final List<MapEntry<String, _Stat>> entries =
      <MapEntry<String, _Stat>>[
        for (final MapEntry<String, _Stat> entry in stats.entries)
          if (entry.key.startsWith(prefix) &&
              !known.contains(entry.key.substring(prefix.length)))
            entry,
      ]..sort(
        (MapEntry<String, _Stat> a, MapEntry<String, _Stat> b) =>
            b.value.sources.length.compareTo(a.value.sources.length),
      );

  return <String>[
    for (final MapEntry<String, _Stat> entry in entries)
      '${entry.key.substring(prefix.length)}（${entry.value.sources.length} 源 / ${entry.value.hits} 处）',
  ];
}

void _printStats(StringBuffer out, Map<String, _Stat> stats) {
  final List<MapEntry<String, _Stat>> entries = stats.entries.toList()
    ..sort(
      (MapEntry<String, _Stat> a, MapEntry<String, _Stat> b) =>
          b.value.sources.length.compareTo(a.value.sources.length),
    );
  for (final MapEntry<String, _Stat> entry in entries) {
    out.writeln(
      '${entry.key}\t${entry.value.sources.length}\t${entry.value.hits}',
    );
  }
}
