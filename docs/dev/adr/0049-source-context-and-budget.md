# ADR-0049 书源规则的上下文与单源预算：`ChapterRequest`、`java.get` 的两个内置键、`SourceBudget`

- **状态：** Accepted（2026-10-21，M12 规格前置；用户裁决「改端口，一次做对」+「新增 domain 协作者 `SourceBudget`」）
- **日期：** 2026-10-21
- **关联：** C-ARCH-2、C-ERR-1、C-ERR-2、ADR-0034、ADR-0041、ADR-0043、ADR-0046、ADR-0047 §决策 8、
  `docs/dev/book-source.md` §6、`docs/dev/roadmap.md` §3.7-B7

## 背景

M12 剩下两项，都是 §3.7 登记过的：

1. **`java.get('bookName' / 'title')`**（上游 `AnalyzeRule.get`，`AnalyzeRule.kt:812-821`）在上游是**内置键**：
   `when (key)` 先答书名 / 章节名，查不到才落到变量表。本仓的 `java.get` 只认变量表，而
   `FetchContent.execute(source, url)` 只收一个 URL —— 书名与章节名**在域层根本没有入口**。
2. **单源预算**（§3.7-B7）：聚合搜索 60 s（ADR-0046）、校验 180 s（ADR-0043）、`HttpPolicy` 15 s
   三处各写一份；前两处各自 `.timeout(...)`，第三个调用方出现时会写第四份。

## 决策

### 决策 1 `ChapterRequest` 取代裸 URL，书与章节是**上下文**而不是规则

- 新值对象 `ChapterRequest{url, title, bookName}`（freezed，`domain/entities/`）：
  `FetchContent.execute(source, ChapterRequest)`；
  `FetchToc.execute(source, url, {String bookName = ''})`。
- 它只带**调用方已经知道**的东西：阅读器手里有书名与章节名（`ReaderBook.name` + 目录项标题），
  校验有 `BookInfo.name` 与 `Chapter.name`，详情页 / 调试控制台只有一个 URL —— 那就留空。
- **空值不是错误**：`bookName` / `title` 为空时 `java.get` 回落到变量表（见决策 2），
  所以「不知道」与「知道」是同一条路径，不需要两个入口。

### 决策 2 `java.get` 的两个内置键**先于**变量表

- `JsJob` / worker 的消息带上 `bookName` / `chapterTitle`；`applyJsJavaCall` 的读分支是
  `named[key] ?? variables[key] ?? ''`。
- **顺序是契约，不是实现细节**：`java.put('title', …)` 不能劫持内置键，这正是上游 `when (key)` 的含义。
  单测 `applyJsJavaCall_givenABookName_answersItBeforeTheVariables` 钉住它。
- `Decode` 侧把空串当缺失（`decodeJsNamedContext`），因此「阶段不知道书名」不会等于「书名叫空串」而
  覆盖掉一个同名变量。
- 上下文挂在 **`JsPageContext`（页面）**上，而不是逐字段传：页面 scope 派生出的每个条目、每条规则、
  每次翻页都继承它 —— 这也是 `_pagingContext` 要把两个值抄过去的原因（`book-source.md` §6 的 `baseUrl`
  同一条继承规则）。

### 决策 3 `SourceBudget` 是「一个源一份预算」的唯一实现

- 新协作者 `domain/source_budget.dart`：

  ```dart
  final class SourceBudget {
    SourceBudget(Duration limit, {Clock clock = const SystemClock()});
    Duration get remaining;   // 不为负
    bool get isExpired;
    Future<ParseResult<T>> run<T>(Future<ParseResult<T>> Function() op, {required String rulePath});
  }
  ```

- 语义三条：
  1. **只决定等多久，不决定成不成**：`op` 自己的失败原样穿出去；
  2. 预算耗尽 → `ParseFailureKind.networkTimeout`，`rulePath` 由调用方给（`book-source.md` §7 的 9 个 kind
     里没有更近的桶）；
  3. **不作废在飞的请求**：HTTP 层没有取消原语，被放弃的请求按自己的 `HttpPolicy` 结束
     （ADR-0043 §后果 同一口径）。
- 接线：
  - 聚合搜索：每个源 `SourceBudget(60 s)`，包住 `SearchBooks.execute`；预算耗尽仍**不**计入
    「整批失败原因」（ADR-0046 §决策 5 的行为不变，只换成同一个实现）。
  - 校验：**一个源一份**预算跨全部阶段（原来就是 `startedAt + timeout` 的 deadline，现在换成
    `SourceBudget`，行为不变，`_CheckRun` 不再自己算时间）。
- 时钟注入（`Clock`）让测试用 `FakeClock` 花预算而不是 `sleep`（`docs/dev/testing.md` §8）。

### 决策 4 读端口的**跨 feature** 形态：只加可选参数，不新增方法

- `ChapterListProvider.fetch(sourceUrl, tocUrl, {bookName})`、
  `ChapterContentProvider.fetch(sourceUrl, chapterUrl, {bookName, chapterTitle})`：
  两个端口都在 `reader` 域，装配根（`lib/app.dart`）把它们绑到 `book_source` 的两个 use case 上
  （ADR-0041 §决策 2 的形态不变）。
- 两个参数都是**可选且带默认值**，所以既有调用方（书架打开阅读器、详情页的行内阅读）一行都不用改；
  读端口的「绑定缺失」桩（`UnboundChapterListProvider` / `UnboundChapterContentProvider`）也照旧只警告。
- 章节名由阅读器从目录里查（`_chapterTitleOf`）：目录还没加载完时给空串，正文照读 —— 一个纯展示性的
  绑定不值得挡住阅读。

## 影响

- 新增 `domain/entities/chapter_request.dart`、`domain/source_budget.dart`；
- `core/js/{js_bridge,js_bindings,quickjs_worker}.dart`：`JsJob` 两个字段 + 内置键优先；
- `domain/rule_engine/rule_scope.dart`：`JsPageContext` 两个字段；`rule_engine.dart` 三处 `JsJob` 构造；
- `domain/page_fetch_service.dart`：`fetch` / `fetchRule` / `walk` 把两个值建到**页面** scope 上；
- `usecases/{fetch_content,fetch_toc,check_book_source,run_source_debug}.dart`、
  `presentation/notifiers/book_queries.dart`、`presentation/notifiers/reader_session_notifier.dart`、
  `reader/domain/repositories/reading_chapter_source.dart`、`lib/app.dart`（两处适配器）；
- `usecases/{aggregate_search_books,check_book_source}.dart`：改用 `SourceBudget`。

## 证据

- 单测：`source_budget_test.dart` 6 条（剩余量、不为负、原样穿透、已耗尽、真的超时、失败不改种类）；
  `js_bindings_test.dart` 3 条（内置键优先、无上下文时回落、畸形信封）；
  `rule_engine_test.dart` 2 条（名字随页面进 job / 没有名字时为空）；
  `fetch_content_test.dart` 1 条（use case 真的把两个值喂进 job）；
  `reader_session_notifier_test.dart` 1 条（阅读器把书名 / 章节名交给端口）。
- 没有真源证据**需要**：这两项检查的是「规则能不能读到上下文」与「预算怎么算」，与站点无关；
  M12 的真源回归仍以 ADR-0047 §证据 那一组为准。

## 后果

- 好的方面：`java.get('bookName')` / `java.get('title')` 从「登记未做」变成真的能用；
  单源预算第一次有了唯一实现，第三个批量调用方不需要再抄一份。
- 代价：`FetchContent` 的签名变了（`ChapterRequest` 而不是 `String`），`reader` 的两个端口多了两个可选参数；
  两者都在本切片内一次性改完，测试全绿。
- 未闭环：`SourceBudget` 目前只被两个批量调用方使用；**单章正文**仍靠 `HttpPolicy` 的 15 s
  逐请求超时（它没有「一次操作」的边界可挂）。触发条件 = 阅读器出现「同一章多页翻到天荒地老」的反馈。
