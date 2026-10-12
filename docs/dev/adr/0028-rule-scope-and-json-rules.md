# ADR-0028 规则 scope 显式化为 `RuleScope`，`@json:` 与默认 / `@css:` 规则共用一条读取路径

- **状态：** Accepted（2026-10-11 **架构师裁决「RuleScope」**；细节由本 PR 登记，见 §决策 2/3/4/5）
- **日期：** 2026-10-11
- **关联：** C-SRC-4、C-SRC-6、C-SRC-8、C-SRC-9、C-ARCH-7、ADR-0013、ADR-0016、ADR-0025、
  `docs/dev/book-source.md` §3.2/§3 矩阵 #13/#30、`PLAN.md` 3.2、`RuleEngine`、`PageFetchService`

## 背景

矩阵 #13（`@json:`，含裸 `$.` / `$[`）是 **M0** 语法，3.2 之前一直被拒绝为
`unsupportedRule`；`json_path` 自 Phase 1 起就声明在 `pubspec.yaml` 里，却没有任何使用。

拒绝的原因不是「懒得写 JSONPath」，而是**接口形状**：`RuleEngine` 的公开面是

```dart
ParseResult<List<Element>> selectAll(String rule, Node scope, ...);
```

即「吃 `Node`、吐 `Element`」。而 JSON 规则需要的是另一种 scope，且**列表规则**的 JSON 形式
（真实书源的 `bookList: "$.data.list[*]"`）产生的是 JSON 对象、不是元素——后续字段规则要在
这些对象上继续读。把 JSON 折成 `Element` 只能伪造 DOM，会污染 C-SRC-8 的失败定位与矩阵 #8 的
提取语义。

同时，**DOM / JSON 不匹配时没有定义结果**。若让它返回「成功且为空」，就正好落进 C-SRC-4
禁止的静默忽略：书源规则写错、页面换成了 JSON 接口，界面只会显示「没搜到」。

架构师因此裁决：显式引入 `RuleScope`，让「规则读什么」成为类型的一部分。

## 决策

1. **`RuleScope` 是密封的 scope 类型**（ADR-0016 的形态）：
   `DomScope(Node node, {String? body})` 与 `JsonScope(Object? value)`。`RuleEngine` 的公开
   方法接收 `RuleScope`，列表规则返回 `ParseResult<List<RuleScope>>`，让**每个匹配成为下一级的
   scope**，与 `book-source.md` §3.2 的分层读取一致。
2. **整页是「带原始 body 的 DOM scope」。** `PageFetchService.fetch` 把解析出的 DOM 与原始
   body 一起放进 `RuleScope.dom(..., body: ...)`，于是**一页可同时回答两类规则，由规则决定**
   — 同一个响应的 `bookList`（`$.data…`）与 `content`（`class.content@text`）不必约定同一种。
   架构师草图里的做法是让 `PageFetchService` 按规则前缀选变体；本 PR 把选择下移到分支求值。
   保留该形态的理由是两条（2026-10-11 复审确认）：
   （a）矩阵 #7 的 `-` 前缀无需在服务层再判一次；
   （b）`jsonDecode` 的失败语义留在引擎内，才能成为带字段路径的可定位 `parseFailed`
   （C-ERR-1、C-SRC-8），而不是分裂到服务层。

   > **2026-10-11 复审更正（PM）：** 本节初稿曾以「一条规则可能同时含两种 scope 头
   > （`$.a||class.b`）而前缀选不出来」为理由之一。**该理由不成立，已删除：** 实测
   > `extractAll('$.a||class.b@text', RuleScope.dom(htmlDoc, body: html))` 返回 `parseFailed`，
   > 因为 `||` 遇到候选失败即终止（见 §决策 3 与 `RuleEngine._selectAll`）。混合 scope 头的
   > `||` 候选**不做回退**，属**响亮失败**，由 `extractAll_givenMixedScopeOr_returnsParseFailed`
   > 钉住。若将来真实语料确实需要跨 scope 回退，须另立 ADR 修改 `||` 语义，不得就地假设。
3. **scope 与规则的匹配按方向判定，且不对称**（2026-10-11 复审收窄）：
   - **JSON 规则**打在**没有 body 的 DOM scope**（元素，或其匹配项）上 → `parseFailed`；页面
     body 不是 JSON（`jsonDecode` 失败）→ 也 `parseFailed`。语法本身是支持的，只是这个 scope
     回答不了，正是 §7 的「规则无匹配」，**不是** `unsupportedRule`、更不是空结果。
   - **DOM 规则**打在 JSON 页上 → **空结果（success）**，不是失败：页面仍是一份解析出来的
     文档（JSON 文本进了 body），选择器零匹配就是矩阵 #8 的「成功但为空」。这一条**不得**写成
     「scope 答不了就 `parseFailed`」。
   - 只有「匹配项本身就是 JSON 值」的情况连 DOM 都不存在，按第一条处理。
   非顶层字段仍按 ADR-0026 降级为「置空 + warning」，所以不会变成无记录的 `null`。
4. **跨 scope 的合并显式失败。** `$.a&&class.b` 报 `parseFailed`：`book-source.md` §3 的 `&&`
   注记已经写明连接符只合并**同种**规则，异构结果是未定义的，不猜一种语义。
5. **JSON 值 → 值规则的结果**：字符串原样；数字与布尔按 JSON 的写法；`null` 与空字符串**不产生
   值**（与矩阵 #8 的空提取同口径）；对象按 **JSON 文本**返回。上游用 Java 的 `toString`
   （`{a=1}`）不可复现、也不是任何规则能依赖的形式，故取无损形式。真实 JSON 语料
   （`test/fixtures/json/`）中的取值目前均为标量，故**对象形态仍只有单测覆盖，待后续
   真实源确认**（`book-source.md` §10）。

   > **复审更正（2026-10-12，随 `PLAN.md` 3.7 的真实源回归）：** 本条初稿把**数组**与对象并列，
   > 都写成「按 JSON 文本返回」，**已不成立**。实测（猫耳FM JSON 接口源）与上游源码都表明
   > **列表要逐元素展开**：取值规则按 `AnalyzeByJSonPath.kt:83-87`（`for (o in obj)
   > result.add(o.toString())`）展开，列表规则按 `:137`（`read<ArrayList<Any>>`）把命中的列表
   > 当成**条目列表**；否则 `bookList: $.info.Datas` 只会得到一个「数组」，真实源的搜索段直接
   > 空掉（回归修前 1 条且书名为空，修后 30 条）。**对象仍保持 JSON 文本**并保留差异登记（上游
   > `Map.toString` 不可复现）。行为规格的唯一出处是 `docs/dev/book-source.md` §3 的 #13 注记，
   > 本节只负责决策与更正记录。
6. **`@json:` 必须在按 `@` 切段之前识别**：JSONPath 的过滤器里既有 `@`（`$[?(@.a)]`）也有 `&&`
   （`$[?(@.a==1 && @.b==2)]`），先切段就会把一条路径切碎。

## 后果

- `json_path` 从「已声明未使用」变为实际使用；`tech-stack.md` §2 早已登记该依赖，**不新增依赖**
  （C-DEP-1 不涉及）。
- 矩阵 #30（提取段里的嵌套规则）**仍未实现**，边界因此明确：`class.a@json:$.b` 仍报
  `unsupported:@json:`，元素 scope（不带 body 的 `DomScope`）上的 JSON 规则报 `parseFailed`。
  两者都要动到提取契约，不在 3.2 范围内。
- 4 个 UseCase 与 `PageFetchService` 的 scope 参数由 `Node` 换成 `RuleScope`；`domain` 行覆盖
  由 794 增至 881 行，阈值不变（ADR-0019）。- `RuleEngine` 满足 ADR-0025 §2 的三条判据：无状态（scope 只读、不缓存）、只依赖 `core/` 抽象与
  纯 Dart 依赖（`html` / `cascadia` / `json_path`）、不承担仓储职责。
- **JSON 离线语料已加入**：`test/fixtures/json/`（3 页）+ `test/fixtures/book_sources/legado_json_source.json`，
  由 `chain_givenJsonSourceAndCorpusPages_replaysEveryStage` 驱动生产链路回放。为找到「逐字保留
  即可跑通」的 JSON 书源，扫描了 211 条公开真实书源：用 `@json:` 的只有 **2** 条，且它们的 URL
  规则都用 M1 的 `{$.x}` / `{{$.x}}` / `@put:` / `@get:` 模板，**0 条在 M0 可逐字回放**。因此该
  语料有**唯一一处偏离**：`ruleSearch.bookUrl` 与 `ruleToc.chapterUrl` 两条 URL 规则改写为等价的
  纯 JSONPath，其余规则逐字保留；原文与理由见 `test/fixtures/json/README.md`。
- 上述扫描同时说明 **#16–#19（`@put:` / `@get:` / `{}` / `{{}}` URL 模板）的优先级值得在 3.3
  之后重排**：JSON 接口源普遍用它们拼书址，缺了它们，真实 JSON 书源在 M0 下无法完整回放。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 保留 `Node scope`，另加 `extractJson(body, rule)` 平行入口 | 两条读取路径会各自漂移（ADR-0013 §1），且表达不了 JSON 列表规则（`bookList: $.data.list[*]`），真实 JSON 接口的书源用不了 |
| `@json:` 只作为提取段标志 | 同上；且响应本身就是 JSON 的站点（`searchUrl` 返回 JSON）整个用不了 |
| 把 JSON 结果折成 `Element` | 伪造 DOM 会污染 C-SRC-8 的失败定位与矩阵 #8 的提取语义 |
| `PageFetchService` 按规则前缀选变体（保持裁决草图原文） | `-` 前缀要再判一次；`jsonDecode` 的失败语义会分裂到服务层，无法成为带字段路径的可定位失败（见 §决策 2）。**注意：** 混合 scope 头的 `\|\|`（`$.a||class.b`）两种形态都**不支持**——它遇到候选失败即终止（实测），不是保留本形态的理由 |
| DOM / JSON 不匹配时返回「成功且为空」 | 正好是 C-SRC-4 禁止的静默忽略：规则写错与「真的没搜到」在界面上无法区分 |
