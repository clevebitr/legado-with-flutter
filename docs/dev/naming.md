# 命名规范

> 本文档是**命名主题的唯一来源**。其他文档只能引用，不得复述。
> 命名相关的 lint 规则及其与本文档的映射见 `docs/dev/tech-stack.md`。
> 本文档不含自查清单与 AI 提示词模板，二者只存在于 `docs/dev/constraints.md` 末尾。

---

## 1. 总则

- 所有代码遵循 **Effective Dart** 与 **Flutter 官方风格指南**，并通过 `flutter analyze` 零警告。
- 命名必须**清晰、一致、可读**；优先使用描述性强的完整单词。
- 仅在广泛认可时才使用缩写，白名单：`id`、`url`、`uri`、`html`、`css`、`js`、`json`、`api`、`ip`、`toc`、`ui`、`db`。
- 其他任何缩写（`bs`、`ctx`、`res`、`req`、`kw`、`btn`）一律禁止。

---

## 2. 文件与目录命名

| 类型 | 规则 | 示例 |
|---|---|---|
| 目录 | `snake_case`，全小写 | `book_source/`、`core/theme/` |
| Dart 文件 | `snake_case` | `rule_engine.dart`、`book_source_parser.dart` |
| 基础设施 Provider 文件（仅 `core/di/`） | `<subject>_provider.dart` | `logger_provider.dart`、`http_client_provider.dart` |
| 测试文件 | `*_test.dart`；位置（镜像 `lib/` / `integration_test/`）见 `docs/dev/testing.md` §3（ADR-0017） | `test/core/error/parse_result_test.dart`、`integration_test/app_boot_test.dart` |
| 生成文件 | 由工具决定，禁止改名、禁止手改 | `book_source.freezed.dart` |
| ADR | `docs/dev/adr/NNNN-kebab-title.md` | `0001-riverpod-codegen-only.md` |
| ARB | `app_<locale>.arb` | `app_en.arb`、`app_zh.arb` |
| 禁止 | 驼峰、空格、特殊字符、大写字母 | ❌ `BookSource/`、`ruleEngine.dart` |

目录归属规则见 `docs/dev/architecture.md`，不得自行发明目录层级。

---

## 3. 类型命名（类、枚举、typedef、扩展、mixin）

统一使用 **UpperCamelCase**。

| 类型 | 规则 | 示例 |
|---|---|---|
| 类 | 名词或名词短语 | `BookSourceParser`、`RuleEngine` |
| 抽象类 | 名词或名词短语，**不加** `Base` / `Abstract` 前缀 | `BookSourceRepository` |
| 枚举类型 | UpperCamelCase | `ParseMode`、`ParseFailureKind` |
| 枚举值 | lowerCamelCase | `ParseMode.css`、`ParseFailureKind.networkTimeout` |
| typedef | UpperCamelCase | `BookSourceCallback` |
| 扩展 | UpperCamelCase，`XxxExtension` | `StringExtension` |
| mixin | UpperCamelCase，`XxxMixin` | `LoggingMixin` |

**书源解析核心类型：**

```dart
class BookSource { /* ... */ }
class SearchRule { /* ... */ }
class BookInfoRule { /* ... */ }
class TocRule { /* ... */ }
class ContentRule { /* ... */ }
class RuleEngine { /* ... */ }
class HtmlParser { /* ... */ }
class JsonPathEvaluator { /* ... */ }
class JsBridge { /* ... */ }
sealed class ParseResult<T> { /* ... */ }
class ParseSuccess<T> implements ParseResult<T> { /* ... */ }
class ParseFailure<T> implements ParseResult<T> { /* ... */ }
```

`ParseResult` 的密封层级：穷尽性来自 **`sealed` + 子类与基类同库**，
**不**来自子类是否带 `final`。实际子类由 freezed 生成，形态就是上面这种
`class X<T> implements ParseResult<T>`；`final class` 不是本项目的硬性要求
（freezed 也无法生成）。若某个密封层级确实需要禁止外部库二次派生，
必须弃用 freezed 改为手写 `sealed` + `final class`，并在类型注释中写明理由（ADR-0016）。

---

## 4. 方法 / 函数命名

统一使用 **lowerCamelCase**，**动词开头**。

| 场景 | 规则 | 示例 |
|---|---|---|
| 普通方法 | 动词 + 名词 | `fetchBookInfo()`、`parseHtml()` |
| 异步方法 | 动词开头，**不加** `Async` 后缀 | `Future<BookInfo> fetchBookInfo()` |
| 布尔返回 | `is` / `has` / `can` / `should` 前缀 | `isValid()`、`hasMore()` |
| 私有方法 | `_` 前缀 | `_parseContent()`、`_cacheResult()` |
| 工厂方法 | `fromJson` / `fromMap` | `BookSource.fromJson()` |
| 转换方法 | `toJson` / `toMap` / `toString` | `toJson()` |
| 用例方法 | 统一为 `execute()`（类名为 动词+名词） | `SearchBooks.execute()` |
| 事件回调 | `on` + 事件名 | `onBookSourceTapped` |

**书源解析 API：**

```dart
Future<ParseResult<List<Book>>> searchBooks(String keyword, {int page = 1});
Future<ParseResult<BookInfo>> fetchBookInfo(String url);
Future<ParseResult<List<Chapter>>> fetchToc(String url);
Future<ParseResult<String>> fetchContent(String url);
String renderUrlTemplate(
  String template,
  Map<String, String> params, {
  required AppLogger logger,
});
```

`renderUrlTemplate` 的 `logger` 必须由调用方注入（未定义变量要记 warning）——项目禁止
全局 logger，也禁止在 `domain/` 里 `ref.watch`（C-ARCH-7）。

> **归属说明（2026-10-11）：** `renderUrlTemplate` 是纯函数（实现位于
> `lib/features/book_source/domain/url_template.dart`），命名由**本节**管；§6 只列
> 类型与分层命名模式，因此**不为它另立一行**。

---

## 5. 变量与常量命名

统一使用 **lowerCamelCase**。

| 类型 | 规则 | 示例 |
|---|---|---|
| 普通变量 | 名词或名词短语 | `bookList`、`searchKeyword` |
| 布尔变量 | `is` / `has` / `can` / `should` 前缀 | `isLoading`、`hasError` |
| 集合变量 | **复数名词** | `books`、`rules`、`chapters` |
| 私有成员 | `_` 前缀 | `_cache`、`_parseResult` |
| 常量 | lowerCamelCase（**不是** SCREAMING_CAPS） | `defaultTimeout`、`maxRetryCount` |
| 泛型参数 | 单大写字母 | `T`、`E`、`K`、`V` |
| 参数 | lowerCamelCase | `keyword`、`page`、`url` |
| 循环计数器 | `i`、`j`、`k`（仅限短循环） | `for (var i = 0; i < list.length; i++)` |

**禁止：** 单字母变量（循环计数器除外）、无意义缩写、类型明确时的 `var`、`dynamic`（JS 桥接除外）。

```dart
// ✅
final List<Book> bookList = <Book>[];
bool isLoading = false;
const Duration defaultTimeout = Duration(seconds: 15);

// ❌
var bs = [];                 // 缩写且类型不明确
bool load = false;           // 应为 isLoading
const DEFAULT_TIMEOUT = 15;  // 常量必须 lowerCamelCase
```

---

## 6. API 分层命名模式

| 层级 | 命名模式 | 示例 |
|---|---|---|
| 实体 | `Xxx` | `BookSource`、`SearchRule` |
| 结果 | `ParseResult<T>` + `ParseSuccess<T>` / `ParseFailure<T>` | — |
| 引擎 | `XxxEngine` | `RuleEngine` |
| 服务 | `XxxService` / `XxxParser` | `HtmlParser`、`JsBridge` |
| 用例 | 动词 + 名词，方法 `execute()` | `SearchBooks`、`FetchToc` |
| 仓储接口 | `XxxRepository`（放在 `domain/`） | `BookSourceRepository` |
| 仓储实现 | `XxxRepositoryImpl`（放在 `data/`） | `BookSourceRepositoryImpl` |
| 数据源 | `XxxDataSource` | `BookSourceLocalDataSource` |
| 状态 | `XxxNotifier`（Riverpod 代码生成） | `BookSourceListNotifier` |
| 基础设施 Provider | 被注入对象的名词，lowerCamelCase，**不加** `Provider` 后缀；文件见 §2 | `@riverpod AppLogger appLogger(Ref ref)` → `appLoggerProvider` |
| Widget | `XxxPage` / `XxxView` | `BookSourceListPage`、`ReaderView` |
| 扩展 | `XxxExtension` | `StringExtension` |

> **关于 ViewModel：** 本项目使用 Riverpod 代码生成，`XxxViewModel` 命名与
> `presentation/viewmodels/` 目录**已废弃**，统一为 `XxxNotifier` +
> `presentation/notifiers/`。理由见 `docs/dev/adr/0001-riverpod-codegen-only.md`。

---

## 7. 注释与文档

| 类型 | 语言 | 规则 |
|---|---|---|
| 文档注释 `///` | 英文 | 所有公共 API 必须包含；单句摘要开头、首字母大写、句号结尾；引用其他符号用 `[]` |
| 普通注释 `//` | 中文 | 解释「为什么」而非「做了什么」；仅在逻辑复杂或易误解处添加 |
| 行内禁用注释 | — | 禁止注释掉的死代码；禁止 `// ignore:` 无理由豁免 lint（确需豁免必须写明理由与关联 issue） |

```dart
/// Searches books with the given keyword.
///
/// [keyword] is URL-encoded before being rendered into the search template.
/// [page] defaults to 1.
///
/// Returns a [ParseResult] wrapping the matched books.
Future<ParseResult<List<Book>>> searchBooks(
  String keyword, {
  int page = 1,
}) async { /* ... */ }
```

---

## 8. 国际化键名

- ARB key 使用 lowerCamelCase，并以 feature 作前缀以避免冲突：`bookSourceListTitle`、`readerMenuChapterList`。
- 失败文案键统一以 `failure` 前缀 + `ParseFailureKind` 名：`failureNetworkTimeout`。
- 新增键必须**同时**更新 `lib/l10n/app_en.arb` 与 `lib/l10n/app_zh.arb`，
  英文文件必须带 `@key.description`。详见 `docs/dev/tech-stack.md` §4。

---

## 9. 速查表

| 类别 | 规则 | 示例 |
|---|---|---|
| 目录 / 文件 | `snake_case` | `book_source/rule_engine.dart` |
| 类 / 枚举 / typedef / 扩展 / mixin | `UpperCamelCase` | `BookSourceParser` |
| 方法 / 函数 | `lowerCamelCase`，动词开头 | `fetchBookInfo()` |
| 变量 | `lowerCamelCase`，名词 | `bookList` |
| 常量 | `lowerCamelCase` | `defaultTimeout` |
| 私有成员 | `_` 前缀 | `_parseHtml()` |
| 布尔 | `is` / `has` / `can` / `should` 前缀 | `isLoading` |
| 集合 | 复数名词 | `books` |
| 泛型 | 单大写字母 | `T`、`E` |
| 枚举值 | `lowerCamelCase` | `ParseMode.css` |
| 测试文件 | `*_test.dart` | `rule_engine_test.dart` |
| ADR 文件 | `NNNN-kebab-title.md` | `0001-riverpod-codegen-only.md` |
| 文档注释 | 英文 `///` | `/// Searches books.` |
| 普通注释 | 中文 `//` | `// 适配 Rhino 类型转换。` |
| ARB key | `lowerCamelCase` + feature 前缀 | `bookSourceListTitle` |
