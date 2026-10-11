# ADR-0022 书源 JSON 解析启用 json_serializable 的 `checked` 模式

- **状态：** Accepted（2026-10-11 **由架构师复审指令裁决**；本 ADR 是记录，不是作者自决）
- **日期：** 2026-10-11
- **关联：** C-ERR-1、C-ERR-2、C-SRC-7、C-SRC-8、C-DEP-3、C-DEP-4、C-DEP-5、C-DOC-4、
  ADR-0013、ADR-0019、ADR-0021、`docs/dev/book-source.md` §7、`build.yaml`

## 背景

`book-source.md` §7 规定：导入的 JSON「缺必填字段或结构非法」必须变成
`ParseFailureKind.invalidBookSource`。Phase 2.1 落地书源模型时发现**该失败语义在实现上不可达**：

| 环节 | 事实 |
|---|---|
| json_serializable 默认值 | `checked: false`（已核实 `json_serializable 6.14.1` 的 `lib/src/type_helpers/config_types.dart`：`ClassConfig.defaults.checked = false`） |
| 未检查模式的缺键 | 生成 `json['bookSourceUrl'] as String` → 抛 `TypeError` |
| 未检查模式的非法枚举 | `$enumDecodeNullable` → 抛 `ArgumentError`（已核实 `json_annotation 4.12.0` 的 `enum_helpers.dart`） |
| 两者的类型 | `TypeError` / `ArgumentError` 都是 `Error`，不是 `Exception` |
| 冲突 | C-ERR-2 由 lint `avoid_catching_errors`（error 级）强制「禁止捕获 `Error`」，因此导入层**写不出**「catch 住畸形输入 → 返回 `invalidBookSource`」的代码 |

「在导入层解析前显式校验原始 map」曾被列为备选，但它会把「哪些字段必填、什么类型」
复制到模型之外，模型加一个字段就会漂移——正是 ADR-0013 §1（一个事实只定义一次）
禁止的重复定义，也是 ADR-0021 否决 `data/` DTO 的同一理由。

架构师复审时实测核实：`checked` 是受支持的构建期选项，开启后抛
`CheckedFromJsonException implements Exception`（已核实 `json_annotation 4.12.0` 的
`lib/src/checked_helpers.dart:97`），并自带 `key` / `innerError` / `className`，
因此一次 catch 即可同时覆盖「缺必填字段」「类型非法」「`header` 非法」「枚举取值非法」。

## 决策

1. **根目录新增 `build.yaml`**，对 `json_serializable` 设 `checked: true`；它是该生成器
   选项的唯一来源，生成命令的唯一来源仍是 C-DEP-4。
2. **生成物必须同 PR 重新生成**（C-DEP-4、C-DEP-5）：`*.g.dart` 的 `fromJson` 形态会从
   `_X(...)` 变为 `$checkedCreate(...)`。
3. **导入层据 `CheckedFromJsonException` 映射失败**：`key` 是出错字段，即 C-SRC-8 要求的
   `rulePath` 来源；`innerError` 区分原因（`TypeError` = 缺键或类型错，`FormatException` =
   `header` 非法，`ArgumentError` = 枚举取值非法）。
   **`badKey` 不得作为判据**：它只在 `innerError is BadKeyException` 时为 `true`
   （`checked_helpers.dart:141`），而本项目生成的代码不会产生该异常。
4. **未知 `bookSourceType` 一律拒绝整份书源，不回落 `BookSourceType.text`**：回落会把音频 /
   图片源静默当成文本源，比导入失败更难排查；`book-source.md` §7 的「结构非法」本来就该
   显式失败。
5. `checked` 的语义随 `json_serializable` 版本变化（包装行为在 `$checkedConvert` /
   `$checkedNew` 内）。**升级该依赖后必须复验本 ADR**，不得凭记忆沿用结论。

## 后果

- C-ERR-2 的解释被钉死：**可预期失败统一为 `Exception`；`Error` 仍禁止捕获**。
  「用 `// ignore: avoid_catching_errors` 捕获 `Error`」不再是可选项（C-DOC-4）。
- 测试断言从 `throwsFormatException` / `throwsA(anything)` 收紧为
  `CheckedFromJsonException` + `key` + `innerError`，顺带消除了弱断言。
- 新增根配置文件 → 登记进 `docs/README.md` §4；启用理由与影响记入
  `docs/dev/tech-stack.md` §8。
- 影响面可控：当前唯一的 json_serializable 输入是书源模型，重生成只改动
  `book_source.g.dart`；后续新增 JSON 模型沿用同一配置，无需再改本文件。
- 该选项是**全局**的：它同时决定了未来所有 JSON 模型对畸形输入的行为。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 导入层解析前显式校验原始 map | 把必填字段与类型清单复制到模型之外（ADR-0013 §1），模型一改就漂移 |
| 保持未检查模式，在导入层 `// ignore: avoid_catching_errors` 捕获 `Error` | 违反 C-ERR-2 与 C-DOC-4；`Error` 表示编程错误，不应被当作可预期失败 |
| 手写 `fromJson` 自行返回 `ParseFailure` | 违反 C-SRC-7（禁止手写 `fromJson` / `toJson`） |
| 只对书源模型写 `@JsonSerializable(checked: true)` | freezed 生成的是裸 `@JsonSerializable()`，作者无法为其注入该参数；只能用构建期全局配置 |
| 让未知枚举值回落 `text`（`unknownEnumValue`） | 静默改变书源语义：音频 / 图片源会被当成文本源，违反 C-SRC-4 的「禁止静默」精神 |
