# ADR-0004 主题令牌以 `m3e_design` 为准，取色用 `dynamic_color`

- **状态：** Accepted
- **日期：** 2026-10-10（2026-10-10 按官方 API 修订）
- **关联：** C-UI-1、C-UI-2、C-UI-3、C-TYPE-2、C-PLT-2、`docs/dev/tech-stack.md` §3.1

## 背景

旧文档在主题与取色上有三处问题：

1. `TECH_STACK.md` 声明依赖 `dynamic_color`，而 `AGENT_CONSTRAINTS.md` §6 却要求
   「动态取色必须通过 `material_you_dynamic_theme`」——取色出现了两个真源。
2. `AGENT_CONSTRAINTS.md` §6 的示例写作 `Theme.of(context).extension<M3ETheme>()!`
   并访问 `theme.colorScheme` / `theme.textTheme.titleLarge`。
3. 该示例中的 `!` 强制解包违反 C-TYPE-2。

按官方 API 核实 `m3e_design` 0.2.1 后确认：`M3ETheme` 是**独立 ThemeExtension**，
成员为 `colors` / `typography` / `shapes` / `spacing` / `motion`，**不存在**
`colorScheme` 与 `textTheme`；旧示例**无法编译**。此外：

- 读取入口是 `ThemeData` 扩展 `Theme.of(context).m3e`（非空：debug 下 assert，
  release 下回退默认值），因此根本不需要 `!`。
- `M3ETypography` 是 `{required TextTheme base, required M3EEmphasized emphasized}`，
  取文本样式**必须经 `base`**：`typography.base.titleLarge`；
  原拟写法 `typography.titleLarge` **同样不存在**。
- `M3ESpacing` 为六阶：`xs=4`、`sm=8`、`md=12`、`lg=16`、`xl=24`、`xxl=32`。

## 决策

1. 设计令牌的**唯一来源**是 `m3e_design` 的 `M3ETheme`。
2. 安装经 `withM3ETheme(ThemeData)` 或 `ColorScheme.toM3EThemeData()`。
3. 读取统一使用 `Theme.of(context).m3e`；**禁止** `extension<M3ETheme>()!`。
4. 文本样式统一经 `m3e.typography.base.*`；间距统一经 `m3e.spacing.{xs..xxl}`。
5. 动态取色只使用 `dynamic_color` 的 `DynamicColorBuilder`；
   **禁止引入 `material_you_dynamic_theme`**。
6. 取色链路：`DynamicColorBuilder` → `ColorScheme` → `toM3EThemeData()` → `M3ETheme`；
   Windows / iOS 走种子色 fallback。

```dart
// lib/core/theme/app_theme.dart
ThemeData buildLightTheme(ColorScheme scheme) => scheme.toM3EThemeData();

// 使用侧
final m3e = Theme.of(context).m3e;
Container(
  color: m3e.colors.surface,
  padding: EdgeInsets.all(m3e.spacing.md),
  child: Text(
    AppLocalizations.of(context).bookSourceListTitle,
    style: m3e.typography.base.titleLarge,
  ),
);
```

## 后果

- `constraints.md` §6 示例与 `tech-stack.md` §3.1 已按官方 API 重写，
  并显式列出两个**不存在的成员**作为反例，避免再次被误用。
- `pubspec.yaml` 使用 `m3e_design: ^0.2.1` 与 **`dynamic_color: ^1.9.0`**。
  `m3e_design 0.2.1` 声明 `dynamic_color: ^1.8.1`，因此取色库**只能停在 1.x**；
  升到 2.x 会直接导致版本求解失败（已实测）。
- 读取入口推荐 `context.m3e`（`BuildContextM3EX` 扩展，自带 fallback，已用于 `lib/app.dart`）；
  `Theme.of(context).m3e` 亦可。所有 API 名称已对着 pub cache 中的**真实源码**逐项核对，
  不再依赖文档或记忆。
- Golden 测试必须固定种子色并禁用动态取色（`docs/dev/testing.md` §5）。
- 许可证：`m3e_design` 为 MIT、`dynamic_color` 为 Apache-2.0，均与 GPL-3.0 兼容（C-DEP-7）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 使用 `material_you_dynamic_theme` | 与 `dynamic_color` 职责重叠，产生两个取色真源 |
| 直接用 Flutter `ThemeData` + `ColorScheme` | 放弃 MD3E 的 spacing / motion / shapes 令牌，退回硬编码尺寸 |
| 继续沿用 `theme.colorScheme` / `theme.textTheme` 写法 | 该 API 不存在，代码无法编译 |
