# ADR-0008 JS 引擎只保留 `flutter_js_plus`

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-SRC-2、C-SRC-3、`docs/dev/book-source.md` §6、`docs/dev/tech-stack.md` §5

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
