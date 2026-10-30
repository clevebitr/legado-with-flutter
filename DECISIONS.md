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

## 2026-10-25 — M20-b 开工前的四项裁决：播种范围、rules feature 边界、净化与缓存、G6 维持登记

开工前四项空白已由用户裁决，全部写进 ADR-0070 的「增补（2026-10-24，M20-b 开工前的四项裁决）」：

1. **播种（§5）**：只播目录规则（上游 `txtTocRule.json`）与字典规则（`dictRules.json`），净化/高亮不播。原文「内置净化规则」与上游事实不符，已撤销——上游 assets/defaultData 里根本没有默认净化规则，凭空的净化会改用户正文且无从解释。
2. **feature 边界（§6）**：新建 `lib/features/rules/`（data/domain/presentation/di.dart）。判据：dict/highlight/toc 与书源无关，数据源是 Drift 而非 shared_preferences，所以既不属于 book_source 也不属于 settings。book_source 要读净化规则、规则变更要清缓存，两件事只走 ADR-0041 端口 + 装配根绑定，rules 不被任何 feature import。
3. **净化与缓存（§7）**：保持「replaceRegex 之后、写缓存前」，但 `replace` 规则任一写入（增/改/删/启停/排序）后作废正文缓存——只删 `ruleField = content` 的条目（`CacheDao.deleteByRuleField` + `ContentCache.clearAll()`），书源信息/目录/封面缓存保留。不做「只删受影响章节」：规则是全局表达式，命中面无法先验确定。副作用：进度/书签偏移可能与新正文不逐字对应，与 5.3「进度是比例估算」同量级，不另开机制。
4. **G6（§8）**：维持登记不做（ADR-0069 的口径不变），不做确定性重放。理由：本轮只一条源命中，重放会改 job 执行语义（脚本多次运行、java.put/log 重复、js:quota 计数重定义），属独立一轮设计与验收。

文档改动：ADR-0070 §决策 4 修正 + 增补 §5–§8 与「影响（增补）」；`architecture.md` §1 的 feature 列表加 `rules`（引用 ADR-0070）。

## 2026-10-25 — M20-c 规则管理 UI：四类共用一页、表单保留未知键、入口在「我的」

M20-c 落地，形态写进 ADR-0070 增补 §9：

- **一条 kind 一页**：`RulesRoute.list(kind)` → `RulesListPage`，四类共用启停 / 拖动排序 / 删除 / 点击进表单；kind 只影响标题与行摘要。
- **字段之外的东西一律保留**：`RuleEditPage` 只呈现当前 kind 的字段，保存时把 `timeoutMs`（净化）与 payload 的 `extra`（上游的 volumeRule / example / excludeScope 等）原样写回——这是 ADR-0070 §决策 1「未知键必须保留」在 UI 上的落点。
- **入口在「我的」**：`AppNavigation` 加四个方法（openReplaceRules / openTocRules / openDictRules / openHighlightRules）。四个方法而不是一个带 kind 参数的：端口只收发原语（ADR-0042），字符串 kind 会把 switch 搬进每个实现。
- **排序也作废缓存**：`RuleRepository.reorder` 把整类重编号 0..n-1，`replace` 触发一次正文缓存作废（顺序变了净化结果就会变）。
- **表单前置校验**（执行期仍按 ContentPurifier 的规则跳过）：正则必须能编译、颜色必须 #RRGGBB/#AARRGGBB、名字与各 kind 必填表达式非空。
- **坏 payload 可修**：表单显示「存的内容读不懂」+ 原文，填好合法内容保存即替换。

踩坑：MyPage 多了 4 行之后「设置 / 关于」落到首屏之外，`ListView(children:)` 是懒挂载的，老测试 `find.text` 直接找不到 → 测试改成先 `scrollUntilVisible`。表单页的保存按钮同理：`RuleEditPage` 的坏 payload 分支多出一段提示，Save 被挤出视口，tap 静默不打中，抽取 `_save()` 帮手统一 `ensureVisible`。

验证：1969 用例全过；core 100% / domain 100% / data 98.42%；format 0、analyze 干净。

## 2026-10-25 — M20-d 书内全文搜索：reader 侧窗口预取 + 自量预算 + sheet 落点

M20-d 落地，落点写进 ADR-0070 增补 §10（§决策 2 的语义不变：当前章起顺序预取、并发 2、可停、命中带章节与偏移）。

- **用例在 reader**：`SearchInBook` 只依赖阅读器已有的 `ChapterContentProvider`，所以「发请求」仍全在 book_source，速率门与 `HttpPolicy` 原样生效。
- **预算自己量**：`SourceBudget` 属 book_source/domain，跨 feature 不能 import（C-ARCH-2），改用注入 `Clock` + `budget`（默认 2 分钟，与聚合搜索 60 s / 校验 180 s 同量级），用完以 `budgetSpent` 停，已找到的命中仍算数。
- **窗口式顺序预取**：每窗 ≤2 章、`Future.wait` 后按章序产出；不是滑动窗口（慢章会拖同伴），换来顺序与「最多 2 个在飞」一眼可验。
- **取消语义**：cancel 后不再发新请求、在途结果丢弃（正文留在缓存里不算副作用）；run 放在**下一个微任务**启动，所以 `execute` 后立刻 cancel 一个请求都不发。
- **命中粒度按上游逐条**，但每章上限 20 条；`excerpt` 两侧各 40 字符、换行压空格；`offsetInText` 用 `RegExp(caseSensitive: false)` 在原串求位置——不用 `toLowerCase` 双串比较，因为 `İ` 这类字符会改长度、把偏移整体挪位。
- **失败章节不吞**：计入 `failedChapters` 并在 UI 明说「有 N 章读取失败」。
- **UI 是 sheet**：入口在阅读器 AppBar 搜索按钮；点命中把 `hit.offsetInText` 当 `charOffset` 交给 session（与书签同一套，ADR-0066 §决策 7），落在那一句；关 sheet 即 dispose → 取消。

踩坑两条：① 单订阅 `StreamController.close()` 的 future 在有监听者之前不完成，所以 `run()` 末尾改成 `unawaited(controller.close())`，否则只等 `done` 的调用方会永远挂着；② autoDispose notifier 在测试里用裸 `container.read` 轮询会在两次读之间被销毁而自动取消搜索，测试必须先 `container.listen` 保活。

已登记（roadmap §3.7）：搜索历史/结果落库、正则开关/繁简转换/跨书聚合，均带触发条件。

验证：1999 用例全过；core 100% / domain 100% / data 98.42%；format 0、analyze 干净、codegen 幂等、Windows app_boot 通过。

## 2026-10-25 — M23 规则与书源导入导出、净化 scope 与 @js: 替换

按用户四项裁决（连 scope 与 `@js:` 一起做、书源导出全部+选中、预览+逐条勾选、URL+粘贴+文件）落地，规格在 ADR-0071。

**导出的格式就是上游的**：净化规则导出为 `ReplaceRule` 数组（`id` 不导出、`order`/`isEnabled` 取列值、`timeoutMillisecond` ↔ `timeoutMs`、未知键经 payload 的 `extra` 往返）；书源导出直接写存储里的 payload（ADR-0040 §决策 4 的原样保真），只覆盖 `enabled`/`customOrder` 两个用户态键——因此单条导出也改走同一方法，ADR-0050 §决策 4 的「字节就是 payload」被这一条修订。

**导入**：`ImportReplaceRules` 接三种来源（粘贴/URL/文件，32 MB 上限，明文 http 跟 `allowPlainHttp`），先预览（逐条可勾、坏条目带原因且不可勾），提交时按 `name`+`pattern` 去重——同键改写、不同键新增、**从不删除**；提交前重新读库，避免「更新一条预览后被删掉的行」变成静默无操作。

**执行面两块新东西**（这是用户明确要求的「不只是搬运」）：
- *scope*：`PurgeRule` 带 `appliesToContent`/`appliesToTitle`，`purgeContent` 与 `purgeTitles` 各扫各的；标题净化在装配根把目录映射成阅读器 `ReadingChapter` 时做，因此目录 sheet / 正文头 / 进度名 / 搜索命中是同一份净化后的标题。
- *`@js:` 替换*：一条规则**一批一个 job**——所有匹配合成 `__matches`，用 `eval` 的完成值取每条替换（上游的脚本常写成 `if (…) { … } else { "" }`，语句形态只有 eval 能回答）；`timeoutMs` 终于有了用处（该 job 的上限），脚本报错/超时/答案长度不符都只跳过该规则。设备级用例在真 QuickJS 上跑通了这套脚本形状。

**语料口径校正**：`净化规则.json` 20 条里 `@js:` 只有 4 条（#01–#04）、标题专用 1 条、全部 isRegex/带 group/无 timeoutMillisecond——ADR 背景里先写成「大量」是错的，已按逐条统计改正。

登记（roadmap §3.7）：规则分组只存不展示不筛选、正则规则仍无超时、标题净化不覆盖详情页目录预览与书架「最新章节」。

验证：2062 用例全过；core 100% / domain 100% / data 98.25%；format 0、analyze 干净、codegen 幂等；Windows app_boot 通过、js_bridge 35/35（含新的真沙箱净化替换用例）。

## 2026-10-25 — M22-a 第一批：按源缓存（v10）与 Cookie 管理页

M22 拆批并落了第一批（ADR-0072），先按用户裁决对齐上游行为：

上游实况（逐条查过）：缓存清理只有「全部 / 按书」（`BookHelp.clearCache`），**没有按源**；Cookie 只有书源编辑页里的「清掉该源的 Cookie」（`BookSourceEditViewModel.clearCookie`）+ `enabledCookieJar` 开关，**没有列表页**；`loginUi` 是 `RowUi` 数组（text/password/toggle/select/button + `viewName` 可求值 + 本身可以是 `@js:`/`<js>`），登录信息由 `BaseSource.putLoginInfo` 加密存、确认时跑 `loginUrl` 里的 `login()`。所以「按源缓存」与「Cookie 列表」是本仓在**上游没有的粒度上做的增强**，ADR 里写明了这一点。

第一批交付：
- **schema v10**：`cache_entries.source_key` + 索引；迁移**顺带清空旧缓存**——摘要无法反推，留着会让按源统计在 TTL 内少算，缓存又是可再生数据，清空比显示错数诚实。schema dump v10 + 迁移测试（fromV9→v10、全量链路、版本断言）齐了。
- **按源缓存页**（book_source，「我的 → 缓存管理」）：每源章数、清理该源、清理过期、清空全部（带二次确认）。
- **Cookie 管理页**（settings，「我的 → Cookie 管理」）：按域分组，显示名称与过期（**不显示值**——会话凭据印在屏上没有用处）；删单条/整域/过期/全部。`CookieStore` 补 `deleteByDomain`/`deleteAll`。
- `ContentCache` 补 `countForSource`/`clearForSource`/`countAll`/`clearExpired`。

登记：每书源 Cookie 隔离仍不做（当前是全局按域）；登录信息将按 ADR 明文存库（与 Cookie 同级）；`putLoginHeader`/`upLoginData` 不做。

验证：2089 用例全过；core 100% / domain 100% / data 98.30%；format 0、analyze 干净、codegen 幂等；Windows app_boot 与 on-disk 数据库用例通过。

## 2026-10-25 — M22-a 第二批：loginUi 原生登录表单与 login() 执行

M22-a 第二批落地（ADR-0072 §决策 3 + 实现注记）：loginUi 表单 + 登录信息 + `login()`。

上游行为照搬的地方：`loginUi` 是 `RowUi` 数组（text/password/toggle/select/button，`chars` 是选项、`default` 初值、`viewName` 引号字面量或脚本）；`loginUi` 本身可以是 `@js:`/`<js>`（前置 `loginUrl` 的脚本求值）；确认时**先存值再跑** `<loginUrl 脚本>\nif (typeof login=='function'){ login.apply(this) } else { throw ... }`，值绑在 `result`；脚本失败也保留已存值。

本仓的落点：
- **schema v11** `book_sources.login_info`（JSON 文本，属用户态，重导入不覆盖）。原计划并进 v10，但 v10 已提交，改历史版本会让已升到 v10 的库永远补不上列——ADR-0056 的同一教训。
- `ResolveLoginForm`（domain）：字面量/脚本两种 `loginUi`、`viewName` 求值（失败退回 `name`）、未知 type 退 text、无 `name` 的行跳过；坏文档给 `loginUi` 的 rulePath。
- `SignIn`（domain）：确认与按钮 `action` 两条入口共用同一个 `_run`；`loginUrl` 是裸地址时明确 `unsupportedRule`（那是浏览器那条路）。`loginScriptOf` 统一判定三种脚本形态。
- 沙箱：`JsJob.loginInfo` 快照 + 前奏 `source.getLoginInfo()`/`getLoginInfoMap()`（沿用 ADR-0034 的「随 job 进、随结果回」机制）。
- 入口：列表行「登录」——有 `loginUi` 走表单页，只有 `loginUrl` 仍走可见 WebView；表单为空就明说。

登记（roadmap §3.7 + book-source.md §11 已改）：登录信息只喂给登录自己的 job，页面请求 job（`loginCheckJs`/字段规则）还读不到；`java.upLoginData`、`source.putLoginHeader` 未做。

验证：2118 用例全过；core 100% / domain 100% / data 98.35%；format 0、analyze 干净、codegen 幂等；Windows app_boot / on-disk / js_bridge(35) 逐个跑通。

## 2026-10-25 — M22-b 备份与恢复：zip + 每表 JSON、合并式恢复、archive 依赖

按用户四项裁决（范围 = 数据 + 设置、恢复 = 按自然键合并、格式 = 本仓格式带 manifest、归属 = 新 feature `backup`）落地，规格在 ADR-0073。上游格式只当对照组：每表一个 JSON + config.xml，没有 manifest、按 id 插入、个别表 replaceAll。

落地要点：
- 产物 backup<yyyy-MM-dd>.zip：manifest.json（formatVersion/createdAt/appVersion/tables/preferences）+ 七个表文件 + preferences.json。行对象用列名（camelCase）作键，DateTime 一律 ISO-8601 UTC，id 不导出；books 的分组写组名（groupName）而不是 groupId。
- 恢复：先整包解析校验，再在一个 drift 事务里按自然键合并；从不删除；本地进度更新时不回拨；已存在的规则/书签/会话不动；书源已存在时刷新 payload 与用户态但不搬 customOrder；单行坏掉记 skipped，文件级坏掉整次失败。
- 设置：PreferenceStore.snapshot()/writeAll()（只写给的键、返回写入数），备份 feature 不需要知道任何 settings.* / reader.* 键名；恢复后由装配根的 RestoreCompletionHook invalidate 两个 keepAlive 设置 provider，否则界面一直显示恢复前的主题与字号。
- 依赖：archive ^4.5.2（MIT、纯 Dart、此前已是 dev 传递依赖，包总数不变）；新增端口 BackupArchiveSaver / BackupArchivePicker，读取前按 XFile.length() 判上限，解码前按中央目录声明值判条目大小。appVersion 是 core/app_version.dart 的常量镜像，app_version_test 读 pubspec.yaml 防漂移。

踩坑：
- archive 4.x 两种失败类型：结构坏（截断/中央目录越界/zip64 locator 坏）抛 ArchiveException，解压流坏抛 FormatException（Windows 实测）。统一进私有 _guarded 后两个 catch 都有可测触发路径。构造触发输入的手法：① EOCD 前 20 字节写 zip64 locator 签名；② 把中央目录「解压后大小」写小；③ 打坏 deflate 数据。
- 纯垃圾字节不会让 decodeBytes 抛：它安静解出空档案，失败落在「没有 manifest」。别为「不是 zip」写走不到的分支。
- pumpAndSettle 等不到 Isolate.run 的结果，且 working 态的 LinearProgressIndicator 一直在动会直接超时；widget 测试要 tester.runAsync + pump（见 backup_page_test 的 _tapAndWait）。
- const 构造折叠再次踩到：OversizedBackupArchive / BackupContents 的非 const 用例要 // ignore: prefer_const_constructors 并写理由，否则 core/domain 的 100% 门禁缺执行点。
- DAO 时间戳可注入：insertNew / upsertProgress / restoreUserState 加可选 createdAt/updatedAt/tocUrl，默认仍取 Clock；恢复要写回备份里的时间，否则「最近阅读」被重排。

验证：2196 用例全过；core 100% / domain 100% / data 96.41%；format 0、analyze 干净、codegen 幂等（第二次写 0 输出）；scan_licenses 193 包 Risky items: none。Windows 设备级用例未跑（本批无平台通道改动，file_selector 对话框在宿主 VM 里不可自动化）。

## 2026-10-25 — M22-c 备份增强：位置/自动备份与保留份数/覆盖恢复/整包加密/WebDAV

按用户裁决落地 ADR-0074：四项一次做完（含 WebDAV）、范围维持不含 Cookie/缓存/校验历史、凭据进系统密钥库、安全副本写「用户选的备份位置，未设置则应用私有目录」。

交付：
- 备份位置：BackupLocation = appPrivate（path_provider 的应用支持目录 /backups）或用户选的文件夹；自动备份、恢复前安全副本、页面「保存到备份位置」共用；文件夹不可用回落私有目录并在页面显示真实落点；「另存为…」仍走系统保存框。
- 自动备份：AppShell 首帧后触发，1 天节流（backup.lastAutoBackupAt），成功后保留份数 N=1..30（默认 5，N=1 等价上游 onlyLatestBackup）；只删匹配 ^backup.*\.zip(\.enc)?$ 的文件；时间戳只在写成功后前进。
- 覆盖式恢复：RestoreMode.overwrite 在同一 drift 事务里先清空七张表再写入；覆盖前先写 backup-before-restore-<yyyyMMdd-HHmmss>.zip[.enc] 安全副本，写失败即中止；preferences 两种模式都只合并不删除。DAO 补 deleteAll（分组/书签/阅读记录/规则）。
- 加密：整包 WinZip AES-256（archive 自带 password 支持，不引新密码学依赖）；口令存 flutter_secure_storage；解码前先读中央目录 flag bit 0 判「加密包」，无口令报 backup.read.passwordRequired、口令错报 backup.read.badPassword（外层兜底：加密包+有口令仍读不出=口令错）。
- WebDAV：core/network 的 WebDavClient（PROPFIND Depth:1 / PUT / GET / DELETE，Basic 认证，http 受 allowPlainHttp 约束）+ features/backup/data 的 WebDavRemoteBackupStore（凭据每次现读、只认本应用命名、远端保留份数）；页面有配置对话框、上传、刷新、云端恢复、删除。
- 新依赖 flutter_secure_storage ^11.2.0（BSD-3），包数 193→201，Risky items: none。

踩坑：
- dart:io 的 HttpDate 才是 PROPFIND 的 getlastmodified 格式（RFC 1123）解析器，DateTime.tryParse 对它一律返回 null——一度让所有条目落到 epoch、列表退化成按名字排序。HttpDate.parse 对非 RFC1123 抛 HttpException（不是 FormatException），所以只接 HttpException。
- 同一时间戳的排序要用名字兜底，否则会随服务器返回顺序抖动。
- 集合条目（href 以 / 结尾）必须跳过，真实 NAS 有的不给 resourcetype。
- widget 测试里 ListView 是懒挂载：先 drag 到目标再 tap，否则静默打空；Isolate.run 需要 tester.runAsync 给真实事件循环。
- secret store 的默认闭包（插件调用）在宿主 VM 里跑不到：用一个 FlutterSecureStorage 的假子类注入 storage 参数，才能覆盖那三行（core 100% 门禁）。
- const 构造折叠又一次：OversizedBackupArchive / BackupContents 的测试用例改非 const 并 // ignore: prefer_const_constructors。

验证：2298 用例全过；core 100% / domain 100% / data 95.79%；format 0、analyze 干净、codegen 幂等（第二次 0 输出）；scan_licenses 201 包无风险项。未做（已登记 §3.7）：后台调度的自动备份、密钥库不可用时的降级策略、口令强度校验、云端进度同步、读上游 zip。主题与阅读设置扩展（U9/U10）本轮未开始，下一步。

## 2026-10-25 — M24 同步 java.* 重放层的切片与验收

目标：让上游「同步 java.*」书源不改写即可跑（触发源：来看文学，`java.ajax` 在 searchUrl 第一行就拒绝）。

切片顺序（每片都能独立过门禁）：
1. 与重放无关的三个缺口先补：`cookie.getCookie/setCookie/removeCookie`（读自 job 快照、写穿 CookieManager）、`source.getVariable/setVariable/putVariable`（每源持久变量，落点待定：Drift 新表 or 复用书源字段）、`java.toast/longToast`（转发到 UI，去重）。
2. 重放骨架：worker 内 `java.ajax` 命中未缓存 → 抛哨兵 `{op,url}`；桥取页后缓存 → **从脚本开头重跑**；`_variables` 按 pass 重置、成功 pass 才提交；pass 上限 16；等人的时间不计预算（沿用 ADR-0068 §决策 5）。
3. 同步族补齐：`java.ajax/post/head`（`post` 返回可 `.header()` 的响应对象，复用 `http.* {response:true}` 的信封）、`java.getCookie`、`java.setContent`（页级 scope 的内容覆盖）。
4. 验证族答案记忆：`getVerificationCode` / `startBrowserAwait` 按 `op+url` 记忆，重跑时同步返回上次答案（保证只弹一次窗）。
5. 文档：`book-source.md` §11 把 `ajax/post/getCookie/setContent/cookie.*` 从「明确不支持」移出，写清重放语义与 pass 上限；roadmap §3.7 对应行。

已落地的前置（2026-10-25）：`HttpResponse.url`（跟随重定向后的地址，页面 baseUrl / loginCheckJs 的 url() 都改用它）+ `http.* {response:true}` 返回响应对象（与 loginCheckJs 的 result 同形）。

未做且不在本里程碑：`java.importScript` / `cacheFile` / `downloadFile` / `refreshBookUrl` / Rhino Java 互操作。

## 2026-10-26 — 测试精简第一轮（ADR-0077）已完成：门禁降到 95%，删 plumbing + 合并拆分文件

用户判定「过度测试严重」，裁决：core/domain 覆盖率 100%→95% + 写 ADR，data 保持 80%；优先精简 book_source / 页面 Widget / DI 装配；允许合并同目标多文件、删 plumbing、表驱动、抽 harness。

已完成（门禁全绿：format / analyze 0 issue / 2279 用例 / check_coverage exit 0）：
- ADR-0077 + testing.md §2 阈值表 + §3 表驱动约定 + §8 措辞回链；check_coverage.dart 默认值 95/95/80。
- 数据：237 文件 / 61847 行 / 2371 个 test 调用点 → 234 / 61090 / 2324（-3 文件、-757 行、-47 用例）。覆盖率：core 100%、domain 99.12%、data 95.65%。
- DI/provider 装配测试 990→674 行（platform 370→175、storage 145→110、http 133→118，其余各削一条纯类型断言）。
- 3 组「同目标两文件」按 C-TEST-4 合并：book_source_list_page(+_batch)、book_source_list_notifier(+_view)、reader_page(+_audio)。
- 表驱动合并同构用例：状态灯 2→1、工具栏交接 2→1、登录结果 2→1、平台端口 14→7、DAO 装配 8→4、动态取色 3→1。

踩坑：① 合并同一个页面/Notifier 的两个测试文件时，两个文件各自有私有 helper（`_source`/`_l10n`/`_pump`/`_fixture`），必须先确认签名差异再拼，否则会出现「顶层 group」与重复声明；② 表驱动里第二次 `pump` 同一棵树不会重置 Navigator —— 上一轮 push 过占位路由时要先 `pumpWidget(SizedBox.shrink())`；③ 删掉「只为读 provider 断言类型」的用例后要复查「未测量源文件」判定（clock/web_dav 的 provider 测试因此保留）；④ `dart run build_runner build` 在本地会改写 `storage_provider.g.dart` / `settings_notifier.g.dart` 的 hash（与本轮改动无关，属既存漂移），已 revert，需要单独确认 CI 是否也红。

下一步待定：唯一还能大幅减量的手段是把 rule_engine_test(4854 行/269 例) 与 js 测试(2766 行/113 例) 的 Legado 矩阵改成表驱动（估 -2.5k 行，行为断言不变，但风险与工作量都高）。

## 2026-10-26 — M25 引擎对齐上游：缺口清单、切片与验收（目标从「规则面可用」升级为「行为几乎一致」）

用户裁决（2026-10-26）：引擎目标从「真实语料可用」升级为「与上游 legado 行为几乎一致」，同时要高性能实现，允许重构。缺口清单与状态表落 docs/dev/engine-parity.md（唯一清单），理由与边界见 ADR-0078。

对齐清单（按「不补就静默不生效」排序，证据在 engine-parity.md 表内）：

A 书源级字段
A1 ⚠ jsLib：源内 JS 库，上游作为每个脚本的 prototype scope（BaseSource.kt:335-339、AnalyzeRule.kt:848）；本仓未建模、未执行 —— 依赖库函数的源每条规则 js:error。
A2 ⚠ coverDecodeJs 封面解密（ImageUtils.kt:66-69）。
A3 ⚠ ruleReview 段评（ReviewRule.kt 九个字段）。
A4 ⚠ bookUrlPattern：搜索 URL 命中即按详情页解析 + bookList 为空时回落详情页（BookList.kt:62-84, 100-110）。
A5 ⚠ eventListener / callBackJs / customButton / homepageModules。

B 阶段字段
B1 ⚠ ruleContent.subContent（正文副文 / 音频歌词，BookContent.kt:144-163）。
B2 ⚠ ruleContent.title（正文反取章节名 + reviewImg，:165-190）。
B3 ⚠ ruleContent.payAction（付费解锁，ReadBookViewModel.kt:2623）。
B4 ⚠ ruleContent.callBackJs（事件回调，SourceCallBack.kt:54/94/117）。
B5 ruleToc.formatJs / isVolume / isPay / preUpdateJs（BookChapterList.kt:141-163, 229-268；WebBook.kt:305-313）。
B6 ruleBookInfo.downloadUrls（BookInfo.kt:171-180）/ relatedBooks。
B7 ⚠ 目录去重与章节元数据保留（wordCount/variable/reviewImg，:120-140, :275-295）。

C 规则语法（矩阵剩余 4 条 + 3 处方言）
C1 #20 `:正则`（AnalyzeByRegex + allInOne）。
C2 #21 @xpath: 与裸 `//`（AnalyzeByXPath）。
C3 #22 @webJs 规则级（AppPattern.WebJS_PATTERN、AnalyzeRule.getWebJsResult）。
C4 #30 提取段嵌套规则。
C5 ⚠ 列表规则尾部 @js:：上游任一段是 JS 段即可（AnalyzeRule.kt:439），本仓只认「整条 JS」或 `<js>`（rule_engine.dart:2658、测试 rule_engine_test.dart:3256）→ 与 §3 #14 的「已支持」表述冲突，按行为修正文档。
C6 ⚠ URL 方言：页码列表 `<1,2,3>`（AnalyzeUrl.kt:777）、段链 `@result`（:157-176）、GET query 全量按 charset 编码（:295-300）、`+` 正序前缀（BookList.kt:73-75）。

D JS 绑定面（对 JsExtensions.kt 1220 行 + bindings 表）
D1 ⚠ 密钥类 crypto：createSymmetricCrypto / aes* / des* / HMac*、base64DecodeToByteArray、hexDecodeToByteArray、md5Encode16、hexEncodeToString —— 语料里 326/328 处字节类调用属这一类，是仅次于 jsLib 的硬缺口。
D2 全局绑定：chapter / src / nextChapterUrl / fromBookInfo / infoMap / speakText / gInt+index（formatJs）。
D3 cache.*；source.getKey/getTag/getLoginHeader/putLoginHeader/upLoginData；timeFormatUTC / htmlFormat / t2s / s2t / toNumChapter / refreshBookUrl。
D4 明确不做（沙箱禁忌，维持具名拒绝）：文件/压缩包族、Rhino Java 互操作、importScript/cacheFile/downloadFile。

E 非文本书源
E1 文件型（type=3，downloadUrls）与视频型（type=4）无链路；图片源 imageDecode 仍拒绝、imageStyle 只 single/full。
E2 正文 HTML 化：HtmlFormatter.formatKeepImg（相对 img 补全 + <usehtml> 保真，BookContent.kt:207-216）与阅读端 HTML 渲染缺失。

切片（每片独立过全部门禁，行为测试先行；顺序即依赖顺序）：
S1 jsLib（A1）。S2 阶段字段族 B1-B4 + B5 + B6 + B7。S3 密钥类 crypto 与 D2/D3 绑定。S4 URL 方言 C6。S5 语法 C1/C2/C3/C4（按语料占比定序）。S6 非文本链路与正文 HTML（E1/E2）。S7 文档与拒绝清单收敛（§11 与 engine-parity 同步）。

验收（硬性）：
1. engine-parity.md 每行状态改为「已对齐」，并附真实书源证据（源名 + 四段计数/哈希），格式照 book-source.md §10。
2. 语料普查（tool/spot_check/batch_probe.dart）统计每个缺口字段/语法的出现次数，写进 engine-parity.md；出现次数 >0 且未实现的项必须显式 unsupported 或进「有意的差异」并留触发条件。
3. 文档与代码一致：§3 矩阵状态列、§11 拒绝清单、§2 未建模字段清单三处不得再出现「已支持但不支持」这类矛盾。
4. 差异台账：与上游不同的每一处，要么在 book-source.md §11/§3 注记登记，要么在 engine-parity.md 标「有意的差异 + 触发条件」。

不在本里程碑：RSS/订阅源、朗读规则、上游备份 zip 读取、Rhino 互操作、字典/高亮规则。

## 2026-10-26 — M26 引擎高性能重构：可测指标、允许的重构面与不可动红线

用户裁决（2026-10-26）：性能与行为对齐同属目标，允许重构引擎内核。本里程碑只改「同一行为更快」，不改语义；每个优化必须在 M25 的行为测试全绿下进行，行为变化一律回到 M25。

可测指标（写进 docs/dev/testing.md §2 的同一口径，数值先按下列初值，实测后只准收紧）：
P1 单章正文（≤200KB HTML，规则 3 段）：解析 → 提取 → replaceRegex 全程 ≤ 40 ms（Windows release，不含网络）。
P2 千章目录（1000 条正则/CSS 混合规则）：≤ 300 ms，且与章数近似线性（无 O(n²)）。
P3 规则解析缓存：同一条规则文本在一本书的一次会话内只编译一次（CSS/JSONPath/正则），命中率 ≥ 95%。
P4 HTML DOM 复用：一页只 parse 一次，同一 scope 的多个字段共享 DOM（现在是每次 evaluate 重建）。
P5 JS worker 往返：每个 job 的固定开销 ≤ 3 ms（空脚本基准），`java.getString` 字面量内联路径覆盖 ≥ 90% 的嵌套调用。
P6 内存：解析单章峰值增量 ≤ 8 MB，1000 章目录 ≤ 32 MB（不得一次性把整页/整书读进内存，C-NET-7 不变）。

重构允许面（都是当前实现的可识别热点）：
R1 规则编译期/运行期分离：`_parse` / `_check` 的结果按 (rule text, hasExtraction) 缓存，规则求值只走已编译的步骤表；缓存 key 与生命周期归 PageFetchService 作用域，随书源 reload 失效。
R2 去掉重复 scope 重建：`_pages.field()` 现在每个字段都重新解析页面 body，改为一个 FetchedPage 持有一份 RuleScope（DOM + body + JSON 惰性解析）。
R3 提取管线批量化：同一 rule 在列表条目上逐项求值时，共享选择器编译结果与已解析的条目 DOM。
R4 页内并发：nextTocUrl / nextContentUrl 多值并发抓取（上限沿用 book-source.md §8 的 3，且不得嵌套占用同一源的槽位）。
R5 JS 通道：把「一条规则一个 job」的开销降到固定成本（脚本编译结果按 sourceId+script hash 缓存），保留 5s / 32MB / 20 调用配额不变。
R6 目录/正文缓存的命中路径不得触碰引擎（现状已满足，重构不得回退）。

不可动（红线照旧）：C-SRC-*（含 C-SRC-4 禁止静默忽略、C-SRC-8 rulePath 可定位）、ParseResult 契约、无 dynamic/print/!、presentation 不 import data、JS 白名单与配额数值、书源并发上限与限速合成顺序、生成物不手改。

验收：P1-P6 的基准脚本落在 tool/bench/（不进 CI，与 tool/spot_check 同模式，README 写复现方法）；重构 PR 必须附前后数字；内存指标用 integration_test 的设备级用例抽一次真机数据。行为对齐测试与性能基准不得互相让步 —— 做不到就登记为「已知热点」而不是放宽行为。

## 2026-10-26 — M27 语料全量回归与差异台账：口径、出口判据与两条新增门禁

目的：把「行为几乎一致」变成可复核的数字，而不是逐条目测。M25 交付能力、M26 交付速度，本里程碑交付**证据**。

语料与口径：
1. 语料分层两档，都写清来源与抓取日期（不进仓库大文件）：L1 = 128 条公开合集（`4dc410d1.json` 一档，历史普查用过的同一份）；L2 = 全量合集（3907 条一档）。只对 L1 要求逐源跑通，对 L2 只要求普查与显式拒绝，避免把「站点挂了」算成引擎缺陷。
2. 普查（静态、不联网）：`tool/spot_check/batch_probe.dart --list=` 统计每个缺口字段/语法/`java.*` 成员的出现次数与涉及源数，产出 docs/dev/engine-parity.md 的「语料命中」列。这张表决定 S5（#20/#21/#22/#30）的排序，取代拍脑袋。
3. 链路（联网、可复现）：L1 里能跑的源按 book-source.md §10 的格式记录「语法/字段 + 书源 + 四段结果 + 哈希」；失败必须落到归因（网络 / 站点改版 / 未实现能力），不允许只写「失败」。
4. 差异台账：与上游行为不同的每一处，三选一 —— ① 修掉；② 登记为「有意的差异 + 触发条件」（book-source.md §3/§4/§6/§11 的注记）；③ 登记为「已知热点」（性能，归 M26）。未登记差异视为缺陷。
5. 出口判据（M27 完成）：engine-parity.md 无「未对齐」行；L1 逐源归因表完整；book-source.md §3 矩阵状态列、§11 拒绝清单、§2 未建模字段清单与代码逐条一致（用一次 grep 复核：文档声称支持的名字必须能在 lib/ 找到实现，反之亦然）。

新增门禁（只加不删）：
G1 一条单测/工具用例：把 book-source.md §11 的拒绝名单与 `quickjs_worker.dart` 的 `__javaRejectedNames` 对照，两边不一致即失败（防文档漂移，ADR-0012）。
G2 一条单测：矩阵「已确认」行的语法各有 ≥1 条用例（现存已满足，改为按表驱动查漏）。
G3 基准脚本冒烟（tool/bench，不进 CI）：P1/P2 的数字写进 engine-parity.md，PR 里可对照。

不在本里程碑：为对齐而引入上游 Android 专属行为（WebView 特有 JS、Rhino 类型系统）；这些以「有意的差异」登记。

## 2026-10-26 — M24 落地：同步 java.* 重放层（ADR-0076）+ 每源变量表 v12 + toast 端口

用户裁决全量做完切片 1–4（不做「只做一片」），三个落地前的岔口也一并定了：每源变量落 **Drift 新表** `source_variables`（不放 book_sources payload，导出保真不动）、`java.toast` 落 **core 端口 `UserMessages` + 装配根 snack bar**、本轮范围含文档。

落地形态（行为面归 book-source.md §6，为什么归 ADR-0076 §实现注记）：
- worker 内 `JsSyncCache` + `while` 重放循环；同步调用未命中 → 记 `{op,url,body,key}` + 回失败信封 → `evaluate` 取页 → 写缓存（**失败也缓存**）→ 从第一行重跑。哨兵走状态，规则 try/catch 吞掉也不影响正确性。
- 桥侧新绑定 `sync`（ajax/post/head/getCookie/cookie.*）、`toast`；`HttpClient` 新增 `head`；`parse.*` 带上 `java.setContent` 的覆盖正文。
- 验证族不改成同步，只按 `op+url` 记忆答案（形态仍是 Promise，`await` 一个缓存值无差别）。
- 预算口径：同步取页期间暂停硬预算、等掉的时间从 elapsedMs 扣、**每趟重置每规则调用额度**；pass 上限 16 → `js:replay`。
- schema v12（dump + generated_migrations + migration_test v11→v12 + on_disk 真实写入）。

踩坑（值得记住的六条）：
1. **`sendMessage` 的每个绑定都必须在 worker 的 `runtime.onMessage` 注册过**，否则它根本到不了桥：`toast` 第一次就漏了，真引擎探针才发现（`_serveToast` 从没被调用）。
2. `Uri.tryParse` 对任意字符串几乎不返回 null（`'not a url'`、`'%'`、`'http://'` 都能解析），所以「畸形 URL」分支是死代码——Cookie 动词改成直接 `Uri.parse`，宗里没域就答空。
3. `_job()` 这类测试助手不传 `sourceVariables` 时，job 的快照是空的：真引擎探针里「写进去读不回来」不是实现错了，是测试没喂快照（生产链由 `RuleEngine._runScript` 下发）。
4. 首参是**字面量**的 `java.getString` 由引擎在 job 之前内联（ADR-0037 §决策 3①），所以「先 setContent 再写字面量规则」看不到覆盖——探针必须把选择器写成变量才会走运行时通道。
5. 桥现在 watch `cookieManagerProvider`（同步族要 Cookie 宗），于是任何读真实 `ruleEngineProvider` 的用例都会拉出数据库；`search_results_notifier_test` 用 `cookieStoreProvider.overrideWithValue(FakeCookieStore())` 挡住（新增 test/support/fake_cookie_store.dart）。
6. `lib/core/storage/source_variables.dart` 要进 `tool/coverage_allowlist.txt`（drift 表定义是生成期输入）；同批加的 `core/platform/user_messages.dart` 其实**被测量**，登记会让门禁以「stale entry」失败——豁免表只登记真正未测量的文件。

验证：format 0、analyze 0 issue、2346 用例全过、check_coverage exit 0（core 99.36 / domain 99.03 / data 95.65）、build_runner 无意外漂移（`settings_notifier.g.dart` 的 hash 漂移是 #34 记过的既存问题，已 revert）。设备级：`integration_test/js_bridge_test.dart` 42 例与 `on_disk_database_test.dart` 6 例在 **Windows 与 Android 模拟器**双端全绿（新增 7 条真引擎探针：重放、响应对象、pass 上限、Cookie、每源变量、toast、setContent）。

## 2026-10-26 — M25/S1 jsLib 落地：字段 + 解析缓存 + 同一作用域执行 + 失败归因（ADR-0078）

用户裁决（2026-10-26）：继续 M25，然后修提交问题。本轮做切片 **S1（jsLib）**，并顺手确认了「提交问题」的真实成因。

**S1 落地形态**（行为面 → `book-source.md` §6；为什么 → ADR-0078 §实现注记；台账 → `engine-parity.md` A1 改「已对齐」）：
- `BookSource.jsLib`（进 payload 往返 + 进指纹，库变即行为变）；`JsSourceInfo.jsLib` 只做**宿主侧载体**，`toJson` 仍只发 name/url/group；所有阶段经 `source.jsSourceInfo` 一处自动拿到，不必逐 usecase 透传。
- `core/js/js_lib.dart` 的 `JsLibStore`：纯 JS 直通；JSON 对象只下载 `http(s)` 值、按对象序拼接、非 URL 值忽略；缓存按 `jsLib` 原文、上限 16（对齐上游 `LruCache`）、单飞、**失败不缓存**（瞬断可重试）；无 HTTP 端口时 URL 形态报 `unsupportedRule` 而不是「当没有库」。
- 沙箱：worker 前奏新增 `__runRuleWithLib(lib, rule)` = 同一函数作用域里两次 `eval`，库的 `var`/`function` 对规则可见且不漏到 globalThis（上游靠 `preventExtensions`）。`_evaluationSource` 按 job 是否有 lib 二选一。
- 归因：下载失败 → `ParseFailure(…, '<field>:js:lib')`；库自身抛错 → worker 信封带 `libError`，桥折成同一个 `js:lib`；规则自己的错仍是 `js:error`。引擎在解析失败时**不造 job**。

**三个坑**：
1. fake worker 的约定是「脚本不是 `fail`/`runaway`/`hold` 就自动回显」，所以桥侧新用例必须写 `script: 'hold'` 才会等到自己发的信封——否则测试在 `evaluate` 那一刻就成功了。
2. worker 的**结果信封只搬了 ok/value/error 三个字段**，JS 侧新增的 `libError` 在 `_decodeEnvelope` 之后被丢掉了 → `js:lib` 从来没出现过。凡是「JS 前奏产出、桥要读」的标记，都必须同时加进 worker 的 `_toBridge.send`。
3. `let`/`const` 在**第二次** eval 里看不到第一次 eval 的声明（两次 eval 的 let/const 各属自己的词法环境）；上游 Rhino 是 ES5 本来也不认，已登记为有意差异。

**「提交问题」的真实成因（顺手修掉一半）**：工作树里除了上一轮未提交的 ADR-0077（测试精简）与 ADR-0078（台账）之外，还有 **4 个文件丢了 why-注释**（MainActivity.kt、in_app_web_view_page_fetcher.dart、in_app_webview_cookie_bridge.dart、long_running_task.dart）——MainActivity 的文档注释还被弄成语病（`still has no foreground service of its own / the only foreground service in the app is` 断句）。功能无变化，判定为更早某次自动化清理的误伤，已 `git checkout --` 还原。提交整理见下一步（按主题拆 Conventional Commits，提交后再跑 `build_runner` + `git diff --exit-code`）。

验证：format 0 / analyze 0 issue / 全量 `flutter test` 2346+ 全过（新增 store 11 例、实体 3 例、指纹 1 例、引擎 2 例、桥 2 例）；真引擎探针 46 例在 **Windows 与 Android 模拟器**双端全绿（新增 4 条 jsLib 探针，含「库里 java.ajax 触发整条重放」与「上一个 job 的库不泄漏」）。

## 2026-10-26 — 提交整理：误删注释、生成物 hash 漂移与四片混合工作树的拆分

用户裁决（2026-10-26）：按切片拆 4 个提交（含台账 hunk 拆分），留在当前分支 `feat/ui-m15-m18`。

**「提交的问题」查清了三件事，都已修**：
1. **4 个文件被误删注释**（`MainActivity.kt`、`in_app_web_view_page_fetcher.dart`、`in_app_webview_cookie_bridge.dart`、`long_running_task.dart`）：只删了 why-注释、功能未变，MainActivity 的文档注释还被弄成语病（`still has no foreground service of its own / the only foreground service in the app is` 断句）。判定为更早某次自动化清理的误伤 → `git checkout --` 还原。
2. **`settings_notifier.g.dart` 的 hash 漂移让最后一道门禁永远红**：`build_runner build` 每次都会改写 `_$settingsHash`，而源文件没动 —— 于是 `git diff --exit-code -- '**/*.g.dart'` 在干净树上也必定非空，只能每次手 revert。根因是生成器版本变了、committed 输出没跟上；提交锁定版本的输出后，`build_runner build` 变成 no-op（实测 `wrote 0 outputs`），门禁在 HEAD 上真的绿了。
3. **工作树里混了四块工作**（ADR-0077 测试精简 / ADR-0078 台账 / M24 重放 / M25-S1 jsLib）→ 拆成 4 + 1 个提交。

**最终提交序列**（都在 `feat/ui-m15-m18`，工作树已干净）：
- `test: trim the suite to behaviour and lower the coverage gate (ADR-0077)`
- `docs(adr): register the engine-parity ledger and the M25-M27 goals (ADR-0078)`
- `feat: replay upstream's sync java.* dialect and persist per-source variables (M24, ADR-0076)`
- `feat: run a source's own jsLib before every rule (M25 S1, ADR-0078)`
- `chore: adopt the generator output for the settings provider hash`

**拆提交时踩的两个坑（下次别再踩）**：
1. **`git commit` 不带 `-a` 只提交 index**：我用 `git checkout <snapshot> -- .` 把最终态灌进 index 后，又在**工作树**里做切片剥离，结果第一个 M24 提交把 S1 的代码与文档一起带了进去，而两个新文件（`js_lib.dart` / `js_lib_test.dart`）被 reset 掉 → 那个中间提交**编译不过**。发现后 `git reset --mixed` 回退、把剥离脚本写成文件重跑、并**改用 `git add -A` 后再 reset 掉属于下一片的两个新文件**，这次核对过 `git show :<path>` 的 index 内容才提交。
2. **用 `grep -c "已对齐（M25/S1）"` 判断台账状态会假阴性**：markdown 里是 `**已对齐**（M25/S1）`，`**` 夹在词与全角括号之间。核对提交内容要看 `git show <sha>:<file>` 的实际行，而不是关键词计数。

验证（HEAD 上六条门禁全过）：format 0 changed / analyze 0 issue / `flutter test` 2365 用例全过 / `check_coverage` exit 0（core 99.38、domain 98.95、data 95.65）/ `build_runner build` 后 `git diff --exit-code -- '**/*.g.dart' '**/*.freezed.dart'` exit 0 / 真引擎探针 46 例在 Windows 上全绿（Android 侧在提交前同内容已跑过 46 例全绿）。

## 2026-10-26 — M25/S2 第一半落地：目录字段族（formatJs/isVolume/isPay/wordCount/preUpdateJs）+ bookUrlPattern（ADR-0078）

用户裁决（2026-10-26）：继续 S2。本轮交付 **S2 第一半**（目录字段族 + `bookUrlPattern` + 目录去重/元数据），并如实登记第二半。

**落地**（行为面 → `book-source.md` §4.1 / §4.1b；为什么 → ADR-0078 §实现注记；台账 → `engine-parity.md` 3.1–3.3）：
- `TocRule` += `formatJs` / `isVolume` / `isPay` / `wordCount` / `preUpdateJs`；`ContentRule` += `subContent` / `title` / `payAction` / `callBackJs`；`BookSource` += `bookUrlPattern` / `eventListener`；`Chapter` += `isPay` / `isVolume` / `wordCount` / `variable` / `reviewImg`（freezed + fingerprint 无需改）。
- `formatJs` 是**一个 job 跑 N 章**：worker 前奏新增 `__formatTitles(lib, script, chapters)`，同一函数作用域里 `for` + `eval`，`index`/`chapter`/`title` 每轮重绑、`gInt` 跨章累积，某章抛错回 `null` 保留原标题。
- `preUpdateJs` 在 `walk` **之前**跑，失败即失败且不发请求。
- 卷条目无 URL 用 `title + index` 占位；**名字读不出来的条目整条丢弃**（上游 `if (title.isNotEmpty)`）。
- 去重按 `(名字, URL)` 保序。
- `bookUrlPattern` 全匹配最终响应地址 → 用 `ruleBookInfo` 读成一条结果（复用 `FetchBookInfo.readFromPage`）；无 pattern 且列表为空（或列表规则一条未命中）也回落详情页。

**两条行为变化（都是对齐上游，但影响下游，特意记下）**：
1. 「搜索页一条都没命中」不再是 `parseFailed`，而是回落详情页 → 仍无书则**空结果**。书源校验因此补了 `emptyRulePath`：空结果仍判「搜索失效」，但 `rulePath` 指回**列表规则**（`searchRule.bookList` / `exploreRule.bookList` / `tocRule.chapterList` / `contentRule.content`），不再指阶段入口。
2. 名字为空的章节不再保留（旧行为来自 ADR-0026 的「字段降级保留」口径）。ADR-0026 管的是**字段**能否降级，上游的 `title.isNotEmpty` 管的是**条目**是否存在 —— 两者不冲突，已在 `book-source.md` §4.1 写清。

**登记为「S2 剩余」/有意差异（不假装支持）**：
- `subContent` / `title`：**已建模、未执行**。执行需要 `FetchContent` 返回 `ChapterContent`（正文 + 副文 + 改名 + reviewImg + 音频歌词），属第二半；音频歌词（`engine-parity` E 行）随之。
- `payAction` / `callBackJs` / `eventListener`：已建模、不执行 —— 需要付费解锁 UI 与读者事件面，标「有意差异 + 触发条件」。

**踩的坑**：
1. `formatJs` 的 `gInt` 不能靠「每章一个 job」实现——上游只在循环前初始化一次。这条直接决定了「一条脚本一个 job」的设计。
2. `tag.i.1@text` 这类写法在本仓不是「第 n 个 tag.i」，测试里要改用 `class.xxx@text`，否则读不到值却看不出原因。
3. `bookUrlPattern` 的「全匹配」必须显式加 `^(?:...)$`：Kotlin `String.matches` 是全匹配，Dart `hasMatch` 是包含匹配，直接照抄会把不该命中的 URL 当详情页。

验证：format 0 / analyze 0 issue / `flutter test` 2377 用例全过 / check_coverage exit 0 / `build_runner build` 后生成物无漂移；真引擎探针 **49 例** 在 Windows 与 Android 模拟器双端全绿（新增 3 条 formatJs 探针）。

## 2026-10-26 — M25/S2 第二半（S2 闭环）：subContent / title 执行 + ChapterContent 返回形状（ADR-0078）

用户裁决（2026-10-26）：开始 S2 第二半。已交付：`subContent` / `title` 执行 + `ChapterContent` 返回形状。**S2 至此闭环**（两半合计），剩余是有意差异与「阅读端采用」。

**落地**（行为面 → `book-source.md` §4.1「副文与正文页标题」；为什么 → ADR-0078 §实现注记；台账 → `engine-parity.md` 3.1 / §6 / §7）：
- `FetchContent.execute` 现在答 `ChapterContent{body, title, reviewImg, lyric}`；阅读器端口仍是 `String`，装配根取 `.body`。
- 顺序照抄上游 `content → subContent → title → replaceRegex`：副文先进正文，替换规则才看得到它；`title` 读**第一页** scope。
- `subContent`：文本源追加（`\n` 分隔），音频源只作 `lyric`；值是 `http(s)` 时先取那一页**正文原文**（新增 `PageFetchService.plainBody`，走同一 fetchRule：预算/header/登录拦截都在），取不到只记 warning、正文照常。
- `title`：非空即改名；值里**最后一个** media URL 作 `reviewImg`；只剩一张图时标题回落目录名。
- 缓存按整个结果存，但**只带额外信息时才换形状**：纯正文仍写纯文本（零迁移），否则写一行带 `v:2` 的 JSON；读不懂按正文处理。

**登记的差距（不假装支持）**：
- 阅读器**尚未采用**正文页改名与歌词（端口只取正文）→ 台账标「解析已对齐；阅读端采用归后续」。
- `payAction` / `callBackJs` / `eventListener`：需要付费解锁 UI 与读者事件面 → 有意差异 + 触发条件。
- 一处**有意的小差异**：标题里残留的 HTML 标签被剔掉（上游会把 `<div id=…>` 或半截 `<img src="` 当标题）。

**踩的坑（三条，都是「照抄上游会得到错值」）**：
1. 上游 `imgRegex` 在 `@html` 取值下会把外层标签当标题：真正的实现要按「最后一个 media URL」切分**再剔标签**，还要处理切分点落在标签中间（`… 开端<img src="`）。
2. Dart 里写这条正则要小心引号：`'[^\s"'<>]'` 会被单引号截断，`r"…"` 也会被双引号截断 —— 只能用转义 `'(?:data|https?):[^\\s"\'<>]+'`。
3. 副文页失败不能判章失败（正文仍可读），但副文为**空串**时要给 `null` 而不是 `''`，否则调用方会以为「有歌词但是空的」。

验证：format 0 / analyze 0 issue / `flutter test` **2385 用例全过**（新增 `fetch_content_test` 9 例）、check_coverage 与生成物门禁随后一起验。

## 2026-10-26 — M25/S3a 落地：密钥类 crypto 与字节族（pointycastle + 句柄）

用户裁决（2026-10-26）：S3 拆两半，本轮做 **S3a（D1 密钥类 crypto + 字节族）**，并同意新增 `pointycastle`。S3b（D2/D3 绑注入面）留下一轮。

**落地**（行为面 → `book-source.md` §6「字节与密钥族」/ §11；为什么 → ADR-0078 §实现注记 S3a；台账 → `engine-parity.md` §5 D1 / §7）：
- `byte[]` = JS `Uint8Array`（不是句柄）：语料是 `Array.from(bytes).slice(8,-16)` 与 `bytes.length`，句柄会让这两种写法失效；`flutter_qjs_next` 原生支持 `Uint8List ↔ Uint8Array`，过桥是一次 memcpy。
- `createSymmetricCrypto` = 不透明句柄 `{__symmetric: true, id}`，沿用 `JsFontRegistry` 的契约（每 job 清表、id 不复用），九个方法（`encrypt*` / `decrypt*` / `setIv`）与 `SymmetricCryptoAndroid` 一一对应。
- `core/js/js_crypto.dart`：hex/base64 宽容编解码、`md5Encode16` / `digestHex` / `digestBase64Str` / `HMacHex` / `HMacBase64`、AES / DES / DESede × ECB / CBC × PKCS5-PKCS7 / NoPadding、transformation 与密钥规范化照抄上游（无 `/` 补 ECB/PKCS5、DES >8 截 8、DESede >24 截 24、key 缺省随机）。**单 DES 用 `DESede(K1=K2=K3)`** 兑现（pointycastle 4 只带三倍引擎），与 `openssl enc -des-cbc` 逐字节相同。
- worker：`crypto` 通道一个解码器（老的四个 `crypto.*` 动词与新族共用），字节族载荷是**对象**而非 JSON 字符串；`__javaRejectedNames` 去掉 10 个已实现名字，加上 `createAsymmetricCrypto` / `createSign`（仍拒绝，保持 §11 与代码一致）。
- `charset_text.dart` 新增 `charsetText`（未知标签/坏字节退 UTF-8 容错），供 `java.bytesToStr` 用。

**有意差异（已登记，不假装对齐）**：`aesEncodeToString` 上游实现是 `decryptStr`（历史 bug）→ 本仓按名字的意图加密；`base64DecodeToByteArray(str, flags)` 收 `flags` 但不按位分支；CFB/OFB/CTR/GCM、非对称、签名仍具名拒绝（触发条件：真实语料出现且有可复现源）。

**踩的坑（三条）**：
1. `PaddedBlockCipherImpl.init` 在 pointycastle 4 要 `PaddedBlockCipherParameters(underlying, padding)`，不是裸 `CipherParameters`；ECB 要 `KeyParameter`、CBC 要 `ParametersWithIV`，两者不能混。
2. `HMacHex(data, algorithm, key)` 的 `algorithm` 是 **Java 的 Mac 名**（`HmacSHA256` / `HMAC-SHA1`），前缀不去掉就会答「unsupported digest algorithm」——真实语料（西瓜小说）正是这么写的。
3. `createSymmetricCrypto(transformation, key, iv)` 的 `key`/`iv` 允许字符串（UTF-8 字节）**和**字节数组：第一版只认字节，语料里的 `"D2o4XyQeIFobJ4tS"` 直接被判成 `expected bytes`。

**语料数字（2026-10-26 手工静态普查，M27 用 `batch_probe.dart` 重算）**：本地 `corpus_a`(504 条) 29 源 / 85 处，`corpus_b`(128 条) 4 源 / 6 处；`createSymmetricCrypto` 32 处、`hexDecodeToString` 16 处、`aesBase64DecodeToString` 9 处、`base64DecodeToByteArray` 9 处、`hexDecodeToByteArray` 8 处、`HMacBase64` / `digestHex` 各 3 处。

验证：format 0 / analyze 0 issue / `flutter test` 2434 例全过 / check_coverage exit 0（core 99.19、domain 98.67、data 95.65；`js_crypto.dart` 与 `charset_encoding.dart` 行覆盖 100%）/ `build_runner` 后生成物无漂移 / `dart run tool/scan_licenses.dart` 202 包 Risky none（新增 1 个 MIT 包）/ 真引擎探针 56 例（新增 7 条）在 **Windows 与 Android 模拟器**双端全绿。

## 2026-10-26 — 工作树收敛到唯一的 dev checkout，并新增集成分支 dev（ADR-0079）

用户指令（2026-10-26）：整理工作树、重订开发标准 —— 任何开发代码都提交到 `dev` 工作树；删除本地多余 worktree，统一在 dev worktree 开发。裁决三点：① 新建 `dev` 分支指向当时 HEAD（不重命名 `feat/ui-m15-m18`，避免断开已有 PR）；② `legado-p5` 的 137 处未提交改动先备份再删；③ 本会话目录无法自删，用 `git worktree move`/改名把它变成 `legado-p5-dev`。

**为什么必须做**（ADR-0079 §背景，三条实证）：① 提交位置歧义——同一功能在 3 个 checkout 各有版本，`legado-p5` 积了 106 改动 + 31 未跟踪文件，与集成分支版本不同、既没提交也没人清理；② 分支语义错位——远端没有集成分支，`ci.yml` 的 push 门禁只听 `main`，于是实际在 `feat/ui-m15-m18` 上跑的集成提交**从来没被 L1 门禁验证过**；③ 每个 worktree 各有 `.dart_tool`/`build`/Gradle 缓存，`pub get` 与 `build_runner` 争用同一 pub cache。

**落地**：
- 规则唯一出处 = `CONTRIBUTING.md` §4.1：单一 dev 工作树（`<父目录>/legado-p5-dev`，check out `dev`）+ 三条硬规则（唯一长命 checkout、所有提交落 `dev`、并行用短命分支或临时 clone）；`main` 只收 `dev` 的 PR。
- `AGENTS.md` §3 新增第 0 步「定位」，只回链 §4.1 不抄正文（仍是 98 行 ≤120）。
- `.github/workflows/ci.yml` 的 `push.branches` 加 `dev`（L1 门禁跟着集成分支跑）；发布通道 `release.yml`（tag）/`beta.yml`（手动）/`debug.yml`（main push）不动。
- `CHANGELOG.md` Unreleased 记一条（为什么改、改了什么）。
- 手工手术：主克隆 `legado-with-flutter`（`main`）改名为 `legado-p5-dev` 并切 `dev`；删 `legado-p5-audio`（干净）、`legado-p5`（先归档为仓库外 patch + 未跟踪文件 zip）；本会话所在的 `legado-p5-mgmt` 先搬成临时 worktree 再删除，最后 `git worktree list` 只剩一条。

**踩的坑（值得记）**：
1. **主 worktree 不能 `git worktree remove`**：`F:/Projetcs/legado-with-flutter` 是 `.git` 所在的主克隆，`worktree remove` 直接拒绝。要「只剩一个 checkout」只能让**主克隆本身**变成 dev 工作树——先删掉全部 linked worktree 再重命名目录（`.git/config` 里没有绝对路径，重命名安全），否则 linked worktree 的 `.git` 文件会指向旧路径。
2. **dev 分支同一时刻只能被一个 worktree 占用**：主克隆要切 `dev`，得先让临时 worktree `switch --detach` 释放它，顺序错了会报 "already checked out"。
3. **远端没有 worktree**：用户说的「整理远端 worktree」实际只能落到「统一分支」上；远端只保留 `main`/`dev` 两条长命线，`feat/*` 转只读。
4. **CI 触发分支漏改就是假绿**：集成分支换了名字/新增了 `dev` 而 `ci.yml` 只监听 `main`，push 门禁等于不存在——这次一并加上。

验证：`git worktree list` 只剩 `F:/Projetcs/legado-p5-dev [dev]`；四个分支里 `dev` 已推到远端；`legado-p5` 的未提交快照落在 `F:/Projetcs/_archive/`（patch + zip）。

## 2026-10-27 — M25/S3b 第二组落地：source.* 簇与登录头（v13 列 + 请求头合并 + Cookie 合并）

用户裁决（2026-10-26）：本轮只做 S3b 的 source.* 簇；登录头存 book_sources 新列 loginHeader（v13，与 v11 的 loginInfo 同构）；规则内 source.login() 具名拒绝并登记差异。全局绑定与平台族（chapter/src/nextChapterUrl/fromBookInfo/infoMap/speakText、androidId/openUrl/connect/ajaxAll）留下一段。

落地形态（行为面归 book-source.md §2/§6/§11，为什么归 ADR-0078 §实现注记 S3b 第二组，台账归 engine-parity.md §5 D）：
- source.getKey()/getTag() = bookSourceUrl/bookSourceName；两者本就在 source 字段里，纯读取不过通道。
- 登录头按 **URL** 读写（上游 CacheManager 键是 loginHeader_<url>）：测 「最新一条有值的行」、写「该 URL 的所有行」，两条同 URL 的导入因此共享同一个登录头。
- 桥在发 job 前把快照塞进信封（{'type':'evaluate','job':…,'loginHeader':…}），所以每个 job 都看得到它、构造点一个都不用改；结果信封里带 loginHeader 键才算「写过」→ 当即写穿 store。
- PageFetchService.headersOf 把登录头合并 **在源 header 之上**（上游 getHeaderMap(hasLoginHeader=true) 同序），@js: 规则的 http.* 走同一份 map；合并粒度是「每个阶段取 header 表时」。
- putLoginHeader 里的 Cookie 并进 Cookie 宗（新 CookieManager.mergeCookieHeader）：_CookieInterceptor 会用宗里的值盖掉请求头的 Cookie，只存头不并宗会在「宗里还有别的 cookie」时丢掉登录 cookie。
- source.removeLoginHeader() 不绑定（上游没标 @JavascriptInterface，本仓无登出入口）；规则内 source.login() 具名拒绝（重入同一 worker 会死锁，登录页的 SignIn 跑同一段 loginUrl 脚本）。

踩坑（值得记的四条）：
1. 迁移步骤必须两头判：drift 的 migrateAndValidate 以「目标版本」为参数把库跑到中间版本，`if (from < 13)` 会把新列加进 v11/v12 的库，比对 schema 时「多出一列」直接失败。改成 `from < 13 && to >= 13`，并把迁移测试的目标版本统一到最新（createTable 用的是当前表定义，from-scratch 路径必然带最新列）。
2. 新增 store 被 pageFetchServiceProvider/jsBridgeProvider watch，于是任何读真实 provider 的 widget 测试都会拉出数据库（drift_flutter → path_provider 需要 binding）：test/support/offline_corpus.dart 的五个 pump helper 与 search_results_notifier_test 各加一条 sourceLoginHeaderStoreProvider.overrideWithValue(SourceLoginHeaderStore())。
3. 后台 isolate 读不到库也读不到资产，登录头只能靠「快照下发 + 结果回传」，与每源变量同一条契约；但它**不能**等 job 结束才落库（登录脚本写完立刻取页），所以写回挂在结果信封上而不是 job 生命周期上。
4. 设备级探针里日志的 error message 是脱敏的（error=<String: N chars, sha256=…>），断言「错误可读」只能看形状（rulePath = field:js:error）+ 日志前缀，不能 contains 脚本抛出的那句话。

验证：format 0；analyze 0 issue；flutter test 2530 例全过；check_coverage exit 0（core 98.89 / domain 98.66 / data 95.68）；build_runner 后生成物无漂移（190 个 g.dart 无变化，仅新增 provider/表列相关）；真引擎探针 65 例在 Windows 与 Android 模拟器双端全绿（新增 4 条：getKey/getTag、无值答 null、写入跨 job 并合并 Cookie、source.login() 落 js:error）；integration_test/on_disk_database_test.dart 6 例在 Windows 全绿。

## 2026-10-27 — M25/S3b 第三组落地：全局绑定 D2 + 平台族（S3b 收尾）

用户裁决（2026-10-26）：S3b 收尾，**两块都做**（D2 全局绑定 + 平台族）；`java.openUrl` 引 url_launcher 并自己做确认弹窗；`infoMap` 一并实现；`speakText`/`speakSpeed` 不做（见下）。

落地形态（行为面归 book-source.md §6/§11，为什么归 ADR-0078 §实现注记 S3b 第三组，台账归 engine-parity.md §5 D）：
- **阶段绑定**住在 JsPageContext：`src`（这一页的正文，`_pageOf` 填）、`chapter`（JsChapterInfo，正文阶段由目录给）、`nextChapterUrl`（目录里紧邻的下一条）、`fromBookInfo`（详情阶段置 true）。新增 `forPage` 让整份上下文随翻页传播，`walk` 改调 fetch(context:) 后第 2 页与第 1 页看到的东西一致。
- **`infoMap`** 是 per-source 的内存 store（LRU 32 源）：桥塞快照进信封，worker 在 job 结束后**再求值一次**读回 `JSON.stringify(infoMap)`（规则可能 await 或抛错，两条路径都要带回），桥合并。`save()`/`saveNow()` 是空操作（没有 Cache 表；值本来就在会话里）。
- **`connect` 吞失败、`ajaxAll` 不吞**（上游 runCatching vs mapAsync 的现成语义）；二者走重放层，ajaxAll 的缓存键带整张地址表；`skipRateLimit` 收下但不绕过单源预算。
- **`androidId`** 是首启生成、写进轻量开关的 v4 UUID，`main()` 在 runApp 之前 hydrate（与 Cookie 宗同一时点）；桥把值补进 job 载荷。
- **`openUrl`** 走新端口 `ExternalUrlOpener` + 装配根确认弹窗（appNavigatorKey 拿 context），最后一步才用 `url_launcher`（BSD-3，新依赖）；地址超过 64 K 拒绝（上游同一道门）。
- **`speakText`/`speakSpeed` 不绑定**：只由上游 HttpTTS 源表提供，本仓只有系统 TTS → 有意差异，触发 = 引入 HttpTTS 朗读引擎；规则里读到它们是 ReferenceError，而不是一个恒为空的假值。

踩坑（值得记的四条）：
1. `PreferenceStore` 是 final class，测试没法 implements；`InstallId` 因此改成吃小端口 `InstallIdStore`（`PreferenceInstallIdStore` 是唯一生产实现），既能测「写失败也只留 warning」，也让 core/platform 不直接 import core/storage。
2. `sendMessage('openUrl', …)` 必须在 worker 的 `runtime.onMessage` 注册过（M24 已经踩过一次）：这次与 toast 同一形状（`_notify` 单向转发）。
3. 读 `infoMap` 不能靠规则作用域回传（Promise / 抛错两条路径会漏），用**独立的第二次求值**读 `JSON.stringify(infoMap)`，代价是一次极小的 eval。
4. 设备级探针里断言「错误可读」只能看形状：日志 message 是脱敏的（`error=<String: N chars, sha256=…>`），所以断言 rulePath 形状而不是错误文本（上一轮已记过一次，这轮又验证了一遍）。

验证：format 0；analyze 0 issue；flutter test 2565 例全过；check_coverage exit 0；build_runner 无漂移；`dart run tool/scan_licenses.dart` 210 包 Risky none（新增 url_launcher BSD-3）；真引擎探针 70 例在 Windows 与 Android 模拟器双端全绿（新增 5 条）；`on_disk_database_test` 未受影响。

## 2026-10-27 — M25/S4 落地：URL 方言五条 + 列表尾部 @js:

用户裁决（2026-10-26）：S4 一轮做完，不拆半片。

落地形态（行为面归 book-source.md §3 #7/#14 与 §4.3，为什么归 ADR-0078 §实现注记 S4，台账归 engine-parity.md §4 C5/C6）：
- **URL 规则是链**（上游 `analyzeJs`）：`renderUrl` 先跑 `_expandUrlSegments`（字面段替换当前值、先把 `@result` 换成它；脚本收当前值作 `result`、返回值成为新值），再走 `{{…}}`，最后页码列表。顺带补齐「整条规则就是一个 `@js:`」的 URL——此前它会被当字面地址发出去。body 不做这一步（上游只对地址跑 analyzeJs）。
- **页码列表** `<1,2,3>`：按请求页码取第 n 个、超出取末项（`page < size` 的上游判据）；页码来自 `JsPageContext.page`。
- **GET query 全量编码**：声明 `charset` 时整条 query 按该编码转义，安全集**照抄两处**（判「已编码」用 `NetworkUtils.notNeedEncodingQuery`，真编码用 `AnalyzeUrl.encodeQueryParams`），空格因此是 `%20`；`escape` 方言未建模并登记。
- **`+` 前缀**：先剥 `-` 再剥 `+`，两者都只是标记（`-+rule` 仍倒序）。
- **列表尾部 `@js:`**：列表规则「任一段是 JS 段」即走段链解释器；脚本看到条目内容（`outerHtml`），不是 jsoup 元素（既有口径）。

踩坑（两条）：
1. **嵌套柜口必须显式**：第一版只放开顶层，`parse.getElements('class.count@js:result')` 直接无限递归（段链里的脚本再起 job，fake bridge 把 parse 请求重放给同一段链）→ 生产里是队列自锁，测试里是整文件 6 分钟挂死。现在嵌套的 `@js:` 仍报 `unsupported:@js:list`，并带字段前缀（与 `js:parse-scope` / `js:parse-recursion` 同形）。
2. **`@js:` 贪婪吞到行尾**：想在脚本后再写字面段只能用 `<js>…</js>`；写测试时先按「拼接」理解会立刻失败——字面段是**替换**，只在 `@result` 处保留旧值。

验证：format 0；analyze 0 issue；flutter test 2584 例全过；check_coverage exit 0；build_runner 无漂移；新增 17 例单测（url_template 9 / rule_engine 6 / page_fetch 2）+ 1 条改写（尾部 `@js:` 从「拒绝」改为「跑段链」）。S4 不需要新的沙箱绑定，真引擎探针仍是 70 例，未重跑双端（无绑定面变化）。

## 2026-10-27 — M25/S7 门禁部分落地：G1 名单对照 + G2 矩阵行覆盖

用户裁决（2026-10-26）：S4 之后先做 S7 的两条文档门禁，防后续切片把文档写成「声称支持但已不支持」。

落地形态：
- **G1**：§11 的两个拒绝名单改成机器可读的 ```text 块（一行一个名字），`test/docs/book_source_doc_test.dart` 读**同一份文本**并与 `quickjs_worker.dart` 前置脚本里的 `__javaRejectedNames` / `__javaInteropNames` 数组字面量逐字对照。故意不导出成 Dart 常量：门禁要看见的是 worker 实际执行的那段文本。
- **G2**：解析 §3 的矩阵表（按**未转义**的 `|` 切列——示例里就有 `\|\|`），取出状态以「已确认」开头的行号，再扫 `test/**/*_test.dart` 找 `matrix #N`，缺一行即红。
- `testing.md` §3 记成「测试镜像 lib/」的**唯一例外**（文档漂移门禁没有 lib 对应物）。

踩坑（两条）：
1. G1 一上来就抓到真漂移：文档写 Rhino 互操作 4 个包（lang/security/util/net），代码拒 8 个（还有 io/nio/math/text）。按代码补全文档——这正是门禁要防的那类「状态变了文档没跟」。
2. G2 第一次跑出 10 行没有 `matrix #N` 标记（#2/#5/#8/#10/#11/#23/#24/#25/#27/#29）。用例其实都在，只是名字里没写行号；补齐方式是在覆盖它们的 group/test 上写一行注释，而不是重命名 10 个用例（门禁要的是「能指到用例」，注释紧贴那条用例就够，重命名只会让 blame 更难读）。
3. 注释里写 `matrix #5 / #8` 只算覆盖 #5：正则只吃第一个编号，所以每个编号都要单独成文。

验证：format 0；analyze 0 issue；flutter test 2587 例全过（新增 3）；G3（基准脚本冒烟）留给 M26/M27。

## 2026-10-27 — M25 语料普查（334 源）与由此定下的 S5/S6 排序

用户提供真实语料（2026-10-27）：`C:\Users\xiaol\Downloads\Mobile Devices\bookSource (1).json`（255 条，用户称「大部分可用」）与同目录 `bookSource.json`（291 条）。两份合并按 `bookSourceUrl` 去重后 **334 个源**：type0 文本 280 / type2 图片 35 / type1 音频 7 / type3 文件 7 / type4 视频 5。之前 DECISIONS #35/#37 提到的 corpus_a/corpus_b 已不在磁盘上，这份是新的基线。

工具：新增 `tool/spot_check/corpus_census.dart`（静态、不联网、`dart run` 即可，口径见 `tool/spot_check/README.md` §8）。`java.*` 的「已实现」名单**从 `quickjs_worker.dart` 前奏读**（surface 键 + `__javaRejectedNames`），因此工具不会自己漂移；`source.*` 与全局变量名单手写。产物是 `engine-parity.md` 的新 §9（普查表）+ 各行的「语料命中」列。

数据结论（决定排序）：
- **最大语法缺口是裸 `//`（XPath 省略标志）：43 源 / 155 处**；`@xpath:` 带标志 0 处（语料都写裸 `//`）。→ S5b（需依赖 + ADR）。
- **matrix #30 嵌套提取段：22 源 / 125 处**（`class.a@css:.b` 这类）。→ S5c。
- **`source` 对象的字段与别名：约 30 源**（`source.key` 14、`bookSourceUrl` 10、`bookSourceComment` 5、`put/get` 4/3、`getLoginHeaderMap`/`removeLoginHeader`/`putLoginInfo(Map)`/`removeLoginInfo` 2/2/3/1）。→ **S5a，改动最小、收益最高**。
- **Rhino 互操作：`java.lang` 13 源、`java.util` 10、`java.io` 4、`java.security` 3、`java.net` 1**；真实写法是 `new Packages.java.lang.String(bytes,'UTF-8')`、`java.util.UUID.randomUUID()`、`java.util.Arrays.copyOfRange(raw,0,16)`、`new java.util.HashMap()`（给 `java.upLoginData`）——多数有一行等价替代。→ S5d 需 ADR 裁「最小 shim」vs 维持拒绝。
- **`imageStyle` 不是缺口**：49 源声明，取值只有 `FULL` 26 / `0` 20 / `full` 2 / `Full` 1，`left`/`right` 命中 0；本仓 full/single/默认已覆盖。
- **`downloadUrls` 11 源（type3 共 7 个文件源）** → S6b；`imageDecode` 2 源、`coverDecodeJs` 1 源 → S6c（要「返回字节的 job」+ 落盘 + 阅读端从字节渲染）。
- **语料命中 0、可明确「不做」**：`ruleReview` / `eventListener` / `customButton` / `homepageModules` / `@webJs` / `imageStyle` 的 left/right。
- 反向验证：`connect` 9 源、`putLoginHeader` 6 源、`jsLib` 19 源、`bookUrlPattern` 52 源——S1/S2/S3b 的选点都被语料证实。
- 其余动作类成员（`refreshExplore` 4 / `upLoginData` 3 / `searchBook` 2 / `refreshTocUrl` 2 / `getStrResponse`/`initUrl`/`url`/`headerMap`/`open` 各 1、`readTxtFile` 1、`cache.getFile|putFile` 1）已逐条登记去向（多为「不做 + 触发条件」）。

新顺序：**S5a（source 对象/别名）→ S5b（XPath 43 源）→ S5c（#30 22 源）→ S5d（Rhino shim，先 ADR）→ S5e（`:正则` 2 源）→ S6b（文件源）→ S6c（图片字节）**。S5/S6 的旧排序已被 §9.4 取代。

复跑命令（新对话可直接用）：`dart run tool/spot_check/corpus_census.dart --source="C:/Users/xiaol/Downloads/Mobile Devices/bookSource (1).json" --source="C:/Users/xiaol/Downloads/Mobile Devices/bookSource.json"`。

## 2026-10-27 — M25/S5a 落地：source 对象补全 + 变量形状改正 + 登录族收口

用户裁决（三问全选「推荐」）：① getVariable/setVariable/putVariable 改成上游无参整份形状；② putLoginInfo/removeLoginInfo 按 URL 写穿；③ removeLoginHeader 连 Cookie 一起清。

落地：
- `JsSourceInfo` 白名单 +6 字段（key / bookSourceUrl / bookSourceName / bookSourceComment / header / loginUrl），comment 从 `extra` 读原文，header 规则形态原文、JSON 形态重新序列化。
- 前奏新增 `__javaMap`（普通对象 + 不可枚举 get/put/remove/containsKey/size/isEmpty），`getLoginHeaderMap`/`getLoginInfoMap` 都走它（语料 9 源写 `.get("账号")`）。
- `source.put(k,v)` 答回值、`source.get(k)` 未写过答空串；整份变量落 `source_variables` 的**空名条目**（无迁移、无第二个 store）。
- `source.removeLoginHeader()` = 删头 + `CookieManager.removeCookiesFor(url)`（内存/持久双实现）。
- `source.putLoginInfo(json)`/`removeLoginInfo()`：worker 槽位（job 内立即可见）+ 结果回传 + `SourceLoginInfoWriter`（core 端口）→ `book_sources.login_info`（新 DAO `writeLoginInfoByUrl`，按 URL）。只收字符串，解析不出答 false。
- 语料证据：无参 getVariable 54 处 / setVariable 41 处（本仓键值形状命中 0）；put/get 4/3 源；getLoginHeaderMap 2 源；removeLoginHeader 2 源；putLoginInfo 3 处。

门禁：format 0 / analyze 0 / 2621 例全过 / coverage exit 0（core 98.93、domain 98.54、data 95.68）/ build_runner 无漂移。docs/book-source.md §6+§11、engine-parity.md §5/§7/§9.3/§9.4 已同步（并把重复的 §9 语料曝光改成 §10）。

遗留：`integration_test/js_bridge_test.dart` 新增 6 条真引擎探针**未在设备上跑**（用户要求最后手动统一跑），前奏（__javaMap、新 source 方法）尚未经过真实 QuickJS 验证。

## 2026-10-27 — M25/S5b 落地：XPath 自研子集（无依赖，ADR-0080）

用户裁决：自研 XPath 子集（不自带 fork xpath_selector）。

选型事实（推翻了计划里的「新依赖」）：
- pub 上没有 Dart 3 可用的 XPath 包：`xpath_selector` 3.0.2 + `xpath_selector_html_parser` 3.0.1 + `expressions` 0.2.5 的 SDK 全是 `>=2.12.0 <3.0.0`（最后一次发布 2023-01）；更致命的是 html 适配器 `HtmlNodeTree.children` 只暴露元素子节点，`text()`（语料 131 处里 61 处）必须改 fork 才成立。
- 语料真实数字复核：**21 源 / 131 处 / 94 条表达式**（普查里的 43/155 把 `@js:` 里的 `//` 注释、`jsLib` 注释与 searchUrl 之类的相对 URL 也算进去了）。

落地：
- 新文件 `lib/features/book_source/domain/rule_engine/xpath_rule.dart`（自研解析器 + 求值器）：路径（`/` `//` `.` `..` `@attr`）、节点测试（标签 / `*` / `text()`）、八个轴（child/descendant/descendant-or-self/self/parent/following-sibling/preceding-sibling/attribute）、谓词（`[N]`、`[@a='v']`、`contains()`、`not()`、`starts-with()`、`position()`、`last()` 及算术、存在性路径、and/or）、`|` 并集（节点集合、文档顺序去重）。
- 语义三条：`//` 编成 `descendant-or-self::node()`+`child::test`（位置=同父第 N 个）；结果按**文档顺序**；元素值=折叠空白文本，`text()` 只答直接文本子节点。
- 触发面：只认 `//` 与 `@xpath:`（上游连单个 `/` 都算 XPath，本仓不跟——否则 `coverUrl: /static/x.jpg` 这类根相对地址会被静默当成表达式）。
- 具名拒绝（`unsupported:xpath:<语法>`）：ancestor/ancestor-or-self/following/preceding/namespace 轴、node()/comment()、`@*`、count()/normalize-space()/concat() 等函数。列表规则选中文本 → parseFailed；对着 JsonScope 跑 → parseFailed。
- engine：`_deferredFlags` 去掉 '//' 与 '@xpath:'；`_readBranch` 先认 XPath（整条分支=表达式，不切 `@`）；新增 `_XPathBranch` + `_xpathElements` / `_xpathMatches`；`_mergesTwoScopes` 把 XPath 当 DOM 分支。

测试：新增 `xpath_rule_test.dart` 25 例（语料 94 条表达式的代表形状逐条断言 + 拒绝面）；`rule_engine_test.dart` 新增 `matrix #21` 组 10 例。原本拿 `@xpath://div` 当「未实现标志」样本的 ~20 处用例改成 `@webJs` / `@webJs:`（含 usecases 与两个页面测试）。全量 2656 例全过；format 0 / analyze 0 / coverage exit 0（core 98.93、domain 97.26、data 95.68）。

文档：新 ADR-0080 + adr/README 索引；book-source.md §3 矩阵 #21 改「已确认」+ 新增 XPath 注记（支持面/三条语义/拒绝面）、§11 改成「XPath 未实现子集」具名列表、§10 拒绝测试行、两处旧「不支持 @xpath:」表述；engine-parity.md §4 #21 行、§9.2（43/155 → 21/131 并说明口径）、§9.4 S5b ✅。

遗留：设备级探针未跑（用户要求最后统一手动跑）；S5b 不涉及前奏，真引擎风险低。

## 2026-10-27 — M25/S5c 取消：matrix #30 语料命中归零，普查探测器已修（并更正 #51 的数字口径）

用户裁决：修普查工具 + 把 matrix #30 登记为「有意差异 + 触发」，直接进 S5d。

发现（S5c 复核）：
- `corpus_census.dart` 的 #30 探测器是 `text.split('@').skip(1)`：不管括号/引号/模板/脚本体，于是把三类**已支持**的写法算成「嵌套提取段」：① 整条规则以 `@css:`/`@json:` 开头又含后续 `@`（117 条）、② `{{@css:…@text}}` 模板里的内联规则、③ `+@css:` / `-@css:` 正倒序前缀。
- 修法：位置敏感的四个探测器（裸 `//`、#30、`:正则`、`+` 前缀）改跑 `_ruleHeadOf(text)`（剔掉 `@js:` 脚本与 `{{…}}` 模板），段切分改成括号/引号感知的顶层 `@`，且首段只剩 `+`/`-`/`@@` 时不算「有第二段」。工具耗时从超时降到 1.6 s（旧的按字符 substring 是 O(n²)）。
- 复跑（334 源）：**嵌套提取段 = 0 源 / 0 处** → matrix #30 维持拒绝，登记为有意差异（触发 = 出现依赖它的真实源），S5c 不进切片。

同时更正 DECISIONS #51 里的一个说法：
- 我当时把「裸 `//` 43 源 / 155 处」当成误报、改写成 21/131，这是错的。按字段拆开：**四段规则字段 100 处 / 21 源 + URL 字段 31 处（coverUrl 15、bookUrl 5、nextTocUrl/nextContentUrl/tocUrl 各 3、chapterUrl 2）+ bookSourceComment 里的脚本注释 24 处**。三者都是本仓会求值的文本，43/155 是对的。engine-parity §4/§9.2 与 ADR-0080 背景段已按字段拆开更正。
- 真正是误报的是 #30 的 22/125。

文档：book-source.md §3 矩阵 #30 改「有意差异（触发）」+ 新增 #30 复核注记、§3.1 M2 范围表；engine-parity.md §4 #30 行、§7 S5 行、§9.2/§9.4（S5c 取消、S5e 不再与 #30 同批）；tool/spot_check/README.md §8 增「位置敏感探测器先剔掉非规则文本」的口径说明；tool 的 `_knownSource` 补齐 S5a 的 17 个成员（之前会把 `source.key` 等继续报成缺口）。

门禁：dart format 0 / flutter analyze 0 / test/docs 3 例全过（文档门禁 G1/G2 未受影响）。

## 2026-10-27 — M25/S5d 落地：Rhino 互操作最小垫片（白名单 12 类成员，ADR-0081）

用户裁决：实现 shim（不维持全量拒绝）。

语料复核（334 源）：**19 源**用 `Packages.*`；其中 **6 源只需白名单**（七猫四合一、阅文、长佩、海棠、书旗、Hi歌曲），**13 源另需** `javax.crypto`（Cipher/SecretKeySpec/IvParameterSpec/Mac，多在 `new JavaImporter()` + `with()` 里）、`java.io` 流、`java.net.URL`、`okhttp3`、`org.jsoup`、`BitmapFactory`。

落地（`quickjs_worker.dart` 前奏，约 200 行 JS）：
- 白名单：`java.lang.String`（`new String(bytes,charset)` 解码 / `String(x).getBytes(charset)` 编码）、`java.lang.System.currentTimeMillis`、`java.lang.Thread.sleep`（**空操作**）、`java.util.UUID.randomUUID`、`java.util.Arrays.copyOfRange/copyOf/toString`、`java.util.HashMap`/`LinkedHashMap`（复用 `__javaMap`）、`java.util.ArrayList`（数组 + 不可枚举 `add`/`size`）、`android.util.Base64`、`android.text.TextUtils.isEmpty`、`cn.hutool.crypto.digest.DigestUtil.md5/md5Hex`、`cn.hutool.core.codec.Base64`、`io.legado.app.help.http.StrResponse`。
- 脚本侧小工具：`__bytesOfHex` / `__bytesToBase64` / `__base64ToBytes`（不给一次编码加一趟宿主往返）。
- 每个包节点都是 Proxy：白名单外的名字抛 `Packages.<到第一个未知段的路径> is not supported`；`JavaImporter` 抛具名错误（原来那 13 源报的是 `JavaImporter is not defined`）。
- `java.*` 的 8 个包名（lang/util/io/security/net/nio/math/text）**不变**，仍全部抛错：本仓 `java` 是扩展面、不是包（上游同样取不到 `java.lang.*`），§11 门禁 G1 的名单与含义不动。

验证：
- **Node `vm` 一次性校验**（桩 sendMessage 出 strToBytes/bytesToStr/md5/randomUUID）：白名单成员 + 两条具名拒绝逐条通过；抓出两个真 bug（`new` 只认对象返回值 → 解码须返回装箱 String；根节点路径拼出 `Packages..javax`）。
- 设备探针新增 6 条（`integration_test/js_bridge_test.dart` 的 `Rhino interop shim (M25/S5d)` 组）：编解码往返、Base64 往返、hutool+TextUtils、UUID/ArrayList/Arrays/HashMap/System、StrResponse 形状、未知成员与 JavaImporter 落 `js:error`。**尚未在设备上跑**（用户统一手动跑）。

文档：新 ADR-0081 + adr/README 索引；`book-source.md` §6 新增「`Packages.*` 最小垫片」三条边界（只做数据/编码/集合、`javax.crypto` 等不做、`java` 不是包）、§11 的 8 包名块后补「S5d 之后的口径」；`engine-parity.md` §5 拆出 Rhino 互操作行（部分对齐 + 19/6/13）、§9.3 行、§9.4 表。

门禁：dart format 0 / analyze 0 / 全量 2656 例过 / docs 门禁 3 例过（本轮 prelude 属 allowlist，覆盖率不受影响）。

## 2026-10-27 — M25/S5e 落地：`:正则` 列表规则（正则链 + $N 条目模板），M25 引擎切片收口

语料：2 源 / 2 处，都在目录列表（若夏 `:(?s)(\d+)" class="(isvip)?[^"]*name[^>]*>([^<]*)`；快眼小说 `:正文卷[\s\S]*?/dl&&href ="([^"]+)">([^<]+)`）。

上游语义（`AnalyzeByRegex.kt` + `AnalyzeRule.kt:393/430`）：
- 只有 `getElements` / `getElement` 有 `Mode.Regex`；`getString`/`getStringList` 没有（落到 `else -> rule`，等于答规则原文）→ 本仓在**值规则位置**具名拒绝 `unsupported::`。
- `&&` 在正则规则里是**正则链**（`rule.splitNotBlank("&&")`），除最后一条外把文本缩到自己的匹配段再交给下一条——所以必须在切候选/分支之前识别 `:`。
- 一次匹配 = 一个条目，条目内容是**全部组** `[整段, 组1, …]`；条目字段用 `$1`/`$2`/`$0` 模板取组值（上游 `SourceRule.splitRegex` 拆 `\$\d{1,2}`、`makeUpRule` 填回），可带 `##正则##替换`。

落地：
- `rule_scope.dart`：新增 `RegexScope(groups, jsContext)`（三处 switch 补全）。
- `rule_engine.dart`：`_deferredFlags` 去掉 `':'`；`_parse` 在切候选前认出 `:` 前缀并编译 `&&` 链（坏正则 → `parseFailed`）；`_ParsedRule.regexes`；`_RegexBranch`；`_check` 在值规则位置拒 `unsupported::`；`_matches` → `_regexScopes`（页面正文来自 `DomScope.body`，元素 scope 用 outerHTML，JSON 值 → `parseFailed`）；`_evaluate` 对 `RegexScope` 走 `_evaluateRegexItem`（`$N` 模板 + `##` 替换，非模板规则 → `unsupported:regex:item`）。
- 测试：`rule_engine_test.dart` 新增 `matrix #20` 组 9 例（语料两条原样、模板/URL 模板/带替换、正则链、值规则位拒绝、非模板条目拒绝、坏正则、JSON scope）；`_unsupportedRules` 里删掉 `:regex`（它现在是支持的）。

文档：book-source.md §3 矩阵 #20 改「已确认」+ 新增 `:正则` 注记（三条语义）、§11 的 `:` 行改为「只在值规则位置拒绝」；engine-parity.md §4 #20 行、§9.2 行、§9.4 表、§7 的 S5 行（S5a/S5b/S5d/S5e 已交付、S5c 登记不做、只剩 #22 @webJs 语料 0 源）。

门禁：dart format 0 / analyze 0 / 全量 2665 例过 / coverage exit 0（core 98.93、domain 97.10、data 95.68）。

M25 引擎对齐切片至此全部收口（S1–S4、S5a、S5b、S5d、S5e 已交付；S5c 复核取消；S5d 的设备探针与 S5a/S5b 的探针一起等手动跑；S6b/S6c 归 M25 之后的文件型/图片字节链路）。

## 2026-10-27 — 正文获取两处缺陷修复：多匹配合并 + HTML 转纯文本（PO18 / 免费小说）

用户报障（2026-10-27）：PO18 系正文页显示大量 HTML 片段；免费小说正文只有一行字。语料 `bookSource (1).json`。

根因两条（都在正文章节边界，与具体站点无关）：

1. **`PageFetchService.content` 只取第一条匹配。** 它用 `extractFirst`，而上游 `getString` 是
   `getStringList` 用换行拼接。语料里 `content: "#content p@textNodes"`（免费小说，`#77` 与普通版各一条）
   是「一段一个 `<p>`」，取第一条就只剩一行。→ 改用 `extractJoined`（同一入口，缓存的仍是成品正文）。
2. **`@html` / `@all` 的正文从来没有转成纯文本。** 阅读端 `readerBodyText` 按换行分段、纯文本渲染；
   语料 249 条 `content` 规则里 **83 条**以 `@html`/`@all` 结尾（PO18 系 `id.booktxt@html`、
   `#nr@html`、顶点小说网 `class.font_max@html` 等），所以页面把 `<p>`/`<br>` 原样印出来。
   上游保留 HTML 并由自己的富文本视图渲染——这是本仓**有意差异**（engine-parity §3.1 已登记）。

修复：
- 新文件 `lib/features/book_source/domain/html_to_text.dart`：**扫描器**（不建 DOM，正文已为跑规则解析过一次）
  → 块级标签（p/div/br/li/tr/td/h1-6/pre/table…）变换行、行内标签剥掉、`<script>`/`<style>` 内容整段丢弃、
  注释/doctype 丢弃、实体解码（`&nbsp;` `&amp;` `&hellip;` `&#32;` `&#x4E2D;`，未知实体原样留）、
  `1 < 2` 这种字面小于号不当标签、带引号属性里的 `>` 不截断、空行与缩进折叠、图片丢弃。
  纯文本输入走快路径原样返回。
- `FetchContent._finish`：先 `htmlToText(text)`，**再**跑 `replaceRegex` 与净化规则（这些规则是作者对着
  能读的正文写的：`&nbsp;`、`\<.*` 之类清理 HTML 残留），成品再 `.trim()`（`replaceRegex` 删掉整段会
  留下那一段的换行）。
- 测试：`html_to_text_test.dart` 10 例（纯文本快路径、段落/换行、行内标签、script/style、注释、实体、
  缩进折叠、字面 `<`、属性里的 `>`、图片）；`fetch_content_test.dart` 新增 3 例（多 `<p>` 全部保留、
  `@html` 出纯文本且不含 `<`、转换先于 `replaceRegex`）。

文档：book-source.md §4.1 的 `content` 行 + 新增「正文的统一形状」四条注记；engine-parity §3.1 把
「正文 HTML 化」改成「HTML → 纯文本（有意差异，83/249 条规则受影响）」。

门禁：format 0 / analyze 0 / 全量 **2678** 例过 / coverage exit 0（core 98.93、domain 97.07、data 95.68）。

## 2026-10-27 — M26-R7 日志改造第一阶段：取消脱敏 + 落文件（按天/7 天/20 MB）+ 运行时级别 + Dart 侧崩溃栈

用户裁决四项：① release 也不脱敏（开源软件，脱敏过度设计）；② 按天轮转、保留 7 天 / 总 20 MB；③ 崩溃只做 Dart 侧；④ 搜索关键词原样记录。

落地（ADR-0082）：
- **删掉脱敏**：`core/logging/redaction.dart` 与其 12 条测试整份删除；8 个文件的 `redactUrl`/`redactMessage` 调用改为原样插值；`describeError` 移到 `error_text.dart` 并返回 `<类型: 原文>`（`FormatException` 不重复类型前缀）。保留的纪律是「请求头与正文不交给日志」（C-SEC-4 已改措辞）。
- **落文件**：`core/logging/log_file.dart` —— 目录 `getApplicationSupportDirectory()/logs`（三平台同规则），`app-YYYY-MM-DD.log` 按天切；`prune()` 先删 7 天以前，再最旧优先删到 ≤ 20 MB（当天永远保留）；追加写串行排队（`flush()`）、崩溃行 `appendSync`；写失败只丢那一行。
- **运行时级别**：`AppLogger.setLevel` + 门面自判级别（`logger` 侧 `Level.all`）；`AppSettings.logLevel`（`settings.logLevel`）持久化；设置页新增「诊断」区的等级下拉，改完立即生效。
- **崩溃栈**：`core/logging/crash_handlers.dart` 接 `FlutterError.onError` / `PlatformDispatcher.onError` / `Isolate.current.addErrorListener`，记录以 `CRASH` 开头、带完整栈、同步落盘，之后仍转发原 handler。原生崩溃不做（登记）。
- **装配**：`main()` 首帧前建 `LogFile` + `prune()` + 覆盖 `logFileProvider` + 装崩溃处理器 + 把设置里的级别套上门面，并写一行 `app start`（平台 / 日志路径 / 级别）。
- **管理页**：`LogFilesPage`（文件名、大小、合计、清空、复制目录路径）；`settingsLogLevel` 等 16 条 l10n（中英各一份、已 gen）。

测试：`log_file_test.dart` 12 例（按天切 / appendSync / 7 天 / 20 MB / 清空 / 忽略无关文件 / 排队写 / 运行时级别 / off）；`app_logger_test.dart`、`http_client_test.dart` 改为断言原文。

门禁：format 0 / analyze 0 / **2657 例全过** / coverage exit 0（core 98.10、domain 97.08、data 95.69）。

**未做（本里程碑后续）**：
1. 详情页「多源自由切换」：搜索结果里同名书的多条命中（`SearchBook.origins`）应直接作为换源候选，当前 `ChangeBookSourceSheet` 只按书名重新搜索。
2. 搜索期内存/闪退：目前只能靠新日志文件定位；计划加「每次搜索的计数与 RSS 采样」+ 去掉可疑的累积点，再用真机日志确认。

## 2026-10-28 — M26-R1 基准基线落地：tool/bench + compileStats + 阈值维持初值

M26 的第一步（R1 前置）落地：`tool/bench/bench.dart`（P1/P2/P3，`flutter run -d windows --release`，选项走 `BENCH_ARGS`，夹具确定性生成）+ `tool/bench/README.md`（口径、复现、P4/P5/P6 的接法）；数字写进 `engine-parity.md` §11（G3 要求）与 ADR-0078 实现注记。

改前基线（Windows 11 / release / 单章 199.7 KB / 目录 1000 章，复跑两次 p50 差异 ≤1.2%）：P1 p50 6.31 ms（解析 2.60 + 提取 3.59 + replaceRegex 0.10）、P2 千章 CSS 形态 p50 17.76 ms、P2 正则形态 10.71 ms、线性度 250→2000 章每章 16.6→18.6 µs、P3 命中率 0.0%（lookups 600 = compilations 600）。

四处值得记住的判断：
1. **P3 必须先有观测点才可测**：命中率不能从耗时反推，所以 `RuleEngine` 加只读 `compileStats`，计数落在 `_parseForEvaluation` 接缝（R1 的缓存就插在这里）。生产代码只写不读，消费方是 bench + 一条单测；单测钉的是「改前 lookups == compilations」，R1 落地时这条必须改成 ≥95% 命中。
2. **阈值维持初值，验收用前后差值**（用户裁决 2026-10-28）：实测已比 ADR 初值好 5–17 倍（6.31 vs 40、17.76 vs 300），过线没有信息量；收紧阈值会让换机/负载变成误报，所以 M26 只看「同一命令的改前/改后差值」。ADR-0078 决策 4 的「只准收紧」仍然有效，只是本轮不动。
3. **R2/R3 的靶子由读数定**：P1 里「提取」占 57%（3.59/6.31，比 HTML 解析还贵），P2 里 1000 条条目字段占 69%（12.19/17.76）。这两块对应「共享 RuleScope」与「条目批量提取」，不是猜的。
4. **两个基准自身的坑**：`Stopwatch.reset()` 只清零不重新 start，第一版把每个阶段的第二次及以后测量都记成 0.00 ms（看起来像「提取免费」）；夹具命中校验不能用 `assert`——`--release` 会丢掉它，基准就会在「规则其实没命中」时报出好数字（改用 `_verify` + StateError）。

P4/P5/P6 仍未测：P4 需要一个「一页 parse 几次」计数器（与 R2 同批做），P5 要在真 worker 上跑空脚本 job（桥已就位），P6 按决策 4 走 `integration_test` 设备级用例。

门禁：format 0 / analyze 0 / flutter test 全过 / coverage exit 0 / build_runner 无生成物漂移。

## 2026-10-28 — 修掉 HEAD 上在 Windows 必红的日志页用例（路径分隔符）

开工 M26-R1 时 `flutter test` 在 HEAD 上就有 1 例红：`test/features/settings/presentation/pages/log_files_page_test.dart` 的 `page_givenOneFile_sharesEveryFileOnDisk`（find.text('app-2026-10-27.log') 找不到）。用 `git stash` 撇开本轮改动复跑确认是**既有缺陷**，不是 R1 引入的。

根因：`LogFilesPage._nameOf` 用 `file.path.split(Platform.pathSeparator).last` 取文件名，而用例的夹具路径是 POSIX 写法 `/tmp/logs/app-2026-10-27.log`——Windows 上 `Platform.pathSeparator` 是 `\`，切不开，于是标题显示整条路径。`File.path` 不会归一化调用方给的字符串，所以这不是「测试写错了」而是页面只能处理「本机分隔符写法的路径」：一旦路径来自夹具、导入或分享回程（含 `/`），页面上就会显示全路径。

修法：`_nameOf` 改成 `file.path.split(RegExp(r'[\\/]')).last`（两种分隔符都认），不动用例的断言强度。门禁复跑：format 0 / analyze 0 / **2676 例全过** / coverage exit 0（core 98.05、domain 97.08、data 95.69）/ build_runner 无生成物漂移。

## 2026-10-28 — M26-R1 落地：规则编译缓存，P3 0% → 99.7%，P2 −28%

R1（规则编译缓存）落地，`#36` 的第一张重构面，也是 P3 的靶子。

设计（ADR-0078 实现注记 2026-10-28 R1 有完整理由）：
- **两层缓存、两个键**：拆步骤 `_parse` 只依赖规则文本；编译选择器 `_check` 还依赖 `hasExtraction`（末段是选择器还是提取段）与 `field`（畸形规则的 `rulePath` 就是字段路径，C-SRC-8）。分成两个键，既不把 field 塞进错误信息，也不让列表读法与取值读法互相污染。
- **共享编译产物安全**：选择器步骤、`RegExp` 链、`JsonPath`（包文档明写可复用）、`XPathExpression`（`select` 中间态全是局部变量）都无跨求值状态，与引擎既有的「不改 scope、不改元素」是同一条契约。
- **「随书源 reload 失效」被更强的性质取代**：键不含书源状态 ⇒ 缓存项永远有效、不需要失效钩子；代价只在内存，所以两层都有 LRU 上限（256 / 512，命中时重插入以保持「最久未用先淘汰」）。
- **计数仍是唯一判据**：`lookups` 含两次查找，`compilations` 只在真编译时 +1；P3 = 1 − compilations/lookups，不掺耗时。

改后数字（同机同命令同参数，`build/bench-r1.json`）：
- P3 **0.0% → 99.7%**（lookups 1200 / compilations 4）✅ 达标（≥95%）
- P2 千章目录 CSS 形态 **17.76 → 12.76 ms（−28%）**，其中 1000 条条目字段 12.19 → 7.42 ms（**−39%**）
- P2 正则形态 10.71 → 9.69 ms（−9.5%）；线性度每章 18.6 → 13.7 µs（2000 章）
- P1 6.31 → 6.17 ms（−2.2%），符合预期：一章只求值一次同一条规则，成本在 HTML 解析与多段拼接上
- 结论：P2 剩下的空间在**选择器求值**本身（R3 的批量提取），不在规则解析

顺带踩到并记下的坑（影响所有 `--release` 工具）：Windows 产物里 `exit()` 会卡在 VM 关闭阶段（最小复现：`main` 只做 `ensureInitialized(); exit(0);` 也挂住），所以 `flutter run -d windows --release` 永远等不到断开事件。`tool/bench` 的标准跑法改成 `flutter build windows --release -t tool/bench/bench.dart` + 直接跑产物，脚本收尾自我结束；**退出码不再有含义**，成败看 stdout 与 `--out`。README §2 已写明。

门禁：format 0 / analyze 0 / **2679 例全过**（新增 5 条 `compileStats` 用例）/ coverage exit 0（core 98.05、domain 97.09、data 95.69）/ build_runner 无生成物漂移。

## 2026-10-28 — M26 首次量出 P5/P6：P5 压在阈值上（2.8–3.0 ms），P6 有一个量级余量

按用户裁决「先量 P5/P6 再决定」，这两项第一次有了数字（未做任何优化）。文档：`tool/bench/README.md` §5.3、`engine-parity.md` §11、ADR-0078 实现注记。

做法：
- **P5 的覆盖率需要一个计数器**：`RuleEngine.inlineStats`（`inlinedCalls` 计在 `_inlineLiteralJavaRules` 每次替换上，`bridgedCalls` 计在 `_parseEvaluatorFor` 的 `parse.*` 请求上），覆盖率 = inlined / (inlined+bridged)。与 `compileStats` 同一立场：只写不读，消费方是 bench / spot_check / 两条单测。
- `tool/bench` 加 `--only=p5`（真 worker 空脚本往返 + 两种写法的内联计数）与 `--only=p6`（RSS 前后差，单章 / 千章目录）。
- `tool/spot_check` 现在每次运行结束打印 `rules:` / `nested:` 两行——语料侧的 P3 命中率与 P5 内联覆盖率就在 M27 的 L1 回归里顺手取得，不用额外工具。

实测（Windows release，P5 复跑两次 n=10 / n=20）：
- **P5 job 往返 p50 2.83–3.03 ms、p95 3.17–3.62**（目标 ≤3 ms）⇒ **压在阈值上**，是六项里唯一没有余量的。
- P5 内联覆盖：字面量写法（语料主流）**1/1 = 100%**；带变量写法 0/1（设计如此，内联前提就是字面量首参）⇒ 「≥90%」必须在真实源上取，故补了 spot_check 的两行输出。
- **P6 单章 1.06 MB 首次 / 0.88 中位 / 3.13 最大**（目标 8 MB）；**千章目录 1.55 / 0.46 / 7.09 MB**（目标 32 MB）⇒ 一个量级余量。

三点判断：
1. P5 省的不是「解析」而是**一个 job 的固定成本**（isolate 两跳 + 沙箱前奏 + 结果信封 JSON），所以 R5（按 sourceId+脚本 hash 缓存编译结果）只省其中一段 —— **R5 开工前必须先分段量**，否则改完不知道动的是哪一块。
2. P6 的「后续中位」不为 0（0.46–0.88 MB/次）：10 轮 RSS + 没有 GC 钩子只够下「不像大块泄漏」的结论；按决策 4 原文，Android 真机与按轮采样留给 `integration_test`。
3. 工具侧的坑同批记下：bench 的夹具校验用 StateError（`--release` 丢 assert），并挂 `PlatformDispatcher.onError` 在未捕获异常时结束进程——否则 release 下既不退出也不报错。

门禁：format 0 / analyze 0 / **2681 例全过**（新增 2 条 `inlineStats` 用例）/ coverage exit 0（core 98.05、domain 97.09、data 95.69）/ build_runner 无生成物漂移。

## 2026-10-28 — M26 P5 分段：2.87 ms 里 2.8 ms 是「每 job 重跑 52 KB 沙箱前奏」，R5 靶子需修正

P5 分段量完成（`tool/bench` 的 `--only=p5` 多出四段 + 一条机器底座，全是现成接缝，不改生产代码）。结果**改写了 R5 的靶子**。

分段（Windows release，n=10，同一 exe）：
- 裸 `Isolate` echo 往返（消息底座）：**0.04 ms**
- 引擎侧（换成立刻返回的假桥）：**<0.005 ms** —— 内联扫描 / 作业构造 / `jsLib` 解析都可以忽略
- 桥 + worker 空脚本：**2.87 ms**
- + `jsLib`（40 B）：2.93 ms（库本身 ≈ 0）
- + 32 KB 结果信封：3.24 ms（信封 ≈ +0.37 ms）
- + 45 KB 脚本源码：7.05 ms ⇒ 源码 ≈ **94 µs/KB**

结论：固定成本 = **每 job 重新解析的那份沙箱源码**。`quickjs_worker.dart` 的 `_evaluationSource()` 把 `_prelude`（**52 KB / 1438 行**：`java.*` / `crypto` / `cache` / `Packages` / `parse` 全套绑定）拼在规则前面，而沙箱每个 job 都重跑（有意为之：`globalThis` 共享，不重跑会把上一 job 的重绑定漏给下一个）。

两条推论：
1. ADR-0078 决策 3 给 R5 写的「按 `sourceId + 脚本 hash` 缓存脚本编译结果」**收益极小**：真实规则脚本几百字节，按 94 µs/KB 算不到 0.05 ms。R5 的动作应改为「**沙箱源码一次编译 + 每 job 只重置状态与绑定**」。
2. 代价与风险：要把 `_prelude` 里**无状态定义**（`globalThis.__xxx = function…`，绝大多数）与**有状态重建**（`cache` / `java` / `source` / `infoMap` 这些闭包 IIFE）分开，逐条确认哪些 `globalThis.*` 必须每 job 新建。`quickjs_worker.dart` 是 `coverage:ignore-file`，只有 `integration_test/js_bridge_test.dart` 的真引擎探针覆盖它 ⇒ 必须双端实跑设备用例（Windows + Android），主机侧全绿不算数。

工具侧的坑（同批记下）：体积灵敏度的外推会算出「前奏 4.75 ms > 空 job 2.87 ms」这种自相矛盾的数——填充语句与前奏代码形状不同，斜率只能定性、不能外推；打印里已改成只报斜率与性质。

门禁：format 0 / analyze 0 / **2681 例全过** / coverage exit 0（core 98.05、domain 97.09、data 95.69）/ build_runner 无生成物漂移。文档：`tool/bench/README.md` §5.4、`engine-parity.md` §11、ADR-0078 R5 前置注记。

## 2026-10-28 — 日志行格式 + Windows 控制台 AXTree 噪声过滤（ADR-0084）

用户报障两处日志噪声，落地为 ADR-0084（M26 性能工作按用户要求先搁置）。

**1. 文件日志不是一行一条记录。** `logger` 包默认的 `PrettyPrinter` 画 ANSI 盒子（`␛[38;5;12m┌───…`），一条记录五个物理行，文件里全是转义序列；它还**给每条记录补假栈**：`event.stackTrace == null` 时用 `StackTrace.current` 打 5 帧（`methodCount` 默认），于是 `INFO app start` 后面跟着 `#0 AppLogger.info …`。
修法：新增 `core/logging/log_line_printer.dart` 的 `LineLogPrinter` 并成为门面默认打印机。格式 `时间 级别  消息`，级别定宽 5 字符；**不写 ANSI**（同一批行既进控制台又落盘，着色只会破坏 grep）；消息里的换行折成 ` | `（行内空格不动）；异常以 `error=<原文>` 接在同一行；**栈只在真有时打**，作为 `  #0 …` 缩进续行。崩溃的同步落盘按**整条事件**判定（头行带 `CRASH` 时续行一起 `appendSync`），否则崩溃现场只留半条。

**2. Windows 控制台被 `Failed to update ui::AXTree` 刷屏。** 那是 Flutter 引擎无障碍桥的已知缺陷（flutter/flutter#182444，open，`platform-windows`/`a: accessibility`），由 C++ 直接写 stderr，Dart 拿不到。
修法：`windows/runner/ax_log_filter.{h,cpp}` + `main.cpp` 在 `AttachConsole` 后安装过滤器——stderr → 管道 → detached 线程逐行转发回原 stderr（副本 fd）+ `setvbuf` 无缓冲；**只丢包含该子串的行**，其余引擎/插件/Dart 输出一条不动；任一步失败就原样返回（不制造「stderr 指着无读者管道」）；不关无障碍、不碰语义树。

验证：文件日志与 stdout 都是 `2026-10-28 13:04:18.943 INFO  app start: …`；用临时标记实跑证明 stderr 转发与丢行都对（普通行出现、含关键字行消失、进程不挂）；**AXTree 行本身未复现**（上游描述需要挂读屏，本机没有）；五个 Windows 设备级用例文件全绿（`js_bridge` 81 例）。

顺手修掉两条**只在设备上跑**的陈旧断言（主机侧 `flutter test` 跑不到，一直没人发现）：`source.putVariable` 是上游 `void`，拼进字符串是 `undefined` 而非 `''`；`Packages.java.lang.String` 已被 ADR-0081 放行，改成仍被拒的 `Packages.javax.crypto.Cipher`。另修 `test-environment.md` 里不存在的 `-TestFile` 参数名（实际是 `-FileFilter`，按旧文档调用会白等）。

门禁：format 0 / analyze 0 / **2689 例全过** / coverage exit 0（core 98.07、domain 97.09、data 95.69）/ build_runner 无漂移；Windows 原生构建 `/W4 /WX` 干净；设备级：`app_boot` 1、`on_disk_database` 6、`audio_playback` 5、`web_view` 3、`js_bridge` 81 全通过。

## 2026-10-28 — 真实日志取证：7 处未登记语义缺口（M27 取材）

来源：本机 2026-10-28 全量书源校验日志（54 源）+ 同库静态扫（`reader.db` 的 book_sources）+ 引擎探针复现。27/34 条 `Book source check failed` 是网络（`groups=网站失效`），下列只记语义。

已确认并本轮修复：
1. **G1 默认规则里的 `[attr]`**：`_readName` / `_splitDegradedSuffix` 见 `[` 就当索引，`[property$=image]`、`meta[property=…]`、`a[href*="_"]` 全 parseFailed（日志 21 条降级；静态 10 源 / 31 处；上游 `AnalyzeByJSoup.kt:406` 的 `findIndexSet` 解析不出索引就 `break`，整段留给 jsoup 当 CSS；ADR-0032 早已承诺「属性选择器」可退化）。
2. **G2 位置列表 `.N:M`**：上游 `ElementsSingle` 注释明确 `tag.div.-1:10:2` / `!0:3` 是两种筛选方式（`AnalyzeByJSoup.kt:280-288`、`:406`），本仓只实现了 `!N:N` 与 `[N:M]`（日志 23 条；静态 10 源 / 15 处，如 `span.1:2`、`li.4:6`、`p.3:4:5:6:7`）。
3. **G3 JSON 条目裸键**：`$.pic@put:{img:pic}` 的 `pic` 在 JsonScope 上 parseFailed → 520diandu 的 1022 条 `tocRule.chapterUrl` 拒绝 + 511 条降级 + 511 章回落目录页；上游 `AnalyzeRule.kt:331` 对 GSON `LinkedTreeMap` 直接按 key 取值。台账 §4 把「JSON 自动模式」记为「实测无增益」，本日志是反证（应改为「JSON 条目上的裸键」这一条窄口径）。
4. **G5 URL 段链未绑 `key`**：`_expandUrlSegments` → `evaluateJs` 没有 `key`，qushu123 的 `searchUrl …@js: … result.replace('{{key}}', key)` 报 `'key' is not defined`（日志 line 3697），整条搜索废；上游 `AnalyzeUrl.kt:377` 在 `evalJS` 里绑 `key`，ADR-0034 §决策 3 与本仓 `renderUrl` docstring 也都声称支持。
5. **G6 `cookie.removeCookie(url)` 单参**：上游绑定 `CookieStore`（`CookieStore.kt:79` 只有一个参数），八零电子书 `cookie.removeCookie(source.getKey())` 因此 `unsupportedRule`（日志 line 1462）；本仓前奏要求 `(url,key)`，`book-source.md` §6 也跟着写错。
6. **G8 空候选**：`A||##replace` 在 `_candidatesOf` 里产生一个空分支 → parseFailed，把整条规则炸掉；上游对空段直接跳过（`AnalyzeByJSoup.getString` 的 `temp.isNullOrEmpty()`），`##` 替换仍作用于整条规则（`AnalyzeRule.kt:339`）。日志：tiandizw 的 `wordCount` 40 条。
7. 顺带修正台账：`ehp`/`getElements`/`connect` 被记成「已对齐」，与 G6/G9/G10 矛盾。

登记为有意差异（不改行为，补台账行 + 触发条件）：
- **G4** `@put` 值失败仍硬失败（上游 `getString(value)` 给空串）：保留 C-SRC-4 的响亮失败；语料命中 0（除 G3 外）。
- **G7** 列表条目缺 URL 时跳过而非回落当前页（上游 `BookList.kt:282`）：23uswx 的 11 条是推荐块，回落会造 11 本指向分类页的垃圾书；触发 = 出现依赖该回落的单书站。
- **G9** `java.getElements` 只给 outerHtml 字符串（freexiaoshuo 的 `.text()/.attr()` 失败）：要真 DOM 句柄；触发 = 语料命中 ≥3 源。
- **G10** 响应对象没有 `.raw()`（qushu123 的 `connect(...).raw().request().url()`）：等价能力是 `url()`；触发 = 出现只差 `.raw()` 的源。
- **G11** exploreUrl 的空标题占位项 / 传统格式无 `::` 的分隔行（3 源 + qushu123）：只影响布局标签，G11 只修了空 url。
- **G12** 正文分页缺「下一页 == 下一章」：台账已有「提前停止（低）」，mxjtedu 触发 50 页上限。

另记两个非引擎 Bug（本轮不修）：`in_app_web_view_page_fetcher.dart:55` 把 `getUrl()` 的 Future 当字符串（日志 line 3812 可见 `Instance of 'Future<WebUri?>'`）；`explore_notifier.dart:80` 在 provider dispose 后 `ref.read`（日志第 10 行 CRASH）。

## 2026-10-28 — M27 交付：日志取证六项已修 + 两处未登记 Bug

按 #63 的取材实施，全部改动有单测/文档同步，门禁全绿（format / analyze / 2703 tests / coverage 98.05/96.98/95.69 / build_runner 无源码漂移）。

已修（引擎）：
1. **G1 属性选择器**（矩阵 #32）：`_childrenIndexExpression` / `_splitDegradedSuffix` 只在 `[` 后是数字 / `-` / `!` / 空串时当索引；字母 / `_` 整段给 cascadia。并补 **jsoup 方言的不加引号值**：`[property=og:novel:book_name]` 的 `:` / `|` 会被 RFC 9535 的解析器拒绝，`_readCss` 在编译前把这类值包成双引号（`_quoteAttributeValues`，已加引号 / 纯标识符不动）。没有这一步，修复对真实源无效（实测 `tiandizw` 的 5 个字段仍全失败）。
2. **G2 位置列表 `.N:M`**（矩阵 #33）：`_dotIndexList` + 复用 `_readIndices`；变体顺序按写法保留。
3. **G3 JSON 条目裸键**（矩阵 #13 注记）：`_values` 的 DomBranch 改为 `_domValues`，JsonScope + Map + 无选择器 → `map[key]`，值走 `_jsonValues`；列表/标量条目仍 parseFailed。
4. **G5 URL 段链绑 `key`**：`evaluateJs` 增加可选 `key`，`_expandUrlSegments` 传 `params['key']`（上游 `AnalyzeUrl.kt:377`）。
5. **G6 `cookie.removeCookie(url)` 单参**：无 key → `removeCookiesFor`（清整域），带 key 仍是按名删除；文档 §6 与测试同步。
6. **G8 空候选**（矩阵 #10 注记）：`_candidatesOf` 丢掉空候选/空分支，但**整条规则都空时仍报畸形**（`-` / `&&` 保持响亮失败）。`A||##replace` 因此走替换而不是 parseFailed。

顺带修（日志里的非引擎 Bug，原 #63 记为“本轮不修”）：
- `in_app_web_view_page_fetcher.dart` 的 `getUrl()` 是 `Future`，原来直接 `.toString()` → `baseUrl` 变成 `Instance of 'Future<WebUri?>'`（日志 line 3812）；已 await。
- `explore_notifier.dart` 的 `loadCategories` / `openCategory` 在 await 后未查 `ref.mounted` → 真机 CRASH（日志第 10 行）；三处 catch/赋值前补守卫。

登记为有意差异（未改行为，台账已加行 + 触发条件）：G4 put 值失败响亮失败、G7 列表条目缺 URL 跳过、G9 `java.getElements` 无 DOM 句柄、G10 `.raw()`、G11 explore 占位项、G12 正文分页、jsoup `[attr~=regex]` 的正则子串语义（CSS `~=` 是整词 → 3 源仅影响 `kind`）、`tag.li[x]` 比上游更严。

矩阵新增 #32 / #33（G2 文档门禁要求每行有 `matrix #N` 用例，已补）。

## 2026-10-28 — 第二轮日志取证：6 个引擎缺口 + 通知 + 日志节流（M27 续）

第二轮日志（15023 行，254 源）暴露的问题与处置（用户已裁决：Android 前台通知、翻页/非 URL fail-fast、首条 WARN + 窗口聚合、元素句柄做最小子集）。

**日志量来源**（本段约 10400 行）：`Field rule degraded` 4351 / `Rejected rule` 3454 / `JS rule failed` 998 / `Search hit without URL` 287。按源：Dragon isVip 1363（行首 `//` 注释行是作者故意写的“停用”，上游静默）、re0zero isVolume 920（`result.attr` 元素句柄）、fushuw chapterUrl+chapterName 436×2（章列表 JS 返回 `JSON.stringify` 字符串，`$.title` 应解码）、bequ6 kind 300（只读 `##` 规则）、sanjiusk 4 字段×100（行首 `@tag…`）、weilaitianwang 12 条只读 `##`、qidian 2 条只读 `##`、janpn bookUrl JS 自己返回 undefined。

**新确认缺口**：
1. 行首 `@` 未按上游 `RuleAnalyzer.trim()` 修剪（`@tag.td.2@text` / `@href` / `@onclick@js:…`）→ 8 源。
2. 只读 `##pattern##replace###` 字段规则（正文为空）应作用于 scope 内容（页面 body / 条目 outerHtml），本仓 parseFailed → 10+ 源。
3. JS 列表条目是 JSON 字符串时应解码成 JSON scope（上游 `isJson()` = `{…}`/`[…]`）→ fushuw 872 次。
4. 裸 `@js:` 条目字段的 `result` 应是元素（可 `attr`/`text`/`select`），不是 outerHtml 字符串 → 964 次 `not a function`。
5. 正文翻页缺「下一页 == 下一章」：检查阶段没传 nextChapterUrl（上游传目录第 2 章）→ 14 源各跑满 50 页。
6. `option=js` 被忽略、`javascript:`/`undefined` 落到请求层才拒 → 按用户决定在取值处 fail-fast。
7. 日志按条目/章节重复，同一 (源,字段) 刷上千行 → 首条 WARN + 60s 窗口聚合 + suppressed 计数，引擎 Rejected rule 降 debug。
8. 缺上游的校验状态通知（`BookSourceCheckService` 的常驻进度通知 + 完成通知）→ 复用 MainActivity 现有通知权限通道加一个 MethodChannel 端口（无新依赖）。

**不改**：上游检查两条链（搜索+发现）都跑，我们保持；HTTP 重试保持（只对可重试 kind，有上限）；janpn 的 bookUrl JS 自身 bug 不猜。

## 2026-10-28 — M27 第二轮交付：6 个引擎缺口 + 日志节流 + Android 校验通知

对应 #65 的取材，全部落地；门禁全绿（format / analyze / 2729 tests / coverage 98.05·96.60·95.69 / build_runner 无漂移 / `:app:compileDebugKotlin` 通过）。

引擎（`rule_engine.dart`）：
- **行首 `@`**：`_segmentsOf` 先按上游 `RuleAnalyzer.trim()` 剥单个 `@`（`@@` 除外），`_flagOf` 把标志头的 `@` 补回。修复三九小说 4 字段×100、金銀 6 条、阅友 2 条、5 个单条源。
- **只读 `##` 字段规则**：body 为空且 `replacementParts>1` 时对 `_replacementContentOf(scope)`（页面 body / 条目 outerHtml / JSON 文本）应用替换；模式不命中给空串。修复千寻、未来天王、肉文屋、破万卷等 10+ 源的 bookUrl/coverUrl/bookInfo 字段。
- **JSON 字符串条目**：脚本列表返回的字符串若形如 `{…}`/`[…]` 解码成 `JsonScope`（上游 `isJson()`），否则当 HTML。修复福书网章列表 872 次。
- **`result` 元素垫片（最小子集）**：裸 `@js:` / 首个 `<js>` 段（`elementResult`）上，把**字面量参数**的 `result.<op>(…)` 链在宿主求值后内联（attr/text/ownText/html/outerHtml/select/children/parent/first/last/get/size/elementSiblingIndex）；变量参数或未覆盖方法整条不内联；选择器之后的 `@js:` 明确保持字符串 `result`（防静默错值）。修复 re0zero isVolume 920 次、福书网 explore.author、金銀 11 条。
- **翻页 stop-at-next-chapter**：`walk` 比较下一页与 `nextChapterUrl`（两边绝对化）；`CheckBookSource` 按上游把目录第 2 章作为 `nextChapterUrl` 传入（卷标题排除）。14 个跑满 50 页的源不再整本连读。

日志（新增 `core/logging/log_throttle.dart`，60s 窗口 + `suppressed=N`）：
- `PageFetchService.warnThrottled` 用于字段降级 / 无下一页 / 无替换 / 列表条目缺 URL / 目录条目缺 URL / 封面选项 / 副文页 / 音频非 URL；桥的 `JS rule failed` 与 `Synchronous JS fetch failed` 也聚合；引擎 `Rejected rule` 降 debug（字段级 WARN 仍保留）。同一 (源,字段,原因) 从 1363/920/436 行降到每窗口 1 行。

Fail-fast（用户裁决）：
- 未建模 URL 选项（`origin`/`js`/…）从「warning 后照发」改为取值处 `unsupportedRule`（`rulePath=unsupported:url-options:<名字>`），ADR-0068 记增补（含重开条件）。
- 非 http(s) 目标（`javascript:;` / `undefined` / 拼错的相对值）在 `fetchRule` / `fetch` 发请求之前判 `parseFailed` 并只记一条（HttpClient 不再背这个锅）。

Android 校验通知（用户裁决）：
- 新增 `SourceCheckNotification` 端口（Noop + MethodChannel）、`sourceCheckNotificationProvider`；`SourceCheck.start` 每次结论后推进度、收尾发结果通知；文案由页面从 ARB 传入（4 个新 key，中英）。
- `MainActivity.kt` 用框架 `Notification`/`NotificationChannel`（minSdk 26，无新依赖）建通道、发进度/结果、支持 cancel；复用已有的 POST_NOTIFICATIONS 权限请求。**不是前台服务**：校验仍在主 isolate，通知只是后台可见的状态面（platform.md 已登记与上游的差异）。

登记/未做：`result` 垫片只覆盖字面量参数（变量索引不内联）；G4（`@put` 值失败仍响亮失败）、G7（条目缺 URL 跳过）、G11（explore 占位项）、`[attr~=regex]` 正则子串语义仍为有意差异；janpn 的 bookUrl JS 自身 bug 不猜。

## 2026-10-29 — M28 阅读页对齐上游：单一页表 + 章首章头 + 重复标题剥离（ADR-0087）

用户报障：阅读页①加载正文时标题出现两次 ②滚动翻页时正文会跳。先 `git pull` 到 93aacc7（已在 dev 线）。

根因：
- 双重标题：源站正文首行常是本章标题，本仓没有上游 `ContentProcessor.kt:117-141`（`//去除重复标题`）那一步，而 ADR-0086 §决策 7 又让流程自印章头 → 两次。另外分页模式只在加载页印标题，真实页没有。
- 内容跳：`ReaderScrollFlow` 在 widget 里量章节高度，且「上一章是否进窗口」由量出来的视口高度决定（`_anchorFillsViewport`）→ 正文到达/跨章时锚点上方高度变化，补偿只能放到后帧 `jumpTo`，那一帧已按错位画出。

用户三项裁决：①单一页表 + 自然高度（不用「一屏一页」的上游像素模型，保住连续观感）②章标题作为章首章头、两模式一致 ③排版前剥离正文首行重复标题。

落地（ADR-0087）：
- 新增 `reader_page_table.dart`：`ReaderPageId=(chapterIndex,pageIndex)`、每页先验高度、累计 tops、`positionAt`/`offsetOf`、按章测量缓存。
- 两个流程只画不量；表变了就按「锚点字符偏移」把读者的那行字放回视口顶（换 controller + 换 key，同帧生效，不再有后帧 jumpTo）。
- 窗口只向前长、上一章只在正文到手时进窗口 → 跨章时锚点上方高度不变 → 不打断手势。
- 落地过程中额外修掉三处真机形状：末页不满一屏时滚不到视口顶（补精确尾部留白，否则「跳到最后一章」回弹）；显式跳转会被流程的旧位置报告撤销（`_pendingJump` 以目标为准，落地前丢弃别的章的报告）；锚点章正文换章后丢失（记进正文表，否则上一章整章变矮）。

门禁：format / analyze 零警告 / 2817 用例全绿 / coverage core 98.02% · domain 96.55% · data 95.71% / build_runner 后生成物无 diff。

未做（已登记 roadmap §3.7）：会话与书签的偏移在「排版后」空间而书内搜索命中在「源站原文」空间，跳转落点会偏几行；滚动模式的上一章占位条不再出现（有意差异）。

## 2026-10-29 — M28 真机日志 15 条 overflow：量的样式与画的样式不一致（ADR-0087 §决策 8）

用户报障：Windows 真机日志 `app-2026-10-29.log` 「全是 error」。日志实为 15 条同一条记录（10:06:28–10:06:35，一帧一条），其余 1500 行是它的栈：`A RenderFlex overflowed by 31 pixels on the bottom`。对比 10-28 的日志（1.7 MB）没有任何溢出 → 是 44d6134 引入的。

根因（复现出来的，不是猜的）：页表按 `TextPainter` 量到的高度给每一项定高，而 `Text` 会把传入样式**并到环境的 `DefaultTextStyle`** 上——样式里没写的字段（行高、行高分布、字距…）由环境补，量的时候看不见。于是「画的」比「量的」高一整行，Column 溢出。用真实中文字体（`C:\Windows\Fonts\simhei.ttf`，`FontLoader` 注册成 Roboto）在 1440×900 上稳定复现：旧样式溢出 24 px，新样式 0。
另有一处同类：`m3e_design` 的 `titleMedium` **只给字族不给字号**，`TextPainter` 用默认 14、`Text` 从环境继承别的字号 → 章头量高也算错。

修复（ADR-0087 §决策 8）：两个阅读样式都**定型**后再生效——`inherit: false`、章头显式 `fontSize`（无主题字号时按正文 ×1.2）、`Text` 显式传 `textWidthBasis: parent` + `textHeightBehavior: TextHeightBehavior()`（与 `TextPainter` 默认对齐）。回归测试用一份**故意完全不同**的环境样式（`height: 3, letterSpacing: 8`）钉住「量到 576 就必画 576」；去掉修复这条用例红（576 vs 864）。

顺手补的观测能力：widget 类错误的崩溃记录多一段 `where=<creator 链>`（只取首个 ≤400 字符的信息节点，渲染树转储跳过），一条记录一行（ADR-0084 不变）。下次再溢出，日志能指名到 widget，而不是十五份一模一样的 `paint` 栈。新增 `test/core/logging/crash_handlers_test.dart`（该文件此前 0 覆盖，只靠 main 装配）。

门禁：format / analyze 零警告 / 2823 用例全绿 / coverage core 98.52% · domain 96.55% · data 95.71% / build_runner 后生成物无 diff。提交 81f05b4。

未解释的一点（如实记账）：31 px 与复现出的 24 px 不是同一个数，说明真机那台的字号/行高与复现环境略有差别；但「画的比量的高」这一机制与修复是同一条。

## 2026-10-29 — M28 跨章上限 + 预取 ±15 章（ADR-0088）

用户报障：向下滑动时有几率同时跨过多章并一起加载；要求加以限制，并把预取提前到两侧各 15 章。

根因：页表右边界恒为 `anchor + 1`，锚点每前进一章就往下补一章；补进来的一章若正文没到手就是一页加载页，流程的 `_requestMissingBodies` 立刻为它发请求。快滑时锚点连续前进 → 连续补进来好几页空白 → 那几章同时被拉起，且顺序由书源限速队列决定（不是「最近优先」）。根子是**阅读位置跑到已加载内容前面**。

落地（ADR-0088）：
- 跨章上限：锚点章正文没到手时页表右边界收回 `anchor`；到手才允许 `anchor + 1` 进来。于是任何时刻身前最多一章没有正文，能被跨过去的章一律是已经抓好的 → 跨章不再产生新请求。
- 预取 ±15 章、队列化、最近优先（+1, -1, +2, -2…）、同一时刻只有一个请求在飞；队列在锚点章变化时重排，离开 ±15 的待取项丢弃，换源整队作废。
- 保留分两层：正文原文留 ±15（这是提前缓存的内容），排版文本与页高测量只留渲染窗口（它们可重算）。
- 结清 roadmap §3.7「预加载章数可配」的数值部分：定 15；设置面仍未做。

实现时挖出并修掉三处真问题（都写进 ADR §实现注记）：
1. 接力加载（占位页在等）会把「已失败」标记清掉 → 屏幕和预取队列轮流为同一章发请求，一帧一个。现在只有读者的「重新加载」按钮传 `explicit: true`。
2. 锚点章被 `ref.read` 探一下 loading 状态：`ref.read` 会把没人监听的 provider 现造出来，等于凭空多发一个请求。改成锚点章直接走 provider（接力什么都不做）。
3. 串行队列靠 `addPostFrameCallback` 续链，而它**不排帧**：读者静止时链条第一跳之后就停了（预取永远只抓一章）。`_afterFrame` 补 `scheduleFrame`。

门禁：format / analyze 零警告 / 2826 用例全绿 / coverage core 98.52% · domain 96.55% · data 95.71% / 生成物无 diff。提交 020d1d6。

新增测试：锚点章无正文时页表停在该章；下一章无正文时只开一页加载页、第三章不预先排进来；20 章目录锚点第 8 章时请求顺序为「锚点 + 距 1/1/2/2/3/3…」、每章只问一次、同时在飞 ≤2（队列那一个 + 页面自己那一章）。

## 2026-10-29 — M28 目录更新时不许挪动读者（ADR-0089）

用户报障：书在别处更新出更多章节后，阅读页 ①闪屏 ②滚动进度因页面变长而错位。要求参考上游 `F:\Projetcs\legado-with-MD3(READ_ONLY)` 的阅读连续性。

上游做法（`ReadBook.kt:1798 upToc()`）：目录在 IO 线程拉取，**只有新列表更长才整表替换**；随后 `saveRead()`（把**没变过**的 durChapterIndex/durChapterPos 写回去）、`publishSnapshot()`、必要时 `loadContent(durChapterIndex + 1)`。视口、页码、进度一个都不动——它的位置是「目录下标 + 章内偏移」，而目录只在末尾变长，所以天然不用换算。还有 10 分钟节流。

本仓根因两处「刷新等于重建」：
1. 页面按 `AsyncValue` 的**形状**分支（`AsyncData → 正文，_ → 转圈`）。目录刷新时它先是 `AsyncLoading`（但**带着上一次的值**）→ 整块正文换成转圈 = 闪屏；同时正文流程的 State 被销毁，滚动位置丢。
2. `ReaderSession.build` 也 `ref.watch` 目录 → 同一次刷新让会话重建，而重建走的是「首次打开」那条路：`readerProgressStore.read` 从**磁盘**恢复。落盘只发生在换章与停手时，读数与当前屏差一截 → 错位。另外源在前面插章时 `chapterIndex` 指向的已不是读者那一章。

修复（ADR-0089）：
- 决策 1：两层都按 **`.value`** 分支——有值（刷新中/刷新失败）继续画上一次的正文，只有「从来没有过」才画转圈。正文流程不再被销毁。
- 决策 2：会话把 `(chapterIndex, charOffset)` 记在内存（`_position`），重建时用它，**不再**重读磁盘（磁盘只在首次打开时是权威）。
- 决策 3：`chapterIndex` 按**章节 URL** 搬到新目录上，字符偏移不动；URL 真找不到才退回原下标（不回第一章——读到一半不能把读者踢回书首）。
- 决策 4：预取队列的重建条件加上**章数**（ADR-0088 只在锚点章变化时重排，目录变长时新章节永远进不了队列）。

测试（先证明有牙）：页面用例「目录刷新期间没有转圈 + 会话与滚动位置都不动」——把 `.value` 分支改回形状分支即失败（找到 1 个 CircularProgressIndicator）；会话用例「末尾变长保留内存位置」——把 `_position` 改成 `null` 即失败（432 → 0），「前面插入搬到下标 3」同理。

门禁：format / analyze 零警告 / 2829 用例全绿 / coverage 98.52% · 96.55% · 95.71% / 生成物已重新生成并与源码同步。提交 721d0a8。

## 2026-10-29 — M28 追修：build 恢复出来的位置也必须记住（否则刷新跳第一章）

用户追报：721d0a8 之后「还是连续加载，滚动进度在加载时乱跳，跳到第一章」。查到一个真 bug，同时解释了「乱跳」与「跳到第一章」。

漏的那一半（ADR-0089 §决策 2 实现不完整）：`_position` 只在 `selectChapter` / `updateOffset` 里赋值，**`build` 自己算出来的那个位置从来没记住**。

复现链：
1. 打开一本书，恢复出「第 3 章」（`build` 返回 + 不记 `_position`）。
2. 读者一屏都没滑 → 流程第一次上报的偏移就是 0 → `updateOffset(0)` 因为「没变化」直接 return → `_position` 永远是 null。
3. 目录刷新（书更了章节）→ 会话重建 → `_position == null` → 走「首次打开」那条路 → **重读磁盘**。
4. 磁盘里没有这本书（首次打开还没落盘）或写着别的章 → `restored < 0` → **chapterIndex 0 = 第一章**。
5. 每次都跳一次 → 用户看到「加载时乱跳」。

修法：`build` 的每条**成功**返回都经 `_remember` 记下位置；`ParseFailure` 那条**故意不记**（目录没读到不算位置，否则下次读到了会带着错的位置走）。

牙：`build_whenTheRestoredPositionWasNeverScrolled_keepsItAcrossARefresh` —— 把 `_remember` 改成不赋值，用例立刻红（期望 2、实际 0），与真机现象一致。

排查过但**不是**原因（记下来免得下次重查）：`readerContentProvider` 内部用 `ref.read` 读目录，所以目录刷新不会连带重取正文；`_requestMissingBodies` 每章只问一次且失败即停；预取队列在锚点/章数不变时不重排。

门禁：format / analyze 零警告 / 2832 用例全绿 / coverage 98.52% · 96.55% · 95.71% / 生成物无 diff。提交 fe1d2f0。

## 2026-10-29 — M28 跨章不再回顶部：补偿改用页内像素（ADR-0087 §决策 2 修订）

用户报障：两章间隙处 ①向下滑进下一章会被「强制回到顶部」（进度跳变）②在下一章上滑回上一章会跳到上一章顶部；要求参考上游。

复现（页面级 scratch，打印每步 offset + session）：4 章 × 40 行、1200×1200，向下每步拖 60（有效 40）。跨章那一步日志里出现 `LAND 2166.0 (was 2123.0)` —— **正好 +43 px**，而 titleExtent 约 45，即「一行章头的高度」。

根因：`ReaderScrollFlow._sync` 在页表变了以后用**字符偏移往返**做补偿：`positionAt(offset)` 反解出 `(chapter, charOffset)`，再 `offsetOf(chapter, charOffset)` 落位。这个往返在章头那几十像素里**有损**：视口顶落在标题里时 `charOffsetAt` 夹到 0，而 `offsetOf(0)` 回到**正文首行**（章头之下）。于是每跨一次章，章头就被顶出屏幕；向上跨同理（落到上一章正文首行）。

上游同一个道理：`ReaderScrollPolicy.apply(offsetPx, deltaPx, previousExtentPx, currentExtentPx, …)` 跨界时把 offset 按**页高差**搬过去（`next - previousExtent` / `next + currentExtent`），从不回 0 重算；`ReaderPartialPagePolicy` 还额外拒绝翻进「还没排完」的章（与本仓 ADR-0088 的跨章上限同形）。

修复（ADR-0087 §决策 2 修订）：结构变化**先按页内像素补**——在旧表里找到视口顶所在的那一页，按页身份 `(chapterIndex, pageIndex)` 在新表里找回来，`newOffset = 新页顶 + (旧 offset - 旧页顶)`；只有这一页**自己的高度也变了**（换字号 / 换视口 / 占位页换成真实正文）才退回 `offsetOf(anchor)` 按字符找，因为那时「同一段字」比「同一个像素」更接近读者位置。

牙：
- `update_whenTheTopIsInsideAChapterHeading_doesNotJump`（flow 级）：视口顶放在章头里 3 px，第三章正文到手后位置必须不动。去掉修复 → 偏移 1051 → 1096，**差 45 px = 一行章头**，与真机一致。
- `scroll_acrossAChapterBoundary_movesSmoothly`（页面级）：4 章 × 40 行，向下 60 步再向上 60 步，逐步断言位移与拖动同向、且不超过拖动量；必须至少跨过一次章。

门禁：format / analyze 零警告 / 2834 用例全绿 / coverage 98.52% · 96.55% · 95.71% / 生成物无 diff。提交 90f101a。

## 2026-10-29 — M28 跨章不再换屏：页表正文在手就按在手算 + 窗口留 lead（ADR-0090）

用户再次报障（滚动模式）①滚到章末切下一章会「跳到下一章顶部」并且闪一下 ②在新章顶部往上滚回上一章会「跳到上一章顶部而不是末尾」；要求参考上游。

复现（页面级 scratch，每步打印 offset + 会话 + 页表形状）：4 章 × 40 行、1200×1200、每步拖 60（有效 40）。
- `DOWN 51 ch 0->1 TABLE 0:[1161,962] 1:[P]` —— 跨章那一帧第二章整章缩成一页占位页，下一帧又长回 3 页。
- `UP 8 ch 1->0 TABLE 0:[P]` + `d=-2126.0` —— 一步上滑被扔出两章远，落点是第一章开头。

根因一（主因）：「正文只认 provider」。页表给锚点章的正文只取 `readerContentProvider` 这一帧的值，而 `readerContent` 是 autoDispose 的家族 provider：锚点一换就是另一次请求、先是 loading。哪怕这一章正文早在 `_prefetchedBodies`（预取 ±15 章，读到章末时必在）里，那一帧也整章退回一页占位页（高度 = spacing.xxl + lg），页表上方/当前页高度骤变 → `_sync` 退回字符偏移往返 → 占位页的 `charOffsetAt`/`distanceOf` 都是 0 → 落点就是章首；`anchorReady == false` 还把右边界收回锚点章，屏幕上换成加载条 = 闪一下。

根因二：「往回读时窗口里没有上一章」。`_applyWindow` 只维持锚点上方 1 章、`_trimWindow` 停手后把水位提到 `anchor - 1`；读者上滑过这个边界时必须在视口上方插一整章，`_sync` 的补偿是换 `ScrollController` + 换 key（帧内生效），惯性活动连同手势一起丢。8 章读到第 6 章再上滑：`offset 2072.8 → 4090.2 (LAND)`，位移差 2017 px = 一整章。

上游不会：章节正文挂在章对象上（`TextChapter.content`/`isLoad`），换章不丢已读回的正文；跨章是页表运算（`ReaderScrollPolicy.apply` 用 `next - previousExtent` / `next + currentExtent` 搬 offset），没有「插内容后重建滚动位置」这一步。

修复（ADR-0090）：
- §决策 1 正文在手就按在手算：`currentData = provider 值 ?? _prefetchedBodies[url]`，`anchorReady` 与「失败」标记都只看正文是否在手（有字就不是失败态）。仍保留锚点章 watch provider 的那条通道：首次取正文、重试 `invalidate`、进章时重取（源更新章节能拿到新正文），多出的一次请求由 5.2 缓存吸收。跨章那一帧页表因此**什么都不变**，只按窗口往下追加一章，`_sync` 的位移差为 0 —— 不换控制器、不打断惯性。
- §决策 2 窗口在锚点上方留 `_windowLead = 3` 章，且只由**前进**维持（`_windowAnchor` 记录已读到的最大章）：后退不动水位（要回看的章本来就在表里），只有退到表的上沿才补章；`_trimWindow` 也停在 `anchor - lead`。渲染窗口宽 2 章，代价是几趟 `TextPainter`。
- §决策 3 登记未解决：往回超过 lead 仍要在视口上方插章，只能重设位置（位置精确、那一次手势结束）。彻底解决要 `center` 键的 `CustomScrollView` 或自绘 sliver 上报 `scrollOffsetCorrection`，属滚动模型级重构。

牙（四条都在修复前失败）：
- `scroll_whenTheBoundaryIsCrossed_keepsTheNewChapterInHand`：跨章后新章每页都是真正文、无占位条/转圈、窗口往下接一章；再上滑回上一章同样不掉正文且不是被扔回章首。修复前 `isPlaceholder` 命中。
- `scroll_acrossAChapterBoundary_doesNotStopTheFling`：惯性里跨章，逐帧位移单调不减且跨章后仍在前进。修复前跨章那一帧 `2179 → 2147` 并当场停住。
- `scroll_backAcrossChapters_keepsTheFlingRunning`：第 13 章一次上滑跨过至少两章、位移单调不增。lead 改回 1 即失败（第 43 帧 `+2047`）。
- `scroll_acrossAChapterBoundary_movesSmoothly` 改写：原用例在循环外抓一次 `ScrollPosition`，而重设位置会换掉这个对象（断言其实在读已脱离的对象）；现在每步读活的位置，容差从 ±120 收紧到「一步不超过拖动量」。

门禁：format / analyze 零警告 / 2837 用例全绿 / coverage 98.52% · 96.55% · 95.71% / build_runner 生成物无 diff。提交 cc7754f。

## 2026-10-30 — 换源重构：全屏两步页 + 渐进搜索（用户裁决）

用户 2026-10-29 裁决：换源界面用**全屏两步页**（第一步源列表 + 进度 + 范围 + 选项，点某个源后同页切到章节列表）；只有点「开始搜索」才跑，之前它是一个按钮；换源过程必须有进度条与加载态；点新书源后才显示章节选择。

默认值对齐上游 `ChangeSourceSettings`：校验作者 / 加载详情 / 加载目录 / 字数 **默认全关**（只跑搜索，请求最省），用户按需打开。范围**独立持久化**（对齐上游 changeSourceSettings.searchScope，与搜索页互不干扰），但复用 `BookSearchScope` + `resolveSearchSources` + 现有 scope 选择 sheet 组件。

章节：默认自动对齐（同名 → 包含 → 同索引 clamp，沿用 `alignChapterIndex`），用户可在一屏里改选；「确认换源」才提交，提交期再有进度。迁移第一版固定为 阅读进度 / 分组 / 置顶 / 状态 / 自定义封面（浏览器式勾选表留后续）。

页面归属：`book_source` 的 `ChangeSourcePage`；阅读器经 `AppNavigation` 新端口方法进入并只收 primitive 结果（C-ARCH-2），详情页直接 push。进度事件 = 已处理源 / 总源 / 已找到条数 / 当前源名，运行中可暂停与停止，停止保留已找出的行。

## 2026-10-30 — 无名命中（标题取不到）的根因修复与合并键兜底

现象：朝花夕拾这类书在详情/书架里有标题，但换源时提示「其他书源没有这本书」；有的书压根没标题。

根因链（代码事实）：`book_list_fields.dart` 的 `readBooks` 对 `name` 字段用 `name.dataOrNull ?? ''`——规则失败或没命中时**静默变成空串**；`SearchResultMerger` 的合并键是 `(name, author)`，空名命中会全部塌进 `other` 桶并互相合并；`SwitchBookSource.candidates` 在 `bookName.trim().isEmpty` 时**直接返回空列表**，所以无名书永远换不了源。

修法（三处）：
1. `readBooks`：`name` 取不到时打**节流警告**并带上 `rulePath=$fieldPrefix.name` 与 sourceId（能定位到具体源的具体规则）；URL 有效的命中仍保留，不静默丢。
2. 合并键：`searchBookKeyOf` 在 name 为空时回落到 `url`，避免不同源的无名命中被合并成一行（无名行仍显示，可点开）。
3. 换源：关键词**可编辑**（默认书名）；书名为空时关键词回落作者；`candidates` 不再因空关键词短路；匹配接受「作者相同」的命中；排序仍需同名优先。

验收：真机复跑用户报告的源，名字能解析出来，或日志能把失败钉到 `…name` 规则；无名书籍在换源页仍能出候选并完成切换。

## 2026-10-30 — 搜索结果合并条目保留每源快照 + 点条目选源

用户 2026-10-29 裁决：合并条目（朝花夕拾 / 4 个来源）点一下弹「来源选择」sheet，列出每个源的书名/作者/最新章，选哪个就按哪个源打开详情页；合并列表本身保持不变（不改上游式「按源分组」）。

实现要点：`SearchBook` 现在只留**第一个源**的 `url/author/lastChapter/coverUrl`，`origins` 只是 URL 列表——选中第 2 个源没有任何地址可用。因此 `SearchBook` 增 `hits: List<OriginHit>`（每源快照：sourceUrl、url、author、lastChapter、kind、coverUrl、updateTime），merger 合并时保留；合并键与桶排序不变。sheet 的数据全部来自这条快照，**不重新发请求**；来源已被删除的行给出「来源已删除」而不是打开错书。

## 2026-10-30 — 发现页两种布局（列表 / 网格 + 列数可调）

用户 2026-10-29 裁决：发现页要支持上游的两种布局，**列表 + 网格**，网格**列数可调**（1–10），横竖屏分别记忆。

对齐上游 `ExploreShowViewModel`：`layoutState`（0=列表 / 1=网格）+ `gridCount`（竖屏默认 3、横屏默认 7），均持久化；切换按钮在 AppBar，网格模式下再给一个列数入口。网格项 = 封面 + 标题(+作者)，与列表项共用同一 `Book` 数据，点击行为一致（打开详情页）。偏好写 `shared_preferences`（与上游一致的轻量开关；不进备份，因为它是设备相关外观偏好）。

## 2026-10-30 — 书架编辑书籍详情：第一版字段与 custom_intro 新列

用户 2026-10-29 裁决：书架里的书要能自由编辑详情，第一版覆盖 **书名 / 作者 / 封面 / 简介**（对齐上游 `BookInfoEditViewModel` 最常用的四项，其余备注/分类标签/阅读设置留后续）。

要点：
- `books` 表已有 `custom_cover_path`（M19 换封面）；`intro` 是**书源快照**，直接改会被下一次「加入书架」刷新覆盖 → 新增 `custom_intro` 列（schemaVersion 13 → 14，走 `_addColumnIfMissing`），显示时 custom 优先、回落快照。上游同形（`customIntro` vs `intro`）。
- 备份 `books` 表写入/读取 `custom_intro`；旧备份缺这个键按 `null`，恢复不报错。
- 书名/作者直接覆盖快照列（上游也是直接改 `book.name/author`）；保存后 `bookshelfProvider` 失效并让打开的阅读器换用新标题。
- 入口：书架行长按菜单「编辑书籍」+ 书籍详情页菜单；一页表单（`TextFormField` + 封面预览/清除），空书名拒绝保存。

## 2026-10-30 — M29 落地记录：换源内核换成渐进候选（三开关，字数登记未做）

M29 落地（ADR-0091）。改动：新增 `change_source_search.dart`（ChangeSourceSearch + 请求/候选/进度/匹配档位）；`readBooks` 书名缺失改为按 sourceId+rulePath 节流告警并保留命中；`SearchBook` 增 `OriginHit`/`hits`，`SearchBookKey` 空名回落 URL；merger 合并时保留每源快照；`SwitchBookSource.candidates` 改为新用例的薄封装（旧 UI 立刻拿到修复，不留两份匹配逻辑）；详情页换源把 `info.author` 传下去，标题读不出来时按作者搜。

**口径调整（对齐 ADR-0091 §决策 4）：** 换源选项从「四个开关」收敛为**三个**（校验作者 / 加载详情 / 加载目录）。上游的「字数」要多抓一次正文、且要在对齐章节之前知道章节索引，收益不成立 → 登记为有意不做，触发条件 = 用户要求候选列表显示字数。

牙：`change_source_search_test.dart`（进度序列 1/2/3 与 total、空标题回落作者、空标题且作者不符不冒充、checkAuthor 拒绝、exact 排在 partial 前、loadInfo+loadToc 补字段、详情页失败仍保留候选、取消保留已得、全失败报失败、无关键词不发请求）；`search_result_merger_test.dart` 补「同书两源留两份快照」「两条无名命中不合并」；`explore_books_test.dart` 补「无名命中保留 + rulePath=exploreRule.name」。

门禁：format / analyze 零警告 / 2851 用例全绿 / coverage 98.52% · 96.31% · 95.71% / 生成物二次构建无 diff。

## 2026-10-30 — M30 落地记录：换源全屏两步页（含路由例外与旧 sheet 退役）

M30 落地（ADR-0091 §决策 1/1b）。新增 `ChangeSourcePage`（全屏两步、进度/范围/三开关/开始-暂停-停止 → 章节选择 + 确认换源），状态在 `ChangeSourceController`（`@riverpod` 家族，key = `ChangeSourceTarget` 记录，离开即销毁）；范围独立存储 `bookSource.changeSourceScope`；范围选择器抽成 `source_scope_sheet.dart` 共享组件（`sourceScopeLabel` 也挪过去），搜索页同步换用。

入口：详情页直接 `MaterialPageRoute<ChangeSourceSelection>`；阅读器经新端口 `AppNavigation.openChangeSource(ChangeSourceLaunch) → ChangeSourceOutcome?`（`core/router/change_source_contract.dart`），装配根负责「改写书架身份 + 切选中源」，阅读器只做就地重定位。**删除**：`ChangeBookSourceSheet`、`ReaderSourceSheet`、`BookSourceSwitcher` 端口与两个旧测试；`SwitchBookSource` 收敛成纯映射（`withChapters` / `alignChapterIndex`），不再持 I/O。

两处口径记下：
1. **页面表例外**：`AppRouter` 的表是 `Route<void>`，而这一页要把选择当结果返回；不为它泛化路由表（会改到所有已登记路由），等出现第二个带返回值页面再泛型化。回链写在 `architecture.md` §6。
2. **无「提交中进度」**：序号迁移与选源都是本地写，真正耗时的详情/目录在「点源 → 章节列表」那一步完成（那里有 spinner）。页面 pop 之后才落库，用户看到的是章节列表 + 一次即时返回。

牙：换源页 4 条 Widget（首帧零请求；开始后 `searchProgress(2,2)` 与「已找到 2 条」；点源后才出现章节并按同名自动对齐、把选中章作为结果返回；范围里没有可搜源时给「没得搜」且零请求）；`switch_book_source_test` 重写为 `withChapters`（身份/作者/封面/最新章/tocUrl 回落）+ 对齐三档与越界钳位。

门禁：format / analyze 零警告 / 2845 用例全绿 / coverage 98.42% · 96.33% · 95.71% / 生成物二次构建无 diff。ARB 新增 13 键中英双语，`l10n_untranslated.json` 为空。

## 2026-10-30 — M31 落地记录：搜索结果「选择来源」sheet

M31 落地（ADR-0091 §决策 6）：`SearchBook.hits`（M29 已建的每源快照）现在被用起来了。新增 `book_source/presentation/widgets/search_source_sheet.dart`：点合并条目弹「选择来源」，每个来源一行 = 源名（从书源表现查）+ 作者 · 最新章 + 封面（全部取自该源快照，零请求）；被删除的源**保留但禁用**并标注「该书源在此期间被删除了」——藏起来会让「4 个来源」看起来在撒谎。只有一个来源时不弹 sheet，保持原来的直达路径（少一次点击）。

选中后：先 `selectedBookSourceProvider.select`，再推详情页；书本地址/作者/封面/最新章全取该源快照的字段。`SearchBook.hits` 为空时（M29 之前的合并行兜底）用 `origins.first` + 行内字段合成一条。

牙：`search_books_page_test` 新增「两源命中同一本书 → 来源数 2 → 点行弹 sheet → 选第二个源 → 详情页按 b.test 请求书籍页」；旧「单个来源直接打开详情页」用例保持通过（回归保护直达路径）。

门禁：format / analyze 零警告 / 2846 用例全绿 / coverage 98.42% · 96.33% · 95.71% / 生成物二次构建无 diff。ARB 新增 1 键（`searchSourceSheetTitle`）中英双语。

## 2026-10-30 — M32 落地记录：发现页列表/网格 + 列数分横竖屏记忆

M32 落地（`DECISIONS.md` #77）：发现页支持**列表 / 网格**两种布局，AppBar 一个按钮切换（图标 + tooltip 都随当前布局翻），网格模式下多一个「网格列数」按钮开底部滑块（1–10，松手才落盘）。

数据面：新端口 `ExploreLayoutStore`（`load` / `save`，total，坏值回落默认）+ 实体 `ExploreLayout`（`isGrid` + `portraitColumns` / `landscapeColumns`，默认 3 / 7，`copyWith` 里做 1–10 钳位——release 没有 assert，存坏值不能让 `GridView` 抛）+ `ExploreLayoutController`（keepAlive，唯一写入者）。偏好键 `bookSource.exploreIsGrid` / `explorePortraitColumns` / `exploreLandscapeColumns`（C-NET-9 的轻量开关，不进备份）。取列数用 `MediaQuery.orientationOf`，横竖屏各用各的。

UI 面：网格项 = 封面（`LayoutBuilder` 取格子尺寸，不写死像素）+ 标题两行 + 作者，点击与列表同一路径推详情页；列表项保持原样。牙：发现页三条 Widget（切到网格并落盘、偏好为网格时打开即网格、把滑块拖到 10 只改竖屏那一份）。

门禁：format / analyze 零警告 / 2849 用例全绿 / coverage 98.42% · 96.34% · 94.93% / 生成物二次构建无 diff。ARB 新增 4 键中英双语。

**留给 M33 的已知点**：`data` 层覆盖率从 95.71% 降到 94.93%（新 store 的实现行只被 Widget 间接覆盖），仍高于 80% 门槛；M33 加迁移测试时顺带补一条 `ExploreLayoutStoreImpl` 的直接单测更稳。

## 2026-10-30 — M33 落地记录：书架编辑书籍详情 + custom_intro（v14）

M33 落地（ADR-0092，`DECISIONS.md` #78）：书架终于能改书源抓错的字段。

**数据**：`books.custom_intro`（nullable，schemaVersion 13→14，`_addColumnIfMissing` 可重入），`drift_schema_v14.json` + `generated_migrations/schema_v14.dart` + v13→v14 迁移用例；仓储一次写入 `updateDetails(id, name, author, customIntro)`（三个字段同一次保存，避免两个 `updatedAt` 让书架顺序跳）；备份 `books` 表多一个 `customIntro` 键，旧备份缺键按 null 保留本地（合并语义，ADR-0073 §决策 3）。

**归属与入口**：编辑页在 `bookshelf`（`ShelfBookEditPage`，路由 `BookshelfRoute.editBook(book:)`，整行随路由走以便填表）；书架行菜单「编辑书籍」；详情页多一个「编辑」按钮，经新端口 `AppNavigation.openShelfBookEdit(context, bookId)` 进入（`ShelfMembership` 增 `id` / `customIntro`）。详情页简介展示改为 `membership.customIntro ?? info.intro`——用户改过的简介立刻生效。

**交互**：封面「选择/改用书源封面」各自立即落盘（取消不是失败）；书名空值拦下不保存；简介留空 = 存 null（回到书源简介）。

**登记未做**：分类/标签、备注、阅读类型、固定类型、每本阅读设置——各自要先有列或动分书阅读设置，触发条件 = 用户点名。

牙：迁移 15 条；仓储 `updateDetails` 两条（写入三项且不动快照 / 清空回落）；备份 `roundTrip_carriesTheUsersOwnIntro`；编辑页 Widget 三条（空书名拦下且不落库 / 三字段写入并关闭 / 留空存 null）。

门禁：format / analyze 零警告 / 2856 用例全绿 / coverage 98.38% · 96.34% · 94.96% / 生成物二次构建无 diff（含 drift schema dump）。ARB 新增 10 键中英双语。

## 2026-10-30 — 换源改回弹层 + 修真机崩溃（UnmountedRefException）

① 修 P0 崩溃（真机日志 `app-2026-10-30.log` 12:07:23 与 12:08:20 两处 `UnmountedRefException` + ERROR CRASH，栈顶都是 `ChangeSourceController.start`）：用户搜索没跑完就关掉换源，`await` 回来后继续对**已销毁**的 provider 写状态。修法三条——`ref.onDispose` 里取消在跑的那批（worker 会在两个源之间退出）、每个 `await` 之后判 `ref.mounted`（书源表 / 搜索结束 / 目录结束）、`onProgress` 回调里也判。回归用例把请求按在 `FakeHttpClient.onRequest` 闸门上，关 sheet 再放行；**去掉任一条守卫该用例即红**。

② 形态按用户要求改回**弹层**（ADR-0091 §决策 1b 修订）：删除全屏 `ChangeSourcePage`，改为 `ChangeSourceSheet` + `showChangeSourceSheet(context, target:)`（`isScrollControlled`、0.92 屏高、`FractionallySizedBox`、键盘 `viewInsets` 顶起），两步在同一个 sheet 内切换（点源后标题变源名 + 返回箭头），**功能一字未减**（关键词 / 范围 chip / 三开关 / 进度条与计数 / 开始-暂停-停止 / 章节选择 + 自动对齐 / 确认换源）。详情页与阅读器走同一个弹层；`architecture.md` §6 的「页面表例外」整条撤回。

门禁：format / analyze 零警告 / 2857 用例全绿 / coverage 98.38% · 96.34% · 94.96% / 生成物二次构建无 diff。ARB 新增 `actionBack`（中英）。

日志复查里另外两条**不是崩溃、但值得记**：
- `Detail page yielded no book name`（linovel / zhulang / tiandizw / cthulhuclub / rouwen / po18 / yingyuxiaoshuo 等）：这些源的 `searchUrl` 会直接返回**详情页**，而 `ruleBookInfo.name` 读不到 → 按上游语义（`getInfoItem?.let`）就是「空结果」，不是失败。本仓已有一条警告；要不要进一步给用户「这个源搜不到」的提示，取决于是否愿意为此加一个候选空态标记（现在只是一行日志）。
- `Paging stopped at 50 pages`（多数为 `ruleToc`）+ 同一源连续两次 50 页：目录翻页上限是保护，但这些源的目录确实超过 50 页，**最后几章会缺**。上游 `BookChapterList` 的上限也是 50（`chapterList` 翻页），所以行为一致，登记为已知边界。

## 2026-10-30 — 日志复查：目录 50 页截断（已抬到 500）与三条「与上游一致」的告警

日志复查（`app-2026-10-30.log` / `app-2026-10-29.log`）结论：

**已修（本轮）**
1. `UnmountedRefException` ×2（换源跑一半关页面）→ 见 #84。
2. **目录翻页上限 50 → 500**：真机日志里 `m.bequ6.info` / `m.bingfengzw.net` / `wap.po18.in` / `23.224.242.55` / `www.mxjtedu.com` 都撞上 `Paging stopped at 50 pages`，意味着长书**尾部章节缺失**（读到最后跳不过去）。上游 `BookChapterList` 不设固定上限（靠 `nextTocUrl` 收敛 + `nextUrlList` 去重），本仓改成 500 只作失控保护；`book-source.md` §9 / §4.1 注记、`engine-parity.md` 对应行同步改。牙改成「51 页目录必须全部读到、且无 warning」。

**判定为「与上游一致，不是 bug」**
3. `Detail page yielded no book name`（linovel / zhulang / tiandizw / cthulhuclub / rouwen / po18 / yingyuxiaoshuo 等十余源）：这些源的 `searchUrl` 直接返回详情页，而 `ruleBookInfo.name` 读不到。上游 `getInfoItem()?.let{…}` 同样**不加条目**——所以我们只留一行 warning，不报失败。
4. `Request failed / Retrying` 与 15s 超时：站点本身慢（`vikbook` / `kxwx`），已有重试 + 单源预算；换源整体 2–3 分钟是源数量的正常代价，界面有进度与停止。
5. `Search hit without URL skipped` / `Chapter without URL reuses the toc page` / `Volume without URL gets a placeholder`：§7/§9 的既有降级语义，与上游一致。

**未定位（旧日志，页面栈里没有 feature 帧）**
6. `app-2026-10-29` 10:06 的 `RenderFlex overflowed by 31 pixels`（`RenderSliverMultiBoxAdaptor` → `RenderFlex`，即在某个列表项里）：出现 15 次、形状一致。10-29 的换源面板/阅读换源 sheet 已在 M30 删除，最可能是它们；新版需要复跑确认。若再现，按「列表项 Column 超过固定高度」定位（本仓列表项只有书源行 / 目录行 / 换源行三处）。

**顺手清掉**：`reader_settings.dart` 里三个从未被引用的 `ReaderAutoReadSeconds` 常量（自动翻页未实现，留着就是死代码）。

## 2026-10-30 — M34/M35 落地记录：自动翻页 + 阅读内净化开关

M34 + M35 落地（ADR-0093 / ADR-0094），两项都不动数据库。

**M34 自动翻页**：`ReaderSettings.autoPageSeconds`（3–60，默认 15，prefs 键 `reader.autoPageSeconds`，工厂里 clamp）；驱动是 `ReaderPageTurn`（`ChangeNotifier` 命令对象）——分页 flow `nextPage(300ms)`、滚动 flow `animateTo(+viewport, 300ms)`，因为两个 flow 的控制器会在帧内被替换（ADR-0087 §决策 2），从外面抓控制器必然抓到废弃实例；工具条加播放/暂停 toggle，并把整条工具条改成可横向滚动（10 个按钮在窄屏放不下）；六条停止条件（再点开关 / 点正文 / 翻章 / 起朗读 / 两拍无进展 / dispose）逐个接线。

**M35 阅读内净化**：`reader` 声明 `PurgeRuleSwitches` 端口（`list` + `setEnabled`，原语），默认 unbound（空列表 + warning）；装配根绑到 `rules` 的 `RuleRepository`，写入后 `contentCache.clearForBook(sourceId, bookUrl)` **只清这本书**；面板 `ReaderPurgeSheet` 从工具条（`Icons.auto_fix_high`）打开，逐条开关，切换后 `ref.invalidate(readerContentProvider)` 让当前章与预取章按新规则重读；端口拒绝时给 snackbar 而不是假装开关动了。

牙：M34 —— `ReaderSettings` clamp + prefs 往返；页面级三条（一拍翻一页、点正文停止并回到播放图标、滚动模式滚一屏）。M35 —— 面板四条（列表与开关状态、写这本、端口拒绝、空态）+ 阅读页「点按钮开面板」。

门禁：format / analyze 零警告 / 2867 用例全绿 / coverage 98.38% · 96.28% · 94.96% / 生成物二次构建无 diff。ARB 新增 9 键中英双语。

**仍有未做（登记在 roadmap §3.13）**：音量键/自定义翻页键位、日夜自动切换、目录按卷折叠、字体导入、进度实时云同步、换源「作为新书添加/冲突处理」。

## 2026-10-30 — M36/M37 落地记录：目录按卷折叠 + 键盘翻页

M36 + M37 落地（ADR-0095 / ADR-0096），两项都不动数据。

**M36 目录按卷折叠**：`ReaderTocSheet` 的显示模型从「章节行」变成「组头 / 章节行」两种。`isVolume` 章节
渲染成组头（展开箭头 + 加粗标题），`onTap` 只折叠、不回调 `onSelected`、不发正文请求；折叠按**原索引**记在
`Set<int>`，只隐藏「本卷到下一卷之前」的章节，卷标题自身永远可见。默认全展开；**搜索忽略折叠**（命中项必须
看得见）。倒序仍是整表反转（卷标题跟着走）。当前章居中的估算不受影响（`ListTile` 同高）。

**M37 键盘翻页**：`ReaderPageTurn` 加方向（`next()` / `previous()` + `direction`），分页 flow 用
`nextPage`/`previousPage`、滚动 flow 用 ±`viewportDimension`（夹到滚动范围）；阅读器用
`CallbackShortcuts` + `Focus(autofocus: true)` 绑定 →/↓/PageDown/Space 与 ←/↑/PageUp；按键属手动输入，
先停自动翻页（ADR-0093 §决策 3.2）。**Android 音量键登记未做**：系统先消费音量键，要平台通道拦截并处理
「用户其实想调音量」的冲突与无障碍语义——触发条件 = 用户点名要音量键。**自定义键位**同样未做（要整套键位编辑器）。

牙：M36 目录 sheet 三条（组头分组且点组头不跳转、折叠只隐藏本卷、折叠中搜索仍出命中）；M37 页面级两条
（右箭头翻一页、左箭头回一页）。

门禁：format / analyze 零警告 / 2872 用例全绿 / coverage 98.38% · 96.28% · 94.96% / 生成物二次构建无 diff。

## 2026-10-30 — M38 落地记录：正文缓存 3 天 / 在架永久，预取改为后 15 章优先

M38 落地（ADR-0097），按用户口径「进入阅读页就缓存后面 15 章；默认 3 天清；加入书架后一直保留到用户清这本书的缓存」。

**缓存寿命分两档**：`chapterCacheTtl` 12 h → **3 天**；**在架书**写缓存时带 `persistent`，过期时间写哨兵 `DateTime.utc(9999)`（不新增列、不迁移：`expiresAt.isAfter(now)` 语义不变，`deleteExpired` 也不会误删）。「在架」的判定放在**装配根**的正文端口（`_ChapterContentSource`）：每次取正文前 `BookshelfRepository.findByUrl` 查一次（单行索引），结果经 `ChapterRequest.persistCache` → `FetchContent` → `ContentCache.write(persistent:)` 一路透传。每次查而不缓存判定，是因为一条错判成「永久」的条目只有用户手动清理才会消失。清除路径不变：详情页/缓存管理页的「本书缓存」与「全量清理」。

**预取顺序**：`_queuePrefetches` 从「最近优先（+1, −1, +2, −2…）」改为**后 15 章优先**（`+1…+15`，再 `−1…−15`）。半径仍是 ±15、仍串行（ADR-0088 §决策 2 的礼貌性保留），只改顺序——这是「进入即缓存后面 15 章」的直接实现；ADR-0088 索引行标注「顺序已修订（ADR-0097）」。预取本来就在 build 里随会话与目录就绪立刻开始，所以不需要新的触发点。

牙：缓存适配器两条（永久条目跨 10 天仍命中且 `clearExpired` 不动它 / 普通条目 3 天后未命中）；`FetchContent` 一条（`persistCache` 透传到 `write`）；阅读页预取用例改「前向递增、回翻整段排在前向之后」。顺手补了两处 fake 的签名（`FakeContentCache.writePersistent`、`_FailingCacheDao.put`、`tool/spot_check` 的 `_NoContentCache`）。

门禁：format / analyze 零警告 / 2875 用例全绿 / coverage 98.38% · 96.28% · 94.96% / 生成物二次构建无 diff。文档：`book-source.md` §4.2 缓存注记、`roadmap.md` §5.2 与新增 §3.15。

**已知边界（写进 ADR）**：`persistent` 只在写时生效——一本书在加入书架之前写下的条目仍按 3 天过期，过期后下一次读取会重写为永久条目；不做「加架时批量改写」的全表更新（缓存可再生，多一次请求比一次全表更新划算）。

## 2026-10-30 — 发布 v1.0.0：dev→main 的整理、冲突收编与发版结果

发布 v1.0.0 的过程与结果（2026-10-30）。

**提交**（dev）：`9b6f614` 代码（M29–M38，98 文件）/ `b3155e6` 文档（7 条 ADR + roadmap/ui-gap/architecture/book-source/engine-parity + DECISIONS/PLAN）/ `69aa443` .gitignore 收 `devtools_options.yaml` / `52a9154` 版本 1.0.0 + CHANGELOG / `5ccacef` 收编 main 血缘 / `a420417` 修「关于」页与本地回退版本号。

**main 与 dev 的分岔**：main 比 dev 多两条提交（#45 三通道发布、#47 数据/主题/引擎重建），它们是同一条线更早的 squash；dev 已含其全部内容。main 独有文件只有 `redaction.dart`（ADR-0082 已取消脱敏）、旧换源 sheet/端口（ADR-0091 已退役）、三份被替代的测试（`book_source_view_notifier_test` / `book_source_list_page_batch_test` / `reader_page_audio_test`，dev 有对应覆盖）。因此用 **`git merge -s ours origin/main`** 记录合并、保留 dev 的树——156 个冲突一次清零，且 main 成为 dev 的祖先。合并提交里逐条写明了丢掉的 5 个文件与理由。

**PR**：复用并整理既有 #48（原 `chore(release): 0.2.0`，一直未合），改标题为 `chore(release): 1.0.0`、按模板重写正文（门禁实测输出、影响范围、ADR 清单、待真机验收项）。checks 全绿（verify 9m10s、android 6m38s）后 **squash 合并** → main `8375e44`。

**注意**：`gh pr merge --squash` 默认删除了 `dev` 远端分支，已立即 `git push origin dev` 重建（ADR-0079 要求 dev 长期存在）——后续用 merge 时记得 `--delete-branch=false`。

**发版**：`git tag -a v1.0.0`（tag 消息含本版要点）+ push → Release workflow `41011633658` 全绿（meta / gate / android / windows / ios / publish），GitHub Release `v1.0.0` 已发布、非 pre-release，四个产物：windows-x64.zip 26.7 MB、android.apk 91.7 MB、android.aab 89.8 MB、ios-unsigned.xcarchive.zip 60.5 MB。

**收尾状态**：`origin/main` 与 `origin/dev` 的树完全一致（squash 后无回灌差异），本地工作树回到 `dev`。
