# ADR-0091 换源内核：渐进候选搜索、选源范围与无名命中

- **状态：** Accepted（2026-10-29，M29 规格前置；起因是用户报障，范围与 UI 形态由 `DECISIONS.md` #74 / #75 裁决）
- **日期：** 2026-10-29
- **关联：** ADR-0046（聚合搜索：并发 / 单源预算 / 进度 / 暂停 / 取消）、ADR-0051 §决策 3（换源语义与身份迁移）、
  ADR-0041 §决策 4（`(sourceUrl, bookUrl)` 身份）、ADR-0085 §决策 4（换源等于换一份目录）；
  `constraints.md` C-ARCH-2、C-ERR-8、C-NET-9、C-STATE-6、C-UI-5/C-UI-7（M30 的 UI 面）；
  `docs/dev/book-source.md` §7（失败语义）；上游 `F:\Projetcs\legado-with-MD3(READ_ONLY)`：
  `domain/usecase/ChangeSourceSearchUseCase.kt`（渐进事件）、`ui/book/changesource/ChangeChapterSourceViewModel.kt`
  （范围 + 四开关 + 章节两步）、`ui/widget/components/changeSource/ChangeSourceSheet.kt`（进度与筛选）

## 背景

换源（ADR-0051 §决策 3）今天是 `ChangeBookSourceSheet` / `ReaderSourceSheet` 里的一次性 `Future`：

1. `SwitchBookSource.candidates` 用**当前书名**在「启用 + 文本源」里搜一遍，全部跑完才返回；
2. `bookName.trim().isEmpty` 时**直接返回空列表**；
3. 每个源的命中靠 `_bestMatch` 挑：名称完全相等 → 名称互相包含（`wanted.contains(title)`）；
4. 没有范围、没有进度、没有章节选择，切换与迁移在点击后一次性完成，中途只有一层不可取消的转圈。

用户报障（2026-10-29）四条都落在这段代码上：

- **「其他书源没有这本书」**：`book_list_fields.dart` 的 `readBooks` 把书名读成
  `name.dataOrNull ?? ''`——书名规则失败或没命中就是空串，**没有任何日志**；于是书架/详情里的书没有标题，
  换源的关键词就是空串，走到上面第 2 条就永远「没有这本书」。另外空名命中的合并键是 `('','')`，
  不同源的无名书会互相塌成一行（M31 要修的那条链的起点）。
- **像死锁**：扫一遍 30~100 个源要几十秒，屏幕上只有一个转圈，看不出跑到哪、也没法停。
- **不能选章节**：对齐只能靠「同名 → 包含 → 同索引」，对不上时用户没有任何补救手段。
- **不能选范围**：用户往往知道只有某几个分组里的源是好的，但没有地方说。

上游的形态是：渐进事件流（`Started` / `Progress` / `Result` / `Finished`）+ 范围（`SearchScope`）+
四个开关（`checkAuthor` / `loadInfo` / `loadToc` / `loadWordCount`）+ 点源之后才进章节列表
（`ChangeChapterSourceSheet` 的 `showToc`）。本 ADR 把**内核**（搜索与匹配语义）定下来；界面形态归 M30。

## 决策

### 决策 1 换源是一个「渐进候选搜索」，不是一次性 Future

新增用例 `book_source/domain/usecases/change_source_search.dart` 的 `ChangeSourceSearch`：

```dart
final class ChangeSourceRequest {
  final String keyword;      // 书名，可为空（退化到作者）
  final String? author;      // 已知作者（书架行 / 详情页），可为空
  final List<BookSource> sources;   // 已由范围 + 类型过滤解析好
  final bool checkAuthor;    // 校验作者
  final bool loadInfo;       // 加载详情
  final bool loadToc;        // 加载目录（得到章数）
  final int concurrency;     // 取 settings.maxConcurrentPerSource
}
```

- `execute(request, {onProgress, pause, cancellation})` 每处理完一个源就调用一次 `onProgress`，
  快照字段：`candidates`（已得候选）、`processedSources`、`totalSources`、`failedSources`、
  `currentSourceName`。**快照而不是增量事件**：界面只需要「现在是什么样」，而事件流要求前端自己累积
  状态，和 `AggregateSearchState` 的写法不一致。
- `pause` / `cancellation` 复用 `SearchPause` / `TaskCancellation`，语义与 ADR-0046 §决策 6 **逐字相同**：
  协作式、只在两个源之间生效、停止保留已找到的候选、停止不算失败。
- 并发与预算是同一套：`settings.maxConcurrentPerSource` 个 worker，每源一份 `SourceBudget(60s)`；
  一个源超时/抛异常只加 `failedSources`，不把整批变成失败（ADR-0046 §决策 5）。
- 返回 `ParseResult<List<ChangeSourceCandidate>>`：全部源失败才 `ParseFailure`；「一个都没有」是成功空表
  ——换源没找到不是错误。

### 决策 1b 形态：阅读页与详情页都是**同一个弹层**（2026-10-30 修订）

- 形态是 **modal bottom sheet**，不是单独一页：`book_source/presentation/widgets/change_source_sheet.dart`
  的 `showChangeSourceSheet(context, target:)`（`isScrollControlled` + 0.92 屏高），两步在**同一个 sheet 里**
  切换（点源后标题变成源名并出现返回箭头），与上游 `ChangeSourceSheet` / `ChangeChapterSourceSheet` 一致。
  修订原因：用户 2026-10-30 明确要求「阅读页里弹出 box 换源，而不是单独一页，功能不变」——阅读时离开正文
  去一个全屏页再回来，比就地弹层打断得多。
- 状态在 `ChangeSourceController`（`@riverpod` 家族，按 `ChangeSourceTarget` 记录做 key，关掉即销毁）。
  **销毁时必须停手**：`ref.onDispose` 里取消在跑的那批，且每个 `await` 之后判 `ref.mounted`
  （真机日志 `app-2026-10-30` 里两次 `UnmountedRefException` + ERROR CRASH 就是漏了这一条）。
- 答案是 `ChangeSourceSelection`（候选 + 已读到的目录 + 选中章）：`Navigator.pop<T>` 返回，
  调用方据此落库（详情页直接写；阅读器经装配根写书架身份再就地重定位）。
- 因此**没有路由登记**：`ChangeSourcePage` 已删除，`architecture.md` §6 的那条例外一并撤回。
- 阅读器不 import `book_source`：新增 `AppNavigation.openChangeSource(context, ChangeSourceLaunch)`
  → `ChangeSourceOutcome?`（`core/router/change_source_contract.dart`，原语），由装配根负责
  身份迁移 + 选中书源，再把结果交回阅读器就地重定位（C-ARCH-2、ADR-0042 §决策 2）。
- 因此 **旧的一次性换源消失**：`ChangeBookSourceSheet`、`ReaderSourceSheet`、
  `BookSourceSwitcher` 端口及其测试一并删除；`SwitchBookSource` 只保留纯映射
  （`withChapters` / `alignChapterIndex`），不再持有任何 I/O 依赖。

### 决策 2 匹配规则：书名优先、作者兜底、无名命中只在作者对上时接受

每个源只产出**一条**候选（换源问的是「这本书在另一个源里是哪一本」，不是结果页）：

| 关键词 | 命中条件（按优先级） |
|---|---|
| 非空 | ① 名称折叠后**完全相等** ② 名称**互相包含** ③ 名称取不到（空）但**作者相等/包含**且请求带作者 |
| 为空 | 仅按作者：作者相等 → 包含；名称不参与 |

- 折叠 = `trim()` + `toLowerCase()`（`mergeKeyOf`，ADR-0046 §决策 3 的同一口径），不发明拼音/空格规则。
- `checkAuthor` 打开时，候选的**作者必须包含**请求作者；候选作者**为空**视为「未知」而**保留**
  （丢掉未知作者会丢掉真实候选，「校验作者」防的是**已知不同**的书）。
- 候选携带 `matchKind`（`exact` / `partial` / `authorOnly`），排序 = 档位 → 源名，最多 20 条（ADR-0051 §决策 3 的上限）。
- **无名命中不再被当成万能匹配**：今天 `wanted.contains(title)` 在 `title == ''` 时恒真，任何空名命中都会
  冒充「这本书」；改为决策 2 的第 ③ 行——只有作者真的对上才接受。

### 决策 3 关键词与作者都要能被界面改，内核不因空关键词短路

`ChangeSourceRequest.keyword` 允许为空，此时按 `author` 搜（作者也空才返回空表 + 一条 warning）。
这条是用户报障的直接修法：书没有标题时仍然能换源，而 M30 的界面会把关键词做成**可编辑输入框**
（默认填书名，为空时填作者），让用户自己补。

### 决策 4 可选加载：详情与目录；字数**登记为未做**

- `loadInfo`：对每个候选调 `FetchBookInfo`，补 `coverUrl` / `lastChapter` / `author` 与 `tocUrl`；
- `loadToc`：调 `FetchToc` 得到 `chapterCount`（选源时最有用的信息：章数差太多通常就是别的版本/别的书）；
- 两个都默认**关**（`DECISIONS.md` #74）。关着的时候候选只有搜索页给的字段，一个候选只花 1 次请求；
- 单项失败只把该字段留空（候选仍保留），并记一条节流 warning：一个源详情页坏了不该让候选消失。
- **登记差异（有意不做）**：上游的 `loadWordCount` 会再抓一章正文算字数。它多一次正文请求、并且要在
  「对齐到哪一章」之前就知道章节索引；对「换不换」的增益远小于章数，收益/代价不成立。触发条件：用户明确
  要求「候选列表里显示字数」时再评估。

### 决策 5 范围：复用解析器，偏好独立存储

- 候选源由 `resolveSearchSources(rows, scope, types: {text})` 解析，再**排除当前源**；范围的三态
  （全部 / 分组 / 点名）与搜索页共用同一份实现（ADR-0046 §决策 1、ADR-0058 的回退语义一并继承）。
- 换源的范围是**独立偏好**（对齐上游 `ChangeSourceSettings.searchScope`），键与搜索页不同：
  `SearchScopeStoreImpl` 增加可注入的 key，`bookSource.changeSourceScope` 与 `bookSource.searchScope` 各存一份。
  理由：搜索页想要「全库撒网」，换源往往只想要「那几个我信得过的分组」，混用会让两边互相打断。
- 本 ADR 不改 `SearchScopeStore` 的接口形状（仍是 `load` / `save`），只让实现接受 key；两个 provider 在
  `book_source/di.dart` 里给出。

### 决策 6 候选快照要保留「每个源各自的那一本」（M31 的前置）

`SearchBook` 今天只留**第一个源**的 `url` / `author` / `lastChapter` / `coverUrl`，`origins` 只是 URL 列表——
搜索结果里「4 个来源」点开只能进第一个源（`DECISIONS.md` #76）。

因此 `SearchBook` 增 `hits: List<OriginHit>`（每源一条快照：`sourceUrl` / `url` / `author` / `lastChapter` /
`kind` / `coverUrl` / `updateTime`），由 `SearchResultMerger.add` 在合并时追加。合并键与桶排序**不变**；
`searchBookKeyOf` 在 `name` 为空时回落到 `url`（空名命中不再互相塌陷）。换源候选的字段集合与之对齐，
M31 的选源 sheet 只需要读这条快照，**不重新发请求**。

### 决策 7 无名命中的根因要可见，而不是继续静默

`readBooks` 对书名：

- 规则失败或结果为空 → `warnThrottled('no-name|<sourceId>|<noun>', '… rulePath=<fieldPrefix>.name')`；
- 命中**仍然保留**（URL 有效就留），因为「没标题」比「整页消失」对用户更可用（还能点开、还能换源）；
- 不因为书名失败而让整页 `parseFailed`：那是 §7 的「列表规则没命中」语义，与单字段无关（ADR-0026 的同一取向）。

## 影响

- 新增 `book_source/domain/usecases/change_source_search.dart`（用例 + 请求/候选/进度类型）；
  `SwitchBookSource.candidates` 改为它的薄封装（构造请求 → 取候选），旧 UI 立刻拿到修复，不留两份匹配逻辑。
- `book_source/domain/book_list_fields.dart`：书名缺失时按源 + 规则路径节流告警。
- `book_source/domain/entities/search_book.dart` + `search_result_merger.dart`：`SearchBookKey` 增 URL 兜底位、
  `SearchBook.hits`、`OriginHit`。
- M30 已落地：`ChangeSourceSheet`（两步弹层）、范围 chip（`bookSource.changeSourceScope` 独立 store）、
  三个开关、`AppNavigation.openChangeSource` 端口、`sourceScopeSheet` 抽成共享组件（搜索页与换源页同一份）、
  旧 `ChangeBookSourceSheet` / `ReaderSourceSheet` / `BookSourceSwitcher` 退役。
- M31 承接：搜索结果选源 sheet 只读 `SearchBook.hits`。

## 后果

- 好的方面：换源从「等一分钟看一个转圈」变成「有进度、能停、能选范围、能改关键词、能选章节」；
  无名书不再被判死刑；匹配语义有档位可解释，也能被单测钉住。
- 代价：每个候选默认只花一次搜索请求，但**开了 `loadToc` 就是 N 次目录请求**；界面必须把开关写清楚
  （M30 的选项菜单），并且进度条要跟着 `processedSources` 走。
- 仍然分页无关：换源只取搜索第一页（上游也是 `searchBookAwait` 单页）。触发条件：候选里经常出现
  「这本书在第 2 页」时再做翻页。
- `SearchBook.hits` 让合并行变大（每源一份快照）；上限仍是 `maxRetainedSearchBooks`，单测覆盖淘汰路径。
