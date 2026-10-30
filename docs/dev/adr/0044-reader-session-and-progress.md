# ADR-0044 阅读器会话：设置轴、进度端口、`tocUrl` 列与两种翻页模式

- **状态：** Accepted（2026-10-21，M4 / roadmap §5.3 规格前置，用户裁决四项）
- **日期：** 2026-10-21
- **关联：** C-ARCH-2、C-NET-9、C-STATE-5、C-UI-1、C-UI-5、ADR-0011、ADR-0017、ADR-0041、
  `docs/dev/roadmap.md` §5.3、`docs/dev/architecture.md` §1 / §6、`docs/dev/book-source.md` §2

## 背景

ADR-0041 已经把 `reader` 的边界与三条端口（`ChapterListProvider` / `ChapterContentProvider` /
`ReadingProgressWriter`）写好，5.4 也把 `books` + `reading_progress` 两张表建好了。§5.3 要落地阅读器本体，
而四处必须在动工前定死，否则实现会分叉：阅读设置与设置页已有的全局字号是什么关系、进度怎么**读**回来
（ADR-0041 只写了写）、从书架打开阅读器时目录地址从哪来、两种翻页模式怎么共存。

## 决策

### 决策 1 阅读器拥有自己的三个设置轴，与全局 `textScale` 叠乘

- `ReaderSettings` = **字号**（`fontScale`，0.8–2.0）· **行距**（`lineHeight`，1.2–2.4）· **背景**
  （`ReaderBackground { system, paper, sepia, dark }`）+ **翻页模式**（`ReaderPageMode { scroll, paged }`）。
  存 `shared_preferences`，键私有于 `reader/data/`（C-NET-9）。
- 与设置页的字号**不是同一个旋钮，语义分开**：设置页那个是**全应用无障碍缩放**（`app.dart` 的
  `MediaQuery.textScaler`），阅读器这个是**正文字号**。两者叠乘，与 `app.dart` 叠加平台缩放同一条思路。
  理由：用户把系统字号调大是为了看得清菜单，而正文单独一档是阅读偏好；把二者合成一个必然得罪其中一方。
- 背景是**阅读器内**的色板：它按 `ReaderBackground` 取 `ColorScheme` 的表面色**派生**（不硬编码颜色，
  C-UI-1），因此仍然跟随主题与动态取色。

### 决策 2 进度端口是**读写**的 `ReadingProgressStore`

- ADR-0041 §决策 2 只列了 `ReadingProgressWriter`（写入）。恢复阅读位置必须能**读**，否则
  「进度写入 → 恢复」的验收只能靠调用方传参，把进度语义推到路由参数里。
- 因此 `reader/domain` 声明 `ReadingProgressStore`：`read(sourceUrl, bookUrl) → ReadingPosition?` +
  `write(...)`。表的归属不变（`bookshelf`），装配根仍把实现绑到 `bookshelf` 的仓储上。
- 这条是 ADR-0041 §决策 2 的**扩展**，不是推翻：端口仍由消费方声明、装配根绑定、默认实现是
  `unsupportedRule` + warning 的 null object。

### 决策 3 `books` 加 `tocUrl` 列（schemaVersion 4 → 5）

- 书架要能直接打开阅读器，而目录可能不在书籍页（`ruleBookInfo.tocUrl` 指向独立目录页）。没有这一列，
  从书架进入时只能拿 `bookUrl` 猜，独立目录页的源必输。
- 该列在**加入书架时**由详情页的 `BookInfo.tocUrl` 填（那也是目录地址的唯一来源），可空：老行没有它时
  回落到 `bookUrl`（与 `BookInfo.tocUrl` 的回落同义）。
- 迁移只有一列可空值：`addColumn` + dump（`drift_schema_v5.json`）+ 迁移测试 + `on_disk_database_test`
  真实写入一次。注意 `createTable` 用的是**当前**表定义，所以 `addColumn` 只能写在 `from >= 4` 的分支里
  （M10 的 v4 已经踩过这条）。

### 决策 4 两种翻页模式都做，字符偏移是**按比例估算**的

- `ReaderPageMode.scroll`：单个可滚动 `Text`，滚动位置按比例换算成字符偏移。
- `ReaderPageMode.paged`：用 `TextPainter` 按当前字号 / 行距 / 可用宽度把正文切成页，`PageView` 横向翻页；
  每页末尾额外一页是「本章读完 → 下一章」。
- **字符偏移的语义是估算**：`charOffset ≈ 滚动比例（或分页比例）× 正文长度`。真正的字符级锚点需要
  逐字测量并把锚点落进正文模型，属于跨版本的数据格式，本阶段不做 —— 写进 `docs/dev/roadmap.md` §3.7
  并写明触发条件（用户反馈「同一章重进后位置偏很多」）。
- 分页的切分同样按 `TextPainter` 的**右下角文本位置**取断点，落点通常正好是行首；不是行首时整页会少排
  半行，属可接受的近似（记录同上）。
- 明令不做：`isVolume` / `formatJs` / `preUpdateJs`（ADR-0041 §决策 6 不变）、竖排 / 翻页动画曲线、
  「阅读器内直接换源」。

### 决策 5 `canReName` 的消费点是「加入书架」

- `canReName` 的语义（`docs/dev/book-source.md` §2）是「是否允许覆盖已有书名 / 作者」。本仓把它绑定到
  **加入书架**这一动作：`ShelfBookDraft` / `ShelfCandidate` 透传 `canReName`；为 `false` 时
  `refreshDetails` **只更新**封面 / 分类 / 简介 / 最新章节，保留已存的书名与作者；为 `true` 时按上游语义
  一并覆盖。
- 首次入库（行还不存在）总是写入规则读到的书名 —— 没有「已有」可保护。

## 后果

- `reader` 成为第四个有 `data/` 的 feature（设置仓储），它的 `domain/` 进覆盖率门禁（100%）。
- `ReaderPage` / `ReaderRoute` 从 `book_source/presentation/` **迁入** `reader/presentation/`：
  文件移动 + 镜像测试移动（ADR-0017），详情页改为「用 draft 打开阅读器」，`book_source` 不再拥有它。
- 书架行从「不可点」变成「打开阅读器」（5.4 的注释写着这是 5.3 的活）：返回后 `invalidate` 书架，
  让进度立刻出现在「阅读到」那一行。
- `updateTime` 的展示（§3.7 的另一条）在搜索列表 / 详情 / 目录三处落地，空值不显示（不写「未知」）。
- 阅读器设置只对正文生效；设置页的全局字号继续管全应用。两个旋钮各自的 ARB 描述写清差别，避免用户以为
  其中一个失灵。
- 新登记：偏移估算近似（触发 = 用户反馈位置偏移）、分页断点近似（同上）、跨章连续翻页（分页模式在章末给
  显式「下一章」，不是无限翻页）。
  **2026-10-28 注：** 跨章连续翻页这一条已由 **ADR-0085** 结清（滚动与分页都改成跨章接流）；偏移估算与
  分页断点两条登记不变。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 阅读器复用设置页的字号 | 一个旋钮同时管菜单与正文：调大正文必然把全应用一起放大，反之亦然 |
| 只写进度不读进度（恢复靠路由参数） | 恢复语义被推到调用方，书架 / 详情 / 未来的「继续阅读」各写一份换算；且验收的往返测试测不到端口 |
| 用 `bookUrl` 猜目录地址 | 独立目录页的源从书架打开必输，而这类源在真实语料里是主流 |
| 打开时先跑一次详情页取 `tocUrl` | 每次进阅读器多一次请求，且详情页失败就进不去；一次加列把成本换成迁移 |
| 只做滚动模式 | 用户已裁决「两种都做」；滚动模式在小屏上翻章体验差 |
| 逐字测量做精确锚点 | 需要把锚点写进正文/章节模型并版本化，属数据格式决策，收益只在极端场景 |
| 分页模式在章末无限翻到下一章 | 需要预取全部章节正文（网络与内存代价），并与 §9 的翻页上界冲突 |
