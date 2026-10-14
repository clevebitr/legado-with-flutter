# ADR-0038 设备级探针的执行时点：按阶段出口，不按切片

- **状态：** **Superseded by ADR-0039**（2026-10-13：本决策的代价前提——Android 单次 ≥ 30 分钟——
  在 `run_android.ps1` 重写后降到 2 分钟级，切片级恢复双端；原文保留，理由见 ADR-0039）
- **日期：** 2026-10-13
- **关联：** ADR-0017（测试文件位置）、ADR-0019（覆盖率门禁）、`docs/dev/testing.md` §1（测试分层）、
  `docs/dev/test-environment.md` §1/§3/§7（设备级用例、脚本与实测证据）、`PLAN.md` §4（G7）

## 背景

设备级用例（`integration_test/`，Windows 桌面 + Android 模拟器）从 Phase 2 起就是**切片级验收项**：
`PLAN.md` §3.5 的每一行都写着「双端设备探针实跑」。这条要求在 M1 阶段开始失衡：

| 事实 | 数字 |
|---|---|
| Android 单次完整跑（建 APK + 冷启 AVD + 逐文件 `flutter test`） | **≥ 30 分钟**（2026-10-13 实测，`Medium_Phone`，API 37） |
| Windows 单次完整跑（复用已构建的 exe） | 约 **2 分钟** |
| M1 切片数（b1–b4b + b1b 返工） | 8 次交付 |
| 设备级用例实际盯住的东西 | 平台通道（`path_provider` / `dynamic_color`）、原生 SQLite + 后台 isolate、**真实 QuickJS 引擎**的绑定与沙箱行为 |

也就是说：**Android 与 Windows 跑的是同一份 Dart 代码、同一份 `flutter_qjs_next` 原生引擎**，
两侧的差异只在平台通道与原生 SQLite 的加载路径——而那两件事与绝大多数切片（规则语法、模型、
解析引擎）无关。同时，切片级的**主机侧**门禁已经很强：`AGENTS.md` §4 的六条命令含
`flutter test --coverage`（674 用例上下的全套单测 + Widget 测试）与「未测量源文件」判定
（ADR-0019，`lib/core/**`、`domain/**` 100%），`integration_test/` 的用例本身不在覆盖率统计里，
但它们断言的行为大多已被主机侧单测覆盖，设备侧多出来的是**引擎与平台通道真的能跑起来**。

代价落在**开发组的迭代速度**上：每个切片末尾多等 30 分钟以上，且失败原因常是环境
（模拟器启动、native assets 下载超时，见 `test-environment.md` §6），与代码无关。

## 决策

1. **切片级（每个 `PLAN.md` §3.5 的行，含返工）**：设备级探针**至少跑 Windows** 一次并记录；
   **Android 不再强制**。切片验收列写「Windows 实跑」而不是「双端实跑」。
2. **阶段出口（离开任一 Phase 之前）**：`integration_test/` 的**全部**用例必须在
   **Windows 与 Android 各实跑一次**且退出码 0，命令与结果写进 `test-environment.md` §7——
   它同时是 `PLAN.md` §4 的 **G7**。
3. **例外（切片级也要跑对应平台）**：切片若改动 `lib/core/platform/**`、原生插件配置
   （`android/` / `windows/` / `ios/`）或 `integration_test/` 自身，则该平台必须在本切片实跑；
   Android 侧的改动同样如此，不适用第 1 条。
4. **谁跑**：阶段出口那次由**阶段收口人**（架构师复核）执行；开发组可随时自行复跑。
5. **执行命令与脚本仍只有一处定义**：`docs/dev/test-environment.md` §3（本文档不复述命令）。

## 后果

- `PLAN.md` §4 新增 **G7**（阶段出口的设备级探针），§3.5 的新切片行只要求 Windows；
  既有已完成的切片行不改（它们当时确实跑过双端，属历史证据）。
- `docs/dev/testing.md` §1 的「设备级集成测试」行补一条回链：**执行时点**归
  `docs/dev/test-environment.md`，理由归本 ADR；`testing.md` §7 的 CI 口径不变（设备级仍不进 CI）。
- `docs/dev/test-environment.md` §1/§7 增列一句「执行时点」并指向本 ADR。
- `docs/README.md` §2.1 的事实行「本机测试环境、脚本、设备级用例、实测证据」扩为
  「…设备级用例**及其执行时点**…」，归属仍是 `test-environment.md`。
- **不改动任何 `C-*`**：设备级探针从来不在 `constraints.md` §8 的条目里（那里的 C-TEST-* 只管
  覆盖率门禁、Widget smoke、命名与位置、CI 命令清单），所以本决策没有可回链的约束条目——
  它约束的是 `PLAN.md` 的验收列与 `test-environment.md` 的口径。
- **风险与重开条件**：Android 侧的回归窗口从「每切片」变成「每阶段」（Phase 4 约 8 个切片）。
  若出现「Windows 通过但 Android 失败」的实例（例如平台通道或原生加载差异导致
  `integration_test/` 在模拟器上失败而桌面通过），立即回到切片级双端，并在此处登记该实例。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 保持切片级双端（现状） | 每个切片 30+ 分钟，M1 阶段共 8 次 ≈ 4 小时以上的等待，换来的信息与 Windows 高度重复；失败多来自环境而非代码 |
| 只跑 Windows（不再要求 Android） | Android 是**发布目标平台**，平台通道与原生 SQLite 的加载路径只在真机/模拟器上成立；完全去掉会失去唯一的 Android 端到端证据 |
| 把设备级用例接进 CI（GitHub Actions + Android 模拟器） | 需要 `macos`/`ubuntu` + KVM 加速与模拟器镜像，成本与时长都不小；ADR-0017 §决策 5 已把「接入 CI」列为需另开 PR/ADR 的事项。若将来接入，本决策的第 2 条由 CI 承担即可 |
| 只跑一个「冒烟」子集（如 `app_boot`）作为切片级 | 冒烟子集证明不了 `js_bridge` 的沙箱与配额行为——那正是设备级唯一不可替代的部分 |
