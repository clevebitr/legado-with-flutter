# ADR-0040 Phase 5 的书源导入契约：身份、重复导入与体积边界

- **状态：** Accepted（2026-10-14 架构师裁决；开发组起草）
- **日期：** 2026-10-14
- **关联：** C-SEC-5、C-PERF-5、C-NET-8、C-DEP-6、C-ERR-7、C-UI-5、ADR-0003、ADR-0021、
  ADR-0022、`PLAN.md` §3.6（5.0 / 5.1）、`docs/dev/book-source.md` §2、
  `docs/dev/tech-stack.md` §8、`tool/spot_check/README.md` §3

## 背景

`PLAN.md` §3.6 的 5.0 要求在做 5.1（书源入口）之前先把四件事定死：**表的主键**、
**重复导入语义**、**批量文件的体积与读法**、**新依赖**。它们互相咬合：主键取决于「同一个源导入
两次」的期望，而「校验 + 限制体积 + 禁止一次性读入」是 C-SEC-5 的原文要求。

真实语料给出的形状（入库工具普查，`tool/spot_check/README.md` §3）：

| 事实 | 数值（2026-08-15 快照） |
|---|---|
| 条目 / 不同 `bookSourceUrl` | 3907 / 2596 |
| 同一 URL 出现多次 | 1217 个 URL（最多 3 条） |
| 其中**每条行为完全一致** | 1012 个 URL |
| 其中**至少一条行为不同** | 205 个 URL（例：起点中文 / 💰起点中文） |

上游把 `bookSourceUrl` 当主键、后导入覆盖前者。那会**静默丢掉** 205 个 URL 下的其余规则串；
反过来「URL 建唯一索引」又会让 1012 个等价条目在库里反复长出来（每次导入 +1 行）。

## 决策

1. **主键与唯一索引**：新表 `book_sources`（`lib/core/storage/book_sources.dart`）——
   `id INTEGER PRIMARY KEY AUTOINCREMENT` 是主键；`UNIQUE (url, fingerprint)`。
   `fingerprint` = 行为字段的**稳定序列化**（递归按键排序后 `jsonEncode`）的 sha256 十六进制
   （`crypto` 已是依赖，`core/logging/redaction.dart` 在用）。
2. **「行为字段」= 决定一份书源跑起来结果的那些字段**：`bookSourceName`、`searchUrl`、
   `header`、`ruleSearch`、`ruleBookInfo`、`ruleToc`、`ruleContent`、`ruleExplore`。
   **不含**用户态（`enabled` / `customOrder`）与展示用时间戳（`lastUpdateTime` / `respondTime` /
   `weight`）——它们由库里自己的列承担修复与排序，改它们不应产生新身份。
3. **重复导入语义**：
   - 同一 `(url, fingerprint)` 已存在 → **幂等**：不新增行、**不换 `id`**，用新的负载刷新
     `payload` 与 `updatedAt`；
   - 同 `url`、`fingerprint` 不同 → **新增一行**（多条共存）。**这是与上游的登记差异：**
     上游按 URL 覆盖，本仓保留全部变体，并在书源列表里逐条呈现；
   - **用户态不被导入覆盖**：`enabled` / `customOrder` 在既有行上只由 UI 写；导入新行时按负载
     初始化，导入既有行时**不动**这两列（否则用户启用的源会被一份旧导出重新禁用）。
   - **多条共存时「当前源」的解析顺序是契约的一部分**：启用位优先 → `customOrder` 升序 → `id` 升序。
     它是 5.1 里 `currentBookSource` 默认值的口径，也是列表的缺省排序；同 URL 的多条变体因此有确定
     的「谁是默认」，不依赖插入顺序。
4. **原始负载列 `payload TEXT NOT NULL`**：存导入时该条的 `jsonEncode(rawEntryMap)`——
   从**解析后的原始 Map** 编码，不经过 freezed 模型，因此未知键、`header` 的对象形态都原样保留
   （ADR-0021 §后果的 `toLegadoJson` 在 5.8 以它为导出源）。`url` / `name` / `group` /
   `sourceType` / `lastUpdateTime` / `respondTime` / `weight` 是**投影列**，只供列表与排序，
   与 `payload` 同批写入。
5. **单次导入的体积上限 = 32 MiB（33 554 432 字节）**，按 **UTF-8 字节数**计，在**解析之前**判定。
   **数值怎么来的：** 已知最大的真实合集是合集 C（3907 条 / **20.9 MB**，`tool/spot_check/README.md` §3），
   32 MiB 是它的约 **1.6 倍**——够装下同量级的合集，又不给「一次性 `jsonDecode`」留出无界的峰值内存
   （64 MiB 的文本在解析期会翻出几百 MB 的峰值，移动端低内存设备上不可控）。**上限只在这里定义一次**：
   - 文本粘贴：`utf8.encode(text).length`；
   - URL 导入：响应按块累加计数，**超过上限立即中止**（不把超大响应读完，C-PERF-5），
     复用 `core/network/HttpClient` 的请求路径；
   - 超限 → `ParseFailure(ParseFailureKind.invalidBookSource, rulePath: 'import.sizeLimit')`。
   **不另设条数上限**：字节上限已经把条数封顶，两个数值只会带来第二个漂移点。
6. **结构校验的分档**（`checked` 模式已在 ADR-0022 定死单条畸形 → 抛 `FormatException`）：
   - **整份文件级**：不是合法 JSON / 顶层既不是对象也不是数组 / 数组为空 →
     `invalidBookSource`，`rulePath` 分别为 `import.notJson` / `import.noEntries`；
   - **单条级**：缺必填（`bookSourceUrl`、`bookSourceName`）或结构畸形 →
     **跳过该条并计数**，其余照常导入；跳过数进入导入结果，UI 用汇总文案呈现（决策 8）。
     **每一条跳过都必须可定位**：日志给出**条目的下标 + `bookSourceUrl`（可能缺失时给名字）+ 失败字段路径**，
     但**不得**记录该条正文（C-ERR-8）；跳过是「显式失败 + 汇总」，不是静默丢弃（C-SRC-4 的同一原则）。
7. **不扩 `ParseFailureKind`**：超限与结构非法都复用 `invalidBookSource`。理由：那 9 个值是三层
   `switch` 的密封契约（`parse_result.dart` 的 `isRetryable`、`parse_failure_arb_key.dart`、
   UI 的键 → 文案映射都由「新增 kind 就编译失败」强制），而**用户看到的后果相同**——这份文件
   不是可用的书源文件。精确原因进 `rulePath`（`import.sizeLimit` / `import.notJson` /
   `import.noEntries`），只用于日志与排错（C-ERR-8）。
8. **用户可见文案（C-UI-5）**：失败复用既有 `failureInvalidBookSource`；新增两条**双语**汇总键：
   `bookSourceImportSucceeded`（`{count}`）与 `bookSourceImportPartiallySkipped`
   （`{count}`、`{skipped}`）。键与文案在本 ADR 定稿时同批落 ARB（`lib/l10n/app_en.arb` +
   `app_zh.arb`，英文带 `@description` 与 `placeholders`）。
9. **5.1 的导入入口形态 = 粘贴 JSON 文本 + 从 URL 拉取；5.1 不引入任何新依赖。**
   文件选择器与分享随 **5.8（导入 / 导出保真）** 一起裁决，届时把 `pubspec.yaml` +
   `tech-stack.md` §1 + `NOTICE.md` §5 **同批**更新（C-DEP-6 禁止只改一处）。
   - 理由一（代价）：文件选择器要引入原生插件（Windows / Android 各一套实现），会把 5.1 从
     纯 Dart 改动升级为原生工程改动，从而把 ADR-0039 的切片级双端实跑绑定到每一步；
   - 理由二（必要性）：5.1 的验收是「一个人点通闭环」，而 URL 导入正是本项目取语料的方式
     （合集 C 本身就是一条 URL，见 `tool/spot_check/README.md` §3 的命令）。
   - **登记（与本 ADR 之前的口头排期建议的差异）：** 2026-10-14 的排期建议写「只加
     `file_picker`」；本 ADR 改为「5.1 不加、5.8 一并裁决」。

## 后果

- `book_sources` 是新表 ⇒ `schemaVersion` 1 → 2，按 `tech-stack.md` §8 走
  `drift_dev schema dump` / `schema generate`、提交生成物并补迁移测试。
- 「多条同 URL 源共存」要求**默认源的选择有确定顺序**：启用位优先、其次 `customOrder`、
  最后 `id`（5.1 的 `currentBookSource` 默认值即此序；展示与排序字段在 5.5 补齐）。
- 导入是 `long` 操作但**不新增 isolate**：32 MiB 的 `jsonDecode` 一次同步调用在本机是
  百毫秒量级，按 C-PERF-4 的门槛（>16 ms 的纯计算）应放 `Isolate`/`compute`——**留给 5.1 实现时
  按实测决定**，本 ADR 只把上限钉死；若实测超阈，用 `compute` 而不是自建 isolate。
- 未闭环登记：文件选择 / 分享依赖 → `PLAN.md` §3.6 的 5.8；`toLegadoJson` 的 `extra` 回写
  → 同 5.8；`book_sources` 的文件型数据库真写入 → `integration_test/on_disk_database_test.dart`。
- 本 ADR 于 2026-10-14 被接受，5.1 的表定义与 `currentBookSource` 改动**随 5.1 落地**。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| `bookSourceUrl` 直接作主键（上游行为） | 205 个 URL 下行为不同的源只能留一条，静默丢用户数据 |
| URL 唯一索引 + 后导入覆盖 | 同前；覆盖还会换掉行的 `id`，让「当前选中源」等引用失效 |
| 合成 `id` 主键，但 URL 上只建**非唯一**索引 | 反复导入同一份合集会让 1012 个等价条目每次 +1 行，列表被重复项淹没 |
| 用整段「行为字段的规范 JSON」代替 sha256 作 `fingerprint` | 与 `payload` 几乎等长（一行里存两份规则），且长度不可预测；sha256 定长、可索引、可直接比较 |
| 扩 `ParseFailureKind`（`importTooLarge` 等） | 收益只是文案更精确，代价是改一个三层 `switch` 的密封契约 + ARB 键名规则 + 覆盖率门禁；真实需求出现前不做 |
| 现在就加 `file_picker` | 见决策 9 的两条理由；5.1 的验收不依赖它 |
| 不设体积上限，只按 C-SEC-5「禁止一次性读入」流式解析 | 流式 JSON 解析在纯 Dart 里要自建分词器（C-SEC-5 的「限制体积」本就要求一个数值）；先有上限，再有流式，是两步而不是一步 |
