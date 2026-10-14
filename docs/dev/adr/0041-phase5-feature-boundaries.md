# ADR-0041 Phase 5 的 feature 边界、共享数据与页面路由

- **状态：** Accepted（2026-10-14 架构师裁决；开发组起草）
- **日期：** 2026-10-14
- **关联：** C-ARCH-1、C-ARCH-2、C-ARCH-6、C-STATE-2、C-STATE-4、C-ERR-1、C-DEP-6、
  ADR-0003、ADR-0011、ADR-0017、ADR-0021、ADR-0025、ADR-0034、ADR-0039、
  `PLAN.md` §3.6（5.0 / 5.3 / 5.4 / 5.6）、`docs/dev/architecture.md` §1/§2/§3/§6/§7、
  `docs/dev/testing.md` §4

## 背景

`PLAN.md` §3.6 要新建 `reader` / `bookshelf` / `settings` 三个 feature，而 5.1 是 5.2–5.8 的前置。
但**共享数据与跨 feature 调用**在现有规范下没有合法落点：

| 需求 | 谁想调谁 |
|---|---|
| 阅读器取目录与正文（`FetchToc` / `FetchContent`） | `reader` → `book_source` |
| 阅读进度落盘（新表） | `reader` 写、`bookshelf` 读（最近阅读排序） |
| 「加入书架」（详情页与搜索页触发） | `book_source` → `bookshelf` |

C-ARCH-2 与 `architecture.md` §2 只给两条出路：**上移 `core/`** 或**合入同一个 feature**；而
`architecture.md` §1 又写明 `core/` 是「无业务语义的共享能力」，进度与章节显然不是。今天
`ReaderPage` / `ReaderRoute` 就住在 `book_source/presentation/` 里，正是这个矛盾的现状形态——
5.0 不裁决，5.3 / 5.4 只能各自违规或临时发明一套。

## 决策

1. **四个 feature 的边界**（其余留在 `book_source`）：

| feature | 拥有 |
|---|---|
| `book_source`（已有） | 书源列表 / 导入 / 搜索 / 发现 / 书籍详情；书源仓储与规则引擎（4 个 UseCase） |
| `reader`（新） | 阅读器页面与阅读设置（字号 / 行距 / 背景，`shared_preferences`）、章节切换、进度显示 |
| `bookshelf`（新） | 书架列表（在追 / 已读、删除、置顶）、加书 / 删书、最近阅读排序、**阅读进度仓储** |
| `settings`（新） | 设置页（主题模式、默认字号、并发上限、缓存清理入口、关于入口） |

2. **跨 feature 一律走「消费方 `domain/` 的端口 + 装配根绑定」，feature 之间零 import**
   （C-ARCH-2）：
   - `reader/domain` 定义 `ChapterListProvider`（目录 URL → `ParseResult<List<ReadingChapter>>`）、
     `ChapterContentProvider`（章节 URL → `ParseResult<String>`）、
     `ReadingProgressWriter`（源 ID + 书写 URL + 章节 URL + 字符偏移 → 写入）；
   - `book_source/domain` 定义 `BookshelfWriter`（把一本书加入书架）；
   - 端口的**默认实现是「未绑定」的 null object**：返回 `ParseFailure(unsupportedRule)` 并记一条
     warning，**不抛异常**（C-ERR-1）。「忘记绑定」因此是可观测的失败，而不是启动崩溃。
     **每个端口都要有一条「未绑定」路径的测试**（注入默认实现 → 断言失败态与 warning，而不是崩溃）：
     否则「忘了绑」只会在用户那里第一次暴露；这条测试同时把失败文案的 `rulePath` 钉住。
   - 生产绑定在装配根**一次**完成：`lib/app.dart` 导出 `appProviderOverrides`
     （`List<Override>`），`lib/main.dart` 交给 `ProviderScope`。装配根不是 feature，它可以
     同时 import 四个 feature——`architecture.md` §2 的禁令对它不适用。
3. **端口只收发原语与消费方自己的实体**：`reader/domain` 不复用 `book_source.Chapter`，而是定义
   `ReadingChapter`（读者视角：标题 + URL；本阶段**不含** `isVip` / `updateTime`——5.3 需要时再登记）。`book_source.Chapter` → `ReadingChapter` 的映射
   写在**装配根的适配器**里——这是唯一允许在根做跨 feature 映射的地方；
   `architecture.md` §3 的「Mapper 必须放 `data/`」针对的是 feature 内的 DTO ↔ Entity。
   端口签名因此不牵进任何外部实体，`reader` / `bookshelf` 各自的测试用
   `ProviderScope(overrides: …)` 注入假端口即可（`testing.md` §4），互不依赖。
4. **阅读进度归 `bookshelf`**：新表 `reading_progress`，主键 = (书源 ID, 书籍 URL)，列含章节 URL /
   字符偏移 / 更新时间。`reader` 只经 `ReadingProgressWriter` 写，自己不建表、不 import 对方。
5. **页面与路由的归属调整**（表本体归 `docs/dev/architecture.md` §6，本节不复制）：
   `book_source` 保留 `BookDetailRoute` / `ExploreRoute`，5.1 新增书源列表与导入页；
   `ReaderRoute` 与 `ReaderPage` 从 `book_source/presentation/` **迁入** `reader/`；
   `bookshelf` / `settings` 各自新增一个路由类型。四个路由类型只在 `app.dart` 的页面表里登记
   （ADR-0011 的三分职责不变）。
6. **规则面裁决（结论写回 `PLAN.md` §3.7）**：`isVolume` / `formatJs` / `preUpdateJs` 本阶段
   **不做**——它们属规则面而非 UI 面，且没有真实语料证据；先用入库工具普查，触发条件写回 §3.7。
7. **规则变量不落盘**（ADR-0034 §决策 2 的裁决）：随 Provider 作用域，进程结束即失；与上游
   「持久化在 book / source 上」的差异登记在 §3.7。

## 后果

- `reading_progress` 与 ADR-0040 的 `book_sources` **同批迁移**（`schemaVersion` 1 → 2），
  `tech-stack.md` §8 的 dump / generate 与迁移测试一次做完。
- `ReaderPage` 的迁移是**文件移动**：`book_source/presentation/pages/reader_page.dart` 与其
  Widget 测试按镜像路径移动（ADR-0017），`app.dart` 与详情页的 import、`ReaderRoute` 的归属
  随之改。5.3 的验收因此包含「迁移后现有 reader 用例仍全过」。
- 四层依赖关系保持不变：`presentation` → `domain` → `data` → `core`；新增的只有
  `app.dart` 的适配器与 `appProviderOverrides` 这一处「根上的跨 feature 装配」。
- 端口的 null object 默认值意味着**单测与生产走同一条代码路径**，差别只在 override。
- 本 ADR 于 2026-10-14 被接受：`reader` / `bookshelf` / `settings` 的目录与 `ReaderPage` 的迁移
  随 5.3 / 5.4 / 5.6 落地（5.1 不依赖本 ADR）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 允许 feature 之间 import 一个公开入口文件（`<feature>_api.dart`） | 要改 C-ARCH-2 与 `architecture.md` §2 的口径，且公开边界会随需求漂移；端口方案的边界由编译器与 lint 强制 |
| 阅读器留在 `book_source`，只新建 `bookshelf` / `settings` | 与 `PLAN.md` §3.6 5.3 和 `architecture.md` §1 的划分矛盾；且「从书架打开阅读器」会变成 `bookshelf` → `book_source` 的反向依赖 |
| `reader` 与 `bookshelf` 合并成一个 feature | 书架（集合）与阅读器（会话）生命周期不同；合并只是把跨层引用藏进同一目录，C-ARCH-2 的约束力随之消失 |
| 把进度与共享端口上移到 `core/` | `core/` 不得含业务语义（§1）；而且端口签名会牵进书源实体，等于让 `core/` 依赖 feature |
| 让 `book_source` 直接 push 阅读器路由 | `book_source` → `reader` 的反向依赖；详情页应只触发端口，由装配根决定落到谁 |
| 直接读 `book_source` 的 `Chapter` 来避免 `ReadingChapter` | `reader` 会因此 import `book_source` 的实体（违 C-ARCH-2）；在根上做一次映射的代价远小于破例 |
