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
