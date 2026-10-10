# ADR-0006 日志统一 `logger` + `core/logging` 门面

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-ERR-5、C-ERR-8、C-SEC-4、`docs/dev/tech-stack.md` §7

## 背景

旧文档要求「禁止 `print`，必须使用 `logger` 或 `debugPrint`」（`AGENT_CONSTRAINTS.md` §3/§11），
但依赖清单里**没有任何日志包**；同时 §3 的示例直接使用 `_logger.warning(...)`，
却没有定义 `_logger` 从哪来、级别如何配置、字段如何脱敏。

## 决策

1. 引入 `logger` 作为日志实现。
2. 业务代码**只允许**通过 `lib/core/logging/` 暴露的门面使用日志；禁止直接 import `package:logger`。
3. 门面方法：`debug` / `info` / `warning` / `error`，均接受 `(String message, [Object? error, StackTrace? stackTrace])`。
4. 日志级别：debug 与 release 构建下默认 `info`；通过 `--dart-define=LOG_LEVEL=` 覆盖。
5. 强制脱敏：`Cookie`、`Authorization`、`Token`、页面正文、搜索关键词原文不得进入日志
   （C-ERR-8、C-SEC-4）。搜索关键词以长度与哈希代替。

## 后果

- `core/logging` 的 Logger 通过 Provider 注入，测试可注入内存收集器并断言级别与内容。
- 书源相关日志必须自动附加 `rulePath` 与书源 ID，便于定位失效规则。
- `avoid_print` 在 `analysis_options.yaml` 中为 **error** 级别，`debugPrint` 亦不允许。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 只用 `debugPrint` | 无级别、无结构化字段、release 下仍需手工剥离 |
| 直接用 `package:logging` | 需要自建输出格式与级别分层，成本高于收益 |
| 直接使用 `package:logger`，不设门面 | 无法统一脱敏与字段约定，也难在测试中断言 |
