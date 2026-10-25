# ADR-0071 规则与书源的导入导出，以及净化的执行面（scope + `@js:` 替换）

- **状态：** Accepted（2026-10-24，用户裁决四项：净化导入导出**顺带**实现 scope 与 `@js:` 替换；
  书源导出做「全部 + 选中」；规则导入走「预览 + 逐条勾选」；网络导入三入口全开）
- **日期：** 2026-10-24
- **关联：** ADR-0070（规则表与净化接线）、ADR-0052 §决策 5（导入预览与逐条勾选）、
  ADR-0040 §决策 4（payload 原样存储）、ADR-0042（跨 feature 端口）、ADR-0026（降级为 warning）、
  ADR-0031/0033、C-SEC-2/5、C-PERF-5、C-NET-1/6、`docs/dev/book-source.md` §4.3/§6/§11

## 背景

用户给了一份上游导出的 `净化规则.json`（20 条 `ReplaceRule`），要求：净化规则**能导入能导出**
（网络 + 本地文件），**书源也能导出**。把语料逐条摊开看，这份文件暴露了三件事：

| 语料里的东西 | 本仓当时的状态 |
|---|---|
| `replacement` 大量以 `@js:` 开头（`@js:if (result.slice(0,1)=="第") {…}`） | **跳过 + warning**（ADR-0070 增补 §7 登记） |
| `scopeTitle: true` / `scopeContent: false`（数字标题、全角字符这类只作用于标题的规则） | 字段进 `extra` 保留，但**执行时不区分**：所有启用规则都往正文上套 |
| `group` / `order` / `id` / `timeoutMillisecond` | 只有 `order` 有对应列（`sort_order`），其余进 `extra` |

也就是说：只做「搬运」的话，这份文件导入后 18/20 条实际不生效，其中 6 条还会把**正文改花**
（标题专用规则套在正文上）。用户因此裁决连执行面一起做。

## 决策 1 净化规则的交换格式就是上游的 `ReplaceRule` 数组

**导出**是一个 JSON 数组，每个元素是上游 `ReplaceRule` 的键面（本 ADR 是映射的唯一出处）：

| 本仓 | 上游键 | 说明 |
|---|---|---|
| `rules.name` | `name` | |
| `payload.pattern` | `pattern` | |
| `payload.replacement` | `replacement` | 可能是 `@js:` 表达式（§决策 5） |
| `payload.isRegex` | `isRegex` | |
| `payload.timeoutMs` | `timeoutMillisecond` | 上游默认 3000；本仓默认空（用沙箱默认超时） |
| `payload.group` | `group` | 上游的分组，只做展示 |
| `payload.scopeContent` | `scopeContent` | 默认 `true`（上游默认） |
| `payload.scopeTitle` | `scopeTitle` | 默认 `false`（上游默认） |
| `rules.sortOrder` | `order` | **导出时以行的 `sort_order` 为准**（用户拖过顺序才反映真实顺序） |
| `rules.isEnabled` | `isEnabled` | 导出时以列值为准（用户启停是列上的用户态） |
| — | `id` | **不导出**：上游的主键是它自己库里的 id，带过去只会撞号 |

`payload.extra` 里剩下的键（上游的 `excludeScope`、`useTo`…）**原样写回**，因此
「导入一次再导出」对未知键是无损的（与 ADR-0021 的书源 `extra` 同一立场）。

**导入认三种形态**，因为上游自己就吃三种：

1. 现代形态：数组里直接是 `ReplaceRule` 的键面（本 ADR 上表）；
2. 遗留形态（上游 `ReplaceAnalyzer.jsonToReplaceRule` 兼容的那一份）：`regex` → `pattern`、
   `replaceSummary` → `name`、`useTo` → 作用范围、`enable` → `isEnabled`、`serialNumber` → `order`；
3. 单个对象（不是数组）：当成只有一条的数组。

`schema` 之外的东西一律**不猜**：`pattern` 缺失/非字符串 → 该条在预览里标「不可用」并能被取消勾选，
而不是整份文件失败（ADR-0052 §决策 5 的同一口径）。

## 决策 2 导入：三入口 + 预览 + 逐条勾选 + 「同名同 pattern 就更新」

- **来源**：粘贴文本 / URL / 本地文件。体积上限沿用书源导入的 **32 MB**（C-SEC-5、C-PERF-5：
  先比字节数再解析，绝不一次性吃进无上限的文本）。URL 走 `core/network/HttpClient`（C-NET-1），
  明文 `http://` 由既有的 `allowPlainHttp` 开关决定（C-SEC-2）。
- **预览**：每条显示「名称 · 作用范围 · 是否本版可执行」，不可用的默认不勾选；勾选后才写库。
- **去重键 = `name` + `pattern`**（同一个名字下 pattern 改过算不同规则）：命中已有行 → 改写
  name/payload/isEnabled 与 `sort_order`（= 文件里的 `order`）；没命中 → 新增。报告分「新增 / 更新 / 跳过」。
- 导入**不删除**任何现有规则：这份文件里没有的规则保持原样（删除是用户的显式动作）。
- 导入会作废已缓存的成品正文（与 ADR-0070 增补 §7 同一理由：净化规则变了）。

## 决策 3 书源导出：全部 + 选中，用户态覆盖 payload

- 入口两个：书源列表页 AppBar 的「导出全部」，以及多选工具栏的「导出选中」。
- 输出是上游 Legado 的源数组。payload 本来就是**原样存储**的导入 JSON（ADR-0040 §决策 4），
  所以「未知键保真」不是新增工作：导出时只把两列用户态覆盖回去 ——
  `enabled` ← `book_sources.is_enabled`、`customOrder` ← `custom_order` ——
  因为文件里的 `enabled` 是**导入那一刻**的值，而用户后来启停过。
- 写文件走 `file_selector` 的保存对话框（`core/platform/` 的既有端口，本 ADR 把它从
  「书源专用」改名为通用 `JsonFileSaver`）；用户取消不是失败。

## 决策 4 净化的作用范围：正文 / 标题各扫各的

- `PurgeRule` 带 `appliesToContent` / `appliesToTitle`；`scopeContent` 缺省 `true`、
  `scopeTitle` 缺省 `false`，与上游一致。
- `ContentPurifier` 分成两个入口：`purgeContent(text, context)` 与 `purgeTitle(title, context)`，
  各自只跑声明了该范围的规则，顺序仍是用户的 `sort_order`。
- **正文**：位置不变（`replaceRegex` 之后、写缓存前，ADR-0070 增补 §7）。
- **标题**：在**装配根**把 `book_source` 的目录映射成阅读器的 `ReadingChapter` 时净化。
  这样阅读器里「目录 sheet / 正文头标题 / 进度里存的章节名 / 搜索命中的章节名」是同一份净化后的
  标题，不需要在每个展示点各接一次。
- **不净化**的标题：书源详情页的目录预览、书架上「最新章节」——它们来自 `book_source` 的目录缓存
  而不是阅读器的映射点，净化它们会让同一章在两处显示成两个名字（登记在 `roadmap.md` §3.7，触发 =
  用户反馈「详情页标题没被净化」）。
- 标题净化改变标题长度时，`reading_progress.chapter_name` 会跟着变；章节**地址**不变，所以定位不受影响。

## 决策 5 `@js:` 替换表达式：一条规则一章**一个** job

上游的 `@js:` 替换是「每个匹配跑一次脚本」（`RegexExtensions.kt:24-70`，Rhino 内联）。本仓的沙箱是
独立 isolate，逐匹配一个 job 会让一条「全角字符」规则在一章里发起上千次跨 isolate 调用，配额与时延都
不可接受。做法：

- 一条规则在一章里的**所有匹配文本**合成一个数组，塞进**一次** job：

  ```js
  var __matches = [<JSON 数组>];
  var __out = [];
  for (var __i = 0; __i < __matches.length; __i++) {
    var result = __matches[__i];
    __out.push(eval(<引号包裹的替换脚本>));
  }
  __out;
  ```

  用 `eval` 的**完成值**取每条替换结果：上游的替换脚本常写成
  `if (cond) { … } else { "" }`（语句而非表达式），而 JS 的 `eval` 对一个 `if` 语句返回被执行分支的
  完成值——这与 Rhino 的 `eval` 语义一致，用 `new Function` 反而要求每条脚本都 `return`。
- 绑定：`result` = 该条匹配文本（与上游一致）；`chapter` / `book` / `source` / `baseUrl` 等沿用
  `JsJob` 既有的绑定面。
- **`timeoutMs` 终于有意义**：这条规则的那一个 job 以它为时间上限（缺省用沙箱默认值）。
  超时 / 脚本抛错 / 返回值不是数组 → **跳过该规则**并记 warning（ADR-0026 §决策 2），正文保留上一条
  规则的结果；不把整章变成失败。
- 配额：每章每条 JS 规则只多算 **1** 次 job（`book-source.md` §6 的 `js:quota` 口径不变）。
- 正则规则不走沙箱（保持现有同步实现）。

## 后果

- 好的方面：上游的净化规则包可以直接导入并**真的生效**；导出的规则与书源能回到上游；
  书源导出天然保留未知键（payload 原样存储的副产品）。
- 代价：净化链路第一次依赖 JS 沙箱（内容读取路径上多一次 isolate 往返），所以缓存命中仍然不跑净化
  （缓存里是成品）；标题净化只覆盖阅读器一侧（§决策 4 的登记项）。
- 未做（登记在 `roadmap.md` §3.7）：规则导入导出 UI 之外的**分组筛选**、书源导出的分享/剪贴板通道、
  上游的 `excludeScope`（按书/源排除）执行语义、`useTo` 的多范围组合。

## 实现注记（2026-10-25 落地时补充）

- **标题净化是一批一次**：`ContentPurifier.purgeTitles(List<String>)` 把整份目录作为一批处理，
  所以 `@js:` 标题规则是一章书**一个** job 而不是每章一个（2000 章的源不会打出两千次跨 isolate 调用）。
  正文同理：`purgeContent` 一章一个 job。
- **`timeoutMs` 现在真有用处**：它只作用于 `@js:` 替换（脚本跑不完就跳过该规则并记 warning），
  正则规则仍然没有超时（Dart `RegExp` 无此 API），只保留上游那两条静态拦截（语法错、未转义 `|` 结尾）。
- **脚本答案的形状必须是数组**：长度与匹配数不一致、或不是数组时整条规则跳过——少一条多一条都对不上位置，
  猜一个只会把正文改错。
- **`payload.extra` 里的 `id` 被丢掉**：上游主键属于它自己的库，留着只会在下次导出时撞号；
  其余未知键（`excludeScope` 等）照旧往返。
- **导出的 `order` / `isEnabled` 以列为准**，书源的 `enabled` / `customOrder` 同理（§决策 3）；
  这也是单条书源导出现在与批量走同一方法（`exportPayloads`）的原因。
