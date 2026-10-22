# ADR-0047 引擎兼容面（M12）：URL 规则后缀、`<js>` 分段、列表 JS、header 规则、JSONPath 方言与失败隔离

- **状态：** Accepted（2026-10-21，M12 规格前置 + 落地；范围由 `DECISIONS.md` #7 裁决，用户追加
  「以真实语料 `4dc410d1.json`（128 条）为验收对象，要求兼容原版支持的书源」）
- **日期：** 2026-10-21
- **关联：** C-SRC-1 / C-SRC-4 / C-SRC-5 / C-ERR-1 / C-ERR-8 / C-NET-3 / C-SEC-4、ADR-0026、ADR-0031、
  ADR-0032、ADR-0040、ADR-0046、`docs/dev/book-source.md` §2 / §3 / §4.3 / §5.1 / §6 / §7、
  `docs/dev/roadmap.md` §3.7 / §3.8

## 背景

M12 的范围（`DECISIONS.md` #7）是「引擎规则面五条（§3.7 已登记）+ 编码缺口 + 单源预算与错误容忍」。
动工前先用一条真实语料把**一半以上的源**跑一遍，量出失败分布：新增 `tool/spot_check/batch_probe.dart`
（`flutter run -d windows -t …`，四段链路逐源跑，输出 `stage/kind/rulePath` 直方图）。

128 条源的首轮结果（`build/probe_all.json`）：**只有 8 条四段全通**。失败分布是：

| 失败点 | 条数 | 真实原因（逐条查过后） |
|---|---|---|
| `searchUrl` 段 HTTP 失败（404 / 连不上 / 超时 / 403） | 54 | 域名已死或换了站点；**其中 50 条的 `searchUrl` 写着 `url,{…}` 后缀，本仓把这一整段当 URL 发出去**，因此 404 是自找的 |
| `searchRule.bookList` 匹配为空（页面拿到了） | 54 | 绝大多数是上一条的死站点返回 301 页 / 空体；剩下一部分是 `$.[*]` 这类 Legado 方言与列表 JS |
| 导入即失败（`CheckedFromJsonException`） | 3 | `header` 写成 `<js>…</js>` / `@js: …` |
| 抛 `FormatException` 到批外 | 2 | `searchUrl` 用 GBK 编码关键词时，`redactUrl` 的 `queryParameters` 解码炸了 |

同一批语料的结构统计（整份文件）：`<js>` 出现在规则里 **50** 条、`url,{…}` **50** 条、`@put:`/`@get:` 22 条、
`{{…}}` 67 条、`$.[*]` 2 条、`header` 写成规则 2 条。

于是 M12 的 A 组五条之外，还必须做两件**规格没写但决定可用率**的事：**URL 规则后缀**与 **`<js>` 分段**。
本 ADR 记录这几条的口径，以及三条取证后**不改**语义的结论。

## 决策

### 决策 1 URL 字段是一条**规则**，`url,{…}` 后缀属于引擎而不是请求层

- 解析器 `domain/url_rule.dart`：`parseUrlRule` 把规则切成 `template` + `UrlRuleOptions`。切点取
  `,\s*(?=\{)`（上游 `AnalyzeUrl.paramPattern`）**且**要求后面是「以 `}` 收尾的平衡对象」，所以
  `search?q={{key}}`、地址里的普通逗号都不会被误切。
- 后缀不是严格 JSON：单引号、裸键、尾逗号、`{{…}}` 模板插在值里都是真实写法，因此用一个
  **宽松扫描器**（`_OptionScanner`）读它；读不懂就是 `unsupported:url-options` 的显式失败，
  绝不把 `,{…}` 当 URL 发出去（那正是 50 条源的 404 来源）。
- 建模的字段：`method`（`GET` / `POST`，其余按 GET 发并记 `method:<名字>`）、`body`、`charset`、
  `headers`（对象或**字符串形式的对象**）。`webView` / `webJs` / `retry` / `js` / `origin` / `type`
  记进 `unsupported` 并按名 warning（ADR-0032 的降级口径：降级要留痕）。
- **关键词的转义位置**：URL 与**表单** body 里按声明的 `charset` 做一次性百分号编码；**JSON / XML body
  里原样出现**（上游 `analyzeFields` 在 body 是 JSON 时整段跳过）。这条差异不写下来就会被"顺手统一"。
- **charset 双向生效**：请求侧决定 `{{key}}` 的字节（GBK 的「剑来」= `%BD%A3%C0%B4`），响应侧作为
  `decodeBody(declaredCharset:)` 的**最高优先级声明**，走 ADR-0031 的宽容车道（声明出错只报不致命）。
- 首段 URL 的渲染仍然走 `RuleEngine.renderUrl`，所以 `{{page}}` / `{{Math.round(Date.now()/1000)}}`
  这类 JS 模板在 URL 与 body 里都能用（matrix #18 不变）。

### 决策 2 `<js>…</js>` 是**规则分段**，不是一条规则的一个标志（matrix #31）

- 上游 `AppPattern.JS_PATTERN = <js>([\w\W]*?)</js>|@js:([\w\W]*)`，`splitSourceRule` 先把规则切成
  段，`getString` / `getStringList` / `getElements` 再**链式**求值：上一段的产出就是下一段的 `result`。
- 本仓的实现（`RuleEngine._jsSegmentsOf` / `_evaluateSegments` / `_selectAllSegments`）：
  - 值规则：逐段求值，段间用 `single ? values.first : values` 传递（与 `getString` / `getStringList` 同形）；
  - `{{result}}` 在这条链上解析成**上一段的产出**（不是整页正文）；
  - 列表规则：脚本返回数组时逐项成为条目——**字符串按 HTML 解析成 DOM scope**（上游 `AnalyzeByJSoup(String)`
    也是解析文本），对象 / 数组成为 JSON scope。
- **只有真出现 `<js>` 才走这条链**：尾部 `@js:` 的既有语义（matrix #14）逐字节不变，避免"顺手统一"
  带来的回归。两段形式的组合（`<js>…</js>@js:…`）由同一条链覆盖。

### 决策 3 列表规则（`bookList` / `chapterList`）接受 JS

- 旧的 `unsupported:@js:list` 是登记缺口（ADR-0014 的边界），现在按上游 `getElements` 的 `Mode.Js` 实现：
  `evalJS` 的返回值就是条目列表。`bookList: "@js: …"` 与 `bookList: "<js>…</js>"` 都走这条。
- 失败语义不变：**顶层**列表规则的 JS 报错 / 拒绝仍然整次失败（C-SRC-4），不退化成"没搜到"。

### 决策 4 JSON 条目上裸 `@js:` 的 `result` 是**条目对象**（§3.7-A1）

- `_resultOf(scope)`：`JsonScope` 给它的值（Map / List / 标量），`DomScope` 给页面正文。
- 依据：上游 `evalJS` 的 `result` 就是 `content`，而 `bookList` 的 JSON 条目是 `NativeObject` / `LinkedTreeMap`；
  页面则是 `String`。两者在 `@js:result.Name` 这种写法里行为完全不同，所以必须按 scope 类型分流。
- **登记差异：** 本仓把**页面**永远当 `DomScope`（正文原文给脚本），这与上游一致；把**JSON 条目**当
  `JsonScope`。同一份 JSON 页面若被 `@json:` 规则切出游标，之后的 `@js:` 也拿到 JSON 值——比上游"更松"，
  但只影响"本应拿对象"的写法。

### 决策 5 `header` 写成规则时，在**首个请求之前**求值（§3.7-A2）

- 模型新增 `BookSource.headerRule`（不参与 codegen，随机型工厂填充）：`header` 是 `@js:` / `<js>` 时，
  文本落在这里，`headers` 为 `null`；导入**不再丢字段、不再报降级**。
- 求值点：`PageFetchService.headersOf(source)`。它属于**取页**而不是规则引擎，因为求值时还没有页面
  （这正是"规则求值需要页面"与"header 需要求值"的先后矛盾，§3.7 要求先裁决）。
- 语义：脚本结果按 JSON 解析成 `Map<String,String>`；解析失败 / 脚本失败 → **保留静态 header + warning**，
  不失败整段（`BaseSource.getHeaderMap` 也是 catch 掉）。合并顺序：静态 header 在底，规则结果覆盖。
- 导入器仍然保留 `header` 的降级通道：既不是规则、也读不成对象的写法（裸 UA、截断对象）**仍然**丢字段 +
  warning（ADR-0040 §决策 6）。

### 决策 6 JSONPath 方言：`$.[…]` 归一化；`@@` / 默认规则**不改**语义（§3.7-A3/A4/A6）

- `$.[*]`（Legado 的 JsonPath 接受，RFC 9535 不接受）在 `_normalizeJsonPath` 里归一成 `$[*]`。
  真实语料 2 条（宜搜小说、有声听书网），后者改造后 search 段由 `parseFailed` 变为真命中。
- **A3（JSON 页面上的默认 / `@@` 规则）取证结论：不改。** 上游 `SourceRule.init` 在**页面正文是 JSON** 时
  把任意规则读成 `Mode.Json`，但它用的 jayway JsonPath 同样要求 `$` 前缀——`data.bookList` 这类裸规则在
  上游也读不出东西。也就是说"按页面类型换分析器"对**能跑的规则没有增益**，对**写错的规则只改变失败位置**。
  因此继续保持"默认规则读 DOM，`$.` / `$[` / `@json:` 读 JSON"，并把它登记为与上游的**有意差异**
  （ADR-0032 的"未知类型退化为 CSS"因此仍然成立）。
- **A4（页面字段规则的 `page` 绑定）取证结论：不改。** 搜索 / 发现阶段的 `page` 已是渲染它的那个页码；
  字段规则本身不消费 `page`（只有 URL 模板与 `@js:` 绑定消费），语料里没有反例。

### 决策 7 失败隔离：一个源、一次读、一条日志都不得击穿批次

三处修正，每一处都有真实触发：

1. **`redactUrl`**（`core/logging/redaction.dart`）：查询串不是合法 percent-encoded UTF-8 时
   `Uri.queryParameters` 会抛 `FormatException`。GBK 站点把关键词编进 URL 就是这种值。日志绝不能成为
   请求失败的原因，因此这条路改为**按原始文本逐对掩码**（`name=***`），既不解码也不泄露。
2. **`DioHttpClient._send`**：正文是**流式**读的（C-PERF-5），`receiveTimeout` 会在**读**的过程中来，
   而它原来在 `try` 之外抛出 → 穿过 `HttpClient` 契约（C-ERR-1）。现在读 body 的 `on Exception`
   统一映射成 `ParseFailureKind`。
3. **`AggregateSearchBooks` + `AggregateSearchNotifier` + `SearchBooksPage`**：逐源 `on Exception` 只记该源
   失败；notifier 的失败路径保留已发布的命中（`_settled`）；页面只在 `books.isEmpty` 时才用失败占满结果区。
   用户可见症状是「一个坏源把整屏成功结果冲掉」，根因就是前两条 + 第三处的旧写法。

### 决策 8 明确不做（本轮）

- `java.get('bookName' / 'title')` 特例（§3.7-A5）：它要求域层端口带上 Book / Chapter 上下文，而
  `FetchContent` / `FetchToc` 今天只收 URL。改端口会一路改到阅读器，超出"引擎规则面"的范围；登记为未实现，
  触发条件是语料里出现"因缺 bookName 而读不出正文"的实例（本轮 128 条里没有）。
- `webView` / `webJs` / `sourceRegex` / 字体反爬：无浏览器 DOM 与字体表，维持不支持。
- 单源重试 / 超时的**统一预算**（§3.7-B7）：聚合搜索继承 ADR-0046 的 60 s 单源超时，校验继承 ADR-0043 的
  180 s；两者都还没抽公共件，属登记项而非本轮范围。

## 影响

- `domain/url_rule.dart`（新）、`page_fetch_service.dart`（`fetchRule` / `headersOf` / `walk(rule:)`）、
  `rule_engine.dart`（分段链、列表 JS、`_resultOf`、`$.[…]`）、`url_template.dart`（charset 编码）、
  `charset_decoder.dart`（`declaredCharset`）、`http_client.dart`（`declaredCharset` + 流读异常）、
  `entities/book_source.dart`（`headerRule`）、五个 use case（改走 `fetchRule` / `headersOf`）。
- `tool/spot_check/batch_probe.dart`（新）与 `--plain-http`（`spot_check.dart`）：前者是 M12 的度量工具，
  后者让单源 spot-check 能跑 `http://` 源（与 App 里的用户开关同义）。

## 证据

真实语料 `4dc410d1.json`（128 条），同一台机器、同一关键词「剑来」：

| 轮次 | 四段全通 | 说明 |
|---|---|---|
| 改造前 | 8 | 54 条死在 `searchUrl`，54 条死在 `bookList`，3 条导入失败，2 条抛异常 |
| URL 后缀 + 流读异常 | 8 | `notFound` 20 → 11（后缀不再当 URL 发），`threw` 消失 |
| 本轮（含 `<js>` / 列表 JS / header 规则 / `$.[*]`） | **10** | `阅友小说` 从**导入失败**变成四段全通；`有声听书网` 由 `parseFailed` 变真命中；`飞卢小说💰` 目录页 291 → 1087 |

单源记录（`tool/spot_check/README.md` §4 的格式，`--plain-http`）：

- **阅友小说**（`https://sma.yueyouxs.com/`，`header` 为 `<js>…</js>`）：search=5、bookInfo=1、toc=57、
  content=676 / `sha256=d7e97e3157580991`。
- **飞卢小说💰**（`https://b.faloo.com`，`searchUrl` 带 `{"charset":"gbk"}`）：search=28、bookInfo=1、
  toc=1087、content=1156 / `sha256=d208052977d3039c`。

> 剩下的 118 条里，绝大多数是**站点已死**（域名无法解析 / 301 到别站 / 空体 / 需要登录 token），
> 逐条记录在 `build/probe3.json`（不入库）。这个数字不是"规则还能再好"的空间，而是语料的现实：
> 该文件是一份公开合集，发布后被下游站点反复迁移。

## 后果

- 好的方面：真实语料里能跑的源从 8 条变成 10 条，且**导入失败清零**；`url,{…}` 这条覆盖面最大的缺口被补上；
  一次"某个源崩了"不再能把整次聚合搜索打成失败。
- 代价：`RuleEngine` 多了一条分段链（值 / 列表各一份），`PageFetchService` 多了一个 `fetchRule` 入口。
  两处的重复都写成"同一段链的两种产物"，并由单测钉住 `{{result}}` / `列表 JS` 两个关键契约。
- 未闭环：A5（`java.get('bookName')`）、统一单源预算、`webView` 类源；都已登记进 roadmap §3.7。
