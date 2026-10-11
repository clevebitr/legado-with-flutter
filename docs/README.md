# 文档索引

> **本文件是项目内所有文档路径的唯一权威。** 任何文档引用其他文档时，以本表为准。
> 若发现某处引用的路径不在本表中，视为缺陷，请修正引用而不是新增副本。

---

## 1. 入口类文档

| 路径 | 职责 | 谁需要读 |
|---|---|---|
| `AGENTS.md` | AI 代理入口：工作流 + 门禁 + 文档地图（≤120 行，零规范正文） | 所有 AI 代理、贡献者 |
| `PLAN.md` | **实现顺序、验收标准与检查点**（只讲先做什么、怎么验收，不复述规则） | 开始任何功能开发前 |
| `CONTRIBUTING.md` | 贡献流程：分支、Commit、PR、Review、语言约定 | 所有贡献者 |
| `README.md` | 项目简介、快速开始、构建与运行 | 使用者、贡献者 |
| `CHANGELOG.md` | 破坏性变更与版本记录 | 贡献者、发布负责人 |

## 2. 规范类文档（`docs/dev/`，每份都是该主题的唯一来源）

| 路径 | 职责 | 条目 ID 前缀 |
|---|---|---|
| `docs/dev/naming.md` | 文件、类、方法、变量、API、注释的命名规范 | — |
| `docs/dev/constraints.md` | 架构、状态、错误、网络、书源、UI、平台、测试、安全、性能约束 | `C-*` |
| `docs/dev/tech-stack.md` | 依赖清单与版本、lint 与约束 ID 的映射、国际化配置 | — |
| `docs/dev/architecture.md` | 目录结构、分层边界、依赖注入、路由 | `C-ARCH-*` |
| `docs/dev/book-source.md` | Legado 书源规则支持矩阵、模板语法、失败语义、测试基线 | `C-SRC-*` |
| `docs/dev/testing.md` | 测试分层、覆盖率门禁、Golden 策略、CI 流水线 | `C-TEST-*` |
| `docs/dev/platform.md` | Android / iOS / Windows 平台基线与降级策略 | `C-PLT-*` |

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

1. **一个事实只允许定义一次。** 需要复述时，写引用而不是副本。
2. `AGENTS.md` 与 `CONTRIBUTING.md` 只放地图与流程，**不放规则正文**。
3. 同一份清单（提示词模板、自查清单、检查项）只保留一处；
   AI 提示词模板位于 `docs/dev/constraints.md` 末尾，其他文档只链接。
4. 需要机器执行的规则（lint、CI、脚本）必须落到 `analysis_options.yaml`、
   `AGENTS.md` §4 或 `docs/dev/testing.md` 声明的命令中，不允许只存在于散文里。
5. 修改任何规范时，必须同步检查：`docs/README.md` 索引、
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

---

**文档版本：** v2.0 · **最后更新：** 2026-10-11
