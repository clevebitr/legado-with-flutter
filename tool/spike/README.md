# SPIKE 1 — 后台 Isolate 中的 JS 引擎

> 执行日期：2026-10-10 · 环境：Flutter 3.47.7 / Dart 3.13.5 / Windows 11
> 关联：`docs/dev/adr/0015-adopt-flutter-qjs-next.md`（结论）、`docs/dev/adr/0008-single-js-engine.md`（被取代）

## 1. 结论

**引擎已选定：`flutter_qjs_next ^1.5.2`（ADR-0015）。** 9 项探针全部通过，
ADR-0008 的全部配额要求（5 秒超时、32MB 内存上限）**真实可实现**，且**无需给依赖打任何补丁**。

### 双引擎对照（同一份 9 项探针）

| 探针 | `flutter_js_plus 0.0.4` | **`flutter_qjs_next 1.5.2`** |
|---|---|---|
| 01 根 Isolate 求值 | ✅ | ✅ |
| 02 **后台 Isolate 创建 + 求值** | ✅ | ✅ |
| 03 **JS→Dart 回调桥（后台 Isolate）** | ✅ | ✅ |
| 03b 回调桥根 Isolate 对照 | ✅ | ✅ |
| 04 runaway 可被 `Isolate.kill` 终止 | ✅ 3002ms | ✅ 3002ms |
| 05 终止后原生库仍可用 | ✅ | ✅ |
| 06 复用运行时性能（100 次求值） | 0.11 ms/次 | **0.18 ms/次** |
| 07 **引擎级超时终止 runaway** | ❌ 无效（靠 6s 预算杀 Isolate 才停） | ✅ **2012ms 准确中断**，且运行时仍可用（`afterValue=2`） |
| 08 **内存上限真实生效** | ❌ 符号缺失（`jsSetMemoryLimit`） | ✅ **8MB 上限在 99ms 内抛错** |
| 可直接构建 | ❌ 4 处 Dart 编译错 + Windows CMake 名错 | ✅ 无需补丁 |
| 陈旧原生库检测 | ❌ 静默失败 | ✅ `_checkNativeAbi` 显式报错 |

**结论：ADR-0008 的核心架构假设成立（JS 可在 Isolate 中安全执行、回调桥可用），
其两项配额要求只有换成 `flutter_qjs_next` 才能满足。**

## 2. 已废弃引擎的缺陷记录（`flutter_js_plus 0.0.4`）

保留于此以便追溯，并作为"为什么换引擎"的证据：

| # | 缺陷 | 位置 | 影响 |
|---|---|---|---|
| 1 | `Pointer.fromFunction` 的回调返回**可空** `Pointer`，Dart 3.13 拒绝编译 | `lib/quickjs/quickjs_runtime.dart` 3 处 + `lib/quickjs/ffi.dart` 1 处 | **全平台不可用**：任何 import 都编译失败 |
| 2 | Windows CMake 目标名与包名不匹配 | `windows/CMakeLists.txt` | `flutter build windows` 直接失败 |
| 3 | 预编译 DLL 缺 `jsSetMemoryLimit` | `windows/shared/quickjs_c_bridge.dll` | 内存上限物理不可用 |
| 4 | `timeout` 参数无实际效果 | `QuickJsRuntime2._ensureEngine()` | 引擎级超时不可用 |

> 方法论教训：早期"APK 构建成功"**完全没有验证 JS 路径** —— Dart 只编译**可达**的库，
> 而 app 当时从未 import 该依赖。集成探针的价值正在于此。

## 3. 运行方式

不再需要给 pub cache 打补丁。原生库由正常构建产出：

```bash
export PATH="$PATH:<flutter>/bin"

# 1) 先构建目标平台的原生库
flutter build windows --debug        # 或 flutter build linux --debug / apk

# 2) 用环境变量指到产物（该 fork 的内置机制，并带 ABI 校验）
FLUTTER_QJS_NEXT_LIBRARY="<repo>/build/windows/x64/runner/Debug/flutter_qjs_next_plugin.dll" \
  flutter test tool/spike/js_isolate_spike_test.dart

# Linux:
# FLUTTER_QJS_NEXT_LIBRARY="<repo>/build/linux/x64/debug/bundle/lib/libflutter_qjs_next_plugin.so"
```

预期：`All tests passed`（9 项）。

**为什么不进 CI：** 需要先构建原生库；CI 目前不构建桌面/移动产物。
等 `@js:` 正式落地后，应改为在 CI 中先 `flutter build linux --debug` 再跑本探针。

## 4. 对实现的具体约束（写入 `book-source.md` §6 前须固化）

1. **`sendMessage` 的载荷必须是合法 JSON**。桥接层用 `jsonDecode` 解析，传裸字符串
   （如 `'ping'`）会抛 `FormatException`。应写成 `sendMessage(channel, JSON.stringify(v))`。
2. **超时用引擎中断器**：`QuickJsRuntime2(timeout: 5000)`；调用方仍须持有硬预算并
   `Isolate.kill` 兜底。
3. **内存上限用 `memoryLimit: 32 * 1024 * 1024`**（该引擎默认 64MB）。
4. 引擎实例创建成本并不低（探针 02 的整轮耗时含创建），**必须复用**：
   按 `JsEnginePool` 或每书源一个长驻 Isolate + 复用运行时。
5. **脚本执行中 `Isolate.kill` 在本机会 hang（2026-10-12 实测，3.4 part 3）**：第一次在
   Windows 设备探针里跑「额度超限」用例时，判决后立刻杀隔离体直接把探针卡死（`Isolate.kill`
   只能在该 isolate 回到 Dart 事件循环时生效，而它正卡在原生 `evaluate` 里）。因此**致命边界
   （额度 / `parse.*` 边界）不杀 worker**：判决先记录、拒绝后续绑定调用，等脚本自己的结果回来
   （或引擎中断 / 硬预算兜底）再交付。语义归 `book-source.md` §6；这条坑登记在此以免重踩。

## 5. 复现清单

| 项 | 值 |
|---|---|
| 探针代码 | `tool/spike/js_isolate_spike_test.dart`（9 项） |
| 引擎 | `flutter_qjs_next 1.5.2`（MIT） |
| 原生库 | `flutter build windows --debug` 产出 2.9 MB DLL |
| 全绿命令 | `FLUTTER_QJS_NEXT_LIBRARY=... flutter test tool/spike/js_isolate_spike_test.dart` |

---

**状态：** 已完成。引擎选型结论见 ADR-0015；本文档作为该引擎的回归基线保留。
