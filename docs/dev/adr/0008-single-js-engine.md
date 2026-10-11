# ADR-0008 JS 引擎只保留 `flutter_js_plus`

- **状态：** **Superseded by ADR-0015**（2026-10-10）—— 核心架构假设经实测成立，但所选依赖不可用，已改用 `flutter_qjs_next`
- **日期：** 2026-10-10
- **关联：** C-SRC-2、C-SRC-3、ADR-0015、`docs/dev/book-source.md` §6、`docs/dev/tech-stack.md` §5、`tool/spike/README.md`

> ## ⚠️ 实测结论（2026-10-10，见 `tool/spike/README.md`）
>
> **本节是 spike 期的中间状态记录，已被 ADR-0015 完全取代：**
> 引擎已选定为 `flutter_qjs_next 1.5.2`，`@js:` 已恢复为 **M0**
> （见 `docs/dev/book-source.md` §3.1）。下文的「引擎选型未定」只是当时的结论，
> 保留仅为可追溯，不得作为当前规范引用。
> 本 ADR 的**核心架构假设成立**：QuickJS 可在后台 Isolate 中创建、求值，
> 且 JS→Dart 回调桥在 Isolate 内同样可用；runaway 脚本可由 `Isolate.kill` 终止且
> 不污染原生库；复用运行时下 100 次求值仅 11ms（0.11ms/次）。
>
> 但以下部分**已被证据推翻，并已由 ADR-0015 取代**：
>
> | 本 ADR 的结论 | 实测 |
> |---|---|
> | 采用 `flutter_js_plus 0.0.4` | ❌ 该版本在 Dart 3.13 下**编译失败**（4 处 `Pointer.fromFunction` 可空返回），Windows 上还有 CMake 目标名错误 |
> | 单次 JS 超时 5 秒（引擎中断器） | ❌ `timeout` 参数**无效**；必须由调用方用「预算到期 `Isolate.kill`」实现 |
> | 内存上限 32 MB | ❌ 预编译 DLL 未导出 `jsSetMemoryLimit` |
> | 禁止在后台 Isolate 使用回调桥 | ✅ **担忧不成立**：回调桥在 Isolate 内正常工作 |
>
> **引擎选型未定（今已由 ADR-0015 取代）**：候选与建议见 `tool/spike/README.md` §4–5（首选 `flutter_qjs_next`）。
> 该中间状态下的限制「`@js:` 不得计入 M0 完成判定」**已失效**。

## 背景

`AGENT_CONSTRAINTS.md` §5 写「JavaScript 执行必须通过 `flutter_js_plus` / `flutter_qjs`」，
但依赖清单中只有 `flutter_js_plus`；同时约束要求「在独立 Isolate 中运行」，
而基于 platform channel 的 JS 插件在后台 Isolate 中无法直接使用回调桥。

## 决策

1. 只使用 **`flutter_js_plus`**；禁止引入 `flutter_qjs`。
2. 依据其 FFI 实现（Android/Linux/Windows 走 QuickJS，iOS/macOS 走 JavaScriptCore），
   JS 运行时可在后台 Isolate 中执行，满足 C-SRC-2。
3. **禁止**在后台 Isolate 中使用依赖 platform channel 的回调桥
   （如 `JavascriptRuntime.onMessage`）；确需双向通信时必须使用
   `BackgroundIsolateBinaryMessenger`，并在 `docs/dev/book-source.md` §10 补对应测试。
4. 必须实现配额：单次 JS 墙钟超时 5 秒、内存上限 32 MB、单条规则 JS 调用 ≤ 20 次；
   超时或异常映射为 `ParseFailure(parseFailed)`。

## 后果

- `docs/dev/book-source.md` §6 定义了 JS 白名单与配额；白名单之外的绑定一律不暴露。
- 真实 JS 引擎测试只能在 `integration_test` 中运行并标记 `@Tags(['js'])`；
  单元测试使用假 `JsBridge`。
- 若 `flutter_js_plus` 在某一目标平台失效，必须新开 ADR 评估替代方案，
  不得在代码中按平台切换引擎。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 双引擎并存（`flutter_js_plus` + `flutter_qjs`） | 两套语义与错误模型，规则行为不可复现 |
| 自建 QuickJS FFI 绑定 | 维护成本高，且需自行处理多平台构建 |
| 不实现 JS 规则 | 会丢弃 `@js:` 规则，命中大量真实书源，等于放弃兼容目标 |
