# SPIKE 1 — 后台 Isolate 中的 JS 引擎

> 执行日期：2026-10-10 · 被测依赖：`flutter_js_plus 0.0.4` · 环境：Flutter 3.47.7 / Dart 3.13.5 / Windows 11
> 关联：`docs/dev/adr/0008-single-js-engine.md`、`docs/dev/constraints.md` C-SRC-2 / C-SRC-3、`docs/dev/book-source.md` §6

## 1. 结论摘要

**ADR-0008 的核心架构假设成立**——QuickJS 可以在后台 Isolate 中创建、求值、并通过回调桥反向调用 Dart。
**但 ADR-0008 中的两项配额要求无法用该库实现**，且该依赖本身在本工具链上**不可直接使用**。

| 探针 | 结果 | 实测证据 |
|---|---|---|
| 01 根 Isolate 求值 | ✅ | `["第一章 开始","第二章 换行","第三章"]` |
| 02 **后台 Isolate 创建 + 求值** | ✅ | `status=completed`，值与根 Isolate 一致 |
| 03 **JS→Dart 回调桥（后台 Isolate）** | ✅ | `dartReceived=ping jsSawReturn=pong` |
| 03b 回调桥根 Isolate 对照 | ✅ | 与 03 完全一致 |
| 04 runaway 脚本可被终止 | ✅ | `status=killed elapsed=3002ms` |
| 05 终止后原生库仍可用 | ✅ | 再次求值正常，未被污染 |
| 06 运行时复用成本 | ✅ | **100 次求值 11ms（0.11ms/次）** |
| 07 引擎级 `timeout: 2000` | ❌ **无效** | 脚本一直跑到 6s 预算杀 Isolate 才停 |
| 08 `memoryLimit: 32MB` | ❌ **符号缺失** | `Failed to lookup symbol 'jsSetMemoryLimit'` |

### 对 ADR-0008 逐条对照

| ADR-0008 要求 | 实测结论 |
|---|---|
| JS 在独立 Isolate 中执行 | ✅ **成立**，且回调桥在 Isolate 内同样可用 |
| 单次 JS 墙钟超时 5 秒 | ⚠️ **必须由调用方实现**：引擎的 `timeout` 参数无效，唯一可行手段是「预算到期 `Isolate.kill`」，已验证有效且不会污染原生库 |
| 单次 JS 内存上限 32 MB | ❌ **无法实现**：预编译 DLL 未导出 `jsSetMemoryLimit` |
| 单条规则 JS 调用 ≤ 20 次 | ✅ 与引擎无关，调用方计数即可 |
| 禁止使用 `JavascriptRuntime.onMessage` 回调桥（原文担心 Isolate 不安全） | ✅ **该担心不成立**，回调桥在后台 Isolate 中正常工作，`book-source.md` §6 的 `parse.*` / `http.*` / `log.*` 绑定可行 |

## 2. 上游缺陷（4 项，均需处理）

| # | 缺陷 | 位置 | 影响 |
|---|---|---|---|
| 1 | `Pointer.fromFunction` 的回调返回**可空** `Pointer`，Dart 3.13 拒绝编译 | `lib/quickjs/quickjs_runtime.dart` 3 处 + `lib/quickjs/ffi.dart` 1 处 | **全平台不可用**：任何 import 该库的 Dart 编译都会失败 |
| 2 | Windows CMake 目标名与包名不匹配 | `windows/CMakeLists.txt`：`PLUGIN_NAME "flutter_js_plugin"`，而 Flutter 生成物要求 `flutter_js_plus_plugin` | `flutter build windows` 直接失败（`No target "flutter_js_plus_plugin"`） |
| 3 | 预编译 DLL 缺少 `jsSetMemoryLimit` 符号 | `windows/shared/quickjs_c_bridge.dll` | 内存上限物理不可用 |
| 4 | `timeout` 参数无实际效果 | `QuickJsRuntime2._ensureEngine()` → `jsNewRuntime(..., timeout, port)` | 不能用引擎中断器防死循环 |

> 缺陷 1 的成因是 Dart SDK 收紧 `Pointer.fromFunction`：Dart 侧回调必须与 `NativeFunction` 的
> **非空**返回类型精确一致。修复方式经实测确认：把回调签名改为非空并让空路径返回
> `nullptr.cast<T>()`。

## 3. 本 spike 的运行前提（重要）

`flutter_js_plus 0.0.4` 必须打补丁才能编译，因此**本 spike 不能进 CI**，且依赖
pub cache 处于已打补丁状态：

```bash
P="$HOME/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_js_plus-0.0.4"
# 补丁 1（缺陷 1）：ffi.dart / quickjs_runtime.dart 的回调返回值改为非空
#   并让空路径返回 nullptr.cast<T>()
# 补丁 2（缺陷 2，仅 Windows 应用构建需要）：
#   windows/CMakeLists.txt 中 PLUGIN_NAME 改为 flutter_js_plus_plugin

PATH="$PATH:$P/windows/shared" flutter test tool/spike/js_isolate_spike_test.dart
```

> `flutter pub get` 有可能重新解包并覆盖补丁——补丁失效时表现为"编译报 4 个 FFI 错误"，
> 重打即可。

## 4. 引擎候选矩阵

| 候选 | 版本 / 发布 | Dart 约束 | 平台 | 依赖 | 评估 |
|---|---|---|---|---|---|
| `flutter_js_plus` | 0.0.4 / 2025-04 | `>=3.0.0 <4.0.0`（**声明支持 3，实际编译失败**） | android/ios/windows/linux/macos | ffi, http, sync_http | 已实测：Isolate 与回调桥可用、性能优秀；但需我们自己维护 fork（2 处补丁），且内存上限缺失 |
| **`flutter_qjs_next`** | **1.5.2 / 2026-09** | **`^3.10.0`** | **windows/linux/android/macos/ios** | **仅 ffi** | **首选候选**：活跃维护、依赖最干净、API 延续 `flutter_qjs`。需用本 spike 复测 |
| `quickjs_engine` | 0.1.6 / 2026-09 | `^3.8.0` | android/ios/macos/linux/windows | ffi, http, sync_http | 备选，同样是 FFI 方案 |
| `fjs` | 3.3.2 / 2026-09 | `^3.9.2` | android/ios/linux/macos/windows | flutter_rust_bridge, freezed_annotation | 需 Rust 工具链，构建链最重，不推荐 |
| `quickjs_runtime` | 0.3.5 / 2026-09 | `^3.5.0` | 非 Flutter 插件（纯 Dart FFI） | ffi, native_synchronization | 需自行打包各平台原生库，成本高于收益 |

> 所有候选在采用前都必须：① 跑一遍本 spike 的 9 项探针；② 通过 `NOTICE.md` §5 的
> GPL-3.0 兼容性核查（C-DEP-7）。

## 5. 建议

1. **优先用本 spike 复测 `flutter_qjs_next`**（同一份探针，换 import 与运行时构造即可）。
   若其通过，直接采用它，**不引入 fork**：维护一个已停止维护的包不划算。
2. 若 `flutter_qjs_next` 不满足，**次选是 fork `flutter_js_plus`**（补丁量已实测很小：
   2 处签名 + 1 处 coalesce + 1 行 CMake），并以 `dependency_overrides` 指向 `third_party/`，
   同时按 C-DEP-7 记录其 MIT 许可与来源。
3. **无论选哪个引擎**，5 秒超时都按已实测有效的方案实现：
   在专用 Isolate 中执行 + 预算到期 `Isolate.kill(priority: immediate)`；
   内存上限若引擎不支持，则退化为「限制单条规则的输入/输出规模」并在 ADR 中记录该降级。
4. 在引擎选定前，**不要把 `@js:` 纳入 M0 的完成判定**（`book-source.md` 矩阵 #14）。

## 6. 复现步骤

```bash
cd <repo>
export PATH="$PATH:<flutter>/bin"
P="$HOME/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_js_plus-0.0.4"
PATH="$PATH:$P/windows/shared" flutter test tool/spike/js_isolate_spike_test.dart
# Linux: LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$P/linux/shared"
# 预期：All tests passed（9 项），其中 07/08 断言记录的是平台限制
```

---

**状态：** 已完成，等待引擎选型裁决（需新增 ADR 并取代 ADR-0008 中受影响的部分）。
