# PLAN.md — 核心功能实现流程

> 本文档是**实现顺序、验收标准与检查点**的唯一来源。
>
> - **功能范围**（做到哪、分期如何）由 `docs/dev/adr/0014-book-source-minimal-scope.md`
>   与 `docs/dev/book-source.md` §3.1 决定。
> - **怎么写**（命名、分层、约束）由 `docs/dev/naming.md` 与 `docs/dev/constraints.md` 决定。
> - 本文档**不复述任何规则**，只回答：先做什么、每步怎么验收、什么时候可以进下一步。
>
> 需要规则细节时，按本文档给出的 `C-*` ID 或文档路径去查，不要在此处寻章摘句。

---

## 0. 起点状态（2026-10-10）

| 已完成 | 尚未开始 |
|---|---|
| Flutter 3.47.7 工具链、Android/Windows 双目标可构建 | `lib/` 下的业务代码（目前只有 `main.dart` / `app.dart` / `core/theme/`） |
| 规范体系（103 条约束 ID）、15 条 ADR | 书源解析引擎 |
| 门禁全链路 + GitHub CI（全绿） | 阅读器、书架、设置等任何 UI |
| 引擎选型（ADR-0015，已实测） | 持久化（Drift 表尚未定义） |

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
Phase 0  环境与规范                      ✅ 已完成
   │
Phase 1  core 基础设施                    ← 从这里开始
   │     ParseResult → logging → platform → network → storage
   │
Phase 2  书源引擎【竖切】                  1 个书源 + 默认 CSS 规则，全链路打通
   │     模型 → RuleEngine(最小) → UseCase → 最小 UI
   │
Phase 3  M0 横向铺开                     矩阵 #1–#14（含 @js: 与 JsBridge）
   │
Phase 4  M1                              矩阵 #15–#19 + 发现页等
   │
Phase 5  阅读体验                        阅读器、书架、缓存、设置、法律声明页
   │
Phase 6  发布前                           清单见 §5
```

依赖关系（不可颠倒）：

```
ParseResult ──► 所有层的返回类型
HttpClient ──► RuleEngine ──► UseCase ──► UI
JsBridge   ──► @js: 规则
Drift      ──► 书源仓库 ──► 缓存/进度
```

---

## 3. 各阶段：目标 / 交付物 / 验收

### Phase 1 — core 基础设施

| 步骤 | 交付物 | 依据 | 验收 |
|---|---|---|---|
| 1.1 | `lib/core/error/`：`parse_result.dart`（契约）+ `parse_failure_arb_key.dart`（ARB 键名规则）+ 单测 | ADR-0002 | `ParseFailureKind` 9 个值均有 ARB 文案键；`switch` 穷尽；core 覆盖率 100% |
| 1.2 | `lib/core/logging/`：Logger 门面 + Provider | ADR-0006、C-ERR-5 | 测试断言级别与脱敏（Cookie/Token/正文不入日志，C-SEC-4） |
| 1.3 | `lib/core/platform/`：`PlatformInfo` / `DynamicColorProvider` 抽象 + 各平台 fallback | C-PLT-1..4 | 把 `lib/app.dart` 里直接用 `DynamicColorBuilder` 的接线收敛到这里 |
| 1.4 | `lib/core/network/`：`HttpClient`、`CookieManager` | C-NET-1..5 | 替身可注入；超时/重试上限可配；编码走 `betto_charset_detector`（C-NET-3） |
| 1.5 | `lib/core/storage/`：Drift 库、TTL 表、DAO | ADR-0003、C-NET-6/9 | `build_runner` 真跑一次；迁移有测试 |

**本阶段禁止：** 写任何书源相关代码；写 UI 页面。

**完成判定：** `AGENTS.md` §4 的全部门禁（含覆盖率门禁）全绿，且 `lib/core/**` 覆盖率 100%。

---

### Phase 2 — 书源引擎【竖切】

**只挑 1 个真实书源，且该书的规则只用到默认 CSS 规则**（矩阵 #1/#2/#5/#8/#9）。
目标不是功能全，而是**把接口形状跑出来**。

| 步骤 | 交付物 | 依据 | 验收 |
|---|---|---|---|
| 2.1 | `BookSource` 及子规则模型（仅竖切所需字段） | C-SRC-7 | `freezed` + `json_serializable`；能用真实书源 JSON 反序列化 |
| 2.2 | `RuleEngine` 最小版：`类型.名称.位置`、`@` 提取段、`##` 替换 | `book-source.md` §3.3 | 每条已实现语法至少 1 条单测（矩阵 #1/#2/#5/#8/#9） |
| 2.3 | `renderUrlTemplate`：`{{key}}` / `{{page}}` | C-SRC-5 | 关键词只编码一次；未定义变量渲染为空串并有 warning |
| 2.4 | 4 个 UseCase：`SearchBooks` / `FetchBookInfo` / `FetchToc` / `FetchContent` | C-ARCH-4 | 失败路径返回 `ParseResult`，不得抛到 UI |
| 2.5 | 最小 UI：搜索框 → 结果列表 → 目录 → 正文（纯文本） | C-UI-1..9 | 文案来自 ARB；令牌来自 `context.m3e` |
| 2.6 | 离线语料：`test/fixtures/book_sources/*.json` + `test/fixtures/html/*.html` | `book-source.md` §10 | 测试**禁止真实联网**（C-NET-8） |
| 2.7 | `failureAt<T>` 封装：`rulePath` 非空断言 + 失败构造的唯一入口 | C-SRC-8、ADR-0002 | 空 `rulePath` 抛 `AssertionError`（1 条单测）；规则引擎所有失败路径均经此构造 |

**本阶段禁止：** 实现 `@js:`；实现翻页；做任何"以后会用到"的抽象。

**完成判定：** 1 个真实书源完成「搜索 → 详情 → 目录 → 正文」**离线回放**，
且手动跑通一次真实链路。

---

### Phase 3 — M0 横向铺开

把矩阵 #1–#14 补齐，其中 **#14 `@js:` 是重头**（ADR-0015 已验证的结论要落成代码）。

| 步骤 | 内容 | 验收 |
|---|---|---|
| 3.1 | 补齐默认规则语法：#3（`text` 类型）、#4（`children`）、#6（`!` 排除）、#7（首字符 `-` 倒置） | 每条 1 条单测 |
| 3.2 | `\|\|`（#10）、`&&`（#11）、`@css:`（#12）、`@json:`（#13） | 同上 |
| 3.3 | `JsBridge`：专用 Isolate + **复用运行时** + `timeout: 5000` + `memoryLimit: 32MB` + `Isolate.kill` 兜底 | ADR-0015、C-SRC-2；`sendMessage` 载荷必须是合法 JSON |
| 3.4 | `@js:` 规则接入（#14）+ JS 白名单绑定（`baseUrl`/`result`/`parse.*`/`http.*`/`log.*`） | `book-source.md` §6 白名单逐项有测试；越权访问被拒绝 |
| 3.5 | 目录翻页 `nextTocUrl`、正文分页 `nextContentUrl`、`isVip` 判定 | 各 1 条单测 |
| 3.6 | 失败语义全量：9 个 `ParseFailureKind` 各有触发路径 | 每个 kind ≥1 条单测 |
| 3.7 | **真实书源验证记录** | 按 `book-source.md` §10 格式写入 PR，并把矩阵状态列改为「已确认」 |

**完成判定：** 2 个真实书源完成全链路离线回放；矩阵 M0 行的状态列**全部为「已确认」**。

---

### Phase 4 — M1

矩阵 #15–#19 + `exploreUrl` 发现页 + `canReName` + `java.timeFormat` + `concurrentRate`。
每条语法同样需要真实书源验证记录。完成判定：M1 行状态列全部为「已确认」。

---

### Phase 5 — 阅读体验

阅读器（翻页、字号、进度）、书架、正文缓存、设置页、**「关于 → 法律声明」页（C-UI-9，GPL 要求）**。
完成判定：`C-UI-9` 页面存在且可达（widget 测试断言）。

---

## 4. 检查点门槛（Gate）

进下一阶段前必须**全部**满足，否则不进入：

| Gate | 条件 |
|---|---|
| **G1** | `lib/core/**` 覆盖率 100%；`AGENTS.md` §4 的全部命令退出码均为 0 |
| **G2** | 1 个书源全链路离线回放通过；手动真实链路跑通一次 |
| **G3** | 2 个书源全链路离线回放；矩阵 M0 状态列全部「已确认」；9 个失败 kind 均有测试 |
| **G4** | 矩阵 M1 状态列全部「已确认」 |
| **G5** | C-UI-9 可达；无 `TODO` 占位；无未使用代码 |
| **G6** | 发布前清单（§5）全过 |

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
| 8 | 手改生成文件 / 忘记重跑生成 | 只用 `dart run build_runner build`（C-DEP-4/5；`--delete-conflicting-outputs` 已失效，见 ADR-0013 §6） |
| 9 | 同一数值写在两处（版本、阈值） | 单一来源原则；本项目的"四处同步"清单见 `tech-stack.md` §1 |
| 10 | 以为 spike 绿了就等于功能已测 | `tool/spike/` 是**架构可行性**验证，不是功能回归；功能测试必须进 `test/` |

---

## 7. 每阶段结束时必须同步的文档

| 发生了什么 | 必须更新 |
|---|---|
| 新增/推翻了一个决策 | `docs/dev/adr/NNNN-*.md` + `docs/dev/adr/README.md` 索引 + 回链受影响的 `C-*` 条目 |
| 改了规范本身 | `docs/README.md` 索引 + `AGENTS.md` §2 文档地图 |
| 依赖有变化 | `pubspec.yaml` + `docs/dev/tech-stack.md` + 重跑 `NOTICE.md` §6 的许可扫描 |
| 有用户可见的行为变化 | `CHANGELOG.md` |
| 书源语法的验证状态变化 | `docs/dev/book-source.md` §3 矩阵的「状态」列 |
| 平台基线/构建变通变化 | `docs/dev/platform.md` §1 / §8 |

> 变更完成后跑一次文档一致性自检（`PLAN.md` 只约定"要自检"，自检项清单由
> `docs/README.md` §6 的单一来源规则决定）。

---

## 8. 快速索引：我要实现 X，该看哪里

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

---

**文档版本：** v1.0 · **最后更新：** 2026-10-11
