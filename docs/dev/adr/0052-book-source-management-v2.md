# ADR-0052 书源管理二期：校验历史表与状态灯、探索开关、批量管理、导入预览、列表分组

- **状态：** Accepted（2026-10-22，用户裁决：三批里程碑「管理 → 漫画 → 音频」；状态灯走**新增
  `source_checks` 表**；管理面四项补齐全选）
- **日期：** 2026-10-22
- **关联：** C-PERF-6、C-BAN-2、C-UI-1、C-UI-5、C-UI-7、ADR-0019、ADR-0040、ADR-0043、ADR-0045、
  ADR-0050、`docs/dev/roadmap.md` §3.10（M15）、`docs/dev/book-source.md` §2

## 背景

M13 把书源管理从「只能导入 + 开关」补到「多选、批量启停/删除/分组、搜索、编辑、单条校验/导出」，
但对照 `F:\Projetcs\legado-upstream` 仍差四类东西：

1. **没有状态灯**。校验结论写在 `groupName` / `comment` / `respondTime` 三列里，列表行只显示文本，
   用户得逐条读注释才能判断「这个源还活着吗」。上游用一个彩色指示点 + 文本状态表达，本仓要补，
   而且用户点名要「上次校验时间」这类只有历史才有的信息。
2. **没有探索开关**。`enabledExplore` 是上游的用户态；本仓的 `exploreUrl` 只表示「能不能发现」，
   用户无法在不删除规则的前提下关掉某源的发现页。
3. **批量管理只有一半**。有批量启停/删除/加入分组，没有置顶/置底、没有分组重命名/删除/移出。
4. **导入没有预览**，且列表只有单一排序方向、没有按域名分组。

`BookSourceDao.writeCheckState` 是唯一的校验写回点，因此「历史」不能从列里补，必须新建表。

## 决策

### 决策 1 新增 `source_checks` 表，作为状态灯与历史的唯一来源（schema v5 → v6）

```text
source_checks(
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  source_id     INTEGER NOT NULL,      -- book_sources.id
  checked_at    DATETIME NOT NULL,     -- Clock.now()，不用 DB 时间
  status        TEXT NOT NULL,         -- succeeded / failed / cancelled
  invalid_groups TEXT,                 -- joinGroups(...)，可空
  error_comment TEXT,                  -- 本次的错误注释，可空
  elapsed_millis INTEGER NOT NULL
)
索引：(source_id, checked_at) —— 取「最近一条」与列表排序都走它（C-PERF-6）。
```

- **写：** `BookSourceRepository.applyCheckReport` 在**同一个事务**里写两处 —— 新表插一条历史，
  三列照旧写回。列写回不在本 ADR 的改动范围内（ADR-0043 §决策 1、ADR-0050 §决策 1 的契约不变，
  导出与上游互通依赖它）；新表只是把「这一次」也留成可查询的历史。两处写入同事务，
  所以「灯」和「分组」不会给出两个答案。
- **读：** 列表的灯、「上次校验」、按校验时间筛选/排序只读新表；`groupName` 轴仍按 ADR-0050 §决策 1
  读列。旧库（v5 及以前）没有历史 → 灯为灰，不做回填（回填只能从注释里猜时间，属于臆造）。
- **删除：** 删书源时在**同一事务**里删它的历史；`deleteAll` 一并清空。否则 id 复用（本仓用
  AUTOINCREMENT，不复用，但清理仍是义务）后会留下孤儿行。
- **保留上限：** 每源最多保留最近 20 条，插入后按 `checked_at` 裁剪（同事务）。历史是诊断信息，
  不是账本；不设上限会让一次批量校验永久占用磁盘。
- **取消不构成结论：** `cancelled` 记录会写入（便于排查），但状态灯取「最近一条非 `cancelled`」；
  只有取消记录的源等同于「从未校验」。

### 决策 2 状态灯四态，颜色与文案都来自令牌与 ARB

| 状态 | 判据（最近一条非 `cancelled` 记录） | 颜色令牌 | 语义标签 |
|---|---|---|---|
| 通过 | `status = succeeded` | `colors.primary` | `bookSourceCheckStatusPassed` |
| 失败 | `status = failed` 且失效分组不含超时/JS | `colors.error` | `bookSourceCheckStatusFailed` |
| 降级 | `status = failed` 且失效分组**只有** `校验超时` / `js失效` | `colors.tertiary` | `bookSourceCheckStatusDegraded` |
| 未校验 | 没有记录 | `colors.outline` | `bookSourceCheckStatusUnchecked` |

- 判据里的分组常量仍以 `source_check_group.dart` 为唯一出处；本 ADR 不复制清单。
- 指示灯是**装饰性**的：颜色不单独承载信息，`Semantics`/tooltip 必须给出上表的语义标签（C-UI-7）。
- 行内同时显示「上次校验 <相对时间> · <耗时> ms」；相对时间在 `presentation` 里由注入的时钟换算，
  不引入日期格式化依赖。

### 决策 3 探索开关是用户态列，写读都不碰 payload 的规则字段

- 新列 `is_explore_enabled`（v6，默认 `true`）。导入时按 payload 的 `enabledExplore` 初始化**新行**，
  之后只由用户操作改（与 `is_enabled` 同一口径，ADR-0040 §决策 3）。
- 消费方只有三处，避免「加了开关没人用」（C-BAN-2）：
  1. 发现页：当前源关了发现 → 空态说明「该源已关闭发现」，不发请求；
  2. 校验页：勾了「发现」阶段时，跳过探索开关为假的源；
  3. 列表：行内徽标 + 批量开关 + 筛选轴的一个可选维度（「仅看已开发现」）。
- **搜索不受影响**：`enabledExplore` 在上游也只管发现页。

### 决策 4 三个新的批量/管理动作都只写用户态，且各自一个事务

- **置顶 / 置底**：读默认序的 id 列表，移出选中项后前插/后插，复用 `BookSourceDao.reorder`
  的整表 `0..n-1` 重编号（ADR-0045 §决策 3）。不做相邻交换：同 `customOrder` 的交换没有确定结果。
- **分组重命名 / 删除 / 移出**：只改 payload 的 `bookSourceGroup`（与 `setGroupFor` 同一条路径），
  指纹不参与，身份因此不变（ADR-0050 §决策 3）。
- **排序方向**：`BookSourceListView` 增 `ascending`（默认 `true`）；DAO 的每个排序键都按它取方向。
  **默认序倒序 = 手动序反转**，此形态下禁用拖拽；正序才可拖。
- **按域名分组**：`BookSourceListView` 增 `groupByDomain`。它只影响渲染（按 `bookSourceUrl` 的 host
  分节），不改查询、不改拖拽语义；开启时禁用拖拽（跨节拖动没有定义）。

### 决策 5 导入拆成「预览」与「提交」两步

- `ImportBookSources` 新增 `preview(input)` → `ParseResult<BookSourceImportPreview>`；
  `commit(entries)` 只保存被勾选的**原始条目**。
- 预览条目携带：序号、名称、URL、用户分组、类型、`new` / `refresh`（按现有 `(url, 指纹)` 身份判断）
  与拒绝原因（复用现有 `_missingRequiredField` / `_sanitise` 的裁决）。
- `execute(input)` 保留为「preview 全选 + commit」的组合，既有调用方与测试不被迫改语义。
- 32 MiB 上限、单条跳过、`header` 降级三条规则**原样保留**，不因拆步骤而放宽（ADR-0040 §决策 5/6）。

## 影响

- `lib/core/storage/source_checks.dart`（新表定义，覆盖率豁免同 `book_sources.dart`）、
  `database.dart`（v6 + `onUpgrade` 建表）、`drift_schemas/drift_schema_v6.json`、迁移测试。
- `BookSourceDao`：`recordCheck`（插 + 裁剪）、`latestChecks`、`deleteChecksOf`、`moveToEdge`、
  `renameGroup` / `deleteGroup` / `removeFromGroups` 的 payload 重写辅助。
- `StoredBookSource` 增 `lastCheck`（可空投影）与 `isExploreEnabled`；`BookSourceListView` 增
  `ascending` / `groupByDomain`；`BookSourceSortOrder` 不变（方向是独立轴）。
- `presentation/pages/book_source_list_page.dart`：状态灯、探索徽标、批量置顶/置底/移出分组、
  分组管理对话框、方向切换、域名分节；`book_source_import_page.dart`：预览列表 + 逐条勾选。
- ARB 双语新增键：四个状态标签、上次校验行、探索开关/徽标、分组管理、预览各项。
- 测试：迁移（v5 → v6）、DAO（裁剪、级联、置顶/置底、分组重写）、状态灯四态 × 判据、
  预览 → 勾选 → 提交（含 refresh 身份）、方向与域名分组的 Widget 测试。

## 后果

- 好的方面：状态可一眼判断且有历史；探索开关有真实消费方；管理动作补齐上游的常用项；
  导入不再是「一按就落库」的黑盒。
- 代价：schema 多一张表、每源最多 20 条历史；列表行比以前多一行摘要（`isThreeLine` 的形态要复核）。
- 明确不做 / 未闭环：
  - 批量导出 / 分享（仍归 5.8）；
  - 定时校验 / 校验间隔（上游 `CheckSelectedInterval`）—— 需要后台调度，登记在
    `docs/dev/roadmap.md` §3.7；
  - 用历史做趋势图 / 统计 —— 历史是诊断用，不建聚合查询；
  - 回填 v5 及以前库的校验历史（不臆造时间）。
