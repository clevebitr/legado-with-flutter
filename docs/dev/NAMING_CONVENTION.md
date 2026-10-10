# 开发命名规范（AI Coder 约束版）

> 本文档用于约束 AI 编码助手（Copilot、Cursor、Claude 等）在 Flutter 阅读 App 项目中的代码生成行为。所有 AI 生成的代码必须严格遵守本规范，否则视为不合格。人类开发者同样应遵循此规范以保持一致性。

---

## 1. 总则

- 所有代码必须符合 **Effective Dart** 与 **Flutter 官方风格指南**。
- 命名必须 **清晰、一致、可读**，避免无意义缩写（除非是广泛认可的，如 `id`、`url`、`html`）。
- AI 生成代码时，必须优先使用描述性强的完整单词，而非缩写。
- 本规范与项目根目录 `analysis_options.yaml` 中的 lint 规则配合使用，所有代码必须通过 `flutter analyze` 零警告。

---

## 2. 文件与目录命名

| 类型 | 规则 | 示例 |
|---|---|---|
| 目录 | `snake_case`，全小写 | `book_source/`、`core/theme/` |
| Dart 文件 | `snake_case` | `rule_engine.dart`、`book_source_parser.dart` |
| 测试文件 | `*_test.dart` | `rule_engine_test.dart` |
| 禁止 | 驼峰、空格、特殊字符、大写字母 | ❌ `BookSource/`、`ruleEngine.dart` |

---

## 3. 类型命名（类、枚举、typedef、扩展、mixin）

统一使用 **UpperCamelCase**。

| 类型 | 规则 | 示例 |
|---|---|---|
| 类 | 名词或名词短语 | `BookSourceParser`、`RuleEngine` |
| 抽象类 | 名词或名词短语，**不加** `Base`/`Abstract` 前缀 | `BookSourceRepository` |
| 枚举类型 | UpperCamelCase | `ParseMode` |
| 枚举值 | lowerCamelCase | `ParseMode.css`、`ParseMode.xpath` |
| typedef | UpperCamelCase | `BookSourceCallback` |
| 扩展 | UpperCamelCase | `StringExtension` |
| mixin | UpperCamelCase | `LoggingMixin` |

**书源解析核心类型命名示例：**
```dart
class BookSource { ... }
class SearchRule { ... }
class BookInfoRule { ... }
class TocRule { ... }
class ContentRule { ... }
class RuleEngine { ... }
class HtmlParser { ... }
class JsonPathEvaluator { ... }
class JsBridge { ... }
sealed class ParseResult<T> { ... }
class ParseSuccess<T> extends ParseResult<T> { ... }
class ParseFailure<T> extends ParseResult<T> { ... }
```

---

## 4. 方法 / 函数命名

统一使用 **lowerCamelCase**，**动词开头**，描述行为。

| 场景 | 规则 | 示例 |
|---|---|---|
| 普通方法 | 动词 + 名词 | `fetchBookInfo()`、`parseHtml()` |
| 异步方法 | 动词开头，**不加** `Async` 后缀 | `Future<BookInfo> fetchBookInfo()` |
| 布尔返回 | `is` / `has` / `can` / `should` 前缀 | `isValid()`、`hasMore()` |
| 私有方法 | `_` 前缀 | `_parseContent()`、`_cacheResult()` |
| 工厂方法 | `fromJson` / `fromMap` | `BookSource.fromJson()` |
| 转换方法 | `toJson` / `toMap` / `toString` | `toJson()`、`toMap()` |
| 用例类方法 | 动词 + 名词 | `SearchBooks.execute()` |

**书源解析 API 方法命名示例：**
```dart
Future<ParseResult<List<Book>>> searchBooks(String keyword, {int page = 1});
Future<ParseResult<BookInfo>> fetchBookInfo(String url);
Future<ParseResult<List<Chapter>>> fetchToc(String url);
Future<ParseResult<String>> fetchContent(String url);
ParseResult<T> parse<T>(String raw);
String renderUrlTemplate(String template, Map<String, String> params);
```

---

## 5. 变量命名

统一使用 **lowerCamelCase**。

| 类型 | 规则 | 示例 |
|---|---|---|
| 普通变量 | 名词或名词短语 | `bookList`、`searchKeyword` |
| 布尔变量 | `is` / `has` / `can` / `should` 前缀 | `isLoading`、`hasError` |
| 集合变量 | **复数名词** | `books`、`rules`、`chapters` |
| 私有变量 | `_` 前缀 | `_cache`、_parseResult` |
| 常量 | lowerCamelCase | `defaultTimeout`、`maxRetryCount` |
| 泛型参数 | 单大写字母 | `T`、`E`、`K`、`V` |
| 参数 | lowerCamelCase | `keyword`、`page`、`url` |
| 循环计数器 | `i`、`j`、`k`（仅限短循环） | `for (var i = 0; i < list.length; i++)` |

**禁止：**
- 单字母变量（除循环计数器外）
- 无意义缩写：`bs`、`ctx`、`res`、`req`
- 使用 `var` 当类型明确时（局部变量除外）
- 使用 `dynamic`，除非与 JS 引擎交互等必要场景

**正例：**
```dart
final List<Book> bookList = [];
bool isLoading = false;
final String searchKeyword = '关键词';
```

**反例：**
```dart
var bs = [];          // ❌ 缩写，类型不明确
bool load = false;    // ❌ 应为 isLoading
String kw = '关键词';  // ❌ 应为 searchKeyword
```

---

## 6. API 命名规则（特定于书源解析）

| 层级 | 命名模式 | 示例 |
|---|---|---|
| 实体 | `Xxx` | `BookSource`、`SearchRule` |
| 结果 | `ParseResult<T>` + 子类 | `ParseSuccess<T>`、`ParseFailure<T>` |
| 引擎 | `XxxEngine` | `RuleEngine` |
| 服务 | `XxxService` 或 `XxxParser` | `HtmlParser`、`JsBridge` |
| 用例 | `动词 + 名词` | `SearchBooks`、`FetchToc` |
| 仓库 | `XxxRepository` | `BookSourceRepository` |
| ViewModel | `XxxViewModel` | `BookSourceViewModel` |
| Widget | `XxxPage` / `XxxView` | `BookSourceListPage`、`ReaderView` |
| 扩展 | `XxxExtension` | `StringExtension` |

**公共 API 必须包含英文文档注释（`///`），并遵循以下格式：**
```dart
/// 执行搜索并返回书籍列表。
///
/// [keyword] 为搜索关键词，会被 URL 编码后填入模板。
/// [page] 指定页码，默认为 1。
///
/// 返回 [ParseResult] 包装的书籍列表。
Future<ParseResult<List<Book>>> searchBooks(
  String keyword, {
  int page = 1,
}) async { ... }
```

---

## 7. 注释与文档

| 类型 | 语言 | 规则 |
|---|---|---|
| 文档注释（`///`） | 英文 | 所有公共 API 必须包含；以单句摘要开头，首字母大写，句号结尾；使用 `[]` 引用其他类/方法 |
| 普通注释（`//`） | 中文 | 解释“为什么”而非“做了什么”；仅在逻辑复杂或易误解时添加 |
| TODO | 中文或英文 | 单行，包含完整描述和负责人：`// TODO(@username): 描述` |

**AI 生成代码时必须包含必要的文档注释，且文档注释必须为英文。**

---

## 8. AI Coder 约束清单

AI 在生成任何代码前，必须逐项检查以下内容：

- [ ] 文件/目录是否为 `snake_case`？
- [ ] 类/枚举/typedef/扩展是否为 `UpperCamelCase`？
- [ ] 方法是否为 `lowerCamelCase` 且动词开头？
- [ ] 变量是否为 `lowerCamelCase` 且名词？
- [ ] 布尔变量/方法是否使用 `is`/`has`/`can`/`should` 前缀？
- [ ] 集合变量是否为复数名词？
- [ ] 私有成员是否以下划线 `_` 开头？
- [ ] 常量是否为 `lowerCamelCase`？
- [ ] 公共 API 是否包含英文 `///` 文档注释？
- [ ] 是否避免了 `print()`、`dynamic`、`!` 强制解包？
- [ ] 是否使用了 `final` 或 `const` 当变量不变时？
- [ ] 导入顺序是否遵循：Dart SDK → Flutter SDK → 第三方包 → 项目内部？
- [ ] 是否通过 `flutter analyze` 和 `dart format`？

**如果命名不确定，优先选择描述性强的完整单词，而不是缩写。**

---

## 9. 速查表

| 类别 | 规则 | 示例 |
|---|---|---|
| 目录/文件 | `snake_case` | `book_source/rule_engine.dart` |
| 类/枚举/typedef | `UpperCamelCase` | `BookSourceParser` |
| 方法/函数 | `lowerCamelCase`，动词开头 | `fetchBookInfo()` |
| 变量 | `lowerCamelCase`，名词 | `bookList` |
| 常量 | `lowerCamelCase` | `defaultTimeout` |
| 私有成员 | `_` 前缀 | `_parseHtml()` |
| 布尔 | `is`/`has`/`can`/`should` 前缀 | `isLoading` |
| 集合 | 复数名词 | `books` |
| 泛型 | 单大写字母 | `T`、`E` |
| 枚举值 | `lowerCamelCase` | `ParseMode.css` |
| 测试文件 | `*_test.dart` | `rule_engine_test.dart` |
| 文档注释 | 英文 `///` | `/// Fetches book info.` |
| 普通注释 | 中文 `//` | `// 适配 Rhino 类型转换。` |

---

## 10. 与 lint 规则的对应

在 `analysis_options.yaml` 中启用以下规则以强制执行本规范：

```yaml
linter:
  rules:
    # 文档注释
    - public_member_api_docs
    - slash_for_doc_comments
    - prefer_doc_comments
    # 命名与代码质量
    - camel_case_types
    - camel_case_extensions
    - library_names
    - file_names
    - non_constant_identifier_names
    - constant_identifier_names
    - prefer_final_locals
    - always_declare_return_types
    - avoid_print
    - unawaited_futures
    - directives_ordering
    - prefer_const_constructors
    - prefer_final_fields
```

---

## 11. 给 AI 的提示词示例

在向 AI 编码助手发出指令时，可附加以下提示：

> 请严格遵循项目根目录下 `docs/NAMING_CONVENTIONS.md` 中的命名规范。生成代码时：
> - 类名使用 `UpperCamelCase`，方法名使用 `lowerCamelCase` 动词开头，变量名使用 `lowerCamelCase` 名词；
> - 常量使用 `lowerCamelCase`，私有成员以下划线 `_` 开头；
> - 布尔变量/方法使用 `is`/`has`/`can`/`should` 前缀；
> - 集合变量使用复数名词；
> - 公共 API 必须包含英文 `///` 文档注释；
> - 禁止使用 `print`、`dynamic` 和 `!` 强制解包；
> - 导入顺序：Dart SDK → Flutter SDK → 第三方包 → 项目内部。

---

**文档版本：** v1.0  
**适用项目：** Flutter 阅读 App（MD3E、多平台、Dart 书源解析）  
**维护者：** Clevebitr
**最后更新：** 2026-10-10