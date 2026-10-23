# ADR-0046 聚合搜索：范围编码、类型筛选、匹配模式（分桶排序）、合并去重与分页

- **状态：** Accepted（2026-10-21，M11 规格前置；范围由 `DECISIONS.md` #6 的用户裁决给定）
- **日期：** 2026-10-21
- **关联：** C-ARCH-2、C-NET-6、C-NET-9、C-UI-5、C-UI-7、ADR-0036、ADR-0043、ADR-0045、
  `docs/dev/roadmap.md` §3.8、`docs/dev/architecture.md` §1 / §6

## 背景

`docs/dev/roadmap.md` §3.8（`DECISIONS.md` #6）把 M11 定为：聚合搜索（范围 / 类型 / 匹配模式 / 并发 /
暂停 / 合并去重 / 分页）+ 校验与调试按「分组 + 类型」选源。上游实现是
`domain/usecase/SearchBooksUseCase.kt`（`BookSearchRequest` / `SearchRunEvent` / `BookSearchControl` /
`SearchResultMerger` / `supportsSearchPage`）、`domain/model/BookSearchScope.kt` 与 `ui/book/search/SearchScope.kt`。

本仓今天只有「搜索**当前选中的一条源**」（`SearchResultsNotifier` + `SearchBooks`），没有范围、类型、匹配模式、
并发与合并。要在不推翻它的前提下加聚合，需要先把下面七件事定死。

## 决策

### 决策 1 范围是三态，编码进 `shared_preferences` 的 JSON

- `BookSearchScope` = `all` / `groups(Set<String>)` / `sources(List<ScopeSource>)`（`ScopeSource` 收
  **展示名 + URL** 两个原语，因为源可能被删）。
- 持久化形态（与上游 `BookSearchScope.encode*` 同形）：`{"type":"group","groups":[…]}` 与
  `{"type":"source","sources":[{"name":…,"url":…}]}`，缺省（空串 / 缺失）= `all`。
- **回落**（上游 `SearchScope.getBookSourceParts` 的等价物，本仓写在解析层，不写在存储层）：
  - `groups` 里已经不存在的分组被丢弃；丢完为空 → 回落 `all`；
  - `sources` 里已经被删的 URL 被丢弃；丢完为空 → 回落 `all`；
  - `all` = 所有 **`enabled`** 的行（禁用源永远不参与搜索，这与 5.5 的「启用优先」是两件事）。
- 范围只决定**候选源**；它不隐含类型或匹配模式。
- **2026-10-22 修订注记（ADR-0058 §决策 2）：** 回落的判据收紧为「范围本身已经不存在」
  （名字一条也对不上），不再把「范围还在、只是里面没有能搜的源」静默扩成全库；回落发生时
  必须在搜索页上写出来（`AggregateSearchState.scopeFellBack`）。

### 决策 2 类型筛选默认「文本」，且**类型是过滤而不是排序**

- `BookSourceType`（0 文本 / 1 音频 / 2 图片 / 3 文件）作为 `Set<BookSourceType>` 收在请求里。
- **默认 = `{text}`**：本仓只有文本链路可读（阅读器读正文），把音频 / 图片 / 文件源默认拉进搜索结果只会产生
  点开就失败的条目。用户可以在搜索页把类型放宽。
- 上游的 `types: Set<Int>?`（`null` = 不限）与本仓的「默认文本」是**有意的差异**：上游有音频与图片播放器，
  本仓没有，默认全选即等于制造死链（登记在 `book-source.md` / roadmap 的差异注记里）。

### 决策 3 匹配模式 = **分桶排序**，不是过滤（照抄上游语义）

- `SearchMatchMode { defaultMode, exact }`，两个值就是上游的 `DEFAULT` / `EXACT`。
- 每本书按「关键词 vs 书名 / 作者 / 分类」被分进四个桶，**桶间优先级固定**：

  | 桶 | 判据（忽略大小写） | `defaultMode` | `exact` |
  |---|---|---|---|
  | `equal` | 书名 **或** 作者 **等于** 关键词 | ✅ | ✅ |
  | `tags` | `kind` **包含** 关键词 | ✅ | ❌ |
  | `contains` | 书名 **或** 作者 **包含** 关键词（非等于） | ✅ | ❌ |
  | `other` | 其余 | ✅ | ❌ |

- **`exact` 不是「只保留精确等于」而是「只保留 `equal`」**：上游 `classifyBucket` 对 `tags` / `contains` /
  `other` 在 `EXACT` 下返回 `null`（丢弃）。这条容易被误读，所以写成表。
- **大小写归一化用 `toLowerCase()`**（上游 `ignoreCase = true` 的 Dart 等价物）。**不做**全角/半角、繁简、
  拼音归一化：那需要一个 collation 依赖（C-DEP-1），而且会把「用户搜什么就匹配什么」变成隐式规则。
- 桶内排序：**`origins.size` 降序**（多源命中的书更可靠）；`other` 桶保持插入序（上游 `getSortedList` 就是
  这么写的，不「顺手改好」）。

### 决策 4 去重键是 `(name, author)`，URL 只做去重索引

- 同一本书在不同源里 `bookUrl` 不同、`(name, author)` 相同 → **合并成一条**，`origins` 里记下每个来源的 URL；
  这就是「来自 N 个源」标记的来源。
- 同一个 `bookUrl` 出现两次（同一源被选两次、或一次搜索结果里重复）→ 用 `bookUrlIndex` 跳过。
- 键是 `(name, author)` 而不是 URL：跨源找同一本书正是聚合搜索的目的（上游 `SearchBookKey` 同此）。
- `origins` 是 `List<String>`（源 URL），**保持插入序并去重**。

### 决策 5 并发 = 用户预算，单源 60 s，失败不拖垮整批

- 并发数 = `concurrencySettingProvider`（设置页的同一书源并发上限，与请求层同一个数，C-NET-6 的一条预算）。
- 单源超时 **60 s**（上游 `withTimeout(60000L)`），超时只让**这一源**失败并计入 `failedSources`。
- **「没搜到」不是失败**：`book-source.md` §7 把「列表规则一个都没命中」报成 `parseFailed`；
  聚合搜索把它读成**空结果**（只记 debug），否则一次全班空搜索会被说成「全部源都坏了」。
  判据：`kind == parseFailed && rulePath.startsWith('searchRule')`。
- 批的终止条件（上游一致）：
  - 有任一源产出结果 → 正常结束，`Failed` 的源只记日志与进度；
  - **全部源都失败** → 整次搜索失败（`ParseFailureKind.networkFailed`，`rulePath` 为 `search.aggregate`）；
  - 候选源为空（范围内没有被启用 / 没有 `searchUrl` / 类型不符）→ `invalidBookSource`，`rulePath` 为
    `search.scope`。这两条是本仓的失败语义，写在这里以免 UI 各自发明。

### 决策 6 暂停 / 恢复 / 取消沿用 `TaskCancellation`，在**源与源之间**生效

- 暂停 = 一个 latch（`SearchPause`），worker 在开始下一源之前 `await` 它；**不中断在飞的请求**
  （与 M10 的取消同一条理由：HTTP 层没有取消原语）。
- 取消 = `TaskCancellation`（M10 已有），被取消的批返回 `cancelled`，已产出的结果**保留**在界面上
  （上游 `SearchRunEvent` 不回收已有结果）。
- 暂停状态不是结果状态：`paused` 只是「已处理 < 总数」时不再前进，界面上是「已暂停，可继续」。

### 决策 7 分页：每页对所有候选源再搜一次，`hasMore` 只在「有源支持翻页」时为真

- `supportsSearchPage(searchUrl)`（上游同名判定）：`searchUrl` 里的 `{{…}}` / `<js>` / `@js:` 片段里出现
  独立单词 `page`，或者去掉脚本后的静态部分含 `<…>` 分组（`<1,2,3>` 那种页码列表）。**没有再请求一次去验证。**
- 第 2 页起，不支持翻页的源**直接跳过**（上游 `if (page > 1 && !supportsSearchPage()) return Found(empty)`），
  不把它记成失败。
- `hasMore` = 本页有任一源既「支持翻页」又「返回了非空结果」，且没到结果上限
  （上游 `hasMore && !merger.resultLimitReached`）。
- 结果上限 **1000**（上游 `MAX_RETAINED_SEARCH_RESULTS`）；超限时按「`other` → `tags` → 来源最少的
  `contains` → 来源最少的 `equal`」淘汰（上游 `trimSearchBooks` 的顺序照抄），并置 `resultLimitReached`。

## 后果

- 搜索结果不再落库：本里程碑只做**内存合并**（上游会把 `SearchBook` 写进数据库以便「搜索历史」复用）。
  触发条件写进 `docs/dev/roadmap.md` §3.7：用户要求「搜索历史 / 收藏搜索结果」时，再加表与迁移。
- 搜索页从「搜当前源」升级为「搜范围」：范围默认 `all`（全部启用文本源），因此**默认行为变了** —— 这是一次
  有意的行为变更，ARB 文案与页面提示要说清楚，CHANGELOG 里记在「行为变更」一节。
- 校验 / 调试页的选源与搜索共用 `resolveSearchSources`（决策 1 的候选源 + 决策 2 的类型过滤），
  所以两处不会再各自实现一遍「哪些源参与」。
- 覆盖率：新增的 domain（scope 解析、分桶合并、聚合用例）进 100% 门禁；presentation 只有 Widget 测试。
- 上游的「搜索范围」还能按**指定源**（`ScopeSourceItem` 的名字 + URL）表达，本仓照搬；名字只用于显示，
  匹配一律按 URL。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 范围只做「全部 / 单源」两态 | 用户裁决里明确包含「分组」；而且 5.5 刚把分组做出来，不用它反而怪 |
| 类型默认「不限」 | 本仓没有音频 / 图片 / 文件链路，默认全选等于把点开必失败的条目摆到用户面前 |
| `exact` = 只保留 name/author 精确等于 **且** `contains` 也保留 | 与上游语义相反；用户选「精确」就是要把「包含」的结果收起来 |
| 按 `bookUrl` 去重 | 跨源找同一本书是聚合搜索的核心价值；URL 去重会把同一本书摆成 N 条 |
| 匹配模式实现成「过滤」（只留 equal） | 上游是分桶排序，`defaultMode` 下 `contains` / `other` 仍然要显示；过滤会让结果突然空掉 |
| 暂停 = 取消在飞请求 | HTTP 层没有取消原语（M10 已记录）；只能源与源之间生效 |
| 搜索结果落库 | 需要新表 + 迁移 + `SearchBook` 的清理策略；M11 的范围里没有「搜索历史」 |
| 用 `intl` 或 collation 做归一化 / 排序 | 新依赖要走 C-DEP-1；而且会把匹配规则变成隐式的、用户无法预期的东西 |
