# ADR-0012 文档单一来源（SSOT）与约束条目 ID 方案

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** `docs/README.md`、`AGENTS.md`、全部 `docs/dev/*.md`

## 背景

2026-10-10 的文档审计发现，4 份文档之间存在系统性重复，且**重复已经开始漂移**：

| 重复内容 | 副本数 | 已发生的漂移 |
|---|---|---|
| AI 提示词模板 | 3（`AGENTS.md` §5、`AGENT_CONSTRAINTS.md` §13、`NAMING_CONVENTION.md` §11） | 三份引用的路径各不相同且**全部错误** |
| AI 自查清单 | 3 | 覆盖率要求不一致（见 ADR-0013） |
| 禁止行为清单 | 3 | `AGENTS.md` 缺少 `debugPrint` 例外说明 |
| lint 规则 | 4（`errors` 段 / `linter` 段 / `custom_lint` 段 / 映射表）+ 命名规范 §10 | 7 个重复 YAML 键 + `avoid_non_null_assertion` 无效规则 |
| `pubspec.yaml` / `analysis_options.yaml` 正文 | 内嵌于 `TECH_STACK.md` | 与「根目录存在该文件」的引用矛盾 |

此外所有文档引用的路径均不存在：`AGENT.md`（实为 `AGENTS.md`）、
`docs/dev/NAMING_CONVENTIONS.md`（实为 `NAMING_CONVENTION.md`）、
`docs/dev/ADDITIONAL_CONSTRAINTS.md`（实为 `AGENT_CONSTRAINTS.md`）、
根 `CONTRIBUTING.md`（实为 `docs/github/CONTRIBUTING.md`，且该位置不被 GitHub 识别）。

## 决策

1. 文档树按 `docs/README.md` §2 重组；每份文档是**唯一**主题来源。
2. `AGENTS.md` 只保留「地图 + 工作流 + 门禁」，**≤120 行，零规范正文**。
3. 引入稳定条目 ID `C-<组>-<序号>`（规则见 `docs/README.md` §5）：
   ID 永不复用、永不重排；废止条目保留编号并回链 ADR。
4. 提示词模板与自查清单**各只保留一份**，位于 `docs/dev/constraints.md` §15–§16。
5. `pubspec.yaml`、`analysis_options.yaml`、`l10n.yaml` 为真实文件，
   文档只保留「为什么」与「与约束的映射」。
6. 删除被取代的旧文档：`docs/dev/NAMING_CONVENTION.md`、`docs/dev/AGENT_CONSTRAINTS.md`、
   `docs/dev/TECH_STACK.md`、`docs/github/CONTRIBUTING.md`
   （在 git 基线提交中可回溯）。

## 后果

- 所有跨文档引用改为「文件路径 + 条目 ID」，例如
  `见 docs/dev/constraints.md C-ERR-2`；散文式复述被禁止。
- `docs/README.md` 成为路径的**唯一权威**，新增文档必须先在索引登记。
- 修改规范的 PR 必须同时检查：索引、被引用条目的回链、是否需要新 ADR。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 只修路径，不改结构 | 重复仍在，漂移会再次发生 |
| 合并为单一大文档 | 单文件会膨胀到数百行，AI 代理与人都难以按需定位，且不利于 diff 评审 |
| 保留旧文件名（SCREAMING_SNAKE） | 与 `naming.md` §2 的 `snake_case` 约定不一致，且无法体现「docs/dev 下全小写」的一致性 |
