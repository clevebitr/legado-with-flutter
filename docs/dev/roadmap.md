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
| Phase 5 — 阅读体验 | 🚧 进行中：5.0 ✅、5.1 ✅、5.2 ✅、5.4 ✅、5.6 ✅、5.7 ① ✅、5.8 的文件选择半程 ✅、5.10 ✅；其余见 §3.6 |
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

#### 5.3 阅读器

- 翻页模式（滚动 / 分页先做一种，另一种登记去向）、字号 / 行距 / 背景（`shared_preferences`，C-NET-9）、
  章节切换、**阅读进度落盘**（新表：书 + 章节 + 偏移；建表走 `tech-stack.md` §8 的 dump / generate 与迁移测试）。
- 同时收 §3.7 的两条展示项：**`updateTime` 的展示**、**`canReName` 的消费方**（改名何时覆盖已有书名）。
- **验收**：字号 / 主题切换的 Widget 测试；进度写入 → 恢复的往返测试；`updateTime` 与 `canReName` 各有
  行为测试；Golden 基线按 `testing.md` §5 **单独 PR**。

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
> JS 变量表，属规则面改动，触发条件是真实语料出现该写法（§3.7）。

#### 5.5 书源展示与排序字段

- `lastUpdateTime` / `respondTime` / `weight` / `customOrder` 的展示与排序（5.1 已用其中两个做默认排序），
  以及**书源校验 / 调试入口**（`checkKeyWord` 一类未建模字段的处置一并收）。

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

### 3.7 未闭环交接登记（不得静默丢弃）

> 已闭环 / 已否决的登记项（并发上限 3、M1 #15–#19、规则变量不落盘、`ruleBookInfo.init` 未应用、b1b 首版
> 返工与真源回归、`{{…}}` 内 `##`、JSONPath `]name`、charset 结果缓存、`bookSourceType=4`、`java.*` 兼容面…）
> 已移出本表，过程记录见 `CHANGELOG.md`。下表只留仍未闭环的；**触发条件写在这里，行为面仍归
> `book-source.md` 的注记**。

| 事项 | 去向 / 触发条件 |
|---|---|
| `canReName` 的消费方（覆盖已有书名 / 作者） | 5.3（M1 只建模，*不求值*该规则） |
| `updateTime` 的展示（列表 / 详情 / 目录） | 5.3 |
| `java.get('bookName' / 'title')` 的上游特例（`AnalyzeRule.kt:812-821`） | **未做**（5.4 落地时未收）：要把 Book / Chapter 绑进 JS 变量表，属规则面改动；触发 = 真实语料出现该写法（普查命令见 `tool/spot_check/README.md` §3） |
| `downloadUrls` / `relatedBooks`；`isVolume` / `formatJs` / `preUpdateJs` | **均未做**：`isVolume` 一族已裁决本阶段不做（ADR-0041 §决策 6）；`downloadUrls` 属批量下载面、`relatedBooks` 无语料证据。触发 = 5.10 校验或入库工具普查出真实需求；未建模期间**不得**声称支持（清单归 `book-source.md` §2 注记） |
| `checkKeyWord`（书源校验 / 调试的默认关键词） | ✅ **已闭环（5.10，2026-10-21）**：`SearchRule.checkKeyWord` 已建模，「像规则」判据 = `resolveCheckKeyword` / `looksLikeRule`（ADR-0043 §决策 2） |
| 并发上限接入用户设置时必须**显式校验 / 钳制 `> 0`**（今天只有 `assert`，release 会剥掉；`0` = 永久排队） | ✅ **已闭环（5.6，2026-10-21）**：`budgetOrDefault` 在 release 也生效（`<= 0` 回落默认 + warning），设置页的下限也是 1 |
| `httpClientProvider` 是 autoDispose，预算挂在实例上 ⇒ 跨操作会重建 | ✅ **已闭环（5.6）**：改 `keepAlive`，预算跨操作保持一份（批量下载因此不必另起机制） |
| `extra` 的导出合并（`toLegadoJson`） | 5.8（在那之前不得声称可无损导出） |
| 按书源清理缓存（给 `cache_entries` 加列 + 迁移） | **5.7 ②**（① 全量清空 ✅ 已随 5.6 落地；② 仍按真实需求排期） |
| Android **前台服务**（通知 + `startForeground`）：批量校验现在只有 `PARTIAL_WAKE_LOCK` | **未做（5.10 登记，ADR-0043 §决策 3）**：需要通知渠道 + `POST_NOTIFICATIONS` 运行时权限 + 服务生命周期三件原生接线。触发 = 真机上息屏后批量校验被系统杀掉 |
| 校验的**阶段开关与单源超时**目前是页面内状态（默认全开 + 180 s），不持久化 | **未排期（5.10 登记，ADR-0043 §后果）**：要落进 `AppSettings`（`shared_preferences`）就得跨 feature 取设置，触发 = 用户反馈每次都要重选 |
| 文件型数据库（后台 isolate + 原生库）无自动化覆盖 | **持续约定**：5.1 起每个新表都由 `integration_test/on_disk_database_test.dart` 真实写入一次（`books` / `reading_progress` 已随 5.4 补上） |
| **JSON 条目上裸 `@js:` 的 `result` 绑定**（本仓给 JSON 文本，上游给条目对象） | b7：① 取证 ✅（85 条源 / 98 个字段）；② 是否按新 ADR 改 `book-source.md` §6 契约**待裁决** |
| `header` 写成规则（`@js:` / `<js>`，真实语料 21 条）尚未求值 | 未排期；当前导入降级为无 header + warning（ADR-0040 §决策 6）；触发 = 这批源在真机因缺 header 普遍失败 |
| 默认 / `@@` 规则打在 JSON scope 上必然失败（上游按页面类型选分析器） | **先取证、不立单**：① 核上游在「JSON 内容 + `@@`」下的分析器选择；② 真实语料的可用实例。在此之前不改语义 |
| 页面字段规则的 `page` 绑定与「已取到的那一页」不一致（搜得 / 发现阶段不传 `page`） | 待语料裁定（把 `page` 传下去 vs 像上游只在 URL 规则绑）；数值语义归 `book-source.md` §6 |
| `concurrentRate` 的真源只有 3 条且都跑不了原样链路 | 已登记（b2 用派生源 A/B 取证）；触发 = 其中任一条变得可跑 |
| 「关于」页入口（设置页的菜单行） | **5.9**：与法律声明页一起落地；一个打开空页的菜单行是死链（C-BAN-2），所以 5.6 没有加它 |
| Big5 / Big5-HKSCS 既不能检测也不能解码；`shift-jis` / `euc-jp` 严格解码抛 `RangeError`（`Error`，越出 `ParseResult` 契约） | 待排期：需换依赖或加隔离层（ADR-0022 不得捕获 `Error`）；证据归 `book-source.md` §5.1 |
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
