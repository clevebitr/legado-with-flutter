# ADR-0004 主题令牌以 `m3e_design` 为准，取色用 `dynamic_color`

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-UI-1、C-UI-2、C-UI-3、C-PLT-2、`docs/dev/tech-stack.md` §3

## 背景

旧文档在主题与取色上有三处问题：

1. `TECH_STACK.md` 声明依赖 `dynamic_color`，而 `AGENT_CONSTRAINTS.md` §6 却要求
   「动态取色必须通过 `material_you_dynamic_theme`」——取色出现了两个真源。
2. `AGENT_CONSTRAINTS.md` §6 的示例写作 `Theme.of(context).extension<M3ETheme>()!`
   并访问 `theme.colorScheme` / `theme.textTheme.titleLarge`。
   经核实（`m3e_design` 0.2.1），`M3ETheme` 是**独立 ThemeExtension**，
   其成员是 `colors` / `typography` / `shapes` / `spacing` / `motion`，
   **不存在** `colorScheme` / `textTheme`；示例无法编译。
   同时 `!` 强制解包违反 C-TYPE-2。

## 决策

1. 设计令牌的**唯一来源**是 `m3e_design` 的 `M3ETheme`。
2. 安装经 `withM3ETheme(ThemeData)` 或 `ColorScheme.toM3EThemeData()`。
3. 读取统一使用 `Theme.of(context).m3e`（`ThemeData` 扩展，非空：debug 下 assert，
   release 下回退默认值），**禁止** `extension<M3ETheme>()!`。
4. 动态取色只使用 `dynamic_color` 的 `DynamicColorBuilder`；
   **禁止引入 `material_you_dynamic_theme`**。
5. 取色链路：`DynamicColorBuilder` → `ColorScheme` → `toM3EThemeData()` → `M3ETheme`。
   Windows / iOS 走种子色 fallback。

## 后果

- `constraints.md` §6 示例已按真实 API 重写，并标注
  「`M3ESpacing` / `M3ETypography` 成员名以 IDE 补全为准，首次接入时回写本文档」。
- `pubspec.yaml` 保留 `m3e_design: ^0.2.0` 与 `dynamic_color: ^2.1.0`。
- Golden 测试必须固定种子色并禁用动态取色（`docs/dev/testing.md` §5）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 使用 `material_you_dynamic_theme` | 与 `dynamic_color` 职责重叠，产生两个取色真源 |
| 直接用 Flutter `ThemeData` + `ColorScheme` | 放弃 MD3E 的 spacing / motion / shapes 令牌，退回硬编码尺寸 |
| `dynamic_color` 与 `m3e_design` 各自独立取色 | 无法保证色值与令牌同源，主题切换会出现色偏 |
