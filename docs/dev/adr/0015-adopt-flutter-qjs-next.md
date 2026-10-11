# ADR-0015 采用 `flutter_qjs_next` 作为 JS 引擎

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** 取代 ADR-0008；C-SRC-2、C-SRC-3；`docs/dev/book-source.md` §6；`docs/dev/tech-stack.md` §5；`tool/spike/README.md`

## 背景

ADR-0008 决定使用 `flutter_js_plus 0.0.4`，并把「JS 在独立 Isolate 中执行」「5 秒墙钟超时」
「32MB 内存上限」写成硬性要求。

`tool/spike/js_isolate_spike_test.dart`（9 项探针）实测后发现该依赖**不可用**：

| # | 缺陷 | 影响 |
|---|---|---|
| 1 | `Pointer.fromFunction` 的回调返回可空 `Pointer`，Dart 3.13 拒绝编译（4 处，全在插件源码） | 全平台不可用（任何 import 都编译失败） |
| 2 | Windows CMake 目标名 `flutter_js_plugin` ≠ 包名要求的 `flutter_js_plus_plugin` | `flutter build windows` 直接失败 |
| 3 | 预编译 DLL 未导出 `jsSetMemoryLimit` | 内存上限物理不可实现 |
| 4 | `timeout` 参数无实际效果 | 引擎级超时不可用 |

ADR-0008 由此被标为「部分失效（待裁决）」，`@js:` 也从 M0 完成判定中移除。

## 决策

**采用 `flutter_qjs_next ^1.5.2`，不维护 fork。**

1. `pubspec.yaml` 中移除 `flutter_js_plus`，改为 `flutter_qjs_next: ^1.5.2`。
2. 「JS 在独立 Isolate 中执行」保持不变（C-SRC-2），**且引擎级 `timeout` 与 `memoryLimit`
   现在真实可用**，配额按 ADR-0008 的原定值执行：
   - 单次 JS 墙钟超时 **5 秒** → 通过 `QuickJsRuntime2(timeout: 5000)` 实现；
   - 单次 JS 内存上限 **32 MB** → 通过 `memoryLimit: 32 * 1024 * 1024` 实现。

   > 配额数值的**规范出处**是 `docs/dev/book-source.md` §6；本条只记录决策与实测证据，
   > 其他文档引用时不得再抄一份数字（ADR-0013）。
3. **`Isolate.kill(priority: immediate)` 保留为兜底**：引擎中断器优先，但调用方仍必须
   持有硬预算，防止未来引擎行为变化导致 UI 线程被拖死。
4. JS→Dart 回调桥（`parse.*` / `http.*` / `log.*`）保持不变，已在后台 Isolate 中实测可用。
5. `tool/spike/` 中的 9 项探针**改指向 `flutter_qjs_next`**，作为该引擎的回归基线；
   仍不进 CI（需要 `flutter build <platform>` 产出的原生库）。

## 实测证据（2026-10-10，Windows 11 / Flutter 3.47.7）

> **证据范围：** 下表全部数据来自 **Windows 11 + Flutter 3.47.7**。
> Android / iOS / Linux / macOS 仅由包元数据声明支持，**尚未实测**；
> 在这四个平台跑过探针之前，不得声称「全域已验证」。

| 探针 | `flutter_js_plus 0.0.4` | **`flutter_qjs_next 1.5.2`** |
|---|---|---|
| 后台 Isolate 创建 + 求值 | ✅ | ✅ |
| JS→Dart 回调桥（Isolate 内 / 根 Isolate） | ✅ / ✅ | ✅ / ✅ |
| runaway 可被 `Isolate.kill` 终止 | ✅ 3002ms | ✅ 3002ms |
| 终止后原生库仍可用 | ✅ | ✅ |
| 复用运行时性能（100 次求值） | 0.11 ms/次 | **0.18 ms/次** |
| 引擎级超时终止 runaway | ❌ 无效 | ✅ **2012ms 准确中断，且运行时仍可用** |
| 内存上限真实生效 | ❌ 符号缺失 | ✅ **8MB 上限在 99ms 内抛错** |
| 可直接构建（无需打补丁） | ❌ 4 处编译错 + CMake 名错 | ✅ 无需补丁 |
| `_checkNativeAbi` 陈旧库检测 | 无（静默失败） | ✅ 显式报错并提示用 `FLUTTER_QJS_NEXT_LIBRARY` |

## 后果

- **ADR-0008 标为 `Superseded by ADR-0015`**（其历史结论与实测发现保留，可追溯）。
- `book-source.md` 矩阵 #14 `@js:` **恢复为 M0**；§6 移除「引擎未定」与「超时/内存不可实现」的降级说明。
- `platform.md` §8.1 中为 `flutter_js_plus` 加的两条 Gradle 变通已分别处理：
  `kotlin.jvm.target.validation.mode=warning` **已删除**（它只服务于该插件，实测删除后
  `flutter build apk --debug` 与 `flutter build windows --debug` 均成功）；
  `kotlin.incremental=false` **保留** —— 复核确认它是 Kotlin 2.4 在 Windows 上的缓存锁问题，
  与任何插件无关（本条初版把两者都判为「应重新评估并删除」，已按 `platform.md` §8.1 修正）。
- `NOTICE.md` §5 的依赖许可表新增 `flutter_qjs_next`（**MIT**，与 GPL-3.0 兼容，满足 C-DEP-7）；
  `NOTICE.md` §6 的扫描流程会在下次执行时自动覆盖它。
- 运行 spike 的方式改变：不再需要给 pub cache 打补丁，改为
  `flutter build windows --debug` + `FLUTTER_QJS_NEXT_LIBRARY=<DLL 绝对路径> flutter test ...`。
- **`@js:` 的实现细节**（`sendMessage` 的载荷必须是合法 JSON）已写进 spike 注释，
  属于 `book-source.md` §6 需要固化的约束。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| fork `flutter_js_plus`（补丁量已实测很小） | 需长期维护一个停更包；且内存上限缺陷无法通过小补丁解决（预编译 DLL 缺符号） |
| `fjs` 3.3.2 | 引入 `flutter_rust_bridge`，需要 Rust 工具链，构建链最重 |
| `quickjs_engine` 0.1.6 | 可行备选，但功能集与维护活跃度不及 `flutter_qjs_next`（后者含引擎池、模块字节码、Web API、ABI 校验） |
| 暂不支持 `@js:`（移出 M0） | 大量真实 Legado 书源依赖 `@js:`，兼容性代价过高；且现已证明无需付此代价 |
