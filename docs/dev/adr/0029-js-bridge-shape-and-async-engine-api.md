# ADR-0029 `@js:` 接入：引擎公开 API 转异步，JS 绑定形态**逐项**定义（`JsBridge` + 复用运行时的常驻 worker）

- **状态：** Proposed（待裁决；2026-10-11 架构师裁决草案 —— **实现前不得默认生效**）
- **日期：** 2026-10-11
- **关联：** C-SRC-2、C-SRC-3、C-SRC-9、C-PERF-4、C-ERR-1、ADR-0015、ADR-0025、
  `docs/dev/book-source.md` §6/§3 矩阵 #14、`docs/dev/testing.md` §4、`PLAN.md` §3.3/§3.4/§3.7、
  `tool/spike/README.md` §4

## 背景

`PLAN.md` §3.3/§3.4 要落地矩阵 #14（`@js:`）。开发组提出两个架构选项，二者都在等一条裁决：

| 选项 | 主张的做法 | 主张的收益 / 代价 |
|---|---|---|
| **1** | `RuleEngine.selectAll/extractAll/extractFirst` 改为 `Future<ParseResult<…>>`，`PageFetchService` 与 4 个 UseCase 加 `await`，1943 行引擎测试机械加 `await` | 结构不变、改动面大；但认为 `parse.*` / `crypto.*` / `http.*` **只能**是 Promise，同步写法的真实规则要登记为「已知缺口」 |
| **2** | 引擎保持同步，QuickJS 运行时 + 引擎同住常驻 worker isolate；`PageFetchService` 改成 job 协议 | 认为 `parse.*` / `log.*` / `crypto.*` 可同步，真实规则兼容性最好；代价是 page 服务调用形状、scope 跨 isolate 传递、链路与 Widget 测试装配全部重做（比 PLAN 3.3 更大） |

两个选项的事实前提**不成立**，这是本 ADR 存在的理由。取证（2026-10-11，`flutter_qjs_next 1.5.2`
本地 pub cache，Windows 11 / Flutter 3.47.7）：

1. **同步与异步不是引擎级属性，而是逐绑定的属性。** 桥接实现
   （`lib/quickjs/quickjs_runtime2.dart` 的 `initChannelFunctions`）把 JS 的
   `sendMessage(channel, msg)` 直接接到 Dart 闭包上并 **`return` 该闭包的返回值**：
   Dart 处理器返回普通值 → JS **同步**拿到；返回 `Future` → JS 拿到 Promise。
   官方 recipe `doc/wiki/recipes/async-bridge.md` 就是这个形态：Dart 侧
   `onMessage('ch', (args) async { … })`，JS 侧 `await sendMessage("ch", JSON.stringify(…))`。
   ⇒ 选项 1 里「`crypto.*` / `log.*` 只能 Promise」**是错的**，它们可以同步。
2. **`http.*` 在**两个**选项里都只能是 Promise。** Dart 没有任何同步网络原语；即使引擎住在
   worker isolate（选项 2），该 worker 也无法「阻塞等待」另一个 isolate 的 HTTP 回复。
   ⇒ `http.*` 不构成选项间的差异。
3. **`parse.*` 是否同步，等价于「引擎与 scope 住在哪」。** C-SRC-2 要求 JS 不在 UI isolate 上
   跑；因此 `parse.*` 只有在**引擎和 scope 的副本都在 JS 那个 isolate 里**才可能同步 ——
   这正是选项 2 的真实代价（每次求值都必须搬运 scope），而不是选项 1 的缺口。
4. **仓内语料对 `@js:` 的调用频次是零证据。** `test/fixtures/book_sources/*.json` 中
   `@js:` 出现 **0** 次（`fixtures/json/README.md` 记录的 211 条真实源扫描只覆盖 `@json:`）。
   ⇒ 「同步写法兼容性最好」在仓内**未经验证**，不能据此付结构重做的成本。
5. **运行时必须复用**（`tool/spike/README.md` §4 第 4 条：引擎创建成本不低），
   且 3.3 是 `flutter_qjs_next` 在 `lib/` 中的**首次真实 import** —— 现在 `pubspec.yaml`
   声明了它但无人引用，按 `PLAN.md` §6 陷阱 #1，「构建成功」对此毫无证明力。

## 决策

1. **采纳选项 1 的核心：`RuleEngine` 的公开求值 API 转异步。**
   `selectAll` / `extractAll` / `extractFirst` 返回 `Future<ParseResult<…>>`；
   `PageFetchService` 与 4 个 UseCase 相应 `await`；测试机械更新。
   理由不是「JS 天生异步」，而是 **C-SRC-2 强制 JS 至少跨一次 isolate 边界**，而 `@js:`
   可以出现在任何字段上，调用方无法「按规则串预判」——两条并行求值路径会让
   `book-source.md` §7 的失败语义出现第二份实现（`PLAN.md` §6 陷阱 #5）。分层结构不变
   （ADR-0025 不受影响）。
2. **JS 隔离形态：一个常驻 worker isolate + 复用运行时**（`tool/spike/README.md` §4 第 4 条），
   经**注入的抽象**暴露给 `domain/`：`RuleEngine` 只依赖 `JsBridge` 接口，
   `domain/` 不 import `flutter_qjs_next`（C-ARCH-7、ADR-0025 判据）。因此
   `testing.md` §4「单元测试用假 `JsBridge`」保持成立，1943 行引擎测试
   **不需要真实引擎**；真实引擎只出现在 `integration_test/` 与 `tool/spike/`。
3. **JS 侧形态逐绑定定义，且其唯一出处是 `book-source.md` §6。** 本 ADR 只定裁决，
   不抄数值、不抄表：
   - **同步**（JS 立刻拿到值）：只允许「在 worker 内可完成且开销小」的绑定，即
     `log.*`（发后即忘）、`crypto.*`（纯计算）；
   - **Promise**（规则必须 `await`）：`http.get/post`（唯一实现是 `core/network/HttpClient`，
     C-NET-1）、`parse.*`（引擎与 scope 在另一 isolate）。
4. **`parse.*` 的异步形态是裁决，不是「缺口」。** 它同时满足 C-PERF-4（重计算不阻塞 UI
   isolate 一侧的调用链）与「引擎 / scope 只住一处」；**同步写法 3.3 不实现**。
   仅当 **3.7 的真实语料回归**给出证据时，才允许以**新 ADR** 追加同步形态，不得就地放宽。
5. **3.3 的 `parse.*` 只承诺页级 scope**：worker 侧用页面原始 body 重建 scope；
   元素级 scope 无法跨 isolate。命中该边界时按 C-SRC-4 **显式失败并带 `rulePath`**
   （`js:parse-scope`），不得静默返回空值。该边界须写进 `book-source.md` §6。
6. **拒绝选项 2**（见 §备选方案）。

## 后果

- `RuleEngine` 的公开 API 发生**破坏性变更**（同步 → `Future`），必须记入 `CHANGELOG.md`；
  `naming.md` §4 的示例是 UseCase 签名，不受影响。
- `book-source.md` §6 需新增/补全**逐绑定 JS 侧形态**列（同步 / Promise、是否要求 `await`），
  以及 §决策 5 的页级 scope 边界；本文档不复述该表。
- `PLAN.md` §3.3 的验收增加两条：绑定形态逐项有测试；**单测走假 `JsBridge`**。
- 3.3 落地时**必须**补集成探针（真实引擎 + 真实 worker），不能只靠 `flutter analyze` /
  `flutter test` 通过 —— `PLAN.md` §6 陷阱 #1；`tool/spike/` 的 9 项探针继续作为引擎回归基线。
- **语料欠账（记入 `PLAN.md` §3.7 登记表）：** 仓内没有任何含 `@js:` 的真实源，
  矩阵 #14 因此无法按 §10 改「已确认」；3.7 之前必须先补至少 1 条含 `@js:` 的真实源样本。
- 3.8（同一书源并发上限）与 JS 容量直接耦合：worker 的引擎数与排队策略必须先定，
  否则桥接契约（决策 1/2）会随并发策略返工。**桥接契约冻结前必须先给出 3.8 的裁决。**

## 备选方案

| 方案 | 否决原因 |
|---|---|
| **选项 2**：引擎 + 运行时同住常驻 worker，引擎保持同步 | ① 唯一收益（同步 `parse.*`/`log.*`/`crypto.*`）中，`log.*`/`crypto.*` 在选项 1 下**本来就能同步**（背景 1）；② `http.*` 两边都是 Promise（背景 2），不构成差异；③ 唯一真收益是同步 `parse.*`，而它要求每次求值都搬运 scope —— 正是它自己声称要避免的问题，且与 C-SRC-9 的并发调用、3.8 的并发预算冲突（单 worker 串行化）；④ 让 Widget/单元测试改用真实引擎 + worker，与 `testing.md` §4 的假 `JsBridge` 策略直接冲突；⑤ 改动面（page 服务调用形状、scope 传递、链路、测试装配）远大于收益，命中 `PLAN.md` §6 陷阱 #5 |
| 在**主 isolate** 上跑 JS，保持引擎同步 | 直接违反 C-SRC-2（JS 必须在独立 Isolate 中执行）；runaway 会拖死 UI |
| 保留同步 API，另加一条 `…Async` 入口给 `@js:` | 两条并行求值路径 = §7 失败语义的第二份实现，`|`/`&&`/`%%`、scope 方向判定、ADR-0026 降级都要各写一遍，必然漂移（`PLAN.md` §6 陷阱 #3、#5） |
| 把 `parse.*` 做成「同步 + 元素级 scope 全支持」 | 需要把 worker 内的 DOM 与主 isolate 的 DOM 视为同一份状态（C-SRC-9 的可并发调用前提会被破坏），且无仓内证据表明真实规则需要它（背景 4） |
