# PLAN.md — 核心功能实现流程

> 本文档是**实现顺序、验收标准与检查点**的唯一来源。
>
> - **功能范围**（做到哪、分期如何）由 `docs/dev/adr/0014-book-source-minimal-scope.md`
>   与 `docs/dev/book-source.md` §3.1 决定。
> - **怎么写**（命名、分层、约束）由 `docs/dev/naming.md` 与 `docs/dev/constraints.md` 决定。
> - **过程记录**（每个切片做了什么、为什么）归 `CHANGELOG.md`；本文档不复述。
> - 需要规则细节时，按本文档给出的 `C-*` ID 或文档路径去查，不要在此处寻章摘句。

---

## 0. 起点状态（2026-10-10，已冻结，不再随进度更新）

| 已完成 | 尚未开始 |
|---|---|
| Flutter 3.47.7 工具链、Android/Windows 双目标可构建 | 书源解析引擎（Phase 2） |
| 规范体系（103 条约束 ID）、15 条 ADR | 阅读器、书架、设置等任何 UI（Phase 5） |
| 门禁全链路 + GitHub CI（全绿） | 业务数据表（书源、章节、阅读进度） |
| 引擎选型（ADR-0015，已实测） | 缓存、限速等运行时策略 |

> 当前进度以 §3.1 的阶段状态表为准。

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
Phase 1  core 基础设施                    ✅ 已完成
   │     ParseResult → logging → platform → network → storage
Phase 2  书源引擎【竖切】                  ✅ 已完成（G2a 达成；G2b 移至 3.2 之后）
   │     模型 → RuleEngine(最小) → UseCase → 最小 UI
Phase 3  M0 横向铺开                      ← 当前（3.1 已完成）
   │     矩阵 #1–#14（含 @js: 与 JsBridge）
Phase 4  M1                              矩阵 #15–#19 + 发现页等
Phase 5  阅读体验                        阅读器、书架、缓存、设置、法律声明页
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

### 3.1 阶段状态表

| 阶段 | 状态 | 证据 / 说明 |
|---|---|---|
| Phase 1 — core 基础设施 | ✅ 完成 | 六条门禁全绿（含覆盖率门禁，阈值与判定见 `docs/dev/testing.md` §2）。交付物见 3.2；过程记录见 `CHANGELOG.md` |
| Phase 2 — 书源引擎竖切 | ✅ 完成（2.1–2.7） | 四个 UseCase + `RuleEngine` + 最小 UI；G2a 达成（ADR-0024）。交付物见 3.3 |
| Phase 3 — M0 横向铺开 | ✅ 完成 | 3.1 默认规则语法、3.2（连接符 / `@css:` / `@json:` / `RuleScope` / ADR-0026 降级 / 3.6 九个 kind）、3.5（`nextTocUrl` / `nextContentUrl` / `isVip` / `replaceRegex`）、3.8（同一书源并发预算）、3.3（`JsBridge` 机制 + 同步绑定）、3.4（`@js:` 接入 + 全部 JS 绑定与额度）、**3.7（真实源回归 → 矩阵 M0 状态列全「已确认」，G3 达成）**已完成；真实站点 spot-check 已达（**G2b 达成，2026-10-12**，见 `tool/spot_check/`）；**3.9（charset 检测结果缓存）** 已完成，Phase 3 全部收口；下一步 = Phase 4（M1）。细节见 `CHANGELOG.md` |
| Phase 4 — M1 | ⏳ 进行中 | **语法先行（矩阵 #15–#19）已完成（2026-10-12）**；**规格前置已完成（2026-10-13）**：**ADR-0035**（发现页）、**ADR-0036**（`concurrentRate`）、**ADR-0037**（`java.*` 兼容面）。**b1 已完成（2026-10-13，含复核）**：四处 `updateTime` + `java.timeFormat`。**b2 已完成**：`concurrentRate` 与速率门/并发门合成。**b3 已完成**：`canReName`（不求值）+ `variableComment` 建模。**b4a 已完成**：发现页引擎（`exploreUrl` 两种形态 + 分类解析 + 整条回落 + `ExploreBooks`）。**b4b 已完成（2026-10-13，含架构师复核）**：发现页分类 UI（五个界面状态 + 分类行保留 + 重试 + 双语 ARB）。**b1b 已完成（2026-10-13，含架构师复核）**：`java.*` 兼容面 + 真源主流写法回归 + `--list` 普查修正。**下一步：b5（M1 真源缺口，见 §3.5/§3.7）与 Phase 4 出口**（出口含按 **ADR-0038** 的阶段级设备探针，Windows + Android 各一次） |
| Phase 5 — 阅读体验 | ⏳ 未开始 | — |
| Phase 6 — 发布前 | ⏳ 未开始 | 清单见 §5 |

> Phase 1 与 Phase 2 的详细完成记录（含每步产出、修订的 ADR、依赖变化）已归档到
> `CHANGELOG.md`；§3.7 只保留**仍未闭环**的交接事项。

### 3.2 Phase 1 — core 基础设施（已完成）

| 步骤 | 交付物 | 依据 | 验收 |
|---|---|---|---|
| 1.1 | `lib/core/error/`：`parse_result.dart`（契约）+ `parse_failure_arb_key.dart`（ARB 键名规则）+ 单测 | ADR-0002 | `ParseFailureKind` 9 个值均有 ARB 文案键；`switch` 穷尽；core 层通过覆盖率门禁（`docs/dev/testing.md` §2） |
| 1.2 | `lib/core/logging/`（Logger 门面，不依赖 Riverpod）+ `lib/core/di/logger_provider.dart`（Provider） | ADR-0006、C-ERR-5、`architecture.md` §1/§4 | 测试断言级别与脱敏（Cookie/Token/正文不入日志，C-SEC-4） |
| 1.3 | `lib/core/platform/`：`PlatformInfo` / `DynamicColorProvider` 抽象 + 各平台 fallback + `lib/core/di/platform_provider.dart`（Provider） | C-PLT-1..4、ADR-0020 | 动态取色接线收敛到 `core/platform/` |
| 1.4 | `lib/core/network/`：`HttpClient`、`CookieManager` | C-NET-1..5 | 替身可注入；超时/重试上限可配；编码走 `betto_charset_detector`（C-NET-3）；失败日志经 `describeError` 脱敏（C-SEC-4） |
| 1.5 | `lib/core/storage/`：Drift 库、TTL 表、DAO | ADR-0003、C-NET-6/9 | `build_runner` 真跑一次；迁移有测试 |

**本阶段禁止：** 写任何书源相关代码；写 UI 页面。

### 3.3 Phase 2 — 书源引擎【竖切】（已完成 2.1–2.7）

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
| 2.7 | `failureAt<T>` 封装：`rulePath` 非空断言 + 失败构造的唯一入口 | C-SRC-8、ADR-0002 | 空 `rulePath` 抛 `AssertionError`；引擎与四个 UseCase 的失败路径均经此构造 |

**本阶段禁止：** 实现 `@js:`；实现翻页；做任何"以后会用到"的抽象。

**出口条件：** G2a（已达成，ADR-0024）；2.5 已完成。G2b（手动真实链路）移至 3.2 之后。

### 3.4 Phase 3 — M0 横向铺开

把矩阵 #1–#14 补齐，其中 **#14 `@js:` 是重头**（ADR-0015 已验证的结论要落成代码）。

**执行顺序（架构师 2026-10-11 裁决；表内序号不代表先后，以本段为准）：**

1. **3.1** 默认规则语法（#3 / #4 / #6 / #7 / #26 / #28）—— ✅ 已完成。
2. **3.2 与 3.6 同批**：连接符与 `@css:` / `@json:`，并在同一次把 9 个 `ParseFailureKind` 的触发路径补齐。—— ✅ **已完成（2026-10-11）**，见本阶段步骤表后的状态说明。
3. **真实站点 spot-check**（插在 3.2 之后、3.3 之前；不占用步骤号）：取 1–2 个存活站点手跑
   搜索 → 目录 → 正文，确认 `@css:` 求值在本仓的 `cascadia` 语义下对真实 HTML 成立；站点、
   命令与结果写入 PR。**理由：** 在 JS 桥之上建之前，先把引擎对真实页面的正确性证掉。
   若站点页面**声明了编码但含非法字节**，按 ADR-0031 的声明车道宽容规则继续跑，并在记录里
   写明「该页含非法字节」（宽容是登记过的降级，不是「一切正常」）。
   —— ✅ **已完成（2026-10-12）**：`tool/spot_check/`（可复现 harness + 记录）。
   `biquge99.cc` 四段跑通（搜索 2 → 详情 → 目录 1310 → 正文 3031 字符，`sha256=6578ef3efc456856`；
   该书页正是上述「声明 UTF-8 但含 1 个非法字节」的页面，已记录在 `tool/spot_check/README.md` §4），
   同站派生 `@css:` 等价源得到**相同的计数与哈希**；由此产出 **ADR-0032**（未知类型 → CSS）
   与 **ADR-0031**（架构师裁决的已声明编码宽容解码），并修掉 `header` 字段未接线的 M0 缺陷。
4. **3.5** 在 3.6 之后：字段按「用到才建」分批补 —— 本阶段只补 M0 的 `isVip` / `nextTocUrl` /
   `nextContentUrl` / `replaceRegex`；`canReName` / `updateTime` 留 Phase 4。加字段会同时改动
   `book_source_test.dart` 里 `extra` 的期望清单，同批更新。
   —— ✅ **已完成（2026-10-12）**：四个字段已建模（`extra` 的期望清单同步改）；目录 / 正文翻页、
   `isVip` 判定与 `replaceRegex` 净化按 `book-source.md` §4.1 落地，§9 补「正文分页失败整章失败」一行。
5. **3.8** 在 3.5 之后：同书源并发上限 + 章节正文有限并发。
   —— ✅ **已完成（2026-10-12）**：预算落在请求层（`DioHttpClient` + `RequestLimiter`），默认 3
   且可配（`HttpPolicy.maxConcurrentRequestsPerSource`）、FIFO 排队不报 busy、异常也释放槽位；
   实现点与排队语义归 `book-source.md` §8，容量不进 `JsBridge` 契约（ADR-0030 §决策 2）。
6. **3.3 与 3.4**：`JsBridge` 与 `@js:` 接入 —— 白名单里的 `parse.getString(rule, doc)` 委托给
   规则引擎，所以必须等 3.2 / 3.5 的求值路径定型再冻结桥接契约。
   —— 3.3 ✅ **已完成（2026-10-12）**：`JsBridge` 契约（一个异步 `evaluate(JsJob)`，**无容量参数**）、
   常驻 worker isolate + 单复用运行时、FIFO 排队与硬预算 `Isolate.kill` 兜底、同步绑定
   `log.*` / `crypto.*`、真实引擎集成探针；已落的边界与 3.4 的清单归 `book-source.md` §6 的注记。
   —— 3.4 ✅ **已完成（2026-10-12，part 1/2/3）**：异步求值 API、值规则上的终段 `@js:` + 页级
   上下文、Promise 绑定 `http.*` / `parse.*`（含页级 scope 边界 `js:parse-scope`）与每规则调用
   额度（含 `log.*`）；新登记的边界见 §3.7。
7. **3.7** ✅ **已完成（2026-10-12）**：真实源回归 → 矩阵 M0 行的状态列全改「已确认」
   （19 行），四次活站点运行与逐行结论见 `tool/spot_check/README.md` §4b；入库了 `@js:` 语料
   （`legado_js_rules_source.json`）与语法覆盖派生源（`legado_g2b_syntax_rules_source.json`）；
   回归顺带修掉矩阵 #13 的两处保真缺口（JSONPath 命中列表时不展开），并把 `spot_check` 改回可运行。
8. **3.9** ✅ **已完成（2026-10-12）**：按「书源 ID + URL」缓存嗅探结果（键复用 `CacheDao`，
   不加列不建表），声明车道不进缓存；`CacheDao` 由此拿到第一个生产消费方。

| 步骤 | 内容 | 验收 |
|---|---|---|
| 3.1 | 补齐默认规则语法：#3 / #4 / #6 / #7 / #26 / #28 ✅ | 每条 1 条单测 |
| 3.2 | `\|\|`（#10）、`&&`（#11）、`@css:`（#12）、`@json:`（#13）、`@css:` 内的 jsoup 索引伪类（#29）；并落地 **ADR-0026** 的非顶层字段降级语义（顶层不降级） ✅ | 连接符分组与跨类型合并拒绝各 ≥1 条单测；降级语义顶层 / 非顶层各 ≥1 条单测 |
| 3.3 | `JsBridge`：专用 Isolate + 复用运行时 + 引擎级 `timeout` / `memoryLimit` + `Isolate.kill` 兜底 ✅ | 验收（依据：ADR-0015、**ADR-0029**（引擎 API 异步 + 逐绑定形态）、**ADR-0030**（单常驻 worker + FIFO，容量不进契约）、C-SRC-2）：`sendMessage` 载荷必须是合法 JSON；并发调用 FIFO 排队且**不得**报 busy（C-SRC-9）；一次超时/中断后同一运行时仍可继续求值（探针 07 口径）；单测走假 `JsBridge`（`testing.md` §4）；逐项绑定形态归 `book-source.md` §6。**冻结前置（架构师 2026-10-11 裁决）：必须在 G2b spot-check 与 3.5 / 3.8 之后**——3.5 的 `nextTocUrl` / `nextContentUrl` 允许 JS 返回 URL **数组**（`book-source.md` §4.1），先把「JS 返回单值 vs 列表」这一返回契约用真实字段行使定型再冻合同 |
| 3.4 | `@js:` 规则接入（#14）+ JS 白名单绑定 ✅ | `book-source.md` §6 白名单逐项有测试（含 Promise 形态的 `http.get` / `http.post` / `parse.getString` / `parse.getElements`）；越权访问被拒绝；单测走假 `JsBridge`（`testing.md` §4），真实引擎只在集成探针里（`integration_test/js_bridge_test.dart`，Windows 实测 16 项） |
| 3.5 | 目录翻页 `nextTocUrl`、正文分页 `nextContentUrl`、`isVip` 判定、`replaceRegex` 批量替换（含建模 `ContentRule.replaceRegex`） ✅ | 各 1 条单测 |
| 3.6 | 失败语义全量：9 个 `ParseFailureKind` 各有触发路径 | 每个 kind ≥1 条单测 |
| 3.7 | **真实书源验证记录** ✅ | 按 `book-source.md` §10 格式写入 PR（现落为 `tool/spot_check/README.md` §4b），矩阵 19 个 M0 行的状态列已全改「已确认」；`@js:` 语料入库（`legado_js_rules_source.json` + `maoer_search.json` / `maoer_toc.json`） |
| 3.8 | 同一书源并发上限（默认 3）+ 章节正文串行/有限并发 ✅ | 并发上限可配且有单测；超限请求排队而非并发发出；**并发预算只在此层实现，不改 `JsBridge` 契约**（ADR-0030 §决策 2） |
| 3.9 | charset 检测结果缓存：按「书源 ID + URL」维度缓存；复用 `CacheDao` 的稳定键与 TTL，**不加列、不新建表**（架构师裁决 F1） ✅ | 同 `(书源, URL)` 第二次编码检测**不再嗅探**，有单测（`CharsetCache` 命中即用缓存标签、声明仍优先）；本行同时让 `CacheDao` 拿到第一个生产消费方 |

**完成判定：** 2 个真实书源完成全链路离线回放；矩阵 M0 行的状态列**全部为「已确认」**。

> 3.1 的实现细节（校验与求值收敛为同一次解析、30 条新增单测等）见 `CHANGELOG.md`。
>
> **3.4 状态：✅ 已完成（2026-10-12，三个部分）。** part 1 = 引擎求值 API 转异步（ADR-0029
> §决策 1，破坏性变更记入 `CHANGELOG.md`）；part 2 = 值规则上的终段 `@js:` + 页级上下文
> （`baseUrl` / `page` / `source`）；part 3 = Promise 绑定 `http.get` / `http.post` /
> `parse.getString` / `parse.getElements`、`parse.*` 的页级 scope 边界、每规则调用额度（含
> `log.*` 计数）。`HttpClient` 为此补上了 `post`（C-NET-1 的唯一实现仍是请求层）。
> **未完成的收口（归 3.7）：** 矩阵 #14 的状态列仍为「待验证」——仓内 `@js:` 语料为 0，只能由
> 真实书源回归改（ADR-0024 §决策 2、ADR-0029 §后果）；列表规则上的 `@js:` 仍报
> `unsupported:@js:list`（新登记在 §3.7）。
>
> **3.2 状态：✅ 功能面已完成（2026-10-11）。** 交付：连接符 `\|\|` / `&&` / `%%`（含分组与
> 跨类型拒绝）、`@css:` 与 jsoup 索引伪类 #29、`@json:`（含裸 `$.` / `$[`）与 `RuleScope`
> （ADR-0028）、ADR-0026 非顶层字段降级（置空 + warning）、3.6 九个 `ParseFailureKind` 触发路径。
> `firstFailure` 因降级改动被删除；覆盖率门禁保持全绿（阈值与判定见 `docs/dev/testing.md` §2）。
> 验收清单逐项对照见 `CHANGELOG.md`。
> **未完成的收口：** 矩阵状态列未改（需 3.7 的真实回归）；G2b 真实站点 spot-check 待执行；
> JSON 语料的 URL 规则依赖 M1 的 #16–#19（见 §3.7 登记表）。

**本步产出 / 修订的 ADR：** 0026（非顶层字段两类均降级，复审修订）、**0028**（`RuleScope`
与 `@json:`；含复审对 §决策 2/3 的更正）。

### 3.5 Phase 4 — M1

> **状态（2026-10-13）：** 「语法先行」那半（矩阵 #15–#19 + 规则变量，ADR-0034）已合并；
> **规格前置**（M1-b0）也已完成：**ADR-0035**（发现页：`exploreUrl` 两种形态 + `ruleExplore` → `ruleSearch`
> 整条回落）与 **ADR-0036**（`concurrentRate` 语法/单位 + 「速率门 → 并发门」合成），
> `book-source.md` §2 / §4.2 / §6 / §8 / §9 / §11 已同步。剩下的按下面的 b1–b4 执行。

矩阵 #15–#19 + `exploreUrl` 发现页 + `canReName` + **`updateTime`（依赖 `java.timeFormat`）** +
`concurrentRate`。`isVip` **不在**本阶段（架构师裁决：归 M0 / Phase 3.5，见 ADR-0014 的修订注记）。
每条语法同样需要真实书源验证记录。
完成判定：M1 行状态列全部为「已确认」（ADR-0024 §决策 2：只能由**真实源回归**给出）。

| 步骤 | 内容 | 验收 |
|---|---|---|
| **b0** ✅ 已完成（2026-10-13） | **规格前置（架构师）**：ADR-0035 / ADR-0036；`book-source.md` §2（`ExploreRule` 行、四处 `updateTime`、`canReName` 不求值、`variableComment`、未建模字段去向）、新增 §4.2（发现页）、§6（`java.timeFormat` 入参/时区）、§8（`concurrentRate`）、§9、§11 | 开发组可**按规格直接实现**，不需要再猜；本节 b1–b4 的验收与本表一致 |
| **b1** ✅ 已完成（2026-10-13，含架构师复核） | `updateTime`（四处：`SearchRule` / `ExploreRule` / `BookInfoRule` / `TocRule`）+ 沙箱 `java.timeFormat`（worker 内同步、**不计**调用额度）；承载值的实体（`Book` / `BookInfo` / `Chapter`）补字段 | 六条门禁 ✅（599 用例、`core` 858/858、`domain` 1497/1497）；单测（时区 / 毫秒入参 / 小数截断 / 非法入参 → `js:error`）✅；设备探针**实跑**：Windows ✅ 21/21、**Android ✅ 21/21**（网络恢复后架构师复跑，`test-environment.md` §7）；**真实源记录**：派生源已把 `java.timeFormat` 的返回值坐实到 `Chapter.updateTime`（`tool/spot_check/README.md` §4）；语料主流写法依赖 `java.getString` → 归 **b1b** |
| **b1b** ✅ 已完成（2026-10-13，含架构师复核；首版曾退回返工） | **`java.*` 兼容面**（形态归 `book-source.md` §6、拒绝清单归 §11）：① 别名族 `md5Encode` / `base64Encode` / `base64Decode`（= `crypto.*`）、`encodeURI`（= Java `URLEncoder`，空格 → `+`）、`log`（= `log.info`），worker 内同步、不计额度；② 规则求值族 `getString` / `getStringList` / `getElement` / `getElements`＝**字面量快路径（引擎在交给 worker 前内联，同步语义）+ 异步兜底（Promise，绑定当前 scope）**，两者共用同一实现点；③ 列表返回 JS `Array` + `Array.prototype.toArray()` 垫片；④ 其余成员**具名拒绝**（抛错存根 / 抛错 Proxy，含 `Packages.*`；`get` / `put` 名字被变量读写占用，已在 ADR-0037 §决策 5 与 §11 写明） | 六条门禁 ✅（**合流后复核** 674 用例、`core` 943/943、`domain` 1708/1708 均 100%；`gen-l10n` 与生成物同步）；**同一 (规则, scope) 在快路径与异步路径上结果一致**的对照测试 ✅——首版两条不许的差异（`getElement` 单值/数组、`getString` 无匹配 `null`/`''`）已修，架构师复核又发现并修掉第三条（**JSON scope 下列表值被 `toString()` 成字符串**，见 `CHANGELOG.md` 的 b1b 复核条目）；每个成员 ≥1 条单测 ✅；`.toArray()` 垫片与具名拒绝各有测试 ✅；**`{{…}}` 模板里的主流写法**（`{{java.timeFormat(java.getString('$.x')*1000)}}`）另有单测 ✅（首版只测了 `@js:` 段）；**真实源回归** ✅：派生漫客栈真源（合集 C 第 1229 条，只改 `ruleToc.updateTime`）把 `start_time=1540458357` 经主流写法落到 `Chapter.updateTime = 2018/10/25 17:05`（算术已由架构师复算：UTC 09:05:57 → +08:00 17:05）；设备探针：**Windows ✅ `js_bridge` 24/24**（架构师独立复跑，含 `app_boot` 1/1 与 `on_disk_database` 1/1），**Android 归 Phase 4 出口按 ADR-0038 补跑**（本切片不再要求双端）；同批发现三条真源缺口（`{{}}` 内 `##`、JSONPath `]name` 方言、以及复核发现的 JSON 列表值串化——最后一条已在本切片修掉），前两条排为 **b5**（§3.5/§3.7） |
| **b2** ✅ 已完成（2026-10-13，含架构师复核） | `concurrentRate`：模型字段 + `RequestLimiter` 按 **ADR-0036** 落「先速率门、再并发门」；非法声明降级 + warning | 六条门禁 ✅（621 用例、`core` 920/920、`domain` 1503/1503）；`n/m` / 单数字 / `"0"` / 空 / 非法 / 两门各自与合成的单测 ✅；**语料取值分布与单位判断记录** ✅（3/3907 条声明、均为 1000–3000 单整数 → 毫秒口径成立，重开条件未满足）；**真实源回归** ✅（同源 A/B，架构师独立复跑：声明 `1500` → **4.6 s**、声明 `0` → **0.5 s**）；设备探针双端 ✅ 21/21 |
| **b3** ✅ 已完成（2026-10-13，含复核） | `canReName` + `variableComment` 建模（`canReName` 的规则**不求值**，见 §2 注记；消费方归 Phase 5） | 六条门禁 ✅（629 用例、`core` 920/920、`domain` 1506/1506）；模型往返（含 `extra` 不丢键）单测 ✅；谓词四种形状与接线各一条 ✅；设备探针 Windows ✅ 21/21 |
| **b4a** ✅ 已完成（2026-10-13，含复核） | 发现页引擎 / UseCase：`exploreUrl` 两种形态 + 分类解析 + `ExploreBooks`（含 **整条回落**）+ 条目 URL 走 `renderUrl` | 六条门禁 ✅（切片自测 653 用例 / `domain` 1657；**与 b3 合流后复核 661 用例 / `core` 920/920 / `domain` 1660/1660**）；ADR-0035 的四条登记差异各 ≥1 条单测 ✅（`<js>` 收尾 / 缺少 URL 拒条目 / 整字段 JS 的绑定与 `infoMap` 无容错 / 脚本失败 = `parseFailed`）；单分类失败态与空态 ✅；设备探针 **Windows ✅ 21/21、Android ✅ 21/21**（集成后复跑，`test-environment.md` §7）；**真实源回归留到 b1b 之后**（explore 源大量用 `java.getString`，见 §3.7） |
| **b4b** ✅ 已完成（2026-10-13，含架构师复核） | 发现页分类 UI（`presentation` + ARB 双语） | 六条门禁 ✅（666 用例；`core` 919/919、`domain` 1660/1660 均 100%；`flutter gen-l10n` 产物与提交一致、`build_runner` 0 输出）；Widget 测试 5 条（无书源 / 无分类空态 / 分类列表 / **分类内无可用书目** / 单分类失败保留分类行 + 重试）✅；复核改了两处：分类空态原先复用搜索空态文案（会说「没有匹配该关键词的书」，而发现页没有关键词）→ 新增 `bookSourceExploreEmptyCategory` 双语键 + 对应用例，`switch` 里不可达的 `ExploreCategories()` 分支清理；`tool/spot_check` 的「非搜索字段 URL 里的 `{…}`」判据项 **2026-10-13 裁决：不收紧、只改措辞**（理由与口径归 `tool/spot_check/README.md` §3/§6、§3.7） |
| **b5**（新，2026-10-13 架构师排期；触发条件已发生） | **M1 真源缺口修复**——两条都与 `java.*` 无关，但都由 b1b 的真源回归带出：① **`{{…}}` 模板内部的 `##`** 被 `_expandRule` 当成规则分界，模板因此被判不平衡 → 该字段 `parseFailed`（矩阵 #18 × #9 交叉；腾讯搜索系两活源的 `ruleBookInfo.kind` 第一条模板就是它）。修法：切 `##` 时跳过 `{{…}}` 内部（复用 `_templateEnd` 同一套引号 / 嵌套计数）。② **JSONPath 方言 `]` 后直接跟成员名**（`$.data.page[*]image` / `$.a[0]b`）被 RFC 9535 解析器拒，而 Legado 接受。修法：把 `]` 后紧跟标识符归一成 `].` 再交给解析器 | 六条门禁；两条各 ≥1 条单测 + 边界用例（`{{a##b##c}}`、`]` 后接 `.` / `[` / 空白 / 字符串模板，`$[0]b`）；Windows 设备级实跑（Android 归 Phase 4 出口，ADR-0038）；用腾讯搜索系真源或派生源复跑一次，确认两条都通（`java.getStringList` 的**成功路径**也要在真源上见到——b1b 只在离线语料与探针里验过） |

> **并行度：** b1 / b2 / b3 互不冲突（分别落在沙箱 + 模型、请求层 + §8 模型、详情页模型），
> 可并行；**b4a 依赖 b1**（`ExploreRule` 自带 `updateTime`）与 b0（规格），b4b 跟 b4a。

### 3.6 Phase 5 — 阅读体验

阅读器（翻页、字号、进度）、书架、正文缓存、设置页、**「关于 → 法律声明」页（C-UI-9，GPL 要求）**。

平台体验：`platform.md` §2 中其余三个接口在本阶段落地（不另设阶段）。

| 步骤 | 内容 | 验收 |
|---|---|---|
| 5.1 | 预测性返回接线：`PredictiveBackSupport` → `PageTransitionsTheme` + `AndroidManifest.xml` 的 `enableOnBackInvokedCallback`（C-UI-4、C-PLT-2） | Android 13+ 侧滑返回出现预览动画 |
| 5.2 | `SystemUiController`：状态栏透明与 edge-to-edge 适配 | edge-to-edge 下内容不被遮挡 |
| 5.3 | `HapticsController`：触感反馈能力探测与降级 | 不支持的平台 no-op 且不抛异常 |
| 5.4 | 书源展示与排序字段建模：`lastUpdateTime` / `respondTime` / `weight` / `customOrder` | 书源列表按 `weight` / `customOrder` 排序，`respondTime` 参与展示；四个字段有排序 / 展示单测 |
| 5.5 | 缓存清理（架构师裁决 F2；**只登记归属与成本分档**）：**① 全量清空缓存** —— 现有三列已够 `DELETE`，零 schema 变更（建议先做）；**② 按书源清理** —— 需给 `cache_entries` 加 `sourceId` 列 → `drift_dev schema dump` → 补迁移测试（`tech-stack.md` §8），成本更高，作为有真实需求时的后续项 | 缓存可被用户清空；若实现「按书源清理」，`DELETE WHERE sourceId = ?` 生效且有迁移测试 |

完成判定：`C-UI-9` 页面存在且可达（widget 测试断言）；三端平台验收清单（`platform.md` §6）逐项通过。

### 3.7 未闭环交接登记（不得静默丢弃）

| 事项 | 去向 |
|---|---|
| 同一书源并发上限 3 + 章节正文有限并发 | ✅ **已闭环（3.8，2026-10-12）**：请求层唯一实现点 `DioHttpClient` + `RequestLimiter`（键 = 书源，无书源时按主机；默认 3 可配、FIFO 排队不报 busy、异常也释放槽位）；语义归 `book-source.md` §8 |
| M1 语法 #15–#19 的状态列仍为「待验证」（真实书源回归未做） | **待回归**：按 ADR-0024 §决策 2，只有真实抓取页面 / 真实链路才能改状态列；需要在语料里找到用到 `@@` / `@put:` / `@get:` / `java.*` / `{{}}` / `{}` 的真实源（选源命令见 `tool/spot_check/README.md` §3，统计必须由入库工具复算），回归记录写入该文件与 PR |
| `java.get('bookName')` / `java.get('title')` 的上游特例（取 Book / Chapter 名字，`AnalyzeRule.kt:812-821`） | **Phase 5（bookshelf / reader）**：那两个实体到那时才有；当前按普通变量读（`book-source.md` §3 的 #17 注记） |
| 规则变量的生命周期：随 Provider 作用域、不落盘（上游持久化在 book / source 上） | **Phase 5**：与书架 / 阅读进度的持久化一起裁决（ADR-0034 §决策 2）；`@put:` / `@get:` 的**同源**语义已完整 |
| `{{…}}` 在**列表规则**里的语义：本仓替换后按选择器读，上游回文本本身（`Mode.Regex`） | **待语料**：真实源出现「列表规则里用 `{{…}}` 造选择器」时再对齐；差异已登记在 `book-source.md` §3 的 #18 注记 |
| 模板的 JS 返回**列表**时本仓取第一个值（上游插入数组的 `toString()`） | **已登记（`book-source.md` §3 #18 注记）**：待真实语料出现再定 |
| `@put:{…}` 的体按 `key:value` 解析（值可带引号或裸写），不走上游 GSON 的严格 / 宽松两级 | **已登记（`book-source.md` §3 #16 注记）**：解析不出键值对的片段被忽略（与上游空 putMap 同结果） |
| **上游有、本仓未建模的字段**：`SearchRule.checkKeyWord`、`BookInfoRule.downloadUrls` / `relatedBooks`、`TocRule.preUpdateJs` / `formatJs` / `isVolume` / `isPay` | **保留在 `extra`（不丢数据）+ 去向待排期**：`checkKeyWord` 只用于「书源校验的默认关键词」（`BookSource.kt:228-238`），属书源校验 / 调试；`downloadUrls` / `relatedBooks` 与 `isVolume` / `formatJs` / `preUpdateJs` 属 Phase 5 的阅读器与书架；未建模期间**不得**声称支持这些字段（清单归 `book-source.md` §2 注记） |
| 发现页整字段 JS 的 `infoMap` 绑定、分类参数（`args` / 临时变量）与排名模块（`executeForRanking`、`MAX_RANKING_BOOKS` / `MAX_RANKING_PAGES`） | **不在 M1（ADR-0035 §决策 6）**：`infoMap` 命中即 `js:error`；表单型分类（`type` 非 `url`）报 `unsupportedRule`；行为归 `book-source.md` §4.2 / §11 |
| 发现页条目 URL 缺失时，上游把**整段 `exploreUrl`** 当 URL 传下去（`ExploreBooksUseCase.kt:64-72`） | **已登记（ADR-0035 差异②）**：本仓拒绝该条目；真实语料若证明有书源依赖该副作用，再单独裁决 |
| `java.timeFormatUTC(time, format, sh)`（带时区偏移与自定义 pattern） | **不在 M1**：触发条件 = 真实语料出现；`java.timeFormat` 的入参 / 时区语义归 `book-source.md` §6 |
| `canReName` 的**消费方**（覆盖已有书名 / 作者） | **Phase 5（书架 / 阅读器）**：上游 `BookInfo.kt:65-84` 只在有 Book 实体时才有意义；M1 只建模 + 把「是否允许改名」传出，且**不求值**该规则（有意差异，归 `book-source.md` §2 注记） |
| `updateTime` 的**展示**（列表 / 详情 / 目录 UI） | **Phase 5**：M1-b1 只把它落到实体字段（四处），UI 展示随阅读器 / 书架一起做 |
| `concurrentRate` 的真实源只有 3 条（合集 C 3907 条），且三条都跑不了原样链路 | **已登记（2026-10-13，b2）**：1 条站点不可达（快书网）、2 条用未实现的 URL 形态（`<js>` 包装 / `{...}` URL 选项）；因此 b2 的真链路回归用**派生源**（漫客栈 + 只在 `concurrentRate` 上做 A/B：`1500` → 4.6 s、`0` → 0.6 s），记录在 `tool/spot_check/README.md`。这三条里任何一条变得可跑时，优先用真源复现 |
| `spot_check --list` 的「非搜索字段 URL 里的 `{…}`」判据（原排期 M1-b4b） | **未做，等你裁决（2026-10-13）**：该判据的原始理由是「`{…}` 模板型 URL 规则在 M0 下无法逐字回放」，而矩阵 **#19 已在 3.7 实现**（`{$jsonpath}` 模板），现在排除这类源会把**能跑**的源挡在候选之外；另一方面收紧判据会改变 `--list` 的 353/253/122（ADR-0032 与 `tool/spot_check/README.md` 多处引用）。**两个选项：** ① 不改（现状，`{…}` 由真实回归逐条看）；② 改判据并同批用工具复算 + 更新引用它的数字（一次做全）。 |
| ~~b2 的 Android 设备探针在本机跑不了（环境）~~ | ✅ **已闭环（2026-10-13 架构师复核）**：网络恢复后复跑 `tool/test/run_android.ps1` —— `Medium_Phone` 上三个用例文件全过、`js_bridge` **21/21**（退出码 0），记录已写入 `test-environment.md` §7；原阻塞是 `flutter build apk` 的 native assets 要从 `github.com/.../releases/download/` 下载 `libsqlite3.arm.android.so` 超时（与本切片无关） |
| ~~M1-b1 的两条验收项（2026-10-13 复核）~~ | ① **部分闭环（架构师 2026-10-13）：** 派生源（只改 `ruleToc.updateTime` 一条规则）在活站点上把 `java.timeFormat` 的返回值坐实到了 `Chapter.updateTime`（`2023/11/15 06:13`，记录见 `tool/spot_check/README.md` §4）；**语料主流写法仍未证** —— 184 条用 `java.timeFormat` 的源主流是 `{{java.timeFormat(java.getString('$.x')*1000)}}`，先要 **`java.getString`（见下一行 b1b）**。② ✅ **已闭环（2026-10-13）**：网络恢复后复跑 `tool/test/run_android.ps1` —— 模拟器 `Medium_Phone` 上三个用例文件全过、`js_bridge` **21/21**（退出码 0），记录已写入 `test-environment.md` §7 |
| **`java.*` 绑定名与真实语料的缺口（2026-10-13 架构师取证 → **ADR-0037 已裁决**）** | 全量 3907 条里 **540 条**用 `java.*`（用法计数：`md5Encode` 1221 · `put` 1070 · `get` 1048 · `ajax` 866 · **`getString` 603** · `base64DecodeToByteArray` 328 · `timeFormat` 297 · `log` 250 · `encodeURI` 138 · `getElements` 84 · `base64Encode` 84 · `base64Decode` 71 · `setContent` 62 · `getElement` 45 · `getStringList` 36 · 密钥类 crypto · Rhino 互操作 · UI）。**裁决结果（ADR-0037 §决策 2-5，形态归 `book-source.md` §6 / 拒绝清单归 §11）：** ① 别名族（`md5Encode` / `base64*` / `encodeURI` / `log`）worker 内同步，归 **b1b**；② 规则求值族＝**字面量快路径（引擎在交给 worker 前内联；语料 379 个字面量嵌套调用里的 377）+ 异步兜底（Promise，绑定当前 scope）**，两条路径共用同一实现点（同一 (规则, scope) 结果必一致）；同步语义是 load-bearing 的（嵌套 395 vs 独立 372），所以不能只做异步；③ 列表返回 JS `Array` + `Array.prototype.toArray()` 垫片（语料 38 处 Java `List` 习惯用法）；④ `ajax` / `get` / `post` / `webView*` / `setContent` / `toast*` / 字节数组与密钥类 crypto / Rhino 互操作等一族**具名拒绝**（抛错存根 / 抛错 Proxy），不落 `undefined is not a function`；⑤ 多参重载（flags / charset / unescape）具名拒绝 |
| ~~**b1b 的真实源回归**（`{{java.timeFormat(java.getString($.x)*1000)}}` 主流写法）~~ | ✅ **已闭环（开发组 2026-10-13，待架构师复核）**：58 条 `ruleToc.updateTime` 用主流写法的真源逐个探活后无一条能原样跑（TLS 不可达 / WAF 403 / POST 表单搜索 / `<js>` 包装，表见 `tool/spot_check/README.md` §4），因此在**真实导出的漫容栈源**上只改 `ruleToc.updateTime` 一条规则（`$.change_time@js:…` → `{{java.timeFormat(java.getString('$.start_time')*1000)}}`；该站 `change_time` 全为 `"0"`），真链路得出 `Chapter.updateTime = 2018/10/25 17:05`，同时收口了 b1 剩下的那半。另新增一条 `{{…}}` 模板形态的单测（首版只测了 `@js:` 段） |
| **`{{…}}` 模板内部的 `##` 替换会被当成规则分界（新发现，2026-10-13，真源回归带出）** | **已排期 b5（架构师 2026-10-13 裁决：真缺口，但不在 b1b 修——与 `java.*` 无关；架构师已用临时用例复现 `{{$.tag_views##\s+##,}}` → `parseFailed`）**：`{{$.tag_views##\s+##,}}` 这类写法里，第一个 `##` 在模板内部，而 `_expandRule` 先按第一个 `##` 把整条规则切成「规则体 + 替换段」，模板因此被判成不平衡 → 该字段 `parseFailed`（矩阵 #18 × #9）。腾讯搜索系真源（`●QB女生<kd♛` / `南极 🐧`，`ruleBookInfo.kind`）的第一条模板就是它，所以那两条活源跑不到主流写法。**修复方向（未做）**：切 `##` 时跳过 `{{…}}` 内部（与 `_templateEnd` 同一套引号 / 嵌套计数）。**触发条件：** 语料里出现依赖 `{{rule##a##b}}` 的源就是现在 |
| **JSONPath 方言：`]` 后直接跟成员名（新发现，2026-10-13，同一次真源回归）** | **已排期 b5（架构师 2026-10-13 裁决；架构师已复现：`$.data.page[*].image` 成功、`$.data.page[*]image` `parseFailed`）**：`$.data.page[*]image` / `$.a[0]b` 是 Legado（上游 jsonpath 库）接受的写法，而本仓用的 RFC 9535 解析器（`json_path`）只认 `$.data.page[*].image`；同一页真实数据下 `[*]image` 直接 `parseFailed`、`[*].image` 返回 3 张图。它让 b1b 派生真源的 content 段失败（`java.getStringList` 快路径**已被调用**，卡在内层规则），所以 b1b 的 `getStringList` 只在离线语料与探针里验过成功路径。**修复方向（未做）**：把 `]` 后紧跟成员名的形式归一成 `].` 再交给解析器（需附带边界测试）。**触发条件：** 本例已触发，只是不阻塞本切片 |
| **HTML 实体反转义：本仓不做，上游默认做（新发现，2026-10-13）** | **已登记（`book-source.md` §3 的对照注记）**：上游值规则 `unescape` 默认 `true`，对含 `&` 的结果做 `StringEscapeUtils.unescapeHtml4`（`AnalyzeRule.kt:297-308` / `:362-366`），`java.getString(rule, false)` 可关。实际差异比看起来小（DOM 文本 / 属性已被解析器解码），真正不同的是 `html` / `all` 一类**原样**提取。**触发条件：** 真实语料回归出现「作者依赖实体反转义」的实例（如标题里的 `&amp;`）时，按**新 ADR** 决定是否实现；在此之前 `java.getString(rule, true)` 具名拒绝 |
| `tool/spot_check` 的 `--list` 判据口径（2026-10-13 更新两次，已闭环） | ✅ **已闭环（架构师 2026-10-13）：** 判据随已实现语法收放（`@js:`、`@put:` / `@get:`、`{{}}` 内嵌不再排除），合集 C 的普查由 266/192/69 变为 353/253/122。**同日修正（b1b 返工）：** 「`{` 开头就排除」那条旧判据（为 `{"method":"POST"}` 写的）把 `{{…}}` 也当对象头，与同一段注释和本行互相矛盾；现在只排除**单**花括号开头，普查复算为 **384/278/142**（架构师用工具判据的独立复刻脚本在同一份 `build/ao.json` 上复现了两组数字）。残留的保守项只有搜索 URL 的裸 `{…}`（**不收紧**，理由与口径归 `tool/spot_check/README.md` §3/§6） |
| ~~`spot_check --list` 不检查非搜索字段 URL 里的 `{…}`（矩阵 #19）~~ | ✅ **已闭环（架构师 2026-10-13 裁决：不收紧、只改措辞）**：该判据的原始前提是「`{…}` 模板型 URL 规则在 M0 下无法逐字回放」，而矩阵 **#19 已在 3.7 落地**，这类源现在**能跑**；按此收紧会把能跑的源挡在候选之外，放开又会把「搜索 URL 用裸 `{…}`」的源当成可跑。因此判据**不收紧**（`--list` 只做保守筛查，这类源由 §4 的真实回归逐条判定）。**补充（同日）：** 非搜索字段那半边随后以 **bug 修复**的形式放开了 `{{…}}`（见上一行），那是「代码与已写明的判据不一致」，不是收紧/放开之争；搜索 URL 那半边保持不变 |
| ~~charset 检测结果缓存~~ | ✅ **已闭环（3.9，2026-10-12）**：`CharsetCache` 端口 + `CacheDao` 适配器，按「书源 ID + URL」缓存**嗅探**结果（声明车道不进缓存）；语义归 `book-source.md` §5 |
| 按书源清理缓存（需加列 + 迁移） | **Phase 5.5** |
| **页面字段规则的 `page` 绑定与「已取到的那一页」不一致（新发现，2026-10-13）** | 搜得 / 发现阶段调 `PageFetchService.fetch(...)` 时**不传 `page`**，而它的默认值是 `1`；于是第 2 页响应里的字段规则在 JS 里读到 `page = 1`。上游的**字段规则 JS 根本不绑** `page`（`AnalyzeRule.evalJS` 的绑定里没有它，只有 `AnalyzeUrl.evalJS` 有），所以两边都不是「另 一家」。**触发条件：** 真实语料出现「字段规则用 `page` 分支」的源时裁定（要么把 `page` 传下去、要么像上游一样只在 URL 规则绑）；数值语义仍归 `book-source.md` §6 |
| ~~`.gitattributes` 声称 `* text=auto eol=lf`，但三个文件的 blob 里存的是 CRLF（2026-10-13）~~ | ❌ **不成立，已撤回（架构师 2026-10-13 复测）：** 复现命令给出的是**相反的**结论 —— `git cat-file blob main:PLAN.md \| od -An -tx1 \| tr ' ' '\n' \| grep -c '^0d$'` 对 `PLAN.md` / `CHANGELOG.md` / `docs/dev/book-source.md` 在 `08c19d7`、`33bc9fc`、`2e8eabe`、`a319f52` 四个提交上都返回 **0**；`git ls-files --eol` 对全部受管文本都是 `i/lf w/lf attr/text=auto eol=lf`。原始判断来自 `git show <ref>:<file> \| grep -c $'\r'` 一类检查，它在本机 shell 上会给**每一行**都报 CR（把 `PLAN.md` 的 375 行全数报成 CRLF），属**检查方法错误**，不是仓库行尾问题。真正存在 CRLF 的只是**开发组编辑器新建的 4 个工作树文件**（`explore_page.dart` / `app_en.arb` / `app_zh.arb` / `explore_page_test.dart`），`git add` 时已由 `text=auto` 归一化为 LF——这也解释了 `git status` 里那几条 “CRLF will be replaced by LF” 提示。**结论：** 无需任何仓库卫生动作，也不需要「编辑这三个文件时保持现有行尾」这条临时约束 |
| **覆盖率门禁 flake：`core` 会随机从 100% 掉到 99.89%（2026-10-13，复核 b1b 时发现）** | ✅ **已闭环（架构师 2026-10-13）：** `lib/core/network/request_limiter.dart` 原有私有 `_wait`（`Future<void>.delayed` 的一行包装）只能在「速率门真的等待」时才被执行，而唯一覆盖它的用例 `run_givenNoInjectedDelay_waitsOnRealTime` 用 **1 毫秒**真实窗口——两次 `run` 之间耗掉 ≥1 ms 时第二次不必等待，该行当次未执行 → `core` 943/944 → 退出码 1。3 连跑可复现（100% / 99.89% / 100%）。**修法：** 删掉 `_wait`，默认值直接是 `Future.delayed` 的 tear-off，本文件不再有「只有等待时才执行」的行；用例窗口放宽到 20 ms 并把这一点写进注释。5 连跑 `core` 稳定 919/919 |
| ~~**b1b 首版交付复核：快路径与异步路径结果不一致等 5 类缺陷（2026-10-13 架构师复核 → 退回开发组返工）**~~ | ✅ **已闭环（2026-10-13，返工后复核通过并合并）**：5 项必改逐条落地并复核（`getElement` 两条路径都成单值、`getString` 无匹配都成 `''`、`post` 具名拒绝、`base64*` 多参拒绝、`book-source.md` §6 状态列真正翻成 ✅ 且 `PLAN.md` 不再被 CHANGELOG 虚报）；架构师复核又发现同类的**第三条**（JSON scope 下列表值被 `toString()` 串化，实测内联 `["a.jpg","7"]`）**已在合并前修掉**；Windows 设备级由架构师独立复跑 `js_bridge` 24/24；Android 按 ADR-0038 归 Phase 4 出口。原必改清单（存档）：已达标部分：`javaEncodeUri` 与 Java `URLEncoder` 语义逐项对齐、别名族、`.toArray()` 垫片、Rhino 抛错 Proxy、`encodeURI` 多参拒绝。**必改清单：** ① **两条路径结果不一致**（违反 ADR-0037 §决策 3 与 §3.5 b1b 验收项「同一 (规则, scope) 在快路径与异步路径上结果一致」）：`getElement` 快路径给单值（`rule_engine.dart:802,855` 的 `_wantsList` 不含它）而异步路径给数组（`quickjs_worker.dart:569` → `__parse('getElements')`）；`getString` 无匹配时快路径内联 `null`（`rule_engine.dart:824`）而异步路径答 `''`（`rule_engine.dart:1581`，与 §6「无匹配时 `''`」一致）。② `java.post` **没有**具名拒绝（`quickjs_worker.dart:506` 的 `__javaRejectedNames` 缺 `post`）→ 落到 `undefined is not a function`，违反 ADR-0037 §决策 5 与 §11；`get` 被变量读写占用是合理偏离，但要写回 ADR/§11 而不是只写在代码注释里。③ `java.base64Encode(str, flags)` / `base64Decode(str, charset)` 未拒绝多参（`quickjs_worker.dart:542,545` 只透传首参），违反 §决策 2「猜一个会静默给出不同结果」。④ 文档漂移：CHANGELOG 写「`PLAN.md` §3.5 marks b1b done」但该提交**没改 `PLAN.md`**；`book-source.md` §6 兼容面表 5 个成员的状态列仍是 `M1-b1b`。⑤ 验收项未完成：真源回归（`{{java.timeFormat(java.getString('…')*1000)}}` 主流写法）、双端设备探针与 `test-environment.md` §7 记录。另有三处小项：`quickjs_worker.dart:601` 一行两条语句、`_selectAllValues` 的 `///` 中间夹空行、`Packages.*` 未具名拒绝。**返工后按 §3.5 b1b 的验收项重新走一遍门禁与探针** |
| 非顶层字段被拒降级为 warning（ADR-0026） | ✅ **已闭环（3.2）**：唯一实现点为 `PageFetchService`，两类（`unsupportedRule` / `parseFailed`）均降级，顶层 / 非顶层各 ≥1 条测试 |
| 真实站点 spot-check（G2b） | ✅ **已闭环（2026-10-12）**：四段链路与派生 `@css:` 等价验证记录见 `tool/spot_check/README.md`；衍生的 **ADR-0032**（未知类型 → CSS）已落地，**ADR-0031**（已声明车道宽容解码）已实现 |
| JSON 接口源的 URL 规则依赖 #16–#19（`@put:` / `@get:` / `{}` / `{{}}`） | **3.3 之后重排 M1 优先级**：211 条真实书源中 2 条用 `@json:`，其 URL 规则全部依赖上述 M1 模板，M0 下无法逐字回放（证据见 ADR-0028 §后果、`test/fixtures/json/README.md`） |
| `{{}}` 内嵌规则（矩阵 #18）当前按「未定义变量」→ 空串 + warning | **Phase 4** 落地 #18 时改为求值，并同步矩阵状态列 |
| `extra` 的导出合并（`toLegadoJson`） | 随**导入 / 导出**功能实现（ADR-0021 §后果）；在那之前不得声称可无损导出。**2026-10-13 补充（b1 复核发现）：** freezed 生成的 `BookSource.toJson()` 在顶层把嵌套规则给出**对象**而不是 `Map`，递归成 JSON 得靠 `jsonEncode`（它认 `toJsonableObject`）；`explicit_to_json: true` 是否开由导入 / 导出那一批决定（生成器选项的唯一出处是根 `build.yaml`），本切片不动 |
| Big5 / Big5-HKSCS 解码缺口 | 仍待排期（`book-source.md` §5.1） |
| 文件型数据库（后台 isolate + 原生库）无自动化覆盖 | 由 `integration_test/` 覆盖（`test-environment.md` §4） |
| ~~G2b 的**证据语料未入库**~~ | ✅ **已闭环（2026-10-12）**：`legado_g2b_default_rules_source.json` 与
`legado_g2b_css_rules_source.json` 按 `test/fixtures/book_sources/README.md` 的来源/脱敏格式入库（含 16 处派生映射表），
入库后在活站点上逐字复现「同计数 + `sha256=6578ef3efc456856`」；同时发现并改正了统计口径：`--list` 复算为 **137/197（69.5%）**，
搜索段失败 **10/13**（原 157/270、58.1%、9/13 出自未入库的临时脚本，已作废，见 ADR-0032 §背景） |
| `shift-jis` / `euc-jp` 的字节不完整会让 `charset 2.0.1` 抛 `RangeError`（`Error`），越过 `ParseResult` 契约逃到调用方；同样地，`euc-kr` 的解码器静默丢弃非法字节（无宽容入口可走） | **待排期**：按 ADR-0022 不得捕获 `Error`，需换依赖或加隔离层；两族因此**不在** ADR-0031 的宽容映射里，仍按严格失败处理（`euc-kr` 则是依赖自身的丢弃行为）；证据与影响见 `tool/spot_check/README.md` §6 与 `book-source.md` §5.1 |
| 矩阵 #14（`@js:`）无任何真实语料样本 | **3.7**：仓内 `test/fixtures/book_sources/*.json` 的 `@js:` 出现次数为 **0**，因此 #14 的状态列无法改「已确认」；补样前先补语料（ADR-0029 §后果）。3.4 已把值规则侧的语法、绑定与额度落完（见 `book-source.md` §6） |
| JS 绑定是否需要**同步**写法（3.4 只实现 Promise 形态的 `http.*` / `parse.*`） | **3.7** 真实语料回归出证据后，以**新 ADR** 裁决是否追加；不得就地放宽（ADR-0029 §决策 4） |
| ~~3.4 剩余绑定与额度（`http.*` / `parse.*` 的 Promise 形态、`parse.*` 的页级 scope、≤20 调用额度**含 `log.*` 计数**）~~ | ✅ **已闭环（3.4 part 3，2026-10-12）**：`http.get` / `http.post` / `parse.getString` / `parse.getElements` 均为 Promise 且经请求层 / 引擎实现；页级 scope 命中以外的 `doc` 报 `js:parse-scope`；额度由桥按 job 计数（`log.*` + `http.*` + `parse.*`，`crypto.*` 在 worker 内完成不计），超限报 `js:quota`。语义归 `book-source.md` §6 |
| 列表规则（`bookList` / `chapterList`）上的 `@js:` 报 `unsupported:@js:list` | **待语料 + 新契约**：上游 `getElements` 的 `Mode.Js` 分支要的是「JS 返回一列元素」的契约（元素对象 / 裸键取值），仓内无任何 `@js:` 语料可定型，3.4 只实现值规则；触发条件 = 3.7 真实语料出现列表 `@js:` |
| `parse.*` 的嵌套规则自己又用 `@js:` | **已登记（3.4）**：报 `unsupportedRule` + `js:parse-recursion`。理由：单 worker 正在跑发起它的那个 job（ADR-0030 §决策 1/3），嵌套 evaluate 只会排在自己的队后面；放宽需新 ADR + 真语料 |
| `parse.getElements` 交给脚本的是 `outerHtml` 字符串 / JSON 值，**不是 DOM 句柄** | **已登记（3.4）**：沙箱无 DOM（ADR-0029 §决策 5），所以上游「`getElements` 后再 `parse.getString(rule, element)`」的写法会在 `doc` 那步报 `js:parse-scope`；要读元素内部就写在嵌套规则里（`class.a@tag.b@text`） |
| **元素 scope 上独立 `@js:` 的 `result` 形态**：本仓给该元素的 `outerHtml`（JSON 条目给 JSON 文本），理由是沙箱无 DOM 句柄可交（ADR-0029 §决策 5） | ✅ **已闭环（3.7，2026-10-12）**：读 fork 源码核实——上游 `AnalyzeRule.evalJS(rule, result)` 把当前 `result`（`setContent` 得到的 jsoup `Node`）直接绑给 JS，所以上游能用 `outerHtml()` / `text()` 等 DOM 方法；本仓只能给 HTML 字符串，靠 DOM 方法的脚本会 `js:error` **显式失败**（不会静默给错值）。仓内 1096 条含 `@js:` 的真实源里未出现这种写法（元素级脚本全是字符串运算/拼接），保持为**有意差异**；行为描述归 `book-source.md` §6 |
| 矩阵 #7（前导 `-`）在真实回归里只行使了**单元素**倒置（恒等） | **待语料**：方向语义由单测钉住（`extractAll` 与列表规则的多元素倒置各 ≥1 条），但仓内没有需要多元素倒置的真实源；触发条件 = 真实回归出现这种规则（选源命令见 `tool/spot_check/README.md` §3） |
| `http.*` 的传输失败不把 `ParseFailureKind`（可重试性）交给字段 | **已登记（3.4）**：失败以 rejected Promise（message = kind 名）交给脚本，脚本可以 `catch` 后改走镜像；未捕获时按 §7 报 `js:error`。把传输 kind 上抛就是猜，需先有真实语料证明「作者不会 catch」 |
| ~~3.8 并发策略与 JS worker 容量的耦合~~ | ✅ **已闭环（ADR-0030）**：裁决为单常驻 worker + 单复用运行时 + FIFO，**容量不进 `JsBridge` 契约**；重开触发条件见 ADR-0030 §决策 5 |
| ~~`isVip` 的**正侧**真值缺上游 `file:line`~~ | ✅ **已闭环（R1，2026-10-12）**：直抓 fork 源码 `HapeLee/legado-with-MD3@master`，判定就是上游 `String?.isTrue()`（调用 `BookChapterList.kt:261-264`，谓词 `StringExtensions.kt:75-80`）——`null` / 全空白 / 字面量 `"null"` → 非 VIP，其余值除非匹配 `(?i)^(?:false|no|not|0|0.0)$` 否则算 VIP（因此 `是` / `yes` 是 VIP，`no` / `not` / `0.0` 不是）；代码与测试已按此对齐，两处上游怪癖（`"null"` 在 trim 前比较、模式里 `.` 未转义）按原样照抄并登记在 `book-source.md` §4.1，唯一出处仍是 §4.1 |
| 并发上限接入**用户设置**时（Phase 5）必须显式校验 `> 0`：`HttpPolicy` / `RequestLimiter` 目前只用 `assert`，release 下会被剥掉，`0` 会让该键的每个请求**永久排队** | **Phase 5（设置页）**：在设置边界校验或钳制；语义归 `book-source.md` §8 |
| `httpClientProvider` 是 autoDispose，预算存在于 `DioHttpClient` 实例上，所以「同一书源并发上限」在**一次操作内**有效、跨操作会重建 | **Phase 5**：批量下载必须保证整批共用一份预算（该 provider 改 `keepAlive`，或把预算提到 app 级单例）；今天是串行翻页，无影响 |

---

## 4. 检查点门槛（Gate）

进下一阶段前必须**全部**满足，否则不进入：

| Gate | 条件 |
|---|---|
| **G1** | 覆盖率门禁全绿（阈值与「未测量源文件」判定见 `docs/dev/testing.md` §2）；`AGENTS.md` §4 的全部命令退出码均为 0 |
| **G2a** | 1 个**真实书源**的「搜索 → 详情 → 目录 → 正文」**离线回放**通过，且回放必须驱动**生产链路**（UseCase → `renderUrlTemplate` → `HttpClient` → `RuleEngine`）；**已达成**（ADR-0024） |
| **G2b** | 手动跑通一次**真实站点**链路；依赖矩阵 #12（`@css:`，3.2）。✅ **已达成（2026-10-12）**：`biquge99.cc` 四段跑通 + 同站派生 `@css:` 等价源哈希一致，记录见 `tool/spot_check/README.md` |
| **G3** | 2 个书源全链路离线回放；矩阵 M0 状态列全部「已确认」；9 个失败 kind 均有测试。✅ **已达成（2026-10-12，随 3.7）**：离线回放 = 默认规则源 + JSON 接口源（链测试），并有第三个 `@js:` 语料源回放搜索/详情/目录；矩阵 19 行全「已确认」（逐行证据见 `tool/spot_check/README.md` §4b）；9 个 kind 均有测试 |
| **G4** | 矩阵 M1 状态列全部「已确认」 |
| **G5** | C-UI-9 可达；无 `TODO` 占位；无未使用代码 |
| **G7** | **阶段出口的设备级探针**：离开任一 Phase 前，`integration_test/` 的全部用例必须在 **Windows 与 Android 各实跑一次**且退出码 0；**切片级只要求 Windows**（口径、例外与重开条件归 `docs/dev/test-environment.md` §1，决策理由归 **ADR-0038**）。Phase 1–3 出口时两侧都实跑过（`test-environment.md` §7 的历史记录），**Phase 4 出口待跑**（含 b1b 新增的 3 条 `java.*` 探针） |
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
| 8 | 手改生成文件 / 忘记重跑生成 | 只用 C-DEP-4 声明的生成命令（`--delete-conflicting-outputs` 已失效，见 ADR-0013 §6） |
| 9 | 同一数值写在两处（版本、阈值） | 单一来源原则；事实级归属见 `docs/README.md` §2.1 |
| 10 | 以为 spike 绿了就等于功能已测 | `tool/spike/` 是**架构可行性**验证，不是功能回归；功能测试必须进 `test/` |
| 11 | **并行写 ADR 时编号撞车**（两方各写一条同号，其中一条还是同一决策的重复） | 动手前先 `ls docs/dev/adr/`，并与对方分支核对编号；**同一决策只允许一份 ADR**（编号稳定性见 `docs/README.md` §5） |
| 12 | **把脱敏后的语料直接拿去跑真实站点** | 语料主机已改为保留域，复跑前显式还原；原主机与还原命令记录在 `test/fixtures/book_sources/README.md` |
| 13 | **用一次性脚本算统计数字**（未入库、判据与引擎不一致），审查时无法复核 | 统计必须由**入库的工具**复算，且判据与引擎一致（本仓已踩：一个 58.1% 的统计被审查打回并更正，工具与命令见 `tool/spot_check/README.md`） |
| 14 | **把活站点当天内容的哈希当成回归基线** | 哈希钉的是当天内容，站点改版后变化是事实而不是回归；回归基线必须是离线语料（C-NET-8） |
| 15 | **为「嗅探车道」写 `throwsFormatException` 用例** | 该车道的可达标签全是宽容编解码器或抛 `Error` 的族，根本进不了严格失败分支；可核验的形状是「精确标签 + 零替换」，缺口登记在 §3.7 |
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
| 阶段完成 / 遗留事项闭环 | 本文档 §3.1 状态表与 §3.7 登记表 |

> 变更完成后跑一次文档一致性自检（自检项清单由 `docs/README.md` §6 的单一来源规则决定）。

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
