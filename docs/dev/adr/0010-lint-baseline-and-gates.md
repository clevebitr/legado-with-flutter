# ADR-0010 lint 基线、无效规则清理与门禁入口

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-BAN-15、C-TEST-7、ADR-0001、`analysis_options.yaml`、`docs/dev/tech-stack.md` §12

## 背景

审计发现 `TECH_STACK.md` 内嵌的 `analysis_options.yaml` 无法使用：

1. `linter.rules` 中存在 **7 个重复 YAML 键**（`avoid_print`、`avoid_dynamic_calls`、
   `use_build_context_synchronously`、`unused_element`、`unused_local_variable`、
   `unused_import`、`prefer_const_constructors_in_immutables`）——重复键会导致解析失败。
2. `avoid_non_null_assertion` **不是 Dart 官方核心 lint**（属 DCM / `fd_lints` 等第三方包），
   写在 `linter.rules` 中会产生 "invalid rule" 警告。
3. `require_trailing_commas` 与 Dart ≥3.7 的 tall-style 格式化互相冲突。
4. `custom_lint` 插件规则**不会**在 `flutter analyze` 中执行，但门禁只写了 `flutter analyze`。
5. `analysis_options.yaml` 只以文档代码块形式存在，项目根目录没有真实文件。

## 决策

1. `analysis_options.yaml` 抽为**真实文件**，并成为 lint 规则的唯一来源。
2. 删除全部重复键；`avoid_returning_this: false` 一并移除（已废弃规则，无意义）。
3. **不启用** `avoid_non_null_assertion`：禁止 `!` 改由 C-TYPE-2 + Code review 保障。
4. **不启用** `require_trailing_commas`：交给 `dart format` 决定。
5. 门禁同时包含 `flutter analyze` 与 `dart run custom_lint`；两者缺一视为未通过。
6. **待办（验证项）：** `pubspec.yaml` 中的版本约束未经 `flutter pub get` 验证
   （编写环境无 Flutter SDK）。首次解析后必须核对并回写 `tech-stack.md`；
   若某个 lint 规则名在目标 Dart 版本中无效，必须新开 ADR 而不是静默删除。

## 后果

- `docs/dev/tech-stack.md` §12 维护「lint 规则 ↔ 约束 ID」映射，不再内嵌 YAML 正文。
- 「无法 lint、只能人工保障」的约束必须在 PR 自查中显式声明（同 §12 表）。
- CI 增加了生成物一致性检查与覆盖率门禁两步。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 保留内嵌 YAML，只去重 | 无法被工具读取，lint 实际不生效 |
| 启用 `avoid_non_null_assertion` 并加第三方 lint 包 | 引入新依赖与新的失效风险，收益与 C-TYPE-2 重叠 |
| 把 custom_lint 规则降级为「可选」 | 会让 C-STATE-2 失去强制力 |
