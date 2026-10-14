# ADR-0039 设备级探针回到「切片级双端」：代价前提已消失

- **状态：** Accepted（2026-10-13 架构师裁决；**取代 ADR-0038**）
- **日期：** 2026-10-13
- **关联：** ADR-0038（被本决策取代）、ADR-0017（测试文件位置）、`docs/dev/testing.md` §1、
  `docs/dev/test-environment.md` §1/§3/§5/§7、`PLAN.md` §4 的 G7

## 背景

ADR-0038 把设备级探针从「切片级双端」降到「阶段出口双端」，**唯一的理由是代价**：当时实测
Android 单次完整跑（建 APK + 冷启 AVD + 逐文件 `flutter test`）**≥ 30 分钟**，M1 阶段的 8 次
交付要多等 4 小时以上，而失败原因常是环境（模拟器启动、native assets 下载）而不是代码。

该前提在 2026-10-13 被移除：`tool/test/run_android.ps1` 的快照 / 收尾策略被重写之后
（PR #34），**单次完整跑降到 2 分钟级**。架构师在本机独立复跑（模拟器 `Medium_Phone`，含冷启）：

| 侧 | 命令 | 结果 | 耗时 |
|---|---|---|---|
| Windows | `pwsh -File tool/test/run_windows.ps1` | 3 个用例文件全过（`js_bridge` 24/24） | 108 s |
| Android | `pwsh -File tool/test/run_android.ps1` | 3 个用例文件全过（`js_bridge` 24/24） | **163 s**（含模拟器冷启动） |

即：双端各跑一次的总代价约 **4.5 分钟**，与一个切片的门禁时间同量级；而阶段级要求留下的
**回归窗口是一个整阶段**（M1 是 8 个切片，P5 更多）。ADR-0038 自己的重开条件写的是
「Windows 通过但 Android 失败」——那条**尚未触发**；这里重评的是它的**代价前提**，属于该决策
自己在「背景」里列出的可重评项。

## 决策

1. **切片级恢复为「双端各实跑一次」**：`integration_test/` 的全部用例在 **Windows 与 Android
   各跑一次**且退出码 0，结果写进 `test-environment.md` §7；切片验收列写「双端设备探针实跑」。
2. **阶段出口仍要求双端全量**（`PLAN.md` §4 的 **G7** 不变）——切片级只是把它提前到每次交付。
3. **环境阻塞的降级路径（不得静默跳过）**：Android 因**环境**失败（模拟器起不来、
   `libsqlite3.arm.android.so` 下载超时等）时，交付方必须在 PR 与 `test-environment.md` §7
   写明「**环境阻塞，Android 未覆盖**」并附补跑命令；该次 Android 由**架构师**在下一个切片
   之前或该阶段出口前补跑。**不得**把它写成通过。
4. **例外保持**：改动 `lib/core/platform/**`、原生工程（`android/` / `windows/` / `ios/`）或
   `integration_test/**` 的切片，必须在改动的那个平台实跑（与本决策无关，本来就是硬要求）。
5. 命令与脚本仍只有一处定义：`docs/dev/test-environment.md` §3；本文档不复述。

## 后果

- `ADR-0038` 标为 **Superseded by ADR-0039**（原文保留）；`docs/dev/adr/README.md` 索引同步。
- `docs/dev/testing.md` §1 与 `docs/dev/test-environment.md` §1 的「执行时点」措辞改回**双端**，
  并继续只回链这两处 + 本 ADR；`docs/README.md` §2.1 的归属行不变（执行时点归 `test-environment.md`）。
- `PLAN.md` §4 的 G7 措辞同步；§3.5 之后的切片行按「双端实跑」写验收。
- **b5 已按双端交付**（§3.5 的 b5 行记录两侧实跑：Windows 108 s、Android 163 s），因此本决策
  对它只起收尾作用。
- `test-environment.md` §6 增加一条与本次重写直接相关的排错行：Android 跑完的 worktree 里
  Gradle 生成了**超长路径**（`build/integration_test/.transforms/…`），`git worktree remove`
  会以 `Filename too long` 失败，需要先用 `robocopy /MIR` 清空再 `rmdir`（架构师本轮实际踩到）。
- **重开条件**：若 Android 单侧再次出现「几十分钟级」或长期环境性失败的实例，重评本 ADR
  （那时回到 ADR-0038 的阶段级口径是合理选择）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 保持 ADR-0038（切片只 Windows、阶段出口双端） | 该决策的代价前提已被移除；留下「一个整阶段的 Android 回归窗口」不再有对应的收益 |
| 只对 `core/js/**` / `core/network/**` / `domain/rule_engine` 这类切片要求双端 | 分类本身要维护一张「哪些路径算敏感」的清单，而双端一次只多 2 分钟；用清单换 2 分钟不值，且清单会漂移（本轮 b5 改的正是规则引擎，按此清单又该双端——等于绕回本决策） |
| 把设备级用例接进 CI（GitHub Actions + 模拟器） | 仍是最彻底的方案，但需要 KVM 加速的 runner 与模拟器镜像；接入时本决策自动由 CI 承担（ADR-0017 §决策 5 的登记仍在） |
