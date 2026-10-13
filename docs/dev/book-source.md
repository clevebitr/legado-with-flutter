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
| `exploreUrl` | `exploreUrl` | `String?` | **M1** | 发现页；两种形态（分类串 / 整字段 JS）、条目语义与回落规则**全部**见 §4.2（ADR-0035） |
| `ruleSearch` | `searchRule` | `SearchRule` | M0 | 必填 |
| `ruleExplore` | `exploreRule` | `ExploreRule?` | **M1** | 发现结果规则；缺失或 `bookList` 为空时**整条回落** `searchRule`（§4.2、ADR-0035） |
| `ruleBookInfo` | `bookInfoRule` | `BookInfoRule?` | M0 | 缺失时从搜索页继承 |
| `ruleToc` | `tocRule` | `TocRule` | M0 | 必填 |
| `ruleContent` | `contentRule` | `ContentRule` | M0 | 必填 |
| `concurrentRate` | `concurrentRate` | `String?` | **M1** | 并发限速；语法、毫秒单位与「速率门 → 并发门」的合成归 §8（ADR-0036） |
| `variableComment` | `variableComment` | `String?` | **M1** | 书源变量说明；**纯展示**，引擎不读（上游 `BookSource.kt:245-252` 只与校验注释拼接显示） |
| `loginUrl` / `loginUi` / `loginCheckJs` | — | — | **M2** | 登录相关，暂不实现 |
| `lastUpdateTime` / `respondTime` / `weight` / `customOrder` | 同名 | `int?` | M0 | 仅用于展示与排序 |

**子规则字段**（原版字段名 → Dart，全部 camelCase）：

| 规则对象 | 字段 | 分期 |
|---|---|---|
| `SearchRule` | `bookList`、`name`、`author`、`kind`、`wordCount`、`lastChapter`、`intro`、`coverUrl`、`bookUrl`、`updateTime` | M0（`updateTime` 为 M1） |
| `ExploreRule` | 与 `SearchRule` 的九个列表字段**同形** + `updateTime`（上游 `BookListRule` 接口，`BookListRule.kt:6-18`；无 `checkKeyWord`） | M1 |
| `BookInfoRule` | `init`、`name`、`author`、`kind`、`lastChapter`、`intro`、`coverUrl`、`tocUrl`、`wordCount`、`canReName`、`updateTime` | M0（`canReName`、`updateTime` 为 M1） |
| `TocRule` | `chapterList`、`chapterName`、`chapterUrl`、`isVip`、`updateTime`、`nextTocUrl` | M0（`updateTime` 为 M1） |
| `ContentRule` | `content`、`nextContentUrl`、`replaceRegex` | M0 |
| `ContentRule` | `webJs`、`sourceRegex`、`imageStyle` | **M2** |

模型必须使用 `freezed` + `json_serializable`（C-SRC-7）。未知字段必须**保留而非丢弃**：
在 `extra` 中承载，以便导出时不丢信息。

> **列表类规则的「同形」约束（M1-b0 裁决，ADR-0035 §决策 1）：** `SearchRule` 与 `ExploreRule` 的九个
> 列表字段由上游 `BookListRule` 接口固定，两者**必须同批**增减字段，不得只改一处；
> 上游确实存在而本仓尚未建模的字段（`SearchRule.checkKeyWord`、`BookInfoRule.downloadUrls` /
> `relatedBooks`、`TocRule.preUpdateJs` / `formatJs` / `isVolume` / `isPay`）按「保留在 `extra` +
> 去向登记」处理，清单与去向见 `PLAN.md` §3.7，不得在此处另开一份。
>
> **`updateTime` 出现在四处（上游事实）：** `SearchRule` / `ExploreRule`（列表项）、`BookInfoRule`（详情）、
> `TocRule`（章节）。本仓四处**同批建模（M1-b1）**，值都是**展示用字符串**（规则结果原文，不做日期解析；
> 章节侧可调用 `java.timeFormat`，见 §6）。**状态（M1-b1 已落地）：** 四处字段 + 承载实体
> （`Book` / `BookInfo` / `Chapter`）已入库；展示方（列表 / 详情 / 目录 UI）归 Phase 5
> （`PLAN.md` §3.7）。
>
> **`canReName` 的上游语义（2026-10-13 取证，照抄为有意行为）：** 上游只在
> `BookInfo.kt:65` 判「`canReName` 规则字段非空白」+ 调用方开关（入口自己传 `canReName`，`WebBook.kt:235-238`），
> 然后**允许覆盖已有的书名 / 作者**（`BookInfo.kt:67-84`）；**规则内容本身不求值**。
> 因此本仓 M1 只建模该字段并把「是否允许改名」交给调用方；**不得**改成「求值为真才允许」
> （那会成为与上游的差异，需先登记）。消费方（书架改名）归 Phase 5。

> **层归属与 `extra` 的落地形态**见 ADR-0021（模型位于 `domain/entities/`；`extra` 由
> `fromLegadoJson` 逐层填充）。本表只拥有字段映射与分期。

---

## 3. 规则语法支持矩阵（对标原版阅读）

> 「原版适用字段」列取自原版规则说明（原版说明中标注「仅书籍列表和目录列表」的语法
> 才限定字段，其余为**所有字段**可用）。

| # | 语法 | 原版示例 | 原版适用字段 | 分期 | 状态 |
|---|---|---|---|---|---|
| 1 | 默认规则：`类型.名称.位置` | `class.odd.0@tag.a.0@text` | 所有字段 | M0 | 已确认 |
| 2 | 类型 `class` / `id` / `tag` | `id.content@text` | 所有字段 | M0 | 已确认 |
| 3 | 类型 `text`（按文本内容匹配） | `text.最新章节` | 所有字段 | M0 | 已确认 |
| 4 | 类型 `children`（取全部子标签，忽略第二、三段） | `class.list@children` | 所有字段 | M0 | 已确认 |
| 5 | 位置：正索引与负索引（`-1` 为倒数第一） | `tag.li.-1@text` | 所有字段 | M0 | 已确认 |
| 6 | `!` 位置排除（序号用 `:` 分隔，支持负数） | `tag.li!0:1@text` | 所有字段 | M0 | 已确认 |
| 7 | 列表首字符 `-` 使结果**倒置** | `-class.odd@tag.a@href` | 所有字段 | M0 | 已确认 |
| 8 | 提取内容：`text` / `textNodes` / `ownText` / `html` / `all` / `href` / `src`（及其他 HTML 属性名） | `tag.a@href` | 所有字段 | M0 | 已确认 |
| 9 | 正则替换 `##正则##替换内容`（替换为空时可省略第二个 `##`） | `tag.p@text##全文阅读` | 所有字段 | M0 | 已确认 |
| 10 | `\|\|` 依次尝试，首个非空即成功 | `class.odd.0@tag.a.0@text\|\|tag.dd.0@tag.h1@text` | 所有字段 | M0 | 已确认 |
| 11 | `&&` **合并两侧结果（并集，非串联；仅限同种规则，不含 js 与正则）** | `class.odd.0@tag.a.0@text&&tag.dd.0@tag.h1@text` | 所有字段 | M0 | 已确认 |
| 12 | `@css:` 标准 CSS 选择器 | `@css:.book-list li@text` | 所有字段 | M0 | 已确认 |
| 13 | `@json:` JSONPath（以 `$.` 开头时可省略标志） | `@json:$.data.list[*].name` | 所有字段 | M0 | 已确认 |
| 14 | `@js:` JavaScript | `@js:result.replace(/\\s/g,'')` | 所有字段 | **M0** | 已确认 |
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
| 25 | `##match##replace###`：只取**第一个匹配**并在其内部替换（矩阵 #9 的补充语义） | `##match##replace###`（上游注释原文） | 所有字段 | **M0**（Phase 2.2 已实现） | 已确认 |
| 26 | `[]` 索引列表：`[-1, 3:-2:-10, 2]`、`[-1:0]` 可在任意位置反向（与 #5 / #6 同组） | `tag.div[-1, 3:-2:-10, 2]` | 所有字段 | **M0** → Phase 3.1 | 已确认 |
| 27 | `%%` 并行交叉合并（与 `\|\|`、`&&` 同级的选择器连接符） | — | 所有字段 | **M0** → Phase 3.2（与 #10 / #11 同族，复用同一套连接符切分） | 已确认 |
| 28 | 索引作为 `@` 分段后每段的首规则：`.1` / `[1]` / `!0` / `children[1]`，等价于 `children` + 该索引（可与 #5 / #6 / #26 的位置写法组合） | `head@.1@text`、`head@[1]@text`、`head@children[1]@text`（等价） | 所有字段 | **M0** → Phase 3.1（已实现） | 已确认 |
| 29 | `@css:` 内的 jsoup 索引伪类 `:eq(n)` / `:gt(n)` / `:lt(n)`（**兄弟索引**，0-based，**不是**结果集索引） | `@css:div#info > p:eq(3) @text` | 所有字段 | **M0** → Phase 3.2 | 已确认 |
| 30 | 提取段里的**嵌套规则**（末段本身是一条规则，如 `class.a@css:.b`） | `class.a@css:.b` | 所有字段 | **M2 / 暂不实现**（复审触发条件：真实语料统计显示使用率 > 0 且影响可用率时改判 M1） | 不支持 |
| 31 | `<js>…</js>` JS 包装（**任意位置**，可作其他规则的分隔符；与 #14 同能力、不同包装） | `tag.li<js>…</js>//a`（原版文档示例） | 所有字段 | **M2 / 暂不实现**（复审触发条件：真实语料统计显示使用率 > 0 且影响可用率时改判，与 #30 同口径；需先扩规则串的分段能力）**例外：** 整个 `exploreUrl` 字段就是一个 `<js>…</js>` 时按发现页整字段 JS 支持（§4.2、ADR-0035 §决策 6） | 不支持 |

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
>   （与矩阵 #8 的空提取同口径）；**列表逐元素展开**（上游 `AnalyzeByJSonPath.kt:83-87`：
>   `for (o in obj) result.add(o.toString())`），所以 `$.data.tags` 给 `a` / `b` 两个值；
>   对象按 **JSON 文本**返回（上游 Java 的 `Map.toString` `{a=1}` 不可复现，**已登记的
>   差异**，真实语料里没有规则依赖它）。
> - **列表规则的结果：** 命中的路径若本身是**列表**，则把它的元素当作条目列表
>   （上游 `AnalyzeByJSonPath.kt:137` 的 `read<ArrayList<Any>>`），所以 `bookList: $.info.Datas`
>   给 30 个条目而不是 1 个数组——这两点都是 3.7 的真实源回归（`tool/spot_check/README.md` §4b）
>   发现的保真缺口，已修。
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

> **#14 注记（2026-10-12，随 3.4 落地；状态列已确认于 3.7）：** 值规则上的**终段** `@js:`
> 已实现（`@js:` 贪婪吞掉本条规则剩余部分，与上游 `AppPattern.JS_PATTERN` 同形）；**列表规则**
> 上的 `@js:` 报 `unsupported:@js:list`（尚无「JS 返回一列元素」的契约）。白名单绑定、配额与四条边界
> （`js:timeout` / `js:error` / `js:parse-scope` / `js:parse-recursion` / `js:quota`）的唯一出处是
> §6。**真实源证据（3.7，2026-10-12）：** 语料 `legado_js_rules_source.json`（猫耳FM，已脱敏）
> 在活站点上跑通搜索 30 条 + 目录 34 条，两条逐项 `@js:`（`$.id@js:'…'+result` 与
> `$.sound_id@js:'…'+result`）均由脚本产出地址；记录见 `tool/spot_check/README.md` §4b。

> **#15–#19 注记（2026-10-12，随 M1 语法先行落地；状态列仍为「待验证」）。**
> 五条语法的**共同实现点**是引擎的展开步骤：上游先把 `@put:{…}` 抽掉、再把 `@get:{…}` 与
> `{{…}}` 换成它们的值，**最后**才把结果当规则读（`AnalyzeRule.SourceRule.init` /
> `makeUpRule`，`AnalyzeRule.kt:666-760`），本仓照此实现，并把结果放进 `_Expansion`。
> 逐条：
>
> - **#15 `@@`**：只认**规则体开头**（`AnalyzeRule.kt:612-615`：剥掉两个字符、模式不变），
>   所以 `{{@@class.a@text}}` 才等于「在这里跑一条默认规则」——`{{…}}` 的默认是 JS，
>   默认规则必须自报家门。中段的 `@@` 仍报 `unsupported:@@`（上游也只认开头）。
> - **#16 `@put:` / `@get:`**：`@put:{key:rule}` 的每个值都是一条规则，在**摘标志之前**逐个求值
>   并写入变量表（`AnalyzeRule.kt:641-647`）；`@get:{key}` 换成变量值，未定义时为空串。
>   带替换的规则按上游的 **Regex 模式**读：**替换后的整段文本就是这条规则的值**
>   （`AnalyzeRule.kt:674-680`，即 `“地址/{{@get:{x}}}”` 这类写法）。
>   **登记的实现差异：** 本仓按 `key:value` 形状解析 `@put` 体（值可带引号或裸写，
>   逗号 / 方括号 / 引号内的 `:` 都不切分），**不**走上游 GSON 的「严格优先 + 宽松兜底」
>   （`AnalyzeRule.kt:673-686`）；解析不出键值对的片段被忽略（上游同样保留空 putMap）。
> - **#17 `java.put` / `java.get`**：与 #16 是**同一份**变量（上游 `bindings["java"]` 就是那个
>   `AnalyzeRule`，`AnalyzeRule.kt:835`）。存储位置、快照与回程语义归 **ADR-0034**；
>   `java.timeFormat` 属 `updateTime`，仍按 §6 表的分期。
>   **登记的实现差异：** 上游 `java.get` 还有 `bookName` / `title` 两个特例
>   （`AnalyzeRule.kt:812-821`，取 Book / Chapter 的名字），Phase 5 之前本仓没有这两个实体，
>   它们按普通变量读（登记在 `PLAN.md` §3.7）。
> - **#18 `{{…}}`**：内层文本按上游 `isRule` 分流（`AnalyzeRule.kt:736-752`）：以
>   `@` / `$.` / `$[` / `//` 开头就当**规则**求值（取首个值），否则**当 JS**求值（取单个标量，
>   `null` / 无值都变空串）。在**搜索 / 发现 URL** 里只允许 JS，规则头按名报
>   `unsupportedRule`（§4）；URL 脚本的 `key` 绑定只在那里存在（ADR-0034 §决策 3）。
>   **登记的实现差异（两处）：** ① **列表规则**（`bookList` / `chapterList`）里的 `{{…}}`
>   替换后仍按**选择器**读（上游在那个分支回的是文本本身）；② 模板的 JS 返回**列表**时
>   本仓取第一个值，上游插入的是数组的 `toString()`（逗号连接）。
> - **#19 `{}`**：上游在 **JSON 模式**的规则里把每个平衡的 `{$jsonpath}` 换成它的值，
>   再把整段作为**一个值**返回（`AnalyzeByJSonPath.kt:29-48`、`:79-90`）；一条规则整好就是一个
>   模板时，那就是遗留写法 `{$.data.name}`。列表规则里只取其中的 JSONPath，字面文本不贡献元素
>   （矩阵「只能用 JSONPath」）。
>
> **展开的两处边界（已登记，均有测试）：** ① 展开深度上限（8 层）：上游的递归替换没有上限，
> 而按源变量可以装着规则文本，自引用会让一条字段永远展开下去，故以可定位的 `parseFailed` 收场；
> ② 未闭合的 `{{…}` 在规则字段里原样留下（上游的 `{{[\w\W]*?}}` 也匹配不上），但在 **URL** 里
> 是显式 `parseFailed`（§4 不允许字面 `{{…}}` 落到请求层），未闭合的 `@get:{` 也是 `parseFailed`。

**大小写处理：** 原版文档同时出现 `@css:` / `@CSS:`、`@json:` / `@Json:` 等写法。
本项目按**前缀大小写不敏感**实现，并为每种前缀补一条测试（状态：已确认）。

> **状态列的 3.7 证据（2026-10-12）：** 全部 19 条 M0 行的状态列已由真实回归改为「已确认」，
> 逐行结论（语法 / 书源 / 链路 / 结论）与四次活站点运行的输出在 `tool/spot_check/README.md` §4b；
> 用到的四类证据分别是：
> ① 基线源（默认规则 + `##` + 位置）四段跑通（§4）；
> ② 同站 **`@css:` 派生源** 16 处等价映射（行使 #12 / #29）；
> ③ 同站 **语法覆盖派生源** 9 处等价映射（行使 #3 / #4 / #6 / #7 / #10 / #25 / #26 / #27 / #28，
> 与基线得到相同的计数与正文哈希）；
> ④ `@js:` 语料源（猫耳FM）在活站点上行使 #11 / #13 / #14。
> 两个派生源的逐处映射表在 `test/fixtures/book_sources/README.md`。

> **#1 / #2 类型注记（2026-10-12，ADR-0032）：** 默认规则的**类型**是
> 「`class` / `id` / `tag` / `text` / `children`，**或一段原始 CSS**」。类型不在这五个之内时
> （`.searchresult`、`li`、`dd`、`p`、`tr!0`、`#txt`、`div.item`），该段整体作为 CSS 选择器交给
> cascadia；`!` / `[...]` 后缀仍按位置解析（`tr!0` 不是合法 CSS）。`unsupportedRule` 只留给真正
> 未实现的标志（`@xpath:` / 裸 `//` / `<js>` / `:正则` / M1 模板）。依据：G2b spot-check 实测
> **197 条 M0 源中 137 条（69.5%）** 依赖该写法（复算命令与输出见 `tool/spot_check/README.md` §3；
> ADR-0032 §背景的原始 157/270 已作废）。
>
> **`<js>` 的补录依据（2026-10-12，架构师审核 R1 + 开发组行号核对）：** 它此前只在代码里被拒绝、矩阵
> 没有行 —— 正是本节 #25–#27 补录注记要防的缺口（「引擎拒绝得对、账本却没记」），故补为 **#31**
> （追加在表尾，不插入中间）。上游证据两层，均已在 fork `HapeLee/legado-with-MD3@master` 上核到行号：
> ① `app/src/main/java/io/legado/app/constant/AppPattern.kt:5-6` 的
> `JS_PATTERN = Regex("<js>([\\w\\W]*?)</js>|@js:([\\w\\W]*)", IGNORE_CASE)` —— 一个 pattern 同时匹配
> 两种包装（即「任意位置｜可作为其他规则的分隔符」，示例 `tag.li<js></js>//a`）；
> ② `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt:157`（注释「执行 `@js`，`<js></js>`）、
> `:168`（`private fun analyzeJs()`）、`:171`（`JS_PATTERN.findAll(ruleUrl)`）—— 因此它在 **URL 规则**
> 里同样生效。核对日期：2026-10-12。

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

URL 字段的渲染统一走同一个渲染入口（同步部分仍是 `renderUrlTemplate`，C-SRC-5），禁止手写拼接；
`{{…}}` 的求值边界见本节末尾的注记。

| 变量 | 适用位置 | 含义 | 分期 |
|---|---|---|---|
| `{{key}}` | `searchUrl` | URL 编码后的搜索关键词 | M0 |
| `{{page}}` | `searchUrl`、`nextTocUrl`、`nextContentUrl` | 页码，从 1 开始 | M0 |
| `{{baseUrl}}` | 全部 | 当前页 URL（JS 中同名变量） | M0 |
| `{{}}` 内嵌规则/JS | 全部 | 默认按 JS 求值（内层是规则头时按规则求值），见矩阵 #18 | M1 |
| `{{变量名}}` | 全部 | `@put:` / `@get:` 读写的变量（见 §3 的 #16 注记） | M1 |

约定：

- 关键词**必须** URL 编码，且只编码一次、不重复编码。
- 相对 URL（以 `/` 或非协议开头）必须以当前页 URL 为基准解析为绝对 URL。
- 未定义的变量渲染为**空字符串**并记录 warning；不得保留 `{{...}}` 原文。
- 在**搜索 URL 与发现 URL** 中，`{{}}` 内只允许 JS；解析器必须拒绝在其中写非 JS 规则。

> **`{{…}}` 在 URL 里的求值边界（2026-10-12，随矩阵 #18 落地）：** 名字落在上表前三个的
> 占位符仍走**同步模板渲染**（`key` 只编码一次），其余名字交给**沙箱**当 JS 求值；
> 内层以规则头开头（`@@` / `$.` / `$[` / `//` / `@xpath:` …）在 URL 里**按名拒绝**
> （`unsupportedRule`，C-SRC-4）——搜索 / 发现 URL 只允许 JS。URL 脚本的绑定与 §6 一致，
> 额外多一个 `key`（搜索关键词；ADR-0034 §决策 3）；`result` 尚未取页面，保持不绑。
> 脚本结果里的整数不带 `.0`（上游对整数结果的格式化，`AnalyzeUrl.kt:203-207`），
> 未闭合的 `{{` 与渲染失败的 `{{…}}` 都是该字段的 `ParseFailed`（不把字面 `{{…}}` 交给请求层）。

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

> **§4.1 的分页与净化语义（2026-10-12，随 `PLAN.md` 3.5 落地）：** 上表是原版语义；
> 本仓实现到哪一步、以及与原版有意不同的地方，逐条记在这里（原来的「返回空即停止」太粗，
> 分页要落到可测的行为）：
>
> - **翻页规则里的 `{{page}}` / `{{baseUrl}}` 按 URL 模板渲染（§4 的 M0 变量）。** 规则文本整个
>   就是 URL 模板（只含 `page` / `baseUrl` 两个变量、不含 `@` 段）时，整条规则就是下一页地址；
>   否则按选择器规则求值，求出的**每个值**再按模板渲染。`{{page}}` = 该 URL 成为的页码
>   （1-based，即 `{{baseUrl}}` 那一页的页码 + 1），`{{baseUrl}}` = 读到该规则的那一页。
>   渲染后不得把字面 `{{...}}` 交给请求层（§4），渲染为空的值得丢弃；含其它名字的 `{{...}}`
>   （矩阵 #18，M1）不按模板处理，仍由引擎按未实现语法拒绝。
> - **`nextTocUrl` / `nextContentUrl` 是列表，不是单值。** 两者都按规则引擎的
>   `extractAll` 读取（上游 `getStringList`，`BookChapterList.kt:210-218`），所以一条规则
>   可以给出一个 URL 或一组 URL；只取第一个会把「页码链接写成一条 CSS」的书源静默丢页。
>   每个值都按**读到它的那一页**解析成绝对地址（C-SRC-5），当前页自身与重复值被丢弃
>   （上游过滤 `redirectUrl`）。
> - **翻页是队列且有限。** 每一页的翻页规则都入队，已读过的页不重读（上游用
>   `nextUrlList.contains` 防自指）；总页数上限与停止时的 warning 归 §9。
>   **登记一处与上游的差异：** 上游对「数组」分支只做一次**并发**抓取，且不在那些页上继续读
>   翻页规则（`BookChapterList.kt:110-118` 传 `getNextUrl = false`），而对「单值」分支接链；
>   本仓 M0 不分这两个分支，每一页都继续读它的翻页规则，靠「不重读 + §9 上限」封顶——
>   对同一组页码链接，这只多读一些站点本来就要给的页，不会漏页。并发抓取归 3.8。
> - **后续页失败在目录与正文上不同：** 目录缺页按 §9 降级（保留已读到的章节 + warning），
>   正文缺页则**整章失败**——把截断的正文当成成功就是把失败伪装成成功。
> - **`isVip` 的真值判定：** 按上游 `String?.isTrue()`（`BookChapterList.kt:261-264` 调用：
>   `if (isVip.isTrue()) bookChapter.isVip = true`；谓词 `StringExtensions.kt:75-80`，2026-10-12
>   核对）：`null` / 全空白 / 字面量 `"null"` → 非 VIP；其余值除非**逐字**匹配
>   `(?i)^(?:false|no|not|0|0.0)$`（且用 **trim 后**的值匹配）否则算 VIP——所以
>   `true` / `1` / `是` / `yes` 都是 VIP，`false` / `no` / `not` / `0` / `0.0` 不是。
>   两处需要照抄的细节：`"null"` 的比较发生在 **trim 之前**（所以 `" null "` 反而是 VIP），
>   模式里的 `.` **未转义**（`0x0` 也匹配）——改成更「正确」的写法就成为与上游的有意差异，
>   必须先登记再改。
> - **`replaceRegex` 是「独立替换段」规则**（上游「独立使用相当于 `all##正则##替换`」）：
>   在**拼接后**的整章正文上应用一次（上游 `BookContent.kt:190-193`），支持矩阵 #9 的
>   `##正则##替换` 与矩阵 #25 的 `##正则##替换###`。**有意不做的：** 上游在替换前后还会
>   按行 trim 并加全角缩进（`BookContent.kt:191-194`），那是阅读端排版，不属于解析阶段，
>   本仓的正文保持解析出来的原样（否则语料回归里已有的正文会被改形）。
>   规则体带选择器时报 `parseFailed`（规则里没有可选的 DOM）；`@js:` 净化规则在沙箱里跑
>   （`result` = 拼接后的整章正文，与上游 `analyzeRule.getString(replaceRegex, contentStr)` 同形），
>   其余未实现标志（`@xpath:` / `{{}}` …）报 `unsupportedRule`；三种都降级为「不替换」+ warning
>   （ADR-0026 §决策 2）。

### 4.2 发现页（`exploreUrl` 与 `ruleExplore`）

本节是发现页的**唯一出处**（决策理由与四条登记差异见 **ADR-0035**；字段分期归 §2）。

**分类来源（`exploreUrl`）** —— 两种形态，按前缀判定、互斥：

| 形态 | 写法 | 语义 |
|---|---|---|
| 分类串 | `玄幻::https://a.test/list/{{page}}.html&&都市::https://b.test/...` | `&&` 或换行分隔（上游正则 `(&&\|\n)+`）；条目 `标题::URL`。**空标题**或**缺少 URL** 的条目报 `unsupportedRule` 并记录，**其余条目照常** |
| 整字段 JS | `@js:…` 或 `<js>…</js>`（大小写不敏感） | `<js>` 形态**必须**以 `</js>` 收尾，否则该字段 `parseFailed`；返回值认 **JSON 数组**（元素含 `title`，可选 `url`）**或**上面的分隔串 |

- **整字段 JS 的绑定：** `baseUrl` = **书源 URL**、`source`、`java.*`（与 `@put:` / `@get:` 同一份变量表，ADR-0034，`sourceId` = 书源 URL）；**不绑 `key`**（字段里写 `key` 即 `js:error`），`page` 固定为 `1`，**无 `infoMap`**（命中即 `js:error`，不静默给 undefined）。
- **失败面：** 脚本异常或返回值不可解析 → 该字段 `parseFailed` + 日志（上游把错误做成一个 `ERROR:…` 分类展示，属登记差异）。
- **分类类型：** M1 只支持 `type` 缺省或 `url`；表单型分类（`text` / `button` / `toggle` / `select` 及 `chars` / `default` / `action` / `style`）**不在 M1**，该分类报 `unsupportedRule` 并记录（§11）。

**请求渲染：** 条目 URL 与 `searchUrl` 共用 `renderUrl`（C-SRC-5）；`{{page}}` / `{{baseUrl}}` 与「URL 内其他 `{{…}}` 只允许 JS、规则头按名报 `unsupportedRule`」的边界**归 §4 / 矩阵 #18，本节不另立**。发现页**不绑 `key`**——M1 没有「按关键词发现」入口；将来加入口时按 ADR-0034 §决策 3 扩展。

**一次请求一页：** 页号由调用方给（与 `{{page}}` 同口径），**不自动批量翻页**，因此**不占** §9 的自动队列页数上限；单页失败只影响该分类（§9）。

**结果解析（`ruleExplore`）：** `ruleExplore` 缺失或 `bookList` 为空 → **整条回落 `searchRule`**（**不是**逐字段回落），记账字段同样整条来自胜出的一方；唯一实现点是 `ExploreBooks` UseCase（ADR-0035 §决策 2）。列表字段的语义与分期见 §2。

---

## 5. 编码

- 必须使用 `betto_charset_detector` 检测（C-NET-3），检测顺序：
  HTTP `Content-Type` → HTML `<meta charset>` → 字节嗅探 → 回退 UTF-8。
  前两步是**权威声明**：只要有声明就必须用它，嗅探仅用于两者都缺失的页面。
- 检测结果必须缓存到「书源 ID + URL」维度，避免重复嗅探（**已落地：Phase 3.9**）：
  缓存的是**嗅探车道的结果**，键复用 `CacheDao` 的稳定键（`ruleField` 固定为 `charset`、`page` 固定，
  使同书源同 URL 的两个阶段共享一条；C-NET-6 的键形状不变），TTL 是
  `core/network/charset_cache.dart` 的 `defaultCharsetCacheTtl`（唯一出处）；
  **声明车道不进缓存**：`Content-Type` / `<meta>` 每次都能自己读到，而且声明永远优先于缓存标签
  （ADR-0031 的两条车道不因缓存而变）。缓存不可用（读 / 写失败）或无书源 ID 时只是一次
  **重新嗅探**，不得让请求失败（C-ERR-1）——**失败面在适配器（`CacheDaoCharsetCache`）里被吸收**，
  该端口的契约因此是 **total**（读返回 `null`、写 no-op、绝不抛）：这样 `core/network` 的请求路径
  不持有任何异常边界，C-ERR-2 的「`on Exception` 只允许在 `presentation/` 的 Notifier」边界不被触碰，
  `http_client` 也不需要认识 drift。
- **解码失败的判定按车道区分（ADR-0031，2026-10-11 生效）：**
  - **已声明车道**（HTTP `Content-Type` 的 `charset`、`<meta charset>`）：按**声明出的编码族**宽容
    解码（非法字节 → U+FFFD）并记一条 warning（含书源 ID、URL 摘要、字段路径；不得含正文 /
    Cookie / Token，C-ERR-8 / C-SEC-4）。理由：声明是权威，宽容只处理「声明正确、个别字节损坏」；
  - **嗅探车道与未知标签回退**：保持严格，解码失败仍返回 `ParseFailure(encodingFailed)`。
    理由：猜测 + 宽容会把「猜错编码」伪装成成功（乱码进正文），比响亮失败更糟（C-SRC-4）。
  - **禁止「一律 UTF-8 宽容解码」**：宽容必须仍走声明出的编码族；也不得把未知标签或嗅探结果
    兜到 UTF-8 宽容路径。宽容结果中的非法字节必须是 U+FFFD，且**不丢字节**（不得错位）。
  - 解码在每次响应上只发生一次，故**一个页面至多一条 warning**。
  - 本车道区分**不**新增 `ParseFailureKind`（§7 仍是 9 个 kind 的唯一出处）。

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
本表不因 ADR-0031（声明车道的宽容解码）而改变：宽容**不**扩大可解码的标签集，Big5 系仍然既不能
检测也不能解码；若将来发现某编码族没有宽容入口（见 ADR-0031 §背景），必须登记到本表。

> **宽容入口的实测登记（2026-10-12，G2b spot-check + ADR-0031 复审更正）：** 声明车道的宽容
> **只对上表里 `utf-8` 与 `gbk` 两个族实际可达**。两类原因必须分开记，它们不是同一件事：
>
> - **不可达（依赖行为所致）**：`shift-jis` / `euc-jp` 的**严格**解码在字节不完整时抛的是
>   `RangeError`（`Error`）而不是 `FormatException`（`charset 2.0.1`，`shift_jis.dart:26`），
>   宽容分支根本到不了，而且该异常会越过 `ParseResult` 契约逃到调用方 —— 按 ADR-0022 不得捕获
>   `Error`，故登记为待排期缺口（`PLAN.md` §3.7）；`euc-kr` 的解码器丢弃非法字节而不是失败，
>   没有可宽容的失败点。
> - **刻意排除（本仓策略）**：`us-ascii` / `utf-16` / `utf-32` 有宽容入口但**不用**——
>   声明了它们却解不开，说明**声明本身错了**，宽容只会把整页变成垃圾（ADR-0031 §决策 1 的
>   「声明是权威」前提不成立）。该策略的出处是本节，代码里只允许回链（ADR-0013 §3）。
>
> 两个现象都是**实测**，不是推断。

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
| `java.put(key, value)` / `java.get(key)` | `void` / `String` | 规则变量，与 `@put:` / `@get:` 是同一份（ADR-0034）；**仅 JS 内可用** | M1 |
| `java.timeFormat(timestamp)` | `String` | `yyyy/MM/dd HH:mm` | M1 |
| `key` | `String` | 搜索关键词，**只在 URL 规则的 JS 里**存在（ADR-0034 §决策 3） | M1 |
| `log.debug/info/warn/error(msg)` | `void` | 转发到 `core/logging`，自动附加 `rulePath` | M0 |
| `crypto.md5/sha1/base64Encode/base64Decode` | `String` | 纯计算 | M0 |

**禁止暴露：** 文件系统、进程、环境变量、Socket、定时器、原生绑定、
`eval` 之外任意代码加载、`source` 的完整对象（防信息外泄）。

> **JS 侧形态（本表是唯一出处；ADR-0029 §决策 3，2026-10-11 生效）：** 本表「形态」列描述的是**值类型**；
> 调用能否同步取值另有一层，判定标准是「该绑定是否需要在别处执行」：
>
> - **立即返回值（同步）**：`java.put` / `java.get`、`log.*`、`crypto.*`。
>   前提是它们只在运行时所在 isolate 内完成（变量存 Dart 侧、按 `sourceId` 键控，见 ADR-0030 §决策 4）；
> - **返回 Promise（规则**必须** `await`）**：`http.get` / `http.post`（唯一实现是 `core/network/HttpClient`，
>   C-NET-1）、`parse.getString` / `parse.getElements`（引擎与 scope 不在该 isolate）。
>   **同步写法不在支持面**，不得写成 `result.replace(...)` 式的同步链；仅凭 3.7 真实语料证据 + 新 ADR
>   才可追加（ADR-0029 §决策 4）。
>
> **`parse.*` 的 scope 边界（ADR-0029 §决策 5）：** 3.3 只承诺**页级 scope**（worker 侧用页面 body 重建）；
> 元素级 scope 命中时报 `unsupportedRule` / `parseFailed`，`rulePath` 用 `js:parse-scope`。
>
> **排队、超时与隔离（ADR-0030，本表不复述数值）：** 单常驻 worker、单复用运行时、FIFO 串行；
> 并发预算归请求层；跨书源共用 `globalThis` 属**已登记偏离**；触发条件与重开路径见 ADR-0030 §决策 5。

**配额（必须实现）：**

| 项 | 默认值 |
|---|---|
| 单次 JS 墙钟超时 | 5 秒 |
| 单次 JS 内存上限 | 32 MB |
| 单条规则内 JS 调用次数 | ≤ 20 |
| 单条 `log.*` 消息的字符上限 | 2 000（超出截断并附截断标记） |

超时或异常 → `ParseFailure(parseFailed)`，`rulePath` 中标注 `js:timeout` 或 `js:error`。

> - **值规则上的终段 `@js:` 已可用（2026-10-12，3.4 part 2）。** `@js:` 贪婪吞掉本条规则剩余
>   部分（上游 `AppPattern.JS_PATTERN` 的 `@js:([\w\W]*)`），所以 JS 里的 `&&` / `||` 不会被读成
>   连接符；`result` 的形态按上游：`getString` 语义（单值字段）给**字符串**，`getStringList`
>   语义（多值字段，如 `nextTocUrl`）给**列表**，列表返回值也保持列表（§4.1 的 URL 数组靠它）；
>   `##` 替换在脚本**之后**应用（上游同一 `SourceRule` 的 `replaceRegex` 也是最后跑）。
> - **未落的边界（显式报错，不静默）：** 列表规则（`bookList` / `chapterList`）上的 `@js:` 报
>   `unsupported:@js:list`（它要的是「JS 返回一列元素」的契约——上游 `getElements` 的
>   `Mode.Js` 分支，`AnalyzeRule.kt:439`——尚未成型）；`<js>…</js>` 仍按矩阵 #31 拒（M2；
>   `exploreUrl` 整字段那一个例外见矩阵 #31 的注记与 §4.2）。
> - **独立 `@js:` 的 `result`：** 整页 scope 给 responseBody；**元素 scope**（逐项字段，如
>   `searchRule.name`）给它自己的 `outerHtml`——沙箱里没有 DOM 句柄可交（ADR-0029 §决策 5），
>   但规则总得看见它所属的那一项；JSON 条目 scope 给该条目的 JSON 文本。
>
> **JS 绑定的操作面（2026-10-12，3.4 落地；上表是白名单，本段是每一项的行为）：**
>
> - **`http.get(url, options)` / `http.post(url, options)` 是 Promise**（ADR-0029 §决策 3），
>   唯一实现是 `core/network/HttpClient`（C-NET-1），因此超时 / 重试 / 编码 / 明文策略与页面
>   抓取完全同一套。请求带上书源自带的 `header`（C-NET-4，规则自己的同名键优先），并以**书源
>   URL** 作为并发预算键，所以它花的仍是 §8 那份预算。
> - **`options` 只认 `headers` 与（POST 的）`body`**，其余键（如 `charset` / `timeout` / `retry` /
>   `webView`）让**该次调用抛错**：策略由 `HttpPolicy` 拥有，而 `webView` 本仓没有，悄悄忽略
>   它会把「未渲染的页面」当成答案（§1 的不兼容清单）。
> - **传输失败只拒绝这次的 Promise**（message 是 `ParseFailureKind` 名，如 `networkTimeout`）：
>   规则可以自己 `catch` 后改走镜像；规则没 catch 时该 job 按 §7 报 `js:error`。
>   **已登记的取舍：** 可重试性（`isRetryable`）不随它上抛——脚本可能吞掉它，把「传输失败」
>   归给字段就是猜，唯一出处仍是 §7。
> - **`parse.getString(rule, doc)` / `parse.getElements(rule, doc)` 是 Promise**，由**规则引擎**
>   求值（ADR-0029 §决策 5 的页级 scope）：嵌套规则在宿主 isolate 上跑，worker 不需要重建 scope。
>   `getString` = 首个值（无匹配时 `''`，与上游 `getString` 同形）；`getElements` = 每个匹配
>   ——DOM 匹配给 `outerHtml`、JSON 匹配给值本身（**无 DOM 句柄**，所以上游「`getElements` 再
>   `parse.getString(rule, element)`」的写法会在 `doc` 这一步被拒，见下）。
> - **`parse.*` 的边界都报 `unsupportedRule` 且带字段路径：** `js:parse-scope` = `doc` 不是本 job
>   的页 body（元素 scope / JSON 条目 / 脚本自己拼的片段，只有页级 scope 被承诺）；
>   `js:parse-recursion` = 嵌套规则自己又要 `@js:`（单 worker 正在跑发起它的那个 job，
>   ADR-0030 §决策 1/3，嵌套 evaluate 只会排在自己的队后面）；而 `parse.getElements` 的嵌套
>   `@js:` 落在列表规则的柜口上，报 `unsupported:@js:list`（与顶层列表规则同口径）。三者都是
>   **整个 job 的失败**，不被脚本吞成空值。
> - **额度**（上表 20 次/规则）由**桥**按 job 计数，已含 `log.*`：数的是**跨出 worker 的调用**
>   （`log.*` / `http.*` / `parse.*`）；`crypto.*` 与 `java.*` 在 worker 内完成，不进这个计数。超限使该 job
>   失败，`rulePath` 标 `js:quota`，并且之后的调用只被拒绝（不再花钱）。
> - **`java.put(key, value)` / `java.get(key)` 与 `@put:` / `@get:` 是同一份变量表（ADR-0034，矩阵 #16/#17）：**
>   表在**宿主 isolate** 里按**书源 URL** 键控；每个 job 带一份该源的**快照**进 worker，`java.*` 在 worker 内
>   **同步**读写这份快照，job 结束时整份表随结果回到宿主、由桥 merge 回去——所以「表不在 worker 里」
>   与「`java.*` 是同步」同时成立。`java.put(key, null)` 是**清掉**该变量（不是写成空串）；
>   没写过的键 `java.get` 给空串（上游 `AnalyzeRule.get` 同形），`java.put` 不给返回值
>   （上游返回写入的值，属已登记差异）。变量的**生命周期**随 Provider 作用域、不落盘：
>   上游持久化在 book / source 上（`BaseSource.kt:283-295`），本仓在 Phase 5 之前没有 Book 实体，
>   故登记为有意差异（ADR-0034 §决策 2）。
> - **`key` 只绑在 URL 规则的 job 上**（ADR-0034 §决策 3）：其余 job 送 `null`，前奏删掉该全局名，
>   所以字段规则里写 `{{key}}` 是 `js:error`，不会静默拿到空串。
> - **`java.timeFormat(timestamp)` 的入参、格式与时区（2026-10-13 取证，上表只记形态与 pattern）：**
>   入参是**毫秒时间戳**（JS `number` 或可转成数字的字符串，无法转换即 `js:error`）；输出固定
>   `yyyy/MM/dd HH:mm`、**设备本地时区**、不补零以外的任何本地化（上游
>   `JsExtensions.kt:678` + `AppConst.kt:40` 的 `FastDateFormat.getInstance("yyyy/MM/dd HH:mm")`，
>   `FastDateFormat` 默认取 JVM 默认时区）。同为 worker 内同步、**不计**本表的调用额度。
>   **状态（M1-b1 已落地）：** 实现是 `core/js/js_bindings.dart` 的 `formatJsTimestamp` +
>   纯格式化 `formatTimestamp`；设备侧由 `integration_test/js_bridge_test.dart` 的两条探针盯住
>   （Windows 已实测，Android 那次跑受构建环境网络阻塞，登记在 `PLAN.md` §3.7）。
>   **两个入参边界（实现可见，归本表）：** ① 小数按**向零截断**（等价于上一次 Java `(long)`
>   对 JS 数字的转换；毫秒时间戳本不该带小数，所以这个选择不会遮蔽错误值）；
>   ② 超出 Dart `DateTime` 精度范围的入参（`|ms| > 8.64e15`，即 ±1 亿天）**在转换前就判失败**
>   —— `DateTime.fromMillisecondsSinceEpoch` 对超范围值报 `RangeError`（属 `Error`，
>   ADR-0022 / C-ERR-2 不允许本层捕获），所以只能提前挡；结果是该次调用失败（`ok:false` →
>   `js:error`），不是崩溃也不是钳位。
>   `timeFormatUTC(time, format, sh)`（同族，带时区偏移与自定义 pattern）**不在 M1**，
>   登记去向见 `PLAN.md` §3.7。
> - **致命与可吞的区别：** `http.*` 的传输失败只拒绝那次调用；`parse.*` 的边界与额度是**判决**
>   ——判决先记下、等脚本停下来的那条结果回来时才交给调用方（脚本还在跑时不能把 worker 交给下一个
>   job：同一运行时上跑两份求值会共享 `globalThis` 与作业队列），硬预算仍是「脚本永远不停」的兜底。
>
> **3.3 落地状态与两处边界（2026-10-12，随 `PLAN.md` 3.3 落地）：**
>
> - **本阶段落了什么：** 常驻 worker isolate + 单复用运行时的桥（`core/js/`）：引擎级 5 秒中断与
>   32MB 堆上限由构造参数传入；同步绑定 `log.*`（转发到 `core/logging`，自动附字段路径）与
>   `crypto.md5` / `sha1` / `base64Encode` / `base64Decode` 已可用。单 worker + FIFO 排队，
>   超限**等待**而不报 busy（ADR-0030 §决策 1/3）；引擎中断失效时由硬预算 `Isolate.kill` 兜底，
>   并在下一个 job 重建 worker。
> - **`rulePath` 的标注形态：** 失败把标注**附在字段路径后**——`<字段路径>:js:timeout` /
>   `:js:error`（例 `searchRule.name:js:timeout`），这样 C-SRC-8 的「可定位」与本表的「标注」
>   两个要求同时成立。**例外：** 取消（桥 / 作用域已释放，或调用方主动取消）只带**裸字段路径**、
>   不带标记——取消不是脚本错误，触发条件归 §7。
> - **沙箱的禁令是按 §6 执行且可实测的（2026-10-12，3.3 复核 F1）：** 运行时以「什么都不装」
>   构造（`JsWebApis.none()`：无 `console`、无定时器，plain ECMAScript），并且**每个 job 前
>   重跑一次沙箱预备**——删掉 §6 禁止的名字（`setTimeout` / `setInterval` / `clearTimeout` /
>   `clearInterval` / `queueMicrotask` / `console` / `atob` / `btoa` / `structuredClone` /
>   `performance` / `require` / `process` / `XMLHttpRequest` / `fetch` 等）并重装白名单绑定。
>   重跑是必要的：`Object.freeze(crypto)` 冻的是对象、不是 `globalThis` 上的属性名，规则写
>   `globalThis.crypto = …` 会把篡改留给**下一个 job（可能是另一个书源）**。集成探针逐名断言
>   这些名字是 `undefined`，验证重绑后下一个 job 仍能拿到真绑定，并确认硬化沙箱没有打掉引擎
>   自己的 Promise 作业队列（3.4 的 Promise 绑定靠它）。
> - **`log.*` 的宿主侧上界（3.3 复核 F2）：** 单条消息截断到上表的 2 000 字符并留可见标记，
>   所以 `log.debug(result)` 不会把 200KB 正文写进日志；本条数**计入**「单条规则内 JS 调用次数」
>   额度（已随 3.4 的额度实现落地，见上）。
> - ~~**未落的部分归 3.4：** Promise 形态的 `http.*` / `parse.*`、`parse.*` 的页级 scope 边界
>   （`js:parse-scope`）与「单条规则内 JS 调用次数 ≤ 20」（含 `log.*` 计数）~~ → ✅ **均已落地
>   （3.4，见上）**。
> - **`log.*` 的 C-SEC-4 边界：** 转发的是**规则作者自己写的**文本，只经 `AppLogger` 的
>   `redactMessage`（能掩 URL / 凭据，**认不出正文**）。上界挡住体量，但「不得把页面正文交给
>   `log.*`」仍是书源作者的义务，宿主侧无法代为净化。

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
| `parseFailed` | 规则无匹配、JS 异常或超时、规则模板无法展开（未闭合的 `{{…}}` / `@get:{…}`、展开深度超限） | `failureParseFailed` | 否 |
| `unsupportedRule` | 命中 M2 或未实现语法 | `failureUnsupportedRule` | 否 |
| `invalidBookSource` | 导入 JSON 缺必填字段或结构非法 | `failureInvalidBookSource` | 否 |
| `cancelled` | 用户主动取消，或**桥 / 作用域已释放**（job 被丢弃而未运行；`rulePath` 只带裸字段路径，§6） | 无（静默） | — |

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
| `concurrentRate` 覆盖 | `n/m` = 每 `m` **毫秒**内最多 `n` 次；单个整数 `x` = 每 `x` 毫秒 1 次；`"0"` / 空 = 不限；非法（非整数、`n <= 0`、`m <= 0`、`x <= 0`）→ 忽略该声明 + 一条 warning（回退默认并发）。与上行的「同一书源默认并发上限」**两门同时生效**，超限排队 | M1 |
| 章节正文批量下载 | 必须串行或有限并发，禁止对单一域名无限并发 | M0 |
| 缓存键 | `书源 ID + 规则字段 + URL + 页码` 的稳定哈希，必须带 TTL（C-NET-6） | M0 |

> **实现点与排队语义（2026-10-12，随 `PLAN.md` 3.8 落地）：** 预算在**请求层唯一实现**——
> `DioHttpClient` 每次真正上线的请求都经 `RequestLimiter`，键 = `sourceId`（书源 URL），无书源
> 上下文时回退到 URL 主机，因此「章节正文批量下载」（Phase 5）只要走 `HttpClient` 就自动受限；
> 章节正文的分页本身是**串行**的（`FetchContent` 逐页取）。超限的调用**排队等待**而不失败
> （C-SRC-9 要求可并发调用，「busy」不是可接受的答复），按调用顺序（FIFO）接班；调用抛异常也
> 会释放槽位。`JsBridge` 契约**不含**容量参数（ADR-0030 §决策 2）；`concurrentRate`（M1）
> 将把书源自己的声明读进同一预算。
>
> **两处边界（2026-10-12 架构师审查登记）：**
>
> - **同一个主机可能有两份预算。** 带书源上下文的调用按 `sourceId` 分桶，无书源上下文时按 URL
>   主机分桶，两者互不影响（今天所有页面抓取都带 `sourceId`，主机桶只服务将来的无上下文调用）。
> - **JS 桥的 `http.*`（3.4）与页面抓取共用同一书源预算。** 实现时**不得**在已经持有该预算
>   槽位的调用内部再发起同一书源的请求，否则预算会被自身耗尽而永久排队（预算只有 3 个）。
>   —— **已落地（3.4）：** 规则里的 `http.*` 由桥转发到同一个 `HttpClient` 实例，预算键就是
>   规则 job 的 `source.url`（同 §6）；上面的禁忌针对的是「持有槽位时再嵌套发起」，与桥无关
>   （页面抓取的槽位在规则求值之前已释放）。
>
> **`concurrentRate` 的语法与合成规则（2026-10-13，M1-b0 裁决，理由与备选见 ADR-0036）：**
> **语法与毫秒单位以上表为唯一出处**；上游依据是 `ConcurrentRateLimiter.kt:17-46`（`n/m` 解析）、
> `:52-70`（`0` / 空 = 不限）、`:86`（原文注释「次数/毫秒」）、`:88-108`（超限 `delay` 重试），
> 应用点是所有出网请求（`HttpHelper.kt:164` / `AnalyzeUrl.kt:121` / `JsExtensions.kt:512/538/569`）。
> 本仓的合成规则：
>
> - **两门互不替代**：请求要**同时**通过速率门（`n/m` 滑窗）与并发门（默认 3）；量纲不同，不得用
>   「取更严格的一条」这种没有定义的说法代替。
> - **顺序固定为先取速率许可、再占并发槽位**：反过来会让等待中的请求白占并发槽位，
>   3 个槽位被等待者占满即整源停摆。
> - **超限排队、不报 busy**（C-SRC-9）；异常也释放槽位（与上文的并发门同一实现）。
> - **速率门与并发门共用同一个实现点**（`DioHttpClient` 的 `RequestLimiter`，速率状态与并发槽位同键；
>   该实现点归上文，本节不另立）：脚本的 `http.*` 与页面抓取自动共用同一份限速，**不得**为速率
>   另开第二个实现点，也不得把速率参数提到 `HttpPolicy` / `JsBridge` 契约里（ADR-0030 §决策 2 的口径不变）。
> - **默认不限速**：只有书源声明了 `concurrentRate` 才启用速率门；`HttpPolicy` 不新增默认速率字段。
> - **触发条件：** 真实语料若证明作者把 `n/m` 当「次数/秒」，按 ADR-0036 §决策 8 出新 ADR，
>   不得就地改单位；M1-b2 的验收包含「语料里 `concurrentRate` 取值分布 + 单位判断记录」。

---

## 9. 错误恢复

| 场景 | 行为 |
|---|---|
| 单章正文失败 | 该章标记失败，不中断整本书的目录展示 |
| 目录缺页 | 按 `nextTocUrl` 翻页，最多 50 页后停止并记录 warning（正文分页共用同一上限，见 §4.1） |
| 发现页单页失败 | 只影响该分类：该分类报错 + 记录，其余分类与其余页面照常（发现页不进自动翻页队列，§4.2） |
| 章节正文分页失败 | 该章**整次失败**，不返回被截断的正文（§4.1） |
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

> **G2b 验证入口与记录（2026-10-12 落地）：** `tool/spot_check/` —— 驱动生产链路的可复现 harness
> 与实测记录（站点、命令、四段结果、派生 `@css:` 等价验证）。它**不进 CI**，与 `tool/spike/` 同一模式。

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
- `<js>…</js>` JS 包装（矩阵 #31：任意位置、可作分隔符；命中报 `unsupported:<js>`）
  —— **唯一例外：** 整个 `exploreUrl` 字段就是一个 `<js>…</js>` 时，按发现页整字段 JS 支持
  （§4.2、ADR-0035 §决策 6）；它在规则体内的分隔符用法仍属 M2。
- 发现页的**表单型分类**（`type` 为 `text` / `button` / `toggle` / `select`，以及 `chars` / `default` /
  `action` / `style`）：M1 只支持 `type` 缺省或 `url`；命中报 `unsupportedRule` 并记录，
  其余分类照常（§4.2）。
- 发现页整字段 JS 的 `infoMap` 绑定、分类参数传递（`args` / 临时变量）与排名模块
  （`executeForRanking` 一套）：均不在 M1；`infoMap` 命中即 `js:error`（§4.2）。
- `java.timeFormatUTC(time, format, sh)`（带时区偏移与自定义 pattern）：不在 M1；
  `java.timeFormat` 的语义见 §6。
