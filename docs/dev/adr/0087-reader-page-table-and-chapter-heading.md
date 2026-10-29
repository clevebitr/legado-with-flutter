# ADR-0087 阅读页重构：单一页表、章首章头、重复标题剥离

- **状态：** Accepted（2026-10-29，用户裁决三项：① 单一页表 + 自然高度；② 章标题作为章首章头、两模式一致；③ 排版前剥离正文首行重复标题）
- **日期：** 2026-10-29
- **关联：** ADR-0044 §决策 4（按比例估算偏移）、ADR-0051 §决策 1/4（沉浸式、排版六轴）、
  ADR-0062 §决策 5（朗读高亮）、ADR-0066 §决策 7（偏移落地）、ADR-0085（连续阅读，本 ADR 修订其
  §决策 1/5）、ADR-0086 §决策 7（章头与槽位，本 ADR 修订）、
  `docs/dev/constraints.md` C-PERF-1、C-UI-1/5/8、C-ARCH-1；上游 `F:\Projetcs\legado-with-MD3(READ_ONLY)`

## 背景

ADR-0085 定的目标是「一份跨章阅读流，滚动与分页只是同一份页表的两种摆放方式」，但落地时滚动模式
走的是另一条路：**在 widget 里量章节高度**（`ReaderScrollFlow` 的 `_heights` / `_measureOf`），
并且「上一章要不要出现」取决于量出来的视口高度（`_anchorFillsViewport`）。由此产生两个真机缺陷：

1. **正文重复 / 标题出现两次**：源站正文经常以本章标题开头，而阅读器又自己印了一份章头
   （ADR-0086 §决策 7）。上游在正文入库前就把这行删掉（`ContentProcessor.kt:117-141`
   `//去除重复标题`：`^(\s|\p{P}|书名的)*标题(\s)*` 命中即删），本仓没有这一步，
   于是「第五章 xxx」在屏幕上出现两次。**另外分页模式只在加载页印标题**，真实页一个标题都没有，
   两种模式的章名呈现不一致。
2. **滚动时正文会跳**：结构变化（上一章出现 / 正文到达）要挪滚动偏移，而 `jumpTo` 只能在
   帧后调度（`_pendingJump` → `_applyPendingJump`）——**那一帧已经按错位画出去了**，下一帧才
   纠回来。尤其 `_anchorFillsViewport` 这道闸门：读者跨进新章、新章正文到达后闸门翻真，
   上一章整章插进锚点上方，偏移要一次跳整整一章的高度 —— 就是他看到的「内容跳」。

上游从不在 widget 层量正文。它的渲染模型是一张**页表**
（`feature/reader/core/model/ReaderPage.kt`）：每页有稳定 id `ReaderPageId(chapterIndex, pageIndex)`、
`contentTopPx`/`contentBottomPx`、逐行几何 `ReaderElement.Text.chapterPosition`（字符级），
插入/删除页后按 id 重定位（`ReaderPageNavigator.rebasePageIndex`），滚动与翻页都是页运算
（`ReaderScrollPolicy`），邻章未分页时先放**同 id 占位页**、排完原地替换
（`ensureBoundaryPlaceholderPages`）。标题是章节排版的一部分（`LegacyReaderChapterPaginator` 的
`titleStyle` / `titleSegmentation`），**每章一次，就在章首**。

## 决策

### 决策 1 一份页表，测量全部在 widget 之外

新增 `presentation/widgets/reader_page_table.dart`：由 `readerPageStarts`（同一套 `TextPainter`
量法）+ `readerTextHeight` 在 **build 之前**算出 `ReaderPageTable`：

```
ReaderPageId    = (chapterIndex, pageIndex)   ← 稳定身份，跨重建不变
ReaderPageEntry = { id, url, title, text, start, end, titleExtent, bodyExtent, isFailed }
```

- **页的身份是下标，不是 URL**：抓下来的目录里两章指向同一地址是常见形状，按 URL 归并会把它们压
  成一份正文（ADR-0086 §决策 7 已就此裁决，本 ADR 把它落到页表上）。
- **每页的高度先验已知**：`extent = titleExtent + bodyExtent`，两者都由 `TextPainter` 量出，
  widget 只负责画（`ListView.builder` 的 `itemExtentBuilder` 直接吃这份数）。页表还预先算好
  累计 `tops`，于是「偏移 ↔ (章, 字符偏移)」是一对纯函数：
  `positionAt(offset)` / `offsetOf(chapterIndex, charOffset)`。
- **没有正文的章节占一页**（标题 + 加载块 / 重试），`isPlaceholder`，排完原地换成真实页
  ——照上游 `isPlaceholder` 页的语义。占位页高度也由主题度量得出，不猜。
- **测量结果按章缓存**（`ReaderPageMeasureCache`），键含宽度、高度、正文样式、章头样式、正文长度：
  正文到手、换字号、旋屏才重量，普通滚动一帧都不量（C-PERF-1）。

### 决策 2 零跳：锚点是字符偏移，结构变化当帧重建滚动位置

滚动流不再用后帧 `jumpTo` 补偿，改成一个**不变量**：

> 视口顶那一段字，在页表变化前后必须是同一段字。

实现：状态里记住 `anchor = (chapterIndex, charOffset)`（视口顶由页表反解得出）。页表换了以后按
**页**补偿：找到旧表里视口顶所在的那一页，在新表里按页身份 `(chapterIndex, pageIndex)` 找回来，
保留**页内像素**位置（`newOffset = 新页顶 + (旧 offset - 旧页顶)`）；只有那一页自己的高度也变了
（换字号 / 换视口 / 占位页换真实正文）才退回 `table.offsetOf(anchor)` 按字符去找。只有
`|新 offset - 当前 offset| > 0.5` 时才重设滚动位置，方式是**换一个
`ScrollController(initialScrollOffset: newOffset)` 并给 `Scrollable` 一个新 `key`**（帧内生效，
不再有一帧错位）。差值小于半像素时保持原像素偏移，避免每次重建都抖一下。

配套的两条窗口规则让「当帧重建」在常见路径上**根本不需要触发**：

- **上一章只在它的正文到手时才进窗口**：占位页只出现在锚点章之后。这样锚点上方的高度
  在阅读过程中不会变（一个会长高的占位条正是跳动的来源）。
- **窗口只向前长**：保留 `windowFirst` 水位，锚点前进时只在下方追加新章，不回收上方的章；
  只有显式跳转（目录 / 书签 / 书内搜索 / 进度滑杆 / 换源）才把水位重置到 `anchor-1`，
  以及滚动停下且落后超过 3 章时回收（回收是精确补偿，且此刻没有手势在跑）。

因此：**跨章**不改上方高度 → 不重设偏移 → 手势不被打断（这正是 ADR-0085 §决策 4 想要的效果，
只是不再靠「拖动手势期间冻结窗口」去绕）。

### 决策 3 章标题每章一次，位置在章首（两种模式一致）

章头是**该章第一页的一部分**：`titleExtent` 记章头高度（标题 + 与正文的间距），首页的正文可用高度
等于页面高度减 `titleExtent`（`readerPageStarts` 增加 `firstPageInset`）。于是

- 滚动模式：章标题就印在这一章第一页的顶部，与上游「标题是章节排版的第一个块」同构；
- 分页模式：翻到新章的第一页看到章标题，之后每一页都只有正文；
- 占位页（正文未到）同样带标题，读者能看出「下一章是什么、还在加载」。

这同时修掉 ADR-0086 §决策 7 的一个副作用：标题不再是「流程额外印的一行」，而是排版的一部分，
所以它不会和正文的比例/锚点各算一套。

### 决策 4 正文首行与章节标题重复时，排版前剥离

新增纯函数 `readerStripDuplicateTitle(body, title:, bookName:)`，在 `readerBodyText` 之前调用：

- 取正文**第一段非空行**，删掉标点、空白与书名前缀后与标题（同样去掉空白）比较；
- 相等，或「以标题开头且剩余只有标点/空白」，就整行删掉；
- 只删一行、只删首行，不做模糊匹配：宁可留着，不可吃掉正文。

语义与上游 `ContentProcessor` 的「去除重复标题」一致（上游是正则前缀命中即删），实现上取
「按行比较」这一更保守的形态——上游的正则会把标题后面的半行也留在正文里，这里直接整行去掉更符合
读者预期。**只作用于阅读器的排版变换**，缓存与数据层不动（缓存里仍是源站原文）。

### 决策 5 分页模式消费同一份页表，两种模式共用窗口与定位

`ReaderPagedFlow` 从「自己量页」改成「吃 `ReaderPageTable`」：`PageView` 的页就是页表里的页，
位置按 `ReaderPageId` 重定位（页表变了以后同一页还在读者眼前），占位页原地换成真实页
（正文到手只往后追加页，不跳页）。书末多一页「已是最后一章」，与滚动模式末尾的同一句话对齐。

### 决策 6 末页必须能停在视口顶：尾部留白正好补齐缺的那段滚动范围

滚动模式的末页往往不满一屏，于是「把这一页滚到视口顶」所需的滚动距离超出 `maxScrollExtent`：
落位被截住，视口顶仍在上一章，锚点换算回来就把会话退回去——读者点「下一章」看到的是一次回弹。

所以列表在**末页之后**补一段空白，长度正好是 `视口高 - 末页高`（不小于页边距，也不再多给）：
末页的顶端因此恰好可达，多出来的空白永远只有「让末页能上去」这一件事所必需的那一点。

### 决策 7 跳转以**目标**为准，不以会话为准

会话是异步 Notifier：`selectChapter` 落定与流程重建不一定在同一帧。若流程的 `restore` 从会话读
`chapterIndex`，跳转在会话还没更新时就会被当成「回到原章」，流程随即把旧位置报回会话，把跳转撤销。

因此阅读页记住「还没落地的显式跳转目标」：

- 流程的 `restore` 优先取这个目标，而不是会话的当前章；
- 目标落地前，流程报上来的**别的章**一律丢弃（那一刻它是旧位置）；报上来目标章即视为落地。

同理，锚点章的正文（走 provider 拿到的）会记进正文表：不记的话，读者换到下一章后这一章立刻退回
占位页——上一章整章变矮，正是会跳字的那种结构变化。

### 决策 8 量高用的样式必须**已定型**：`inherit: false` + 明确字号 + 定死排版输入

页表按「量到的高度」给每一项定高，而 `Text` 默认会把传入的样式**并到环境的
`DefaultTextStyle` 上**：样式里没写的字段（行高、行高分布、字距、装饰…）由环境补齐，量的时候
却只有样式本身。两者一有差，画出来就比量出来的高，页表给的高度不够——真机上表现为
`A RenderFlex overflowed by 31 pixels on the bottom` 刷满日志（15 条一模一样的栈，没有任何线索
说明是哪个 widget），debug 包里还会在读者眼前盖一条黄黑斜纹。

所以正文样式与章头样式都**定型**后再交给 `Text`：

- `TextStyle.inherit = false`：`Text` 直接用这个样式，不再并环境；
- 章头一定要带 `fontSize`：主题的 `titleMedium` 可能只给字族不给字号（`m3e_design` 就是如此），
  那样 `TextPainter` 用默认 14 而 `Text` 从环境继承一个，量出来与画出来直接差一行；
- `Text` 显式传 `textWidthBasis: parent` 与 `textHeightBehavior: TextHeightBehavior()`，
  和 `TextPainter` 的默认值对齐（这两项 `Text` 也会从环境补）。

`reader_style_test.dart` 用一份**故意完全不同**的环境样式把这条钉住：量到 576 就必画 576，
差一点都不行。

## 后果

- 新增 `presentation/widgets/reader_page_table.dart`（页表 + 条目 + 测量缓存）；
  `reader_pagination.dart` 增加 `firstPageInset` 参数；`reader_style.dart` 增加
  `readerStripDuplicateTitle` 与章头样式/间距的取值；
- `reader_scroll_flow.dart` 重写：删除 `_heights`/`_measureOf`/`_topsOf`/`_anchorFillsViewport`/
  `_pendingJump`/`_applyPendingJump`/`_reland`/`_pendingReland` 与「拖动期间冻结窗口」的整套闸门；
  `reader_paged_flow.dart` 重写：删除自带的 `_starts`/`_measurePages`/`_pendingReland`；
- `reader_chapter_flow.dart` 删除 `ReaderChapterSlots` / `ReaderFlowChapter`（被页表取代），
  保留 `ReaderFlowRestore` / `ReaderFlowHighlight` / `ReaderChapterPendingStrip`；
- `reader_page.dart`：正文改按**章节下标**存取（不再按 URL），排版缓存键含标题与书名（去重需要），
  页表窗口由 `windowFirst` 水位决定，`_chapterBody` 用 `LayoutBuilder` 把视口尺寸交给页表；
- 偏移仍是**按比例估算**（ADR-0044 §决策 4 不变），但估算的基准从「整章高度」变成「本页切片」，
  精度更高；
- 未变：预取仍是相邻各一章、携带完整章节上下文；`ReaderSettings` 不动；ARB 不动。
- 滚动模式改成懒加载（`ListView.builder` + `itemExtentBuilder`）：视口外的页不再构建，正文请求与
  章节接力由**页表**驱动而不是由「被构建出来的 widget」驱动，所以接力不受影响；
- 崩溃日志多一段 `where=`（首个短信息节点的 creator 链），widget 类错误因此能指名到 widget
  （ADR-0082 的记录形状不变，仍是一条记录一行）；
- 测试侧新增 `test/support/reader_page_table_fixture.dart`（与阅读页同一套量法）与
  `reader_page_table_test.dart`；两个流程的用例改为「给一份页表」，并新增三条不变量：
  量到的高度等于画出来的高度、上一章变高时视口里的那行字不动、末页能停在视口顶。

## 修订

- **2026-10-29**：本 ADR 取代 ADR-0085 §决策 1（窗口=已渲染章的累积）与 §决策 5 的「滚动模式在缺正文
  的邻章位置显示占位条」——占位只剩「锚点章之后」一种出现方式；取代 ADR-0086 §决策 7 的
  「流程印章头 + 按视口高度决定上一章槽位」，章头改为排版的一部分，上一章按「正文是否到手」决定。
- **2026-10-29（落地时补的两条）**：§决策 6（末页尾部留白）与 §决策 7（跳转以目标为准、锚点章正文
  进正文表）都是实现过程中真机形状的推理结论——不是新方向，而是「零跳」这条不变量在末页与异步
  会话两个边界上的必要补丁。
- **2026-10-29（用户报「章界跳变」）**：§决策 2 的补偿方式改了一半——结构变化现在先按**页内像素**
  补，只有「这一页自己变高变矮」（换字号 / 换视口 / 占位页换成真实正文）才退回字符偏移。原因：
  字符偏移往返是**有损**的。视口顶落在章头那几十像素里时 `charOffsetAt` 夹到 0，`offsetOf(0)` 又
  回到正文首行——每跨一次章，章头就被顶出屏幕，真机上就是「滑进下一章被强制回顶部 / 上滑回上一章
  跳到上一章顶部」。像素不往返，就不会丢。上游同一个道理：`ReaderScrollPolicy.apply` 跨界时把
  offset 按**页高差**搬过去（`next - previousExtent`），从不回到 0 重算。
  牙：`update_whenTheTopIsInsideAChapterHeading_doesNotJump`（去掉这一段即差 45 px，正好是一行章头）。
- **2026-10-29（报障未闭环后）**：§决策 2 的补偿不是跨章跳变的唯一来源——页表在跨章那一帧会**整章
  退回一页占位页**（锚点章换人 → `readerContent`（autoDispose）重新 loading → 正文只认 provider），
  补偿只能按字符偏移落到章首；往回读时窗口里没有上一章，还得在视口上方插章、重设位置（惯性随之丢）。
  修法与窗口 lead 见 ADR-0090。§决策 2 的像素补偿仍然成立，只是它现在是**兜底**而不是主路径。
- **2026-10-29（真机日志后补的第三条）**：§决策 8（量高的样式必须已定型）来自用户 Windows 真机日志
  ——15 条 `RenderFlex overflowed by 31 pixels`，全是同一个原因。复现方法：用真实中文字体
  （`simhei.ttf`）在测试里跑同一条链路，环境样式一换就能稳定重现 24/31 px 的溢出。
  同批还补了崩溃日志：widget 错误现在带 `where=<creator 链>`，一条记录一行，长转储跳过
  （ADR-0084 的行格式不变）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 只修 bug、不换模型（保留两套流程，把后帧补偿改成同步） | 度量仍是权威、两套模型仍在；「字在跳」是同一类形状，只是换了个触发点 |
| 一屏一页（`itemExtent = 视口高`），完全照上游的滚动翻页 | 观感变化大：章末最后一页不足一屏时会留半页空白（上游如此），用户在本次裁决里选了自然高度 |
| 用 `ScrollController.jumpTo` + 后帧回调继续补偿 | 正是本次要修的一帧错位；再快也是一个渲染帧的跳动 |
| 页表放进 `domain/` | 页表由 `TextStyle`/`TextPainter` 度量，属展示层排版（C-ARCH-7 禁止 `domain/` 依赖 Flutter） |
| 用 `center` 锚定的 `CustomScrollView` 让上方插入不移动视口 | 换锚点章时仍要换坐标系，等于把同一笔补偿挪到别处；且 `center` + 变长 sliver 的偏移语义比一张显式页表更难推理 |
