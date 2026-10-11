# ADR-0017 测试文件位置：在 `test/` 下镜像 `lib/` 路径

- **状态：** Accepted
- **日期：** 2026-10-11
- **关联：** C-TEST-4、`docs/dev/naming.md` §2、`docs/dev/testing.md` §1/§3/§7、ADR-0009

## 背景

`naming.md` §2 与 C-TEST-4 写「测试文件与被测文件**同目录**，文件名 `*_test.dart`」。
Phase 1.1 的测试实际放在 `test/core/error/parse_result_test.dart`，被测文件在
`lib/core/error/parse_result.dart` —— 按字面理解属于违规。复核既有代码发现
`test/app_test.dart`（被测 `lib/app.dart`）同样不满足该字面要求。

进一步核查后确认**规则本身不可执行**：

1. `flutter test` 默认只发现并运行 `test/` 下的测试；放进 `lib/` 的测试要么需要额外参数，
   要么根本不会被执行，门禁会静默漏测。
2. `lib/**` 会被打进应用产物（AOT/内核文件）。测试文件进入发布产物既是体积问题，
   也可能把测试专用的断言与字符串带到用户设备上。
3. `.gitignore`、`analysis_options.yaml` 的排除项、CI 的 `--coverage` 路径统计都默认
   `lib/` 只含生产代码。

因此「与被测文件同目录」是一条**无法同时满足工具链与门禁**的规范，需要修正。

## 决策

1. 测试文件放在 **`test/` 目录下，镜像被测文件的 `lib/` 相对路径**：
   `lib/core/error/parse_result.dart` → `test/core/error/parse_result_test.dart`；
   `lib/features/reader/data/xxx.dart` → `test/features/reader/data/xxx_test.dart`。
2. 文件名仍为 `*_test.dart`，测试名仍为 `方法名_场景_预期结果`（C-TEST-3 不变）。
3. `lib/**` 下**禁止**出现 `*_test.dart`；CI 的门禁不依赖人工检查这一点，而是由
   「覆盖率门禁的文件枚举」天然兜住：`lib/` 下的测试文件不会被 `test/` 的覆盖率报告覆盖，
   会被 ADR-0019 的「未测量源文件」检查直接判失败。
4. 集成回放语料与 Golden 基线位置不变（`test/fixtures/`、`test/golden/`，
   见 `docs/dev/testing.md` §1/§5）。

## 后果

- C-TEST-4、`naming.md` §2、`testing.md` §1/§3 的措辞同步修正为「镜像路径」。
- 既有 `test/app_test.dart` 无需迁移（`lib/app.dart` 的镜像路径就是 `test/app_test.dart`）。
- 新增「测试目录结构」的机器可验证性由 ADR-0019 的未测量文件检查间接保证，
  不再依赖评审者的记忆。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 保留「同目录」，把测试放进 `lib/` | 需要改 `flutter test` 的发现路径与产物排除规则；测试会被打进发布产物，且 CI 覆盖率统计与 `analysis_options.yaml` 排除项全部需要特例 |
| 测试全部平铺在 `test/` 根目录 | 文件规模增长后无法按 feature 定位，也无法与 `lib/` 的 feature-first 结构对应 |
| 改用 `integration_test/` 承载全部测试 | 需要新增 `integration_test` 依赖（C-DEP-1 需评审），且单元测试不必依赖设备 |
