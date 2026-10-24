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

## 2026-10-22 — 数据库迁移不可重入导致库永久打不开（已修）

现象：书源列表加载不出来、导入报 DriftRemoteException（日志只有 230 chars 的脱敏摘要）。

根因：用户机器上的 reader.db 是 user_version=5 但结构已经是 v6（source_checks 表、source_checks_source_checked 索引、book_sources.is_explore_enabled 列都在）。每次打开都重跑 v5→v6，drift 的 createIndex 是裸 CREATE INDEX，撞上已有索引抛 already exists → beforeOpen 失败 → 任何查询都失败。成因是「用没提交的表定义建过库」+ drift 不把 onUpgrade 包在事务里、版本号在迁移之后才写。

修复：升级步骤前先查 sqlite_master / PRAGMA table_info（_hasSchemaObject / _addColumnIfMissing），版本门只做注释说明；回归测试 schemaAt(6) + PRAGMA user_version=5；ADR-0056 + C-NET-9 回链 + tech-stack §8 规则。实测：真实 reader.db 副本 503 行、版本升到 6。

教训：日志脱敏把 sqlite 错误正文换成了哈希，先要拿到原始异常才能在库副本上用 drift 复现（flutter test + NativeDatabase 即可）。

## 2026-10-23 — M19 落地：v7 迁移 + 分组/批量/书签/阅读记录/换封面/本书缓存（ADR-0066），六个坑

M19 按用户裁决分两批，但结构改动一次升到 schemaVersion 7（ADR-0066）：批 A = 书签 + 阅读记录 + 详情入口 + `ReaderRoute` 三兄弟；批 B = 书架分组 chip/管理页/多选批量 + 详情改分组/换封面/本书缓存。

1. **ADR 号撞车**：`CHANGELOG.md` 与 `.github/workflows/ci.yml` 早就引用「ADR-0065 = 分层 CI」，而我开工时 `ls docs/dev/adr` 只列到 0064（0065 的 CI ADR 文件当时还没落盘/被我漏看）。M19 的规格 ADR 因此从 0065 改名为 **0066**，并把 `lib/`、`test/`、`tool/coverage_allowlist.txt`、`architecture.md` 里的引用一并改掉。教训：新 ADR 号先 `grep -rn "ADR-00" CHANGELOG.md .github/ docs/` 再定，别只看目录。
2. **drift 表文件没有 `part`**：`books.dart` / 新表文件都不带 `part`，`XxxRow` 生成在 `database.g.dart` 里。DAO 的 `where` 闭包参数必须是**表类**（`(Bookmarks table) => table.x.equals(...)`），写成 `(BookmarkRow row)` 会得到 `String/Int` 上的 `.equals` 未定义；repo/测试要用 row 类时 import `database.dart`，不能只 import 表文件。
3. **两种 orderBy**：`select(t)..orderBy(...)` 的 cascade 要 `List<OrderClauseGenerator<$T>>`（参数是表结构类型），`JoinedSelectStatement` 才用 `OrderingTerm`；`cast` 错会同时报「元素类型不匹配」与「`.equals` 未定义」两串错。
4. **书签 toggle 的首帧**：工具条只在唤出时才构建，`ref.watch(readerBookmarksProvider)` 放在工具条里会让第一帧仍是「未添加」（测试里 tooltip 找不到 `bookmarkRemove`）。改成在 `_textReader` 的 build 里先 watch，再把 `AsyncValue` 传进工具条。
5. **autoDispose Notifier 的 UnmountedRefException**：`ref.read(xProvider.notifier).write()` 之后 Notifier 可能已被回收，紧跟的 `ref.invalidate(...)` / `ref.read(logger)` 会抛。端口与 logger 必须在 await 前取好，`ref.invalidate` 用 `if (ref.mounted)` 守卫（`ShelfBookActions` / `BookCacheActions`）。
6. **对话框里的 TextEditingController**：`showDialog` 返回后立即 `dispose()` 会在退场动画那一帧再 build 一次 TextField，抛 “used after being disposed”。改成 StatefulWidget 对话框（`_GroupNameDialog`）自己持有并释放控制器。

其它：`CoverImage` 新增 `localPath`（本地封面优先于网络 URL）；自定义封面存**绝对路径**（相对路径会让每行书架做一次异步基准目录查询）；`ContentCache.write` 加可选 `bookUrl` 写 `scope_key`，读仍是同一个 `cache_key`，旧条目只是不计入按书统计。验证：1659 用例全过；core 100% / domain 100% / data 97.94%；format 0、analyze 干净、`build_runner` 幂等；新增豁免项 5 条（封面 file_selector 适配器、ShelfCoverPicker 端口、ShelfGroup 与两个书签/记录 freezed 实体、三张 drift 表）。

## 2026-10-23 — M21a 第一批落地：可见 WebView 验证 + Cookie v8 + 引擎 A/B/D 簇（ADR-0068），四个坑

M21a 按用户裁决拆成「验证 + 引擎」与「原 U8–U15」两条线（M22）。第一批交付：可见 WebView 验证页 + 图片验证码页、`SourceVerification`/`WebViewCookieBridge` 端口与装配根绑定、`appNavigatorKey`、cookie 表 v8 与 `PersistentCookieManager`（`main()` 前 hydrate + 写穿 + WebView 双向同步）、`HttpClient.getBytes`、JS 验证族（`startBrowser*` / `getVerificationCode` / `webView*`，用户门控）、`webViewDelayTime`/`webJs`/`overrideUrlRegex`、`ContentRule.webJs`、`retry`/`readTimeout`、`ParseFailureKind.loginRequired`。

坑与结论：
1. **验证族在沙箱里只能是 Promise。** 上游 Rhino 能同步阻塞线程，本仓 QuickJS 不能停下来等宿主，所以 `startBrowserAwait`/`getVerificationCode` 返回 Promise（规则要 `await`），`startBrowser`（上游返回 void）没有差异。**不要**为了「兼容」去假装同步，否则规则拿到的是 `[object Promise]`。已写进 `book-source.md` §6。
2. **等用户的时间必须从 JS 预算里扣除。** 桥的硬预算 `timeout + killGrace` 与 `_onResult` 的「跑满预算 = 超时」判定都按墙钟算；不扣除 `_humanWaitMs` 时，一次两分钟的人机验证会被判成 `js:timeout`。验证调用同时免掉每规则调用额度（额度数的是 CPU 往返）。
3. **`webView` 从「被忽略的选项」变成字段后，旧的 `canWebView && ignored == 'webView'` 分支就成了死代码**；覆盖率门禁直接把它标出来（domain 100% 不允许不可达行），顺手删掉。同理 `UrlRuleOptions` 的 `retry`/`readTimeout` 要在**解析侧**钳制（3 / 120 s），否则 C-NET-2 的「显式上限」形同虚设。
4. **验证码图片不能走文本门。** `HttpClient.get` 会把正文按检测到的编码解码成 String，图片过一遍就坏了；新增 `getBytes`（共享同一套 URL 校验 / 预算 / 重试 / cookie），这也是将来字体反爬（TTF 字节）必需的门。

未做（ADR-0068 落地注记里逐项写了原因与触发条件）：`loginUrl`/`loginUi`/`loginCheckJs` 三个源字段、`ContentRule.sourceRegex`、字体反爬 C 簇、`proxy`/`dnsIp`/`callTimeout`/`HEAD`/`encodedForm`。验证：1719 用例全过；core 100% / domain 100% / data 97.94%；format 0、analyze 干净、codegen 幂等；Windows 双用例（真实 `main()` 启动 + 文件库 v8 cookie）通过；Android 待跑。

## 2026-10-24 — M21a 第二刀：loginCheckJs 是响应拦截器，不是布尔检查；sourceRegex/bodyJs 落地；字体与 D 簇定案

取证后改写了 ADR-0068 决策 3 的口径，并交付第二刀：

1. **`loginCheckJs` = 响应拦截器（上游语义）**，不是「返回 true/false」。上游 `AnalyzeUrl.evalJS(jsStr, result)` 把 `StrResponse` 绑成 `result`，调用方 `res = analyzeUrl.evalJS(checkJs, res) as StrResponse` 用返回值替换响应；真实语料就是 `var src = result.body; if (…) java.startBrowserAwait(result.url(), '登录')`。本仓在 `PageFetchService` 每次取页成功后跑它：`result` 是 `JsResponseView`（`body` 属性 + `url()`/`code()`/`headers()`/`header()`/`cookie()`/`contentType()`/`isSuccessful()`），`null` 沿用、`{body[,url]}` 替换、裸字符串只换正文、其余在「源声明了 loginUrl/loginUi」时给 `loginRequired`。陷阱：**上游 `body` 是属性**（`getStrResponse().body`），Readori 文档与少量语料写 `result.body()` —— 不能两头讨好，选上游属性形态并把方法形态显式报错登记。
2. **沙箱表示**：响应对象走 `JsResponseView.toJson()` 的 `__strResponse` 标记 + `__url`/`__code`/`__headers`，因为 `url`/`code`/`headers` 是上游的**方法名**，不能同时当数据键；方法用不可枚举 defineProperty，`return result` 时 JSON 只带回数据。prelude 用 `__sandboxValue` 分流，普通 `@js:` 的 `result` 语义不变。
3. **三个登录字段建模 + 书源管理「登录 / 过验证」入口**（走同一个 `SourceVerification` 端口打开可见 WebView；`loginUrl` 是 URL 规则，后缀丢掉；脚本形态则打开源地址）。原生 `loginUi` 表单留在 M21b/U15。
4. **`sourceRegex`**：每次取页后、建 scope 前截取（有捕获组取 group(1)，否则整个匹配），片段就是页面（DOM 与 `$.` 都从它读，拦截器也看它）；不命中/正则非法 → `parseFailed(contentRule.sourceRegex)`；`nextContentUrl` 每页各自截取。**`bodyJs`**（URL 选项）先跑、`sourceRegex` 后跑；`bodyJs` 非字符串 → `parseFailed(bodyJs)`。
5. **字体反爬只做评估**：候选包 `glyph_path` / `ttf` / `dart-ttf-parser` / `flutter_ttf_parser` 均不合格（许可 Other 或 Dart 3 不兼容、且都不给「字形↔字符」反查面）；结论是自研 `cmap` format 4/12（150–200 行）+ 合成字体单测，**不引依赖**；开工前只需定一件事：返回表示用 `code → glyphId`（上游用 `post` 字形名对齐），排在 M21a 第三刀，命中仍 `unsupportedRule`。
6. **D 簇五项裁决「不做」并写死重开条件**（proxy / dnsIp / callTimeout / HEAD / encodedForm），不再以「收益未取证」长期挂着。

覆盖率的两个小坑：`const` 构造的 `SourceLoginGuard.none()` 会被编译期折叠、统计不到（改成运行时构造 + ignore lint）；`_interceptLogin` 里「按 scope 取上下文」的分支永远走不到（`_pageOf` 只造 DomScope），改成由调用方把 `JsPageContext` 与当前 body 传进去，顺带删掉不可达分支。

验证：1761 用例全过；core 100% / domain 100% / data 97.94%；format 0、analyze 干净、codegen 幂等。

## 2026-10-24 — M19/M21a 设备级实跑补齐：双端全绿，并补上 WebView↔cookie 双向探针（抓到键名不一致的真 bug）

双端设备级实跑补上了（这也是 M19 的唯一挂账项），并新增一条 cookie 互操作探针：

1. **Windows 5 文件全过**：`app_boot` 1、`audio_playback` 5、`js_bridge` 30、`on_disk_database` 5、`web_view` 3。
2. **Android（`Medium_Phone`，API 37 模拟器）4 文件全过**：`app_boot`、`on_disk_database`（含 v8 cookie jar 跨连接读回）、`js_bridge` 30、`web_view` 3。M19 因此可以标完成。
3. **新增 `webViewCookieBridge_sharesCookiesWithTheWebView`**（`integration_test/web_view_test.dart`）：本地 HttpServer 上验证**双向**互操作——桥 `setCookie` 写进去的 cookie 页面 `document.cookie` 读得到，页面自己种的 cookie 桥 `getCookies` 读得回。这是 ADR-0068 §决策 4 之前只有单测、没有设备证据的一环。
4. **两个新 `js_bridge` 探针**（`loginCheckJs` 的 `result` 响应对象：属性 + 方法 + 返回值往返）当场抓到一个真 bug：`JsResponseView.toJson()` 发的是 `code` / `headers`，而 prelude 读的是 `__code` / `__headers`，于是设备上 `result.code()` 恒为 0、`headers()` 恒空——单测（用 JSON 直比对）看不出来，只有真引擎跑一遍才暴露。教训：**沙箱前奏与宿主序列化的键名必须由同一条设备级用例钉住**，别只测宿主一侧。

最终门禁：format 0、analyze 干净、1761 用例全过、core 100% / domain 100% / data 97.94%、codegen 幂等。

## 2026-10-24 — M21a 第三刀：字体反爬零依赖落地（cmap + post，字形名优先、id 兜底），并砍掉不存在的 getFontGlyph

M21a 第三刀按 ADR-0068 决策 9 的评估执行：零新依赖、自研解析。落地过程中有两处必须改口径：

1. **字形名优先，字形 id 兜底（原评估写的是「只用 id」）。** 站点发的多半是**子集字体**：子集化会重排字形 id，但 `post` 表里的 `uniXXXX` 名字还在。只按 id 对会在真实语料上静默换错字，而且错得看不出来（换出来的是另一个真字）。所以 `TtfFont` 同时读 `cmap`（format 0/4/6/12，Unicode 平台优先、format 12 优于 4，首选子表映射为空时回退到下一张）与 `post` 2.0 自定义名（索引 <258 的标准 Macintosh 名不内置，这些字形退回按 id）。
2. **`getFontGlyph` 不实现。** ADR 早期登记里有这个名字，但上游 master 的 `JsExtensions.kt` 只有 `queryTTF` / `queryBase64TTF` / `replaceFont`。凭空造一个只会让语料里的假拼写看起来合法。

实现形状：
- `lib/core/font/ttf_font.dart`：纯 Dart 解析 + `replaceFontText`。**不做逐字段边界检查**——字体是不可信输入，`parse` 用一个 `try` 把 `RangeError` 翻成 `FormatException`（一处可达分支换掉二十处守卫；`avoid_catching_errors` 已按理由 ignore）。
- `lib/core/js/js_fonts.dart`：`JsFontRegistry`，字体以不透明句柄 `{__ttf, id}` 进脚本，真实字体留在 worker 里，随 job 清空、id 不复用（跨 job 存句柄会「找不到」而不是读到别人的字体）。一次正文替换只花一个小信封，而不是几万个字形的 JSON。
- **字节门**：`java.queryTTF(url)` 需要字体字节，走 `http` 通道新加的 `getBytes` 动词（base64 过界）。文本门会把二进制体解码坏——与验证码图片同一个理由。网络在本仓一律异步，所以这个形态返回 Promise（`await java.queryTTF(url)`），`queryBase64TTF` / `replaceFont` 同步。
- 失败面：不是字体 / base64 坏了 / 句柄失效都只让**这次调用**抛错，不判整条 job 死——没换成功的正文仍然可读。

测试：`test/support/synthetic_ttf.dart` 现拼 sfnt 字节（表目录 + cmap + post），所以「截断文件 / 表撒谎 / 空子表 / 坏分组 / 3.0 post」都能逐字节复现，不必提交二进制字体基线。真引擎上补了三条 `integration_test/js_bridge_test.dart` 探针（base64 往返、url 字节门、非字体报错）。

验证：1810 用例全过；core 100% / domain 100% / data 97.94%；format 0、analyze 干净、codegen 幂等；Windows 5 文件全过（js_bridge 33/33）、Android js_bridge 33/33。

## 2026-10-24 — ADR-0069：用真实导出定位 9 个引擎差距，修 G1/G3/G4/G5/G7/G8，登记 G2/G6/G9

用户给了一份「上游可用、本仓不可用」的 5 条图片源导出，并要求对照本机上游仓库（`legado-upstream`）定位差距。取证方法：逐条导入 + 把每个规则字段送进 `extractFirst`/`extractAll`/`selectAll`/`renderUrl`，只区分「语法被拒」与「没命中」，再把每条结论对到上游源码实现点。结论写进 **ADR-0069**（G1–G9 表 + 登记差异 + 触发条件）。

用户裁决：G1–G5 + G7 + G8 全做，G6 登记。已修六项：
1. **G1 `java.encodeURI(str, charset)`**：两参形态（GBK 关键词）以前按名拒绝。新增 `lib/core/text/charset_encoding.dart` 的 `charsetBytes` 作为「文本→声明编码字节」的唯一实现，`url_template` 的关键词编码与 JS 绑定共用；未知标签退 UTF-8（上游抛错返回 `""`，退 UTF-8 更有用）。
2. **G3 任意段末尾 `.N` 索引**：`#image_div img.0@src` 被 cascadia 当「类名 0」。degraded 段现在剥「纯数字（可带负号）」的尾巴当索引；`div.item` / `.result-item` 不受影响。落地时确认了 `.-1` / `!0` / `tag.img.0` 本来就支持，只有「裸 CSS 段」缺这一刀。
3. **G4 图片/封面的 `,{…}` 选项**：以前整段 JSON 进了地址。漫画页把选项里的 `headers` 并进该章图片请求头（章节内通常同一套），地址只留 URL；封面地址裁掉选项 + warning（封面加载器还带不了 header，登记）。`stripUnreadableUrlOptions` 顺势更名 `stripUrlOptions`（同一个「切掉 `,{…}`」现在有两个正当用途）。
4. **G5 `imageStyle` / `imageDecode`**：两字段建模（不再落 `extra`）。`imageDecode` 非空 → 显式 `unsupportedRule(contentRule.imageDecode)`——静默降级会把加密字节当图片摆给用户，比失败更坏；`imageStyle` 打通 `MangaPages → ReadingPage.style → 阅读器`，`single` = 一图一屏（`BoxFit.contain` + 视口高），`left`/`right`/居中的对齐分支登记未做。
5. **G7 `Array.prototype.size`**：真实正文 JS 用 `list.size` 遍历 `java.getStringList(...)`；没这条垫片循环一次都不跑，正文**静默变空**。与既有 `toArray()` 垫片同族，只加 getter（属性与方法不能同名）。
6. **G8 目录项空 `chapterUrl`**：以前直接跳过该章 → 美图网这种单章图片书整本没目录。现在回落到目录页地址（上游 `BookChapterList.kt:246-258` 同口径）+ warning。

登记不做（ADR-0069）：**G6** 同步 `java.post/get/ajax` 响应对象（沙箱是独立 isolate，阻塞不了宿主；规则须写 `await http.post`）、**G2** URL 规则里的非 JS `{{…}}`（本批 5 条源走的是值规则，已支持；URL 规则要先把 scope 传进 `renderUrl`，影响面未取证）、**G9** 列表 JSONPath + `@js:` 的 `result` 形状（要该站真实响应体才能定论）、封面 per-URL header、`imageStyle` 对齐分支。

坑一条：`build_runner build --build-filter=…` 会把不匹配的生成物**删掉**（一跑 `flutter analyze` 报 4000+ 错），恢复办法是全量 `dart run build_runner build --delete-conflicting-outputs`；以后改实体别用 filter。

连带修：G8 让「目录里有条目但没有 URL」不再是「成功且为空」，`switch_book_source` 里那条 `data.isEmpty` 分支变成不可达（删掉并注明），`check_book_source` 的 `emptyGroup` 分支改由「搜索列表命中但每条都没 bookUrl」这条真实路径覆盖。

验证：1830 用例全过；core 100% / domain 100% / data 97.94%；format 0、analyze 干净、codegen 幂等；设备级 `js_bridge` 新增 `list.size` 探针（真引擎）。

## 2026-10-24 — ADR-0069/0070：兼容性六项修复落地；M20 规格定案（rules 单表 v9 + 顺序预取搜索）

先说兼容性取证，再做 M20-a。

**兼容性（ADR-0069）**：用户给的 5 条「上游可用、本仓不可用」源全是 `bookSourceType: 2`。我逐条导入并把每个字段送进 `extractFirst`/`extractAll`/`selectAll`/`renderUrl`，只区分「语法被拒」与「没命中」，再把每条对到本机 `legado-upstream` 的实现点，得到 G1–G9。用户裁决「G1–G5+G7+G8 全做，G6 登记」，已全部落地（详见 DECISIONS #21 / ADR-0069）。

**M20-a（ADR-0070）**：用户裁决「Drift 单表 + kind 列」「顺序预取 + 可停止」。落地内容：

1. **ADR-0070** 定两件事：四类规则共用一张 `rules` 表（`kind` + JSON `payload`，payload 形状由 ADR 拥有，未知键保留、坏 payload 标坏不丢），以及书内搜索的语义（从当前章起顺序预取、并发 2、受速率门与 `SourceBudget`、`cancel()` 停新请求但保留已取正文、命中带 `(chapterIndex, title, url, offset, excerpt)`）。还写死了接线范围：**只有净化规则**承诺影响阅读（接在 `replaceRegex` 之后），字典/高亮/目录规则 M20 只做列表+编辑+启停，因为分别缺选词入口、富文本渲染、本地 txt 导入。
2. **schema v8 → v9**：`rules` 表 + `(kind, sort_order)` 索引；迁移只做结构（内置规则由仓储首次使用时播种，`hasAny` 区分「从没初始化」与「用户清空了」）；`drift_schema_v9.json` + `generated_migrations/schema_v9.dart` 一并提交，迁移测试补 v8→v9、v1→v9 与「版本落后于结构」三条。
3. **`RuleDao`**：`ofKind` / `enabledOfKind` / `insert`（缺省追加到该 kind 末尾）/ `updateRow` / `deleteById` / `deleteKind` / `hasAny` / `_nextSortOrder`，11 条单测。

坑：`build_runner --build-filter` 会删掉不匹配的生成物（4000+ analyze 错），改实体一律全量 build。另外迁移测试里几条 `fromV?ToV8` 的名字在目标版本升到 9 后一并改名，避免「名字说 8、断言跑 9」。

验证：1842 用例全过；core 100% / domain 100% / data 97.94%；format 0、analyze 干净、codegen 幂等、schema dump 与生成迁移同步；Windows 5 文件全过（含 on-disk v9）。

## 2026-10-24 — 真机日志四连：content 单值语义（G9）、explore 分组标题（G11）、默认 UA（G10）、HTTP 失败日志（G12）

用户贴了一段真机日志，四类 warning 各对应一个不同的 bug，全部修掉（ADR-0069 增补）：

1. **`JS rule failed: field=contentRule.content error=<String: 14 chars>`** —— 14 字符就是 `not a function`。那份导出的正文规则是 `$.data[*].image` + `@js:result.split("\n")`：上游 `BookContent.kt:234` 对所有书型都用 `getString`，而 `AnalyzeRule.getString` 把多匹配 `joinToString("\n")`，脚本拿到的是**字符串**；本仓漫画链路用 `extractAll`，`result` 是 **List**，`split` 不存在。修法：新增 `RuleEngine.extractJoined`（= `getString` 语义），漫画链路改用它并按行切分；同时把**单值字段交给脚本的 `result`** 从「首个匹配」改成「换行拼接的字符串」（`extractFirst` 的返回值口径不变，仍是首个匹配）。
2. **`Explore category rejected … missing url (title=══ 推荐 ══)`** —— 真实 `exploreUrl` 用「只有标题、没有地址」的条目做**分组标题**；上游 `BookSourceExtensions.exploreKinds()` 直接映射、不校验 url 非空，本仓却按坏条目丢了。修法：`ExploreCategory.url` 可空（`null` = 分组标题），解析两条路径都保留，发现页画成不可点标签，`openCategory` 遇 null 直接返回，`ExploreBooks` 防御性返回空列表。
3. **`Request failed for rule=ruleToc/ruleBookInfo/exploreUrl … <DioException: sha256>`** —— 两层：① 默认 UA 是 `flutter_reader`，一批站点在规则跑之前就 403（上游 `FeatureSettingsRepositories.kt:157-162` 默认是桌面 Chrome）；② 日志把 dio 异常整体脱敏，403 与超时长得一样。修法：默认 UA 换桌面 Chrome（源的 `header` 仍覆盖，C-NET-4）；失败日志带 `type=`/`status=`，URL 仍走 `redactUrl`。
4. 顺带：漫画链路换掉 `extractAll` 之后 `PageFetchService.extractAll` 成了死代码（C-BAN-1），删掉。

转义又踩了两次坑（python 里写 `\n` 进 Dart 源码变成真换行）：以后这种多行/带反斜杠的测试片段改用 write 工具写进临时文件再 splice，别在 heredoc 里拼。

验证：1851 用例全过；core 100% / domain 100% / data 97.94%；format 0、analyze 干净、codegen 幂等；Windows 5 文件全过（js_bridge 34/34）。

## 2026-10-24 — G13/G14：`class.a b c` 全类命中、`java.getStringList` 求值、`size`/`size()` 双形态

用户又给了同一批源（美图网 / 美女图片网 / 小姐姐写真）要"继续修"。这次把每条源的每条规则过了一遍引擎，只剩两个纯引擎缺口（第三十条源是 G6）：

1. **G13：`class.a b c` 是「这几个类都要有」。** 上游 `AnalyzeByJSoup.ElementsSingle` 对 `class` 用 `temp.getElementsByClass(rules[1])`，jsoup 的语义是「元素必须同时带这些类」；本仓把整串当一个类名（`.${escapeCssIdent('a b c')}`），于是 `📷🔞美图网` 的**每一条**规则都返回空：`bookList`、`ruleBookInfo`（`class.container pt-3@tag.a.3@text`）、正文（`class.mb-4 container-inner-fix-m@html`）、目录。修法：`_classSelector` 按空白切分拼成 `.a.b.c`，单类行为不变。
2. **G14：`java.getStringList` 求值，`parse.getElements` 求元素。** 美女图片网正文 `java.getStringList("@css:.ArticleImageBox img@src")` 上次在设备上拿到空数组：上游 `AnalyzeRule.getStringList` 会跑**提取段**并回 `List<String>`，而我们把 `getStringList` 与 `getElements` 混成一条通道（都答元素文档），末尾 `@src` 被当选择器。ADR-0037 §决策 3 当初就把两者写成一件。现在 `JsParseRequest.wantsValues` 分流：`getStringList` → 抽取值并串化（与上游 `List<String>` 一致），`getElements` → 元素文档（类型保真）；字面量内联与宿主求值器两条路径同口径。
3. **G14 附带：`list.size` 与 `list.size()` 都要成立。** 同一份导出两条脚本各用一种。上一轮加的是属性 getter，`size()` 直接 `not a function`。改成「取回来的是可调用对象」：调用 → 长度，参与算术/比较 → `valueOf()` → 长度。只有严格相等（`list.size === 3`）不成立，语料没有这种写法。

连带：`java.getString` 的多匹配在半内联路径上也要换行拼接（上一轮改了沙箱的 `result`，内联路径漏了）。

**G6 仍是`📷🔞小姐姐写真`的唯一死结**：正文只有 `java.post(...).body()` 一条路，沙箱阻塞不了宿主。两条出路：登记（现状），或做**确定性重放**（同步网络调用抛哨兵 → 宿主执行 → 记忆表重跑脚本，直到无待办）。后者能覆盖 `java.post/get/head/ajax/connect` 整族，但脚本会被跑多次（`java.put`/`log` 重复）、`js:quota` 计数要重新定义，属于一轮独立设计，已在 ADR-0069 增补里写明，等用户裁决。

验证：1859 用例全过；core 100% / domain 100% / data 97.94%；format 0、analyze 干净、codegen 幂等；Windows 5 文件全过（js_bridge 34/34）、Android js_bridge 34/34（含新的 `size()` 探针）。
