# UI 缺口对照：上游 `legado-upstream` 与本仓

> 本文是**上游 UI 结构与本仓缺口的唯一清单**，用于排里程碑（`docs/dev/roadmap.md` §3.11）。
> 它不是规范：UI 约束仍归 `constraints.md` §6，页面归属归 `architecture.md` §6，里程碑状态归 `PLAN.md`。
>
> 对照基线：`F:\Projetcs\legado-upstream`（Compose，`app/src/main/java/io/legado/app/ui/`）。
> 本仓基线：分支 `feat/source-mgmt-manga-audio`（M15/M16 落地后）。

---

## 1. 上游 UI 结构

| 区域 | 上游落点 | 提供的能力 |
|---|---|---|
| **主壳** | `ui/main/MainScreen.kt`、`MainBookPageNavigation.kt` | 底部导航最多 5 个可配置 tab：首页 / 书架 / 发现 / RSS / 我的；横向 pager 滑动切 tab；tab 图标、顶/底栏均可配置 |
| **首页** | `ui/main/home/HomeScreen.kt` | 阅读统计（累计本数 / 时长）、最近阅读、今日阅读目标、WebDAV 备份状态卡、首页模块管理 |
| **书架** | `ui/main/bookshelf/BookshelfScreen.kt`、`BookshelfConfigSheet.kt`、`GroupManageSheet.kt`、`ui/book/manage/BookshelfManageScreen.kt` | 分组 chip、书架配置（封面模式/排序/显示字段）、分组管理（新建/改名/删除/排序）、管理页（多选批量：分组/删除/置顶/缓存） |
| **书籍详情** | `ui/book/info/BookInfoScreen.kt`、`BookInfoSheets.kt`、`BookInfoReadRecordSheet.kt`、`ShelfDeleteSheet.kt`、`ui/book/changesource/*`、`ui/book/changecover/*`、`ui/book/group/GroupEditSheet.kt` | 详情 + 目录预览 + 简介折叠 + 阅读记录 sheet + 换源（对齐章节）+ 换封面（相册/规则）+ 改分组 + 缓存本书 |
| **阅读** | `ui/book/read/*`（`ReadBookScreen.kt`、菜单/目录/搜索/进度/亮度）、`ui/book/searchContent/*`、`ui/book/bookmark/*`、`ui/book/readRecord/*`、`ui/book/readaloud/*` | 沉浸式菜单、目录面板（正倒序/搜索/居中）、**书内全文搜索**、书签、阅读记录（按书/按天）、朗读控制条与定时 |
| **漫画** | `ui/book/manga/*` | 条漫/翻页、双页对开、缩放、方向、色彩滤镜、预取、章节过渡 |
| **我的** | `ui/main/my/MyScreen.kt` | 入口聚合：书源管理、替换净化、目录规则、字典规则、高亮标签、多角色规则、AI 聊天、设置、书签、阅读记录、缓存管理、文件管理、关于、退出；Web 服务开关 |
| **规则管理** | `ui/replace/*`、`ui/dict/*`、`ui/highlightTagRule/*`、`ui/tagGroupRule/*`、`ui/book/toc/*`（目录规则） | 替换净化规则、字典规则、高亮标签与分组、多角色规则、目录规则（`txt_toc_rule`）的增删改与排序 |
| **设置** | `ui/config/ConfigNavScreen.kt` 及其子页 | 主题（背景图/导航栏/图标/配色）、阅读设置、封面配置（相册/规则）、下载缓存、备份恢复（本地/WebDAV）、AI、翻译、隐私、实验室 |
| **导入/登录/系统** | `ui/book/import/local/*`、`ui/login/*`、`ui/qrcode/*`、`ui/file/*`、`ui/about/*`、`ui/welcome/*` | 本地书籍导入（txt/epub）、书源登录（WebView）、二维码导入/分享、文件管理、关于页、首次启动引导 |
| **RSS** | `ui/rss/*` | RSS 源管理、订阅、文章列表、收藏、阅读 |

---

## 2. 本仓现状（页面清单）

`lib/features/*/presentation/pages/` 现有 19 个页面（M19 后）：

| feature | 页面 | 已有能力 |
|---|---|---|
| `book_source` | `search_books_page` | 聚合搜索（范围/类型/匹配/暂停/继续/加载更多）——**当前是落地页** |
| | `explore_page`、`book_detail_page` | 发现分类与列表；详情（封面/简介折叠/开始阅读/加入书架） |
| | `book_source_*`（list/import/check/debug/edit） | 书源管理（M15：状态灯/批量/分组/预览导入） |
| `bookshelf` | `bookshelf_page`、`shelf_groups_page` | 在追/已读、置顶、删除、最近阅读排序；M19 加分组 chip / 多选批量 / 分组管理页 |
| `reader` | `reader_page`、`manga_reader_page`、`bookmark_list_page`、`reading_records_page`、`book_reading_records_page` | 文本沉浸式阅读（M14）、漫画阅读（M16）、书签（M19）、阅读记录按天 / 按书（M19） |
| `shell` | `my_page`、`about_page`、`legal_notices_page` | 我的入口聚合、关于、法律声明（M18） |
| `settings` | `settings_page` | 主题模式 / 字号 / 并发上限 / 清空缓存 |

**已有**（M18/M19 后补上）：应用外壳与底部导航、「我的」页、关于/法律声明页、书架分组与管理页、书签、阅读记录、详情改分组/换封面/本书缓存。

**没有**：书内搜索、主题配置、规则管理、备份恢复、本地导入、二维码、登录、缓存按源清理、RSS、AI/翻译。

---

## 3. 缺口清单（按优先级）

### P0 — 不补就「不像一个阅读 App」

| # | 缺口 | 上游落点 | 本仓现状 | 为什么关键 |
|---|---|---|---|---|
| U1 | **应用外壳**：底部导航（书架 / 发现 / 搜索 / 我的）+ 保留各 tab 状态 | `ui/main/MainScreen.kt`、`AppNavigationBar` | 落地页是搜索页，四个 feature 只能互相 push，返回键行为混乱 | 用户每次都要「从搜索页往回退」才能到书架；没有稳定的家 |
| U2 | **「我的」聚合页**：书源管理、缓存、关于、法律声明等入口 | `ui/main/my/MyScreen.kt` | 设置页只有 4 项；书源管理入口藏在搜索页工具栏 | 设置与工具没有归属，功能「找得到」是可用性的前提 |
| U3 | **关于 + 法律声明页**（C-UI-9） | `ui/about/*` | 未做（roadmap 5.9） | GPL 门禁项；也是版本/许可/源码入口 |
| U4 | **书架分组与管理**：分组 chip、分组管理、多选批量（分组/删除/置顶/缓存）、排序与封面模式 | `ui/main/bookshelf/*`、`ui/book/manage/*` | ✅ M19：分组 chip + 分组管理页（增删改拖拽排序）+ 长按多选（改分组/置顶/标记已读/删除）；排序与封面模式配置**按用户裁决不做** | 书架超过 10 本后不可用；分组是上游最常用的组织方式 |
| U5 | **书籍详情增强**：目录预览、阅读记录、换源、换封面、改分组、本书缓存 | `ui/book/info/*`、`changesource/*`、`changecover/*` | ✅ 目录预览与换源（M14）；M19 加阅读记录入口 / 改分组 / 换封面（本地图片）/ 本书缓存统计与清理 | 「换源」是坏源的唯一补救路径；目录预览直接影响是否开始读 |
| U6 | **书内全文搜索** | `ui/book/searchContent/*` | 无 | 找一句话在长篇里是刚性需求 |
| U7 | **书签与阅读记录** | `ui/book/bookmark/*`、`readRecord/*` | ✅ M19 批 A：阅读器书签 toggle（位置唯一键）、「我的 → 书签 / 阅读记录（按天）」、详情页「阅读记录」入口 | 阅读器的「回看/标记」能力缺失，阅读记录也让「最近读」有依据 |
| U8 | **缓存管理（按书 / 按源）** | `ui/book/cache/*`、`config/downloadCache*` | M19 已做**按书**（详情页：本书缓存 N 章 + 清理，`cache_entries.scope_key`）；按源与全量设在设置页（5.7①），按源统计仍归 M21 | 空间是手机上的硬约束；5.7② 已登记未做 |

### P1 — 让「可配置」追上上游

| # | 缺口 | 上游落点 | 本仓现状 |
|---|---|---|---|
| U9 | **主题配置页**：背景图、导航栏（顶/底/tab 图标）、启动图标、配色管理 | `ui/config/themeConfig/*`、`ui/theme/*` | 只有 `themeMode` 三段 |
| U10 | **阅读设置扩展**：字体族/段距/缩进/页边距/翻页键位/亮度与进度条行为 | `ui/config/readConfig/*`、`ui/book/read/*` | M14 已做四轴，键位与背景图未做 |
| U11 | **规则管理 UI**：替换净化、目录规则、字典规则、高亮标签/分组、多角色规则 | `ui/replace/*`、`ui/dict/*`、`ui/highlightTagRule/*`、`ui/tagGroupRule/*` | 全部没有；只有书源编辑里的 JSON 文本域 |
| U12 | **备份与恢复**：本地文件导出/导入、WebDAV 备份、书架/进度/书源全量 | `ui/config/backupConfig/*`、`home` 的备份卡 | 无（书源单条导出 ≠ 备份） |
| U13 | **本地书籍导入**（txt/epub）+ 文件管理 | `ui/book/import/local/*`、`ui/file/*` | 无（只有网络书源） |
| U14 | **二维码导入/分享** | `ui/qrcode/*` | 无 |
| U15 | **书源登录 / Cookie 管理** | `ui/login/*` | 无（`header` 规则可用，但没有交互式登录） |

### P2 — 体量大、可独立立项（不建议与上面混在一批）

| # | 缺口 | 上游落点 | 判断 |
|---|---|---|---|
| U16 | 首页阅读统计/今日目标/WebDAV 状态卡 | `ui/main/home/HomeScreen.kt` | 依赖 U12 与阅读记录表，排在 U7/U12 之后 |
| U17 | RSS（源/订阅/文章/收藏） | `ui/rss/*` | 与「书源阅读」平行的第二条产品线，需单独 ADR |
| U18 | AI 聊天 / 翻译 | `ui/ai/*`、`ui/config/translation*` | 引入外部 API 与密钥管理（C-SEC-1），当前不在范围内 |
| U19 | 朗读/听书 UI | `ui/book/readaloud/*` | **已由 M17 覆盖**（另一代理在做），本文不重复 |

---

## 4. 里程碑切分（提案）

> 每个里程碑开工前必须先有规格 ADR（`AGENTS.md` §3 第 1 步）；下面的「新增数据」都要走 dump + 迁移测试。

| 里程碑 | 范围 | 新增数据 / 决策点 | 出口 |
|---|---|---|---|
| **M18 — 应用外壳与「我的」** | U1、U2、U3：底部导航（书架/发现/搜索/我的）+ 状态保持；我的页入口；关于与法律声明页 | 新 `shell` feature 还是 `app.dart` 内壳？→ **ADR**；路由与返回栈规则；C-UI-9 六键 | 四 tab 可切换且状态不丢；「关于 → 法律声明」可达；Widget 测试 + 双端实跑 |
| **M19 — 书架与书籍详情** | U4、U5、U7：书架分组与管理页（多选批量）、详情目录预览/阅读记录/改分组；书签与阅读记录 | `books.group` 等列（v6→v7）；`bookmarks`、`read_records` 表 → **ADR** | 分组/批量/书签/阅读记录各有迁移 + 单测 + Widget 测试；书架 100 本滚动无卡顿 |
| **M20 — 阅读内搜索与规则管理** ✅ | U6、U11：书内全文搜索；替换净化 / 目录规则 / 字典规则 / 高亮标签的最小 CRUD | 规则存储位置（Drift 表 vs JSON 文件）→ **ADR-0070**；搜索的分章并发与取消 → 同上 §决策 2 / 增补 §10 | 全文搜索可停止且命中可跳转 ✅；四类规则「列表 + 编辑 + 启停」可跑 ✅（净化还接进了正文链路） |
| **M21 — 数据与系统 UI** | U8、U9、U10、U12、U13、U14、U15：按书/按源缓存、主题配置、阅读设置扩展、备份恢复、本地导入、二维码、登录 | 备份格式与 WebDAV（网络/密钥）；本地导入的解析依赖许可（epub）；相机/WebView 平台依赖 → 各自 ADR | 备份导出→清库→恢复往返；本地 txt 可读；主题配置三端生效 |

**顺序理由：** M18 先把「家」立起来（后面的页面都挂到它下面）；M19 依赖 M18 的导航与「我的」入口；M20/M21 相互独立，可按用户反馈换序。U16（首页统计）排到 M19/M21 之后。

**共用门禁（四批一致）：** 每项 ① 单测 / Widget 测试；② 双端 `integration_test` 实跑；③ `AGENTS.md` §4 全部门禁；④ 新增文案双语 ARB；⑤ 新决策写 ADR；⑥ 新表/新列 dump + 迁移测试。

---

## 5. 明确不做的（本轮）

- **U17 RSS / U18 AI 翻译**：不是「缺失的 UI 细节」，而是新产品线；需要独立 ADR 与依赖许可评估。
- **上游的「首页模块管理 / 导航栏图标包 / 启动图标」**：属于主题深度定制，等 M21 的主题配置落地后再评估。
- **上游的多角色规则、投屏、云 TTS、Web 服务**：无本仓需求证据，登记在 `docs/dev/roadmap.md` §3.7 的触发条件里，不提前实现。
