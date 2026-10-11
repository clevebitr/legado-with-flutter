# ADR-0013 门禁阈值与版本基线各自只有一处定义

- **状态：** Accepted
- **日期：** 2026-10-10（2026-10-11 修订：增加「门禁命令清单」与「生成命令基线」两条唯一出处）
- **关联：** C-TEST-1、C-TEST-7、C-PLT-5、C-DEP-4、`docs/dev/testing.md` §2/§7、`docs/dev/platform.md` §1、`docs/dev/tech-stack.md` §1、`AGENTS.md` §4、ADR-0018、ADR-0019

## 背景

三处「同一事实、两个数值」的冲突：

| 事实 | 副本 A | 副本 B |
|---|---|---|
| 覆盖率门禁 | `AGENTS.md` §4：`core/` 与 `domain/` 100%（缺 `data/`） | `AGENT_CONSTRAINTS.md` §8：追加 `data/` ≥80% |
| Flutter 版本 | `CONTRIBUTING.md` §3.1：「最新稳定版」 | `TECH_STACK.md` §1.1：精确 `3.47.0` |
| 平台基线 | 无（`AGENT_CONSTRAINTS.md` §6 只提到需要在 AndroidManifest 开启开关） | 无（原文档完全没有 minSdk / targetSdk 数值） |

覆盖率阈值还有一个执行层面的缺口：原文档只写「必须 100%」，但没有任何工具实现该判定。

## 决策

1. **覆盖率**：`core/` 100%、`domain/` 100%（匹配 `lib/features/*/domain/`）、`data/` ≥80%。
   唯一出处为 `docs/dev/testing.md` §2，由 `tool/check_coverage.dart` **强制执行**。
   阈值可用 CLI 上调，**禁止下调**；下调必须新开 ADR。
2. **版本基线**：唯一出处为 `docs/dev/tech-stack.md` §1。
   `CONTRIBUTING.md` 不再写「最新稳定版」，改为链接该节。
3. **平台基线**：唯一出处为 `docs/dev/platform.md` §1；其他文档一律引用 C-PLT-5
   不得复述数值（本节初版曾在括号内复述 `minSdk 26` / `targetSdk 35` / `iOS 13.0`，
   该复述已漂移并删除 —— 复述本身就是违规，即使当时数值是对的）。
4. 上述三节的数值变更是**规范变更**，必须走 ADR 流程。
5. **门禁命令清单**：唯一出处为 `AGENTS.md` §4。`docs/dev/testing.md` §7 只定义
   **CI 的执行顺序与 CI 特有步骤**，不得再抄一份命令本体；
   `.github/PULL_REQUEST_TEMPLATE.md`、`README.md`、`CONTRIBUTING.md`、
   `docs/dev/constraints.md` §16 一律回链，不再复述命令块。
6. **生成命令基线**：`build_runner` 的调用形态唯一出处为 C-DEP-4。
   实测 `build_runner 2.16.2` 已移除 `--delete-conflicting-outputs`
   （该参数会被忽略并打印
   `These options have been removed and were ignored: --delete-conflicting-outputs`），
   因此 C-DEP-4 的命令更新为 `dart run build_runner build`；
   需要「删除冲突输出」语义时由 build_runner 自身默认行为保证。
   升级 `build_runner` 后必须重新核对本项。

> **本次修订的触发原因：** 2026-10-11 的门禁审计发现门禁命令清单在 6 个位置各写一份、
> 内容已不一致（`AGENTS.md` §4 缺 `--coverage` 与覆盖率门禁、`docs/dev/constraints.md`
> §16 仍在要求已被删除的 `custom_lint`），且生成命令携带一个已失效的参数。
> 这与本条 ADR 确立的原则（同一事实只有一处定义）是同一类缺陷，故并入本条而非新开 ADR。

## 后果

- `CI` 增加 `dart run tool/check_coverage.dart` 步骤，使覆盖率约束可执行（原为纯散文）。
- 门禁命令本体只存于 `AGENTS.md` §4；CI 顺序只存于 `testing.md` §7；
  两者出现分歧时以 §4 为命令来源、以 §7 为顺序来源，并在同一 PR 内修正。
- `platform.md` §1 标注了「需在生成平台工程后核对并回写」的验证状态 ——
  这是唯一允许的未验证数值，且已有回写要求。
- 任何 PR 若在两处写下同一个数值，评审时视为缺陷。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 覆盖率只用文档约束、不加脚本 | 无人执行，等同不存在；且 `data/` 阈值无法验证 |
| 覆盖率阈值写在 CI YAML 里 | YAML 表达多阈值逻辑会变复杂，且无法给出「哪些文件拖后腿」的清单 |
| 保留 `CONTRIBUTING.md` 的「最新稳定版」 | 与精确版本策略冲突，环境不可复现 |
