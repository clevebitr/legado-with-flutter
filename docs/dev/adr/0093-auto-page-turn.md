# ADR-0093 阅读内自动翻页：一个间隔轴、一个工具栏开关、四条停止条件

- **状态：** Accepted（2026-10-30，M34 规格前置；起因：与上游阅读面逐项对照时登记的缺口）
- **日期：** 2026-10-30
- **关联：** ADR-0044（阅读会话与翻页模式）、ADR-0051 §决策 1（沉浸式工具条）、ADR-0085/0087/0088（连续阅读、页表、
  预取窗口）、ADR-0086（阅读舒适度：常亮/护眼/状态行）；`constraints.md` C-UI-5/7、C-STATE-*、C-NET-9；
  上游 `ui/book/read/sheet/AutoReadContent.kt`、`ReadBookMenuRoute.AutoRead`、`ReadBookIntent.ToggleAutoPage`

## 背景

上游的阅读菜单里有 `AutoRead` 一项：可调速度的自动翻页，用 `ToggleAutoPage` / `StopAutoPage` 控制。
本仓没有，而「手不空的时候继续读」是长篇阅读的真实需求。`reader_settings.dart` 里甚至留着三个从未被引用的
`ReaderAutoReadSeconds` 常量（M34 顺手清掉的那条死代码）——说明当初就规划过、只是没实现。

## 决策

### 决策 1 间隔是一个阅读轴，跟其它轴同一套持久化

`ReaderSettings.autoPageSeconds`（int，**3–60 秒，默认 15**，步进 1 s），在工厂里 clamp
（release 无 assert，与字号/行距/亮度同一条理由），存 `shared_preferences` 的读者私有键。
设置面板里是一行滑块，标题「自动翻页间隔」。**不做**「按页/按时间两种模式」：上游也只有时间。

### 决策 2 驱动：一个 `ReaderPageTurn` 命令对象，flow 自己决定「下一页」在哪

页面持有 `ReaderPageTurn extends ChangeNotifier`，`next()` 只 `notifyListeners()`；两种 flow 各订阅一次：

- **分页**：`PageController.nextPage(duration: 300ms, curve: easeOut)`——走的是同一套 `onPageChanged`，
  进度、页表补偿、跨章全都不用另写一遍；
- **滚动**：`ScrollController.animateTo(offset + viewportDimension, 300ms)`，夹到 `maxScrollExtent`。

选择「命令对象」而不是让页面直接操作控制器：两个 flow 的控制器都是**会被替换**的（ADR-0087 §决策 2 的
帧内重建），从外面抓住它必然抓住一个已废弃的实例。

### 决策 3 停止条件（缺一条就会「关不掉」或「翻到外面去」）

自动翻页在下列任一情况下停止：

1. 再点一次工具栏开关（按钮是 toggle，图标 `play_circle_outline` ↔ `pause_circle_outline`）；
2. 用户点正文任一区（唤出/收起菜单本身就是「我要操作」）；
3. 翻章（上一章 / 下一章 / 目录跳转 / 换源后重定位）——新章从头自动翻会跳过开头；
4. 开始朗读（两者抢同一个「自动前进」语义）；
5. **连续两拍位置没变**：书末、正文还在加载、或站点返回空正文时，翻页命令会变成空操作，不停就会每 15 秒空转；
6. 页面 `dispose`（Timer 必须在 `dispose` 里取消，否则真机上就是「退出阅读器后还在后台翻页」）。

### 决策 4 不写库、不进备份

自动翻页是**会话内**状态：离开阅读器即关；`autoPageSeconds` 是外观偏好，随其它阅读轴走
`shared_preferences`，不进备份（与发现页布局同一口径）。上游同理（`ReadBookConfig.autoPage` 是内存状态）。

## 影响

- `reader_settings`（新轴 + 默认值 + clamp）、`reader_settings_repository_impl`（新键）、
  `reader_settings_notifier`（copyWith 透传）、`reader_settings_sheet`（一行滑块）。
- 新增 `reader_page_turn.dart`；`reader_paged_flow` / `reader_scroll_flow` 各加一个可选 `turn` 参数与监听。
- `reader_page`：`Timer`、开关按钮、四条停止接线；工具栏改成可横向滚动（9 个按钮在窄屏放不下）。
- 测试：settings clamp/往返；两个 flow 的「下一页」各一条；页面级「点开关会翻页」「再点停止」「点正文停止」
  「两拍无进展自停」。

## 后果

- 好处：手不空时能继续读；实现复用现有翻页/进度/跨章路径，不需要第二套页码概念。
- 代价与已知边界：滚动模式下「翻一屏」的落点是一屏高度，章末最后一屏可能不足一屏——这与手动上滑一致，
  不做额外对齐（上游同样按屏幕高度推进）。
- 不做：朗读与自动翻页同时开（决策 3 第 4 条）；离线/后台自动翻页（没有这个语义）。
