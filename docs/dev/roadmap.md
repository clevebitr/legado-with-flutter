# ROADMAP.md — 实现路线、验收与检查点

> 本文件是**实现顺序、验收标准与检查点**的唯一来源。
>
> - **里程碑级状态**（当前里程碑 / goal / 断点）由 `plan` 插件维护在根 `PLAN.md`，不进本文件。
> - **功能范围**（做到哪、分期如何）由 `docs/dev/adr/0014-book-source-minimal-scope.md`
>   与 `docs/dev/book-source.md` §3.1 决定。
> - **怎么写**（命名、分层、约束）由 `docs/dev/naming.md` 与 `docs/dev/constraints.md` 决定。
> - **过程记录**归 `CHANGELOG.md`：已完成阶段在本表只留一行结论 + 证据指针，不复述过程。
> - 需要规则细节时，按本文档给出的 `C-*` ID 或文档路径去查，不要在此处寻章摘句。
>
> **本文件原名 `PLAN.md`。** 小节号未变，所以 `CHANGELOG.md` 与 ADR 里对 `PLAN.md` §X 的**历史引用**
> 等同于本文件的 §X；新写的引用请直接写 `docs/dev/roadmap.md`。

---

## 1. 两条铁律

### 铁律一：竖切优先

**先让 1 个书源、1 条最短链路真正跑通，再横向铺开。**
不要先写完 14 条规则语法、再拼成链路——接口形状只有在端到端跑通一次之后才敢定。

### 铁律二：每步都过门禁

每次提交前必须跑 `AGENTS.md` §4 的全部门禁。**新增任何 `lib/core/**` 源文件都会让覆盖率门禁
报「未测量源文件」并以退出码 3 失败**（ADR-0019），所以测试必须与实现同一个 PR 提交，
不能“回头补”——这是**脚本判定**，不是提醒。

---

## 2. 阶段总览

```
Phase 0–4  环境 / core / 引擎 / M0 / M1   ✅ 已完成
Phase 5    阅读体验                        ← 当前（5.0–5.2 已完成）
Phase 6    发布前                          清单见 §5
```

依赖关系（不可颠倒）：`Drift ──► 书源仓库 ──► 缓存 / 阅读进度`。引擎侧的
`ParseResult` / `HttpClient` / `JsBridge` 已在 Phase 1–4 定型，本阶段不重开。

当前进度以 §3.1 的阶段状态表为准；里程碑级状态（当前里程碑 / goal / 断点）见根 `PLAN.md`。

---

## 3. 各阶段：目标 / 交付物 / 验收

### 3.1 阶段状态表

| 阶段 | 状态 |
|---|---|
| Phase 0–4 — 环境 / core / 引擎 / M0 / M1 | ✅ 完成（G1–G4 达成；证据见 `tool/spot_check/README.md` §4 与 `CHANGELOG.md`） |
| Phase 5 — 阅读体验 | 🚧 进行中：5.0 ✅、5.1 ✅、5.2 ✅、5.3 ✅、5.4 ✅、5.5 ✅、5.6 ✅、5.7 ① ✅、5.8 的文件选择半程 ✅、5.10 ✅、M11 ✅、M12 ✅、M13 🚧（见 §3.9）、M15 🚧（见 §3.10）；其余见 §3.6 |
| M16 — 漫画引擎 | 🚧 落地中：M-1–M-3 ✅；设备级实跑与真源抽查未闭环（见 §3.10） |
| M18–M21 — UI 对齐（外壳/书架/规则/数据） | 🚧 M18 已落地（U1–U3）；M19–M21 未开工（见 `docs/dev/ui-gap.md` 与 §3.11） |
| M17 — 听书与音频 | ⏳ 未开工（已交给另一个代理；判断归 ADR-0054） |
| Phase 6 — 发布前 | ⏳ 未开始（清单见 §5） |

> 步骤级「下一步」不写在此处，由 `todo` 工具决定。

### 3.2 Phase 1 — core 基础设施

> ✅ **已完成**：1.1 `ParseResult` 契约、1.2 logging 门面、1.3 `core/platform/`、1.4 `core/network/`、
> 1.5 Drift 库与 TTL 表。依据（ADR-0002 / 0006 / 0020 / 0003）与逐条验收见 `CHANGELOG.md`。

### 3.3 Phase 2 — 书源引擎【竖切】

> ✅ **已完成（2.1–2.7；G2a 达成，ADR-0024）**：2.1 模型、2.2 `RuleEngine` 最小版、
> 2.3 `renderUrlTemplate`、2.4 四个 UseCase、2.5 最小 UI、2.6 离线语料、2.7 `failureAt`。

### 3.4 Phase 3 — M0 横向铺开

> ✅ **已完成（2026-10-12）**：矩阵 #1–#14 —— 3.1 默认规则语法、3.2 连接符 / `@css:` / `@json:`
> 与 ADR-0026 的失败降级、**步骤 3 真实站点 spot-check（G2b）**、3.3 `JsBridge`、3.4 `@js:` 与全部
> JS 绑定、3.5 翻页与 `isVip` / `replaceRegex`、3.7 真实源回归（矩阵 M0 状态列）、3.8 同一书源并发
> 预算、3.9 charset 检测缓存。证据与逐行结论归 `tool/spot_check/README.md`。

### 3.5 Phase 4 — M1

> ✅ **已完成（2026-10-14；G4 全绿）**：b0 规格前置（ADR-0035 / 0036）、b1 `updateTime`、
> b1b `java.*` 兼容面（ADR-0037）、b2 `concurrentRate`、b3 `canReName`、b4a / b4b 发现页、
> b5 两条真源缺口、b6 `ruleBookInfo.init`。
> **b7（JSON 条目上裸 `@js:` 的 `result` 绑定）① 取证已完成、② 待裁决 —— 见 §3.7。**

### 3.6 Phase 5 — 阅读体验

**目标：** 让人在 UI 里走完两条闭环——① 选 / 导入书源 → 搜索或发现 → 详情 → 目录 → 正文 → 阅读；
② 书架 + 设置 + 缓存清理 + 法律声明可用。

**排序：** **5.1 是 5.2–5.8 的前置**（5.9 的平台件与法律声明页可并行），已完成项见下方各小节的「状态」行。

#### 5.0 规格前置（✅ 已接受，2026-10-14）

> 产出：ADR-0040（导入契约：主键 / 重复导入 / 32 MiB 上限 / 校验分档 / 失败语义）、ADR-0041（feature 边界）、
> ADR-0021 复审注记、ADR-0034 修订注记；`book-source.md` §2、`architecture.md` §1 / §2 / §6、双语 ARB 同批同步。

#### 5.1 书源入口（✅ 已完成，2026-10-14）

> `book_sources` 表（`schemaVersion` 1 → 2 + `drift_schemas/drift_schema_v2.json` + 迁移测试）、
> `BookSourceDao` + `BookSourceRepository`（身份规则 = `bookSourceFingerprint`，与入库工具共用同一实现）、
> `ImportBookSources`（粘贴文本 / URL，32 MiB 上限在解析前判）、可写的 `SelectedBookSource`（默认 = 启用 →
> `customOrder` → `id`，选中的行被删后回落）、列表页 + 导入页 + 双语 ARB、`on_disk_database` 的真实写入。
> 证据：`core` 1014/1014、`domain` 1837/1837、`data` 54/54；设备级 Windows 99 s / Android 169 s。

#### 5.2 正文缓存（✅ 已完成，2026-10-14）

> `ContentCache` 端口（`domain/`）+ `CacheDao` 适配器（复用其键形状与
> 过期列：`ruleField=content`、`page=1`、TTL = `chapterCacheTtl` 半天）；`FetchContent` 命中即跳过整个
> 引擎（**一个请求都不发**）、只缓存成功结果；缓存失败由**唯一**豁免点 `absorbCacheFailure` 吸收
> （ADR-0033 的修订注记），端口保持 total。
> 验收：命中 / 过期 / 另一书源同 URL / 读失败 / 写失败各 ≥1 条单测，另有「同一章节两次只请求一次」。

#### 5.3 阅读器（✅ 已完成，2026-10-21）

> **状态：** `reader` feature 落地（`ReaderPage` / `ReaderSession` / `ReaderSettingsNotifier` + 三条端口），
> `reading_progress` 读写走 `bookshelf`（ADR-0041 §决策 4、ADR-0044 §决策 2），`books.tocUrl` 随 v5 入库。
> 四处裁决见 **ADR-0044**。

- 翻页模式：**滚动 + 分页两种都做**（用户裁决）；字号 / 行距 / 背景 / 翻页方式四轴存 `shared_preferences`
  （C-NET-9），与设置页的全局字号**叠乘**而不是共用一个旋钮。
- 章节切换：上一章 / 下一章 / 目录面板 / 分页模式章末的「下一章」。
- **阅读进度落盘**：表已随 5.4 建好（v3），本节补上读写链路；偏移是**按比例估算**的（ADR-0044 §决策 4）。
- 同时收 §3.7 的两条展示项：**`updateTime` 的展示**（搜索列表 / 详情 / 目录）、**`canReName` 的消费方**
  （加入书架时决定是否覆盖已有书名 / 作者）。
- **验收**：字号 / 背景 / 翻页方式切换的 Widget 测试 ✅；进度写入 → 恢复的往返测试 ✅（`reader_session_notifier_test`）；
  `updateTime` 与 `canReName` 各有行为测试 ✅；Golden 基线按 `testing.md` §5 **单独 PR**（未做，见 §3.7）。

#### 5.4 书架（✅ 已完成，2026-10-21）

> `books` + `reading_progress` 两张表（`schemaVersion` 2 → 3 + dump / 迁移测试 / `on_disk_database` 真实写入）、
> `BookshelfDao` + `BookshelfRepository`（身份 = `(sourceUrl, bookUrl)`；重复加入只刷新快照，用户态列不动）、
> `Bookshelf` Notifier（写失败转 `ParseFailure` 而不是抛）、书架页（在追 / 已读、置顶、删除；最近阅读排序）、
> 书籍详情页的「加入书架」经 `BookshelfWriter` 端口 + 装配根绑定（ADR-0041 §决策 2），搜索页的书架 / 设置入口经
> `AppNavigation` 端口（**ADR-0042**）。
> 证据：896 用例、`core` 1184/1184、`domain` 1892/1892、`data` 130/130。
>
> **三条登记项的落地**：① 规则变量**不落盘**（沿用 ADR-0034 修订注记）；② `downloadUrls` / `relatedBooks`
> **未做**——它们是规则面字段，且没有真实语料证据，触发条件留在 §3.7；③ `isVolume` / `formatJs` /
> `preUpdateJs` 本阶段不做（ADR-0041 §决策 6）。`java.get('bookName')` 也**未做**：它要把 Book / Chapter 绑进
> JS 变量表，属规则面改动 —— 已排进 **M12**（§3.8、`DECISIONS.md` #7）。

#### 5.5 书源展示与排序字段（✅ 已完成，2026-10-21）

> **状态：** 列表页按 **ADR-0045** 落地：四个排序键 + 固定 tie-breaker、分组筛选、默认序下的拖拽重排、
> 行内展示分组 / 最近更新 / 响应耗时 / 校验注释；排序与筛选持久化在 `book_source/data/`。
> `StoredBookSource` 现在暴露五个**列投影**（校验写的是列，负载不动）。

- `lastUpdateTime` / `respondTime` / `weight` / `customOrder` 的展示与排序 ✅（用户裁决：权重降序 / 响应耗时
  升序 / 名称升序，外加默认的手动序）；`customOrder` 可**拖拽**编辑（整体归一化写入）。
- **书源校验 / 调试入口** ✅ 已随 5.10 落地；`checkKeyWord` 的处置见 ADR-0043 §决策 2。

#### 5.6 设置页（✅ 已完成，2026-10-21）

> `AppSettings`（`themeMode` / `fontScale` / `maxConcurrentPerSource`，**钳制在工厂里**）+ `SettingsRepository`
> （`shared_preferences`，键私有于 `settings/data/`）+ 设置页（主题三段、字号滑杆、并发步进器、清空缓存）；
> 主题与字号在 `app.dart` 接线（字号**叠加**在系统无障碍缩放之上），并发上限经 `concurrencySettingProvider`
> 由装配根注入 `HttpPolicy`。
>
> **两条登记项已闭环：** ① `budgetOrDefault` 在 release 也生效——`<= 0` 回落默认并记 warning（`assert` 会被剥掉，
> 违反它会让该源的请求永久排队）；② `httpClientProvider` 改 `keepAlive`，预算不再随操作重建。
>
> **关于页入口未做**：它属于 5.9 的法律声明页，一个打开空页的菜单行是死链（C-BAN-2），触发条件登记在 §3.7。

#### 5.7 缓存清理

- ① **全量清空 ✅ 已完成（随 5.6 落地，2026-10-21）**：`CacheDao.deleteAll` + `CachePurger` 端口，零 schema 变更；
  设置页的「清空缓存」就调它，回显删掉多少条。
- ② **按书源清理**：给 `cache_entries` 加 `sourceId` 列 → dump + 迁移测试（成本更高，按真实需求再做）。

#### 5.8 导入 / 导出保真

> **状态：文件选择器部分已提前落地**（`core/platform/` 的 `BookSourceFilePicker` 端口 + `file_selector`
> 实现，导入页第三条入口）。**导出与分享仍归本步**。

- `toLegadoJson` 一类的入口把 `extra` 合并回写（ADR-0021 §后果今天只兑现了「内存里不丢」的一半），并支持
  导出全部书源；导入与导出共用同一份校验。
- **验收**：往返测试（导入 → 导出 → 再导入不丢键，含四层 `extra`）；畸形输入不写出半截文件。

#### 5.9 平台体验 + 法律声明页

- `PredictiveBackSupport` / `SystemUiController` / `HapticsController` 三个接口落地（`platform.md` §2 的契约：
  不支持的平台返回 `null` 或 no-op，**禁止抛异常**，调用方不得 `!` 解包）。
- 「关于 → 法律声明」页（C-UI-9 的六个 ARB 键，GPL 门禁），页面存在且可达由 Widget 测试断言。
- **验收**：`platform.md` §6 的三端清单逐项勾选（Android 13+ 预览动画、edge-to-edge、iOS 边缘手势、
  Windows 悬停 / 焦点与窗口缩放）。

#### 5.10 书源测试机制（✅ 已完成，2026-10-21）

> **状态：** 两个机制都落地（`BookSourceCheckPage` / `BookSourceCheck` + `BookSourceDebugPage` /
> `SourceCheck`），四项裁决见 **ADR-0043**，五类失败的复现记录见
> `tool/spot_check/source_check_records.md`。上游行为要点表保留为对照组（本仓的有意差异写在
> ADR-0043 §后果，不要照抄上游的 `Incomplete`、URL 即主键或 `bookSourceComment` 之下的 payload 改写）。

**上游的两个机制**（`F:\Projetcs\legado-upstream`）：

| 机制 | 上游落点 | 做什么 |
|---|---|---|
| **批量校验** | `data/repository/BookSourceCheckRepository.kt` + `domain/gateway/BookSourceCheckGateway.kt` + `service/BookSourceCheckService.kt` | 对**选中的一批书源**逐个跑链路，按阶段打「失效」分组、写错误注释与 `respondTime`，UI 显示进度与逐源结果 |
| **单源调试** | `ui/book/source/debug/*` | 对**一个书源**选目标（搜索 / 发现 / 详情 / 目录 / 正文）+ 查询词跑一次，实时事件流（消息 / 来源 / 错误，带耗时），可从示例入口一键填充 |

**上游的行为要点（照抄前先核，别只抄形状）：**

- 阶段可逐个开关：搜索、发现、详情、目录、正文；搜索词取 `ruleSearch.checkKeyWord`，为空或「像规则」（含 `http` / `::` / `++` / `--`）时回落到默认词（`BookSource.getCheckKeyword`）。
- 结果写回书源自身：分组追加 `搜索失效` / `发现失效` / `搜索目录失效` / `搜索正文失效` / `发现目录失效` / `发现正文失效` / `搜索链接规则为空` / `发现规则为空`；异常按类型追加 `校验超时` / `js失效` / `网站失效`；错误注释写进 `bookSourceComment`；`respondTime` 记录耗时。**重新校验前先清掉**这些「失效」分组与错误注释（`removeInvalidGroups` / `removeErrorComment`）。
- 状态机：`Pending / Running / Succeeded / Failed / Cancelled`，失败原因 `CheckFailed / SourceMissing / SaveFailed / Incomplete`；正常跑完但仍有未终止项 → `Failed + Incomplete`，被取消 → `Cancelled`。
  **本仓差异（ADR-0043 §后果）：** 没有 `Incomplete` —— 协作式取消把每个未开始的源直接标成 `Cancelled`。
- 并发按「下载线程数（≥1）」起线程池，单源超时默认 180 s 可配；批量任务在 Android 上是**前台服务 + wake lock**。
  **本仓落地：** 并发 = 设置页的同一书源并发上限（`concurrencySettingProvider`），超时是页面上的下拉（30/60/120/**180**/300 s），
  Android 只有 `PARTIAL_WAKE_LOCK`（`LongRunningTask`），前台服务登记在 §3.7。

**本仓开工前必须先定死的四件事（已裁决，见 ADR-0043；下表保留为裁决索引）：**

1. **校验结果落在哪**：我们的 `BookSource` 是 freezed 投影，分组是 `groupName` 列、注释在 `extra` 里。要么加列（dump + 迁移），要么只产出**内存报告**（不写回），要么新建 `source_checks` 表（可查询历史）。这是 M10 的第一条 ADR。
2. **`checkKeyWord` 的处置**：`BookSource.md` §2 目前把它留在 `extra`；本里程碑要把它建模，并定义「像规则就跳过」的判据（上游的四个排除前缀是**行为依据**，不是规格）。
3. **长任务的平台面**：前台服务 / wake lock 在 `platform.md` §2 的既有接口之外，需要新的抽象（例如 `LongRunningTask`），并给出 Windows 上的等价物（可为 no-op）。
4. **失败语义不另起一套**：逐源结果是 `ParseResult<SourceCheckReport>` 的集合，`ParseFailureKind` 不够用时**先改 `architecture.md` §5 并写 ADR**，不得在 feature 内私自加枚举。

**验收：**

- 批量校验：≥5 条可判定的失败（搜索失败 / 目录为空 / 正文为空 / 超时 / JS 错误）各有一次可复现的执行记录；分组 / 注释 / `respondTime` 的写入各 ≥1 条单测。✅ 记录见 `tool/spot_check/source_check_records.md`。
- 取消必须是 `Cancelled` 而不是 `Failed`（上游 `Incomplete` 口径）；再跑一次要先清掉上次的「失效」分组。✅ 单测 + Widget 测试各一条。
- 单源调试：目标 × 查询词的组合走真实链路，事件流至少包含「消息 / 来源 / 错误」三类；Widget 测试覆盖空态、运行中、成功、失败、取消。✅
- 门禁全绿 + 双端设备级实跑（ADR-0039）。

#### 完成判定（出口）

1. `C-UI-9` 页面存在且可达；§5 发布前清单里属于本阶段的项已勾选。
2. `platform.md` §6 的三端清单逐项通过。
3. 门禁全绿（命令清单归 `AGENTS.md` §4）；`data/` 层首次进入覆盖率统计（`testing.md` §2）。
4. **G5** 与 **G7** 达成；**G6** 留 Phase 6；§7 的文档同步清单走完。

> **本阶段高发返工陷阱（对照 §6）：** 新增 `lib/core/**` 或 `lib/features/*/data/**` 却不带测试（#7）；
> 手改 `database.g.dart` 或忘记 dump（#8）；同一数值写在两处（#9）；把 `toJson` 当成无损导出（ADR-0021 §后果）；
> 把「构建成功」当成「功能可用」（#1）。

### 3.8 M11 / M12 — 引擎兼容、聚合搜索与健壮性

> **状态：** 两个里程碑由用户 2026-10-21 裁决立项；**逐条对照** `F:\Projetcs\legado-upstream` 移植，
> 差异逐条写 ADR（与 M1 / M4 / M10 同一做法）。范围、规格前置与验收标准记在 `DECISIONS.md`
> （M11 = #6，M12 = #7），本节只放「做什么 / 先后 / 出口」，不复制判据。

**M11 — 聚合搜索 + 选源分类（#6）** —— ✅ **已完成（2026-10-21，ADR-0046）**

- **引擎**：范围三态与回落、类型筛选（默认文本）、匹配模式（分桶排序）、`(name, author)` 去重 + origins、
  并发 / 60 s 单源超时 /「没搜到不算失败」、暂停与取消、分页 `hasMore` 与 1000 条上限、
  以及搜索与校验共用的 `resolveSearchSources`。
- **展示**：搜索页的范围 chip（全部 / 分组 / 指定源）与筛选 sheet（类型 + 匹配模式）、聚合结果列表
  （「N 个来源」标记，点到命中它的第一个源）、进度行与暂停 / 继续 / 停止、加载更多；
  校验页新增分组 + 类型筛选 chips（同一套「哪些源参与」的概念）。

| 交付物 | 上游落点 |
|---|---|
| 搜索范围（全部 / 分组 / 指定源 + 持久化与显示） | `ui/book/search/SearchScope.kt`、`domain/model/BookSearchScope` |
| 书源类型筛选（0 文本 / 1 音频 / 2 图片 / 3 文件） | `BookSearchRequest.types` |
| 匹配模式（模糊 / 精确书名 / 精确书名+作者） | `domain/model/MatchMode` |
| 多源并发 + 逐源进度 + 单源超时不打断整批 | `domain/usecase/SearchBooksUseCase.kt` |
| 暂停 / 恢复 / 取消（源与源之间生效） | `BookSearchControl` |
| 结果合并去重排序 + 分页与 `hasMore` | `SearchResultMerger`、`supportsSearchPage()` |
| 校验 / 调试按「分组 + 类型」筛选选源（与搜索范围共用一套选源逻辑） | 本仓 5.10 的两个页面 |

**M12 — 引擎规则面 + 编码与单源预算（#7）** —— 🚧 **进行中（ADR-0047）**

改造前先用真实语料（`4dc410d1.json`，128 条）量出失败分布：新增
`tool/spot_check/batch_probe.dart`（全量四段跑，输出 `stage/kind/rulePath` 直方图）。首轮只有
**8/128** 条四段全通，其中 50 条 `searchUrl` 是 `url,{…}` 形态、50 条规则含 `<js>`、3 条导入即失败。

| 交付物 | 状态 |
|---|---|
| JSON 条目上裸 `@js:` 的 `result` 绑定 | ✅ **已落地**：`_resultOf` 按 scope 分流（JSON 条目给对象，页面给正文） |
| `header` 写成规则（`@js:` / `<js>`）求值 | ✅ **已落地**：原文进 `BookSource.headerRule`，`PageFetchService.headersOf` 在首个请求前求值；导入不再丢字段 |
| 默认 / `@@` 规则打在 JSON scope 上 | ✅ **取证后不改**（ADR-0047 §决策 6）：上游 jayway JsonPath 同样要求 `$` 前缀，换分析器对能跑的规则无增益 → 登记为有意差异 |
| 页面字段的 `page` 绑定与已取到的那一页一致 | ✅ **取证后不改**：字段规则本身不消费 `page`，语料无反例 |
| `java.get('bookName' / 'title')` 特例 | ✅ **已落地**：`ChapterRequest` + `JsJob` 两个内置键（ADR-0049） |
| Big5 / Big5-HKSCS / `shift-jis` / `euc-jp` 的检测与解码 | 🚧 **Big5 解码已落地**（`enough_convert`，ADR-0048：许可政策改为 MPL 白名单）；检测仍缺、HKSCS 扩展区部分支持、日文 `RangeError` 登记未做 |
| 单源预算（超时 / 重试）与同源多阶段失败的容忍 | ✅ **已落地**：三处失败隔离（ADR-0047 决策 7）+ 统一 `SourceBudget`（ADR-0049 决策 3） |
| **规格外的两项（真实语料驱动，ADR-0047 §决策 1/2）** | ✅ `<js>` 分段链（矩阵 #31，50 条源）+ URL 规则后缀 `url,{…}`（50 条源，含 POST / body / charset / headers） |

**顺序：** M11 先于 M12 —— 聚合搜索会先给「单源失败不拖垮整批」立出第一份真实用法，M12 的单源预算
直接复用它；反过来做会让 M11 再造一遍。**两者的规格前置（ADR-0045 聚合搜索、M12 的三条契约 ADR）都必须
在动代码前完成**（`AGENTS.md` §3 第 1 步）。

**出口：** 严格档验收（用户裁决）：每条能力有单测 + 派生源/离线语料回归；收尾 Windows + Android
`integration_test` 双端实跑；真源抽查一次（M12 的 `header` / `@js:` 两条**必须**有真实源证据，
否则只能记「已实现未验证」）；`book-source.md` 的矩阵状态列按真实回归逐行改。

### 3.9 M13 / M14 — UI 修复 + 书源管理 / 阅读体验

> **状态：** 2026-10-22 用户裁决立项（`DECISIONS.md` #11）：先修 UI 问题、补缺失的 UI 功能，逐条对照
> `F:\Projetcs\legado-upstream`，**重点是书源管理与阅读体验**。分两批：**M13 = UI 修复 + 书源管理**，
> **M14 = 阅读体验**。本节只放范围与验收，判据归 ADR-0050 与既有 ADR-0040 / 0045 / 0046。

**M13 — UI 修复 + 书源管理** —— 🚧 进行中（S1–S6 已落地，待收尾门禁）

| # | 交付物 | 现状 / 触发 |
|---|---|---|
| S1 ✅ | **封面**：共用 `CoverImage`（占位 / 错误态 / 解码尺寸 / 装饰性语义）接入发现页、聚合搜索、详情页、书架 | `cached_network_image` 早在依赖里却**全仓 0 处引用**，所以现在一个封面都不显示；`Book` / `SearchBook` / `BookInfo` / `ShelvedBook` 的 `coverUrl` 都已是绝对地址，只差 UI |
| S2 ✅ | **批量操作**：长按进入多选、全选 / 反选 / 退出；批量启用 / 禁用 / 删除 / 加入分组 / 移出分组 | 现在只有行内 `Switch` 与单条删除；DAO 需要批量方法（一个事务，见 ADR-0050 §决策 2） |
| S3 ✅ | **列表搜索 + 分组管理 + 「全正常」筛选**：名称 / URL / 分组搜索；分组新建 / 重命名 / 删除；筛选维度加「全正常 / 有失效」，分组列表覆盖**全部**自带分组（含没有任何校验标记的源） | 现在只有分组 chips（来自投影列）与排序；「全正常」是用户点名的能力 |
| S4 ✅ | **书源编辑页**：名称 / URL / 分组 / 类型 / 权重 / header / 五组规则；保存前用 `BookSource.fromLegadoJson` 校验 | 现在没有任何编辑入口；保存要重写 payload 并**重算指纹**，而指纹参与 `(url, 指纹)` 唯一索引（ADR-0040）→ 身份语义归 **ADR-0050 §决策 3** |
| S5 ✅ | **单条校验 + 导出**：行菜单的「校验」（复用 M10 `CheckBookSource` 只跑一条）与「导出」（payload 原文 → 剪贴板 / 保存文件） | 现在校验只能整批；导出归 5.8，但单条导出不依赖批量导出 |
| S6 ✅ | **UI 缺陷修复**（审计所得）：详情页没有「开始阅读 / 继续阅读」（只能点某个目录项才进阅读器）、详情信息块没有封面与简介折叠、搜索页「加载更多」无进度、书架行只有图标 | 这些不是「新功能」，是缺了就说不通的交互 |

**M14 — 阅读体验** —— ⏳ 未开工（本轮只登记）

| # | 交付物 | 上游落点 |
|---|---|---|
| R1 | 底部阅读菜单 + 进度 / 亮度条（点中间唤出、自动隐藏、沉浸式） | `ui/book/read/ReadBookMenuBarBottom.kt` |
| R2 | 目录面板增强：当前章居中高亮、正序 / 倒序、章节名搜索 | `ui/book/read/ReadBookMenuBar*`、`ChapterListSheet` |
| R3 | **换源**：按书名跨源重取详情 + 目录并尽量回到同一章 | `ui/book/read/sheet/ChangeChapterSourceSheet.kt`（新领域能力，需 ADR） |
| R4 | 排版扩展：字体族 / 段距 / 首行缩进 / 页边距（简繁转换与粗体可后置） | `ui/book/read/ReadStyleDelegate.kt`、`config/` |

**验收（两批同一口径）：** 每项 ① 单测 + Widget 测试；② 双端 `integration_test` 实跑；③ 收尾跑 `AGENTS.md` §4
全部门禁；④ 新增用户可见文案必须双语 ARB 同步；⑤ 新增决策写 ADR（M13 的 S3/S4 已在 ADR-0050 里定）。
**M14 的真源抽查**：换源要在一条真实书源上换到另一个源并回到同一章（否则记「已实现未验证」）。

### 3.10 M15 / M16 / M17 — 书源管理二期、漫画引擎、听书与音频

> **状态：** 2026-10-22 用户裁决立项（`DECISIONS.md` #13）：三批顺序 **M15 书源管理二期 →
> M16 漫画 → M17 听书/音频**，逐条对照 `F:\Projetcs\legado-upstream`。规格前置：**ADR-0052**（管理二期）、
> **ADR-0053**（漫画）、**ADR-0054**（音频与 TTS）。本节只放范围与出口，判据归上述 ADR。

**M15 — 书源管理二期（ADR-0052）** —— 🚧 进行中（V1–V6 已落地；待双端实跑 + 真源抽查）

| # | 交付物 | 现状 / 触发 |
|---|---|---|
| V1 ✅ | **状态灯**：`source_checks` 表（schema v5 → v6 + dump + 迁移测试），四态（通过 / 失败 / 降级 / 未校验）+ 「上次校验 <相对时间> · 耗时」+ 行内语义标签 | 现在只有「有失效 / 全正常」筛选，行内没有指示；校验结论只有文本列 |
| V2 ✅ | **探索开关**：`is_explore_enabled` 列（v6，导入按 `enabledExplore` 初始化新行），行内徽标 + 批量开关 + 筛选；发现页空态与校验页的发现阶段消费它 | 现在 `exploreUrl` 只能整条规则在或不在，用户无法单独关发现 |
| V3 ✅ | **批量管理补全**：置顶 / 置底（整表重编号，单事务）、分组重命名 / 删除 / 移出（只重写 payload 的 `bookSourceGroup`） | 现在只有启停 / 删除 / 加入分组 |
| V4 ✅ | **列表视图**：升 / 降序切换（默认序倒序 = 手动序反转，此形态禁用拖拽）+ 按域名分节 | 现在四个排序键固定方向、无域名分节 |
| V5 ✅ | **导入预览**：`ImportBookSources.preview` + `commit`，预览逐条勾选（new / refresh / 拒绝原因），`execute` 保留为「全选 + 提交」 | 现在导入一按就落库，错误只能从计数里猜 |
| V6 ✅ | **批量处置**：工具栏「多选」入口（可从零开始勾）、「有失效」筛选行旁的一键禁用 / 删除、分组管理里的「选中该组全部书源」/「删除该组全部书源」（ADR-0059） | 多选只能长按进入；失效源与整组书源都得先手点几十下才能批量处理 |

**M16 — 漫画引擎（ADR-0053）** —— 🚧 进行中（M-1–M-3 已落地；待设备级实跑 + 真源抽查）

| # | 交付物 |
|---|---|
| M-1 ✅ | `FetchMangaPages`（`ruleContent` 列表语义 → 图片页，相对地址按章节页解析，空列表整章失败） |
| M-2 ✅ | `MangaReaderPage`（按 `sourceType` 分派；竖滚动 + 左右翻页、双击/双指缩放、失败页重试、页号进度） |
| M-3 ✅ | 预取前后各 1 页、解码尺寸上限；零新依赖（`cached_network_image` + `InteractiveViewer`） |

> **M16 落地记录（2026-10-22）：** `FetchMangaPages`（`ruleContent` 列表语义、相对地址按章节页
> 解析、分页去重、非 http(s) 地址点名丢弃、空结果整章失败）与 `reader.mangaPages` /
> `reader.sourceKind` 两条端口；`ReaderPage` 按源类型分派到 `MangaReaderPage`（滚动条 / PageView
> 两种观影、页号进度复用 `reading_progress`、图片带源 header、失败页独立重试、前后各 1 页预取）。
> 图片走 `CachedNetworkImageProvider`（C-PERF-3），测试用 `ImageProvider` 注入缝 + 1×1 PNG，不触网。
> **落地修正（已写回 ADR-0053 §决策 3）：** 常驻 `InteractiveViewer` 会抢走翻页横滑，改为 1 倍普通图片
> + 双击放大后才挂 `InteractiveViewer`。**未闭环：** Windows/Android `integration_test` 与真源抽查
> （Android 当前无设备）。

**M17 — 听书与音频（ADR-0054）** —— ⏳ 未开工

| # | 交付物 |
|---|---|
| A-0 | 依赖探针：`just_audio` / `just_audio_windows` / `audio_service` / `flutter_tts` 的三端可编译 + 双端实跑；许可证写 `NOTICE.md` §5 |
| A-1 | `FetchAudioTracks`（音频源 `ruleContent` → 直链音轨） |
| A-2 | 音频播放器（播放/暂停/seek/倍速/上下章/失败重试）+ 进度写 `reading_progress`（毫秒偏移） |
| A-3 | 系统 TTS 朗读（语速/音高/音色、暂停/继续/停止、读完自动下一章、退出默认停止） |
| A-4 | 后台与通知：Android `audio_service` 前台服务，Windows 降级为 no-op |

> **M15 落地记录（2026-10-22）：** schema v5 → v6（`source_checks` 表 + `is_explore_enabled` 列 + dump
> 与迁移测试）；状态灯四态与「上次校验」摘要、探索徽标/批量开关、置顶/置底、分组重命名/删除/移出、
> 升降序与域名分节、分组管理对话框全部接线；`source_checks` 与三列写回在同一事务（ADR-0052 §决策 1），
> 历史每源保留 20 条。**V5 已按 ADR-0052 §决策 5 拆成 `preview` / `commit`**：预览列出每条的新增 /
> 刷新 / 拒绝原因，逐条勾选后只提交被选中的原始条目，`execute` 保留为「全选 + 提交」；`exists`（身份
> 查询）是新端口方法，预览不写库。**设备级实跑：** Windows 桌面 3 个用例文件全过（`js_bridge` 25/25、
> `on_disk_database` 3/3，应用启动用例通过）；**Android 未实跑**——当前环境没有可用模拟器/真机
> （`flutter emulators` 为空），按 `test-environment.md` §1 登记为环境阻塞。**真源抽查未做**：四态状态灯
> 目前由离线语料与 Widget 测试覆盖，按约定记「已实现未验证」。

**验收（三批同一口径）：** 每项 ① 单测 / Widget 测试；② 双端 `integration_test` 实跑；③ `AGENTS.md` §4
全部门禁；④ 双语 ARB 同步；⑤ 新增/改变的决策写 ADR。**M15 的真源抽查**：批量校验 ≥5 条源后，
状态灯的四态各至少出现一次且与注释 / 分组一致。**M16 / M17 的真源抽查**：各一条真实图片源 / 音频源
从搜索读到第一页 / 听到第一段（不通过则记「已实现未验证」）。

> **M15/M16/M17 共用的回归点：** `ReaderPage` 按 `sourceType` 分派后文本阅读不许回归；
> 书源列表的三个筛选轴（用户分组 / 校验状态 / 探索开关）互不污染（ADR-0050 §决策 1 的延伸）。

### 3.11 M18–M21 — UI 对齐：上游 UI 结构对照与缺口清单

> **状态：** 2026-10-22 立项（用户要求对照 `F:\Projetcs\legado-upstream` 列出缺失的关键 UI）。
> **缺口清单、优先级（P0/P1/P2）与每批的新增数据/决策点归 `docs/dev/ui-gap.md`**（唯一清单，
> 本节不复述）。这里只放批次与出口。

| 里程碑 | 一句话范围 |
|---|---|
| **M18 — 应用外壳与「我的」** | ✅ 底部导航（书架/发现/搜索/我的）+ `IndexedStack` 保活；我的页入口；关于与法律声明（C-UI-9）。落地记录见本节末 |
| **M19 — 书架与书籍详情** | 书架分组 + 管理页（多选批量）；详情目录预览/阅读记录/改分组；书签与阅读记录 |
| **M20 — 阅读内搜索与规则管理** | 书内全文搜索；替换净化 / 目录规则 / 字典规则 / 高亮标签的最小 CRUD |
| **M21 — 数据与系统 UI** | 按书/按源缓存、主题配置、阅读设置扩展、备份恢复、本地导入、二维码、书源登录 |

**顺序：** M18 先立「家」；M19 依赖 M18 的导航与入口；M20/M21 可换序。U16（首页统计）排到
M19/M21 之后，U17（RSS）/U18（AI 翻译）**不排期**（新产品线，需独立 ADR）。

**开工前置（每批都要）：** 规格 ADR（尤其是新 feature 边界、新表/新列、备份格式、平台依赖）；
新表/新列必须 dump + 迁移测试。**出口：** 见 `ui-gap.md` §4 的「共用门禁」——四项门禁 + 双端实跑 +
双语 ARB + ADR，与 M15/M16 同一口径。


> **M18 落地记录（2026-10-22）：** 新增根级 `lib/app_shell.dart`（组合根，四 tab + `NavigationBar`，
> `IndexedStack` 保活，默认书架）；`features/shell/presentation/` 放「我的 / 关于 / 法律声明」三页，
> 只经 `AppNavigation` 端口跳转（新增 `openBookSources` / `openAbout`）；关于页用 `app_info.dart` 的
> 版本常量（单测读 `pubspec.yaml` 比对）、打包 `assets/legal/gpl-3.0.txt`、源码地址可复制（不引入
> `url_launcher`）；法律声明页覆盖 C-UI-9 六键并可查看 GPL 全文。落地页从搜索页改为外壳，
> `app_test` / `app_boot_test` 同步更新。
> **未闭环：** 设备级 `integration_test` 实跑（Windows / Android）与「我的」入口的真机点按。

### 3.7 未闭环交接登记（不得静默丢弃）

> 已闭环 / 已否决的登记项（并发上限 3、M1 #15–#19、规则变量不落盘、`ruleBookInfo.init` 未应用、b1b 首版
> 返工与真源回归、`{{…}}` 内 `##`、JSONPath `]name`、charset 结果缓存、`bookSourceType=4`、`java.*` 兼容面…）
> 已移出本表，过程记录见 `CHANGELOG.md`。下表只留仍未闭环的；**触发条件写在这里，行为面仍归
> `book-source.md` 的注记**。

| 事项 | 去向 / 触发条件 |
|---|---|
| `canReName` 的消费方（覆盖已有书名 / 作者） | ✅ **已闭环（5.3，2026-10-21）**：加入书架时透传 `canReName`，为假时 `refreshDetails` 只刷新封面 / 分类 / 简介 / 最新章节（ADR-0044 §决策 5） |
| `updateTime` 的展示（列表 / 详情 / 目录） | ✅ **已闭环（5.3，2026-10-21）**：三处都显示规则原文，空值不显示（`bookSourceUpdateTimeLine`） |
| 阅读进度的字符偏移是**按比例估算**（滚动或分页比例 × 正文长度），不是字符级锚点 | **未做（5.3 登记，ADR-0044 §决策 4）**：精确锚点要把锚点写进章节模型并版本化。触发 = 用户反馈「同一章重进后位置偏很多」 |
| 分页模式的**断点**取 `TextPainter` 右下角文本位置，落点不是行首时整页会少排半行 | **同上**（同一触发条件） |
| 分页模式**不跨章连续翻页**：章末给显式的「下一章」页 | **未做（5.3 登记，ADR-0044 §决策 4）**：跨章翻页要预取全部正文。触发 = 用户反馈「翻到章末还得点一下」 |
| 阅读器 UI 的 **Golden 基线**（`testing.md` §5） | **单独 PR**（5.3 验收明写；本轮不做，避免把 Golden 资产塞进功能 PR） |
| 聚合搜索的结果**不落库**（上游把 `SearchBook` 写进数据库以复用搜索历史） | **未做（3.8 登记，ADR-0046 §后果）**：M11 只做内存合并。触发 = 用户要求「搜索历史 / 收藏搜索结果」，届时加表 + 迁移 |
| 音频 / 图片 / 视频 / 文件源**只能被搜索的类型过滤排除**，本仓没有它们的链路（阅读器只读文本） | **未做（ADR-0046 §决策 2 的有意差异）**：类型筛选默认只选文本，界面上可以把它们打开但打开后没有可读页面。触发 = 真的要支持非文本书源 |
| `java.get('bookName' / 'title')` 的上游特例（`AnalyzeRule.kt:812-821`） | ✅ **已闭环（M12，2026-10-21）**：`ChapterRequest` 替代裸 URL，`JsJob` 携带两个内置键且**先于**变量表（ADR-0049 §决策 1/2）；阅读器 / 校验 / 目录都接线并有测试 |
| `downloadUrls` / `relatedBooks`；`isVolume` / `formatJs` / `preUpdateJs` | **均未做**：`isVolume` 一族已裁决本阶段不做（ADR-0041 §决策 6）；`downloadUrls` 属批量下载面、`relatedBooks` 无语料证据。触发 = 5.10 校验或入库工具普查出真实需求；未建模期间**不得**声称支持（清单归 `book-source.md` §2 注记） |
| `checkKeyWord`（书源校验 / 调试的默认关键词） | ✅ **已闭环（5.10，2026-10-21）**：`SearchRule.checkKeyWord` 已建模，「像规则」判据 = `resolveCheckKeyword` / `looksLikeRule`（ADR-0043 §决策 2） |
| 并发上限接入用户设置时必须**显式校验 / 钳制 `> 0`**（今天只有 `assert`，release 会剥掉；`0` = 永久排队） | ✅ **已闭环（5.6，2026-10-21）**：`budgetOrDefault` 在 release 也生效（`<= 0` 回落默认 + warning），设置页的下限也是 1 |
| `httpClientProvider` 是 autoDispose，预算挂在实例上 ⇒ 跨操作会重建 | ✅ **已闭环（5.6）**：改 `keepAlive`，预算跨操作保持一份（批量下载因此不必另起机制） |
| `extra` 的导出合并（`toLegadoJson`） | 5.8（在那之前不得声称可无损导出） |
| 按书源清理缓存（给 `cache_entries` 加列 + 迁移） | **5.7 ②**（① 全量清空 ✅ 已随 5.6 落地；② 仍按真实需求排期） |
| Android **前台服务**（通知 + `startForeground`）：批量校验现在只有 `PARTIAL_WAKE_LOCK` | **未做（5.10 登记，ADR-0043 §决策 3）**：需要通知渠道 + `POST_NOTIFICATIONS` 运行时权限 + 服务生命周期三件原生接线。触发 = 真机上息屏后批量校验被系统杀掉 |
| 校验的**阶段开关与单源超时**目前是页面内状态（默认全开 + 180 s），不持久化 | **未排期（5.10 登记，ADR-0043 §后果）**：要落进 `AppSettings`（`shared_preferences`）就得跨 feature 取设置，触发 = 用户反馈每次都要重选 |
| 文件型数据库（后台 isolate + 原生库）无自动化覆盖 | **持续约定**：5.1 起每个新表都由 `integration_test/on_disk_database_test.dart` 真实写入一次（`books` / `reading_progress` 已随 5.4 补上） |
| **JSON 条目上裸 `@js:` 的 `result` 绑定**（本仓给 JSON 文本，上游给条目对象） | ✅ **已闭环（M12，2026-10-21）**：`_resultOf` 按 scope 分流，条目给对象、页面给正文（ADR-0047 §决策 4、`book-source.md` §6） |
| `header` 写成规则（`@js:` / `<js>`，真实语料 21 条）尚未求值 | ✅ **已闭环（M12，2026-10-21）**：原文进 `BookSource.headerRule`，`PageFetchService.headersOf` 在首个请求前求值（ADR-0047 §决策 5）；真实源证据见 `book-source.md` §10 |
| 默认 / `@@` 规则打在 JSON scope 上必然失败（上游按页面类型选分析器） | ✅ **取证后不改（M12，ADR-0047 §决策 6）**：上游 jayway JsonPath 同样要求 `$` 前缀，换分析器对能跑的规则无增益；登记为有意差异 |
| 页面字段规则的 `page` 绑定与「已取到的那一页」不一致（搜得 / 发现阶段不传 `page`） | ✅ **取证后不改（M12，ADR-0047 §决策 6）**：字段规则本身不消费 `page`（只有 URL 模板与 `@js:` 绑定消费），语料无反例 |
| `<js>…</js>` 分段链（矩阵 #31）与 `url,{…}` 后缀（§4.3） | ✅ **已闭环（M12，2026-10-21，ADR-0047 §决策 1/2）**：真实语料里各覆盖 50 条源；列表规则上的 `@js:` 与 JSON 条目 `result` 一并落地 |
| 统一「单源预算」（超时 / 重试）抽成公共件 | ✅ **已闭环（M12，2026-10-21）**：`domain/source_budget.dart` 是「一个源一份预算」的唯一实现，聚合搜索 60 s / 校验 180 s 都改用它（ADR-0049 §决策 3）；单章正文仍靠 `HttpPolicy` 的逐请求超时 |
| `webView` / `webJs` / `retry` 等 URL 选项字段 | **未做（M12 登记，ADR-0047 §决策 1）**：无浏览器 DOM，按名记 `unsupported` + warning（不静默丢弃） |
| `concurrentRate` 的真源只有 3 条且都跑不了原样链路 | 已登记（b2 用派生源 A/B 取证）；触发 = 其中任一条变得可跑 |
| 「关于」页入口（设置页的菜单行） | **5.9**：与法律声明页一起落地；一个打开空页的菜单行是死链（C-BAN-2），所以 5.6 没有加它 |
| Big5 / Big5-HKSCS 的解码 | ✅ **已闭环（M12，2026-10-21）**：`enough_convert`（MPL-2.0，白名单 + ADR-0048）的 `Big5Codec` 补解码；`book-source.md` §5.1 已更新 |
| Big5 的**检测**（`betto_charset_detector` 候选表里没有 Big5） | **未做（ADR-0048 §决策 3）**：只补解码不补检测，无声明页面仍按嗅探结果解。触发 = 语料出现「无声明 Big5 页面且整条源失败」的实例 |
| Big5-HKSCS 扩展区字符 | **部分支持（ADR-0048）**：扩展区解成 U+FFFD。触发 = 繁体语料反馈缺字 |
| `shift-jis` / `euc-jp` 严格解码抛 `RangeError`（`Error`，越出 `ParseResult` 契约） | **未做（ADR-0048 §决策 4）**：`enough_convert` 不含日文码表，加字节预校验层无收益可验（语料 0 条日文源）。触发 = 出现日文源 |
| 已登记为**有意差异 / 具名拒绝**的一族：`{{…}}` 在列表规则里的语义、模板 JS 返回列表取首值、发现页 `infoMap` 与排名模块、`java.timeFormatUTC`、HTML 实体反转义、同步 `http.*` 形态、列表规则上的 `@js:`、`parse.*` 嵌套与 `parse.getElements` 非 DOM、元素 scope 的 `result` 形态、矩阵 #7 多元素倒置 | **无待办**：行为与触发条件归 `book-source.md` §3 / §4.2 / §6 / §11 与 ADR-0029 / 0035 的注记，本表不再复述 |

---

## 4. 检查点门槛（Gate）

进下一阶段前必须全部满足，否则不进入：

| Gate | 条件 |
|---|---|
| **G1** | 覆盖率门禁全绿（阈值与「未测量源文件」判定见 `docs/dev/testing.md` §2）；`AGENTS.md` §4 的全部命令退出码均为 0 |
| **G2a** | 1 个**真实书源**的「搜索 → 详情 → 目录 → 正文」**离线回放**通过，且回放必须驱动**生产链路**（UseCase → `renderUrlTemplate` → `HttpClient` → `RuleEngine`）；**已达成**（ADR-0024） |
| **G2b / G3 / G4** | 真实站点链路、M0 与 M1 的矩阵状态列 —— **均已达成**（2026-10-12 / 2026-10-12 / 2026-10-14）。证据要求：每行给出「源名 + 字段 + 产出样本」，统计由**入库的工具**复算（`tool/spot_check`，§6 #13）；记录见 `tool/spot_check/README.md` §4 |
| **G5** | C-UI-9 可达；无 `TODO` 占位；无未使用代码 |
| **G7** | **阶段出口的设备级探针**：离开任一 Phase 前，`integration_test/` 的全部用例必须在 **Windows 与 Android 各实跑一次**且退出码 0；**切片级同样是双端各一次**（2026-10-13 起，ADR-0039；口径与降级路径归 `docs/dev/test-environment.md` §1）。Phase 1–4 出口均已实跑（`test-environment.md` §7） |
| **G6** | 发布前清单（§5）全过 |

> **Gate 归属：** G1–G4 属引擎阶段，达成后长期有效；**G5** 依赖 Phase 5 才存在的法律声明页，是 **Phase 5 出口**；
> **G6** 属 **Phase 6 出口**；**G7** 对**任何阶段出口**都适用。Phase 4 → Phase 5 的门槛 = G1–G4 + G7（已达成）。

---

## 5. 发布前清单（Phase 6）

逐项都已在其它文档定义，此处只做汇总与勾选：

| 项 | 出处 |
|---|---|
| `applicationId` 替换为真实包名 | `docs/dev/platform.md` §8.2 |
| 配置发布签名 | 同上 |
| 二进制产物再做一次许可证扫描 | `NOTICE.md` §4 |
| 依赖许可核实表清零「待核实」 | `NOTICE.md` §5 |
| 「关于 → 法律声明」页可用 | C-UI-9 |
| `LICENSE` 与官方文本一致 | `NOTICE.md` §1 |
| 三端平台验收清单 | `docs/dev/platform.md` §6 |
| `@js:` 探针纳入 CI（先建 Linux 产物） | ADR-0015 后果项、`tool/spike/README.md` §3 |

---

## 6. 常见返工陷阱（本项目已实际踩过）

| # | 陷阱 | 正确做法 |
|---|---|---|
| 1 | **把「构建成功」当成「功能可用」** | Dart 只编译**可达**的库。未被 import 的依赖不会被编译 → 构建成功是假信号。**必须写集成探针** |
| 2 | 给依赖源码打补丁来"修好"它 | 换引擎或指到正常构建产物（如 `FLUTTER_QJS_NEXT_LIBRARY`），不要维护本地补丁 |
| 3 | 把规则文本抄进第二份文档 | 只写引用（`见 constraints.md C-ERR-2`），否则必然漂移 |
| 4 | 先写 UI 再定模型 | 模型未定就写 UI，必然返工 |
| 5 | 先铺语法、后拼链路 | 接口形状未经验证，返工成本高一个数量级 |
| 6 | 靠"杀 Isolate"当唯一超时手段 | 引擎级超时优先，`Isolate.kill` 只作兜底（引擎行为可能随版本变化） |
| 7 | 新增 `lib/core/**` 文件却不带测试 | 覆盖率门禁的「未测量源文件」检查以退出码 3 失败（ADR-0019）；实现与测试同 PR |
| 8 | 手改生成文件 / 忘记重跑生成 | 只用 C-DEP-4 声明的生成命令（`--delete-conflicting-outputs` 已失效，见 ADR-0013 §6） |
| 9 | 同一数值写在两处（版本、阈值） | 单一来源原则；事实级归属见 `docs/README.md` §2.1 |
| 10 | 以为 spike 绿了就等于功能已测 | `tool/spike/` 是**架构可行性**验证，不是功能回归；功能测试必须进 `test/` |
| 11 | **并行写 ADR 时编号撞车** | 动手前先 `ls docs/dev/adr/`，并与对方分支核对编号；**同一决策只允许一份 ADR**（`docs/README.md` §5） |
| 12 | **把脱敏后的语料直接拿去跑真实站点** | 语料主机已改为保留域，复跑前显式还原；原主机与还原命令在 `test/fixtures/book_sources/README.md` |
| 13 | **用一次性脚本算统计数字**（未入库、判据与引擎不一致） | 统计必须由**入库的工具**复算，且判据与引擎一致（见 `tool/spot_check/README.md`） |
| 14 | **把活站点当天内容的哈希当成回归基线** | 哈希钉的是当天内容，站点改版后变化是事实而不是回归；回归基线必须是离线语料（C-NET-8） |
| 15 | **为「嗅探车道」写 `throwsFormatException` 用例** | 该车道的可达标签全是宽容编解码器或抛 `Error` 的族，进不了严格失败分支；可核验的形状是「精确标签 + 零替换」 |
| 16 | 临时 Dart 脚本留在仓内（连 `build/` 下也会被 `dart format .` / `flutter analyze` 算进去） | 收尾删掉，否则会污染格式与静态分析的计数与输出 |
| 17 | 在 Windows 上把临时文件写到 `/tmp`（`dart` / `node` 会解析成 `C:\tmp`） | 临时文件统一放 `build/`（已被 `.gitignore` 覆盖）或写全 Windows 路径 |

---

## 7. 每阶段结束时必须同步的文档

| 发生了什么 | 必须更新 |
|---|---|
| 新增/推翻了一个决策 | `docs/dev/adr/NNNN-*.md` + `docs/dev/adr/README.md` 索引 + 回链受影响的 `C-*` 条目 |
| 改了规范本身 | `docs/README.md` 索引与 §2.1 归属矩阵 + `AGENTS.md` §2 文档地图 |
| 依赖有变化 | `pubspec.yaml` + `docs/dev/tech-stack.md` + 重跑 `NOTICE.md` §6 的许可扫描 |
| 有用户可见的行为变化 | `CHANGELOG.md` |
| 书源语法的验证状态变化 | `docs/dev/book-source.md` §3 矩阵的「状态」列 |
| 平台基线/构建变通变化 | `docs/dev/platform.md` §1 / §8 |
| 阶段完成 / 遗留事项闭环 | 本文档 §3.1 状态表与 §3.7 登记表，以及根 `PLAN.md` 的里程碑 |

---

## 8. 快速索引

| 我要做… | 先读 |
|---|---|
| 加一个书源规则类型 | `book-source.md` §3 矩阵（确认分期）→ §4 语法 → §10 测试格式 |
| 加一个新页面 | `architecture.md` §1（放哪层）→ §6（路由）→ `constraints.md` §6（UI 约束） |
| 加一个 Provider / 状态 | `constraints.md` §2（C-STATE-*）→ `architecture.md` §4 |
| 加一个网络请求 | `constraints.md` §4（C-NET-*） |
| 加一个依赖 | `tech-stack.md` §13（流程）→ `NOTICE.md` §6（许可） |
| 定义一个新错误类型 | `architecture.md` §5（`ParseResult` 契约）→ ADR-0002 |
| 处理平台差异 | `constraints.md` §7（C-PLT-*）→ `platform.md` |
| 写测试 | `testing.md` §2–§5 → `constraints.md` §8（C-TEST-*） |
| 遇到 JS 规则相关问题 | ADR-0015 → `tool/spike/README.md` §4（已知坑） |
| 不确定某条规则 | `constraints.md` 对应 `C-*` 条目 |
