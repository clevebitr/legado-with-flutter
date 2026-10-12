# 书源规格（对标原版阅读 / Legado）

> 本文档是书源解析的**唯一规格来源**：字段模型、规则语法矩阵、实现分期、失败语义、测试基线。
> 实现约束见 `docs/dev/constraints.md` §5（C-SRC-1..9）；
> 功能范围与分期见 §3.1 与 ADR-0014。
>
> **对标原则：** 支持矩阵逐条对标**原版阅读（Legado）**公开规则说明，
> 不做方言扩展、不自造语法。每条语法的「状态」一律从 `待验证` 起步，
> 只能由**真实书源回归记录**（§10）改为 `已确认`。
>
> **上游状态（2026-10-11 核实）：** `gedoor/legado` 仓库已**清空**——默认分支只剩一份侵权公告，
> 上游源码不再可得。因此「对标原版」此后只能以**本仓 §3 的规格**与**仍在维护的 fork**
> 为准（本次实现矩阵 #1/#2/#5/#8/#9 时核对的是 `hapelee/legado-with-MD3` 的
> `AnalyzeRule.kt` / `AnalyzeByJSoup.kt`）；§3 矩阵的「状态」列仍按原规则由真实书源回归
> 逐行确认。ADR-0014 已加同一事实的附注。

---

## 1. 范围

| 目标 | 说明 |
|---|---|
| 兼容 | 直接导入原版阅读的书源 JSON，在不修改规则的前提下完成搜索 → 详情 → 目录 → 正文 |
| 不兼容 | 不实现登录脚本与登录 UI、RSS/订阅源、朗读规则、需要浏览器 DOM 的网页 JS |
| 引擎 | 纯 Dart，无 Flutter 依赖（C-SRC-1）；JS 规则在独立 Isolate 执行（C-SRC-2） |
| 分期 | M0 为「首个可导入版本」的必达范围，见 §3.1 |

---

## 2. 书源 JSON 模型

字段名映射到 Dart 时必须转为 camelCase（`naming.md` §5）。

| 原版字段 | Dart 字段 | 类型 | 分期 | 说明 |
|---|---|---|---|---|
| `bookSourceName` | `name` | `String` | M0 | 必填 |
| `bookSourceUrl` | `url` | `String` | M0 | 必填，参与缓存键 |
| `bookSourceGroup` | `group` | `String?` | M0 | — |
| `bookSourceType` | `sourceType` | `BookSourceType` | M0 | 0 文本 / 1 音频 / 2 图片 / 3 文件 |
| `enabled` | `isEnabled` | `bool` | M0 | 默认 `true` |
| `header` | `headers` | `Map<String, String>?` | M0 | 原为 JSON 字符串，导入时解析 |
| `searchUrl` | `searchUrl` | `String?` | M0 | 支持 `{{key}}` / `{{page}}` |
| `exploreUrl` | `exploreUrl` | `String?` | **M1** | 发现页 |
| `ruleSearch` | `searchRule` | `SearchRule` | M0 | 必填 |
| `ruleBookInfo` | `bookInfoRule` | `BookInfoRule?` | M0 | 缺失时从搜索页继承 |
| `ruleToc` | `tocRule` | `TocRule` | M0 | 必填 |
| `ruleContent` | `contentRule` | `ContentRule` | M0 | 必填 |
| `concurrentRate` | `concurrentRate` | `String?` | **M1** | 并发限速 |
| `variableComment` | `variableComment` | `String?` | **M1** | 书源变量说明 |
| `loginUrl` / `loginUi` / `loginCheckJs` | — | — | **M2** | 登录相关，暂不实现 |
| `lastUpdateTime` / `respondTime` / `weight` / `customOrder` | 同名 | `int?` | M0 | 仅用于展示与排序 |

**子规则字段**（原版字段名 → Dart，全部 camelCase）：

| 规则对象 | 字段 | 分期 |
|---|---|---|
| `SearchRule` | `bookList`、`name`、`author`、`kind`、`wordCount`、`lastChapter`、`intro`、`coverUrl`、`bookUrl` | M0 |
| `BookInfoRule` | `init`、`name`、`author`、`kind`、`lastChapter`、`intro`、`coverUrl`、`tocUrl`、`wordCount`、`canReName` | M0（`canReName` 为 M1） |
| `TocRule` | `chapterList`、`chapterName`、`chapterUrl`、`isVip`、`updateTime`、`nextTocUrl` | M0（`updateTime` 为 M1） |
| `ContentRule` | `content`、`nextContentUrl`、`replaceRegex` | M0 |
| `ContentRule` | `webJs`、`sourceRegex`、`imageStyle` | **M2** |

模型必须使用 `freezed` + `json_serializable`（C-SRC-7）。未知字段必须**保留而非丢弃**：
在 `extra` 中承载，以便导出时不丢信息。

> **层归属与 `extra` 的落地形态**见 ADR-0021（模型位于 `domain/entities/`；`extra` 由
> `fromLegadoJson` 逐层填充）。本表只拥有字段映射与分期。

---

## 3. 规则语法支持矩阵（对标原版阅读）

> 「原版适用字段」列取自原版规则说明（原版说明中标注「仅书籍列表和目录列表」的语法
> 才限定字段，其余为**所有字段**可用）。

| # | 语法 | 原版示例 | 原版适用字段 | 分期 | 状态 |
|---|---|---|---|---|---|
| 1 | 默认规则：`类型.名称.位置` | `class.odd.0@tag.a.0@text` | 所有字段 | M0 | 待验证 |
| 2 | 类型 `class` / `id` / `tag` | `id.content@text` | 所有字段 | M0 | 待验证 |
| 3 | 类型 `text`（按文本内容匹配） | `text.最新章节` | 所有字段 | M0 | 待验证 |
| 4 | 类型 `children`（取全部子标签，忽略第二、三段） | `class.list@children` | 所有字段 | M0 | 待验证 |
| 5 | 位置：正索引与负索引（`-1` 为倒数第一） | `tag.li.-1@text` | 所有字段 | M0 | 待验证 |
| 6 | `!` 位置排除（序号用 `:` 分隔，支持负数） | `tag.li!0:1@text` | 所有字段 | M0 | 待验证 |
| 7 | 列表首字符 `-` 使结果**倒置** | `-class.odd@tag.a@href` | 所有字段 | M0 | 待验证 |
| 8 | 提取内容：`text` / `textNodes` / `ownText` / `html` / `all` / `href` / `src`（及其他 HTML 属性名） | `tag.a@href` | 所有字段 | M0 | 待验证 |
| 9 | 正则替换 `##正则##替换内容`（替换为空时可省略第二个 `##`） | `tag.p@text##全文阅读` | 所有字段 | M0 | 待验证 |
| 10 | `\|\|` 依次尝试，首个非空即成功 | `class.odd.0@tag.a.0@text\|\|tag.dd.0@tag.h1@text` | 所有字段 | M0 | 待验证 |
| 11 | `&&` **合并两侧结果（并集，非串联；仅限同种规则，不含 js 与正则）** | `class.odd.0@tag.a.0@text&&tag.dd.0@tag.h1@text` | 所有字段 | M0 | 待验证 |
| 12 | `@css:` 标准 CSS 选择器 | `@css:.book-list li@text` | 所有字段 | M0 | 待验证 |
| 13 | `@json:` JSONPath（以 `$.` 开头时可省略标志） | `@json:$.data.list[*].name` | 所有字段 | M0 | 待验证 |
| 14 | `@js:` JavaScript | `@js:result.replace(/\\s/g,'')` | 所有字段 | **M0** | 待验证 |
| 15 | `@@` 默认规则标志（在 `{{}}` 内使用时必填） | `@@class.odd.0@text` | 所有字段 | M1 | 待验证 |
| 16 | `@put:{key:rule}` / `@get:{key}`（**仅限 js 以外**的规则；`@put` 内 JSONPath 不加引号，其他规则加引号） | `@put:{bid:"//*[@bid-data]/@bid-data"}` | 所有字段 | M1 | 待验证 |
| 17 | `java.put(key,value)` / `java.get(key)`（**仅限 js 内**，js 中不能使用 `@get`） | — | 所有字段 | M1 | 待验证 |
| 18 | `{{}}` 内嵌规则 / JS（搜索 URL 与发现 URL 内**只能**用 JS；其他位置默认 JS，用其他规则必须带标志头 `@@` / `//` 或 `@xpath:` / `$.` 或 `@json:` / `@css:`） | `{{result.match(...)}}` | 所有字段 | M1 | 待验证 |
| 19 | `{}`（阅读 2.0 遗留规则，**只能**用 JSONPath，应尽量避免） | `{$.data.name}` | 所有字段 | M1 | 待验证 |
| 20 | `:正则规则`（不可省略标志；**仅书籍列表与目录列表**） | 待按原版实现确认 | 仅书籍列表、目录列表 | **M2** | 待验证 |
| 21 | `@xpath:` XPath（以 `//` 开头时可省略标志） | `@xpath://div[@id='a']/text()` | 所有字段 | **M2** | 不支持 |
| 22 | `@webJs` 网页 JS | — | 正文规则 | **M2** | 不支持 |
| 23 | `sourceRegex` 源码正则 | — | 正文规则 | **M2** | 不支持 |
| 24 | 字体反爬字形映射 | — | 正文替换规则 | **M2** | 不支持 |
| 25 | `##match##replace###`：只取**第一个匹配**并在其内部替换（矩阵 #9 的补充语义） | `##match##replace###`（上游注释原文） | 所有字段 | **M0**（Phase 2.2 已实现） | 待验证 |
| 26 | `[]` 索引列表：`[-1, 3:-2:-10, 2]`、`[-1:0]` 可在任意位置反向（与 #5 / #6 同组） | `tag.div[-1, 3:-2:-10, 2]` | 所有字段 | **M0** → Phase 3.1 | 待验证 |
| 27 | `%%` 并行交叉合并（与 `\|\|`、`&&` 同级的选择器连接符） | — | 所有字段 | **M0** → Phase 3.2（与 #10 / #11 同族，复用同一套连接符切分） | 待验证 |
| 28 | 索引作为 `@` 分段后每段的首规则：`.1` / `[1]` / `!0` / `children[1]`，等价于 `children` + 该索引（可与 #5 / #6 / #26 的位置写法组合） | `head@.1@text`、`head@[1]@text`、`head@children[1]@text`（等价） | 所有字段 | **M0** → Phase 3.1（已实现） | 待验证 |
| 29 | `@css:` 内的 jsoup 索引伪类 `:eq(n)` / `:gt(n)` / `:lt(n)`（**兄弟索引**，0-based，**不是**结果集索引） | `@css:div#info > p:eq(3) @text` | 所有字段 | **M0** → Phase 3.2 | 待验证 |
| 30 | 提取段里的**嵌套规则**（末段本身是一条规则，如 `class.a@css:.b`） | `class.a@css:.b` | 所有字段 | **M2 / 暂不实现**（复审触发条件：真实语料统计显示使用率 > 0 且影响可用率时改判 M1） | 不支持 |

> **#25–#27 为 2026-10-11 补录（回执 B3）：** 这三条语法此前只存在于上游实现里，本仓矩阵没有行，
> 于是出现「引擎拒绝得对、账本却没记」的缺口。补录时**追加在表尾而不是插在中间**：`PLAN.md`
> 与 ADR-0014 都按 `#1–#14` / `#15–#19` / `#20–#24` 引用矩阵，插入会打乱既有编号
> （与 `docs/README.md` §5 的 ID 稳定性同一原则）。上游证据：`AnalyzeRule.kt:497`（`###`）、
> `AnalyzeByJSoup.kt` 的 `ElementsSingle` 注释（`[]`）、`AnalyzeByJSoup.kt:88` 的
> `splitRule("&&", "||", "%%")` 与 `:110` 的交叉合并实现（`%%`）。

> **#29 / #30 与 `&&` 语义修正（2026-10-11，架构师裁决 1 / 3 / 4 / 5）：**
>
> - **`&&` 语义修正（属规格缺陷，不是歧义）：** 本行此前写「串联多级」、§3.2 写「按 `&&` 切分为
>   多级」，与上游不符。上游公开规则说明（mgz0227 教程、teachme.pages.dev、celeter、missdeer
>   转存的官方文本）与第三方方言实现一致：**`&&` 合并两侧结果（并集）、`||` 取首个有值、
>   `%%` 交叉取数**，且**只在同种规则间使用（不含 js 与正则）**；官方示例
>   `class.odd.0@tag.a.0@text&&tag.dd.0@tag.h1@text` 两侧都是值规则，串联读法下必然为空。
>   **合并的去重与顺序（是否去重、是否按规则先后）行为未确认**（未钉到上游实现行号）：本仓按
>   「拼接、按规则先后、不去重」实现，待 3.7 的真实书源回归核实。跨类型合并（列表规则 `&&`
>   值规则）必须**显式失败**，不得静默拼成异构列表。
> - **#29（jsoup 索引伪类）依据两层：** 仓内真实语料（`legado_export_sanitized.json` 的
>   `@css:dl > div.btm > em:eq(1) @text`、`@css:div#info > p:eq(3) @text ##字数：`，见
>   `book_source_test.dart`）与 jsoup 官方语义（`:eq(n)` / `:gt(n)` / `:lt(n)` 用
>   `elementSiblingIndex()`，0-based；jsoup 自带测试 `SelectorTest.testPseudoEquals` 的
>   `div p:eq(0)` 每个 `div` 各取一个 `p`）。实现方式是把它们**改写成 cascadia 已有的
>   `:nth-child`**（匹配仍全在 cascadia 内，C-SRC-6）：`:eq(1)` → `:nth-child(2)`（**纯整数才是
>   「相等」**，写成 `:nth-child(n+2)` 会匹配该位置之后的全部兄弟）、`:gt(1)` →
>   `:nth-child(n+3)`、`:lt(3)` → `:nth-child(-n+3)`。**负索引：** jsoup 公开文档把索引伪类
>   定义为 0-based，**没有定义负索引**（本仓未核实 jsoup 对负数的实际行为，故不猜），一律报
>   可定位的 `unsupported::eq(-1)`，不静默当空结果（C-SRC-4）。
> - **#30（提取段嵌套规则）暂不实现：** 它要把提取契约从封闭集合（text / textNodes / ownText /
>   html / all / 属性）扩成「提取值可以是子规则」，与 `##` 替换、以及 JSON / JS 的 scope 改造
>   三者叠加，属「接口形状未定型就横向铺开」；且当前无使用率证据。`rulePath` 用
>   **`unsupported:nested-rule`**，与已支持的中段 `@css:` 区分开。
> - **#12 注记（裁决 5）：** `@css:` 内的**状态伪类**（`:hover` / `:visited` / `:focus` …）在静态
>   DOM 下**恒不匹配**，这是正确答案而不是错误：实现为「成功且结果为空」，不报
>   `unsupportedRule`。同处登记两处 cascadia ≠ jsoup 的差异（当前都表现为 `parseFailed`，
>   属「响亮失败」，可接受）：`:containsOwn(a b)` 这类**不带引号的多词参数**会报
>   `Invalid argument`（jsoup 接受；真实语料的 `containsOwn(下一页)` 无空格，可用）；
>   `:matches(x)` 必须写成 `:matches(/x/)`（jsoup 收裸正则）。

> **#13 注记（2026-10-11，随 3.2 落地；接口裁决见 ADR-0028）：**
>
> - `@json:` 与裸 `$.` / `$[` 作用于 **scope**：整页 scope 同时带 DOM 与原始 body，
>   所以同一页的不同字段可以各用各的（一条规则内混用两种 scope 头则不行，见下）。
> - **值规则的结果：** 字符串原样；数字 / 布尔按 JSON 写法；`null` 与空串**不产生值**
>   （与矩阵 #8 的空提取同口径）；对象 / 数组按 **JSON 文本**返回（上游 Java 的
>   `Map.toString` `{a=1}` 不可复现，待 §10 真实语料回归确认）。
> - **scope 答不了的规则报 `parseFailed`（带字段路径）**，不是 `unsupportedRule`、
>   更不是空结果：语法是支持的，是这一页回答不了。非顶层字段仍按 ADR-0026 降级为
>   「置空 + warning」。JSON 分支与默认 / `@css:` 分支用 `&&` 合并同样报 `parseFailed`
>   （§3 的 `&&` 注记：连接符只合并同种规则）。
> - **`@json:` 出现在非分支首位**（如 `class.a@json:$.b`）仍报 `unsupported:@json:`：
>   元素内部的 JSON 需要提取段嵌套规则，那是矩阵 #30 的边界，不在 3.2 范围。

> **#28 为第二轮补录（2026-10-11，架构师裁决 Q4(1)）：** 上游规则文档明确「允许索引作为 `@`
> 分段后每个部分的首规则，此时相当于前面是 `children`」，并给出 `.1` / `[1]` / `children[1]`
> 三条等价式。本仓初版按「不在矩阵内」显式拒绝，评审判定为 M0 功能缺口，故补行 + 实现 + 单测。
> 与 #4 的边界由实现固定：点号后是**字母**（`children.li.0`）归 #4（忽略第二、三段），
> 是**索引写法**（`children.1`、`children[1]`）归 #28。
>
> **#3 的语义依据（架构师 2026-10-11 核实）：** `AnalyzeByJSoup.kt:319` —— `text` 按元素的
> **自身文本**匹配（jsoup `getElementsContainingOwnText`，大小写不敏感）。因此文本落在子元素里的
> 外层节点**不**算命中；该规范化与 #8 的 `ownText` 提取共用同一份实现。
>
> **一处刻意比上游更严的差异（登记）：** `tag.div[-1].0`（`[...]` 与第三段位置同时出现）在本仓
> 返回 `parseFailed`；上游会把 `[-1]` 当成名称的一部分而**静默返回空结果**。按 C-SRC-4
> 「禁止静默忽略」的口径取显式失败，此处登记以免日后被当成实现缺陷。

**大小写处理：** 原版文档同时出现 `@css:` / `@CSS:`、`@json:` / `@Json:` 等写法。
本项目按**前缀大小写不敏感**实现，并为每种前缀补一条测试（状态：待验证）。

### 3.1 实现分期（对齐 ADR-0014）

| 阶段 | 范围 | 完成判定 |
|---|---|---|
| **M0** | 矩阵 #1–#14、#25、#26、#27、#28、#29；搜索 / 详情 / 目录 / 正文四段完整字段；`nextTocUrl`；`nextContentUrl`；`{{key}}`、`{{page}}`、`{{baseUrl}}` | 至少 2 个真实书源完成「搜索 → 详情 → 目录 → 正文」离线回放 |
| **M1** | 矩阵 #15–#19；`exploreUrl` 发现页；`canReName`；`updateTime`；`java.timeFormat`；`concurrentRate` | 每条语法至少 1 条真实书源验证记录 |
| **M2 / 暂不实现** | 矩阵 #20–#24、#30；登录脚本与登录 UI；RSS / 订阅源；朗读规则 | 命中时返回 `ParseFailure(unsupportedRule)` |

**M0 未全部通过前，不得发布「支持导入书源」的版本。**
命中 M2 或任何未实现语法时，禁止静默返回空结果（C-SRC-4）。

### 3.2 解析顺序

```
原始规则串
  → 按 `||` 切分候选（依次尝试，首个非空即成功）
    → 每个候选按 `%%` / `&&` 切成**并列分支**（各分支从同一 scope 求值：
      `&&` 合并两侧结果、`%%` 交叉取数）
      → 每个分支：识别前缀标志（@@ / @css: / @json: / @js: / @xpath: / 默认）
        → 按 `@` 分段：类型段（可多段） → 提取段
        → 应用位置、负索引、`!` 排除、首字符 `-` 倒置
        → 取出内容（text / textNodes / ownText / html / all / 属性）
  → 最后按顺序应用所有 `##` 替换
```

### 3.3 默认规则的段结构（原版语义）

| 段 | 说明 |
|---|---|
| 第 1 段 | 类型：`class` / `id` / `tag` / `text` / `children` 等；`children` 取全部子标签，**忽略第 2、3 段** |
| 第 2 段 | 名称；`text` 类型时表示「文本内容的一部分」 |
| 第 3 段 | 位置：正索引从 0 开始，负数取倒序；不加位置表示取全部 |
| 末段 | 提取内容：`text` / `textNodes` / `ownText` / `html` / `all` / `href` / `src` 等，或 HTML 属性名 |

---

## 4. URL 模板与变量

渲染必须统一经 `renderUrlTemplate`（C-SRC-5），禁止手写拼接。

| 变量 | 适用位置 | 含义 | 分期 |
|---|---|---|---|
| `{{key}}` | `searchUrl` | URL 编码后的搜索关键词 | M0 |
| `{{page}}` | `searchUrl`、`nextTocUrl`、`nextContentUrl` | 页码，从 1 开始 | M0 |
| `{{baseUrl}}` | 全部 | 当前页 URL（JS 中同名变量） | M0 |
| `{{}}` 内嵌规则/JS | 其他字段 | 默认按 JS 求值，见矩阵 #18 | M1 |
| `{{变量名}}` | 全部 | `@put:` / `@get:` 读写的变量 | M1 |

约定：

- 关键词**必须** URL 编码，且只编码一次、不重复编码。
- 相对 URL（以 `/` 或非协议开头）必须以当前页 URL 为基准解析为绝对 URL。
- 未定义的变量渲染为**空字符串**并记录 warning；不得保留 `{{...}}` 原文。
- 在**搜索 URL 与发现 URL** 中，`{{}}` 内只允许 JS；解析器必须拒绝在其中写非 JS 规则。

### 4.1 目录与正文的特殊规则

| 规则 | 原版语义 | 分期 |
|---|---|---|
| `chapterList` | 结果列表；**首字符 `-` 使列表反序** | M0 |
| `chapterName` / `chapterUrl` | 章节名与章节 URL（相对路径需转绝对） | M0 |
| `isVip` | 结果为 `null` / `false` / `0` / `""` 时视为**非 VIP** | M0 |
| `updateTime` | 可调用 `java.timeFormat(timestamp)` 转为 `yyyy/MM/dd HH:mm` | M1 |
| `nextTocUrl` | 支持**单个 URL** 或 **URL 数组**；JS 返回 `[]` / `null` / `""` 时停止加载下一页 | M0 |
| `content` | 正文内容；可含多个 `##` 替换 | M0 |
| `nextContentUrl` | 正文分页；返回空即停止 | M0 |
| `replaceRegex` | 正文的批量替换规则 | M0 |
| `canReName` | 允许重命名书籍 | M1 |

---

## 5. 编码

- 必须使用 `betto_charset_detector` 检测（C-NET-3），检测顺序：
  HTTP `Content-Type` → HTML `<meta charset>` → 字节嗅探 → 回退 UTF-8。
  前两步是**权威声明**：只要有声明就必须用它，嗅探仅用于两者都缺失的页面。
- 检测结果必须缓存到「书源 ID + URL」维度，避免重复嗅探。
  **分期：Phase 3.9；M0 不要求**（§3.1 的 M0 枚举不含此项，本标注用于消除本节与 §3.1 的
  口径不一致；架构师裁决 F1，验收见 `PLAN.md` §3 的 3.9 行）。
- 解码失败返回 `ParseFailure(encodingFailed)`，
  禁止用 `utf8.decode(allowMalformed: true)` 静默吞掉。

### 5.1 可解码的编码集与已知缺口（实测 2026-10-11）

检测得到的是 IANA 标签，解码由 `charset` 把标签变成 `Encoding`（`tech-stack.md` §5）。
标签空间比解码器空间大，**未支持的标签会回落到 UTF-8**，通常接着以
`encodingFailed` 失败（安全，但功能缺失）：

| 标签 | 结果 |
|---|---|
| `utf-8`、`utf-16le/be`、`utf-32le/be` | ✅ |
| `gbk`、`gb2312`、`gb18030`、`cp936` | ✅（四者共用 GBK 解码器） |
| `windows-1252`、`iso-8859-1/2/15`、`latin1` | ✅ |
| `shift-jis`、`euc-jp`、`euc-kr`、`us-ascii` | ✅ |
| `big5`、`big5-hkscs`、`euc-cn`、`sjis`、`windows-31j`、`iso-2022-jp`、`koi8-r` | ❌ 回落 UTF-8 → 通常 `encodingFailed` |

**已知缺口：Big5 / Big5-HKSCS。** 当前依赖树**既不能检测也不能解码** Big5 系编码
（已核实：`betto_charset_detector 0.1.0` 的候选表只有 windows-1252 / iso-8859-1/2/15 /
shift-jis / euc-jp / euc-kr / gbk；`charset 2.0.1` 未注册任何 Big5 编解码器）。
实际行为：`Content-Type` 声明 `big5` → `Charset.getByName('big5')` 返回 `null` → 按本节顺序
回退 UTF-8 → 繁体内容通常随即解码失败 → `ParseFailure(encodingFailed)`。
补齐需新增 Big5 解码依赖（走 C-DEP-1 评审 + C-DEP-7 许可核实 + ADR），或在 `core/network/`
内自带码表（体积与维护成本更高）。**状态：已知缺口，未排期；是否覆盖繁体书源由排期决定。**

**其它已知限制：** `gb18030` 按 GBK 解码，四字节扩展区字符会失败，属 M0 已知限制。

**嗅探的样本下限：** 字节嗅探只看前 8 KB；样本极短时（几个字节）可能误判为
`shift-jis` 等其他 CJK 编码，因此**不得**跳过前两步去信任嗅探结果。

---

## 6. JS 桥接白名单与配额

JS 规则运行在独立 Isolate 中，**只能**访问以下绑定（C-SRC-3）：

> **引擎已选定（ADR-0015）：** 下表绑定已在 `flutter_qjs_next 1.5.2` 上实测可行，
> 含后台 Isolate 中的回调桥。配额均真实生效：`QuickJsRuntime2(timeout: 5000)` 中断死循环、
> `memoryLimit: 32 * 1024 * 1024` 阻止超额分配；调用方仍须持有硬预算并 `Isolate.kill` 兜底。
>
> **载荷必须是合法 JSON：** 桥接层用 `jsonDecode` 解析 `sendMessage` 的第二个参数，
> 传裸字符串（如 `'ping'`）会抛 `FormatException`；必须写 `JSON.stringify(value)`。
> 详见 `tool/spike/README.md` §4。

| 绑定 | 形态 | 说明 | 分期 |
|---|---|---|---|
| `baseUrl` | `String` | 当前页 URL（原版同名变量） | M0 |
| `result` | `String?` \| `List` | 当前页 responseBody（原版同名变量） | M0 |
| `page` | `int` | 当前页码 | M0 |
| `source` | 只读对象 | 仅 `name`、`url`、`group`，其余不可见 | M0 |
| `http.get(url, options)` | `String` | 经 `core/network/HttpClient` 代理，受超时与重试策略约束 | M0 |
| `http.post(url, options)` | `String` | 同上 | M0 |
| `parse.getString(rule, doc)` | `String` | 复用规则引擎，可递归 | M0 |
| `parse.getElements(rule, doc)` | `List` | 同上 | M0 |
| `java.put(key, value)` / `java.get(key)` | `void` / `Object?` | 与原版一致：**仅 JS 内可用** | M1 |
| `java.timeFormat(timestamp)` | `String` | `yyyy/MM/dd HH:mm` | M1 |
| `log.debug/info/warn/error(msg)` | `void` | 转发到 `core/logging`，自动附加 `rulePath` | M0 |
| `crypto.md5/sha1/base64Encode/base64Decode` | `String` | 纯计算 | M0 |

**禁止暴露：** 文件系统、进程、环境变量、Socket、定时器、原生绑定、
`eval` 之外任意代码加载、`source` 的完整对象（防信息外泄）。

> **绑定形态（同步 / Promise）的裁决尚未生效：** 见 `docs/dev/adr/0029-js-bridge-shape-and-async-engine-api.md`
> （状态 **Proposed**，待裁决）。在其中被裁决生效并回写到本表之前，**「形态」列只描述语义**，
> 不得读作「这些调用在 JS 侧是同步的」这一已生效结论；`await` 要求便归该 ADR 决定。

**配额（必须实现）：**

| 项 | 默认值 |
|---|---|
| 单次 JS 墙钟超时 | 5 秒 |
| 单次 JS 内存上限 | 32 MB |
| 单条规则内 JS 调用次数 | ≤ 20 |

超时或异常 → `ParseFailure(parseFailed)`，`rulePath` 中标注 `js:timeout` 或 `js:error`。

---

## 7. 失败语义

> 本表定义的是**触发条件**；「ARB 文案键名规则」（`failure<PascalCaseKind>`）的
> 唯一出处是 `docs/dev/naming.md` §8，本表只列出具体键值。
> 「可重试」列由 `ParseFailureKind.isRetryable` 实现，改动任一侧都必须同步另一侧。

| `ParseFailureKind` | 触发条件 | ARB 文案键 | 可重试 |
|---|---|---|---|
| `networkTimeout` | 连接/读取超时 | `failureNetworkTimeout` | 是 |
| `networkFailed` | DNS/连接失败、5xx | `failureNetworkFailed` | 是 |
| `networkForbidden` | 403 | `failureNetworkForbidden` | 否 |
| `notFound` | 404 | `failureNotFound` | 否 |
| `encodingFailed` | 编码检测或解码失败 | `failureEncodingFailed` | 否 |
| `parseFailed` | 规则无匹配、JS 异常或超时 | `failureParseFailed` | 否 |
| `unsupportedRule` | 命中 M2 或未实现语法 | `failureUnsupportedRule` | 否 |
| `invalidBookSource` | 导入 JSON 缺必填字段或结构非法 | `failureInvalidBookSource` | 否 |
| `cancelled` | 用户主动取消 | 无（静默） | — |

**关键判定：**

- 「规则无匹配」与「成功但结果为空」必须区分：
  - 顶层 `bookList` / `chapterList` / `content` **无匹配** → `parseFailed`。
  - 顶层匹配成功但集合为空 → **成功**，返回空列表（搜索无结果属正常业务）。
- 失败必须携带 `rulePath`（C-SRC-8），格式 `<字段名>` 或 `<字段名>.<子字段>`，
  例如 `searchRule.bookList`、`tocRule.chapterUrl`、`contentRule.content`；
  命中未实现语法时用 `unsupported:<语法名>`，例如 `unsupported:@xpath:`。
- 失败对象**禁止**携带用户可见文案（C-ERR-7）。

---

> **2026-10-11 裁决（ADR-0026；实现与 §3.1 的 3.2 同批落地）：** 「命中未实现语法」分两类——
> **顶层规则**（`bookList` / `chapterList` / `content`）被拒仍**整次失败**；**非顶层字段**被拒时
> 该字段**置空 + warning**（含 `rulePath` 与书源 ID，C-ERR-8 / C-SRC-8），结果照常返回。
> C-SRC-4 的「禁止静默忽略」由「显式降级 + 记录」满足（§9 的健康度统计是同一模式）。
> **已随 3.2 落地（2026-10-11）：** 唯一实现点是 `PageFetchService` —— `field()`（非顶层字段）
> 把 `unsupportedRule` **与 `parseFailed`** 都降级为「置空 + warning（含 `rulePath`、失败 kind
> 与书源 ID）」，`list()` / `content()`（顶层）继续整次失败。两类同口径的理由见 ADR-0026 §决策 2
> 的复审修订注记：畸形规则若上抛，调用方只取 `dataOrNull`，会既不上报也不记录地变成 `null`。

## 8. 并发与限速

| 项 | 值 | 分期 |
|---|---|---|
| 同一书源默认并发上限 | 3 | M0 |
| `concurrentRate` 覆盖 | 按书源声明解析 | M1 |
| 章节正文批量下载 | 必须串行或有限并发，禁止对单一域名无限并发 | M0 |
| 缓存键 | `书源 ID + 规则字段 + URL + 页码` 的稳定哈希，必须带 TTL（C-NET-6） | M0 |

---

## 9. 错误恢复

| 场景 | 行为 |
|---|---|
| 单章正文失败 | 该章标记失败，不中断整本书的目录展示 |
| 目录缺页 | 按 `nextTocUrl` 翻页，最多 50 页后停止并记录 warning |
| 规则失效（0 结果） | 记录到书源健康度统计，UI 提示「规则可能已失效」 |
| 书源整站改版 | 不做自动适配；由用户更新书源 |

---

## 10. 测试基线与回归

| 项 | 要求 |
|---|---|
| 固定语料 | `test/fixtures/book_sources/*.json`（书源）+ `test/fixtures/html/*.html`（HTML 页面）+ `test/fixtures/json/*.json`（JSON 响应页）。页面**优先真实抓取**；站点已不可达或需固定会话参数时允许**按该书源的真实规则构造**，但必须在 `test/fixtures/**/README.md` 标注来源与构造依据。抓取页面仍是 §3 矩阵「已确认」与 Phase 3.7 真实回归的目标 |
| 语法单测 | §3 矩阵中每个 **M0** 语法至少 1 条单测；M1 语法在实现时同步补 |
| 前缀大小写 | `@css:`/`@CSS:`、`@json:`/`@Json:`、`@js:`/`@JS:` 各 1 条 |
| 失败单测 | §7 表中每个 `ParseFailureKind` 至少 1 条单测 |
| 链路测试 | 至少 2 个书源完成「搜索 → 详情 → 目录 → 正文」离线回放（已达成 **G2a 离线回放**：1 个 HTML 默认规则源 + 1 个 JSON 接口源；其中 JSON 源的 2 条 URL 规则按 `test/fixtures/json/README.md` 改写，因此**不**等于真实站点回放——只有真实抓取页面 / 真实链路才能把 §3 矩阵的状态列改为「已确认」，归 `PLAN.md` §3.4 的 3.7） |
| M2 拒绝测试 | `@xpath:` 与 `:` 正则规则各 1 条，断言返回 `unsupportedRule` |
| 真实书源验证 | 每个 M0/M1 语法行需在 PR 中附验证记录，并把状态列改为「已确认」 |
| 网络隔离 | 单元测试禁止真实联网；`HttpClient` 必须可注入替身（C-NET-8） |

真实书源验证记录格式（写入 PR 描述）：

```
语法：#11 &&
书源：<name> (<url host>)
链路：搜索 → 目录 → 正文
结论：已确认 / 行为差异：<描述> → 已更新矩阵
```

> **#13（`@json:` / 裸 `$.`）的当前证据（2026-10-11）：**
> 语法 `#13 @json:`；书源 示例书源（JSON 规则，真实导出结构，已脱敏，
> `test/fixtures/book_sources/legado_json_source.json`）；链路 搜索 → 详情 → 目录 → 正文
> （**离线回放**，`chain_givenJsonSourceAndCorpusPages_replaysEveryStage`）。
> **结论：离线回放已达（属 ADR-0024 的 G2a）；矩阵状态仍为「待验证」**——按 ADR-0024 §决策 2，
> 只有**真实抓取页面 / 真实链路（G2b）**才能把状态改为「已确认」，该语料的页面是按真实规则
> 构造的（唯一偏离：2 条 URL 规则因 M0 缺 #16–#19 而改写，见 `test/fixtures/json/README.md`）。
> 状态改「已确认」统一由 **3.7** 处理（与 #12 同一口径）。

---

## 11. 明确不支持（M2）

命中以下任一语法必须在导入或解析时明确拒绝并给出可读提示，不得假装成功：

- `@xpath:` XPath 规则（需要引入 XPath 依赖，须先开 ADR）
- `:` 正则规则（仅书籍列表与目录列表）
- `webJs`、`sourceRegex`、字体反爬字形映射
- 原版的登录脚本、登录 UI、登录检查 JS
- RSS / 订阅源、朗读规则
- 需要浏览器 DOM/BOM 的网页 JS、依赖 Android WebView 行为的规则
- 提取段里的嵌套规则（矩阵 #30：末段本身是一条规则，如 `class.a@css:.b`；命中报 `unsupported:nested-rule`）
