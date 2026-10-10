# ADR-0002 错误契约：`ParseResult` 与 `ParseFailureKind`

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-ERR-1..3、C-ERR-7、C-ERR-8、C-SRC-8、`docs/dev/architecture.md` §5、`docs/dev/book-source.md` §7

## 背景

旧文档对错误类型有三种互不兼容的说法：

1. `AGENTS.md` §4：「返回 `ParseResult<T>`」。
2. `AGENT_CONSTRAINTS.md` §3：允许 `ParseResult<T>` **或** `Result<T, E>`，但项目中从未定义 `Result`。
3. `NAMING_CONVENTION.md` §3 声明 `ParseFailure<T>` 为泛型密封子类，而 §3 的示例却写作
   `ParseFailure('请求超时，请稍后重试', e)` —— 位置参数、无泛型实参、且把中文文案塞进失败对象，
   与「禁止硬编码用户可见字符串」直接冲突。
4. 失败分类完全没有定义，导致 UI 无法区分「超时」与「规则失效」。

## 决策

1. 可能失败的操作统一返回 `ParseResult<T>`；**不引入 `Result<T, E>`**。
2. `ParseResult<T>` 为密封类，子类固定为 `ParseSuccess<T>` 与 `ParseFailure<T>`（`final class`）。
3. `ParseFailure` 携带 `kind`（`ParseFailureKind`）、`rulePath`（必填）、`cause`、`stackTrace`。
4. **失败对象禁止携带用户可见文案**；文案由 UI 经 ARB 映射，键名规则为
   `failure<PascalCaseKind>`（例如 `failureNetworkTimeout`）。
5. 可预期失败返回 `ParseResult`；编程错误（`ArgumentError`、断言）直接抛出。

## 后果

- `ParseFailureKind` 的每个值必须在 `lib/l10n/app_{en,zh}.arb` 有对应文案键
  （`cancelled` 除外，静默处理）。
- 「规则无匹配」与「成功但结果为空」必须区分：前者 `parseFailed`，后者 `success(空列表)`。
- `ParseResult` 与扩展方法集中在 `lib/core/error/parse_result.dart`。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 同时保留 `Result<T, E>` | 项目内无任何使用场景，双类型会造成实现分裂 |
| 用异常代替返回值 | 违反 C-ERR-1，且无法在 UI 层穷尽处理 |
| 失败对象直接带中文文案 | 违反「禁止硬编码用户可见字符串」，无法国际化 |
