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
| 只跑 Android 设备级 | `pwsh -File tool/test/run_android.ps1` | 没有在线设备时自动启动 AVD |
| 全量但跳过设备级 | `pwsh -File tool/test/run_all.ps1 -SkipDeviceTests` | 没有设备时的收敛选项 |
| 跳过其中一端 | `-SkipWindows` / `-SkipAndroid` | — |
| 保留模拟器 | `-KeepEmulator` | 默认只关闭「本脚本启动的」模拟器，复用在线设备时不会去关别人的环境 |
| 无界面跑 Android | `-Headless` | 追加 `-no-window`，适合没有桌面会话的场景 |
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
要求 3.3 落地时补上这个集成探针（`PLAN.md` §6 陷阱 #1：「构建成功」对 JS 路径毫无证明力）。

**规范依据：** 设备级集成测试是独立的一层，其分层、位置与是否进 CI 由
`docs/dev/testing.md` §3 与 C-TEST-4 定义（ADR-0017 §决策 5）；本文档只负责“怎么跑”。

设备级用例**不参与**覆盖率统计：`integration_test/` 不在 `lib/**` 下，`flutter test --coverage`
也不会加载它，因此覆盖率门禁的输入与结论不受影响。

---

## 5. 关键差异与踩坑（脚本为什么这么写）

这四条都是本机实测踩出来的坑，改动脚本前请先读：

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
| `dart run tool/check_coverage.dart` 以退出码 3 失败 | 新增了 `lib/core/**` / `domain/**` / `data/**` 源文件却没有测试 | 补测试；确需豁免按 ADR-0019 登记进 `tool/coverage_allowlist.txt`（`testing.md` §2） |

---

## 7. 实测证据（2026-10-11；主机侧与 Windows 设备级于 2026-10-12 复跑）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 主机侧 | `pwsh -File tool/test/run_unit.ps1` | 全部用例通过（**504** 个用例）；`tool/check_coverage.dart` 退出码 0（`core` 779/779、`domain` 1163/1163，均 100%；阈值见 `docs/dev/testing.md` §2） |
| Windows 构建前置 | `flutter build windows --debug` | 成功（`build\windows\x64\runner\Debug\flutter_reader.exe`），含 `flutter_qjs_next` 从 `cxx/` 源码编译的 QuickJS |
| Windows 设备级 | `pwsh -File tool/test/run_windows.ps1` | **3 个用例文件全部通过**（`app_boot` 1 项、`js_bridge` 16 项（含 `await http.*` / `await parse.*` / `js:parse-scope` / `js:quota`），`on_disk_database` 1 项）；退出码 0 |
| Android 设备级 | `pwsh -File tool/test/run_android.ps1` | 模拟器自动启动 → 2 个用例文件全部通过 → 自动关闭；退出码 0（当时 `integration_test/` 只有 2 个文件；`js_bridge_test.dart` 的 Android 侧尚未复跑） |
| 许可证扫描 | `dart run tool/scan_licenses.dart` | 156 个包全部为宽松许可，无风险项；退出码 0（`NOTICE.md` §5） |

> `flutter doctor` 的网络项在本机报 `A cryptographic error ... checking https://pub.dev/`
> （代理/中间人证书问题），但 `flutter pub get` 正常，不影响测试。
