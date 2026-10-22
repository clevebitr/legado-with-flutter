# DECISIONS

> 决策与踩坑日志，只追加，不参与日常上下文。可用 grep 检索。条目按文件顺序编号（第一个 `##` 是 #1）。

## 2026-10-21 — PLAN.md 交给 plan 插件，人读路线迁到 docs/dev/roadmap.md

根 `PLAN.md` 交给 `plan` 插件（`pi-is-my-plan`）管理，人读的路线 / 验收 / Gate / 返工陷阱 / 快速索引整体搬到 `docs/dev/roadmap.md`（原名 PLAN.md，小节号未变）。

为什么这样分：插件只认自己的格式（`<!-- plan-bridge:state -->` + `## Milestones` + `## Current`），并且**拒绝覆盖外来 PLAN.md**；而 roadmap 里的 5.x 验收、G1–G7、17 条陷阱被 ~90 处引用（docs / ADR / tool / lib / test）。把两者塞进一个文件只能二选一丢东西，所以拆开：PLAN.md 只放里程碑级状态（进 system prompt 的那一小块），roadmap.md 承担「实现顺序 + 验收 + 门禁」。

踩坑（迁移时实测）：`git mv PLAN.md docs/dev/roadmap.md` 之后，工作区里的目标文件被写成插件自己的 16 行骨架，283 行正文只剩 git index 里的旧版。**下次迁移先 `cp` 一份到 `build/` 再删原文件**，不要依赖 mv 的落盘结果。

约定：
- 里程碑 = roadmap 的 5.x 步骤（M1–M9 ↔ 5.0–5.9），文本 ≤50 字符，详情留在 roadmap 与 ADR。
- ADR 与 CHANGELOG 里对 `PLAN.md §X` 的历史引用**不改**（决策记录不可变），由 roadmap 头部声明「等同本文件 §X」。
- `DECISIONS.md`（插件追加的 #N 短日志）定位是执行期踩坑，**不是** ADR 的替代：正式决策仍走 `docs/dev/adr/`。

## 2026-10-21 — 5.4 书架与 5.6 设置的落地取舍（身份、钳制、keepAlive）

5.4 书架与 5.6 设置落地（M5 / M7）。新增 `books` + `reading_progress`（schemaVersion 2 → 3，dump + 迁移测试 + on_disk 真实写入）、`BookshelfDao` / `BookshelfRepository` / 书架页 / 「加入书架」端口；新增 `AppSettings`（钳制在工厂里）+ `SettingsRepository`（shared_preferences）+ 设置页 + 主题/字号/并发上限接线 + 全量清空缓存。

三个判断值得记住：

1. **书架的身份是 `(sourceUrl, bookUrl)`，书源存 URL 而不是 `book_sources.id`**：`id` 属于一次导入的行，删掉再导入同一个源会换 id，而「这本书来自哪个源」不随行变。ADR-0041 §决策 4 写的是「书源 ID」，本实现按 URL 落地，同一 ADR 里阅读进度也照此办理。
2. **并发上限的校验放在 `core/di/http_client_provider.dart` 的 `budgetOrDefault`**，不是靠 `HttpPolicy` 的 `assert`（release 会剥掉）。设置侧另有一层钳制（1–8）在 `AppSettings` 的工厂里；两层都不依赖 assert，所以「`0` 让请求永久排队」这条登记项在 release 也关得住。
3. **`httpClientProvider` 改 `keepAlive`**：预算挂在 `DioHttpClient` 实例上，autoDispose 会让「批量下载共用一份预算」变成每批一份。代价是 Dio 实例随 App 存活（它本来就没有需要释放的资源）。

另有两处前端结构决定写进 ADR-0042：跨 feature 导航走 `AppNavigation` presentation 端口（由装配根绑定），`StateMessage` / `FailureMessage` 上移 `core/widgets/`。

`checkKeyWord` 的归属从 5.5 改到 5.10：它是校验/调试的输入，随机制一起建模才有判据可写。

## 2026-10-21 — M10 书源测试机制：上游两个机制与四处待裁决

上游 `legado-upstream` 的「书源测试」其实是两个机制，M10（roadmap §5.10）按两半写：

- **批量校验**：`BookSourceCheckRepository` + `BookSourceCheckGateway` + `BookSourceCheckService`。对选中的一批源按阶段（搜索 / 发现 / 详情 / 目录 / 正文，逐个可关）跑链路，失败写进 `bookSourceGroup` 的「搜索失效」「目录失效」… 分组、`bookSourceComment` 的错误注释，并记录 `respondTime`；状态机 `Pending/Running/Succeeded/Failed/Cancelled` + `CheckFailed/SourceMissing/SaveFailed/Incomplete`；并发 = 下载线程数，单源超时默认 180 s；Android 上是前台服务 + wake lock。
- **单源调试**：`ui/book/source/debug/*`。选一个源 + 目标（Search/Explore/Info/Toc/Content）+ 查询词跑一次，实时事件流（消息 / 来源 / 错误三类过滤、带耗时），示例入口一键填充。

四处必须先在 M10 的规格前置里定死，否则实现会分叉：① 校验结果落在哪（`groupName` 列 / 新表 / 只留内存报告）；② `checkKeyWord` 建模与「像规则就跳过」的判据；③ 长任务的平台抽象（前台服务 / wake lock 在 `platform.md` §2 的接口之外）；④ 逐源结果仍走 `ParseResult<SourceCheckReport>`，要加 `ParseFailureKind` 得先改 `architecture.md` §5 + ADR。

## 2026-10-21 — M10 书源测试机制落地：四处裁决 + 五个坑

M10（roadmap §5.10）落地：四项规格前置裁决 + 实现 + 双端实跑，官方决策记录是 ADR-0043。

四处裁决（用户逐条选定，均取推荐项）：
1. 校验结果写回 `book_sources` 并在 v4 加 `comment` 列（payload 不动，保 5.8 导出保真）。踩坑：drift 的 `createTable` 用的是**当前**表定义，所以 v4 的 `addColumn` 必须写在 `from >= 2` 的分支里，否则 v1 → 最新会撞 `duplicate column name: comment`（migration_test 的 v1→最新用例就是这条的回归点）。
2. `SearchRule.checkKeyWord` 建模 + 显式「像规则」判据（`looksLikeRule`：http/:// /:: /++ /-- /## /{{ 或 @/$ 开头）；回落词是**数据**不是 UI 文案，所以不进 ARB（英文界面不该把英文词搜进中文站）。
3. 新端口 `LongRunningTask`：Android 用 MethodChannel + `PARTIAL_WAKE_LOCK`（MainActivity.kt + WAKE_LOCK 权限，无新依赖），Windows/iOS no-op；前台服务登记为未闭环，触发=真机息屏被杀。
4. 不动 `ParseFailureKind`：阶段失败 = 报告内 `SourceCheckStageOutcome`；「JS 失效」靠既有的 `:js:error` / `:js:timeout` rulePath 标记，只在 `checkGroupForFailure` 一处读。

实现踩坑（值得记住的三条）：
- **空列表**：`PageFetchService.list` 把「一个都没命中」报成 `parseFailed`，而上游把同一件事叫「搜索失效」。所以归类必须先在 `checkGroupForFailure` 里把 `parseFailed` + `searchRule` / `exploreRule` 映射成 `搜索失效` / `发现失效`，否则一次空搜索会被写成「网站失效」。
- **一个阶段只留一条 outcome**：发现阶段要读「分类」再读「书单」，两次都记 outcome 会让 UI 里出现重复阶段；分类读取因此 `recordsSuccess: false`，失败才记。
- **不可达分支**：`ExploreCategory` 由解析器保证 URL 非空（§4.2 拒掉空 URL），所以「没有可打开分类」的兜底是死代码 —— 直接 `categories.first` 并注释依据，别为覆盖率留不可达分支。
- 协作式取消让上游的 `Incomplete` 没有落点，`SourceCheckFailure` 只有 checkFailed / sourceMissing / saveFailed 三个值。

验证：1003 用例、format 0、analyze 干净、core/domain/data 均 100%、生成物与源码同步；Windows 93 s 与 Android 188 s（含冷启动）设备级全过（核心是 `lib/core/platform/` 与 MainActivity 都改了，必须双端实跑）。五类失败的可复现记录见 `tool/spot_check/source_check_records.md`。

## 2026-10-21 — M4 阅读器落地：四处裁决 + 五个坑（drift createTable / build 内改 provider / freezed 单变体）

M4（roadmap §5.3 阅读器）落地：四处规格前置 + 两个机制，官方决策记录是 ADR-0044。

四处裁决（用户逐条选定，三项取推荐 + 翻页「两种都做」）：
1. 阅读器自有 字号/行距/背景/翻页方式 四轴，存 shared_preferences，与设置页的全局 textScale **叠乘**（不是共用一个旋钮：一个管无障碍缩放，一个管正文偏好）。
2. 进度端口从 ADR-0041 的 `ReadingProgressWriter` 扩成读写 `ReadingProgressStore` —— 恢复位置必须能读，否则进度语义会被推到路由参数里。
3. `books` 加 `tocUrl` 列（schema v5）：书架打开阅读器时直接用它，老行回落到 `bookUrl`。
4. 翻页两种都做：滚动 + 用 `TextPainter` 真实测量的分页；字符偏移是「比例 × 正文长度」的**估算**（已登记触发条件）。

踩坑（值得记住）：
- **drift 的 `createTable` 用当前表定义**：v5 的 `addColumn(books.tocUrl)` 必须写在 `from >= 3` 的分支里，否则 v1/v2 → 最新会 `duplicate column name`（与 M10 v4 同一个坑，第二次踩到说明这条要当成模板）。
- **`ref.read`/改 provider 不能在 build 里做**：`ReaderPage` 要在「路由指定了章节」时换章，直接调 `selectChapter` 会撞 “Tried to modify a provider while the widget tree was building”，改成 `addPostFrameCallback`。
- **freezed 的密封单变体 union 会生成 `ReaderRoute._()` 而 base 是 abstract**：编译报 “The class 'ReaderRoute' is abstract and can't be instantiated”。单变体的路由直接手写 `final class` 更省事（ADR-0011 只要求「类型化对象」）。
- **生成的 provider 名会吞掉 `Notifier` 后缀**（`ReaderSettingsNotifier` → `readerSettingsProvider`），且端口 provider 不要与 use case 生成的 accessor 同名（`chapterContentProvider` 撞过）。
- **跨 feature 打开阅读器走 `AppNavigation.openReader`**（ADR-0042 §决策 2 早就写明这个形态）：端口只收原语，装配根把它变成 reader 的 `ReaderBook`。
- 进度写回后由装配根的适配器 `invalidate` 书架：唯一同时认识两侧的地方顺手把「阅读到」刷新，阅读器不必知道书架页存在。

验证：1051 用例、format 0、analyze 干净、core/domain 100%、data 98.2%、生成物同步；Windows 92 s / Android 185 s 双端设备级全过（`integration_test` 改过 tocUrl 写入，必须双端）。

## 2026-10-21 — M11 范围：聚合搜索（范围/类型/匹配模式/并发/暂停/合并）+ 选源分类筛选

范围（用户四选全中，故拆 M11/M12；本条目 = M11）。上游依据：`F:\Projetcs\legado-upstream`，逐条对照移植，差异逐条写 ADR（与 M1/M10/M4 同一做法）。

M11 = 聚合搜索 + 选源分类（两者共用「哪些源参与」这一个概念，必须一起设计）：

1. **搜索范围**（上游 `ui/book/search/SearchScope.kt` + `domain/model/BookSearchScope`）：全部 / 分组（`bookSourceGroup` 的多个分组）/ 指定源；范围要能持久化并显示（上游 `display` / `displayNames`），范围指向的分组或源消失时回落到「全部启用源」。
2. **书源类型筛选**（上游 `BookSearchRequest.types: Set<Int>?`）：0 文本 / 1 音频 / 2 图片 / 3 文件；默认只搜文本（本仓目前只有文本链路），类型不限时按全部。
3. **匹配模式**（上游 `MatchMode`）：至少「模糊 / 精确（书名）/ 精确（书名+作者）」三档，合并结果时按模式过滤 + 排序。
4. **并发与进度**（上游 `SearchBooksUseCase`）：并发 = 设置页的同一书源并发上限；逐源发出进度事件（已处理 / 共多少源、结果数）；`SearchRunEvent.Started/Progress/Finished` 的等价物；单源超时（上游 60 s）后记失败但**不打断整批**；全部源都失败才算整次失败。
5. **暂停 / 恢复 / 取消**（上游 `BookSearchControl.pause/resume` + `awaitResumed`）：沿用 M10 的 `TaskCancellation`，暂停要在源与源之间生效（不中断在飞的请求）。
6. **结果合并**（上游 `SearchResultMerger`）：按 `bookUrl` 去重、同名书合并「来自多个源」的标记、结果上限、排序；分页与 `hasMore`（上游 `supportsSearchPage()`：不支持翻页的源在 page > 1 时直接跳过）。
7. **选源分类筛选（书源测试分类）**：校验页 / 调试图按「分组 + 类型」筛选要跑的源，可一键全选一个分类；与搜索范围**共用**同一套选源逻辑（一个概念一处实现）。

规格前置（必须先写 ADR 再动代码）：ADR-0045 —— 搜索范围的编码与持久化形态、类型筛选的默认值、`MatchMode` 的判据（含中文/大小写归一化）、结果合并与去重口径（上游按书 URL，URL 相同的不同源是否合并）、分页与 `hasMore` 的判定、暂停语义。

验收（严格档，用户裁决）：每条能力都要 ① 单测 + 派生源/离线语料回归；② 收尾 Windows + Android 双端 `integration_test` 实跑；③ 一次真源抽查（按 `tool/spot_check/README.md` 的选源口径）；④ 聚合搜索的 Widget 测试覆盖 空态 / 进行中 / 部分失败 / 全部失败 / 暂停 / 取消。

## 2026-10-21 — M12 范围：引擎规则面五条（§3.7）+ 编码缺口 + 单源预算与错误容忍

范围（本条目 = M12，与 M11 同批裁决后拆出）。上游依据：`F:\Projetcs\legado-upstream`，逐条对照移植，差异逐条写 ADR。

A. **引擎规则面兼容（§3.7 已登记的五条，逐条取证后实现）**
1. JSON 条目上裸 `@js:` 的 `result` 绑定：本仓给 JSON 文本、上游给条目对象（b7 已取证 85 条源 / 98 个字段）。**这条是规格前置**：先按上游形态写 ADR 改 `book-source.md` §6 的契约，再改引擎。
2. `header` 写成规则（`@js:` / `<js>`，真实语料 21 条）要求值：当前导入降级为无 header + warning（ADR-0040 §决策 6）。要求值就意味着 header 在**取页面之前**求值，与规则引擎的输入（页面）形成先后关系 —— 需要 ADR 说明求值时机与失败语义。
3. 默认 / `@@` 规则打在 JSON scope 上（上游按页面类型选分析器）：先取证上游在「JSON 内容 + `@@`」下选哪个分析器，再决定是否改语义。
4. 页面字段规则的 `page` 绑定与「已取到的那一页」不一致（搜得 / 发现阶段不传 `page`）：按语料裁定。
5. `java.get('bookName' / 'title')` 特例（`AnalyzeRule.kt:812-821`）：把 Book / Chapter 绑进 JS 变量表。

B. **编码与健壮性**
6. Big5 / Big5-HKSCS 既不能检测也不能解码；`shift-jis` / `euc-jp` 严格解码会抛 `RangeError`（`Error`，越出 `ParseResult` 契约，ADR-0022 不得捕获 `Error`）→ 要换依赖或加隔离层，二选一。
7. 逐源重试 / 超时策略：现在 `HttpPolicy` 是全局默认（15 s + 重试上限），单源超时只在 M10 的校验里存在；批量链路（聚合搜索、批量校验）需要一条统一的「单源预算」。
8. 错误容忍：一个源的规则崩了不得影响其他源的结果（M11 的聚合搜索已部分覆盖，本块补「同一源内多阶段失败」的口径）。

规格前置：① JSON `@js:` 的 `result` 契约 ADR（上面第 1 条）；② header 规则的求值时机 ADR；③ charset 依赖的取舍 ADR（换依赖要走 C-DEP-1/C-DEP-7 许可核对 + NOTICE）。三条都在编码前完成。

验收（严格档，同 M11）：每条 ① 单测 + 派生源/离线语料回归（charset 要有字节级语料）；② 双端 `integration_test` 实跑；③ 真源抽查（`header` 与 `@js:` 两条必须有真实源证据，否则只能算「已实现未验证」）；④ `book-source.md` 的矩阵状态列按真实回归逐行改，不得批量勾选。

## 2026-10-21 — M6 落地：书源列表的排序/筛选/拖拽与投影列为准

M6（roadmap §5.5）落地，官方决策记录是 **ADR-0045**（注意：`DECISIONS #6` 里写的「M11 的第一条 ADR-0045」已被 M6 用掉 —— ADR 编号在**动笔时**分配，M11 的搜索规格 ADR 届时取下一个空号）。

用户裁决四项：排序键 = 默认 / **权重降序** / **响应耗时升序** / **名称升序**；`customOrder` 用**拖拽**排序；行内展示 = **分组 / 最近更新 / 响应耗时 / 校验注释**；排序与分组筛选**持久化**。

值得记住的三条：
- **列表必须以列为准**：M10 的校验写的是 `groupName` / `comment` / `respondTime` 三列，`payload` 逐字节不变（ADR-0040 §决策 4）。所以 `StoredBookSource` 这次把五个列投影也暴露出来，展示与排序都读列 —— 否则校验结果永远不显示。
- **`respondTime` 的 NULL 不是 0**：空 = 从未校验，0 = 校验过且几乎瞬间返回；升序时 NULL 排最后（`OrderingTerm(nulls: NullsOrder.last)`），不然未校验的源永远置顶。
- **拖拽写归一化而不是交换**：把当前顺序编号成 `0..n-1` 一次事务写回全部行（含禁用源），幂等且不受中间值相等影响；其它排序键下不给拖拽（拖完会按别的键跳回去 = 拖了没反应）。

验证：单测 + Widget 测试（排序切换 / 分组筛选 / 拖拽重排 / 行内字段 / 注释对话框）、format/analyze/test/coverage 全绿、双端设备级实跑。

## 2026-10-22 — M12 第一切片：URL 规则后缀、`<js>` 分段、header 规则与失败隔离（ADR-0047）

用户要求「继续 M12 + 修聚合搜索 UI 覆盖 + 用 4dc410d1.json 测引擎兼容性」。做法是**先量后改**：新增 `tool/spot_check/batch_probe.dart`（全量四段跑 + stage/kind/rulePath 直方图），128 条语料首轮只有 8 条全通。

落地的七件事（全部有单测，ADR-0047 记录决策与取证结论）：
1. `url,{…}` URL 规则后缀（50/128 条）：`domain/url_rule.dart` 宽松扫描器 + `PageFetchService.fetchRule`；POST body / 每请求 headers / charset 双向（请求侧编码 `{{key}}`、响应侧 `decodeBody(declaredCharset:)`）；JSON 载荷里关键词原样。
2. `<js>…</js>` 分段链（矩阵 #31，50 条）：上一段产出 = 下一段 `result`，`{{result}}` 由此拼进文本；值规则与列表规则各一条链。
3. 列表规则 `@js:` / `<js>`（原 `unsupported:@js:list`）：脚本返回数组即条目，字符串按 HTML 解析成 DOM scope。
4. JSON 条目上裸 `@js:` 的 `result` 改为**条目对象**（M12-A1）。
5. `header` 规则：原文进 `BookSource.headerRule`，`headersOf` 在首个请求前求值（M12-A2）；3 条源的导入失败清零。
6. `$.[*]` 方言归一化（M12-A6）。
7. 三处失败隔离：`redactUrl` 在非法 percent-encoding 上不再抛；流式读 body 的 `DioException` 映射成 kind；聚合搜索逐源 `on Exception` + notifier 保留已发布命中 + 页面只在无结果时显示失败（用户报的「一个坏源冲掉整屏结果」）。

取证后**不改**语义的两条（写进 ADR）：JSON 页面上的默认/`@@` 规则（上游 jayway 同样要 `$` 前缀，换分析器只改变错误位置）、字段规则的 `page` 绑定（字段规则不消费它）。

未做（已登记 roadmap §3.7）：A5 `java.get('bookName'/'title')`（要改域层端口）、Big5 系解码（要换依赖）、统一单源预算（两处各写一份）、`webView` 类 URL 选项。

结果：四段全通 8 → 10；导入失败 3 → 0；抛到批外异常 2 → 0。真源证据：阅友小说（`<js>` header，search=5/toc=57/content=676）、飞卢小说💰（`charset:gbk`，toc 291 → 1087）。双端 integration_test 各 3 文件全过。门禁：1204 用例、core/domain 100%、data 98.47%、生成物同步。

## 2026-10-22 — M12 余项：Big5 解码（MPL 白名单）、A5 书源上下文、统一单源预算（ADR-0048/0049）

用户裁决三项后（「改 C-DEP-7 允许 MPL，引 enough_convert」/「改端口，一次做对」/「新增 domain 协作者 SourceBudget」），M12 余项收尾。

1. **Big5 系（ADR-0048）**：新增 `enough_convert ^1.7.1`（MPL-2.0，纯 Dart、零依赖）。政策从「MPL 一律禁止」改为「MPL 只按白名单放行」：`tool/scan_licenses.dart` 的 `_forbiddenFamilies` 去掉 MPL，新增 `_mplAllowList = {enough_convert}`，名单外的 MPL 仍让扫描退出码非 0。`charset_decoder.dart` 新增 `_encodingOf`（先 `charset` 再 Big5 家族），严格/宽容两条车道共用；宽容车道加 `Big5Codec(allowInvalid: true)`。**只补解码不补检测**：无声明页面仍不猜 Big5（`betto_charset_detector` 没有该候选），HKSCS 扩展区 → U+FFFD。GBK 仍用 `charset`（避免同标签两套结果）。日文 `RangeError` 不动（`enough_convert` 无日文表，语料 0 条日文源）。

2. **A5（ADR-0049）**：`ChapterRequest{url,title,bookName}` 取代裸 URL；`FetchToc.execute(..., {bookName})`；`JsJob` + worker 消息带 `bookName`/`chapterTitle`；`applyJsJavaCall` 的读是 `named[key] ?? variables[key] ?? ''`（内置键先于变量表，`java.put('title')` 不能劫持）。上下文挂在**页面**的 `JsPageContext` 上（`fetchRule`/`fetch`/`_pageOf`/`walk` 都建到 scope），所以条目、翻页规则自动继承。阅读器两个端口加可选参数，`reader_session_notifier` 从 `ReaderBook.name` + 目录项标题填。

3. **单源预算（ADR-0049）**：`domain/source_budget.dart`，`SourceBudget(limit, {clock})` + `remaining`/`isExpired`/`run(op, rulePath:)`；只决定等多久、不作废在飞请求；聚合搜索 60 s 与校验 180 s（跨阶段共享一份）都改用它，删掉两处 `.timeout` 包装与 `_CheckRun.deadline`。

踩坑两条：① `FetchBookInfo`/`FetchContent` 原来在 `walk` 里传 `context`，但 `fetchRule` 自己重建 `JsPageContext` 并把名字丢了 —— 必须在 `_pageOf` 建带名字的页面 scope，否则 job 上永远是 null（单测先发现）。② 覆盖率门禁把「只有 freezed 重定向工厂」的文件判为未测量，`chapter_request.dart` 需登记进 `tool/coverage_allowlist.txt`（第三类）；另外 `decodeJsNamedContext` 里一行 `if (a && b)` 在 short-circuit 下 lcov 记 0 命中，改成 `_putName` 辅助函数后才算覆盖。

验证：1223 用例全过；core 1279/1279、domain 2848/2848、data 98.47%；format 0、analyze 干净、生成物同步；许可扫描 166 包 / MPL 1 / risky none；双端设备级各 3 文件全过，`js_bridge` 25/25（含新增 `jsBridge_whenAJobCarriesBookNames_javaGetAnswersThemFirst`）。注意：`tool/test/run_windows.ps1 -TestFile js_bridge` 会挂住（16 min 超时），直接用 `flutter test integration_test/js_bridge_test.dart -d windows` 正常，脚本这条路径待查。

## 2026-10-22 — M13 范围：UI 修复 + 书源管理（封面、批量、搜索/分组、编辑页、单条校验/导出）；阅读体验归 M14

用户裁决（4 问）：
1. UI 问题位置 = 书源相关页 + 阅读器 + 书架/详情页，并**点名新需求**：发现页要显示书源给的封面图。
2. 书源管理四项全做（批量操作、列表搜索 + 分组管理、书源编辑页、单条校验 + 导出），并追加「支持显示全正常的书源分组」。
3. 阅读体验四项（底部阅读菜单 + 进度/亮度、目录增强、换源、排版扩展）全要，但归 M14。
4. 节奏 = 分两批：**M13 = UI 修复 + 书源管理；M14 = 阅读体验**。

M13 切分（每项独立可验收）：
- S1 封面管线：`cached_network_image` 早就在依赖里却**从未使用**（全仓 0 处引用），所以现在所有列表/详情都没有封面。新增共用 `CoverImage`（占位、错误态、解码尺寸、装饰性语义），接入发现页 / 聚合搜索 / 详情页 / 书架。
- S2 批量操作：长按进入多选，全选/反选/退出，批量启用/禁用/删除/加入分组/移出分组；DAO 补批量方法（现在只有单条 setEnabled / delete）。
- S3 列表搜索 + 分组管理 + 「全正常」：搜索框（名称/URL/分组）；分组增删改；筛选维度加「全正常 / 有失效」——把「全正常的书源分组」落实为：分组列表覆盖**全部**自带分组（含没有任何校验标记的），且能筛出「全部正常」的源。
- S4 书源编辑页：字段编辑 + 保存前用 `BookSource.fromLegadoJson` 校验；保存要重写 payload 并**重算指纹**，而指纹参与 `(url, 指纹)` 唯一索引（ADR-0040）→ 必须先写 ADR-0050（更新同一行 vs 冲突如何呈现；分组写 payload 还是写列）。
- S5 单条校验 + 导出：行菜单加「校验」（复用 M10 `CheckBookSource` 只跑这一条）与「导出」（payload 原文；先做复制到剪贴板 + 保存文件，5.8 的批量导出仍归后续）。
- S6 UI 缺陷修复（审计所得）：详情页没有「开始阅读/继续阅读」（只能从目录项进）、书架/搜索/发现列表无封面（S1）、详情页信息块无封面与简介折叠、搜索页加载更多时无进度提示。阅读器的沉浸式/菜单等归 M14，M13 只修「不修就是 bug」的部分。

规格前置：ADR-0050 必须先于 S3/S4 动代码（分组写哪、编辑后的身份、导出形态）。其余各项无新决策，沿用 ADR-0040/0045/0046。

## 2026-10-22 — M13 落地：封面管线、批量操作、分组/校验双轴、编辑页、单条校验与导出（ADR-0050）

M13 交付（UI 修复 + 书源管理），用户四处裁决见 #11。落地六项：

1. **S1 封面**：`cached_network_image` 在依赖里躺了多个里程碑却 0 处引用（一个封面都不显示）。新增 `core/widgets/cover_image.dart`：占位/失败态同一块、解码按缩略图（`ResizeImage`）、`ExcludeSemantics`（装饰性，C-UI-7）、**`ImageProvider` 注入缝**让 widget 测试能覆盖「加载成功」与「坏字节」两条分支（1×1 PNG / 非图片字节），不依赖网络栈或 cache manager mock。接入发现页、聚合搜索、详情页、书架（书架把「已读」做成封面角标）。
2. **S2 批量操作**：长按进入多选；全选/反选/退出；批量启用/禁用/删除/加入或移出分组。DAO 三个批量方法各在一个事务里；端口加 `setEnabledFor` / `deleteMany` / `setGroupFor`。踩坑：`_selected..clear()..addAll(all.difference(_selected))` 会先清空再求差 → 变成全选，必须先把差集算进局部变量。
3. **S3 搜索 + 分组 + 全正常**：搜索框（名称/URL/分组，页面内状态，不落库）；**两个筛选轴分开**（ADR-0050 §决策 1）——分组读 payload 的 `bookSourceGroup`，校验状态（全部/全正常/有失效）读校验列（`checkOwnedGroups` + 注释）。这条修掉了一个真 bug：`groupName ?? payload.group` 让一次校验把用户分组顶成「搜索失效」。
4. **S4 编辑页**：`/sources/edit`，字段从**payload** 起填（未建模键保留），五组规则用 JSON 文本域（避免第二份 schema），保存前 `BookSource.fromLegadoJson` 校验，撞另一行 `(url, 指纹)` 显式失败（不合并）。用户态（enabled/customOrder）不被编辑重置。
5. **S5 单条校验 + 导出**：行菜单三新项；校验复用 `CheckBookSource`（单条与批量不会不一致）；导出写 **payload 原文**到剪贴板 + 保存对话框（新端口 `BookSourceFileSaver` + `file_selector` 实现 + 不支持平台回落）。剪贴板**不 await**：测试宿主没有该通道的应答，await 会把整个动作挂住。
6. **S6 缺陷修复**：详情页新增「开始阅读/继续阅读」（经 `AppNavigation` 端口，`bookSource` 仍不 import reader）与可折叠简介；封面四处接入。

踩坑两条值得记：①`pumpSourceManagementPage` 里 `localizationOf(tester, ...)` 必须在 pump 之后调用，否则「No element」；②上一轮遗留的 `flutter_reader.exe` 占着 `reader.db`，`on_disk_database_test` 会以 `PathAccessException` 失败——双端实跑前先结束进程。

验证：1263 用例全过；core 1341/1341、domain 2848/2848、data 98.72%；format 0、analyze 干净、生成物同步；许可扫描 risky none；双端设备级各 3 文件全过（js_bridge 25/25）。

## 2026-10-22 — M14 落地：沉浸式菜单、目录 sheet、换源（含身份迁移）、排版四轴（ADR-0051）

M14 交付（阅读体验 R1–R4，ADR-0051）：

1. **R1 沉浸式 chrome**：AppBar 与工具条默认隐藏，点正文中间 ⅓ 唤出、4 s 自动隐藏（`_keepAlive` 重置）；工具条含章节进度滑块（拖动只动标签、松手才换章，否则每帧一次抓取）、上一/下一章、目录、换源、亮度。**亮度是应用级遮罩**（`IgnorePointer` + 黑层 0.2–1.0），不碰系统亮度——Windows 无统一 API、移动端要平台通道，遮罩三端一致且可测；系统亮度登记未做。
2. **R2 目录**：`ReaderTocSheet`，当前章初始偏移居中 + 高亮，正/倒序只反转视图（点行仍回原索引，单测钉住），章节名搜索。
3. **R3 换源**：`SwitchBookSource`（book_source）做候选搜索与切换；候选**逐源**搜（聚合结果的合并行只留一个 bookUrl，换源需要目标源内的地址），并发 4 + `SourceBudget(60s)`，单源失败只少一条候选。对齐顺序：同名 → 包含 → 同索引（clamp）。切换**原地**发生：页面把 `widget.book` 换成可变 `_book`，所有 provider 以它为 key 自动重取；书架身份用新方法 `BookshelfRepository.migrateIdentity` 原地改写（目标身份已有行则两行并存），保住 `addedAt`/状态/置顶。阅读器声明 `BookSourceSwitcher` 端口，装配根（`lib/app.dart` 的 `_SourceSwitcher`）绑到 book_source + bookshelf，两个 feature 仍零 import。
4. **R4 排版**：新增 fontFamily（平台通用族名，**不打包字体**，否则 10+ MB + 许可）、paragraphSpacing（0/0.5/1 → 0–2 空行）、firstLineIndent（0/1/2 em，CJK 用全角空格）、pagePadding（16/24/32）。四轴与旧四轴同存 shared_preferences，越界值在 `ReaderSettings` 工厂钳制到预设台阶；段距/缩进在**渲染前**套一次（`readerBodyText`），正文数据与缓存不动。

踩坑四条：① `String.fromCharCode(10)` 之外写 `'\n'` 的 python 补丁会被转义成真换行，把源码写坏——改用 `_newline` 常量；② `readerBodyText` 原来的 `separator = '\n' * (1 + spacing.round()*2)` 让 0.5 变成 3 个换行，正确是 `1 + (spacing*2).round()`；③ 旧 reader 测试用 `find.text('第二章正文')`，正文现在带首行缩进 → 改 `textContaining`；④ 工具条也有 `Slider`，设置面板的单测必须把 finder 限定在 `ReaderSettingsSheet` 内；⑤ const 构造在编译期折叠，覆盖率统计不到 → 测试里用函数在运行时构造（并 ignore 对应 lint）。

验证：1294 用例全过；core 1352/1352、domain 2971/2971、data 97.25%；format 0、analyze 干净、生成物同步；双端设备级各 3 文件全过（js_bridge 25/25）；无新增依赖。

## 2026-10-22 — M17 落地：音频源播放 + 系统 TTS + 媒体通知；真源受阻于引擎方言缺口

按 ADR-0054 交付 A-0…A-4（分支 feat/m17-audio，基于 feat/source-mgmt-manga-audio）：just_audio 0.10.6 + just_audio_windows 0.2.3 + audio_service 0.18.19 + flutter_tts 4.2.5（全 MIT；176 包 / Risky none）。阅读器按 sourceType 分派 AudioReaderView；TTS 从工具条进 ReaderTtsSheet；两者共用目录/会话/进度端口，音频进度写毫秒。通知端口 core/platform/PlaybackNotification：Android/iOS 用 audio_service（AudioServiceActivity + 前台服务 + POST_NOTIFICATIONS MethodChannel），Windows no-op。Windows 新增两个构建前提：nuget.exe 在 PATH、MSVC /utf-8（platform.md §1.2）。设备级 integration_test/audio_playback_test.dart 双端全过（本地 WAV 实播、TTS 读完一句、Android 通知 attach/update/detach）。真源抽查（用户提供的「🔊书音M」）未通过：chapterUrl 把 {{$.id}} 写进 @js: 字符串并引用上游 book 对象，本仓矩阵 #14 把脚本内 {{…}} 当脚本、沙箱只有 bookName/chapterTitle，目录地址留下字面量 movieId={{$.id}}，站点回「章节不存在」；记「已实现未验证」，两条缺口入 roadmap §3.7。顺带修真 bug：JSON 条目上的 @js: 字段丢失页面 baseUrl（_jsContextOf(JsonScope)），补单测。门禁：1384 用例全过、core 100% / domain 100% / data 98.53%、format 0、analyze 干净。
