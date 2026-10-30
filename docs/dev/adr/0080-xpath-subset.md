# ADR-0080 M25/S5b：XPath 用自研子集兑现，不引依赖

- **状态：** Accepted（2026-10-27，用户裁决：自研 XPath 子集）
- **日期：** 2026-10-27
- **关联：** ADR-0078（引擎对齐切片）、ADR-0032 §决策 3（未知类型不静默降级）、
  ADR-0026 §决策 2（非顶层字段降级）、C-SRC-4（禁止静默忽略）、C-SRC-6（选择器交给成熟实现）、
  C-SRC-9（不可被不可信规则拖死）、C-DEP-7（许可证）、`docs/dev/book-source.md` §3 注记/§11、
  `docs/dev/engine-parity.md` §4/§9.2

## 背景

`engine-parity.md` §9.2 把「裸 `//`（XPath 省略标志）」列为**最大语法缺口**，原始统计是 43 源 / 155 处。
S5b 的原计划写的是「新依赖 + ADR」，即引入一个 XPath 实现。普查复核与选型结果推翻了这条前提：

1. **数字要按字段拆开看。** 工具口径是 **43 源 / 155 处**，构成：四段规则字段 100 处 / 21 源、
   URL 字段 31 处（`coverUrl` 15、`bookUrl` 5、`nextTocUrl` / `nextContentUrl` / `tocUrl` 各 3、
   `chapterUrl` 2——它们同样按规则求值）、以及 `bookSourceComment` 里的**脚本注释** 24 处
   （源把注释当代码库 `eval`，其中 `//` 是 JS 注释）。三者都是本仓会求值的文本，所以支持面按
   全部 155 处设计；真正落在四段规则字段的是 100 处 / 94 条不同表达式。
2. **pub 上没有能用的 XPath 包。** 全部候选都是 Dart 2 时代、2023 年后无人维护：
   `xpath_selector` 3.0.2（BSD-3，1025 行）与 `xpath_selector_html_parser` 3.0.1 的 SDK 都是
   `>=2.12.0 <3.0.0`，且 `xpath_selector` 依赖的 `expressions` 0.2.5（822 行）同样 `<3.0.0`。
   更关键的是它的 html 适配器 `HtmlNodeTree.children` 只暴露**元素**子节点（`node.children`），
   而语料 131 处里有 61 处用 `text()`——**不改 fork 就用不了**，等于接管两个已死的包。
3. **语料要的语法面很窄。** 94 条表达式只用到：绝对路径与 `/` / `//` 步、`*` / 标签 / `text()` 节点测试、
   `@attr` 属性轴、`[N]` / `[@a='v']` / `[contains(…)]` / `[not(…)]` / `[position() < last()-1]` /
   `[.//a]` 谓词、`|` 并集，以及一处 `following-sibling::a[1]`。

## 决策

**自研一个 XPath 1.0 子集**（`lib/features/book_source/domain/rule_engine/xpath_rule.dart`），不新增依赖。

### 决策 1 触发面：只认 `//` 与 `@xpath:`，不认单个 `/`

上游把「以 `/` 开头」的规则都当 XPath（`AnalyzeRule.kt:637-639`）。本仓不照搬：语料里没有一条 XPath
以单个 `/` 开头，而 `coverUrl: /static/x.jpg` 这种**根相对地址**完全可能落在规则字段里——按上游口径会
静默变成一条选不中的表达式。只认 `//` 与 `@xpath:`（大小写不敏感）把这条歧义关掉，并在 §3 注记里登记。

### 决策 2 表达式就是整个分支，不按 `@` 切段

`[@class='a']` 与 `/@content` 里的 `@` 属于 XPath 自己，按 `@` 切段会把它切碎（本仓的默认规则正是这样
切段的）。所以 `_readBranch` 一认出 XPath 就把**整条分支**交给编译器，`/@content`、`text()`、
`[position() < last()-1]` 都原样成立。`##regex`、`&&` / `||` / `%%`、`@js:` 仍在更外层切分，语义不变。

### 决策 3 支持面（写进 `book-source.md` §3 注记，代码与文档同批）

- **路径**：`/`、`//`、`.`、`..`、`@attr`；**节点测试**：标签名、`*`、`text()`；
- **轴**：`child` / `descendant` / `descendant-or-self` / `self` / `parent` / `following-sibling` /
  `preceding-sibling` / `attribute`；
- **谓词**：位置、`@a='v'`（单双引号）、`contains()`、`not()`、`starts-with()`、`position()`、
  `last()`（含 `last()-1` 这类算术）、存在性路径（`[.//a]`）、`and` / `or`；
- **并集**：`|`，答案是**节点集合**（按文档顺序去重）。

实现取舍三条：

1. **`//` 编成 `descendant-or-self::node()` + `child::test`**，与 XPath 1.0 的等价改写一致，因此
   `[N]` 的位置语义是「同一父节点下的第 N 个」，不是「整个结果列表的第 N 个」——语料里的
   `//*[@id="content"]/div/div[2]/…` 正是这个意思。
2. **结果是文档顺序，不是步展开顺序。** `//h2/a//text()` 要答 `<b>粗体</b>尾巴` 的先后；实现上按
   一次 DFS 建「节点 → 文档序号」表，再稳定排序（属性节点继承其宿主元素的序号）。
3. **元素的值 = 折叠空白后的整段文本**，与既有 `text` 提取同一口径；`text()` 只答**直接**文本子节点
   （XPath 1.0 如此；语料里 `//p[contains(text(),'作者：')]/text()` 拿到的就是 p 自己的那段文字）。

### 决策 4 拒绝面：具名，不静默

`rulePath` 为 `unsupported:xpath:<语法>`，命中即 `unsupportedRule`：

- 轴 `ancestor` / `ancestor-or-self` / `following` / `preceding` / `namespace`；
- 节点测试 `node()` / `comment()` / 处理指令、属性通配 `@*`；
- 函数 `count()` / `normalize-space()` / `concat()` / `substring*` / `name()` / `string()` 等
  （只实现 `contains` / `not` / `starts-with`）。

**列表规则必须选中元素**：`//div/text()` 这种在 `bookList` 位置上是 `parseFailed`（列表规则的答案要能当
scope），不静默少几条。对着 `JsonScope` 跑 XPath 也是 `parseFailed`（没有 DOM）。

## 后果

- **好的方面：** 21 个真实源（含 `coverUrl` 15 处、`name` 19 处）的 XPath 开始工作；没有新依赖、没有
  迁移、没有第三方代码要维护；拒绝面是具名的，缺什么一眼看得出来；`C-SRC-6` 的「选择器交给成熟实现」
  在这里是**有意例外**——没有可用实现，子集是自己写的，因此用 25 条单元测试逐条钉住语料表达式。
- **代价：** 自研解析器要跟语料一起演进（新轴/新函数要么实现、要么进拒绝面）；与上游的 JXPath 在
  边角上有差异（只认 `//`、`text()` 的直接子节点语义、结果顺序按文档）。
- **未做（触发条件）：** `ancestor` / `following` / `preceding` 轴与 `count()` 等函数——触发 = 真实语料
  出现且能给出复现源；届时按本 ADR 的支持面表追加，不重开选型问题。

## 被否的备选

- **Vendor `xpath_selector` + `xpath_selector_html_parser` + `expressions`：** BSD-3（许可证没问题），
  但三个包都 `<3.0.0`，且 html 适配器不暴露文本节点——`text()`（语料 61/131）用不了，必须真改 fork。
  接管 1.8k 行、只对 Dart 2 验证过的死代码，比自研 900 行我们自己的子集更贵。
- **把 XPath 翻译成 CSS 选择器：** `[position() < last()-1]` / `.//a` / `|` 都无法无损映射，且失败会变成
  静默的空结果，与 C-SRC-4 冲突。
- **维持具名拒绝：** 21 个源继续不可用，而这一刀正是 §9.2 里排在第一位的东西。

## 实现注记（2026-10-27 落地）

- 新文件 `xpath_rule.dart`（约 900 行，含文档注释）：`compileXPath` → `XPathCompiled` /
  `XPathUnsupported` / `XPathMalformed`；`XPathExpression.select(Node)` → `List<XPathMatch>`
  （`XPathElementMatch` 带元素，`XPathValueMatch` 带字符串值）。
- `rule_engine.dart`：`_deferredFlags` 去掉 `'//'` 与 `'@xpath:'`；`_readBranch` 新增 `_xpathTextOf` 与
  `_readXPath`；新增 `_XPathBranch` 与 `_matches` / `_values` 的两个分支（`_xpathElements` 要求元素、
  `_xpathMatches` 供值规则）；`_mergesTwoScopes` 把 XPath 视作 DOM 分支。
- 验证：`test/features/book_source/domain/rule_engine/xpath_rule_test.dart` 25 例（语料表达式逐条、
  谓词、拒绝面），`rule_engine_test.dart` 新增 `matrix #21` 组 10 例（含并集/文档顺序、具名拒绝、
  列表选文本失败、JSON scope 失败、DOM+JSON 连接符失败）；全量 `flutter test` **2656 例全过**，
  `dart format` 0 漂移，`flutter analyze` 0 警告，`check_coverage` exit 0（core 98.93 / domain 97.26 /
  data 95.68）。
- 文档：`book-source.md` §3 矩阵 #21 改「已确认」+ 新增 XPath 注记、§11 改为「XPath 未实现子集」具名
  列表、§10 拒绝测试行同步；`engine-parity.md` §4 #21 行、§9.2 的数字按字段拆开记、§9.4 排序。
- **复核更正（2026-10-27，S5c 期间发现）：** 落地时曾把 43/155 当成「误报」，那是把
  `bookSourceComment` 与 URL 字段排除在外的口径；实际三者都是本仓会求值的文本，43/155 是对的，
  本 ADR 的背景段落已按字段拆开更正。真正是误报的是**矩阵 #30** 的 22/125（见
  `book-source.md` 的 #30 注记与 `engine-parity.md` §9.2）。
