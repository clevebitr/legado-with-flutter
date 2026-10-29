# ADR-0090 跨章不换屏：正文在手就按在手算，窗口在锚点上方留 lead

- **状态：** Accepted（2026-10-29，用户报障：滚动模式跨章「跳到下一章顶部 / 闪一下跳到顶部」，在下一章
  上滑回上一章又「跳到上一章顶部而不是末尾」）
- **日期：** 2026-10-29
- **关联：** ADR-0044 §决策 4（按比例估算偏移）、ADR-0085 §决策 2/5（连续阅读、跨章是换会话不是跳转）、
  ADR-0087 §决策 1/2（单一页表、零跳、结构变化当帧重建滚动位置）、ADR-0088（跨章上限与预取窗口）；
  `docs/dev/constraints.md` C-PERF-1、C-STATE-6；上游 `F:\Projetcs\legado-with-MD3(READ_ONLY)`：
  `core/transition/ReaderScrollState.kt`（`ReaderScrollPolicy.apply`）、`ReaderCanvasSurface.kt`（跨章换窗口）

## 背景

用户报障（滚动模式）：

1. 滚到章末切到下一章时**跳到下一章顶部**，并且**闪一下**；
2. 在新一章顶部往上滚回上一章时，**跳到上一章的顶部而不是末尾**。

HEAD `90f101a` 已经把「结构变化按页内像素补偿」修好了（跨章那 43 px 的章头位移）。但真机症状还在，
因为**页表本身在跨章那一帧塌了**。页面级复现（4 章 × 40 行、1200×1200、每步拖 60 → 有效 40 px，
打印每步 offset + 会话 + 页表形状）：

```
DOWN 51 ch 0->1 ... TABLE 0:[1161,962] 1:[P]            ← 第二章整章缩成一页「加载页」
DOWN 52 ch 1->1 ... TABLE 0:[1161,962] 1:[1161,962] 2:[…] ← 正文到了，章高从一行长回一屏
UP  8  ch 1->0 ... TABLE 0:[P]                          ← 第一章也整章缩成一页加载页
UP  8  d=-2126.0                                        ← 一步上滑被扔出两章远（到第一章开头）
```

根因两条：

1. **锚点章换人时，它的正文被当成「还没有」**。页表给锚点章的正文只认
   `readerContentProvider` 这一帧的值；`readerContent` 是 `autoDispose` 的家族 provider，锚点章一换就是
   **另一次请求**，先是 `loading`（`currentData == null`）。于是哪怕这一章的正文早就躺在
   `_prefetchedBodies` 里（预取队列 ±15 章，读者读到章末时它肯定在），那一帧也会整章退回**一页占位页**
   ——章高从一屏缩成 `spacing.xxl + lg` 一行。页表上方/当前页的高度骤变，`_sync` 只能退回
   「字符偏移往返」落位；而占位页的 `charOffsetAt` / `distanceOf` 都是 0，于是落点就是**章首**。
   同时 `anchorReady == false` 还把页表右边界收回锚点章本身，屏幕上的正文换成加载条 = **闪一下**。
2. **往回读时窗口里没有上一章，只能当场上移表头**。`_applyWindow` 只维持「锚点上方 1 章」，而
   `_trimWindow` 停手后把水位提到 `anchor - 1`；读者往上滑过这个边界时，页面必须在视口**上方插入一整章**，
   于是 `_sync` 走「按页内像素补偿」——位置是准的，但方式是**换一个 `ScrollController` + 换 key**
   （ADR-0087 §决策 2，为了帧内生效），惯性活动连同手势一起被丢掉：真机上就是「上滑回上一章被
   停住 / 抖一下」。页面级复现：8 章、读到第 6 章再上滑，日志里出现
   `offset 2072.8 → 4090.2 (LAND)`，位移差 2017 px = 一整章。

上游不会出现这两条：章节正文挂在章对象上（`TextChapter.content` / `isLoad`），**换章不丢已经读回来的
正文**，也不会因为「当前章变了」退回「还没排」；跨章是页表运算（`ReaderScrollPolicy.apply` 用
`next - previousExtent` / `next + currentExtent` 把 offset 搬过界），滚动量存在自己的状态里，没有
「插入内容后要重建滚动位置」这一步。

## 决策

### 决策 1 正文在手就按在手算，不看它是哪条路进来的

页表给锚点章的正文改成「**provider 这一帧的值，没有就用预取缓存**」：

```dart
final String? currentData =
    fetched != null && fetched.isNotEmpty ? fetched : _prefetchedBodies[chapter.url];
final bool anchorReady = currentData != null;   // 正文在手，不是「provider 应答过」
```

- `anchorReady` 只看**正文是否在手**：正文在预取缓存里就已经是「读好了」，ADR-0088 §决策 1 的
  「最多跨进一章未加载的章」因此按真实状态判断，不因为一次多余的重取而把右边界收回去。
- 「失败」标记也只在**没有正文**时打：重取失败但缓存里有同一份文档，屏幕上就不是失败态
  （`_prefetchFailed` 与 `_prefetchedBodies` 互斥，锚点章那条也一样）。
- 仍然保留「锚点章 watch `readerContentProvider`」这条通道：它负责**首次**取正文、重试
  （`invalidate`）与「进章时再取一次」（源站更新章节后，重进这一章能拿到新正文）。多出的这一次请求
  由 5.2 缓存吸收，换来的是「正文到手就永不退回占位页」。
- 结果：跨章那一帧页表**什么都不变**（章高、页数、上方 tops 全同），只是下方按窗口追加一章；
  `_sync` 走「按页身份补偿」那条路且位移差为 0，不换控制器、不打断惯性。注意真正的修复点不是补偿
  算法，而是**让页表不塌**——补偿只是兜底。

### 决策 2 窗口在锚点上方留 lead，往回读不靠「当场插章」

`_windowLead = 3`：页表始终在锚点**上方**保留 3 章，并且只由**前进**维持：

- 锚点前进时（`anchorIndex > _windowAnchor`）把水位降到 `anchor - 3`（只降不升，仍是「窗口只向前长」）；
- 锚点后退时**不动水位**——读者要回去的那一章本来就在表里；
- 只有退到窗口**上沿**（`anchorIndex <= _windowFirst`）才不得不往上补一章，这一次一定重设滚动位置。

这样一次上滑（1–2 屏、通常跨 1–2 章）完全不用改表结构，惯性照跑；`_trimWindow` 也改成停在
`anchor - 3`，回收的章不会是读者下一步就要回看的章（代价是渲染窗口宽了 2 章：排版文本与测量各多
`TextPainter` 几趟，C-PERF-1 的余量足够）。

### 决策 3 没能一并解决：跨 overscan 的回翻仍会重设一次位置

往回滑超过 lead（3 章）时，页表必须在视口上方插章，而 `ListView` 没有「插内容不改 pixels」的原生
手段，只能换控制器重建位置——位置精确（读者眼前那行字不动），但那一次手势到此为止。彻底解决要换成
`center` 键的 `CustomScrollView`（或自绘 sliver 上报 `scrollOffsetCorrection`），是一次滚动模型级
重构，不在本次范围内，登记为已知边界。

## 后果

- `reader_page.dart`：`_chapterBody` 的正文来源与 `anchorReady` / 失败标记（决策 1）；新增
  `_windowLead`、`_windowAnchor`、`_resetWindow()`，`_applyWindow` / `_trimWindow` 按 lead 改写（决策 2）。
- `reader_scroll_flow.dart` **未改**：它本来就能在「只有下方追加」时零动作（ADR-0087 §决策 2）。
- 新增测试（`reader_page_test.dart`，先证明有牙：逐条在修复前失败）：
  - `scroll_whenTheBoundaryIsCrossed_keepsTheNewChapterInHand`：跨章后新章每一页都是真正文（不是占位页）、
    屏幕上没有加载条、窗口往下接了一章；再上滑回上一章同样不掉正文，且不是被扔回章首。
    修复前：`isPlaceholder` 命中，`d = -2126`。
  - `scroll_acrossAChapterBoundary_doesNotStopTheFling`：惯性里跨章，位移逐帧单调不减、跨章之后仍在前进。
    修复前：跨章那一帧 `2179 → 2147`（往回跳）并当场停住。
  - `scroll_backAcrossChapters_keepsTheFlingRunning`：从第 13 章一次上滑跨过至少两章，位移单调不增。
    lead 改成 1 时失败（第 43 帧 `+2047`，即插章后重设位置）。
  - `scroll_acrossAChapterBoundary_movesSmoothly`（改写自 90f101a 的用例）：原来在循环外抓一次
    `ScrollPosition`，而重设位置会**换掉**这个对象，断言其实是在读一个已经脱离的对象；现在每步读活的
    位置，上行/下行的容差也从「±120」收紧到「一步的距离绝不会超过拖动量」。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 把 `readerContent` 改成 `keepAlive`（跨章不丢正文） | 家族 provider 每个 `(book, url)` 都常驻，一本读过的书会把所有章正文永久留在内存里；而且它解决不了「窗口里没有上一章」那半边 |
| 锚点章也走预取队列、不再 watch provider | 换章就不再重取，源站更新过的章节在重启前永远拿不到新正文；重试按钮也要另造一条路径 |
| 跨 overscan 时用 `position.correctBy` / 自绘 sliver 上报 `scrollOffsetCorrection` | 前者在惯性活动里会被下一帧按旧轨迹覆盖，除非重建活动；后者要在 `ListView` 外面包一层自绘 sliver，属于滚动模型级重构 |
| 干脆不回收窗口（`_trimWindow` 去掉） | 读几百章会把几百章的排版文本与测量都留着；ADR-0088 §决策 3 已裁决分两层保留 |
| 用 `center` 键的 `CustomScrollView` 重写滚动流 | 方向正确（插内容不移动 pixels），但 `itemExtentBuilder`、尾部留白、`tops` ↔ 像素的换算与显式跳转都要重做，收益只在「跨 3 章以上的回翻」，风险远大于收益 |
