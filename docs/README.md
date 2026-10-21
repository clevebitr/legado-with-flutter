# 文档索引与归属

> **本文件是项目内所有文档路径的唯一权威。** 任何文档引用其他文档时，以本表为准。
> 若发现某处引用的路径不在本表中，视为缺陷，请修正引用而不是新增副本。
> 事实级归属见 §2.1；单一来源规则见 §6。

---

## 1. 入口类文档

| 路径 | 职责 | 谁需要读 |
|---|---|---|
| `AGENTS.md` | AI 代理入口：工作流 + 门禁 + **何时读哪份文档**（≤120 行，零规范正文） | 所有 AI 代理、贡献者 |
| `docs/dev/roadmap.md` | **实现顺序、验收标准与检查点（Gate）+ 阶段状态表 + 返工陷阱**（只讲先做什么、怎么验收，不复述规则） | 开始任何功能开发前 |
| `PLAN.md` | **里程碑级状态**（当前里程碑 / goal / 断点），由 `plan` 插件维护，**不得手改**；步骤级进度以 `todo` 为准 | 看「当前做到哪」 |
| `DECISIONS.md` | 执行期决策与踩坑日志（`plan` 插件追加，`#N` 可检索）；**正式决策仍归 ADR** | 查历史教训时 |
| `CONTRIBUTING.md` | 贡献流程：分支、Commit、PR、Review、语言约定入口 | 所有贡献者 |
| `README.md` | 项目简介、快速开始、构建与运行 | 使用者、贡献者 |
| `CHANGELOG.md` | 变更历史与破坏性变更（过程记录的唯一归档处） | 贡献者、发布负责人 |
| `NOTICE.md` | 版权、与上游 Legado 的关系、免责声明、GPL 合规义务、第三方依赖许可清单 | 贡献者、发布负责人 |

> **历史引用：** `docs/dev/roadmap.md` 原名 `PLAN.md`，小节号未变 —— `CHANGELOG.md` 与 `docs/dev/adr/` 里
> 对 `PLAN.md` §X 的引用等同于 `docs/dev/roadmap.md` §X（ADR 与 CHANGELOG 是历史记录，不追改）。

## 2. 规范类文档（`docs/dev/`，每份都是该主题的唯一来源）

| 路径 | 职责 | 相关约束组（条目 ID 均定义在 `constraints.md`） |
|---|---|---|
| `docs/dev/naming.md` | 文件、类、方法、变量、API、注释、ARB 键的命名规范 | — |
| `docs/dev/constraints.md` | 约束条目**台账**（`C-*`）；每条为可判定的单句规则 + 回链 | `C-*` |
| `docs/dev/tech-stack.md` | 依赖与版本、lint 与约束 ID 的映射、国际化配置、生成器选项 | — |
| `docs/dev/architecture.md` | 目录结构、分层边界、依赖注入、路由、`ParseResult` 契约 | `C-ARCH-*` |
| `docs/dev/book-source.md` | Legado 书源规则支持矩阵、模板语法、失败语义、JS 白名单与配额、测试基线 | `C-SRC-*` |
| `docs/dev/testing.md` | 测试分层、覆盖率门禁、Golden 策略、CI 流水线 | `C-TEST-*` |
| `docs/dev/test-environment.md` | 本机（Windows/Android）测试环境：一键脚本、设备级用例、排错与实测证据 | —（门禁与分层仍归 `testing.md`） |
| `docs/dev/platform.md` | Android / iOS / Windows 平台基线与降级策略 | `C-PLT-*` |

### 2.1 事实级归属矩阵（每个事实只有一处定义）

ADR-0027 确立：**一个事实只允许在一处定义**，其他位置一律写引用。改任一事实前先看本表。

| 事实 | 唯一定义处 | 其他位置 |
|---|---|---|
| 门禁命令本体 | `AGENTS.md` §4 | 一律回链（ADR-0013 §5） |
| CI 执行顺序与 CI 特有步骤 | `docs/dev/testing.md` §7 | — |
| 覆盖率阈值、「未测量源文件」判定、退出码 | `docs/dev/testing.md` §2 | `constraints.md` C-TEST-1 回链 |
| 覆盖率豁免条目与理由 | `tool/coverage_allowlist.txt`（文件内注释） | 类别定义见 ADR-0019 §2 |
| 测试文件位置（镜像 `lib/` / `integration_test/`） | `docs/dev/testing.md` §3 | C-TEST-4、`naming.md` §2、`test-environment.md` §4 回链 |
| 本机测试环境、脚本、设备级用例**及其执行时点**、实测证据 | `docs/dev/test-environment.md` | `testing.md` §1 回链；执行时点的决策理由归 ADR-0038 |
| 依赖清单与版本 | `pubspec.yaml`（代码）；`docs/dev/tech-stack.md` §1、§2–§9（说明） | C-DEP-6 |
| 依赖版本相互耦合的原因 | `docs/dev/tech-stack.md` §1.1 | — |
| `m3e_design` API 与 `M3ESpacing` 六阶数值 | `docs/dev/tech-stack.md` §3.1 | `constraints.md` §6 回链 |
| 平台基线（minSdk / targetSdk / Windows / iOS） | `docs/dev/platform.md` §1 | C-PLT-5 回链 |
| 平台抽象接口、动态取色矩阵、降级原则 | `docs/dev/platform.md` §2–§4、§7 | `constraints.md` §7 回链 |
| Windows 开发者模式前置条件 | `docs/dev/platform.md` §1.2 | `README.md`、`CONTRIBUTING.md`、`test-environment.md` 回链 |
| lint 规则与 `C-*` 映射 | `docs/dev/tech-stack.md` §12（规则本体在 `analysis_options.yaml`） | — |
| 生成器选项 | 根 `build.yaml`；理由见 ADR-0022 | `tech-stack.md` §8 回链 |
| 命名规则（含 ARB 键名规则） | `docs/dev/naming.md` | — |
| 约束条目 ID 与可判定规则 | `docs/dev/constraints.md` | ADR 回链 |
| 目录结构、分层边界、DI、路由 | `docs/dev/architecture.md` §1–§4、§6 | — |
| 书源校验的分组词表、失败归类、写回落点 | ADR-0043 §决策 1/4（代码常量在 `lib/features/book_source/domain/source_check_group.dart`） | `docs/dev/roadmap.md` §5.10 只做摘要；复现记录见 `tool/spot_check/source_check_records.md` |
| 长任务平台端口（`LongRunningTask`）与三端降级 | `docs/dev/platform.md` §2（ADR-0043 §决策 3） | `constraints.md` §7 回链 |
| `ParseResult` 类型契约与 `ParseFailureKind` 枚举 | `docs/dev/architecture.md` §5 | — |
| `ParseFailureKind` 触发条件与 ARB 键值 | `docs/dev/book-source.md` §7 | `architecture.md` §5 只定义枚举 |
| `RuleEngine` 求值 API 的异步形态、JS 绑定的同步 / Promise 形态与 `parse.*` scope 边界 | `docs/dev/adr/0029-*.md`；操作面形态表归 `docs/dev/book-source.md` §6 | `docs/dev/roadmap.md` §3.3/§3.4 回链 |
| JS 引擎容量、排队、超时后恢复与跨源隔离边界 | `docs/dev/adr/0030-*.md` | `book-source.md` §6 回链；数值仍归 §6 |
| 规则变量（`@put:` / `@get:` / `java.put` / `java.get`）的存储位置、快照与生命周期，以及只存在于 URL 规则的 `key` 绑定 | `docs/dev/adr/0034-*.md` | `book-source.md` §4 / §6 回链（行为面） |
| 发现页：`exploreUrl` 的两种形态、分类条目语义、`ruleExplore` → `ruleSearch` 的**整条**回落 | `docs/dev/book-source.md` §4.2 | ADR-0035 回链；模型字段归 §2 |
| `concurrentRate` 的语法、毫秒单位与「速率门 → 并发门」的合成顺序 | `docs/dev/book-source.md` §8 | ADR-0036 回链；默认并发上限数值仍归 §8 |
| `java.*` 兼容面：别名族的语义、规则求值族的两种形态（宿主内联 / 异步兜底）与具名拒绝清单 | `docs/dev/book-source.md` §6（形态表）与 §11（拒绝清单） | ADR-0037 回链 |
| 编码车道与「已声明车道」的宽容解码边界 | `docs/dev/book-source.md` §5 | C-NET-3 回链；决策理由归 `docs/dev/adr/0031-*.md` |
| 缓存失败吸收的唯一豁免点（`on Exception`） | `docs/dev/adr/0033-*.md` | C-ERR-2 回链；行为归 `book-source.md` §5 |
| 默认规则的未知类型退化语义（矩阵 #1/#2） | `docs/dev/book-source.md` §3 的 #1/#2 注记 | C-SRC-4 回链；决策理由归 `docs/dev/adr/0032-*.md` |
| 书源字段模型、语法矩阵、分期、JS 白名单与配额 | `docs/dev/book-source.md` | C-SRC-* 回链 |
| 实现顺序、验收、检查点（Gate）、返工陷阱、快速索引 | `docs/dev/roadmap.md` | — |
| 里程碑级状态（当前里程碑 / goal / 断点） | `PLAN.md`（`plan` 插件写入，不得手改） | `docs/dev/roadmap.md` §3.1 回链 |
| 执行期决策与踩坑日志（`#N`） | `DECISIONS.md` | 正式决策仍归 `docs/dev/adr/` |
| 变更历史与过程记录 | `CHANGELOG.md` | — |
| 贡献流程（分支 / Commit / PR / Review） | `CONTRIBUTING.md` | — |
| 文档语言约定 | 本文档 §7 | `CONTRIBUTING.md` 回链 |
| 许可证、版权、免责声明、GPL 义务、第三方许可清单 | `NOTICE.md` | `README.md`、`CONTRIBUTING.md` 回链 |
| 决策与理由 | `docs/dev/adr/` | 规范文档回链 ADR |

## 3. 决策记录（`docs/dev/adr/`）

| 路径 | 职责 |
|---|---|
| `docs/dev/adr/README.md` | ADR 索引与状态流转规则 |
| `docs/dev/adr/NNNN-*.md` | 单条决策：背景、选项、结论、后果 |

## 4. 仓库配置（根目录）

| 路径 | 职责 |
|---|---|
| `LICENSE` | GNU GPL-3.0 官方全文（项目许可证） |
| `NOTICE.md` | 版权、与上游 Legado 的关系、免责声明、GPL 合规义务、第三方依赖许可清单 |
| `.gitignore` | 忽略构建缓存与 IDE 文件；**生成文件仍需提交** |
| `.gitattributes` | 统一 LF，保证 `dart format` 门禁跨平台一致 |
| `pubspec.yaml` | 依赖声明；**唯一**依赖来源 |
| `analysis_options.yaml` | 静态分析与 lint；**唯一** lint 来源 |
| `build.yaml` | 代码生成器选项（当前只设 `json_serializable.checked: true`，理由见 ADR-0022）；**唯一**生成器选项来源 |
| `drift_schemas/` | `drift_dev schema dump` 出的历史 schema，供迁移测试逐列比对；改表后必须重新 dump（命令见 `docs/dev/tech-stack.md` §8） |
| `tool/coverage_allowlist.txt` | 覆盖率门禁豁免名单（ADR-0019），每条必须写明原因 |
| `tool/check_coverage.dart` | 覆盖率门禁脚本：阈值 + 「未测量源文件」两项判定（ADR-0019；阈值归 `docs/dev/testing.md` §2） |
| `tool/scan_licenses.dart` | 依赖许可证扫描脚本（重扫流程见 `NOTICE.md` §6） |
| `tool/spike/` | JS 引擎架构可行性探针与已知坑（ADR-0015；**不进入** `flutter test` 默认发现路径） |
| `tool/test/` | 本机测试脚本：`run_all` / `run_unit` / `run_windows` / `run_android` 与共享 `common.ps1`（见 `docs/dev/test-environment.md`） |
| `tool/spot_check/` | G2b 真实站点链路验证入口与实测记录（`docs/dev/roadmap.md` §3.4 步骤 3 / §3.7；可复现，**不进 CI**） |
| `integration_test/` | 设备级用例（Windows 桌面 / Android 模拟器）；不参与覆盖率统计（见 `docs/dev/test-environment.md` §4） |
| `l10n.yaml` | 国际化生成配置 |
| `lib/l10n/app_en.arb` | 英文文案模板（新增字符串的入口） |
| `lib/l10n/app_zh.arb` | 中文文案 |
| `.github/ISSUE_TEMPLATE/` | Issue 模板 |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR 描述模板 |
| `.github/workflows/ci.yml` | CI 流水线；执行**顺序**与 CI 特有步骤归 `docs/dev/testing.md` §7（命令本体归 `AGENTS.md` §4） |

---

## 5. 约束条目 ID 规则

`constraints.md` 中每条约束都带一个稳定 ID，格式为 `C-<组>-<序号>`：

| 组 | 含义 |
|---|---|
| `C-ARCH` | 架构与分层、依赖注入 |
| `C-STATE` | 状态管理 |
| `C-ERR` | 错误处理与异步 |
| `C-NET` | 网络与数据层 |
| `C-SRC` | 书源解析 |
| `C-UI` | 主题与 UI |
| `C-PLT` | 平台适配 |
| `C-TEST` | 测试与质量 |
| `C-DEP` | 依赖与代码生成 |
| `C-SEC` | 安全 |
| `C-PERF` | 性能 |
| `C-DOC` | 注释与文档 |
| `C-TYPE` | 类型与空安全 |
| `C-BAN` | 额外禁令 |

引用方式：`见 docs/dev/constraints.md C-ERR-2`。

**ID 稳定性规则：**
- ID 一旦分配**永不复用、永不重排**，新条目追加到组尾。
- 条目被废止时保留编号并标注 `~~C-XXX-n~~（已废弃，见 ADR-NNNN）`，
  不删除、不把编号让给新条目。
- 冲突裁决必须产出 ADR，并在相关条目上回链该 ADR。

---

## 6. 单一来源（SSOT）规则

1. **一个事实只允许定义一次。** 归属见 §2.1；需要复述时写引用而不是副本。
2. `AGENTS.md` 与 `CONTRIBUTING.md` 只放地图与流程，**不放规则正文**。
3. 同一份清单（提示词模板、自查清单、检查项）只保留一处；
   AI 提示词模板位于 `docs/dev/constraints.md` 末尾，其他文档只链接。
4. 需要机器执行的规则（lint、CI、脚本）必须落到 `analysis_options.yaml`、
   `AGENTS.md` §4 或 `docs/dev/testing.md` 声明的命令中，不允许只存在于散文里。
5. 修改任何规范时，必须同步检查：本文件的索引与 §2.1 矩阵、
   被引用条目的回链、以及 `docs/dev/adr/` 是否需要一个新决策记录。

---

## 7. 文档语言约定

| 场景 | 语言 |
|---|---|
| 文档注释 `///` | 英文 |
| 普通注释 `//` | 中文 |
| 规范文档正文 | 中文 |
| Commit message | 英文 |
| PR 描述 | 中文优先，关键术语保留英文 |
| CHANGELOG | 英文 |
