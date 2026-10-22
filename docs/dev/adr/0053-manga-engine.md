# ADR-0053 漫画引擎：图片书源的解析链路与漫画阅读器

- **状态：** Accepted（2026-10-22，用户裁决里程碑 M16；参考 `F:\Projetcs\legado-upstream` 的
  `ui/book/manga/*`）
- **日期：** 2026-10-22
- **关联：** C-SRC-4、C-PERF-3、C-UI-1、C-UI-7、ADR-0041、ADR-0044、ADR-0052、
  `docs/dev/roadmap.md` §3.10（M16）

## 背景

`BookSourceType.image`（`bookSourceType = 2`）从 M11 起就只能被搜索的类型筛选**排除**：引擎按文本
消费 `ruleContent`，UI 没有图片阅读页。上游把漫画当成阅读器的一个模式（`MangaReaderScreen.kt`），
数据链路的四个阶段（搜索 / 详情 / 目录 / 正文）与文本完全相同，差别只在**正文的产物**是图片地址列表。

## 决策

### 决策 1 漫画是 `reader` feature 的一个模式，不新造 feature

- `ReaderRoute` / `ReaderPage` 不变；`ReaderPage` 按当前书源的 `sourceType` 分派到
  `MangaReaderPage`。这样三条端口（目录 / 正文 / 进度）与上一章 / 下一章 / 进度落盘全部复用
  （ADR-0044 §决策 2），不需要第二套跨 feature 端口。
- `book_source` 不 import `reader`（C-ARCH-2）：打开漫画仍走 `AppNavigation.openReader`，
  与文本阅读同一条路（ADR-0042 §决策 2）。

### 决策 2 图片地址来自 `ruleContent` 的**列表语义**，不在 UI 里猜

- 新增 `domain/entities/manga_page.dart`（页码 + 图片地址 + 可选 headers）与
  `domain/usecases/fetch_manga_pages.dart`。
- 规则求值复用 `RuleEngine` 的列表形态（`book-source.md` §3）：一项 = 一页；空列表按
  `ParseFailureKind.parseFailed` 整章失败，**不**静默显示空白页（C-SRC-4）。
- 单元内出现相对地址时按**章节页 URL** 解析为绝对地址（与封面同一条规则，`book-source.md` §2）；
  仍是相对地址（无 base）→ 该页失败并在日志点名页号。

> **落地修订（2026-10-22，真源取证）：** 真源里 `ruleContent.content` 经常产出的是 **HTML 片段**
> （整块 `<div>…<img …>` 或逐个 `<img …>`，如 `zymk` / `wxzhm`），而不是图片地址。只接受「一项 =
> 一个 URL」会把整章判成失败。`FetchMangaPages` 现在对每个值做归一化：本身就是 URL 直接用；
> 含标记时取其中 `<img>` 的 `data-original` / `data-src` / `src`（懒加载属性优先）；都不行才记一条
> 截断到 80 字符的 warning（C-SEC-4：日志不得写入页面正文）。
- `headers` 与文本正文共用 `PageFetchService` 的首个请求求值结果，不二次实现。

### 决策 3 阅读器是「竖滚动 + 左右翻页」两种模式，缩放用内置 `InteractiveViewer`

- 竖滚动：`ListView.builder` 懒加载（C-PERF-2），每页 `CachedNetworkImage`（C-PERF-3）。
- 左右翻页：`PageView`，方向按源/用户的漫画方向设置决定（LTR / RTL）。
- 缩放用 `InteractiveViewer`（Flutter 内置，**不新增依赖**），但**只在放大后挂上**：常驻的
  `InteractiveViewer` 会抢走横向拖动（`ScaleGestureRecognizer` 即使在 `panEnabled: false` 时也赢手势竞技场），
  翻页会失效。因此 1 倍时是一张普通图片 + 双击放大，放大后才是可平移的 `InteractiveViewer`，
  再次双击复位（这一条是落地时被 Widget 测试逼出来的修正）。
- 图片加载失败：页内占位 + 「重试」按钮，不整章崩；失败页不写进度锚点。
- 进度：沿用 `reading_progress`（章节 + 页号），页号是**页码**而不是字符比例（文本用的比例估算
  不适用于图片）；跨章继续阅读按页号恢复。

### 决策 4 预加载与内存边界

- 预取当前页前后各 1 页（共 ≤3 页）；预取失败不重试、不弹错（滚动到该页时自然重试）。
- 解码尺寸按屏幕宽度上限（`CachedNetworkImage.maxWidthDiskCache` / `memCacheWidth`），
  禁止一次性把整章图片读进内存（C-BAN-14）。
- 章节切换先清空上一章的页缓存引用再加载新章，避免长阅读器持有全部历史图片。

### 决策 5 依赖与门禁

- **不新增依赖**：`cached_network_image` 已在 `pubspec.yaml`，缩放/翻页用 Flutter 内置组件。
- 离线语料：派生一个图片书源 + 本地 `asset` 假图（测试用 `FakeImageProvider`，Widget 测试不联网）。
- 验收：① `FetchMangaPages` 单测（列表 / 相对地址 / 空列表 / 失败页）；② `MangaReaderPage`
  Widget 测试（滚动、翻页、缩放、失败重试、进度写入）；③ 双端 `integration_test` 用假图跑一次；
  ④ 真源抽查一次：一条真实图片书源从搜索到读到第一页（不通过则记「已实现未验证」）。

## 后果

- 好的方面：图片源从「能被筛掉」变成「能读到」；阅读会话、进度、章节切换全部复用，没有第二套。
- 代价：`ReaderPage` 多一层分派；图片阅读没有文本的字体/排版设置，设置面板按模式裁剪。
- 未闭环：条漫的连续拼接（`MangaPageSpread`）、双页对开、色彩滤镜（上游 `MangaColorFilterConfig`）、
  离线批量下载 —— 均无真实需求，登记在 `docs/dev/roadmap.md` §3.7，未实现前不得声称支持。
