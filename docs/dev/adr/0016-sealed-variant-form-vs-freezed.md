# ADR-0016 密封层级的子类形态以编译器产物为准（放弃 `final class` 字面要求）

- **状态：** Accepted
- **日期：** 2026-10-11
- **关联：** `docs/dev/naming.md` §3、ADR-0002、C-SRC-7、C-DEP-3、`docs/dev/architecture.md` §5、`docs/dev/constraints.md` §12

## 背景

`naming.md` §3 与 `ADR-0002` §2 都写「`ParseResult` 的密封层级必须使用 `final class` 子类，
以保证 `switch` 穷尽性检查生效」。但同一条链路上的另外两处规范要求用 freezed：

- C-SRC-7：`BookSource` 及全部子规则必须 `freezed` + `json_serializable`；
- C-DEP-3 / `architecture.md` §5：`ParseResult` 契约以 `@freezed sealed class` 给出。

Phase 1.1 落地时实测（`lib/core/error/parse_result.dart` + `dart run build_runner build`）：

```dart
// lib/core/error/parse_result.freezed.dart（freezed 3.x 产物，非手改）
class ParseSuccess<T> implements ParseResult<T> { ... }
class ParseFailure<T> implements ParseResult<T> { ... }
```

即：**freezed 3 生成的是 `class`（非 `final`）且使用 `implements`，并不存在生成
`final class` 的选项**。两条规范不可同时满足，必须裁决。

同时需要澄清一个传播较广的误解：Dart 的 `switch` 穷尽性来自 **`sealed` 修饰符**
（封闭「同库直接子类」集合），**不来自** `final`。`final` 的作用是阻止**外部库**
通过 `implements`/`extends` 二次派生中间子类，从而把穷尽性边界钉死。

## 决策

1. **以编译器产物为准**：接受 freezed 生成的 `class X<T> implements ParseResult<T>` 形态，
   不再字面要求 `final class`。
2. 穷尽性的**唯一依据**是「`sealed` + 子类与基类同库 + 消费方 `switch` 无 `default`」；
   该依据必须在规范中写明，避免下一个人把 `final` 当成穷尽性的来源。
3. `naming.md` §3 与 `ADR-0002` §2 的措辞同步修正（ADR-0002 保留原文并加修订说明，
   按 `docs/dev/adr/README.md` 的状态规则不删除历史结论）。
4. 若将来某条密封层级**确实**需要禁止外部库二次派生（例如安全相关的封闭集合），
   则该层级**不得使用 freezed**，改为手写 `sealed` + `final class` 子类，
   并必须在该类型的文档注释中写明「此处刻意不用 freezed」及理由。
5. 类型定义的**完整契约清单**（`ParseResult`）仍由 `architecture.md` §5 拥有，
   本文档只裁决「子类形态」这一点，不复述契约字段。

## 后果

- 自动化检查不变：`flutter analyze` 对 `switch` 缺分支报错的行为由 `sealed` 保证，
  与本文档结论一致（Phase 1.1 的 `dataOrNull` / `whenSuccess` 已实测无 `default` 通过）。
- `parse_result.freezed.dart` 属生成物，禁止手改（C-DEP-5）；形态变化只能通过升级
  freezed 触发，升级时必须重新核对本 ADR。
- 生成物形态属于**编译器/生成器**的事实，不是项目可承诺的接口；任何依赖「子类必为
  `final`」的写法（例如自定义 lint、代码模板）都必须改为依赖 `sealed`。
- `naming.md` §3 的示例代码块同步改为 freezed 形态，避免再次出现「规范示例无法编译」。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 手写 `sealed` + `final class` 子类，`ParseResult` 弃用 freezed | 丢失 `==`/`hashCode`/`copyWith`/`toString`，需手写约 90 行样板；且与 C-DEP-3、`architecture.md` §5 冲突，收益仅是字面上的 `final` |
| 保留规范原文，把 Phase 1.1 实现判为不合规 | 该实现是本项目 `ParseResult` 契约的**既定示范**（ADR-0002 + `architecture.md` §5 的代码块），判它不合规等于同时否定这两份文档 |
| 给 freezed 加自定义生成模板产出 `final class` | 需要长期维护生成器补丁，违反 `PLAN.md` §6 陷阱 #2（不给依赖打补丁） |
