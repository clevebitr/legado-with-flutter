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
| [0002](0002-parse-result-contract.md) | 错误契约：`ParseResult` 与 `ParseFailureKind` | Accepted | D9 |
| [0003](0003-drift-as-primary-storage.md) | Drift 作为主持久化方案 | Accepted | D7 |
| [0004](0004-m3e-theme-tokens-and-dynamic-color.md) | 主题令牌以 `m3e_design` 为准，取色用 `dynamic_color` | Accepted | D4、D5 |
| [0005](0005-no-get-it.md) | 不引入 `get_it`，依赖注入统一 Riverpod | Accepted | D6 |
| [0006](0006-logging-facade.md) | 日志统一 `logger` + `core/logging` 门面 | Accepted | D8 |
| [0007](0007-license.md) | 许可证：GNU GPL-3.0 | Accepted | D15 |
| [0008](0008-single-js-engine.md) | JS 引擎只保留 `flutter_js_plus` | ⚠️ **部分失效（待裁决）** | D10 |
| [0009](0009-golden-testing-builtin.md) | Golden 测试使用内置 `matchesGoldenFile` | Accepted | D12 |
| [0010](0010-lint-baseline-and-gates.md) | lint 基线、无效规则清理与门禁入口 | Accepted | D13、D14 |
| [0011](0011-builtin-navigator-routing.md) | 路由使用内置 `Navigator`，暂不引入 `go_router` | Accepted | 本次新增 |
| [0012](0012-docs-single-source-of-truth.md) | 文档单一来源（SSOT）与约束条目 ID 方案 | Accepted | 本次审计 |
| [0013](0013-single-source-for-gates-and-versions.md) | 门禁阈值与版本基线各自只有一处定义 | Accepted | D11、D16 |
| [0014](0014-book-source-minimal-scope.md) | 书源功能范围：对标原版阅读的最小实现分期 | Accepted | 本次新增 |

---

**最后更新：** 2026-10-10
