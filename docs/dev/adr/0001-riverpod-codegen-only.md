# ADR-0001 状态管理只使用 Riverpod，Provider 必须代码生成

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-STATE-1..6、`docs/dev/naming.md` §6、ADR-0005、ADR-0010

## 背景

审计发现三处互相矛盾的表述：

1. `AGENTS.md` 写「统一 Riverpod」，`AGENT_CONSTRAINTS.md` §2 写「Riverpod（推荐）或 Bloc」。
2. `AGENT_CONSTRAINTS.md` §2 给出**手写** `AsyncNotifier` 示例，而 `TECH_STACK.md` 同时
   引入 `riverpod_generator` 并启用 `riverpod_lint` 的
   `avoid_manual_providers_as_generated_provider_dependency` —— 示例被自己的 lint 禁止。
3. 命名规范要求 `XxxViewModel` + `presentation/viewmodels/`，与 Riverpod 的
   `Notifier` / `Provider` 生成物命名不一致。

## 决策

1. 状态管理**唯一方案**为 Riverpod；Bloc / GetX / `package:provider` / `mobx` 禁止引入。
2. 所有 Provider 必须由 `@riverpod` 代码生成；**禁止手写** `Provider` / `Notifier` / `AsyncNotifier`。
3. 命名统一为 `XxxNotifier`，文件 `xxx_notifier.dart`，位置 `presentation/notifiers/`。
   `XxxViewModel` 与 `presentation/viewmodels/` **废弃**。
4. Riverpod 3 的统一引用类型为 `Ref`，不再出现 `XxxRef`。

## 后果

- `AGENT_CONSTRAINTS.md` §2 的手写示例已被替换为 `@riverpod` 示例。
- `naming.md` §6 注明 ViewModel 命名废弃并回链本 ADR。
- 新增 `riverpod_generator`、`riverpod_lint` 到 `pubspec.yaml`。
  > **2026-10-11 修订：** 本项原文还包括 `custom_lint`；它已按 ADR-0010 §5 移除，
  > `riverpod_lint ≥3.1.9` 改为由 `analysis_options.yaml` 顶层 `plugins:` 安装。
- 生成物 `*.g.dart` 必须随源码提交，由 CI 的一致性检查保障（ADR-0010）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 允许手写 Provider | 会同时存在两种写法，`riverpod_lint` 规则失效，评审成本升高 |
| 允许 Riverpod 或 Bloc 二选一 | 同一项目两套状态模型，无法形成统一约定 |
| 保留 `XxxViewModel` 命名 | 与代码生成产物命名冲突，且 `viewmodels/` 目录名暗示非 Riverpod 写法 |
