# ADR-0035 发现页：`exploreUrl` 的两种形态与 `ruleExplore` → `ruleSearch` 的整条回落

- **状态：** Accepted（2026-10-13 架构师裁决；`PLAN.md` §3.5 的 M1-b0 规格前置，开发组不得自行假设）
- **日期：** 2026-10-13
- **关联：** ADR-0024（状态列判据）、ADR-0026（降级只有一个实现点）、ADR-0027（事实级唯一归属）、
  ADR-0029 / ADR-0034（URL 规则与规则变量）、C-SRC-4 / C-SRC-5 / C-SRC-8、
  `docs/dev/book-source.md` §2 / §4.2 / §9 / §10 / §11、`PLAN.md` §3.5 / §3.7

## 背景

`PLAN.md` §3.5 的 M1 要落 `exploreUrl` 发现页，矩阵 #18 只定了「发现 URL 内只允许 JS」这一条，
仓内此前对 `exploreUrl` 的**格式、条目语义、回落规则与绑定**没有可判定的规定。开发组按
`AGENTS.md` §2 不得自行假设，故先由架构师取证并裁决。

上游取证（fork `HapeLee/legado-with-MD3@master`，本地 clone `F:/Projetcs/legado-fork`）：

| 事实 | 出处 |
|---|---|
| 整字段两种形态：`<js>` / `@js:` 前缀（大小写不敏感）走 JS；否则是「`&&` 或换行」分隔的分类串，条目按 `::` 拆成 `(标题, URL?)` | `app/src/main/java/io/legado/app/help/source/BookSourceExtensions.kt:52-104`（`exploreKinds()`），分隔正则 `(&&|\n)+` 在 `:90` |
| `<js>` 形态取 `substring(4, lastIndexOf("<"))`，即要求以 `</js>` 收尾；`@js:` 形态取 `substring(4)` | 同上 `:66-78` |
| 脚本返回**JSON 数组**时按 `ExploreKind` 反序列化，否则按分隔串解析（两种返回值都吃） | 同上 `:82-92` |
| 解析/执行失败时上游**造一个 `title = "ERROR:…"` 的分类**，页面照常打开 | 同上 `:95-98` |
| 分类对象除 `title` / `url` 外还有 `type`（`url` / `text` / `button` / `toggle` / `select`）、`action`、`chars`、`default`、`style` —— 表单型分类 | `app/src/main/java/io/legado/app/data/entities/rule/ExploreKind.kt` |
| 书列表规则：`isSearch` → `searchRule`；否则 **`ruleExplore.bookList` 为空 → 整条回落 `searchRule`**；否则用 `ruleExplore`（**不是逐字段回落**） | `app/src/main/java/io/legado/app/model/webBook/BookList.kt:83-87`，字段读取在 `:107-113` |
| 条目 URL 缺失时的上游取值链：`moduleUrl ?: (key != null ? searchUrl : null) ?: exploreUrl`（把整段 DSL 当 URL 传下去） | `app/src/main/java/io/legado/app/domain/usecase/ExploreBooksUseCase.kt:64-72` |
| 两个规则对象的形状由同一个接口固定：`ExploreRule` = `SearchRule` 去掉 `checkKeyWord`（`bookList`/`name`/`author`/`intro`/`kind`/`lastChapter`/`updateTime`/`bookUrl`/`coverUrl`/`wordCount`） | `.../entities/rule/BookListRule.kt:6-18`、`ExploreRule.kt`、`SearchRule.kt:12-24` |
| 整字段 JS 的绑定（`BaseSource.evalJS`）：`java`（书源自身）/ `source` / `baseUrl` = **`getKey()`（书源 URL）** / `cookie` / `cache`，外加 `infoMap`；**没有 `page` / `key` / `result`** | `app/src/main/java/io/legado/app/data/entities/BaseSource.kt:333-350`，`infoMap` 由 `exploreKinds()` 注入（`BookSourceExtensions.kt:73-77`） |
| 分类页请求的绑定（`AnalyzeUrl.evalJS`）：有 `page` / `key` / `result` / `infoMap` / `book` … | `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt:363-380` |

## 决策

1. **模型新增 `ExploreRule`（`ruleExplore`），与 `SearchRule` 同形 + `updateTime`。**
   `BookSource.exploreRule` 为 `ExploreRule?`；`extra` 逐对象保留（ADR-0021）。
   **同形约束写进 `book-source.md` §2 的注记：** 两类的九个列表字段由上游 `BookListRule` 接口固定，
   将来给列表规则加字段必须**两处同批**，不得只改一处。
   *否决「`exploreRule` 也存成 `SearchRule`」：上游本就是两个类型，且将来给搜索侧补
   `checkKeyWord` 一类字段会把发现侧一起污染。*
2. **回落是「整条」而不是「逐字段」：`ruleExplore` 缺失或 `bookList` 为空 → 用整条 `searchRule`。**
   依据 `BookList.kt:83-87`；记账字段同样整条来自胜出的一方（`:107-113`）。
   **唯一实现点：`ExploreBooks` UseCase**（与 ADR-0026「降级只有一个实现点」同精神）。
3. **`exploreUrl` 认两种形态，且互斥（按前缀判定）：**
   - **分类串**：`&&` 或换行分隔；条目 `标题::URL`。空标题 → **该条目**报 `unsupportedRule` 并记录，
     其余条目照常（C-SRC-4：不静默丢弃）。
   - **整字段 JS**：`@js:` 或 `<js>…</js>`（大小写不敏感）。`<js>` 形态**必须**以 `</js>` 收尾，
     否则该字段报 `parseFailed`（**登记差异 ①**：上游用 `lastIndexOf("<")` 截断，允许尾巴上有垃圾）。
   - URL 缺失的条目：**拒绝该条目**（`unsupportedRule` + 记录），**不**照抄上游
     「把整段 `exploreUrl` 当 URL 传下去」（**登记差异 ②**：那是上游的实现副作用，不是可依赖的语义）。
     `PLAN.md` §3.7 登记「若真实语料证明存在依赖该副作用的书源，再单独裁决」。
4. **整字段 JS 的绑定与返回值（本仓口径）：**
   - 经 `JsBridge` 执行，绑定 `baseUrl` = **书源 URL**、`source`、`java.*`（与 `@put:` / `@get:` 同一份变量表，
     `sourceId` = 书源 URL，ADR-0034）；**不绑 `key`**（前奏删全局名，`key` 显式 `js:error`）。
   - `page` 绑 **1**（本仓 `JsJob.page` 为必填；上游不绑）—— **登记差异 ③**。
   - **`infoMap` 不在 M1**（宿主侧持久信息表，需要新绑定与新存储）：命中即 `js:error` 显式失败，
     不静默给 undefined（登记 `PLAN.md` §3.7）。
   - 返回值：JSON 数组（元素至少含 `title`，可选 `url`）**或**分隔串，两种都认（对齐上游 `:82-92`）。
   - 脚本异常 / 返回值不可解析 → 该字段报 **`parseFailed`**（**登记差异 ④**：上游造一个 `ERROR:` 分类把错误
     展示成内容；本仓按 C-SRC-4 显式失败 + 日志，错误不进 UI 列表）。
   - `type != "url"` 的元素（表单型分类）→ **不在 M1**：该元素按 `unsupportedRule` 拒绝并记录
     （决策 6）。
5. **发现页请求与搜索 URL 共用同一渲染入口**（C-SRC-5）：`{{page}}` / `{{baseUrl}}` 走模板语义，
   URL 内的其它 `{{…}}` 只允许 JS、规则头按名拒绝（矩阵 #18 + §4 的 URL 边界，ADR-0034 §决策 3）。
   `key` 不绑（M1 没有「按关键词发现」入口；将来加入口时按 ADR-0034 §决策 3 扩展）。
   **一次请求只取一页**，页号由调用方给；**不做自动批量翻页**，因此**不新增页数上限**
   （§9 的 50 页上限只管目录 / 正文的自动队列）。
6. **明确的范围边界：**
   - `type` 非 `url` 的表单型分类（`text` / `button` / `toggle` / `select` 及 `chars` / `default` /
     `action` / `style`）、参数传递（`args` / 临时变量）、排名模块（`executeForRanking`、
     `MAX_RANKING_BOOKS` / `MAX_RANKING_PAGES`）、`infoMap` —— **都不在 M1**，登记 `PLAN.md` §3.7。
   - `<js>…</js>` **作为规则体内的分隔符**仍按矩阵 #31 拒绝（M2）。本 ADR 只开放
     「**整个 `exploreUrl` 字段**就是一个 `<js>…</js>`」这一种形态；`book-source.md` §11 与
     矩阵 #31 的注记必须写清这个例外边界，避免「已支持 `<js>`」的误读。

## 后果

- 新增 `ExploreRule` 实体 + `ExploreBooks` UseCase + 分类 UI；`Book` / `BookInfo` / `Chapter` 是否需要
  `updateTime` 归 M1-b1 的模型改动（列表侧 `updateTime` 与 §2 的 `TocRule.updateTime` 是两处）。
- `book-source.md`：§2（`exploreUrl` 行 + `ruleExplore` 行 + 同形约束注记）、新增 §4.2（发现页）、
  §9（发现页不在自动翻页队列里）、§11（`<js>` 的例外边界）。
- `PLAN.md` §3.5 把 M1-b4 拆成「引擎 / UseCase」与「分类 UI」两个 PR，并把本条的四条差异写进验收。
- 矩阵 #18 的状态列仍只能由**真实书源回归**改「已确认」（ADR-0024 §决策 2）；回归记录按 §10 格式写入 PR。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| `exploreRule` 复用 `SearchRule` 类型 | 抹掉「哪一份规则被用」的名字；上游本就是两个类型；将来给搜索侧加字段会污染发现侧 |
| 逐字段回落（`ruleExplore.name` 空就取 `ruleSearch.name`） | 与上游 `BookList.kt:83-87` 不符；同一页混用两套字段规则会让「列表计数为什么对不上」无从解释 |
| 只支持 `@js:`，`<js>` 留 M2 | 真实源里 `<js>` 形态常见，等于用一个拼写拒绝一整类书源；代价只是一个后缀判断 |
| 照抄上游「URL 缺失就把整段 `exploreUrl` 当 URL」 | 那是实现副作用（`?: source.exploreUrl`），照抄会把解析错误变成一次无意义的请求 |
| M1 一并做表单型分类 + `infoMap` + 排名模块 | 需要新绑定（`infoMap` 是宿主侧持久信息表）+ 一套表单 UI 与参数传递链，与 M1「模型与语法先行」的口径不符；先登记 |
