# ADR-0017 测试文件位置：在 `test/` 下镜像 `lib/` 路径

- **状态：** Accepted
- **日期：** 2026-10-11（同日修订：新增 §决策 5「设备级集成测试层」，登记 `integration_test/`）
- **关联：** C-TEST-4、C-TEST-7、`docs/dev/naming.md` §2、`docs/dev/testing.md` §1/§3/§7、`docs/dev/test-environment.md`、ADR-0009、ADR-0019

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
5. **设备级集成测试是独立的一层，放在 `integration_test/`，不镜像 `lib/`、不进 `test/`**：
   只有真实引擎与真实设备（Windows 桌面、Android 模拟器）才提供平台通道与原生 SQLite。
   `lib/core/di/database_executor_provider.dart` 这类「原生库 + 后台 isolate」的接线在宿主 VM 上
   **必然**抛 `Channel was closed before receiving a response`，放进 `test/` 既跑不过也测不到，
   只能靠替身，而替身覆盖的是替身自己、不是接线。
   该层入口为 `integration_test/*_test.dart`（文件名仍固定 `*_test.dart`，测试名仍为
   `方法名_场景_预期结果`），前提、命令与排错见 `docs/dev/test-environment.md`。
   它**不参与覆盖率统计**（不在 `lib/**` 下，`flutter test --coverage` 也不加载它），
   也**不进 CI**（`docs/dev/testing.md` §7 的命令清单不变）；接入 CI 必须另开 PR/ADR。

   > **2026-10-11 修订：** 本项是**新增的例外**，第 1–4 项原文不变。触发原因：搭建 Windows/Android
   > 测试环境时发现 `PLAN.md` 挂着的「文件型数据库（后台 isolate + 原生库）无自动化覆盖」只能由
   > 设备级用例闭环，而 C-TEST-4 的原文（「测试文件放在 `test/` 下」）会把这个目录判为违规。
   > 与 ADR-0013 的处理方式一致：**同一类缺陷并入本条 ADR，不另开新条**。
   > 配套登记：`constraints.md` C-TEST-4 加例外句；`testing.md` §1 加第 5 行、§3 按层区分措辞；
   > `naming.md` §2 同步；`docs/dev/test-environment.md` 记录运行方式与条件。

## 后果

- C-TEST-4、`naming.md` §2、`testing.md` §1/§3 的措辞同步修正为「镜像路径」。
- 既有 `test/app_test.dart` 无需迁移（`lib/app.dart` 的镜像路径就是 `test/app_test.dart`）。
- 新增「测试目录结构」的机器可验证性由 ADR-0019 的未测量文件检查间接保证，
  不再依赖评审者的记忆。
- **设备级集成测试是 `test/` 之外唯一的测试目录**：新增测试默认仍放 `test/` 镜像路径；
  只有当用例必须依赖真实引擎 / 平台通道 / 原生库时才放 `integration_test/`，并在 PR 中引用
  本 ADR §决策 5。C-TEST-4、`naming.md` §2、`testing.md` §1/§3 已按这一区分同步措辞。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 保留「同目录」，把测试放进 `lib/` | 需要改 `flutter test` 的发现路径与产物排除规则；测试会被打进发布产物，且 CI 覆盖率统计与 `analysis_options.yaml` 排除项全部需要特例 |
| 测试全部平铺在 `test/` 根目录 | 文件规模增长后无法按 feature 定位，也无法与 `lib/` 的 feature-first 结构对应 |
| 改用 `integration_test/` 承载全部测试 | 需要新增 `integration_test` 依赖（C-DEP-1 需评审），且单元测试不必依赖设备。**注：本行否决的是「承载全部测试」；设备级专层由 §决策 5（2026-10-11 修订）单独授权。** |
| 设备级用例也放进 `test/`（用替身模拟平台通道与原生库） | 宿主 VM 里 `database_executor_provider.dart` 必抛 `Channel was closed before receiving a response`，替身覆盖的是替身本身而不是接线；且会把只能在设备上执行的代码带进 `flutter test --coverage` 的输入，让覆盖率结论失真 |
