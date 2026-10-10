# ADR-0005 不引入 `get_it`，依赖注入统一 Riverpod

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-ARCH-3、ADR-0001、`docs/dev/architecture.md` §4

## 背景

`AGENT_CONSTRAINTS.md` §1 写「使用 `get_it` **或** Riverpod 的 Provider 进行依赖注入」，
但 `TECH_STACK.md` 的依赖清单中没有 `get_it`。同时 ADR-0001 已确定状态管理唯一方案为 Riverpod，
再引入服务定位器会让「依赖从哪来」出现两条路径。

## 决策

1. **禁止引入 `get_it`**（及其等价服务定位器）。
2. 依赖注入统一通过 `@riverpod` Provider：
   - 基础设施位于 `lib/core/di/`；
   - feature 级仓储与用例位于 `lib/features/<f>/di.dart`。
3. 测试通过 `ProviderScope(overrides: [...])` 注入替身，禁止在实现代码里为测试开分支。

## 后果

- `constraints.md` C-ARCH-3 明确列出 `get_it` 为禁止依赖。
- 所有可替换依赖（`HttpClient`、`Clock`、`Logger`、`JsBridge`）必须暴露为 Provider。
- 单例生命周期由 Riverpod 的 `keepAlive` 语义管理，不再有第二套生命周期规则。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 同时允许 `get_it` | 两套 DI 机制并存，测试需要同时覆盖 Provider 与 locate 注册 |
| 全部使用 `get_it`，Riverpod 只管状态 | 与 ADR-0001 冲突，且 Riverpod 的 override 机制会失去作用 |
| 手写构造函数注入 + 全局 `AppDependencies` | 需要自建 override 机制，重造 Riverpod 已有能力 |
