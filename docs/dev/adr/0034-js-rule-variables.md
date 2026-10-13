# ADR-0034 M1 规则变量：宿主侧一份表 + 每个 job 一份快照（`@put:` / `@get:` / `java.put` / `java.get`）

- **状态：** Accepted（2026-10-12 架构师裁决；本 ADR 是 ADR-0030 §决策 5(a) 的重新裁决）
- **日期：** 2026-10-12
- **关联：** ADR-0030 §决策 4/§决策 5(a)、ADR-0029、ADR-0026、C-SRC-2、C-SRC-3、C-SRC-9、
  C-ARCH-7、C-DOM-*（无）、`docs/dev/book-source.md` §3 矩阵 #15–#19 / §4 / §6、
  `PLAN.md` §3.4 / §3.7

## 背景

`PLAN.md` 3.4 的收口与 `book-source.md` §3 的矩阵 #15–#19（M1）要落地两类变量语法：

| 语法 | 谁读写 | 上游实现 |
|---|---|---|
| `@put:{key:rule}` / `@get:{key}` | **引擎**（宿主侧） | `AnalyzeRule.SourceRule.init` 摘掉 `@put` 并逐个求值（`AnalyzeRule.kt:641-686`），`makeUpRule` 里换成 `@get` 的值（`AnalyzeRule.kt:736-762`） |
| `java.put(key,value)` / `java.get(key)` | **脚本**（worker 内） | `bindings["java"] = this`，即同一个 `AnalyzeRule`（`AnalyzeRule.kt:835`），`put`/`get` 见 `:801-825` |

上游把变量存在「chapter → book → ruleData → source」这条链上（`AnalyzeRule.put` / `get`），
最终落到 `BaseSource.put` 的持久缓存（`BaseSource.kt:283-295`，键 `v_<sourceKey>_<key>`），
因此**同一个书源**里，脚本写下的变量引擎读得到，引擎写下的脚本也读得到。

ADR-0030 §决策 4 已经定过一半：变量存 **Dart 侧、按 `sourceId` 键控**、且**与运行时同 isolate**
（这样 `java.put` / `java.get` 能保持 §6 要求的**同步**取值）。但同一 ADR §决策 5(a) 把
「M1 的 `java.put` / `java.get` 落地」列为**必须重新裁决**的触发条件：按源变量开始 load-bearing 之后，
「单常驻 worker + 跨源共用 `globalThis`」这一形态必须重新审视，**不得就地放宽**。

## 决策

1. **变量表住在宿主 isolate，一个 `JsVariableStore`，按 `sourceId`（书源 URL）键控。**
   - 引擎读表：`@get:{key}`、`{{变量名}}`；引擎写表：`@put:{key:rule}`。
   - 脚本读表：`java.get(key)`；脚本写表：`java.put(key, value)`——但**写发生在 worker 内**，
     见下一条。
   - 每次 `JsJob` 带一份该源的**快照**（`JsJob.variables`，不可变副本）；worker 用它在自己的
     isolate 里**同步**回答 `java.get` / `java.put`，不需要任何跨 isolate 往返——这正是
     ADR-0030 §决策 4 要保留的性质，也是「变量表不在 worker 里」与「`java.*` 仍是同步」能同时成立的
     原因：**worker 不是表的持有者，只是这次 job 的读者与暂存者**。
   - job 结束时 worker 把**它这一份**变量表随结果信封一起交回（`type: 'result'` 的 `variables`），
     桥按 `job.source.url` merge 回宿主表。清空用 `null` 表达（`java.put(key, null)`），
     与「写了空串」区分开。
2. **生命周期：一份表随 Provider 作用域存在（`jsVariableStoreProvider`），不落盘、不跨作用域。**
   这是与上游的**有意差异**：上游把变量持久化在 book / source 上（`BaseSource.kt:283-295`），
   本仓在 Phase 5 之前**没有 Book 实体**，也就没有可以挂载的持久载体；
   先落「一次操作内按源共享」，把持久化留给 Phase 5 的阅读进度 / 书架一起裁决。
   `@put` / `@get` 的**同源**语义（本次落地的全部用法）不受影响。
3. **`key` 绑定只在 URL 规则上存在。** 上游只在 `AnalyzeUrl.evalJS` 里绑 `key`
   （`AnalyzeUrl.kt:377`），`AnalyzeRule.evalJS` 不绑（`AnalyzeRule.kt:830-846`）。
   本仓照此执行：URL 渲染时把关键词作为 `key` 交给 job，其余 job 传 `null`，
   前奏**删掉**该全局名——所以字段规则里写 `{{key}}` 报 `js:error`，而不是悄悄拿到空串。
   这不是「多给一个绑定」，而是把 `{{key}}` 让给 §4 的既有模板语义（关键词只编码一次）
   之后，URL 里的脚本**唯一**能拿到关键词的入口。
4. **`java.*` 不占 §6 的「单条规则内 JS 调用次数」额度。** 额度数的是**跨出 worker 的调用**
   （`log.*` / `http.*` / `parse.*`）；`crypto.*` 与 `java.*` 都在 worker 内完成，进不了这个计数。
5. **跨源 `globalThis` 仍共用（ADR-0030 §决策 4 的偏离继续有效）。** 本次落地**不**引入引擎池或
   按源 `soft` reset：变量本身已经按 `sourceId` 隔离，剩下的风险只是「规则往 `globalThis` 写东西」，
   而那是 §6 白名单之外的行为；ADR-0030 §决策 5 的其余触发条件（真实语料出现跨规则复用全局、
   3.8 之后有实测吞吐数字）继续有效。

## 后果

- `JsBridge` 契约**不变形状**：仍然只有 `evaluate(JsJob)` / `dispose()`，容量参数仍不进契约
  （ADR-0030 §决策 2 不受影响）；新增的是 `JsJob` 的两个字段（`variables` 快照、`key`）
  与结果信封里的 `variables`——都是**数据**，不是策略。
- 宿主侧的异常边界不变：`JsVariableStore` 是纯内存、同步、不抛的（C-ERR-1/2 不涉及新 `catch`）。
- C-SRC-9（可并发调用）成立：表没有跨 `await` 的可变状态被观察——每次读 / 写都是同步的一段；
  两个并发 job 各持一份快照，回程按 `sourceId` merge，最后写入者胜（上游同样是「后写覆盖」）。
- `core/js/` 因此多一个文件（`js_variables.dart`）与一个 Provider；`book-source.md` §6 需要新增
  「变量表在哪、谁在写」的一段，**数值与语义的唯一出处仍是 §4 / §6**，本 ADR 不复述。
- `java.timeFormat`（矩阵 #17 的同族，属 `updateTime`）**不在**本次范围，仍按 §6 表里的分期执行；
  未知动词由前奏变成 JS `Error`（显式失败，C-SRC-4）。
- 未闭环项登记到 `PLAN.md` §3.7：M1 各行的矩阵状态仍为「待验证」（真实书源回归未做）、
  `java.get('bookName' | 'title')` 的上游特例需要 Book/Chapter 上下文（Phase 5）、
  变量不持久化（本 ADR §决策 2）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| **变量表住在 worker isolate**，`JsBridge` 新增异步 `put/get` 端口供宿主读写 | 严格照 ADR-0030 §决策 4 的字面顺序，但把「引擎的一次 `@get:`」变成一次跨 isolate 往返，而宿主侧**没有**同步读取的余地（引擎 API 是异步的，但 `@put` / `@get` 会成倍放大 worker 的串行队列——§8 的预算只有 3、worker 只有 1）；且契约多两个方法，3.8 之后的实现替换要连带改契约 |
| **变量表住宿主，`java.put` / `java.get` 改成 Promise** | 与 §6 的「同步」形态冲突，需要登记为差异；同步写法在真实语料里是否存在**未测量**，为一个未验证的假设付契约成本不合理 |
| 按 ADR-0030 §决策 5 的首选（引擎池 + 按源 `soft` reset）一起做 | 触发条件是「按源变量 load-bearing」，而本次落地的变量已经按源隔离；池化的代价（背景 2/3）没有对应的实测收益，且它会改动 `JsBridge` 的实现而非契约——留到触发条件真正满足时再做 |
| 变量持久化到 `shared_preferences` / Drift | 需要新表 / 新键与清理策略，且 `PLAN.md` 尚未给「书源变量」定归属；与 Phase 5 的 bookshelf 数据一起裁决更省一次迁移 |
