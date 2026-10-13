# ADR-0037 `java.*` 成为兼容面：别名族、规则求值族与具名拒绝

- **状态：** Accepted（2026-10-13 架构师裁决；`PLAN.md` §3.5 的 **b1b** 开工前置，证据来自合集 C 全量语料）
- **日期：** 2026-10-13
- **关联：** ADR-0029（`@js:` 接入与绑定形态）、ADR-0030（引擎容量与排队）、ADR-0034（规则变量）、
  C-SRC-3 / C-SRC-4 / C-SRC-8、`docs/dev/book-source.md` §6（兼容面的唯一出处）与 §11（拒绝清单）、
  `PLAN.md` §3.5 / §3.7

## 背景

本仓的白名单用**自己的名字**（`http.*` / `parse.*` / `log.*` / `crypto.*`），而真实书源用的是
上游那套 `java.*`（上游把 `AnalyzeRule` 实例本身绑定为 `java`，`AnalyzeRule.kt:834`；
`AnalyzeRule : JsExtensions`，所以 `java` 上同时有引擎方法与 `JsExtensions` 的编码/时间工具）。
2026-10-13 在合集 C（`tool/spot_check/README.md` §3 的 3907 条）上做了全量统计：

| 事实 | 数字 |
|---|---|
| 用 `java.*` 的源 | **540** 条 |
| 用法计数（前几项） | `md5Encode` 1221 · `put` 1070 · `get` 1048 · `ajax` 866 · **`getString` 603** · `base64DecodeToByteArray` 328 · `timeFormat` 297 · `log` 250 · `encodeURI` 138 · `getElements` 84 · `base64Encode` 84 · `base64Decode` 71 · `setContent` 62 · `getElement` 45 · `getStringList` 36 |
| 其余族 | 密钥类 crypto（`aesBase64DecodeToString` 51 / `HMacHex` 38 / `createSymmetricCrypto` 16 …）· Rhino 互操作（`java.lang` 234 / `java.security` 45 / `java.util` 34 / `java.net` 1）· UI 与多步（`toast` 36 / `longToast` 24 / `startBrowserAwait` 16） |
| `java.timeFormat` 的源 | 184 条，主流写法 `{{java.timeFormat(java.getString('$.x')*1000)}}` |
| 用 `java.timeFormat` 且**不**经 `getString` 的源 | 40 条（`@js:java.timeFormat(result)` 这一类） |

因此 b1 的语料回归只能做到「派生源证明绑定可用」，主流写法卡在 `java.getString` 上（`PLAN.md` §3.7）。

**问题在于 `java.getString` 是同步的**（上游在脚本里直接取值），而本仓的规则求值在宿主 isolate、
桥是异步的——这正是 `parse.*` 是 Promise 的原因（ADR-0029 §决策 3）。为了不靠直觉裁决，
又对 `java.getString` / `getStringList` / `getElement` / `getElements` 的**调用位置**做了统计：

| 形态 | 计数 |
|---|---|
| **表达式内**（`f(java.getString('$.x'))`、`java.getString('$.x')*1000` 等，必须是同步值） | **395**（其中 **379** 的首参是**字符串字面量**，16 个是变量/拼接；`getString` 单项 359） |
| **独立成句**（`@js:java.getString('$.x')` / `{{java.getString('$.x')}}`，返回 Promise 也可） | 372 |
| 字面量调用里，**内层规则**还带 `@js:` / `{{` / `@put:` / `@get:` / `<js>`（不能走宿主内联） | **2** |
| 紧跟 `.toArray()`（上游 Java `List` 习惯用法） | **38** |
| 首参用模板字符串（反引号） | 0 |
| 出现在 URL 规则（`searchUrl` / `exploreUrl`）里 | 0 |

也就是说：**同步语义是 load-bearing 的（395 处，占嵌套调用的全部）**，但其中 **377 处是「字面量规则」**——
宿主在把脚本交给 worker 之前**自己就能求值**（引擎就在宿主上，而且那时还没有 job 在飞）。

## 决策

1. **`java` 成为兼容面，成员分三档**（唯一出处是 `book-source.md` §6 的表）：
   **实现**（同步，worker 内）· **具名拒绝**（命中即抛可读错误，不落到 `undefined is not a function`）·
   未知成员（照旧 `TypeError`，不特别处理）。
2. **别名族（worker 内同步实现，语义按上游照抄）：**

   | `java.*` | 语义（上游锚点） | 映射到 |
   |---|---|---|
   | `md5Encode(str)` | `MD5Utils.md5Encode` = UTF-8 字节的**十六进制 MD5**（`MD5Utils.kt:13-15`） | `crypto.md5` |
   | `base64Encode(str)` | `EncoderUtils.base64Encode(str, flags = 2)`，**2 = Android `Base64.NO_WRAP`**（`JsExtensions.kt:636-638`） | `crypto.base64Encode`（同为无换行标准 base64） |
   | `base64Decode(str)` | 解成 UTF-8 文本（`JsExtensions.kt:607-609`）；非法输入抛错 | `crypto.base64Decode` |
   | `encodeURI(str)` | **Java `URLEncoder.encode(str, "UTF-8")`**（`JsExtensions.kt:683-689`）：空格 → `+`，保留 `A-Za-z0-9` 与 `-_.*`，其余按 UTF-8 字节 `%XX` 大写 | 新增纯函数（**不是** JS 的 `encodeURI`：那一个空格给 `%20`、保留集也不同） |
   | `log(msg)` | `Debug.log(书源, msg.toString())`（`JsExtensions.kt:1128-1132`） | `log.info`（自动附 `rulePath`） |
   | `timeFormat(ms)` | 已在 b1 落地 | — |

   **只接受单参形态**：上游的多参重载（`base64Encode(str, flags)` / `base64Decode(str, charset)` /
   `encodeURI` 的两参写法）**具名拒绝**，因为这些参数（flags / charset）本仓没有对应语义，
   猜一个会静默给出不同结果。
3. **规则求值族（`getString` / `getStringList` / `getElement` / `getElements`）两种形态、一个实现点：**
   - **① 字面量快路径（宿主内联，同步语义）**：引擎在**构造 `JsJob` 之前**扫描脚本文本，把
     `java.getString('规则')` 等**首参是字符串字面量**的调用**就地求值**，把结果按 JSON 内联回脚本；
     之后脚本里已经没有这个调用了，所以表达式内嵌套（`java.timeFormat(java.getString('$.x')*1000)`）
     自然拿到同步值。
     覆盖：379 个字面量嵌套调用里的 **377**（96% 的嵌套用法）。
   - **② 异步兜底（宿主调用 → Promise，绑定当前 scope）**：①不处理的调用（非字面量首参、或内层规则带
     `@js:` / `{{` / `@put:` / `@get:` / `<js>`）走与 `parse.*` 相同的宿主调用通道，
     等价于 `parse.getString(rule, 当前 scope)`／`parse.getElements(...)`。脚本「返回」这个 Promise
     （`@js:java.getString('$.x')`、`{{java.getString('$.x')}}`）时照常工作；**在表达式内使用会得到 Promise
     而不是字符串**，因此按 C-SRC-4 显式失败（`js:error`），不会静默给错值。
   - **两条路径共用同一实现点**（引擎的嵌套求值），因此同一 (规则, scope) 的结果必然一致；
     差异只有**时机**：①在脚本执行前求值，②在脚本执行到那一行时求值。脚本无法改变 scope
     （`java.setContent` 属 M2），所以这个时机差在实践中不可观测——登记为有意差异。
     内层规则若需要沙箱，在①里是安全的（宿主上还没有 job），在②里按既有边界拒绝
     （`js:parse-recursion`，ADR-0030 §决策 1/3）。**为了不让同一个调用有两种语义**，
     ①的准入条件**明确排除**需要沙箱/变量的内层规则（全语料 2 例）。
   - **URL 规则里没有规则求值族**：URL 的 JS 没有页面 scope，命中即按 `js:parse-scope` 同族具名拒绝
     （语料里 0 例）。
4. **列表返回形态：JS `Array`，并在沙箱里安装 `Array.prototype.toArray()` 垫片**（返回 `this`），
   让上游「Java `List.toArray()`」的写法（语料 38 处，如
   `java.getStringList("$.data.imageArray").toArray().map(...)`）能跑。垫片是**能力中性**的：
   它只加一个方法，不引入任何 I/O / 平台能力，符合 C-SRC-3 的沙箱边界。
   （登记盲区：若将来语料出现 `.size()` 一类 Java 集合方法，再单独裁决，不预造。）
5. **具名拒绝（M2 / 不在 b1b）：** `ajax` / `get` / `post` / `head` / `ajaxAll` / `connect`（上游**同步**
   返回 body，与本仓 `http.*` 的 Promise 形态冲突，别名只会把错误提前成更难懂的错误）、
   `webView*` / `startBrowser*` / `downloadFile` / `cacheFile` / `importScript` / `getVerificationCode` /
   `getCookie`（沙箱禁忌或需要平台能力）、`setContent`（脚本中途改 scope，需要一个规则/作用域 API）、
   `toast` / `longToast`（UI）、`base64DecodeToByteArray` / `hexDecodeToByteArray`（返回 Rhino 字节数组；
   语料里 326/328 处直接喂给 `IvParameterSpec` / `SecretKeySpec`，即密钥类 crypto）、
   `createSymmetricCrypto` / `aes*` / `des*` / `HMac*`（密钥类 crypto）、`md5Encode16` / `htmlFormat` /
   `refreshBookUrl`（零散）。
   实现方式是**抛错存根**（`java.ajax is not supported (M2): …`），Rhino 互操作
   （`java.lang` / `java.security` / `java.util` / `java.net`）用**抛错 Proxy**，让
   `new java.util.ArrayList()` 报可读原因而不是 `undefined is not a constructor`。
6. **`getString` 的第二参**：`getString(rule, false)` **接受**（`false` = 不 unescape，正是本仓既有行为）；
   `getString(rule, true)` 与三参形态具名拒绝——本仓不做 HTML 实体反转义（见后果里的登记）。

## 后果

- `book-source.md` §6 的绑定表重写为**兼容面表**（每行给形态与分期），§11 增列具名拒绝族；
  `docs/README.md` §2.1 新增一行归属（`java.*` 兼容面 → ADR-0037 + §6）。
- **b1b 可开工**（`PLAN.md` §3.5）：别名族 + 规则求值族（快路径 + 异步兜底）+ `.toArray()` 垫片 +
  具名拒绝存根；验收含「同一 (规则, scope) 在两条路径上结果一致」的对照测试、
  `{{java.timeFormat(java.getString('…')*1000)}}` 真实源回归（b1 剩余的那半）、双端设备探针。
- **顺带登记的既有差异（新发现，2026-10-13）：** 上游的值规则在 `unescape = true`（**默认**）时对结果做
  `StringEscapeUtils.unescapeHtml4`（`AnalyzeRule.kt:362-366`），本仓**不做**实体反转义。实际影响比看起来小：
  DOM 的文本/属性提取本来就被 HTML 解析器解码过；真正的差异在 `html` / `all` 一类原样提取
  （上游会把 `&lt;b&gt;` 变回 `<b>`）。去向与触发条件登记在 `PLAN.md` §3.7。
- 矩阵/§6 的状态列仍按 ADR-0024 §决策 2 由**真实源回归**决定。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 只实现**异步**版（`java.getString` 一律 Promise） | 395 处嵌套用法（60% 的 `getString` 用法、以及 `updateTime` 的主流写法）会失败；等于用一个未测量的假设（「作者会写 await」）拒掉真实语料 |
| **worker 内跑同一个引擎**做真同步（把 scope 序列化进 job） | 语义上更贴近上游，但要：scope 序列化（DOM 需重建、祖先上下文会漂）、worker 里第二处求值入口、变量表回写、且收益不大——**字面量快路径已经覆盖 96%**。留作触发条件：若语料出现大量「内层规则本身需要沙箱/变量」的同步用法（今天是 2 例），再开 ADR |
| 把 `java.ajax` / `get` / `post` 也别名到 `http.*` | 上游同步返回 body、本仓是 Promise；别名会把「用错形态」变成更难定位的错误，且掩盖「需要同步 HTTP」这个真需求（真要做得先解决 Promise 形态，见 ADR-0029 §决策 3 的登记） |
| 只改文档、不给别名（把差异写成「本仓用 http/parse/log/crypto」） | 540 条源受影响，其中 `md5Encode` 1221 处、`getString` 603 处是**纯机械翻译**就能救回来的；文档不能替代兼容 |
| 用 JS 原生 `encodeURI` 冒充 `java.encodeURI` | 语义不同（空格 `%20` vs `+`、保留集不同），会让签名/查询串类规则**静默**产生不同 URL——比拒绝更糟 |
| 不做 `.toArray()` 垫片，让 38 处失败 | 成本只是一个方法；不做则这 38 处必须改成 `.map(...)` 直调，而书源不归我们改 |
