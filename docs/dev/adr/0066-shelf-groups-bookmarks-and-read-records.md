# ADR-0066 书架分组、书签与阅读记录（M19）

- **状态：** Accepted（2026-10-23，用户裁决四项：分两批交付 / 独立 `book_groups` 表 /
  阅读记录按会话一行 / 换封面与本书缓存纳入 M19）
- **日期：** 2026-10-23
- **关联：** C-NET-9、C-ARCH-2、C-ARCH-6、C-ERR-2、C-PERF-2、C-PERF-6、C-UI-5、C-UI-7、
  ADR-0011（typed route）、ADR-0041 §决策 4（进度表归 `bookshelf`）、ADR-0042（跨 feature 端口）、
  ADR-0044 §决策 4（偏移估算与恢复）、ADR-0055（外壳与「我的」）、ADR-0056（迁移可重入）、
  `docs/dev/ui-gap.md` §3 U4/U5/U7/U8、`docs/dev/roadmap.md` §3.11

## 背景

M18 之后四个 tab 与「我的」已经就位，但书架只有「在追/已读」两态 + 单行菜单
（`bookshelf_page.dart`），超过十本无法组织；阅读器没有书签，也没有任何「读过什么、读了多久」的
记录；书籍详情只有简介、目录和三个按钮，用户无法从详情调整这本书在书架上的归属。

`docs/dev/ui-gap.md` 把这件事切成 M19（U4 书架分组与管理、U5 详情增强、U7 书签与阅读记录），
并把「新表 / 新列 → ADR」列为开工前置。本 ADR 就是那份规格：

- 新增 `book_groups` 表与 `books.groupId`（分组）；
- 新增 `bookmarks`、`read_records` 两张表（书签 / 阅读记录）；
- 新增 `books.customCoverPath`（自定义封面，存**绝对路径**：文件在应用目录里，只有本机读它；
  相对路径会让书架每一行都要做一次异步基准目录查询，违反 C-PERF-1）与 `cache_entries.scopeKey`（按书缓存聚合），
  两者都服务本里程碑的详情增强；
- schema v6 → v7，dump + 迁移测试（ADR-0056 的可重入规则）。

## 决策

### 决策 1 M19 分两批，数据层一次到位

| 批 | 范围 | 出口 |
|---|---|---|
| **A（先）** | schema v7（五处结构改动）+ 书签（写入 / 列表 / 跳转）+ 阅读记录（写入 / 按书 / 按天）+ 详情页「阅读记录」入口 | 书签能加能删能跳回原句；一次阅读在「阅读记录」里出现一行 |
| **B（后）** | 书架分组 chip + 分组管理页 + 多选批量（改分组 / 删除 / 置顶 / 标记已读）+ 详情改分组 / 换封面 / 本书缓存统计与清理 | 分组可建可改可删可排序；批量动作只作用于选中行 |

分批的理由：批 A 只碰「读」的链路（阅读器 + 两个新页面），批 B 只碰「管」的链路（书架 + 详情），
两批的回归面几乎不重叠，各自过一次双端门禁比一次大爆炸 PR 便宜。结构改动仍然**一次**升到 v7，
理由见决策 6。

### 决策 2 分组是独立表 + `books.groupId`，删除分组不删书

- `book_groups(id, name, sortOrder, createdAt)`，`books.groupId` **可空**：`null` = 未分组。
  「全部」是筛选视图而不是一个组，所以不占一行。
- `name` 唯一（`trim` 后非空）：分组名是用户识别一组书的唯一标识，两个同名分组会让 chip 无法区分。
  重命名撞名 → 写路径返回失败（`ParseResult.failure`），UI 提示，不静默合并。
- `sortOrder` 由分组管理页的拖拽写**归一化**值（0..n-1），与书源 `customOrder` 的同一条策略
  （ADR-0045 §决策 3）。
- **不加外键**：`ALTER TABLE … ADD COLUMN` 带 `REFERENCES … ON DELETE SET NULL` 在旧库上虽然合法，
  但 drift 的 `addColumn` 与 schema dump 比对会让 v6 库里「旧列是否带约束」成为新的迁移雷点
  （ADR-0056 的教训就是这个方向）。删除分组改为 DAO 里一个事务：先把该组的 `group_id` 置 `null`，
  再删组行。
- 组内书的顺序 = 现有书架顺序（置顶 → 最近阅读 → 更新时间 → id），不在本里程碑引入「组内手动排序」。

### 决策 3 书签归 `reader`，一张表 + 位置唯一键

```text
bookmarks(id, source_url, book_url, book_name, toc_url,
          chapter_url, chapter_name, chapter_index,
          char_offset, excerpt, created_at)
UNIQUE (source_url, book_url, chapter_url, char_offset)
```

- **归 `reader` feature**：书签是阅读产物，写入点在阅读器；详情页与「我的」只通过端口 / 路由
  进入，`bookshelf`、`book_source`、`shell` 都不 import `reader`（C-ARCH-2）。
- 行内冗余 `book_name` / `toc_url` / `chapter_name`：全局书签列表要能离线渲染（书源可能已被删），
  而且跳回书签必须重建同一份目录（源把目录放在独立页面时，用书籍页地址会抓错页）；
  一次 join 换来的是「书架没了书签还在」的可读性；这与 `books` 快照列同一条理由
  （`shelved_book.dart` 的类注释）。
- `chapter_index` 是**便利值**：源重排章节后索引会失效，跳转先按 `chapter_url` 定位，
  找不到才回落到索引并夹到边界（与 `ReaderSession.build` 的恢复策略一致）。
- **位置唯一键**让「同一位置再按一次 = 取消收藏」可判定：阅读器工具栏的书签按钮因此是一个
  toggle，而不是会堆出重复行的「添加」。
- `excerpt` 是加书签时截取的正文片段（最多 80 字，纯展示）。它来自**已缓存 / 已渲染**的正文，
  不额外发请求。

### 决策 4 阅读记录每次会话一行，短会话不记

```text
read_records(id, source_url, book_url, book_name,
             chapter_url, chapter_name,
             started_at, ended_at, duration_seconds)
INDEX (book_url) / INDEX (ended_at)
```

- 粒度 = **一次打开阅读器**。章内切章不拆行：一次会话里跳了五章仍然是「我读了 20 分钟这本书」，
  拆成五行只会让记录页变成噪声，而每章的停留时长精确到「偏移估算」的粒度也没有意义
  （ADR-0044 §决策 4 的偏移本来就是估算）。
- `duration_seconds < 60` 的会话**不落库**：误触打开、换源失败重开都不该在记录里留痕。
  阈值是 `domain` 里的具名常量（`minimumRecordedSeconds`），不进 ARB（它不是文案）。
- 时长用注入的 `Clock` 计算（`docs/dev/testing.md` §4），不读 `DateTime.now()`；
  会话在 `ReaderPage.dispose` 收尾，录制逻辑放在 `domain` 的 `ReadingSessionRecorder`
  （纯函数 + 两个时间点），页面只负责「开始 / 结束」。
- 「按书」「按天」都是**查询视图**，不建两张表：按天 = 按 `endedAt` 的本地日期分组。

### 决策 5 详情增强的写路径：改分组 / 换封面走 `BookshelfWriter`，阅读记录只给入口

- 改分组与换封面改的是 `books` 行，归属 `bookshelf`；详情页（`book_source`）通过**已有的**
  `BookshelfWriter` 端口扩展方法访问，装配根绑定，`bookshelf` 不 import `book_source`。
- 阅读记录归 `reader`，页面也在 `reader`：详情页的「阅读记录」只是一个**入口**，走
  `AppNavigation.openBookReadingRecords(context, sourceUrl, bookUrl, bookName)`（只收原语）。
  不给 `book_source` 加一个新的读端口：那会把同一份列表在两个 feature 各实现一次。
- 本书缓存统计与清理走 `ContentCache` 端口扩展（`scopeKey`），在详情页给出「本书缓存 N 项 / 清理」。
- **不做**：换源（M14 已完成，详情页不复制第二入口）、书架排序与封面模式配置（用户裁决不做）。

### 决策 6 schema v7 一次迁移，可重入

| 改动 | 形态 | 旧行语义 |
|---|---|---|
| `book_groups` | 新表 | — |
| `books.group_id` | 新列，可空 | `null` = 未分组 |
| `books.custom_cover_path` | 新列，可空 | `null` = 用源的 `coverUrl` |
| `bookmarks` | 新表 + 唯一索引 | — |
| `read_records` | 新表 + 两个索引 | — |
| `cache_entries.scope_key` | 新列，可空 | `null` = 不知道属于哪本书（旧条目），只能被全量清理 |

- 迁移步骤沿用 ADR-0056：新表先 `createTable`，索引先查 `sqlite_master`，新列走
  `_addColumnIfMissing`；**重复执行是空操作**。
- v1 / v2 上来的库走的是 `createTable(books)`，那已经是当前形状，所以「加列」步骤只对
  「书架表已存在」的路径执行（v4/v5 的同一坑）。
- `drift_dev schema dump` 产出 `drift_schemas/drift_schema_v7.json`，迁移测试覆盖
  v1..v6 → v7 与 `schemaAt(7)` 的逐列比对。

### 决策 7 路由与「我的」入口

`reader_route.dart` 从单一 `final class ReaderRoute` 改为 **sealed union**：

| 变体 | 路径 | 页面 |
|---|---|---|
| `ReaderRoute.read(book, chapterUrl?, charOffset?)` | `/reader` | `ReaderPage` |
| `ReaderRoute.bookmarks()` | `/reader/bookmarks` | `BookmarkListPage` |
| `ReaderRoute.records()` | `/reader/records` | `ReadingRecordsPage` |
| `ReaderRoute.bookRecords(sourceUrl, bookUrl, bookName)` | `/reader/records/book` | `BookReadingRecordsPage` |

- `charOffset` 是书签跳转需要的：只给 `chapterUrl` 会落在章首，「跳到书签」必须落在原句。
  它**只**出现在 reader 自己的路由上，`AppNavigation.openReader` 保持原语 + 无偏移
  （跨 feature 的打开语义仍是「这一章 / 上次位置」）。
- 「我的」新增两行（书签 / 阅读记录），走 `AppNavigation` 的两个新方法；
  详情页的「阅读记录」走 `openBookReadingRecords(context, sourceUrl, bookUrl, bookName)`。
- 装配根的页面表用 `readerPageFor(route)`（与 `shellPageFor` 同形）。

### 决策 8 缓存按书聚合用 `scope_key`，不存明文 URL

`cache_entries.cache_key` 是摘要（「不泄露用户请求过什么」），因此**无法**按书统计。
v7 新增可空 `scope_key` = `digest(sourceUrl + bookUrl)`，写入侧由 `FetchContent` 传入
（它本来就有 `bookUrl`），读取侧不参与键计算（键仍是 `cache_key`）。
统计与清理 = 按 `scope_key` 计数 / 删除。旧条目没有 `scope_key`，只会被全量清理带走。

## 影响

- `lib/core/storage/`：`book_groups.dart`、`bookmarks.dart`、`read_records.dart`（新增表定义），
  `books.dart`（两列）、`cache_entries.dart`（一列）、`database.dart`（v7 + 迁移）、
  三个新 DAO（`shelf_group_dao`、`bookmark_dao`、`read_record_dao`）、`bookshelf_dao` 与
  `cache_dao` 的新方法。
- `features/bookshelf/`：`ShelfGroup` 实体、`ShelvedBook.groupId`、仓储与 Notifier 的分组方法、
  书架页 chip / 多选 / 分组管理页（批 B）。
- `features/reader/`：`Bookmark` / `ReadingRecord` 实体、两个仓储、`ReadingSessionRecorder`、
  阅读器工具栏书签与三个页面（批 A）。
- `features/book_source/`：详情页的改分组 / 换封面 / 阅读记录入口 / 本书缓存（批 B + 批 A 的入口）；
  `ContentCache` 端口加可选 `bookUrl`。
- `lib/core/router/app_navigation.dart` + `lib/app.dart`：三个新端口方法与页面表。
- ARB 双语新增书签 / 记录 / 分组 / 批量文案；`docs/dev/architecture.md` §6 路由表、
  `docs/dev/ui-gap.md` §2/§3 的现状列同步。
- 测试：迁移（v1..v6 → v7）、三个 DAO、两个仓储、`ReadingSessionRecorder`、三个新页面
  Widget 测试、书架分组/批量 Widget 测试、阅读器书签 toggle。

## 后果

- 好的方面：书架从「一条平铺列表」变成可组织；阅读器具备「标记 / 回看」；「我的」有了两个真正的
  内容入口；按书缓存为 M21 的缓存管理铺好底座。
- 代价：v7 是一次跨两批的迁移，批 A 合入时 `books.groupId` / `customCoverPath` 与
  `cache_entries.scopeKey` 暂时**没有 UI 使用者** —— 这是分批的直接成本，登记为 M19 批 B 的范围；
  阅读记录的阈值（60 s）与会话粒度都是产品判断，可在有真实使用数据后调整（只改常量与投影，
  不动表）。
- 未做：组内手动排序、书签分组 / 标签、阅读统计图表（U16，依赖本表的日聚合）、
  换源第二入口、书架排序与封面模式配置。
