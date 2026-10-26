# ADR-0078 引擎目标升级：与上游行为几乎一致 + 高性能实现（允许重构）

- **状态：** Accepted（2026-10-26，用户裁决：行为对齐上游 + 高性能；允许重构引擎内核）
- **日期：** 2026-10-26
- **关联：** C-SRC-1…C-SRC-9、C-NET-7、ADR-0014（分期）、ADR-0029（异步形态）、ADR-0032（未知类型退化）、
  ADR-0037（`java.*` 兼容面）、ADR-0047 / ADR-0068 / ADR-0069 / ADR-0076（逐轮补口）、ADR-0077（测试精简）；
  台账 `docs/dev/engine-parity.md`；里程碑 `PLAN.md` M25–M27（`DECISIONS.md` #35–#37）

## 背景

ADR-0014 把引擎的验收定在「真实语料可用」：矩阵 #1–#19、#25–#31 逐条落地，M12/M21a/M24 又补齐了
`<js>` 分段链、URL 后缀选项、WebView 验证、字体反爬与同步 `java.*` 重放。结果是**大多数公开书源能跑**，
但离「与上游行为几乎一致」还有系统性距离，而且缺口分布很不均匀：

- **规则语法**只剩 4 条（`:` 正则、`@xpath:`、`@webJs`、提取段嵌套规则），而**字段层**缺了整整一族
  （`ruleContent.subContent` / `title` / `payAction` / `callBackJs`、`ruleToc.formatJs` / `isVolume` /
  `isPay` / `preUpdateJs`、`ruleBookInfo.downloadUrls` / `relatedBooks`）；
- **书源级 `jsLib` 完全未建模**：上游把它当每个脚本的 prototype scope，本仓连字段都没有 ——
  依赖库函数的源每条规则都 `js:error`，而这条缺口此前**没有任何文档登记**；
- **JS 绑定面**的密钥类 crypto（AES/DES/HMAC + 字节数组）被具名拒绝，而真实语料里大量正文解密走这条路；
- **URL 方言**有三处缺口（页码列表 `<1,2,3>`、段链 `@result`、query 全量按 charset 编码）；
- **非文本书源**（文件/视频）没有链路，图片源的 `imageDecode` 显式拒绝。

同时，引擎是纯 Dart 实现，本身有可识别的性能热点：规则文本每次求值都重新解析、每个字段重新建
`RuleScope`、目录/正文翻页串行、每条规则一个 JS job 的固定开销。既然对齐工作必然大范围触及
`rule_engine.dart` / `page_fetch_service.dart`，把「更快」与「更像」放在同一批次做，比为对齐后再推翻一次
更省。

## 决策

### 决策 1 目标：从「可用」升级为「几乎一致」，判据可复核

对齐的判据不是「我觉得像」，而是三条可核查的事实：

1. `docs/dev/engine-parity.md` 里**没有**未标注去向的「未建模 / 显式拒绝 / 部分」行；
2. 每一处与上游不同的行为，三选一登记 —— ① 修掉；② 「有意的差异 + 触发条件」；③ 「已知热点」（性能，归 M26）；
3. 语料回归（L1 = 128 条合集逐源归因，L2 = 全量合集只普查）的失败都能归因到网络 / 站点改版 / **已登记**的
   未实现能力，不存在「不知道为什么失败」。

### 决策 2 缺口清单的唯一出处是 `engine-parity.md`

`book-source.md` 只拥有**规范**（矩阵、字段映射、失败语义、JS 白名单），`roadmap.md` 只拥有**顺序与验收**，
`PLAN.md` 只拥有**里程碑状态**。缺口清单与语料命中数只写在 `engine-parity.md`，其他文档一律回链。
这与 ADR-0012 的 SSOT 一致，也避免出现本轮发现的那种「代码拒绝了、文档说支持」的漂移。

### 决策 3 允许重构引擎内核，但语义与红线不动

允许：规则编译结果缓存（`_parse` / `_check` 产物按 (规则文本, hasExtraction) 复用）、`FetchedPage` 级共享
`RuleScope`、条目批量提取复用、目录/正文翻页并发（上限沿用 `book-source.md` §8）、JS 脚本编译缓存。

不动：`ParseResult` / `ParseFailureKind` 契约、C-SRC-4（禁止静默忽略）、C-SRC-8（`rulePath` 可定位）、
JS 白名单与配额数值、书源并发与限速合成顺序、C-NET-7（不得整体读入大文件）、无 `dynamic` / `print` / `!`、
生成物不手改。**性能不得以放宽行为为代价**：行为测试与基准冲突时以行为为准 —— 先确认用例写的是上游语义，
再改实现；确实要放宽行为必须另开 ADR。

### 决策 4 性能指标先定数，再优化

P1 单章（≤200KB HTML，3 段规则）解析→提取→`replaceRegex` ≤ 40 ms；P2 千章目录 ≤ 300 ms 且近似线性；
P3 同一规则一次会话只编译一次（命中率 ≥ 95%）；P4 一页只 parse 一次；P5 JS job 固定开销 ≤ 3 ms；
P6 单章峰值增量 ≤ 8 MB、千章目录 ≤ 32 MB。基准脚本落 `tool/bench/`（不进 CI，与 `tool/spot_check/` 同模式），
每张重构 PR 附前后数字；数值只在实测后收紧，放宽需新 ADR。

### 决策 5 文档与代码的一致性由门禁兜住

新增两条用例（只加不删）：G1 把 `book-source.md` §11 的拒绝名单与 `quickjs_worker.dart` 的
`__javaRejectedNames` 对照，两侧不一致即失败；G2 矩阵「已确认」行按表驱动查漏。理由：本轮发现的
`<js>` 与列表 `@js:` 两处矛盾，都是「文档改了一半、代码改了一半」。

### 决策 6 分期：先对齐、再提速、最后以语料收口

M25（对齐，`#35`）→ M26（性能，`#36`）→ M27（语料回归与台账清零，`#37`）。切片内部允许交错
（例如 S1 `jsLib` 与 R5 JS 编译缓存天然同批），但**每片独立过全部门禁**，且 S7（文档收敛）必须最后做，
否则台账会再次与代码脱节。

## 后果

**正面**：目标可复核；缺口有唯一清单与语料数字，排序不再拍脑袋；性能与行为在同一套测试下演进；
`jsLib` / `isPay` / `subContent` 这类「静默不生效」的字段第一次被登记。

**负面 / 风险**：

- `@xpath:`（#21）与 `:正则`（#20）各要新增能力面（依赖 / 正则模式），属 ADR-0014 曾要求「先开 ADR」的两条，
  落地时按本条 ADR 的决策 1 逐个补 ADR 到 `docs/dev/adr/`，不在这里一次性批发。
- 密钥类 crypto 要用「受控句柄」重做字节族（Dart 没有 Rhino 的 `ByteArray`），这是一次跨 `core/js` 的接口改动，
  风险集中在沙箱边界；失败时退路是继续具名拒绝（已登记，不算回归）。
- 非文本书源（文件/视频）体量可能吞掉整个里程碑，按 M27 普查结果切出去另立里程碑，不在 M25 内硬塞。
- 性能重构会动 `rule_engine.dart` 的既有结构，测试精简（ADR-0077）后的表驱动用例是唯一保护网，
  因此 M26 开工前必须先把 S7 的 G2 落地。

## 被否的备选

| 备选 | 否决理由 |
|---|---|
| 维持「够用」不追对齐 | 与用户目标冲突；且 `jsLib` 这类缺口会让整源静默失效，用户无法判断是站点坏了还是引擎不支持 |
| 一次性重写引擎 | 会丢掉现有 270+ 条规则引擎用例与四段真实语料回归资产，风险不可控 |
| 逐行移植上游 Kotlin | 上游依赖 Rhino 类型系统、jsoup/jayway 方言与 Android WebView 行为，逐行移植会把 Android 依赖带进来，违反 C-PLT 与依赖白名单 |

## 实现注记（2026-10-26，S1 `jsLib` 落地）

决策 2/3/6 在切片 S1 上的落地形态（行为面归 `book-source.md` §6，台账状态归 `engine-parity.md` A1）：

1. **解析放在引擎、执行放在 worker。** worker 是 isolate 且不能取页，所以 `JsLibStore`（`core/js/js_lib.dart`）
   先在宿主侧把 `jsLib` 变成一段可运行的文本，再由 `RuleEngine` 随 job 下发（`JsJob.jsLib`）。
   这与「`parse.*` 在宿主、求值在 worker」是同一条分层。
2. **两种形态都照抄上游。** 纯 JS 原样用；JSON 对象只下载 `http(s)` 开头的值、按对象序拼接（非 URL 值忽略）。
   缓存键是 `jsLib` **原文**、上限 16（与上游 `LruCache` 同数）、失败不缓存、同键单飞——一页二十个 `@js:`
   字段只解析一次。
3. **作用域用「同一函数里的两次 eval」兑现。** QuickJS 没有 Rhino 的 prototype 链，所以 worker 的前奏多了
   `__runRuleWithLib(lib, rule)`：先 `eval(lib)` 再 `eval(rule)`，两次都在该函数的变量环境里 —— 库的
   `var` / `function` 对规则可见，又都不会漏到 `globalThis`（上游用 `preventExtensions` 达到同一效果）。
   代价是库顶层的 `let` / `const` 对规则不可见（它们属于第一次 eval 的词法环境），而 Rhino 是 ES5 本来也不认。
4. **`jsLib` 是行为字段**：进 `BookSource`、进 payload 往返、进书源指纹（库变了就是不同的源）。
5. **失败可归因。** 下载失败 → `ParseFailure(kind, rulePath: '<field>:js:lib')`；库自身抛错 → worker 在信封里
   带 `libError`，桥同样折成 `js:lib`。规则自己的错仍是 `js:error`。三者混在一起会让人以为是站点变了。
6. **不新增依赖、不动配额。** 库脚本与规则共用同一个 job 的 5 s / 32 MB / 20 调用额度（ADR-0030），
   没有为库单独开预算；重放层（ADR-0076）对它同样生效——库里的 `java.ajax` 也会触发整条 job 重跑。

验证：`test/core/js/js_lib_test.dart`（11 例：两形态、非 URL 值、坏 JSON、下载失败、无 HTTP 端口、单飞、
LRU、失败重试）、`rule_engine_test`（job 携带解析后的库 + 解析失败即规则失败且不执行 job）、
`js_bridge_lib` 相关 2 例（job 透传、`libError` → `js:lib`），以及真引擎探针 4 条（库函数可用、库抛错
归因、库里同步取页触发整条重放、无库时上一条库不泄漏）在 **Windows 与 Android 模拟器**双端全绿。

## 实现注记（2026-10-26，S2 第一半：目录字段族 + `bookUrlPattern`）

决策 1/6 在 S2 上的落地形态（行为面归 `book-source.md` §4.1 / §4.1b / §6，台账状态归
`engine-parity.md` 3.1–3.3）：

1. **`formatJs` 是「一条脚本跑 N 章、一个作用域」，所以它是一个 job。** 逐章各开一个 job 会丢掉
   `gInt` 的跨章累积（上游把 `gInt` 只初始化一次），也会把千章目录变成千次 worker 往返。worker 的
   前奏因此多了一个运行器 `__formatTitles(lib, script, chapters)`：同一函数作用域里 `for` 循环 +
   `eval`，`index` / `chapter` / `title` 每轮重绑、`gInt` 自然累积；某章抛错按 `null` 交回（保留原
   标题），与上游 `runCatching(...).onFailure` 同义。库脚本（S1）在这个作用域里同样可见。
2. **`preUpdateJs` 在 `walk` 之前跑，失败即失败**（上游 `runPreUpdateJs(...).getOrThrow()`）；本仓
   连第一个请求都不发，`FetchToc` 的两个失败分支分别对应「脚本坏了」与「页面取不到」。
3. **卷占位与无名条目**：`isVolume` 且无 URL → `title + index`（上游连分隔符都没有，照抄）；名字读不
   出来的条目整条丢弃——这同时推翻了 ADR-0026 时代「名字降级为空、条目保留」的旧行为，因为上游的
   `if (title.isNotEmpty)` 是条目**存在**的条件，而 ADR-0026 管的是**字段**可否降级。
4. **`bookUrlPattern` 复用 `ruleBookInfo` 的读取器**（`FetchBookInfo.readFromPage`），而不是在搜索侧再
   写一份字段解析：同一页、同一套规则、同一个 scope，两个阶段不可能读出不同的书。
5. **行为变化（有意）**：「搜索页一条都没命中」从 `parseFailed` 变成回落详情页 → 仍无书则**空结果**。
   上游本来如此（`BookList.kt:100-110`），但这条变化影响了书源校验的语义，所以校验侧补了
   `emptyRulePath`：空结果仍判「搜索失效」，只是 `rulePath` 指回**列表规则**而不是 `searchUrl`。
6. **不做的两件事会写在台账里**：`subContent` / `title` 的执行要 `FetchContent` 返回 `ChapterContent`
   （正文 + 副文 + 改名 + reviewImg + 音频歌词），那是 S2 的第二半；`payAction` / `callBackJs` /
   `eventListener` 需要付费解锁 UI 与读者事件面，登记为有意差异。

验证：`fetch_toc_test`（新增 8 例：isPay/wordCount、卷占位、无名丢弃、去重、formatJs 单 job、formatJs
失败、preUpdateJs 顺序、preUpdateJs 失败不发请求）、`search_books_test`（新增 4 例：pattern 命中、空
列表回落、pattern 不匹配、坏正则 warning）、真引擎探针 3 条（`index`/`gInt` 跨章、某章抛错保留原名、
formatJs 里可见 `jsLib`）在 **Windows 与 Android 模拟器**双端全绿。

## 实现注记（2026-10-26，S2 第二半：`subContent` / `title` 与 `ChapterContent`）

1. **正文阶段换返回形状，而不是再串一个端口。** `FetchContent.execute` 现在答 `ChapterContent`
   （`body` / `title` / `reviewImg` / `lyric`）：副文、正文页标题、歌词都是**同一次读取**的产物，
   分成多个返回值会让上层再读一遍页面。阅读器端口保持 `String`，装配根取 `.body` —— 阅读端要不要
   显示改名与歌词是另一件事（已登记），不该为此把两边的类型绑在一起。
2. **顺序照抄上游**：`content` → `subContent` → `title` → `replaceRegex`。`replaceRegex` 的文档语义
   是「对**拼接后**的整章正文应用」，所以副文必须先并进去；`title` 必须读**第一页**的 scope，而不是
   替换后的文本。
3. **副文是地址时取那一页的正文原文**（上游 `AnalyzeUrl(...).body`）。为此 `PageFetchService` 多了
   `plainBody`：走同一个 `fetchRule`（预算 / header / 登录拦截都在），但只回文本、不建 scope。
   取不到只记 warning —— 副文缺了正文仍然可读，这与「正文缺页整章失败」不是一回事。
4. **`reviewImg` 用「最后一个 media URL」切分**，并把标题里残留的标签剔掉。上游的
   `(.*)((?:data|https?):[\s\S]+)$` 在 `@html` 取值下会把 `<div id=…>` 甚至半个 `<img src="` 当成
   标题，那不是章节名；这处差异记进 `book-source.md` §4.1。
5. **缓存按整个结果存，但只带额外信息时才换形状**：纯正文仍写纯文本（旧形状、零迁移、调试页读到的
   还是正文），有标题/歌词时写一行带版本号的 JSON；读不懂就按正文处理（丢一个缓存条目的代价是重读）。
6. **不做的事登记在台账**：`payAction` 要付费解锁 UI、`callBackJs`/`eventListener` 要读者事件面；
   阅读端采用 `title` / `lyric` 需要阅读器与音频面板的改动，也单独登记。

验证：`fetch_content_test` 新增 9 例（文本副文追加、音频歌词、副文取页、副文页失败仍给正文、标题改名 +
reviewImg、只有图时保留目录名、`replaceRegex` 看得到副文、二次读命中仍给标题/歌词）与全量
`flutter test` 2385 例全过。
