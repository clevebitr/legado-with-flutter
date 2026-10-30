# ADR-0092 书架编辑书籍详情：用户态四字段与 `custom_intro` 列

- **状态：** Accepted（2026-10-29，M33 规格前置；字段范围由 `DECISIONS.md` #78 裁决）
- **日期：** 2026-10-29
- **关联：** ADR-0019（覆盖率门禁）、ADR-0051 §决策 3（身份迁移）、ADR-0066 §决策 5（自定义封面）、
  ADR-0073 §决策 1/3（备份格式与合并语义）、`constraints.md` C-NET-9、C-UI-5；
  上游 `ui/book/info/edit/BookInfoEditViewModel.kt`（`book.name/author/remark/customIntro/customCoverUrl`）

## 背景

书源解析出错是常态：标题规则没命中、作者写成站点名、目录页把简介抓成广告。今天是「删掉重加」——
而重加会丢掉阅读进度、分组与置顶，等于罚用户替书源擦屁股。

上游的 `BookInfoEditViewModel` 把可改字段分成两类：**快照列**（书名、作者，直接覆盖）与**用户列**
（`customIntro` / `customCoverUrl`，各自一列，显示时优先）。本仓已有 `customCoverPath`（M19），
缺的就是简介这一列与「编辑」这一页。

## 决策

### 决策 1 第一版只放四个字段：书名 / 作者 / 封面 / 简介

- 书名、作者**直接覆盖快照列**：上游也是这么做的（`book.name = …`），且这两个字段是「书源抓错了、
  用户最想改」的那两个。
- 封面沿用 M19 的 `customCoverPath`（换封面 / 清除），走自己的写路径 `setCustomCover`——它还附带删文件。
- 简介**新增一列** `custom_intro`：`intro` 是书源快照，下一次「加入书架」会刷新它，用户写的东西必须活着。
  显示规则是「custom 优先、空则回落快照」，`null` 表示「回到书源简介」，不是空串。
- 其余字段（分类/标签、备注、阅读类型、固定类型、每本阅读设置）**登记为未做**：它们要么要先有列
  （remark / customTag），要么要动阅读设置的分书存储，收益与代价不成比例。触发条件：用户点名要其中某一项。

### 决策 2 数据形态：一列 + 一次写

- `books.custom_intro`（nullable text），schemaVersion **13 → 14**，迁移走 `_addColumnIfMissing`
  （可重入，ADR-0056），`drift_schemas/drift_schema_v14.json` + 迁移测试同时落地。
- 写入是**一个方法** `updateDetails(id, name, author, customIntro)`：三个字段来自同一张表单里的同一次
  保存，分开写会产生两个 `updatedAt` 并让书架顺序跳一下（与 `updateUserState` 的理由相同）。
- 备份：`books` 表多一个 `customIntro` 键；**旧备份没有这个键时按 null（保留本地）**，与其它用户列同一
  合并语义（ADR-0073 §决策 3）——恢复不能把用户改好的简介抹掉。

### 决策 3 入口与归属：编辑页在 `bookshelf`，详情页经端口进入

- 页面是 `bookshelf/presentation/pages/shelf_book_edit_page.dart`，路由 `BookshelfRoute.editBook(book:)`
  ——**整行**随路由走（页面要用当前值填表），`bookshelf_paths` 里与 `/shelf`、`/shelf/groups` 并列。
- 书架入口：行菜单「编辑书籍」。
- 详情页入口：`ShelfMembership` 增 `id`，详情页多一个「编辑」按钮，经新端口
  `AppNavigation.openShelfBookEdit(context, bookId)` 进入（C-ARCH-2：`book_source` 不 import `bookshelf`）。
  不在书架上的书按钮禁用——没有行可改，且这四个字段的「用户副本」归书架所有。
- 详情页展示简介时改为 `membership.customIntro ?? info.intro`：用户改过的简介在详情页立刻生效。

## 影响

- `core/storage/books.dart` + `database.dart`（v14）、`bookshelf_dao`（`updateDetails` / `insertNew` /
  `restoreUserState` 增 `customIntro`）、`ShelvedBook`、`BookshelfRepository.updateDetails`、
  备份导出/恢复、`ShelfMembership`、`AppNavigation`、书架行菜单、详情页简介与「编辑」按钮、新编辑页。
- 生成物：`drift_schemas/drift_schema_v14.json`、`generated_migrations/schema_v14.dart`、
  `schema.dart`（v14 注册）；迁移测试补 v13→v14 并把「最新版」断言改成 14。

## 后果

- 好的方面：书源抓错书名/作者/简介不再需要删书重加，阅读进度、分组、置顶与封面全部保留；
  简介是「用户列」，重新加入书架与恢复备份都不会覆盖它。
- 代价：多一列 + 一次迁移 + 备份格式多一个键；`data` 层覆盖率因新实现行略降（仍远高于 80% 门槛）。
- 已知边界：编辑页只改这四个字段，**不改**身份（`sourceUrl`/`bookUrl`）——换身份是换源（ADR-0091）的活；
  两件事混在一页会让「我改个名字」变成一次可能失败的网络流程。
