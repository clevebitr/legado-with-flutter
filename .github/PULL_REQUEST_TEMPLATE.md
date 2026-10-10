## 变更说明

<!-- 用一到两句话说明这个 PR 做了什么、为什么。 -->

## 关联 Issue

Closes #

## 变更类型

- [ ] `feat` 新功能
- [ ] `fix` Bug 修复
- [ ] `docs` 文档
- [ ] `refactor` 重构（不改变行为）
- [ ] `test` 测试
- [ ] `perf` 性能
- [ ] `chore` 构建 / 工具链

## 影响范围

- [ ] `presentation`
- [ ] `domain`
- [ ] `data`
- [ ] `core`
- [ ] 平台代码（Android / iOS / Windows）
- [ ] 文档 / 配置 / CI

## 门禁结果

<!-- 逐条粘贴实际结果，不要只写「已通过」。 -->

- [ ] `dart format --set-exit-if-changed .`
- [ ] `flutter analyze` 零警告（含 `analyzer.plugins` 的 riverpod_lint 规则）
- [ ] `flutter test --coverage`
- [ ] `dart run tool/check_coverage.dart`
- [ ] `dart run build_runner build --delete-conflicting-outputs` 后无生成物差异

## 规范自查

- [ ] 已逐项核对 [`docs/dev/constraints.md`](../docs/dev/constraints.md) §15 自查清单
- [ ] 公共 API 有英文 `///` 文档注释，复杂逻辑有中文 `//` 说明
- [ ] 未硬编码颜色 / 尺寸 / 用户可见字符串 / 密钥
- [ ] 新增文案已同时更新 `lib/l10n/app_en.arb` 与 `lib/l10n/app_zh.arb`
- [ ] 未手改 `*.g.dart` / `*.freezed.dart` / `*.gr.dart`

## 决策记录

- [ ] 本 PR 未推翻任何既有决策
- [ ] 本 PR 推翻了既有决策，已新增 ADR：`docs/dev/adr/NNNN-...md`

## 平台验证（涉及平台行为时填写）

- [ ] Android：预测性返回预览动画正常
- [ ] Android：动态取色（12+）与种子色 fallback（8–11）均正常
- [ ] iOS：边缘返回手势正常，无动态取色相关崩溃
- [ ] Windows：主题正常，数据写入 `getApplicationSupportDirectory()`

## 截图 / 录屏

<!-- UI 变更必须附「变更前 / 变更后」对比图。 -->

## 备注

<!-- 已知限制、后续工作、需要 Reviewer 特别关注的点。 -->
