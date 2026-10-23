# ADR-0058 选源 / 选范围的界面必须跟随它的输入

- **状态：** Accepted（2026-10-22，用户报障：搜索范围筛选失效、发现页分类不随换源更新）
- **日期：** 2026-10-22
- **关联：** ADR-0046（聚合搜索的范围三态与回落，**§决策 1 的回落判据由本 ADR 修订**）、
  ADR-0052 §决策 3（探索开关）、ADR-0042（跨 feature 端口）、ADR-0055 §决策 2
  （`IndexedStack` 保活）

## 背景

三处「界面显示的选源 / 选范围状态与真实输入不一致」的缺陷，都是**把一次性快照当地持久事实**：

1. **搜索范围 sheet 是快照**（`SearchBooksPage._openScopeSheet`）：`named`（已点名的源 URL）与
   `currentKey`（单选值）在打开 sheet 时算一次，勾选只写 provider、不重画 sheet。后果：
   勾了**看不见**（框还是空的），而且**取消不了**（tile 的值永远是 `false`，点第二次又变成「加上」）。
   另外 `_selectScope` 先 `unawaited` 写入再 `pop`，弹回后立刻点搜索可能仍拿到旧范围。
2. **回落静默**：`SearchResolution.scopeFellBack` 已经算出来，但既没进 `AggregateSearchState`
   也没上屏；同时回落判据是「候选为空」，于是「范围还在、只是里面没有能搜的源」（例如该分组
   的源全被禁用）也会被静默扩成**全库搜索** —— 用户看到的是「我选了分组，结果搜了全部」。
3. **发现页分类随源不变**（`ExplorePage`）：`_requested` 是一个「只请求一次」的布尔标记。
   发现页在 shell 的 `IndexedStack` 里常驻（ADR-0055 §决策 2），用户到书源管理换源再切回来时
   页面**不重建**，标记为真 ⇒ 分类 chip 行永远是上一个源的那一组。

这三条的共同点：**输入（范围 / 当前源）变了，界面没跟着变**，而它们都是用户点名的操作。

## 决策

### 决策 1 范围 sheet 是 `Consumer`，从 provider 派生每一次渲染

- sheet body 用 `Consumer` `ref.watch(searchScopeSelectionProvider)`，单选值、已点名集合、行内勾选
  状态**全部**由当前范围算出；写入口仍然只有 `SearchScopeSelection.select`（ADR-0046 §决策 1）。
- 点名源的勾选**不**关 sheet（允许连着勾几个），靠 provider 变化重画；分组单选**关** sheet。
- `_selectScope` 改为 `await select(...)` 之后再 `Navigator.pop(sheetContext)`：范围是持久化偏好，
  弹回后用户可能立刻点搜索，写入没落地就会拿到旧范围。

### 决策 2 回落只在「范围本身已经不存在」时发生，而且要说出来

- 新增 `_namesSomethingIn(rows, scope)`：只问「这个名字在库里还对得上任何一行吗」，**不看**
  启用 / 类型 / `searchUrl`。候选为空但名字还对得上 ⇒ **不回落**，如实回答「没得搜」
  （页面已有的 `invalidBookSource` 失败态），范围不会被悄悄放大。
- 回落真的发生时，`AggregateSearchState.scopeFellBack` 带上这个事实，搜索页在进度行下方写明
  「所选范围已不存在，本次按全部启用书源搜索」。ADR-0046 §决策 1 的**回落目的**（删分组 /
  删源后不给一个永远空的搜索页）不变，只是把「范围消失了」与「范围内没有能跑的源」分开。
- 这一条**修订** ADR-0046 §决策 1 的 `groups` 回落判据；`sources` 的判据本就等价（点名的源存在
  就不回落），未改。

### 决策 3 发现页记住「为哪个源读过分类」，而不是「读过没有」

- `_requested: bool` → `_loadedSourceId: int?`：只有 `selectedBookSourceProvider` 给出的**源 id 变了**
  才重拉分类；换到「没有源 / 发现已关闭」时清空标记，下次选中真正可用的源时重拉。
- 去掉了「仅当 `exploreProvider` 还是 `ExploreIdle` 才加载」的守卫：换源时状态早就是
  `ExploreCategories`，那个守卫正是漏刷新的直接原因。防重复由 id 比较承担。
- 仍然在 post-frame 回调里发起请求：`exploreProvider` 是 auto-dispose，首帧 `build` 之前读它的
  notifier 会造出没人保活的 element（这条原因没变，见该文件注释）。

## 后果

- 新增 l10n 键 `searchScopeFellBack`（zh / en 同步）。
- 回归点：
  `test/features/book_source/presentation/pages/search_books_page_test.dart`
  （`scope_whenANamedSourceIsTicked_redrawsTheBoxAndCanUntickIt`、
  `start_whenTheStoredScopeNoLongerExists_saysItFellBack`）、
  `test/features/book_source/domain/search_source_resolver_test.dart`
  （`resolve_givenAGroupWhoseSourcesAreAllDisabled_doesNotFallBack`）、
  `test/features/book_source/presentation/pages/explore_page_test.dart`
  （`source_whenTheSelectedSourceChanges_reloadsItsCategories`）。
- `AggregateSearchState.skipped`（哪些源被跳过、为什么）仍只有状态没有界面；它不属于本次报障，
  登记为未做，触发 = 用户要求「这次搜索到底用了哪些源」。
- 搜索范围 sheet 的分组列表仍取 `groupName ?? source.group`（含校验写回的分组 token）。书源**列表页**
  的分组轴只读 payload（ADR-0050 §决策 1），两处的差异保持不变：范围里选「搜索失效」这种 token
  是有意的用法（只搜坏源），本次不改。
