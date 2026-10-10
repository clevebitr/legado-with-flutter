# ADR-0010 lint 基线、无效规则清理与门禁入口

- **状态：** Accepted
- **日期：** 2026-10-10（2026-10-10 修订插件执行方式）
- **关联：** C-BAN-15、C-TEST-7、C-STATE-2、`analysis_options.yaml`、`docs/dev/tech-stack.md` §12

## 背景

审计发现 `TECH_STACK.md` 内嵌的 `analysis_options.yaml` 无法使用：

1. `linter.rules` 中存在 **7 个重复 YAML 键**（`avoid_print`、`avoid_dynamic_calls`、
   `use_build_context_synchronously`、`unused_element`、`unused_local_variable`、
   `unused_import`、`prefer_const_constructors_in_immutables`）——重复键会导致解析失败。
2. `avoid_non_null_assertion` **不是 Dart 官方核心 lint**（属 DCM / `fd_lints` 等第三方包），
   写入 `linter.rules` 中会产生 "invalid rule" 警告。
3. `require_trailing_commas` 与 Dart ≥3.7 的 tall-style 格式化互相冲突。
4. 文档声称「门禁 = `flutter analyze`」，但同时又要求跑 `dart run custom_lint`，
   两处对「谁来执行插件规则」的说法不一致。
5. `analysis_options.yaml` 只以文档代码块形式存在，项目根目录没有真实文件。

**后续核实（修订原因）：** `riverpod_lint` 自 **3.1.9** 起**不再基于 `custom_lint`**，
改为 `analysis_server_plugin` 实现，通过 `analysis_options.yaml` 的 `analyzer.plugins`
安装并**由 `flutter analyze` 执行**。因此项目**不需要、也不应引入 `custom_lint`**。

## 决策

1. `analysis_options.yaml` 抽为**真实文件**，并成为 lint 规则的唯一来源。
2. 删除全部重复键；移除 `avoid_returning_this: false`（已废弃规则）。
3. **不启用** `avoid_non_null_assertion`：禁止 `!` 由 C-TYPE-2 + Code review 保障。
4. **不启用** `require_trailing_commas`：交给 `dart format` 决定。
5. **移除 `custom_lint` 依赖与配置**；`riverpod_lint: ^3.1.9` 只出现在
   `analyzer.plugins`。门禁中的插件规则由 `flutter analyze` 执行。
6. CI 门禁不再包含 `dart run custom_lint` 步骤。
7. **待验证项：** `pubspec.yaml` 的版本约束尚未在本机 `flutter pub get` 验证
   （编写环境无 Flutter SDK）。首次解析后必须核对并回写 `tech-stack.md`；
   若某个 lint 规则名在目标 Dart 版本中无效，必须新开 ADR 而不是静默删除。

## 后果

- `docs/dev/tech-stack.md` §12 维护「lint 规则 ↔ 约束 ID」映射，不再内嵌 YAML 正文。
- 「无法 lint、只能人工保障」的约束必须在 PR 自查中显式声明（同 §12 表）。
- 门禁顺序：`format` → `flutter analyze` → `test` → `build_runner` 一致性检查 → 覆盖率。
- 若将来需要项目自定义规则（例如禁止硬编码颜色的 `avoid_hardcoded_colors`），
  应先评估 `analysis_server_plugin` 生态，再决定是否重新引入 `custom_lint` 并更新本 ADR。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 保留内嵌 YAML，只去重 | 无法被工具读取，lint 实际不生效 |
| 同时保留 `custom_lint` 与 `analyzer.plugins` | 两套插件机制并存，规则来源与执行时机不可预测 |
| 继续要求 `dart run custom_lint` | `riverpod_lint` 已不再支持该入口，命令会失效 |
| 启用 `avoid_non_null_assertion` 并加第三方 lint 包 | 引入新依赖与新的失效风险，收益与 C-TYPE-2 重叠 |
