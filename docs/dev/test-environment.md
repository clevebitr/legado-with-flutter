# 本机测试环境（Windows / Android）

> **本文档只讲「在本机把测试跑起来」**：前置条件、脚本、设备级用例、排错与实测证据。
> - 测试分层、覆盖率门禁、Golden 策略、CI 流水线归 `docs/dev/testing.md`；
> - 平台基线、开发者模式、三端验收清单归 `docs/dev/platform.md`；
> - 门禁命令本体不在此重复，唯一出处为 `AGENTS.md` §4。

---

## 1. 覆盖声明（先看这里）

| 目标 | 状态 | 说明 |
|---|---|---|
| 主机侧单元 / Widget 测试 | ✅ 已跑通 | `flutter test --coverage` 全部用例通过，`tool/check_coverage.dart` 退出码 0。用例计数与分层覆盖率只在 §7 的实测证据表里出现一次（该计数随每个切片增长，以**最近一次运行**为准；阈值与判定归 `docs/dev/testing.md` §2） |
| **执行时点** | — | **切片级：Windows 与 Android 各实跑一次**（2026-10-13 实测：Windows 108 s、Android 163 s，含模拟器冷启动）；**阶段出口：双端全量**（`docs/dev/roadmap.md` §4 的 G7）。Android 因**环境**失败时可以降级为「Windows 实跑 + 写明环境阻塞」，由架构师在下一个切片前补跑——**不得**写成通过。改了 `lib/core/platform/**`、原生工程或 `integration_test/` 的切片必须在改动的那个平台实跑。降级路径、重开条件与理由归 **ADR-0039**，本节不复述；命令见 §3，证据写 §7 |
| Windows 桌面设备级用例 | ✅ 已跑通 | `integration_test/` 两个用例文件在 `-d windows` 全部通过 |
| Android 模拟器设备级用例 | ✅ 已跑通 | AVD `Medium_Phone`（API 37）上两个用例文件全部通过，含文件型 Drift 数据库 |
| iOS | ❌ **未覆盖** | 本机无 macOS / Xcode，条件不具备；iOS 行为仍按 `docs/dev/platform.md` §6 人工确认 |
| Android 真机与多 API 版本矩阵 | ❌ **未覆盖** | 只在模拟器单一 API 37 上验证；minSdk 26（`platform.md` §1）的低版本行为没有自动化覆盖 |
| CI | 不变 | `.github/workflows/ci.yml` 仍只跑 `AGENTS.md` §4 的主机侧门禁；设备级用例尚未接入 CI（要接入需另开 PR/ADR） |

---

## 2. 前置条件

| 项 | 要求 | 不满足时的表现 |
|---|---|---|
| Flutter SDK | 在 PATH 上；版本基线见 `docs/dev/platform.md` §1.1 | 脚本报 `PATH 上找不到 flutter` |
| Windows 开发者模式 | 必须开启，原因见 `docs/dev/platform.md` §1.2 | `flutter build windows` 报 `Building with plugins requires symlink support`；`run_windows.ps1` 会在动手前直接拦下 |
| Android SDK + emulator + AVD | 脚本自动探测 `ANDROID_HOME` / `ANDROID_SDK_ROOT` / `%LOCALAPPDATA%\Android\sdk` | 脚本报找不到 SDK 或 AVD 不存在，并列出可用 AVD 名 |
| PowerShell | Windows PowerShell 5.1 或 PowerShell 7 均可 | — |

**本机 Android 测试目标（实测基线）：** AVD `Medium_Phone`，镜像
`system-images/android-37.2/google_apis_playstore_ps16k/x86_64`，1080×2400 @420dpi。
换机或换 AVD 时用 `-AvdName` 覆盖，不需要改脚本。

> 脚本文件是 **UTF-8 带 BOM**：Windows PowerShell 5.1 不认不带 BOM 的 UTF-8，
> 会把中文注释读成乱码并报语法错误。新增脚本请保持该编码。
> 下面示例统一用 `pwsh`（PowerShell 7）；机器上只有内置的 Windows PowerShell 5.1 时，
> 把 `pwsh` 换成 `powershell` 即可——脚本按两者的交集写，且会把中文输出按 UTF-8 写进日志。

---

## 3. 怎么跑

命令都在仓库根目录执行（脚本内部会自行 `Push-Location` 到根目录）。

| 目的 | 命令 | 说明 |
|---|---|---|
| 全量（门禁 + 两端设备级用例） | `pwsh -File tool/test/run_all.ps1` | 顺序与 CI 一致；Android 默认用完关闭模拟器 |
| 只跑主机侧 | `pwsh -File tool/test/run_unit.ps1` | 等价于 CI 的测试 + 覆盖率两步 |
| 只跑 Windows 设备级 | `pwsh -File tool/test/run_windows.ps1` | 需要开发者模式 |
| 只跑 Android 设备级 | `pwsh -File tool/test/run_android.ps1` | 没有在线设备时自动启动 AVD；**不用快照**，开机后跑完就关并清理。本机实测：全量 3 个文件 **~2 min**（新 worktree 首次要构建，~3 min 20 s），单文件 ~70 s（2026-10-13） |
| 只跑其中一个用例文件 | `-TestFile <名字>` | 如 `-TestFile js_bridge`。逐文件运行意味着**一文件一次构建+安装**，引擎/桥类切片只需 `js_bridge_test.dart` |
| 真正全新的 guest | `-WipeData` | 重置 AVD 的 userdata（完整首次开机，比普通冷启动慢）；只有需要排除残留用户数据时才用 |
| 全量但跳过设备级 | `pwsh -File tool/test/run_all.ps1 -SkipDeviceTests` | 没有设备时的收敛选项 |
| 跳过其中一端 | `-SkipWindows` / `-SkipAndroid` | — |
| 保留模拟器 | `-KeepEmulator` | 默认只关闭「本脚本启动的」模拟器，复用在线设备时不会去关别人的环境 |
| 无界面跑 Android | `-Headless` | 追加 `-no-window`，适合没有桌面会话的场景（快照本来就不读，所以与有窗口无差别） |
| 换 AVD / 放宽等待 | `-AvdName <名字>` / `-BootTimeoutSeconds 600` | 默认 300 秒 |

等价的裸命令（排查时用，注意 §5 的坑）：

```bash
flutter test integration_test/app_boot_test.dart -d windows
flutter test integration_test/on_disk_database_test.dart -d emulator-5554
```

---

## 4. 目录与文件

| 路径 | 职责 |
|---|---|
| `integration_test/app_boot_test.dart` | 设备级 smoke：真实引擎 + 真实平台通道下应用能启动并渲染落地页 |
| `integration_test/on_disk_database_test.dart` | 设备级验证：文件型 Drift 数据库（原生 SQLite + 后台 isolate）建库、落盘、跨连接读回 |
| `integration_test/js_bridge_test.dart` | 设备级验证：真实 QuickJS 引擎 + 真实 worker isolate 上的 `JsBridge`（标量 / 数组结果、同步 `crypto.*`、`log.*` 转发、runaway → `js:timeout` 后 worker 仍可用、JS 异常 → `js:error`、`await http.get` / `http.post`、`await parse.getString`、元素级 scope → `js:parse-scope`、额度 → `js:quota`、白名单内外） |
| `tool/test/common.ps1` | 共享工具：路径解析、命令执行与失败传播、Android 设备/模拟器辅助（**不单独执行**） |
| `tool/test/run_unit.ps1` | 主机侧测试 + 覆盖率门禁 |
| `tool/test/run_windows.ps1` | Windows 设备级用例 |
| `tool/test/run_android.ps1` | Android 设备级用例（启动/复用模拟器 → 运行 → 关闭） |
| `tool/test/run_all.ps1` | 一键全量 |
| `build/test-artifacts/` | 模拟器日志等排错证据（`build/` 已被 `.gitignore` 覆盖，不进仓库） |

**为什么需要设备级用例：** `lib/core/di/database_executor_provider.dart` 在
`flutter test` 的宿主 VM 里必然抛 `Channel was closed before receiving a response`
（后台 isolate 不可用），因此它按 ADR-0019 第二类登记在 `tool/coverage_allowlist.txt` 中
豁免覆盖率。`integration_test/on_disk_database_test.dart` 是它唯一的自动化验证入口，
Windows 与 Android 两侧都已实测通过。

**`js_bridge_test.dart` 同理：** `lib/core/js/quickjs_worker.dart` 需要
`flutter_qjs_next` 的原生库，宿主 VM 加载不了，因此它也在 allowlist 里（第二类），
而 `integration_test/js_bridge_test.dart` 是它唯一的自动化验证入口——ADR-0029 §后果 明确
要求 3.3 落地时补上这个集成探针（`docs/dev/roadmap.md` §6 陷阱 #1：「构建成功」对 JS 路径毫无证明力）。

**规范依据：** 设备级集成测试是独立的一层，其分层、位置与是否进 CI 由
`docs/dev/testing.md` §3 与 C-TEST-4 定义（ADR-0017 §决策 5）；本文档只负责“怎么跑”。

设备级用例**不参与**覆盖率统计：`integration_test/` 不在 `lib/**` 下，`flutter test --coverage`
也不会加载它，因此覆盖率门禁的输入与结论不受影响。

---

## 5. 关键差异与踩坑（脚本为什么这么写）

这几条都是本机实测踩出来的坑，改动脚本前请先读：

1. **逐个用例文件运行，而不是 `flutter test integration_test -d <device>`。**
   桌面端在同一次 `flutter test` 里跑第二个文件时会二次启动同一个 exe 并失败：
   `Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.`
   因此 `Invoke-IntegrationTests` 对每个 `*_test.dart` 单独调用一次 `flutter test`。

2. **测试里必须显式订阅 provider 保活。**
   `@riverpod` 生成的是 autoDispose provider（`storage_provider.g.dart` 中 `isAutoDispose: true`）。
   只 `read` 不 `listen` 时，provider 在本轮事件循环结束时被销毁，
   `readerDatabaseProvider` 的 `ref.onDispose` 随即 `database.close()`，正在进行的写入被
   `ConnectionClosedException` 打断——表现为「第一次写库就报
   *Channel was closed before receiving a response*」。widget tree 里有 `watch` 帮忙保活，
   测试里没有，所以要 `container.listen(...)` 拿一个订阅句柄。

3. **Android 模拟器要「脱离当前进程树」启动。**
   实测：模拟器作为本脚本的子进程时，会在 `flutter test` 的 Gradle 构建期间被连带终止，
   随后 `adb install` 报 `adb.exe: device 'emulator-5554' not found`（模拟器日志里能看到它被要求优雅退出）；
   同一个模拟器改为脱离方式启动后，同一组用例全部通过。`Start-AndroidEmulator` 因此用
   WMI（`Win32_Process.Create`）拉起一个中间 powershell 去 `Start-Process` 并立即退出；
   WMI 不可用时回退为子进程并给出警告。

4. **模拟器追加 `-crash-report-mode disabled`。**
   本机模拟器崩溃过一次之后，每次启动都会弹出崩溃上报同意对话框
   （日志里 `Showing crashdialog to get consent.`）并**阻塞开机**，无界面运行时永远起不来。

5. **不用快照（`-no-snapshot-load`），跑完清理 `snapshots/<avd>/default_boot`。**
   这是 2026-10-13 “Android 一测半小时”的根因链：`adb emu kill` **立刻返回**，而模拟器
   还要跑十几秒才写完快照（关键的其实是几十字节的 `ram.bin` / `snapshot.pb`）；脚本、外层
   工具或手工 Ctrl-C 在这个窗口里退出，就留下**一份被截断的快照**，而 AVD `config.ini` 的
   `fastboot.forceFastBoot=yes` 会让之后每一轮都加载它——表现为「**加载成功但 guest 卡死、
   adbd 永远 `offline`、干等到 300 s 超时**」，且一轮轮重复。
   写入这版模拟器**防不住**（`-no-snapshot-save` 与 `quickbootChoice.ini` 的
   `saveOnExit = false` 实测都被忽略，`ram.img` 照样写出 4 GB），所以脚本保证的是
   「**不读**」，并在等进程真正退出后删掉本轮那份（不删就是每轮白写 4 GB）。
   另一条预防措施：**别再改 AVD 的状​态**：`-WipeData` 只在你主动要全新 guest 时才用。

6. **失败路径也一定要关模拟器，并在脚本末尾显式 `exit`。**
   旧 `finally` 的判据是 `$null -ne $serial`，而 `$serial` 只在 `Wait-ForAndroidBoot`
   **成功**后才被赋值——于是「开机超时」恰好是唯一不关模拟器的路径，留下一个 `offline`
   僵尸占着 AVD 锁与 5554 端口，下一轮启动直接撞上。另外，`pwsh -File` 在「WMI 启过模拟器 +
   抛终止性错误」之后会打完异常却**不退出**（无子进程、线程全在 UserRequest），所以
   `run_android.ps1` 把异常收成一行消息 + `exit 1`，不依赖 PowerShell 默认的收尾。

---

## 6. 排错

| 症状 | 原因 | 处置 |
|---|---|---|
| `Building with plugins requires symlink support` | 未开 Windows 开发者模式 | 管理员执行 `start ms-settings:developers` 打开「开发人员模式」（`platform.md` §1.2） |
| `Error waiting for a debug connection: The log reader stopped unexpectedly` | 一次 `flutter test` 跑了多个 integration_test 文件 | 逐文件运行（§5.1）；用脚本即可 |
| `Channel was closed before receiving a response`（集成测试里） | provider 未保活，数据库连接被 autoDispose 提前关闭 | 用 `container.listen` 持有订阅（§5.2） |
| `Channel was closed before receiving a response`（`flutter test` 里） | 该用例试图在宿主 VM 上开文件型数据库，环境本身不支持 | 别在 `test/` 下写这类用例，放 `integration_test/` |
| `adb.exe: device 'emulator-5554' not found` | 模拟器被外层进程树连带终止 | 用脚本的分离启动（§5.3）；先看 `build/test-artifacts/android-emulator-<avd>.log` |
| Android 侧一直起不来、日志停在 `Showing crashdialog to get consent.` | 崩溃上报对话框阻塞启动 | 脚本已加 `-crash-report-mode disabled`（§5.4） |
| `AVD 'xxx' 不存在` | AVD 名不对 | `%LOCALAPPDATA%\Android\sdk\emulator\emulator.exe -list-avds` 查名，或 `-AvdName` 指定 |
| 脚本报「模拟器进程已消失，未能完成开机」 | 模拟器启动后立刻退出 | 读 `build/test-artifacts/android-emulator-<avd>.log[.err]` |
| 同上，日志里是 `Change of GLES renderer detected` + `Failed to load snapshot 'default_boot'` | `-Headless` 与残留快照记录的渲染器不一致，快照加载失败后模拟器直接退出 | 去掉 `-Headless` 重跑一次：会重新生成快照，之后两者都能用（实测 2026-10-13） |
| `dart run tool/check_coverage.dart` 以退出码 3 失败 | 新增了 `lib/core/**` / `domain/**` / `data/**` 源文件却没有测试 | 补测试；确需豁免按 ADR-0019 登记进 `tool/coverage_allowlist.txt`（`testing.md` §2） |
| **新建 worktree** 里 `flutter test` / `flutter run` 报 `By default, this package downloads a pre-compiled SQLite library` + `SocketException` | native assets 的下载缓存是**按 worktree** 存的（`<worktree>/.dart_tool/hooks_runner/shared/sqlite3/`），新 worktree 没有缓存，一断网就失败（与代码无关，也与 Android 的 `libsqlite3.arm.android.so` 同源） | 从任一已跑通的 worktree 拷 `.dart_tool/hooks_runner/shared/sqlite3/` 过去（实测即时恢复），或等网络恢复后重跑；**不要**为它改 `pubspec.yaml` / 加本地 sqlite3 |
| Android 模拟器日志里 `Successfully loaded snapshot` 之后就一直是 `adb.exe: device offline`，脚本干等到 `-BootTimeoutSeconds` 超时 | `snapshots/<avd>/default_boot` 是**被截断**的（`emu kill` 立即返回，而模拟器还要写十几秒；在窗口里退出就会撕坏它），`fastboot.forceFastBoot=yes` 又让每轮都加载它 | 现在 `run_android.ps1` **不读快照**并在跑完清理，所以不会再发生；手工碰到时删掉 `snapshots/<avd>/default_boot` 或加 `-no-snapshot-load` 启动。**注意**：`bootcompleted.ini` 恒为 0 字节是正常的，_不是_失败指纹（看快照目录里各文件的时间戳是否互相对不上） |
| `flutter build windows` 报一堆 `jNullReference` / `JObject isn't a type`，或某包解析不出类 | pub cache 里有**半下载**的包（2026-10-14 G4 交付时本机踩到：`jni-1.1.0` 目录为空；`dynamic_color` / `flutter_qjs_next` / `path_provider_windows` / `shared_preferences_windows` 缺 `pubspec.yaml`）——中断的 `pub get` 留下的残目录会被当成已安装 | 判据一行可扫（找没有 `pubspec.yaml` 的包目录）；删掉这些目录再 `flutter pub get` 即恢复。**可疑诱因（2026-10-14 二次复发）：** 两个 worktree 并发跑 `pub get` 共用同一份 cache——同一批包两次都缺，建议新 worktree 逐个拉、别并发 |
| 跑完 Android 后删 worktree 报 `Filename too long` | Gradle 会在 `build/integration_test/.transforms/…` 下生成超过 Windows 260 字符上限的路径，`git worktree remove` 与 PowerShell `Remove-Item` 都删不掉（2026-10-13 架构师实际踩到）。**做法：** 先把 git 元数据摘掉（`git worktree remove --force` 失败无妨，`git worktree prune` 即可），再用 `cmd //c "robocopy <空目录> <worktree路径> /MIR"`（robocopy 支持长路径）镜像清空，最后 `rmdir` 掉剩下的空目录 |

---

## 7. 实测证据（2026-10-11；最新一次 **M14 阅读体验，2026-10-22**，双端按 ADR-0039）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 主机侧 | `flutter test --coverage` + `dart run tool/check_coverage.dart` | 全部用例通过（**674** 个用例）；覆盖率门禁退出码 0（`core` 944/944、`domain` 1708/1708，均 100%；阈值见 `docs/dev/testing.md` §2） |
| Windows 构建前置 | `flutter build windows --debug` | 成功（`build\windows\x64\runner\Debug\flutter_reader.exe`），含 `flutter_qjs_next` 从 `cxx/` 源码编译的 QuickJS |
| Windows 设备级 | `pwsh -File tool/test/run_windows.ps1` | **3 个用例文件全部通过**（`app_boot` 1 项；`js_bridge` **24 项**，在原有 21 项（`await http.*` / `await parse.*` / `js:parse-scope` / `js:quota` / `java.*` 同步读写与按源隔离 / URL 的 `key` 绑定 / `java.timeFormat` 的本地渲染与非法入参）之上新增 3 项 M1-b1b 探针：`java.*` 别名族（`md5Encode` / `base64*` 往返 / `encodeURI` / `log`）、命中具名拒绝（`java.ajax` 与 `Packages.java.lang.…`）时给可读错误、`java.getString` 字面量快路径 + `Array.prototype.toArray()` 垫片；`on_disk_database` 1 项）；退出码 0 |
| Android 设备级 | `pwsh -File tool/test/run_android.ps1` | **本轮未复跑（2026-10-13）**：单次完整跑（建 APK + 冷启模拟器 + 三个用例文件）在半小时以上，操作者要求本轮以 Windows 设备级为准（Window 与 Android 跑同一份 Dart 代码与同一份 `flutter_qjs_next` 原生引擎，24 项尺度的差异只在平台通道）。上一条记录的 Android 运行时是 **b4a 集成后的 21/21**（本次新增的 3 项探针尚未在模拟器上跑过），**不计作已覆盖**，需补跑时按下方命令运行 |
| 许可证扫描 | `dart run tool/scan_licenses.dart` | 156 个包全部为宽松许可，无风险项；退出码 0（`NOTICE.md` §5） |
| **G4 主机侧（2026-10-14）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` | **692** 个用例全过；覆盖率退出码 0（`core` 943/943、`domain` 1740/1740，均 100%） |
| **G4 Windows 设备级** | `pwsh -File tool/test/run_windows.ps1` | 3 个用例文件全过（`js_bridge` **24/24**、`app_boot` 1/1、`on_disk_database` 1/1）；退出码 0，**81 s** |
| **G4 Android 设备级** | `pwsh -File tool/test/run_android.ps1` | 模拟器 `Medium_Phone`（含冷启动）3 个用例文件全过（`js_bridge` **24/24**）；退出码 0，**171 s**；跑完按 PR #34 的策略清理了本轮快照 |
| **G4 #15 闭环复跑（2026-10-14）** | 三条命令同上 | 门禁同上（**692** 用例、`core` 943/943、`domain` 1740/1740）；Windows **79 s**、Android **186 s**（含冷启动），两侧各 3 个用例文件全过、`js_bridge` **24/24**，退出码 0；Android 跑完按 PR #34 的策略清理了本轮快照 |

| **Phase 4 出口（G7，2026-10-14）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + `pwsh -File tool/test/run_windows.ps1` + `pwsh -File tool/test/run_android.ps1`（在冻结的 `main` = `473ff1e` 上） | 主机侧 **692** 用例全过、覆盖率退出码 0（`core` 943/943、`domain` 1740/1740，均 100%）；设备级 **Windows 92 s、Android 182 s（含模拟器冷启动）**，两侧 3 个用例文件全过（`js_bridge` **24/24**）、退出码 0。**注：** 运行前本机 pub cache 又出现 5 个半下载包（见 §6 那一行），按判据清理并重拉后跑通——CI 侧用的是干净 cache，不受影响 |
| **b6 主机侧（2026-10-14）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` | **697** 个用例全过；覆盖率退出码 0（`core` 943/943、`domain` 1759/1759，均 100%） |
| **b6 Windows 设备级** | `pwsh -File tool/test/run_windows.ps1` | 3 个用例文件全过（`app_boot` 1/1、`js_bridge` **24/24**、`on_disk_database` 1/1）；退出码 0，**80 s** |
| **b6 Android 设备级** | `pwsh -File tool/test/run_android.ps1` | 模拟器 `Medium_Phone`（含冷启动）3 个用例文件全过（`js_bridge` **24/24**）；退出码 0，**151 s**；跑完按 PR #34 的策略清理了本轮快照 |

| **P5-1 主机侧（2026-10-14）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` | **763** 个用例全过；覆盖率退出码 0（`core` 1014/1014、`domain` 1837/1837、`data` 54/54，均 100%） |
| **P5-1 Windows 设备级** | `pwsh -File tool/test/run_windows.ps1` | 3 个用例文件全过（`app_boot` 1/1、`js_bridge` **24/24**、`on_disk_database` **2/2**，新增的 `bookSourceDao_…persistsTheImportedSource` 在列）；退出码 0，**99 s** |
| **P5-1 Android 设备级** | `pwsh -File tool/test/run_android.ps1` | 模拟器 `Medium_Phone`（含冷启动）3 个用例文件全过（`js_bridge` **24/24**、`on_disk_database` 含新的 `book_sources` 真实写入）；退出码 0，**169 s**；跑完按 PR #34 的策略清理了本轮快照 |

| **P5-2 主机侧（2026-10-14）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` | **773** 个用例全过；覆盖率退出码 0（`core` 1017/1017、`domain` 1840/1840、`data` 64/64，均 100%） |
| **P5-2 Windows 设备级** | `pwsh -File tool/test/run_windows.ps1` | 3 个用例文件全过（`app_boot` 1/1、`js_bridge` **24/24**、`on_disk_database` 2/2）；退出码 0，**93 s** |
| **P5-2 Android 设备级** | `pwsh -File tool/test/run_android.ps1` | 模拟器 `Medium_Phone`（含冷启动）3 个用例文件全过（`js_bridge` **24/24**）；退出码 0，**164 s**；跑完按 PR #34 的策略清理了本轮快照 |

| **书源文件导入（2026-10-14）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **788** 用例全过；覆盖率退出码 0（`core` 1032/1032、`domain` 1857/1857、`data` 64/64，均 100%）；设备级 **Windows 93 s / Android 158 s**，各 3 文件全过、`js_bridge` 24/24、退出码 0。**新增原生插件 `file_selector`**（平台对话框），因此这一轮的双端实跑也是它的构建验证 |

| **M10 书源测试机制（2026-10-21）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **1003** 用例全过；覆盖率退出码 0（`core` 1219/1219、`domain` 2168/2168、`data` 142/142，均 100%）；设备级 **Windows 93 s / Android 188 s**（含模拟器冷启动），各 3 文件全过（`js_bridge` 24/24、`on_disk_database` 3/3 —— 其中 `bookSourceDao_…persistsTheImportedSource` 新增了 v4 的 `comment` / `groupName` / `respondTime` 真实写入），退出码 0。**`lib/core/platform/` 与 `MainActivity.kt` 都改了**（`LongRunningTask` + `WAKE_LOCK`），所以这一轮的双端实跑同时是它的构建验证 |

| **M4 阅读器（5.3，2026-10-21）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **1051** 用例全过；覆盖率退出码 0（`core` 1225/1225、`domain` 2198/2198 均 100%，`data` 98.2% ≥ 80%）；设备级 **Windows 92 s / Android 185 s**（含模拟器冷启动），各 3 文件全过（`js_bridge` 24/24、`on_disk_database` 3/3 —— 其中 `bookshelfDao_…persistsBooksAndProgress` 覆盖了 v5 的 `books.tocUrl` 真实写入），退出码 0 |

| **M6 书源列表排序/筛选（5.5，2026-10-21）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **1083** 用例全过；覆盖率退出码 0（`core` 1245/1245、`domain` 2211/2211 均 100%，`data` 98.41% ≥ 80%）；设备级 Windows / Android 各 3 文件全过（`js_bridge` 24/24、`on_disk_database` 3/3），退出码 0 |

| **M11 聚合搜索（3.8，2026-10-21）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **1155** 用例全过；覆盖率退出码 0（`core` 1245/1245、`domain` 2458/2458 均 100%，`data` 98.47% ≥ 80%）；设备级 Windows / Android 各 3 文件全过（`js_bridge` 24/24、`on_disk_database` 3/3），退出码 0 |

| **M12 引擎兼容面（3.7，2026-10-21）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **1204** 用例全过；覆盖率退出码 0（`core` 1268/1268、`domain` 2816/2816 均 100%，`data` 98.47% ≥ 80%）；设备级 **Windows 3 文件全过**、**Android（`Medium_Phone` 含冷启动）3 文件全过**（`js_bridge` 24/24、`on_disk_database` 3/3），退出码 0。`lib/core/network/`（流式读 body 的异常映射、`declaredCharset`）与 `integration_test/js_bridge_test.dart` 的 `_ProbeHttpClient` 都改了，所以这一轮的双端实跑同时是它们的构建验证 |

| **M12 余项（A5 / Big5 / 单源预算，2026-10-21）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **1223** 用例全过；覆盖率退出码 0（`core` 1279/1279、`domain` 2848/2848 均 100%，`data` 98.47% ≥ 80%）；设备级 Windows / Android（`Medium_Phone` 含冷启动）各 3 文件全过、`js_bridge` **25/25**（新增的内置键探针 `jsBridge_whenAJobCarriesBookNames_javaGetAnswersThemFirst` 在列），退出码 0。**`lib/core/js/**` 改了**（`JsJob` 两个字段 + 内置键优先 + worker 解码），所以这一轮的双端实跑也是它的验证入口 |

| **M13 封面 + 书源管理（§3.9，2026-10-22）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **1263** 用例全过；覆盖率退出码 0（`core` 1341/1341、`domain` 2848/2848 均 100%，`data` 98.72% ≥ 80%）；设备级 Windows / Android（`Medium_Phone` 含冷启动）各 3 文件全过（`js_bridge` 25/25），退出码 0。**新增 `core/platform/` 的保存端口**（`file_selector` 的 `getSaveLocation`），所以这一轮的双端实跑同时是它的构建验证。踩坑：上一轮遗留的 `flutter_reader.exe` 占着 `reader.db`，`on_disk_database_test` 会以 `PathAccessException` 失败——先结束进程再跑 |

| **M14 阅读体验（§3.9，2026-10-22）** | `flutter test --coverage` + `dart run tool/check_coverage.dart` + 双端 `run_*.ps1` | 主机侧 **1294** 用例全过；覆盖率退出码 0（`core` 1352/1352、`domain` 2971/2971 均 100%，`data` 97.25% ≥ 80%）；设备级 Windows / Android（`Medium_Phone` 含冷启动）各 3 文件全过（`js_bridge` 25/25），退出码 0。**没有新增原生依赖**（亮度是应用级遮罩、字体族用平台通用名），所以这一轮的双端实跑验证的是纯 Dart 改动 + 既有插件 |

> Android 补跑命令：`pwsh -File tool/test/run_android.ps1`（`Medium_Phone` 自动启停；需要网络，因 `flutter build apk` 的 native assets 要下载 `libsqlite3.arm.android.so`，见 §6 与本表旧记录）。
>
> `flutter doctor` 的网络项在本机报 `A cryptographic error ... checking https://pub.dev/`
> （代理/中间人证书问题），但 `flutter pub get` 正常，不影响测试。
