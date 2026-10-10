# ADR-0009 Golden 测试使用内置 `matchesGoldenFile`

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-TEST-6、`docs/dev/testing.md` §5

## 背景

`TECH_STACK.md` §1.7 引入 `golden_toolkit: ^0.15.0`，但该包已**停止维护**，
社区已迁移到 `alchemist` 或 Flutter 内置的 `matchesGoldenFile`。
同时 `AGENT_CONSTRAINTS.md` §8 只写「建议加 Golden 测试」，未定义基线尺寸、
主题与动画处理方式 —— 缺少这些固定条件会导致 Golden 测试随机失败。

## 决策

1. **移除 `golden_toolkit`**，改用 Flutter 内置 `matchesGoldenFile`。
2. 基线目录：`test/golden/<feature>/<widget_name>.png`。
3. 每个 Golden 测试必须固定：视图尺寸 `1080x1920`、`devicePixelRatio = 1.0`、
   固定种子色主题、禁用动态取色、`pumpAndSettle` 后截图。
4. Golden 基线更新必须单独 PR 并说明视觉变更原因。
5. Golden 测试只在 CI 的单一平台（`ubuntu-latest`）运行，避免字体差异。

## 后果

- `pubspec.yaml` 不再包含 `golden_toolkit`；测试不再依赖第三方 golden 框架。
- 缺少 `golden_toolkit` 的 `loadAppFonts` 等便利函数，需要自定义字体加载；
  若确需该能力，必须新开 ADR 评估 `alchemist`，不得直接加回已停维护的包。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 保留 `golden_toolkit` | 已停止维护，与 Flutter 3.47 的兼容性无保障 |
| 改用 `alchemist` | 能力更强但引入新依赖，需走 C-DEP-1 评审；当前内置方案已足够 |
| 不做 Golden 测试 | 无法保证 MD3E 令牌改造的视觉一致性，也失去硬编码颜色的兜底检查 |
