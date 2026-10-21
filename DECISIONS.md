# DECISIONS

> 决策与踩坑日志，只追加，不参与日常上下文。可用 grep 检索。条目按文件顺序编号（第一个 `##` 是 #1）。

## 2026-10-21 — PLAN.md 交给 plan 插件，人读路线迁到 docs/dev/roadmap.md

根 `PLAN.md` 交给 `plan` 插件（`pi-is-my-plan`）管理，人读的路线 / 验收 / Gate / 返工陷阱 / 快速索引整体搬到 `docs/dev/roadmap.md`（原名 PLAN.md，小节号未变）。

为什么这样分：插件只认自己的格式（`<!-- plan-bridge:state -->` + `## Milestones` + `## Current`），并且**拒绝覆盖外来 PLAN.md**；而 roadmap 里的 5.x 验收、G1–G7、17 条陷阱被 ~90 处引用（docs / ADR / tool / lib / test）。把两者塞进一个文件只能二选一丢东西，所以拆开：PLAN.md 只放里程碑级状态（进 system prompt 的那一小块），roadmap.md 承担「实现顺序 + 验收 + 门禁」。

踩坑（迁移时实测）：`git mv PLAN.md docs/dev/roadmap.md` 之后，工作区里的目标文件被写成插件自己的 16 行骨架，283 行正文只剩 git index 里的旧版。**下次迁移先 `cp` 一份到 `build/` 再删原文件**，不要依赖 mv 的落盘结果。

约定：
- 里程碑 = roadmap 的 5.x 步骤（M1–M9 ↔ 5.0–5.9），文本 ≤50 字符，详情留在 roadmap 与 ADR。
- ADR 与 CHANGELOG 里对 `PLAN.md §X` 的历史引用**不改**（决策记录不可变），由 roadmap 头部声明「等同本文件 §X」。
- `DECISIONS.md`（插件追加的 #N 短日志）定位是执行期踩坑，**不是** ADR 的替代：正式决策仍走 `docs/dev/adr/`。

## 2026-10-21 — 5.4 书架与 5.6 设置的落地取舍（身份、钳制、keepAlive）

5.4 书架与 5.6 设置落地（M5 / M7）。新增 `books` + `reading_progress`（schemaVersion 2 → 3，dump + 迁移测试 + on_disk 真实写入）、`BookshelfDao` / `BookshelfRepository` / 书架页 / 「加入书架」端口；新增 `AppSettings`（钳制在工厂里）+ `SettingsRepository`（shared_preferences）+ 设置页 + 主题/字号/并发上限接线 + 全量清空缓存。

三个判断值得记住：

1. **书架的身份是 `(sourceUrl, bookUrl)`，书源存 URL 而不是 `book_sources.id`**：`id` 属于一次导入的行，删掉再导入同一个源会换 id，而「这本书来自哪个源」不随行变。ADR-0041 §决策 4 写的是「书源 ID」，本实现按 URL 落地，同一 ADR 里阅读进度也照此办理。
2. **并发上限的校验放在 `core/di/http_client_provider.dart` 的 `budgetOrDefault`**，不是靠 `HttpPolicy` 的 `assert`（release 会剥掉）。设置侧另有一层钳制（1–8）在 `AppSettings` 的工厂里；两层都不依赖 assert，所以「`0` 让请求永久排队」这条登记项在 release 也关得住。
3. **`httpClientProvider` 改 `keepAlive`**：预算挂在 `DioHttpClient` 实例上，autoDispose 会让「批量下载共用一份预算」变成每批一份。代价是 Dio 实例随 App 存活（它本来就没有需要释放的资源）。

另有两处前端结构决定写进 ADR-0042：跨 feature 导航走 `AppNavigation` presentation 端口（由装配根绑定），`StateMessage` / `FailureMessage` 上移 `core/widgets/`。

`checkKeyWord` 的归属从 5.5 改到 5.10：它是校验/调试的输入，随机制一起建模才有判据可写。

## 2026-10-21 — M10 书源测试机制：上游两个机制与四处待裁决

上游 `legado-upstream` 的「书源测试」其实是两个机制，M10（roadmap §5.10）按两半写：

- **批量校验**：`BookSourceCheckRepository` + `BookSourceCheckGateway` + `BookSourceCheckService`。对选中的一批源按阶段（搜索 / 发现 / 详情 / 目录 / 正文，逐个可关）跑链路，失败写进 `bookSourceGroup` 的「搜索失效」「目录失效」… 分组、`bookSourceComment` 的错误注释，并记录 `respondTime`；状态机 `Pending/Running/Succeeded/Failed/Cancelled` + `CheckFailed/SourceMissing/SaveFailed/Incomplete`；并发 = 下载线程数，单源超时默认 180 s；Android 上是前台服务 + wake lock。
- **单源调试**：`ui/book/source/debug/*`。选一个源 + 目标（Search/Explore/Info/Toc/Content）+ 查询词跑一次，实时事件流（消息 / 来源 / 错误三类过滤、带耗时），示例入口一键填充。

四处必须先在 M10 的规格前置里定死，否则实现会分叉：① 校验结果落在哪（`groupName` 列 / 新表 / 只留内存报告）；② `checkKeyWord` 建模与「像规则就跳过」的判据；③ 长任务的平台抽象（前台服务 / wake lock 在 `platform.md` §2 的接口之外）；④ 逐源结果仍走 `ParseResult<SourceCheckReport>`，要加 `ParseFailureKind` 得先改 `architecture.md` §5 + ADR。

## 2026-10-21 — M10 书源测试机制落地：四处裁决 + 五个坑

M10（roadmap §5.10）落地：四项规格前置裁决 + 实现 + 双端实跑，官方决策记录是 ADR-0043。

四处裁决（用户逐条选定，均取推荐项）：
1. 校验结果写回 `book_sources` 并在 v4 加 `comment` 列（payload 不动，保 5.8 导出保真）。踩坑：drift 的 `createTable` 用的是**当前**表定义，所以 v4 的 `addColumn` 必须写在 `from >= 2` 的分支里，否则 v1 → 最新会撞 `duplicate column name: comment`（migration_test 的 v1→最新用例就是这条的回归点）。
2. `SearchRule.checkKeyWord` 建模 + 显式「像规则」判据（`looksLikeRule`：http/:// /:: /++ /-- /## /{{ 或 @/$ 开头）；回落词是**数据**不是 UI 文案，所以不进 ARB（英文界面不该把英文词搜进中文站）。
3. 新端口 `LongRunningTask`：Android 用 MethodChannel + `PARTIAL_WAKE_LOCK`（MainActivity.kt + WAKE_LOCK 权限，无新依赖），Windows/iOS no-op；前台服务登记为未闭环，触发=真机息屏被杀。
4. 不动 `ParseFailureKind`：阶段失败 = 报告内 `SourceCheckStageOutcome`；「JS 失效」靠既有的 `:js:error` / `:js:timeout` rulePath 标记，只在 `checkGroupForFailure` 一处读。

实现踩坑（值得记住的三条）：
- **空列表**：`PageFetchService.list` 把「一个都没命中」报成 `parseFailed`，而上游把同一件事叫「搜索失效」。所以归类必须先在 `checkGroupForFailure` 里把 `parseFailed` + `searchRule` / `exploreRule` 映射成 `搜索失效` / `发现失效`，否则一次空搜索会被写成「网站失效」。
- **一个阶段只留一条 outcome**：发现阶段要读「分类」再读「书单」，两次都记 outcome 会让 UI 里出现重复阶段；分类读取因此 `recordsSuccess: false`，失败才记。
- **不可达分支**：`ExploreCategory` 由解析器保证 URL 非空（§4.2 拒掉空 URL），所以「没有可打开分类」的兜底是死代码 —— 直接 `categories.first` 并注释依据，别为覆盖率留不可达分支。
- 协作式取消让上游的 `Incomplete` 没有落点，`SourceCheckFailure` 只有 checkFailed / sourceMissing / saveFailed 三个值。

验证：1003 用例、format 0、analyze 干净、core/domain/data 均 100%、生成物与源码同步；Windows 93 s 与 Android 188 s（含冷启动）设备级全过（核心是 `lib/core/platform/` 与 MainActivity 都改了，必须双端实跑）。五类失败的可复现记录见 `tool/spot_check/source_check_records.md`。

## 2026-10-21 — M4 阅读器落地：四处裁决 + 五个坑（drift createTable / build 内改 provider / freezed 单变体）

M4（roadmap §5.3 阅读器）落地：四处规格前置 + 两个机制，官方决策记录是 ADR-0044。

四处裁决（用户逐条选定，三项取推荐 + 翻页「两种都做」）：
1. 阅读器自有 字号/行距/背景/翻页方式 四轴，存 shared_preferences，与设置页的全局 textScale **叠乘**（不是共用一个旋钮：一个管无障碍缩放，一个管正文偏好）。
2. 进度端口从 ADR-0041 的 `ReadingProgressWriter` 扩成读写 `ReadingProgressStore` —— 恢复位置必须能读，否则进度语义会被推到路由参数里。
3. `books` 加 `tocUrl` 列（schema v5）：书架打开阅读器时直接用它，老行回落到 `bookUrl`。
4. 翻页两种都做：滚动 + 用 `TextPainter` 真实测量的分页；字符偏移是「比例 × 正文长度」的**估算**（已登记触发条件）。

踩坑（值得记住）：
- **drift 的 `createTable` 用当前表定义**：v5 的 `addColumn(books.tocUrl)` 必须写在 `from >= 3` 的分支里，否则 v1/v2 → 最新会 `duplicate column name`（与 M10 v4 同一个坑，第二次踩到说明这条要当成模板）。
- **`ref.read`/改 provider 不能在 build 里做**：`ReaderPage` 要在「路由指定了章节」时换章，直接调 `selectChapter` 会撞 “Tried to modify a provider while the widget tree was building”，改成 `addPostFrameCallback`。
- **freezed 的密封单变体 union 会生成 `ReaderRoute._()` 而 base 是 abstract**：编译报 “The class 'ReaderRoute' is abstract and can't be instantiated”。单变体的路由直接手写 `final class` 更省事（ADR-0011 只要求「类型化对象」）。
- **生成的 provider 名会吞掉 `Notifier` 后缀**（`ReaderSettingsNotifier` → `readerSettingsProvider`），且端口 provider 不要与 use case 生成的 accessor 同名（`chapterContentProvider` 撞过）。
- **跨 feature 打开阅读器走 `AppNavigation.openReader`**（ADR-0042 §决策 2 早就写明这个形态）：端口只收原语，装配根把它变成 reader 的 `ReaderBook`。
- 进度写回后由装配根的适配器 `invalidate` 书架：唯一同时认识两侧的地方顺手把「阅读到」刷新，阅读器不必知道书架页存在。

验证：1051 用例、format 0、analyze 干净、core/domain 100%、data 98.2%、生成物同步；Windows 92 s / Android 185 s 双端设备级全过（`integration_test` 改过 tocUrl 写入，必须双端）。
