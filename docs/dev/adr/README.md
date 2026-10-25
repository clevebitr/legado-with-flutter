# 决策记录（ADR）

本目录记录所有**架构与规范层面**的决策。规则条目与 ADR 的对应关系见 `docs/README.md` §5。

## 状态定义

| 状态 | 含义 |
|---|---|
| **Proposed（待裁决）** | 已给出建议方案，等待裁决人确认。实现前不得默认生效。 |
| **Accepted** | 已生效，代码与文档必须遵守。 |
| **Superseded by ADR-NNNN** | 已被新决策取代。原文保留，不删除。 |
| **Rejected** | 曾被否决。保留否决原因，避免重复提议。 |

## 规则

1. 一条决策一个文件，文件名 `NNNN-kebab-title.md`，编号永不重用。
2. 推翻旧决策必须新建 ADR 并把旧 ADR 标为 `Superseded by ADR-NNNN`。
3. 任何改动 `docs/dev/` 规范的 PR，若改变了既有结论，必须新增或更新 ADR。
4. ADR 被接受后，必须回链到受影响的 `constraints.md` 条目。

## 索引

| ADR | 标题 | 状态 | 替代了旧文档中的 |
|---|---|---|---|
| [0001](0001-riverpod-codegen-only.md) | 状态管理只使用 Riverpod，Provider 必须代码生成 | Accepted | D1、D2、D3 |
| [0002](0002-parse-result-contract.md) | 错误契约：`ParseResult` 与 `ParseFailureKind` | Accepted（2026-10-11 修订） | D9 |
| [0003](0003-drift-as-primary-storage.md) | Drift 作为主持久化方案 | Accepted | D7 |
| [0004](0004-m3e-theme-tokens-and-dynamic-color.md) | 主题令牌以 `m3e_design` 为准，取色用 `dynamic_color` | Accepted | D4、D5 |
| [0005](0005-no-get-it.md) | 不引入 `get_it`，依赖注入统一 Riverpod | Accepted | D6 |
| [0006](0006-logging-facade.md) | 日志统一 `logger` + `core/logging` 门面 | Accepted | D8 |
| [0007](0007-license.md) | 许可证：GNU GPL-3.0 | Accepted | D15 |
| [0008](0008-single-js-engine.md) | JS 引擎只保留 `flutter_js_plus` | **Superseded by ADR-0015** | D10 |
| [0009](0009-golden-testing-builtin.md) | Golden 测试使用内置 `matchesGoldenFile` | Accepted | D12 |
| [0010](0010-lint-baseline-and-gates.md) | lint 基线、无效规则清理与门禁入口 | Accepted | D13、D14 |
| [0011](0011-builtin-navigator-routing.md) | 路由使用内置 `Navigator`，暂不引入 `go_router` | Accepted | 本次新增 |
| [0012](0012-docs-single-source-of-truth.md) | 文档单一来源（SSOT）与约束条目 ID 方案 | Accepted | 本次审计 |
| [0013](0013-single-source-for-gates-and-versions.md) | 门禁阈值、命令清单与版本基线各自只有一处定义 | Accepted（2026-10-11 修订） | D11、D16 |
| [0014](0014-book-source-minimal-scope.md) | 书源功能范围：对标原版阅读的最小实现分期 | Accepted | 本次新增 |
| [0015](0015-adopt-flutter-qjs-next.md) | 采用 `flutter_qjs_next` 作为 JS 引擎 | Accepted | 取代 0008 |
| [0016](0016-sealed-variant-form-vs-freezed.md) | 密封层级的子类形态以编译器产物为准（放弃 `final class` 字面要求） | Accepted | 本次新增 |
| [0017](0017-test-file-location.md) | 测试文件位置：在 `test/` 下镜像 `lib/` 路径 | Accepted（2026-10-11 修订） | 本次新增 |
| [0018](0018-android-min-sdk-baseline.md) | Android 平台基线：保留 `minSdk 26`，并重建其依据 | Accepted | 本次新增 |
| [0019](0019-coverage-gate-must-detect-unmeasured-files.md) | 覆盖率门禁必须检测「未出现在报告中的源文件」 | Accepted | 本次新增 |
| [0020](0020-dynamic-color-provider-builder-shape.md) | 动态取色接口以 builder 包装形态提供，并在根部注入 | Accepted | 本次新增 |
| [0021](0021-book-source-models-live-in-domain.md) | 书源模型位于 domain 实体，并携带 JSON 序列化注解 | Accepted（**2026-10-14 P5-0 复审注记：例外保持，触发条件已重写**） | 本次新增 |
| [0022](0022-json-serializable-checked-mode.md) | 书源 JSON 解析启用 json_serializable 的 `checked` 模式 | Accepted（架构师复审裁决） | 本次新增 |
| [0023](0023-legal-stance-after-upstream-shutdown.md) | 上游停运后的法律立场：方言兼容继续、真实语料最小化脱敏、免责与用途限制加强 | Accepted（架构师裁决三件事） | 本次新增 |
| [0024](0024-g2-split-offline-replay-vs-live-link.md) | G2 拆分为 G2a（离线回放）与 G2b（真实链路） | Accepted（架构师复审裁决） | 本次新增 |
| [0025](0025-domain-services-and-parsing-components.md) | domain 允许无状态领域服务与解析构件（登记 F1 偏离） | Accepted（架构师 PR 评审指令裁决（F1）） | 本次新增 |
| [0026](0026-optional-field-rejection-degrades-to-warning.md) | 非顶层字段被拒时降级为 warning，顶层规则仍整次失败（登记 F6 裁决） | Accepted（架构师裁决 F6） | 本次新增 |
| [0027](0027-docs-topic-realignment.md) | 文档按主题重排：事实级归属矩阵与去重 | Accepted（2026-10-11 文档审计裁决） | 本次审计 |
| [0028](0028-rule-scope-and-json-rules.md) | 规则 scope 显式化为 `RuleScope`，`@json:` 与默认 / `@css:` 规则共用一条读取路径 | Accepted（架构师裁决「RuleScope」；细节由本 PR 登记） | 本次新增 |
| [0029](0029-js-bridge-shape-and-async-engine-api.md) | `@js:` 接入：引擎 API 转异步，JS 绑定形态逐项定义 | Accepted（2026-10-11 架构师裁决，用户确认生效） | 本次新增 |
| [0030](0030-js-engine-capacity-and-queueing.md) | JS 引擎容量与排队：单常驻 worker + 单复用运行时 + FIFO，容量不进 `JsBridge` 契约 | Accepted（2026-10-11 架构师裁决） | 本次新增 |
| [0031](0031-tolerant-decoding-on-the-declared-charset-lane.md) | 编码宽容只对「已声明」车道开放（声明权威 + warning，嗅探/回退保持严格） | Accepted（2026-10-11 架构师裁决，用户指令） | 本次新增 |
| [0032](0032-unknown-rule-type-degrades-to-css.md) | 默认规则的未知类型退化为原始 CSS 选择器 | Accepted（2026-10-12 开发组起草、**架构师审核接受**；G2b spot-check 触发） | 本次新增 |
| [0033](0033-cache-failure-exemption-in-its-adapter.md) | 缓存失败吸收的唯一豁免点：`CacheDaoCharsetCache` 允许 `on Exception`（drift 不导出 `ConnectionClosedException`） | Accepted（2026-10-12 架构师裁决；3.9 复核 F1 的事实修正触发） | 本次新增 |
| [0034](0034-js-rule-variables.md) | M1 规则变量：宿主侧一份表 + 每个 job 一份快照（`@put:` / `@get:` / `java.put` / `java.get`） | Accepted（2026-10-12 架构师裁决；ADR-0030 §决策 5(a) 的重开触发条件；**2026-10-14 P5-0 修订注记：§决策 2 裁决为不落盘**） | 本次新增 |
| [0035](0035-explore-url-and-rule-explore-fallback.md) | 发现页：`exploreUrl` 的两种形态（分类串 / 整字段 JS）与 `ruleExplore` → `ruleSearch` 的**整条**回落，含四条登记差异 | Accepted（2026-10-13 架构师裁决；M1-b0 规格前置） | 本次新增 |
| [0036](0036-concurrent-rate-and-the-budget.md) | `concurrentRate` 的语法与毫秒单位，以及「速率门 → 并发门」的合成顺序 | Accepted（2026-10-13 架构师裁决；M1-b0 规格前置） | 本次新增 |
| [0037](0037-java-binding-compat-surface.md) | `java.*` 成为兼容面：别名族（`md5Encode` / `base64*` / `encodeURI` / `log`）、规则求值族（字面量宿主内联快路径 + 异步兜底）与具名拒绝 | Accepted（2026-10-13 架构师裁决；合集 C 全量语料取证，M1-b1b 开工前置） | 本次新增 |
| [0038](0038-device-probe-at-phase-exit.md) | 设备级探针按**阶段出口**要求（Windows + Android 各一次），切片级只要求 Windows | **Superseded by ADR-0039** | 本次新增 |
| [0039](0039-device-probe-per-slice-again.md) | 设备级探针回到**切片级双端**（代价前提已消失；环境阻塞走「写明 + 架构师补跑」） | Accepted（2026-10-13 架构师裁决；取代 0038） | 取代 0038 |
| [0040](0040-book-source-import-contract.md) | Phase 5 的书源导入契约：合成 `id` 主键 + `(url, 指纹)` 唯一索引、重复导入幂等、32 MiB 体积上限、不扩 `ParseFailureKind`、5.1 不引入新依赖 | Accepted（2026-10-14 架构师裁决） | 本次新增 |
| [0041](0041-phase5-feature-boundaries.md) | Phase 5 的 feature 边界：`reader` / `bookshelf` / `settings`，跨 feature 一律走「消费方端口 + 装配根绑定」，进度归 `bookshelf` | Accepted（2026-10-14 架构师裁决） | 本次新增 |
| [0042](0042-cross-feature-navigation-and-shared-widgets.md) | 跨 feature 导航走 presentation 端口（`AppNavigation` 由装配根绑定）；共用的 `StateMessage` / `FailureMessage` 上移 `core/widgets/` | Accepted（2026-10-21，5.4 / 5.6 落地时确立） | 本次新增 |
| [0043](0043-source-check-mechanism.md) | 书源测试机制：结果写回 `book_sources`（+ `comment` 列）、`checkKeyWord` 建模与「像规则」判据、`LongRunningTask` 平台端口、失败语义不动 `ParseFailureKind` | Accepted（2026-10-21，M10 规格前置，用户裁决四项） | 本次新增 |
| [0044](0044-reader-session-and-progress.md) | 阅读器会话：自有字号/行距/背景（与全局 textScale 叠乘）、进度端口读写、`books.tocUrl` 列（v5）、两种翻页模式与偏移估算、`canReName` 在加入书架时消费 | Accepted（2026-10-21，M4 规格前置，用户裁决四项） | 本次新增 |
| [0045](0045-book-source-list-order-and-display.md) | 书源列表以投影列为准、四排序键 + 固定 tie-breaker、拖拽只写归一化 `customOrder`、排序与分组筛选持久化、行内展示与格式 | Accepted（2026-10-21，M6 规格前置，用户裁决四项） | 本次新增 |
| [0046](0046-aggregate-search-scope-match-and-merge.md) | 聚合搜索：范围三态与回落、类型默认文本、匹配模式=分桶排序（equal/tags/contains/other）、`(name,author)` 去重 + origins、并发/60 s 单源超时/失败语义、暂停取消、分页与 `hasMore`、1000 条上限 | Accepted（2026-10-21，M11 规格前置，范围由 #6 裁决） | 本次新增 |
| [0047](0047-engine-rule-surface-and-failure-isolation.md) | 引擎兼容面（M12）：URL 后缀 `url,{…}`（含 charset/body/headers）、`<js>` 分段链（#31）、列表 JS、JSON 条目 `result` 绑定、`header` 规则前置求值、`$.[…]` 归一化、三处失败隔离 | Accepted（2026-10-21，M12 规格前置 + 落地；真实语料 128 条度量） | 本次新增 |
| [0048](0048-mpl-2-0-policy-and-big5-decoding.md) | 许可政策：MPL-2.0 进入允许族但**只按白名单**放行（`enough_convert` 提供 Big5 解码）；只补解码不补检测，HKSCS 部分支持 | Accepted（2026-10-21，M12 规格前置；用户裁决改 C-DEP-7） | 本次新增 |
| [0049](0049-source-context-and-budget.md) | 规则上下文与单源预算：`ChapterRequest` 替代裸 URL、`java.get('bookName'/'title')` 先于变量表、`SourceBudget` 成为「一个源一份预算」的唯一实现 | Accepted（2026-10-21，M12 规格前置；用户裁决两项） | 本次新增 |
| [0050](0050-book-source-write-paths.md) | 书源管理的写路径：用户分组（payload）与校验分组（列）分轴、批量操作单事务且只写用户态、编辑按 id 更新同一行（身份冲突显式失败）、单条导出 = payload 原文 | Accepted（2026-10-22，M13 规格前置；范围由 #11 裁决） | 本次新增 |
| [0051](0051-reader-experience.md) | 阅读体验（M14）：三区点击 + 可隐藏工具条（进度/亮度）、目录居中/正倒序/搜索、换源（候选→重取目录→按名对齐→`migrateIdentity`）、排版四轴（字体族用平台通用名、不打包字体） | Accepted（2026-10-22，M14 规格前置；范围由 #11 裁决） | 本次新增 |
| [0052](0052-book-source-management-v2.md) | 书源管理二期（M15）：`source_checks` 历史表 + 四态状态灯、探索开关列、置顶/置底与分组重命名/删除/移出、排序方向与域名分节、导入预览/提交两步 | Accepted（2026-10-22，M15 规格前置；范围由 #13 裁决） | 本次新增 |
| [0053](0053-manga-engine.md) | 漫画引擎（M16）：漫画是 reader 的一个模式（`sourceType = image` 分派）、`ruleContent` 列表语义产出图片页、滚动/翻页两种观影模式 + `InteractiveViewer` 缩放、页号进度与预取 ≤3 页、零新依赖 | Accepted（2026-10-22，M16 规格前置） | 本次新增 |
| [0056](0056-idempotent-schema-migrations.md) | 数据库迁移步骤必须可重入：升级前先问 `sqlite_master` / `PRAGMA table_info`，裸 `addColumn` / `CREATE INDEX` 禁止只看版本号 | Accepted（2026-10-22，线上事故修复：`reader.db` 永久打不开） | 本次新增 |
| [0057](0057-source-check-selection-and-handover.md) | 校验的参测源由「筛选 + 勾选」决定，并可跨页交接 | Accepted（2026-10-22，用户报障） | 本次新增 |
| [0058](0058-source-derived-ui-must-follow-its-input.md) | 选源 / 选范围的界面必须跟随它的输入（修订 ADR-0046 §决策 1 的回落判据） | Accepted（2026-10-22，用户报障） | 本次新增 |
| [0055](0055-app-shell-and-about-pages.md) | 应用外壳与关于/法律声明（M18）：`AppShell` 在组合根、四 tab `IndexedStack` 保活、「我的」只做入口聚合、关于页版本常量 + 打包 GPL 全文 + 源码地址（不引 `url_launcher`） | Accepted（2026-10-22，用户裁决「开始补齐 UI」） | 本次新增 |
| [0054](0054-audio-and-tts-engine.md) | 听书与音频（M17）：音频源播放与系统 TTS 两条独立链路共用章节上下文；依赖选型与三端降级（`just_audio` / `audio_service` / `flutter_tts`，Windows 无媒体通知）；HLS/云 TTS/句级高亮未闭环 | Accepted（2026-10-22，M17 规格前置） | 本次新增 |
| [0059](0059-book-source-batch-disposal.md) | 书源批量处置：多选模式独立状态 + 工具栏入口、多选期间行内开关/菜单失效、「有失效」筛选行旁一键禁用/删除、分组管理区分「删标签」与「删该组全部书源」 | Accepted（2026-10-22，用户裁决四项） | 本次新增 |
| [0060](0060-rule-dialect-alignment.md) | 规则方言对齐（M17 真源触发）：`@js:`/`<js>` 脚本内 `{{…}}`/`@get:` 先展开、规则产出的 URL 先切 `,{…}` 再绝对化、音频地址形态校验 | Accepted（2026-10-22，用户指令「开始修复引擎缺口」；632 源普查） | 本次新增 |
| [0061](0061-playback-http-and-webview.md) | 播放后端 / 明文 HTTP / WebView：Windows 改用 media_kit（libmpv LGPL 白名单）、`allowPlainHttp` 独立开关（页面与媒体共用）、headless WebView 端口与回落、沙箱 `book` 对象 | Accepted（2026-10-22，M17 真源复测；用户裁决三项） | 本次新增 |
| [0062](0062-audio-phase-two.md) | 听书二期（M24）：`webView` 的 POST/body、`book` 方法面（变量表复用 + `setType` 族语义缺失登记）、HLS 现状（Android 可播 / Windows 随包 libmpv 无 HLS demuxer）、Windows SMTC（`audio_service_win`，无时间轴）、TTS 句级高亮 | Accepted（2026-10-23，M24；用户指令，附双端探针证据） | 本次新增 |
| [0063](0063-cloud-tts-proposal.md) | 云 TTS：引擎抽象、凭据存储、合成与缓存、播放接线、六项待裁决 | **Proposed**（2026-10-23，M24-P6 立项；未裁决前不实现） | 本次新增 |
| [0064](0064-audio-page-follows-structure-only.md) | 播放页只跟随「结构状态」：`AudioReaderSkeleton` 投影 + `select`，位置 tick 只重画滑条一行；Windows 的缩略图 / AXTree 日志登记为插件与嵌入层噪声，不用 `ExcludeSemantics` 换安静 | Accepted（2026-10-23，Windows 实跑听书源日志） | 本次新增 |
| [0065](0065-layered-ci-and-release-artifacts.md) | 分层 CI：L1 `verify`（每个 PR）/ L2 平台构建（main、tag、手动）/ L3 Release（tag）；产物 = Windows zip + 通用 APK + AAB + 未签名 iOS archive；macOS 本轮不做；签名材料不进 CI；发布只用 `gh` | Accepted（2026-10-23，用户要求「分层 CI + release 产物」） | 本次新增 |
| [0066](0066-shelf-groups-bookmarks-and-read-records.md) | 书架分组（独立 `book_groups` 表 + `books.groupId`）、书签（位置唯一键的 toggle）、阅读记录（每会话一行、≥60 s）、自定义封面与按书缓存 `scope_key`；schema v6→v7 一次迁移，交付分两批 | Accepted（2026-10-23，M19 规格前置，用户裁决四项） | 本次新增 |
| [0067](0067-three-release-channels.md) | 三条发布通道各自一个 workflow：`release.yml`（tag ↔ 版本强校验、正式 Release）、`beta.yml`（`-beta.<sha7>`、预发布）、`debug.yml`（`-debug.<sha7>.<时间>`、预发布）；构建抽成可复用 `build-artifacts.yml`，跨 workflow 用 `wait-for-verify` 等门禁绿 | Accepted（2026-10-23，用户要求拆分三条通道与各自版本号） | 本次修订 0065 |
| [0068](0068-m21a-webview-verification-and-cookie.md) | M21a：应用内可见 WebView 过人机验证 + Cookie 持久化（v8）与 WebView 双向同步 + 引擎兼容 A/B/C/D 四簇；新增 `ParseFailureKind.loginRequired` | Accepted（2026-10-23，M21a 规格前置；用户裁决四项） | 本次新增 |
| [0069](0069-engine-compatibility-gap-from-a-real-export.md) | 用一份「上游可用、本仓不可用」的真实导出定位引擎语法差距（G1–G9）：修 G1/G3/G4/G5/G7/G8，登记 G2/G6/G9 与封面 per-URL header | Accepted（2026-10-24，用户裁决「G1–G5+G7+G8 全做完，G6 登记」） | 本次新增 |
| [0070](0070-m20-rule-storage-and-in-book-search.md) | M20：四类规则一张表 + `kind` + JSON payload（未知键保留、坏 payload 标坏不丢）；书内搜索顺序预取 + 可停止 + 命中带偏移；净化接在 `replaceRegex` 之后、规则一变即作废正文缓存 | Accepted（2026-10-24，用户裁决三项 + 开工前四项增补） | 本次新增 |
| [0071](0071-rule-and-book-source-import-export.md) | 净化规则导入/导出（上游 `ReplaceRule` 数组、三入口、预览 + 逐条勾选、`name`+`pattern` 去重）与书源导出（全部/选中，用户态覆盖 payload）；净化按 scope 分正文/标题执行，`@js:` 替换一条规则一章一个 job | Accepted（2026-10-24，用户裁决四项：连 scope 与 `@js:` 一起做） | 本次新增 |
