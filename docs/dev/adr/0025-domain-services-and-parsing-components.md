# ADR-0025 domain 允许无状态领域服务与解析构件（登记 F1 偏离）

- **状态：** Accepted（2026-10-11 **架构师 PR 评审指令裁决（F1）**；本 ADR 是记录，不是作者自决）
- **日期：** 2026-10-11
- **关联：** C-ARCH-1、C-ARCH-6、C-ARCH-7、C-SRC-1、C-SRC-9、C-NET-8、C-DEP-1、ADR-0019、
  ADR-0021、`docs/dev/architecture.md` §1/§3、`docs/dev/naming.md` §6、`PLAN.md` 2.4

## 背景

`architecture.md` §3 对 `domain/` 的允许清单是**封闭且明确**的：Entity、Value Object、
Repository 接口、UseCase、领域异常。Phase 2 落地后，`lib/features/book_source/domain/` 下出现了
三类该清单未列的构件：

| 文件 | 性质 | 谁要求它存在 |
|---|---|---|
| `domain/page_fetch_service.dart` | 无状态领域服务：编排 `core/network/HttpClient`、`RuleEngine` 与 `url_template`，并持有 `book-source.md` §7 失败语义的唯一实现 | `PLAN.md` 2.4（四个 UseCase 共享同一失败规则） |
| `domain/rule_engine/rule_engine.dart` | 纯 Dart 解析引擎 | C-SRC-1（解析引擎必须纯 Dart、无 Flutter/UI 依赖） |
| `domain/url_template.dart` | 纯函数模块（`renderUrlTemplate` / `resolveAbsoluteUrl`） | C-SRC-5（URL 渲染只有一处实现） |

偏离**未登记**：`docs/` 全文 grep `PageFetchService` 零命中，即规范与代码已经不一致。
架构师在 PR #2 复审中把它判为**阻断合入项（F1）**：这与 ADR-0021 同类（当时「模型放
`domain/` 但带 JSON 注解」同样必须先开 ADR），而这次既没开 ADR 也没改文档。
按 `docs/dev/adr/README.md` 规则 3，改动 `docs/dev/` 规范的既有结论必须由 ADR 承接，
**不能靠「清单只是举例」解释**。

## 决策

1. **采纳架构师的选项 (a)**：`architecture.md` §3 的 `domain/` 允许清单**增加一类**
   「**无状态领域服务与解析构件**」，并回链本 ADR。
2. **判据（必须逐条满足，可被 review 判定）：**
   - **无状态**：没有跨调用的可变状态，一个实例可并发调用（C-SRC-9）；
   - **只依赖 `core/` 抽象与纯 Dart 依赖**：`HttpClient` / `AppLogger` / `html` /
     `cascadia` / `json_path`；**禁止** import Flutter、平台 API 与 `data/`
     （C-ARCH-7、C-ARCH-1）；
   - **不承担仓储职责**：读写持久化仍是 `domain/` 接口 + `data/` 实现（C-NET-8）。
3. **当前落入该类的文件就是上表三个**；今后新增同类文件必须在 PR 描述中说明它属于本类
   并逐条对照第 2 条判据（与 ADR-0021 §决策 3 的「例外不扩散」同一精神）。
4. **不采纳选项 (b)**（把抓取移入 `data/`、`domain/` 只留接口），理由：
   - `RuleEngine` 与 `url_template.dart` 仍是 §3 清单外的构件，只修 `PageFetchService`
     一处，规范与代码依旧不一致，同一个 F1 会在下次 review 被重新发现；
   - 抓取与规则读取共享同一套失败语义（`book-source.md` §7），拆到两层会把 §7 的
     **唯一实现点**分裂成两处，与 ADR-0013 §1（一个事实只定义一次）冲突；
   - `RuleEngine` 位于 `domain/` 已是 Phase 2 的既成事实且被复审接受（`PLAN.md` 2.2），
     本 ADR 只是把它**显式登记**，不是新开例外。
5. `naming.md` §6 已有 `XxxService` / `XxxEngine` 命名行，无需改动；本 ADR 只补分层归属。

## 后果

- `architecture.md` §3 的 `domain/` 行与例外段同步（附回链）；`lib/features/book_source/`
  **目前仍然没有 `data/` 层**，这是本例外的直接结果而非遗漏。
- 这不是「`data/` 可以缺席」的许可：ADR-0021 §后果的**复审触发条件 (3)** 仍然有效——
  `data/` 出现第一个真实消费方（DTO / DataSource / RepositoryImpl）时，必须重评本 ADR 与
  ADR-0021。
- 不新增依赖（C-DEP-1 不涉及）；不改变任何 `C-*` 的判定方式；不影响 M0/M1/M2 分期。
- 覆盖率：本类文件位于 `lib/core/**` 或 `lib/features/*/domain/**`，仍须满足 ADR-0019
  （阈值 + 未测量源文件检查），不得因「服务 / 引擎」而进入 allowlist。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| (b) 抓取移入 `data/`，`domain/` 只留接口 | 只解决三个构件中的一个；`RuleEngine` / `url_template` 仍是未登记偏离，且把 §7 的唯一失败实现分裂到两层 |
| 不改规范，只在 review 里口头接受 | 规范与代码仍然不一致，下一个人照 `architecture.md` §3 复查时会再次判为违规 |
| 把 `PageFetchService` 下沉成 `core/` 工具 | 它有业务语义（书源字段的规则路径与失败语义），`core/` 明令「无业务语义」（C-ARCH-6） |
| 删除 `PageFetchService`，把失败规则抄进四个 UseCase | 四处复制 `book-source.md` §7 的语义，正是 ADR-0013 §1 禁止的重复定义 |
