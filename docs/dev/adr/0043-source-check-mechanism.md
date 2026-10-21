# ADR-0043 书源测试机制：校验结果写回书源、`checkKeyWord` 建模、长任务端口与失败语义

- **状态：** Accepted（2026-10-21，M10 规格前置，用户裁决四项）
- **日期：** 2026-10-21
- **关联：** C-ARCH-2、C-ERR-1、C-ERR-7、C-PLT-1、C-UI-5、C-NET-9、ADR-0002、ADR-0019、ADR-0025、
  ADR-0039、ADR-0041、`docs/dev/roadmap.md` §5.10、`docs/dev/book-source.md` §2、`docs/dev/platform.md` §2

## 背景

`docs/dev/roadmap.md` §5.10 把上游（`F:\Projetcs\legado-upstream`）的「书源测试」拆成两半：
**批量校验**（`BookSourceCheckRepository` + `BookSourceCheckGateway` + `BookSourceCheckService`）与
**单源调试**（`ui/book/source/debug/*`）。两个机制的行为要点已写进 §5.10，但开工前必须定死四件事，
否则实现会分叉。本 ADR 就是这四件事的裁决。

## 决策

### 决策 1 校验结果写回 `book_sources`，并新增 `comment` 列

- `groupName`（`bookSourceGroup` 的投影）承载「失效」分组，`respondTime` 承载本次耗时，
  **新增 `comment` 列**承载 `bookSourceComment` 的错误注释；`payload` 列**不动**。
- 迁移：`schemaVersion 3 → 4`，`addColumn`；按 `docs/dev/tech-stack.md` §8 重跑 dump / generate，
  `drift_schemas/drift_schema_v4.json` 与 `test/core/storage/generated_migrations/` 一并提交；
  `on_disk_database_test` 里补一次真实写入（`docs/dev/roadmap.md` §3.7 的持续约定）。
- **为什么 `payload` 不动：** 它是 5.8 的导出源，唯一逐字节保存未知键的地方（ADR-0040 §决策 4）。
  把校验结果合并回 payload 会让「导出保真」和「用户态」两件事互相污染，而「失效分组 / 注释」恰恰是
  用户态（重新校验要能清掉）。这也和 `isEnabled` / `customOrder` 的处理一致：投影列归用户态，
  payload 归导入。

### 决策 2 `checkKeyWord` 建模进 `SearchRule`，「像规则就跳过」用显式判据

- `SearchRule` 增 `checkKeyWord`（`String?`）。`ExploreRule` **不加**：上游只把它声明在搜索规则上
  （`SearchRule.kt:14`），而 `book-source.md` §2 的「同形」约束只覆盖 `BookListRule` 的九个列表字段。
- 判据（本仓规格，上游那四个 `contains` 只是**行为依据**）：`resolveCheckKeyword` 先 trim，
  空则回落；再判「像规则」——满足任一条即回落：
  1. 含 `http`（大小写不敏感）或 `://`；
  2. 含 `::` / `++` / `--` / `##`（规则头与替换规则的分隔符）；
  3. 以 `@`、`$`、`@@`、`{{` 开头。
- 回落值是 `SourceCheckSettings.keyword`，默认取**数据常量** `defaultCheckKeyword`（「我的」，与上游
  `keyword.ifBlank { "我的" }` 同值）。它**不进 ARB**：ARB 管 UI 文案，而默认关键词是**发给站点的请求数据**，
  随 UI 语言变化会让英文界面把英文词搜进中文站。
- 这条同时关闭 `docs/dev/roadmap.md` §3.7 的 `checkKeyWord` 登记项。

### 决策 3 长任务抽象为 `core/platform/` 的 `LongRunningTask` 端口

- 接口：`Future<void> acquire()` / `Future<void> release()` / `bool get isSupported`，
  **不抛异常**：不支持的平台返回 no-op（`platform.md` §2 的既有契约）。
- Android 实现 `MethodChannelLongRunningTask`：`MethodChannel('flutter_reader/long_running_task')`，
  原生侧（`MainActivity`）申请 `PARTIAL_WAKE_LOCK`（`WAKE_LOCK` 权限，tag 固定），release 时释放；
  重复 acquire / 重复 release 都是幂等的。
- Windows / iOS：`UnsupportedLongRunningTask`（no-op，`isSupported == false`）。
- **前台服务（notification + `startForeground`）本阶段不做**，登记为未闭环：触发条件 = 真机上
  「息屏后批量校验被系统杀掉」。理由：前台服务需要通知渠道、`POST_NOTIFICATIONS` 运行时权限与
  服务生命周期三件原生接线，收益只在「长时间 + 息屏」，而本里程碑先把抽象、选择与探针立起来。

### 决策 4 失败语义不另起一套，`ParseFailureKind` 不改

- 逐源结果仍是 `ParseResult<SourceCheckReport>`：**失败分支**只用于「这次校验根本没法开始」
  （`invalidBookSource`，例如选中了搜索阶段但书源没有 `searchUrl`，同时也没有可校验的发现页），
  阶段失败属于报告内容。
- 阶段失败是 `SourceCheckStageOutcome`（feature 内枚举 `SourceCheckStage` + `SourceCheckStatus` +
  报告自带的 `ParseFailureKind` / `rulePath`），**不新增 `ParseFailureKind`**：core 契约的 9 个 kind
  已经能表达「超时 / 网络 / 解析 / 不支持 / 取消 / 无效书源」，剩下的信息是**归类**而不是**新失败类型**。
- 「JS 失效」靠 `book-source.md` §6 的既有约定判定：`ParseFailure.rulePath` 以 `:js:error` /
  `:js:timeout` 结尾（`js_bridge.dart` 的契约）。归类函数只有一处（`classifyCheckFailure`），
  其余位置不得再嗅探 `rulePath`。
- 分组归类（写回 `groupName`）与上游同名同义：`搜索失效` / `发现失效` / `搜索目录失效` /
  `搜索正文失效` / `发现目录失效` / `发现正文失效` / `搜索链接规则为空` / `发现规则为空` /
  `校验超时` / `js失效` / `网站失效`。这些字符串是**写回书源的数据**（与 `bookSourceGroup` 同性质），
  不是 UI 文案，因此以常量住在 `domain/source_check_group.dart`，不进 ARB。

## 后果

- 书源列表页多两个入口：批量校验页与单源调试页；两者的路由类型仍是 `book_source` 的
  （`architecture.md` §6 的页面表已登记）。
- 校验会**改写**书源的分组与注释：每次校验前先清掉上次的「失效」分组与 `// Error:` 注释
  （上游 `removeInvalidGroups` / `removeErrorComment` 的等价行为），所以重复校验不会累积分组。
- 被取消的运行必须是 `Cancelled`（上游 `Incomplete` 口径的反面）：已取消的源**不写回**，
  未开始的源标 `Cancelled`，整批不报 `Failed`。因此上游的 `Incomplete` 在本仓**没有落点**
  （`SourceCheckFailure` 只有 `checkFailed` / `sourceMissing` / `saveFailed` 三个值）。
- 「单源超时」的实现是**放弃等待**而不是中断：HTTP 层没有取消原语，`.timeout` 只是不再等，
  底层请求仍按自己的策略超时结束。因此超时后紧接着的下一源会与残留请求并行，这一点在
  `SourceCheckSettings` 的注释里写明，并由并发上限兜住。
- `data/` 层从本里程碑起进入覆盖率统计（阈值见 `docs/dev/testing.md` §2），`BookSourceRepositoryImpl`
  与新增的写回路径必须自带测试。
- 未闭环登记（写入 `docs/dev/roadmap.md` §3.7）：Android 前台服务；校验阶段开关与超时的**持久化**
  （本阶段是页面内状态，默认全开 + 180 s）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 校验结果只留内存报告 | 验收要求「分组 / 注释 / `respondTime` 的写入各 ≥1 条单测」，且上游行为就是写回；用户重新打开列表时看不到任何结论 |
| 新建 `source_checks` 表存历史 | 可查历史是好事，但要自带保留期与清理策略，本里程碑的工作量翻倍；写回投影列已经能满足「重新校验先清掉」的要求 |
| 把校验结果合并回 `payload` | 破坏 5.8 的无损导出（ADR-0040 §决策 4），且用户态与导入内容混在一列 |
| 不建模 `checkKeyWord`（继续留在 `extra`） | 校验 / 调试就没有默认词来源，§3.7 的登记项永远挂账；「像规则就跳过」也就无处可判 |
| 新增 `ParseFailureKind.jsFailed` / `tocEmpty` / `contentEmpty` | 属于跨层契约变更（`architecture.md` §5 + 新 ADR + 全部 ARB + core 100% 覆盖），而信息量并不增加：`rulePath` 已经能定位，阶段本来就知道 |
| 引入 `wakelock_plus` 换掉原生接线 | 一个只为一处使用的依赖要走 C-DEP-1 评审、NOTICE 许可核对与新 ADR；原生侧只有 20 行 |
| 逐源结果用裸 `Future`/异常表示失败 | 违 C-ERR-1；UI 需要 `switch` 穷尽，`ParseResult` 正好提供 |
