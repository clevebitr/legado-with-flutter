# 书源规格（对标原版阅读 / Legado）

> 本文档是书源解析的**唯一规格来源**：字段模型、规则语法矩阵、实现分期、失败语义、测试基线。
> 实现约束见 `docs/dev/constraints.md` §5（C-SRC-1..9）；
> 功能范围与分期见 §3.1 与 ADR-0014。
>
> **对标原则：** 支持矩阵逐条对标**原版阅读（Legado）**公开规则说明，
> 不做方言扩展、不自造语法。每条语法的「状态」一律从 `待验证` 起步，
> 只能由**真实书源回归记录**（§10）改为 `已确认`。
>
> **上游状态（2026-10-11 核实）：** `gedoor/legado` 仓库已**清空**——默认分支只剩一份侵权公告，
> 上游源码不再可得。因此「对标原版」此后只能以**本仓 §3 的规格**与**仍在维护的 fork**
> 为准（本次实现矩阵 #1/#2/#5/#8/#9 时核对的是 `hapelee/legado-with-MD3` 的
> `AnalyzeRule.kt` / `AnalyzeByJSoup.kt`）；§3 矩阵的「状态」列仍按原规则由真实书源回归
> 逐行确认。ADR-0014 已加同一事实的附注。

---

## 1. 范围

| 目标 | 说明 |
|---|---|
| 兼容 | 直接导入原版阅读的书源 JSON，在不修改规则的前提下完成搜索 → 详情 → 目录 → 正文 |
| 不兼容 | 不实现登录脚本与登录 UI、RSS/订阅源、朗读规则、需要浏览器 DOM 的网页 JS |
| 引擎 | 纯 Dart，无 Flutter 依赖（C-SRC-1）；JS 规则在独立 Isolate 执行（C-SRC-2） |
| 分期 | M0 为「首个可导入版本」的必达范围，见 §3.1 |

---

## 2. 书源 JSON 模型

字段名映射到 Dart 时必须转为 camelCase（`naming.md` §5）。

| 原版字段 | Dart 字段 | 类型 | 分期 | 说明 |
|---|---|---|---|---|
| `bookSourceName` | `name` | `String` | M0 | 必填 |
| `bookSourceUrl` | `url` | `String` | M0 | 必填，参与缓存键 |
| `bookSourceGroup` | `group` | `String?` | M0 | — |
| `bookSourceType` | `sourceType` | `BookSourceType` | M0 | 0 文本 / 1 音频 / 2 图片 / 3 文件 |
| `enabled` | `isEnabled` | `bool` | M0 | 默认 `true` |
| `header` | `headers` + `headerRule` | `Map<String, String>?` + `String?` | M0（规则形态 **M12**） | 原为 JSON 字符串，导入时解析；单个引号的宽松写法（GSON 接受）也解析。**写成规则**（`@js:` / `<js>`）时原文落 `headerRule`，在**首个请求之前**求值成 header 表（ADR-0047 §决策 5）；仍不是规则、也读不成对象的写法继续降级为无 header + warning（ADR-0040 §决策 6） |
| `searchUrl` | `searchUrl` | `String?` | M0 | 支持 `{{key}}` / `{{page}}` |
| `exploreUrl` | `exploreUrl` | `String?` | **M1** | 发现页；两种形态（分类串 / 整字段 JS）、条目语义与回落规则**全部**见 §4.2（ADR-0035） |
| `ruleSearch` | `searchRule` | `SearchRule` | M0 | 必填 |
| `ruleExplore` | `exploreRule` | `ExploreRule?` | **M1** | 发现结果规则；缺失或 `bookList` 为空时**整条回落** `searchRule`（§4.2、ADR-0035） |
| `ruleBookInfo` | `bookInfoRule` | `BookInfoRule?` | M0 | 缺失时从搜索页继承 |
| `ruleToc` | `tocRule` | `TocRule` | M0 | 必填 |
| `ruleContent` | `contentRule` | `ContentRule` | M0 | 必填 |
| `concurrentRate` | `concurrentRate` | `String?` | **M1** | 并发限速；语法、毫秒单位与「速率门 → 并发门」的合成归 §8（ADR-0036） |
| `variableComment` | `variableComment` | `String?` | **M1** | 书源变量说明；**纯展示**，引擎不读（上游 `BookSource.kt:245-252` 只与校验注释拼接显示） |
| `loginUrl` / `loginUi` / `loginCheckJs` | 同名 | `String?` ×3 | **M21a** | 三个字段都建模（导入/导出保真）。`loginCheckJs` 是**每次取页后运行的响应拦截器**（不是 true/false 检查），绑定与返回值见 §6；`loginUrl` 是登录入口打开的地址（URL 规则，后缀丢掉），`loginUi` 只保留原文（原生表单归 M21b/U15）。口径与三条登记差异见 ADR-0068（2026-10-24 增补） |
| `jsLib` | `jsLib` | `String?` | **M25/S1** | 源内 JS 库：每条 `@js:` 规则执行**前**先把它跑进同一个函数作用域（纯 JS 原样跑；写成 `{名:http(s)地址}` 的 JSON 对象时逐条下载后按对象序拼接）。解析/缓存与失败语义见 §6（ADR-0078 S1） |
| `lastUpdateTime` / `respondTime` / `weight` / `customOrder` | 同名 | `int?` | M0 | 仅用于展示与排序 |

**子规则字段**（原版字段名 → Dart，全部 camelCase）：

| 规则对象 | 字段 | 分期 |
|---|---|---|
| `SearchRule` | `bookList`、`name`、`author`、`kind`、`wordCount`、`lastChapter`、`intro`、`coverUrl`、`bookUrl`、`updateTime`；`checkKeyWord` | M0（`updateTime` 为 M1；`checkKeyWord` 为 **5.10**） |
| `ExploreRule` | 与 `SearchRule` 的九个列表字段**同形** + `updateTime`（上游 `BookListRule` 接口，`BookListRule.kt:6-18`；无 `checkKeyWord`） | M1 |
| 书源级 | `bookSourceName`、`bookSourceUrl`、`bookSourceGroup`、`bookSourceType`、`enabled`、`header`、`searchUrl`、`exploreUrl`、`ruleSearch`、`ruleExplore`、`ruleBookInfo`、`ruleToc`、`ruleContent`、`concurrentRate`、`variableComment`、`loginUrl`、`loginUi`、`loginCheckJs`、`jsLib`（✅ M25/S1：每条 `@js:` 规则执行前先跑库脚本，见 §6） | M0 / M25 |
| `BookInfoRule` | `init`、`name`、`author`、`kind`、`lastChapter`、`intro`、`coverUrl`、`tocUrl`、`wordCount`、`canReName`、`updateTime` | M0（`canReName`、`updateTime` 为 M1） |
| `TocRule` | `chapterList`、`chapterName`、`chapterUrl`、`isVip`、`updateTime`、`nextTocUrl` | M0（`updateTime` 为 M1） |
| `ContentRule` | `content`、`nextContentUrl`、`replaceRegex` | M0 |
| `ContentRule` | `webJs`（✅ M21a：渲染后执行脚本，见 §4.3）、`sourceRegex`（✅ M21a：先截取再建 scope，见 §4.3）、`imageStyle`（✅ M21a：`single`/`full` 生效，`left`/`right` 的对齐分支未实现）、`imageDecode`（建模保留，**非空即显式 `unsupportedRule`**——沙箱执行不了图片字节解密，ADR-0069 G5） | M21a |

**默认请求头：** 源没写 `header` 时，请求带一个**桌面 Chrome** 的 `User-Agent`（与上游默认一致，
ADR-0069 G10）——裸的客户端标识会让一批站点在规则跑之前就 403；源自己的 `header` 仍然覆盖它（C-NET-4）。
**登录头（`source.putLoginHeader`，M25/S3b）压在 `header` 之上**：顺序是「源的 `header`（规则形态先求值）
→ 登录头」，与上游 `getHeaderMap(userAgent, hasLoginHeader = true)` 一致；它是**按阶段**合并的
（每个阶段取一次 header 表），不是每个请求都重读，所以同一个阶段里中途写下的登录头从下一个阶段起生效。

模型必须使用 `freezed` + `json_serializable`（C-SRC-7）。未知字段必须**保留而非丢弃**：
在 `extra` 中承载，以便导出时不丢信息。

> **列表类规则的「同形」约束（M1-b0 裁决，ADR-0035 §决策 1）：** `SearchRule` 与 `ExploreRule` 的九个
> 列表字段由上游 `BookListRule` 接口固定，两者**必须同批**增减字段，不得只改一处。
>
> **上游存在而本仓尚未建模的字段（清单的唯一出处是 `docs/dev/engine-parity.md`）：**
> `BookInfoRule.downloadUrls` / `relatedBooks`、书源级 `coverDecodeJs` / `ruleReview` /
> `customButton` / `homepageModules`。
> **自 M25 起已建模的**：`jsLib`（S1）；`bookUrlPattern`、`eventListener`、`TocRule.formatJs` /
> `isVolume` / `isPay` / `wordCount` / `preUpdateJs`、`ContentRule.subContent` / `title` /
> `payAction` / `callBackJs`（S2，其中 `subContent` / `title` 只建模、执行留待 S2 剩余）。
> 它们的处理口径固定：**保留在 `extra`**（导入/导出不变形）+ **不假装支持**（不生效即是不生效）+
> **去向登记**（`engine-parity.md` 的切片或「有意差异 + 触发条件」）。本表不重列、不另开清单。
> `SearchRule.checkKeyWord` **不在此列**：它属「校验 / 调试的默认关键词」，已随 5.10 建模
> （判据与默认值见 ADR-0043 §决策 2）。
>
> **`updateTime` 出现在四处（上游事实）：** `SearchRule` / `ExploreRule`（列表项）、`BookInfoRule`（详情）、
> `TocRule`（章节）。本仓四处**同批建模（M1-b1）**，值都是**展示用字符串**（规则结果原文，不做日期解析；
> 章节侧可调用 `java.timeFormat`，见 §6）。**状态（M1-b1 已落地）：** 四处字段 + 承载实体
> （`Book` / `BookInfo` / `Chapter`）已入库；展示方（列表 / 详情 / 目录 UI）**已在 5.3 落地**
> （2026-10-21，`bookSourceUpdateTimeLine`，空值不显示）。
>
> **`canReName` 的上游语义（2026-10-13 取证，照抄为有意行为）：** 上游只在
> `BookInfo.kt:65` 判「`canReName` 规则字段非空白」+ 调用方开关（入口自己传 `canReName`，`WebBook.kt:235-238`），
> 然后**允许覆盖已有的书名 / 作者**（`BookInfo.kt:67-84`）；**规则内容本身不求值**。
> 因此本仓 M1 只建模该字段并把「是否允许改名」交给调用方；**不得**改成「求值为真才允许」
> （那会成为与上游的差异，需先登记）。消费方（书架改名）归 Phase 5。
> **状态（M1-b3 已落地）：** 字段已建模（`BookInfoRule.canReName`），
> `FetchBookInfo` 经 `declaresCanReName` 把「是否声明」传成 `BookInfo.canReName`（布值，不求值）。

> **`init` 的语义（2026-10-14，b6 落地）：** 上游 `BookInfo.kt:58-64`——`init` 规则**非空白**时，
> 先对它求值，并把**结果**当成后续每个 `ruleBookInfo` 字段的内容
> （`analyzeRule.setContent(analyzeRule.getElement(init))`）；空白 / 缺失时沿用整页，行为与从前一致。
> 它是「换 scope」的字段而不是值字段，因此**不适用** ADR-0026 的非顶层降级：求不出 scope
> 时整次详情失败（上游 `setContent(null)` 同样直接失败）——命不中报 `parseFailed`、`rulePath`
> 为 `ruleBookInfo.init`，命中未实现语法则按 §7 报 `unsupportedRule`、`rulePath` 为
> `unsupported:<语法名>`。
> 这正是真实语料的主流形态：`init: "$.data.bookInfo"` 之后，`name` / `author` / `coverUrl`
> 等字段的规则是**相对子对象**写的（`$.resourceName` / `$.picurl`…），此前逐字段对着整页读
> 必然全空。
> **本仓口径与登记差异：** `init` 复用列表规则的元素语义（`RuleEngine.selectAll`）——JSON 规则
> 给出 `JsonScope`（后续字段从该子结构读），DOM 规则给出命中元素的 `DomScope`；命中多个时
> **取第一个**，命中零个按 §7 报 `parseFailed`。`init` 整条写成 `@js:` 或 `<js>…</js>` 时按
> 列表规则的 JS 段求值（脚本返回数组即 scope 列表，见 §3 的 #14 注记补充）；**列表规则尾部**
> 的 `@js:`（`class.a@js:…`）仍报 `unsupported:@js:list`，去向见 `docs/dev/engine-parity.md` S4。

> **层归属与 `extra` 的落地形态**见 ADR-0021（模型位于 `domain/entities/`；`extra` 由
> `fromLegadoJson` 逐层填充）。本表只拥有字段映射与分期。
>
> **书源身份与重复导入（2026-10-14，P5-0；决策、数值与失败语义的唯一出处是 ADR-0040，已接受）：**
> `bookSourceUrl` **不是**主键——合集普查（`tool/spot_check/README.md` §3）显示同一 URL 下既有
> 完全等价的重复条目、也有行为不同的多条，所以落库身份取 **`(bookSourceUrl, 行为指纹)`**：
> 行为字段 = `bookSourceName` / `searchUrl` / `header` / `ruleSearch` / `ruleBookInfo` / `ruleToc` /
> `ruleContent` / `ruleExplore`（递归按键排序后序列化的 sha256）。同 `(url, 指纹)` 重复导入**幂等**，
> 同 URL 不同指纹**共存**（与上游「URL 即主键、后者覆盖」的登记差异）；`enabled` / `customOrder`
> 属**用户态**，导入永不覆盖。体积上限、校验分档与失败 `rulePath` 的数值不在本表。
> **5.1 的落地（2026-10-14）：** 入口是**粘贴 JSON 文本**与**从 URL 拉取**（文件选择与分享归 5.8，ADR-0040 §决策 9）；
> 单条被跳过时**计数并写日志**（下标 + 失败字段 + URL，不写正文），文件级失败复用 `invalidBookSource`；
> 多条同 URL 的变体在列表里逐条呈现并带「同站点的另一份规则」标记。

---

## 3. 规则语法支持矩阵（对标原版阅读）

> 「原版适用字段」列取自原版规则说明（原版说明中标注「仅书籍列表和目录列表」的语法
> 才限定字段，其余为**所有字段**可用）。

| # | 语法 | 原版示例 | 原版适用字段 | 分期 | 状态 |
|---|---|---|---|---|---|
| 1 | 默认规则：`类型.名称.位置` | `class.odd.0@tag.a.0@text` | 所有字段 | M0 | 已确认 |
| 2 | 类型 `class` / `id` / `tag` | `id.content@text` | 所有字段 | M0 | 已确认 |
| 3 | 类型 `text`（按文本内容匹配） | `text.最新章节` | 所有字段 | M0 | 已确认 |
| 4 | 类型 `children`（取全部子标签，忽略第二、三段） | `class.list@children` | 所有字段 | M0 | 已确认 |
| 5 | 位置：正索引与负索引（`-1` 为倒数第一） | `tag.li.-1@text` | 所有字段 | M0 | 已确认 |
| 6 | `!` 位置排除（序号用 `:` 分隔，支持负数） | `tag.li!0:1@text` | 所有字段 | M0 | 已确认 |
| 7 | 列表首字符 `-` 使结果**倒置**；`+` 是「正序」的显式写法（剥掉即忽略，`-+` 仍倒序） | `-class.odd@tag.a@href` | 所有字段 | M0 / **M25/S4** | 已确认 |
| 8 | 提取内容：`text` / `textNodes` / `ownText` / `html` / `all` / `href` / `src`（及其他 HTML 属性名） | `tag.a@href` | 所有字段 | M0 | 已确认 |
| 9 | 正则替换 `##正则##替换内容`（替换为空时可省略第二个 `##`） | `tag.p@text##全文阅读` | 所有字段 | M0 | 已确认 |
| 10 | `\|\|` 依次尝试，首个非空即成功 | `class.odd.0@tag.a.0@text\|\|tag.dd.0@tag.h1@text` | 所有字段 | M0 | 已确认 |
| 11 | `&&` **合并两侧结果（并集，非串联；仅限同种规则，不含 js 与正则）** | `class.odd.0@tag.a.0@text&&tag.dd.0@tag.h1@text` | 所有字段 | M0 | 已确认 |
| 12 | `@css:` 标准 CSS 选择器 | `@css:.book-list li@text` | 所有字段 | M0 | 已确认 |
| 13 | `@json:` JSONPath（以 `$.` 开头时可省略标志） | `@json:$.data.list[*].name` | 所有字段 | M0 | 已确认 |
| 14 | `@js:` JavaScript | `@js:result.replace(/\\s/g,'')` | 所有字段 | **M0** | 已确认（**列表规则**自 M12 起支持：脚本返回数组即条目，ADR-0047 §决策 3；**任一段**都可以是 JS 段，含 `class.list@tag.li@js:…` 这种尾部写法——脚本拿到上一段的条目内容（M25/S4）；脚本文本内的 `{{…}}` / `@get:` 先展开（ADR-0060 §决策 1）） |
| 15 | `@@` 默认规则标志（在 `{{}}` 内使用时必填） | `@@class.odd.0@text` | 所有字段 | M1 | 已确认 |
| 16 | `@put:{key:rule}` / `@get:{key}`（**仅限 js 以外**的规则；`@put` 内 JSONPath 不加引号，其他规则加引号） | `@put:{bid:"//*[@bid-data]/@bid-data"}` | 所有字段 | M1 | 已确认 |
| 17 | `java.put(key,value)` / `java.get(key)`（**仅限 js 内**，js 中不能使用 `@get`） | — | 所有字段 | M1 | 已确认 |
| 18 | `{{}}` 内嵌规则 / JS（搜索 URL 与发现 URL 内**只能**用 JS；其他位置默认 JS，用其他规则必须带标志头 `@@` / `//` 或 `@xpath:` / `$.` 或 `@json:` / `@css:`） | `{{result.match(...)}}` | 所有字段 | M1 | 已确认 |
| 19 | `{}`（阅读 2.0 遗留规则，**只能**用 JSONPath，应尽量避免） | `{$.data.name}` | 所有字段 | M1 | 已确认 |
| 20 | `:正则规则`（不可省略标志；**仅书籍列表与目录列表**；`&&` 在里面是**正则链**不是分支连接符） | `:(?s)(\d+)" class="(isvip)?[^"]*name[^>]*>([^<]*)` | 仅书籍列表、目录列表 | **M25/S5e** | 已确认（每条匹配成一个条目，条目字段用 `$1` / `$2` / `$0` 模板取组值，可带 `##正则##替换`；值规则位置具名拒绝 `unsupported::`，条目上的非模板规则具名拒绝 `unsupported:regex:item`。语义见下方 `:正则` 注记） |
| 21 | `@xpath:` XPath（以 `//` 开头时可省略标志；本仓**只认 `//`**，见下方注记） | `@xpath://div[@id='a']/text()` | 所有字段 | **M25/S5b** | 已确认（自研子集：路径 + `*` / 标签 / `text()` / `@attr`、谓词（位置、`@a='v'`、`contains()`、`not()`、`starts-with()`、`position()`/`last()`、存在性路径）、`\|` 并集、`following-sibling::` 等七个轴；其余轴与函数**具名拒绝**。语义见下方 XPath 注记） |
| 22 | `@webJs` 网页 JS | — | 正文规则 | **M2** | 不支持 |
| 23 | `sourceRegex` 源码正则 | `sourceRegex`（`ruleContent`） | 正文规则 | **M21a** | 已确认（先截取再建 scope，不命中即 `parseFailed`；见 §4.3 与 ADR-0068） |
| 24 | 字体反爬字形映射 | `queryTTF` / `queryBase64TTF` / `replaceFont` | 正文替换规则 | **M21a** | 已确认（自研 `cmap` + `post` 解析；字形名优先、id 兜底，见 §6） |
| 25 | `##match##replace###`：只取**第一个匹配**并在其内部替换（矩阵 #9 的补充语义） | `##match##replace###`（上游注释原文） | 所有字段 | **M0**（Phase 2.2 已实现） | 已确认 |
| 26 | `[]` 索引列表：`[-1, 3:-2:-10, 2]`、`[-1:0]` 可在任意位置反向（与 #5 / #6 同组） | `tag.div[-1, 3:-2:-10, 2]` | 所有字段 | **M0** → Phase 3.1 | 已确认 |
| 27 | `%%` 并行交叉合并（与 `\|\|`、`&&` 同级的选择器连接符） | — | 所有字段 | **M0** → Phase 3.2（与 #10 / #11 同族，复用同一套连接符切分） | 已确认 |
| 28 | 索引作为 `@` 分段后每段的首规则：`.1` / `[1]` / `!0` / `children[1]`，等价于 `children` + 该索引（可与 #5 / #6 / #26 的位置写法组合）；**任意段末尾**的 `.N` / `.-N`（纯数字）同样是索引（`#id img.0`，ADR-0069 G3） | `head@.1@text`、`head@[1]@text`、`head@children[1]@text`、`#image_div img.0@src`（等价） | 所有字段 | **M0** → Phase 3.1（已实现） | 已确认 |
| 29 | `@css:` 内的 jsoup 索引伪类 `:eq(n)` / `:gt(n)` / `:lt(n)`（**兄弟索引**，0-based，**不是**结果集索引） | `@css:div#info > p:eq(3) @text` | 所有字段 | **M0** → Phase 3.2 | 已确认 |
| 30 | 提取段里的**嵌套规则**（末段本身是一条规则，如 `class.a@css:.b`） | `class.a@css:.b` | 所有字段 | **M2 / 登记不做**（2026-10-27 复核：修掉普查探测器后语料命中 **0 源 / 0 处**，见下方 #30 注记） | 有意差异（触发 = 出现依赖它的真实源） |
| 31 | `<js>…</js>` JS 包装（**任意位置**，可作其他规则的分隔符；与 #14 同能力、不同包装） | `tag.li<js>…</js>//a`（原版文档示例） | 所有字段 | **M12**（值规则与列表规则都支持） | 已确认（**分段链**：上一段产出是下一段 `result`，`{{result}}` 由此拼进后续文本；ADR-0047 §决策 2） |
| 32 | 默认规则里的**属性选择器**：`[attr]` / `[attr=v]` / `[attr*=v]`，可带标签名（`meta[...]`） | `[property$=image]@content`、`meta[name=description]@content` | 所有字段 | **M27** | 已确认（`[` 后是字母 / `_` 时整段交给 cascadia；索引列表仍归 #6 / #26 / #33。上游 `AnalyzeByJSoup.kt:406-440` 的 `findIndexSet` 解析不出索引就 `break`，整段留给 jsoup） |
| 33 | 位置列表 `.N:M[:N]`（`.` 是筛选，`:` 分隔序号，可负数；与 #6 的 `!` 同族） | `tag.div.-1:10:2`、`span.1:2`、`p.3:4:5:6:7` | 所有字段 | **M27** | 已确认（上游 `ElementsSingle` 注释与 `AnalyzeByJSoup.kt:406`：非 `[]` 式索引里 `:` 分隔、`.` / `!` 决定筛选；顺序按写法，不是升序） |

> **G4 状态（2026-10-14）：** #15–#19 **全部**已翻「已确认」，逐行证据（源名 + 字段 + 产出样本）见
> `tool/spot_check/README.md` §4 的 G4 记录（RUN 1 = 漫客栈，#16/#18/#19；RUN 2 = QB女生派生，#17；
> RUN 3b = 笔趣阁③派生，#15）。
> **#15 的基座校正（开发组 2026-10-14，有实测依据）：** 架构师裁决要求「用派生源确认」，意图照办；
> 但基座不能用漫客栈——`@@` 是默认（CSS / jsoup）规则的 flag，而漫客栈四段页面全是 JSON，
> 默认规则打在 JSON scope 上被 `_matchElements` 判成 `parseFailed`（RUN 3a 实测：该字段被拒 + 降级为空）。
> 因此改用**同样已证实四段可跑的 HTML 真源**笔趣阁③（合集 C 第 63 条，G2b 基线），只把
> `ruleSearch.kind` 加一个 `@@` 前缀（选择器与替换段逐字不动）：search 产出 `kind=武侠`，
> 其余三段计数/哈希与 G2b 记录逐字相同（toc 1310、content 3031 / `sha256=6578ef3efc456856`）。
> 活源普查（319/25）保留为背景证据。

> **#32 / #33 为 2026-10-28 日志取证补录（M27）：** 真实书源日志（54 源全量校验）暴露了两条
> **上游早已有、矩阵却没有行**的写法，补录同样追加在表尾：
>
> - **#32 属性选择器。** `[property$=image]` / `meta[name=description]` / `a[href*="_"]` 在本仓
>   一直被当成索引列表（`[` 后一律进索引解析）→ `parseFailed`；日志里 4 个 meta 驱动的详情页
>   字段全空（静态普查 10 源 / 31 处）。上游是「索引解析不出就当 CSS」，本仓照此判定：`[` 后
>   首个非空格字符是字母 / `_` 即整段交给 cascadia，数字 / `-` / `!` / 空串仍走索引。
>   **不加引号的属性值：** 真实源写的是 jsoup 方言 `[property=og:novel:book_name]`（值里有 `:`），
>   而 CSS 只允许不加引号的标识符；本仓在交给 cascadia **之前**把这种值包成双引号（已加引号 / 纯
>   标识符不动），否则修复只会把这些字段从 `parseFailed` 变成仍是 `parseFailed`。
>   **尚未对齐的一处：** jsoup 的 `[attr~=regex]` 是**正则子串匹配**，CSS 的 `~=` 是「空白分隔的整词」
>   —— `[property~=category|status|tags]` 因此在本仓解析成功但**匹配不到**（3 源，仅影响 `kind` 展示，
>   登记在 `engine-parity.md`）。
>   **仍然更严的差异：** 已实现的类型名后面写属性选择器（`tag.li[x]`）在本仓是 `parseFailed`，
>   上游会把它当标签名的一部分静默无匹配（登记在 `engine-parity.md`）。
> - **#33 位置列表。** 上游把 `span.1:2` / `li.4:6` 读成「`.` 筛选 + `:` 分隔的序号列表」
>   （`ElementsSingle` 注释的 `tag.div.-1:10:2`），本仓此前只实现了 `!` 那张表；日志里 3 个源的
>   `kind` / `wordCount` 因它置空（静态 10 源 / 15 处）。顺序按写法保留（`2:0` 就是第 2 个再第 0 个），
>   与 `[N,M]` 的顺序语义一致。

> **#25–#27 为 2026-10-11 补录（回执 B3）：** 这三条语法此前只存在于上游实现里，本仓矩阵没有行，
> 于是出现「引擎拒绝得对、账本却没记」的缺口。补录时**追加在表尾而不是插在中间**：`docs/dev/roadmap.md`
> 与 ADR-0014 都按 `#1–#14` / `#15–#19` / `#20–#24` 引用矩阵，插入会打乱既有编号
> （与 `docs/README.md` §5 的 ID 稳定性同一原则）。上游证据：`AnalyzeRule.kt:497`（`###`）、
> `AnalyzeByJSoup.kt` 的 `ElementsSingle` 注释（`[]`）、`AnalyzeByJSoup.kt:88` 的
> `splitRule("&&", "||", "%%")` 与 `:110` 的交叉合并实现（`%%`）。

> **#29 / #30 与 `&&` 语义修正（2026-10-11，架构师裁决 1 / 3 / 4 / 5）：**
>
> - **`&&` 语义修正（属规格缺陷，不是歧义）：** 本行此前写「串联多级」、§3.2 写「按 `&&` 切分为
>   多级」，与上游不符。上游公开规则说明（mgz0227 教程、teachme.pages.dev、celeter、missdeer
>   转存的官方文本）与第三方方言实现一致：**`&&` 合并两侧结果（并集）、`||` 取首个有值、
>   `%%` 交叉取数**，且**只在同种规则间使用（不含 js 与正则）**；官方示例
>   `class.odd.0@tag.a.0@text&&tag.dd.0@tag.h1@text` 两侧都是值规则，串联读法下必然为空。
>   **合并的去重与顺序（是否去重、是否按规则先后）行为未确认**（未钉到上游实现行号）：本仓按
>   「拼接、按规则先后、不去重」实现，待 3.7 的真实书源回归核实。跨类型合并（列表规则 `&&`
>   值规则）必须**显式失败**，不得静默拼成异构列表。
> - **#29（jsoup 索引伪类）依据两层：** 仓内真实语料（`legado_export_sanitized.json` 的
>   `@css:dl > div.btm > em:eq(1) @text`、`@css:div#info > p:eq(3) @text ##字数：`，见
>   `book_source_test.dart`）与 jsoup 官方语义（`:eq(n)` / `:gt(n)` / `:lt(n)` 用
>   `elementSiblingIndex()`，0-based；jsoup 自带测试 `SelectorTest.testPseudoEquals` 的
>   `div p:eq(0)` 每个 `div` 各取一个 `p`）。实现方式是把它们**改写成 cascadia 已有的
>   `:nth-child`**（匹配仍全在 cascadia 内，C-SRC-6）：`:eq(1)` → `:nth-child(2)`（**纯整数才是
>   「相等」**，写成 `:nth-child(n+2)` 会匹配该位置之后的全部兄弟）、`:gt(1)` →
>   `:nth-child(n+3)`、`:lt(3)` → `:nth-child(-n+3)`。**负索引：** jsoup 公开文档把索引伪类
>   定义为 0-based，**没有定义负索引**（本仓未核实 jsoup 对负数的实际行为，故不猜），一律报
>   可定位的 `unsupported::eq(-1)`，不静默当空结果（C-SRC-4）。
> - **#30（提取段嵌套规则）暂不实现：** 它要把提取契约从封闭集合（text / textNodes / ownText /
>   html / all / 属性）扩成「提取值可以是子规则」，与 `##` 替换、以及 JSON / JS 的 scope 改造
>   三者叠加，属「接口形状未定型就横向铺开」；且当前无使用率证据。`rulePath` 用
>   **`unsupported:nested-rule`**，与已支持的中段 `@css:` 区分开。
>   **2026-10-27 复核（M25/S5c）：** 原先登记的「22 源 / 125 处」是**普查工具误报**——探测器用
>   `text.split('@').skip(1)` 切段（不管括号、引号、`{{…}}` 与 `@js:`），于是把三类**已支持**的写法
>   算成了 #30：① 整条规则以 `@css:` / `@json:` 开头又含后续 `@`（117 条）、② `{{@css:…@text}}`
>   模板里的内联规则、③ `+@css:` / `-@css:` 正倒序前缀。按「括号感知切段 + 首段非空（去掉 `+`/`-`/`@@`）」
>   重算后命中 **0 源 / 0 处**，`corpus_census.dart` 已改成这个口径。因此它维持「不做」，但改为
>   **有意差异 + 触发条件（出现依赖它的真实源）**，不再排在切片里。
> - **#12 注记（裁决 5）：** `@css:` 内的**状态伪类**（`:hover` / `:visited` / `:focus` …）在静态
>   DOM 下**恒不匹配**，这是正确答案而不是错误：实现为「成功且结果为空」，不报
>   `unsupportedRule`。同处登记两处 cascadia ≠ jsoup 的差异（当前都表现为 `parseFailed`，
>   属「响亮失败」，可接受）：`:containsOwn(a b)` 这类**不带引号的多词参数**会报
>   `Invalid argument`（jsoup 接受；真实语料的 `containsOwn(下一页)` 无空格，可用）；
>   `:matches(x)` 必须写成 `:matches(/x/)`（jsoup 收裸正则）。

> **#10 注记（2026-10-28，M27）：空分支与「`##` 属于整条规则」。** 上游把一条值规则切成
> 候选后，空候选 / 空分支直接跳过（`AnalyzeByJSoup.getString` 的 `temp.isNullOrEmpty()`），
> 而 `##` 的替换段属于**整条规则**（`AnalyzeRule.kt:339`：规则体为空但有替换时跳过求值、
> 把替换打在上一段结果上）。因此真实写法 `class.span@text||##最新章节.*`（天地中文的
> `wordCount`）在本仓不再 `parseFailed`：空候选不贡献值，替换照常应用。
> **边界：** 整条规则都是空（`-` 只剩倒置前缀、`&&` 只剩连接符）仍报 `parseFailed`——
> 那是写错，不是一个可跳过的候选（C-SRC-4）。一个候选解析失败仍结束整条规则，不会去尝下一个
> `||` 分支（与上游的「失败态不存在」不同，属 C-SRC-4 的响亮失败，登记在 `engine-parity.md`）。

> **#9 / #25 注记（2026-10-28，M27 第二轮日志）：只有替换段的字段规则。** 一条字段规则可以
> 没有选择器，只写 `##pattern##replace###`：上游 `getString` 里替换对象是**这一层的内容**
> ——页面给 body，条目给元素的 HTML（`Element.toString()`），JSON 条目是 Java `Map` 的
> `toString()`（本仓用 JSON 文本，与矩阵 #13 的登记差异同源）。真实源用它从条目 HTML 里抽地址：
> `##href="//m.qidian.com/chapter/(\d+)/0/"##https://m.qidian.com/book/$1/###`（千寻、未来天王、
> 肉文屋的 `ruleSearch.bookUrl` / `ruleBookInfo.*`）。`###` 的「首个匹配内替换」语义不变；
> 模式不命中时结果是空串（单值字段即「没有值」）。

> **行首装饰性 `@` 注记（2026-10-28，M27 第二轮日志）：** 上游 `RuleAnalyzer.trim()` 在切段前
> 把行首的 `@` 与空白**一并剥掉**，所以真实源写的 `@tag.td.2@text` / `@href` /
> `@onclick@js:…` 等于去掉那个 `@`。标志头不受影响：剥掉后 `_flagOf` 会把它补回来，`@js:` /
> `@css:` / `@json:` / `@xpath:` / `@put:` / `@get:` / `@webJs` / `@@` 仍是语法。
> 语料命中：三九小说 6 条、金银小说网 6 条、阅友小说 2 条、笔趣阁 gei / 版主13 / 开心看漫画 /
> PO5 / 废纸文学各 1–2 条（只差这一个字符就整片搜索字段 `parseFailed`）。

> **#13 注记（2026-10-11，随 3.2 落地；接口裁决见 ADR-0028）：**
>
> - `@json:` 与裸 `$.` / `$[` 作用于 **scope**：整页 scope 同时带 DOM 与原始 body，
>   所以同一页的不同字段可以各用各的（一条规则内混用两种 scope 头则不行，见下）。
> - **值规则的结果：** 字符串原样；数字 / 布尔按 JSON 写法；`null` 与空串**不产生值**
>   （与矩阵 #8 的空提取同口径）；**列表逐元素展开**（上游 `AnalyzeByJSonPath.kt:83-87`：
>   `for (o in obj) result.add(o.toString())`），所以 `$.data.tags` 给 `a` / `b` 两个值；
>   对象按 **JSON 文本**返回（上游 Java 的 `Map.toString` `{a=1}` 不可复现，**已登记的
>   差异**，真实语料里没有规则依赖它）。
> - **列表规则的结果：** 命中的路径若本身是**列表**，则把它的元素当作条目列表
>   （上游 `AnalyzeByJSonPath.kt:137` 的 `read<ArrayList<Any>>`），所以 `bookList: $.info.Datas`
>   给 30 个条目而不是 1 个数组——这两点都是 3.7 的真实源回归（`tool/spot_check/README.md` §4b）
>   发现的保真缺口，已修。
> - **JSON 条目上的裸键（2026-10-28，M27）：** 条目的 scope 是 JSON **对象**时，一条**没有选择器**
>   的规则就是成员名（上游 `AnalyzeRule.kt:331` 的 `LinkedTreeMap` 分支），值按矩阵 #13 的形状
>   返回（字符串原样 / 列表展开 / 对象 JSON 文本）。真实源：`ruleToc.chapterUrl` 写成
>   `$.pic@put:{img:pic}`，其中 `pic` 就是条目成员；本仓此前在 JSON scope 上看不到选择器就报
>   `parseFailed`，导致整条规则与正文 `@get:{img}` 一起失效（日志 511 条）。
>   **边界：** 只有 map 条目能这么读；列表 / 标量条目、以及 JSON **页**（ADR-0047 §决策 6 的
>   「不自动切模式」）仍然按原来的口径响亮失败。
> - **JSONPath 方言：`]` 后直接跟成员名（2026-10-13，b5）：** 上游的 JsonPath 接受
>   `$.a[0]b` / `$.data.page[*]image`，而 RFC 9535 那个解析器只认 `].`。本仓在把表达式交给
>   解析器**之前**把「`]` 紧跟标识符（字母 / `_` / 非 ASCII，即中文键）」归一成 `].`；
>   `].`、`][`、末尾的 `]`、`]` 后接空白、以及引号里的 `]`（`$['a]']b`）都不动。
>   真实源：漫客栈的正文规则 `java.getStringList("$.data.page[*]image")`
>   （`tool/spot_check/README.md` §4 的 b5 记录）。
> - **scope 答不了的规则报 `parseFailed`（带字段路径）**，不是 `unsupportedRule`、
>   更不是空结果：语法是支持的，是这一页回答不了。非顶层字段仍按 ADR-0026 降级为
>   「置空 + warning」。JSON 分支与默认 / `@css:` 分支用 `&&` 合并同样报 `parseFailed`
>   （§3 的 `&&` 注记：连接符只合并同种规则）。
> - **`@json:` 出现在非分支首位**（如 `class.a@json:$.b`）仍报 `unsupported:@json:`：
>   元素内部的 JSON 需要提取段嵌套规则，那是矩阵 #30 的边界，不在 3.2 范围。

> **#28 为第二轮补录（2026-10-11，架构师裁决 Q4(1)）：** 上游规则文档明确「允许索引作为 `@`
> 分段后每个部分的首规则，此时相当于前面是 `children`」，并给出 `.1` / `[1]` / `children[1]`
> 三条等价式。本仓初版按「不在矩阵内」显式拒绝，评审判定为 M0 功能缺口，故补行 + 实现 + 单测。
> 与 #4 的边界由实现固定：点号后是**字母**（`children.li.0`）归 #4（忽略第二、三段），
> 是**索引写法**（`children.1`、`children[1]`）归 #28。
>
> **#3 的语义依据（架构师 2026-10-11 核实）：** `AnalyzeByJSoup.kt:319` —— `text` 按元素的
> **自身文本**匹配（jsoup `getElementsContainingOwnText`，大小写不敏感）。因此文本落在子元素里的
> 外层节点**不**算命中；该规范化与 #8 的 `ownText` 提取共用同一份实现。
>
> **一处刻意比上游更严的差异（登记）：** `tag.div[-1].0`（`[...]` 与第三段位置同时出现）在本仓
> 返回 `parseFailed`；上游会把 `[-1]` 当成名称的一部分而**静默返回空结果**。按 C-SRC-4
> 「禁止静默忽略」的口径取显式失败，此处登记以免日后被当成实现缺陷。

> **#14 注记（2026-10-12，随 3.4 落地；状态列已确认于 3.7）：** 值规则上的**终段** `@js:`
> 已实现（`@js:` 贪婪吞掉本条规则剩余部分，与上游 `AppPattern.JS_PATTERN` 同形）；**列表规则**
> 上的 `@js:` 当时报 `unsupported:@js:list`（尚无「JS 返回一列元素」的契约）——**该句已被 M12
> 部分取代**：整条规则为 JS、或规则体内出现 `<js>…</js>` 时，脚本返回数组即条目；只有
> **尾部** `@js:`（`class.list@tag.li@js:result`，上游同样支持）仍报 `unsupported:@js:list`，
> 去向见 `docs/dev/engine-parity.md` S4。白名单绑定、配额与四条边界
> （`js:timeout` / `js:error` / `js:parse-scope` / `js:parse-recursion` / `js:quota`）的唯一出处是
> §6。**真实源证据（3.7，2026-10-12）：** 语料 `legado_js_rules_source.json`（猫耳FM，已脱敏）
> 在活站点上跑通搜索 30 条 + 目录 34 条，两条逐项 `@js:`（`$.id@js:'…'+result` 与
> `$.sound_id@js:'…'+result`）均由脚本产出地址；记录见 `tool/spot_check/README.md` §4b。

> **#14 注记补充（2026-10-22，ADR-0060 §决策 1）：** 脚本**文本内**的 `{{…}}` / `@get:` 在脚本执行前按当前条目展开（对齐上游 `SourceRule.makeUpRule`，`AnalyzeRule.kt:666-768`），脚本拿到的已是替换后的文本；反斜杠转义的 `\}` 不算模板（`/{{\}\}/` 原样保留）。该裁决取代本注记 2026-10-12 的「脚本里的 `{{…}}` 属于脚本」。

> **#15–#19 注记（2026-10-12，随 M1 语法先行落地；状态列仍为「待验证」）。**
> 五条语法的**共同实现点**是引擎的展开步骤：上游先把 `@put:{…}` 抽掉、再把 `@get:{…}` 与
> `{{…}}` 换成它们的值，**最后**才把结果当规则读（`AnalyzeRule.SourceRule.init` /
> `makeUpRule`，`AnalyzeRule.kt:666-760`），本仓照此实现，并把结果放进 `_Expansion`。
> 逐条：
>
> - **#15 `@@`**：只认**规则体开头**（`AnalyzeRule.kt:612-615`：剥掉两个字符、模式不变），
>   所以 `{{@@class.a@text}}` 才等于「在这里跑一条默认规则」——`{{…}}` 的默认是 JS，
>   默认规则必须自报家门。中段的 `@@` 仍报 `unsupported:@@`（上游也只认开头）。
> - **#16 `@put:` / `@get:`**：`@put:{key:rule}` 的每个值都是一条规则，在**摘标志之前**逐个求值
>   并写入变量表（`AnalyzeRule.kt:641-647`）；`@get:{key}` 换成变量值，未定义时为空串。
>   带替换的规则按上游的 **Regex 模式**读：**替换后的整段文本就是这条规则的值**
>   （`AnalyzeRule.kt:674-680`，即 `“地址/{{@get:{x}}}”` 这类写法）。
>   **登记的实现差异：** 本仓按 `key:value` 形状解析 `@put` 体（值可带引号或裸写，
>   逗号 / 方括号 / 引号内的 `:` 都不切分），**不**走上游 GSON 的「严格优先 + 宽松兜底」
>   （`AnalyzeRule.kt:673-686`）；解析不出键值对的片段被忽略（上游同样保留空 putMap）。
> - **#17 `java.put` / `java.get`**：与 #16 是**同一份**变量（上游 `bindings["java"]` 就是那个
>   `AnalyzeRule`，`AnalyzeRule.kt:835`）。存储位置、快照与回程语义归 **ADR-0034**；
>   `java.timeFormat` 属 `updateTime`，仍按 §6 表的分期。
>   **两个内置键（M12 起支持，ADR-0049）：** 上游 `java.get` 先答 `bookName` / `title`
>   （`AnalyzeRule.kt:812-821`，取 Book / Chapter 的名字），**再**查变量表。本仓照此实现：
>   `JsJob` 带 `bookName` / `chapterTitle`（来自 `JsPageContext`，即**页面**的上下文），
>   读的顺序是 `内置键 → 变量表 → 空串`，所以 `java.put('title', …)` **不能**劫持内置键。
>   阶段不知道名字时（搜索、目录、调试控制台）内置键缺失，读回落变量表。
> - **#18 `{{…}}`**：内层文本按上游 `isRule` 分流（`AnalyzeRule.kt:736-752`）：以
>   `@` / `$.` / `$[` / `//` 开头就当**规则**求值（取首个值），否则**当 JS**求值（取单个标量，
>   `null` / 无值都变空串）。在**搜索 / 发现 URL** 里只允许 JS，规则头按名报
>   `unsupportedRule`（§4）；URL 脚本的 `key` 绑定只在那里存在（ADR-0034 §决策 3）。
>   **登记的实现差异（两处）：** ① **列表规则**（`bookList` / `chapterList`）里的 `{{…}}`
>   替换后仍按**选择器**读（上游在那个分支回的是文本本身）；② 模板的 JS 返回**列表**时
>   本仓取第一个值，上游插入的是数组的 `toString()`（逗号连接）。
>   **`##` 的位置（2026-10-13，b5）：** 规则分界只看**模板外**的 `##` ——
>   `{{$.tag_views##\s+##,}}` 里的 `##` 属于内层规则（矩阵 #9），外层不在那里切开；
>   模板之后的 `##`（`{{…}}##/##-`）才是这条规则自己的替换段。未闭合的 `{{…` 不做分界，
>   仍由解析报错。
> - **#19 `{}`**：上游在 **JSON 模式**的规则里把每个平衡的 `{$jsonpath}` 换成它的值，
>   再把整段作为**一个值**返回（`AnalyzeByJSonPath.kt:29-48`、`:79-90`）；一条规则整好就是一个
>   模板时，那就是遗留写法 `{$.data.name}`。列表规则里只取其中的 JSONPath，字面文本不贡献元素
>   （矩阵「只能用 JSONPath」）。
>
> **#14 的条目形态（2026-10-28，M27 第二轮日志）：** 列表规则由脚本产出时，条目按值分流：
> 字符串若形如 `{…}` / `[…]`（上游 `String?.isJson()`）**解码成 JSON 条目**（所以
> `$.title` / `$.url` 命中，福书网的章列表就是 `JSON.stringify({title,url})` 的数组），其余字符串
> 当 HTML 片段解析；对象 / 数组 / 标量仍是 JSON scope。
>
> **`result` 的元素垫片（同一轮的取舍）：** 上游在**条目上的裸 `@js:`** 里把 `result` 绑成 jsoup
> `Element`，真实源因此会写 `result.attr('href')`、`result.select('span').get(1).text()`。沙箱没有
> DOM（ADR-0029 §决策 5），本仓改为**宿主就地求值再内联**：只处理参数是字面量的链
> （`attr` / `text` / `ownText` / `html` / `outerHtml` / `select` / `children` / `parent` /
> `first` / `last` / `get` / `size` / `elementSiblingIndex`），替换成一个 JS 字面量；
> 变量参数（`get(i)`）或链里出现未知元素方法时**整条不内联**，脚本原样交给沙箱响亮失败。
> 整页 `result` 仍是正文文本（上游同形），不做这个替换。真实源证据：re0zero 的
> `tocRule.isVolume = @js:result.attr('href')…`（920 次 `not a function`）、福书网的
> `ruleExplore.author`、金银小说网的 11 条搜索字段。

> **展开的两处边界（已登记，均有测试）：** ① 展开深度上限（8 层）：上游的递归替换没有上限，
> 而按源变量可以装着规则文本，自引用会让一条字段永远展开下去，故以可定位的 `parseFailed` 收场；
> ② 未闭合的 `{{…}` 在规则字段里原样留下（上游的 `{{[\w\W]*?}}` 也匹配不上），但在 **URL** 里
> 是显式 `parseFailed`（§4 不允许字面 `{{…}}` 落到请求层），未闭合的 `@get:{` 也是 `parseFailed`。

**大小写处理：** 原版文档同时出现 `@css:` / `@CSS:`、`@json:` / `@Json:` 等写法。
本项目按**前缀大小写不敏感**实现，并为每种前缀补一条测试（状态：已确认）。

> **HTML 实体反转义（登记差异，2026-10-13 取证）：** 上游值规则的 `unescape` 默认为 `true`，对含 `&` 的
> 结果做 `StringEscapeUtils.unescapeHtml4`（`AnalyzeRule.kt:297-308`、`:362-366`），
> `java.getString(rule, false)` 可关掉。本仓**不做**实体反转义。实际差异比看起来小：DOM 的文本 /
> 属性提取本来就被 HTML 解析器解码过，真正不同的是 `html` / `all` 一类**原样**提取
> （上游会把 `&lt;b&gt;` 还原成 `<b>`）。去向与触发条件登记在 `docs/dev/roadmap.md` §3.7；
> `java.getString(rule, true)` 因此具名拒绝（ADR-0037 §决策 6）。

> **状态列的 3.7 证据（2026-10-12）：** 全部 19 条 M0 行的状态列已由真实回归改为「已确认」，
> 逐行结论（语法 / 书源 / 链路 / 结论）与四次活站点运行的输出在 `tool/spot_check/README.md` §4b；
> 用到的四类证据分别是：
> ① 基线源（默认规则 + `##` + 位置）四段跑通（§4）；
> ② 同站 **`@css:` 派生源** 16 处等价映射（行使 #12 / #29）；
> ③ 同站 **语法覆盖派生源** 9 处等价映射（行使 #3 / #4 / #6 / #7 / #10 / #25 / #26 / #27 / #28，
> 与基线得到相同的计数与正文哈希）；
> ④ `@js:` 语料源（猫耳FM）在活站点上行使 #11 / #13 / #14。
> 两个派生源的逐处映射表在 `test/fixtures/book_sources/README.md`。

> **#1 / #2 类型注记（2026-10-12，ADR-0032）：** 默认规则的**类型**是
> 「`class` / `id` / `tag` / `text` / `children`，**或一段原始 CSS**」。类型不在这五个之内时
> （`.searchresult`、`li`、`dd`、`p`、`tr!0`、`#txt`、`div.item`），该段整体作为 CSS 选择器交给
> cascadia；`!` / `[...]` 后缀仍按位置解析（`tr!0` 不是合法 CSS）。`unsupportedRule` 只留给真正
> 未实现的标志（`:正则` / `@webJs`；XPath 自 M25/S5b 起支持，见下方注记）。依据：G2b spot-check 实测
> **197 条 M0 源中 137 条（69.5%）** 依赖该写法（复算命令与输出见 `tool/spot_check/README.md` §3；
> ADR-0032 §背景的原始 157/270 已作废）。
>
> **`<js>` 的补录依据（2026-10-12，架构师审核 R1 + 开发组行号核对）：** 它此前只在代码里被拒绝、矩阵
> 没有行 —— 正是本节 #25–#27 补录注记要防的缺口（「引擎拒绝得对、账本却没记」），故补为 **#31**
> （追加在表尾，不插入中间）。上游证据两层，均已在 fork `HapeLee/legado-with-MD3@master` 上核到行号：
> ① `app/src/main/java/io/legado/app/constant/AppPattern.kt:5-6` 的
> `JS_PATTERN = Regex("<js>([\\w\\W]*?)</js>|@js:([\\w\\W]*)", IGNORE_CASE)` —— 一个 pattern 同时匹配
> 两种包装（即「任意位置｜可作为其他规则的分隔符」，示例 `tag.li<js></js>//a`）；
> ② `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt:157`（注释「执行 `@js`，`<js></js>`）、
> `:168`（`private fun analyzeJs()`）、`:171`（`JS_PATTERN.findAll(ruleUrl)`）—— 因此它在 **URL 规则**
> 里同样生效。核对日期：2026-10-12。

> **`:正则` 注记（2026-10-27，M25/S5e）：** 上游只在 `getElements` / `getElement` 里有 `Mode.Regex`
> 分支（`AnalyzeRule.kt:393/430`），`getString` / `getStringList` 没有——所以这一条**只作用于书籍列表与
> 目录列表**，值规则位置写了 `:` 是具名拒绝（`unsupported::`），而不是一个悄悄返回规则原文的结果。
> 三条要与上游对齐的语义：
>
> 1. **`&&` 是正则链**（`AnalyzeByRegex.getElements` 的 `rule.splitNotBlank("&&")`）：除最后一条外，
>    每条正则把文本**缩到自己的匹配段**再交给下一条；最后一条每个匹配产出一个条目。
> 2. **条目 = 一次匹配的全部组**：`[整段, 组1, 组2, …]`（Java 的 `groupValues`，含 `$0` 整段）。
>    条目字段用模板取组值：`chapterName: $2$3`、`chapterUrl: https://a.test/c/$1`（上游
>    `SourceRule.splitRegex` 拆 `\$\d{1,2}`，`makeUpRule` 用该条的组值填回）。模板可以带
>    `##正则##替换`（矩阵 #9）。
> 3. **文本来源是页面正文**（`DomScope.body`，元素 scope 上是它的 `outerHTML`）；对着 JSON 值跑正则
>    是 `parseFailed`（没有正文）。条目上的非模板规则（例如 `class.a@text`）具名拒绝为
>    `unsupported:regex:item`——正则匹配没有 DOM 可选。
>
> 语料命中 **2 源 / 2 处**，都是目录列表（若夏的 `<id> isvip 章节名` 三段组、快眼小说的
> `正文卷…/dl && href="…">名字` 正则链）。

> **XPath 注记（2026-10-27，M25/S5b，ADR-0080）：** 上游把「以 `/` 开头」的规则都当 XPath
> （`AnalyzeRule.kt:637-639`），本仓只认 **`//`** 与 **`@xpath:`**（大小写不敏感）：语料里 131 处 XPath
> 没有一处以单个 `/` 开头，而根相对地址（`/static/x.jpg`）也可能落进 `coverUrl` 这类规则字段——把
> 「`/` 开头一律 XPath」照搬进来会让那种源静默变成一条选不中的表达式。支持面是**自研子集**（没有可用的
> Dart 3 XPath 包，取舍见 ADR-0080）：
>
> - **路径**：`/`（子）、`//`（后代）、`.` / `..`、`@attr`（属性轴）；
> - **节点测试**：标签名、`*`、`text()`；
> - **轴**：`child` / `descendant` / `descendant-or-self` / `self` / `parent` / `following-sibling` /
>   `preceding-sibling` / `attribute`；
> - **谓词**：`[N]`、`[@a='v']`（`'` 与 `"` 都收）、`[contains(@class,'x')]`、`[contains(text(),'x')]`、
>   `[not(...)]`、`[starts-with(...)]`、`[position() < last()-1]`、`[.//a]`（存在性）、`[a and b]` / `or`；
> - **并集**：`|`（答案是**节点集合**，按文档顺序去重）。
>
> 三条语义口径：① 结果是**文档顺序**（`//h2/a//text()` 答 `<b>粗体</b>尾巴` 的先后）；② 元素的值是
> 折叠空白后的整段文本（与 `text` 提取同一口径），`text()` 只答**直接**文本子节点；③ 列表规则必须选中
> 元素——选中文本 / 属性的列表规则是 `parseFailed`，不静默少几条。**具名拒绝**（`rulePath` 为
> `unsupported:xpath:<语法>`）：`ancestor` / `ancestor-or-self` / `following` / `preceding` / `namespace`
> 轴、`node()` / `comment()` 节点测试、`@*`、以及 `count()` / `normalize-space()` / `concat()` 等函数。

### 3.1 实现分期（对齐 ADR-0014）

| 阶段 | 范围 | 完成判定 |
|---|---|---|
| **M0** | 矩阵 #1–#14、#25、#26、#27、#28、#29；搜索 / 详情 / 目录 / 正文四段完整字段；`nextTocUrl`；`nextContentUrl`；`{{key}}`、`{{page}}`、`{{baseUrl}}` | 至少 2 个真实书源完成「搜索 → 详情 → 目录 → 正文」离线回放 |
| **M1** | 矩阵 #15–#19；`exploreUrl` 发现页；`canReName`；`updateTime`；`java.timeFormat`；`concurrentRate` | 每条语法至少 1 条真实书源验证记录 |
| **M2 / 暂不实现** | 矩阵 #20、#22、#30；登录脚本与登录 UI；RSS / 订阅源；朗读规则 | 命中时返回 `ParseFailure(unsupportedRule)` |

**M0 未全部通过前，不得发布「支持导入书源」的版本。**
命中 M2 或任何未实现语法时，禁止静默返回空结果（C-SRC-4）。

### 3.2 解析顺序

```
原始规则串
  → 按 `||` 切分候选（依次尝试，首个非空即成功）
    → 每个候选按 `%%` / `&&` 切成**并列分支**（各分支从同一 scope 求值：
      `&&` 合并两侧结果、`%%` 交叉取数）
      → 每个分支：识别前缀标志（@@ / @css: / @json: / @js: / @xpath: / 默认）
        → 按 `@` 分段：类型段（可多段） → 提取段
        → 应用位置、负索引、`!` 排除、首字符 `-` 倒置
        → 取出内容（text / textNodes / ownText / html / all / 属性）
  → 最后按顺序应用所有 `##` 替换
```

> **字段集的前置步（2026-10-14，b6）：** 一个**字段集**（`ruleBookInfo`）在逐字段解析之前，
> 先应用它的 `init`（若有）：按本节顺序求值 `init`，再把结果当作后面每个字段的 scope。
> 语义、失败档位与本仓差异见 §2 的 `init` 注记。

### 3.3 默认规则的段结构（原版语义）

| 段 | 说明 |
|---|---|
| 第 1 段 | 类型：`class` / `id` / `tag` / `text` / `children` 等；`children` 取全部子标签，**忽略第 2、3 段** |
| 第 2 段 | 名称；`text` 类型时表示「文本内容的一部分」 |
| 第 3 段 | 位置：正索引从 0 开始，负数取倒序；不加位置表示取全部 |
| 末段 | 提取内容：`text` / `textNodes` / `ownText` / `html` / `all` / `href` / `src` 等，或 HTML 属性名 |

---

## 4. URL 模板与变量

URL 字段的渲染统一走同一个渲染入口（同步部分仍是 `renderUrlTemplate`，C-SRC-5），禁止手写拼接；
`{{…}}` 的求值边界见本节末尾的注记。

| 变量 | 适用位置 | 含义 | 分期 |
|---|---|---|---|
| `{{key}}` | `searchUrl` | URL 编码后的搜索关键词 | M0 |
| `{{page}}` | `searchUrl`、`nextTocUrl`、`nextContentUrl` | 页码，从 1 开始 | M0 |
| `{{baseUrl}}` | 全部 | 当前页 URL（JS 中同名变量） | M0 |
| `{{}}` 内嵌规则/JS | 全部 | 默认按 JS 求值（内层是规则头时按规则求值），见矩阵 #18 | M1 |
| `{{变量名}}` | 全部 | `@put:` / `@get:` 读写的变量（见 §3 的 #16 注记） | M1 |

约定：

- 关键词**必须** URL 编码，且只编码一次、不重复编码。
- 相对 URL（以 `/` 或非协议开头）必须以当前页 URL 为基准解析为绝对 URL。
- 未定义的变量渲染为**空字符串**并记录 warning；不得保留 `{{...}}` 原文。
- 在**搜索 URL 与发现 URL** 中，`{{}}` 内只允许 JS；解析器必须拒绝在其中写非 JS 规则。

> **`{{…}}` 在 URL 里的求值边界（2026-10-12，随矩阵 #18 落地）：** 名字落在上表前三个的
> 占位符仍走**同步模板渲染**（`key` 只编码一次），其余名字交给**沙箱**当 JS 求值；
> 内层以规则头开头（`@@` / `$.` / `$[` / `//` / `@xpath:` …）在 URL 里**按名拒绝**
> （`unsupportedRule`，C-SRC-4）——搜索 / 发现 URL 只允许 JS。URL 脚本的绑定与 §6 一致，
> 额外多一个 `key`（搜索关键词；ADR-0034 §决策 3）；`result` 尚未取页面，保持不绑。
> 脚本结果里的整数不带 `.0`（上游对整数结果的格式化，`AnalyzeUrl.kt:203-207`），
> 未闭合的 `{{` 与渲染失败的 `{{…}}` 都是该字段的 `ParseFailed`（不把字面 `{{…}}` 交给请求层）。

> **尚缺的三条 URL 方言（2026-10-26 登记，去向 `docs/dev/engine-parity.md` S4）：** 本节的模板语义
> 只覆盖 `{{key}}` / `{{page}}` / `{{baseUrl}}` / `{{…}}` 四类，上游还有三处**没有**对应实现：
> ① 页码取值 `<1,2,3>`（按 `page` 取第 n 个、超出取末值，`AnalyzeUrl.kt:777`）；② 段链 `@result`
> （URL 由「字面段 + `@js:`/`<js>` 段」串联，字面段里的 `@result` 引用上一段产出，`:157-176`）；
> ③ GET query 的**全量**按 `charset` 编码（本仓只编 `{{key}}`，`:268-273`、`:295-300`）。
> 命中前两者的真实源现在会拿到字面文本/未转码参数（响亮失败或 404，不静默成功）。

### 4.1 目录与正文的特殊规则

| 规则 | 原版语义 | 分期 |
|---|---|---|
| `chapterList` | 结果列表；**首字符 `-` 使列表反序** | M0 |
| `chapterName` / `chapterUrl` | 章节名与章节 URL（相对路径需转绝对） | M0 |
| `isVip` | 结果为 `null` / `false` / `0` / `""` 时视为**非 VIP** | M0 |
| `isPay` | 已购标记；与 `isVip` 同一套 `isTrue()` 判定 | **M25/S2** |
| `isVolume` | 分卷标记；卷标题没有 URL 时用「标题 + 序号」占位 | **M25/S2** |
| `wordCount` | 章节字数，展示用字符串 | **M25/S2** |
| `formatJs` | 整份目录一次跑的标题重写脚本（`index` / `chapter` / `title` / `gInt`） | **M25/S2** |
| `preUpdateJs` | 取目录**之前**跑的脚本；失败即整段目录失败 | **M25/S2** |
| `updateTime` | 可调用 `java.timeFormat(timestamp)` 转为 `yyyy/MM/dd HH:mm` | M1 |
| `nextTocUrl` | 支持**单个 URL** 或 **URL 数组**；JS 返回 `[]` / `null` / `""` 时停止加载下一页 | M0 |
| `content` | 正文内容；**每一个匹配都参与**（上游 `getString` 用换行拼接 `getStringList`），结果统一成**纯文本**（`@html` / `@all` 的标签在这里摘掉） | M0 / M26 |
| `nextContentUrl` | 正文分页；返回空即停止 | M0 |
| `replaceRegex` | 正文的批量替换规则 | M0 |
| `canReName` | 允许重命名书籍 | M1 |

> **正文的统一形状（2026-10-27，M26 前置修复）：** 正文交给 `replaceRegex` 与净化规则之前，先
> 变成**纯文本**，并且**每个匹配都参与**。两条都是对着真实语料修的：
>
> 1. **多匹配拼接。** `content` 以前只取第一条匹配，`#content p@textNodes` 这种「一段一个元素」的
>   规则会让整章只剩一行（免费小说）。现在按上游 `getString` 的口径把全部匹配用换行拼起来
>   换行 → 与分页拼接、副文追加同一形状）。
> 2. **HTML → 纯文本。** 语料 249 条 `content` 规则里有 **83 条**以 `@html` / `@all` 结尾，产出的是
>   标签（PO18 系、顶点小说网等）。上游把正文当 HTML 留着、由自己的富文本视图渲染；本仓的阅读端
>   是纯文本（`readerBodyText` 按换行分段），所以标签必须在正文边界就摘掉：块级标签（`p` / `div` /
>    `br` / `li` / `tr` …）变成换行，行内标签剥掉，`<script>` / `<style>` 的**内容**整段丢弃，
>   `&nbsp;` / `&amp;` / `&#xNN;` 解码，空行与缩进折叠，图片丢弃（阅读端没有图片落点，S6c 才有）。
> 3. **转换在 `replaceRegex` 之前。** 这些替换规则是作者对着**能读的正文**写的（`&nbsp;`、`\<.*`
>   这类清理 HTML 残留的写法）；让它们继续面对标签，会把标签后面的真文字一起删掉。成品正文再做一次
>   首尾 `trim`（`replaceRegex` 删掉一整段会留下那一段的换行）。
> 4. 实现是**扫描器不是 DOM**（`html_to_text.dart`）：正文已经为跑规则解析过一次，为了丢标签再解析
>   一遍是 M26 要去掉的那类工作；纯文本输入直接原样返回。

> **§4.1 的分页与净化语义（2026-10-12，随 `docs/dev/roadmap.md` 3.5 落地）：** 上表是原版语义；
> 本仓实现到哪一步、以及与原版有意不同的地方，逐条记在这里（原来的「返回空即停止」太粗，
> 分页要落到可测的行为）：
>
> - **翻页规则里的 `{{page}}` / `{{baseUrl}}` 按 URL 模板渲染（§4 的 M0 变量）。** 规则文本整个
>   就是 URL 模板（只含 `page` / `baseUrl` 两个变量、不含 `@` 段）时，整条规则就是下一页地址；
>   否则按选择器规则求值，求出的**每个值**再按模板渲染。`{{page}}` = 该 URL 成为的页码
>   （1-based，即 `{{baseUrl}}` 那一页的页码 + 1），`{{baseUrl}}` = 读到该规则的那一页。
>   渲染后不得把字面 `{{...}}` 交给请求层（§4），渲染为空的值得丢弃；含其它名字的 `{{...}}`
>   （矩阵 #18，M1）不按模板处理，仍由引擎按未实现语法拒绝。
> - **`nextTocUrl` / `nextContentUrl` 是列表，不是单值。** 两者都按规则引擎的
>   `extractAll` 读取（上游 `getStringList`，`BookChapterList.kt:210-218`），所以一条规则
>   可以给出一个 URL 或一组 URL；只取第一个会把「页码链接写成一条 CSS」的书源静默丢页。
>   每个值都按**读到它的那一页**解析成绝对地址（C-SRC-5），当前页自身与重复值被丢弃
>   （上游过滤 `redirectUrl`）。
> - **翻页是队列且有限。** 每一页的翻页规则都入队，已读过的页不重读（上游用
>   `nextUrlList.contains` 防自指）；总页数上限与停止时的 warning 归 §9。
>   **登记一处与上游的差异：** 上游对「数组」分支只做一次**并发**抓取，且不在那些页上继续读
>   翻页规则（`BookChapterList.kt:110-118` 传 `getNextUrl = false`），而对「单值」分支接链；
>   本仓 M0 不分这两个分支，每一页都继续读它的翻页规则，靠「不重读 + §9 上限」封顶——
>   对同一组页码链接，这只多读一些站点本来就要给的页，不会漏页。并发抓取归 3.8。
> - **后续页失败在目录与正文上不同：** 目录缺页按 §9 降级（保留已读到的章节 + warning），
>   正文缺页则**整章失败**——把截断的正文当成成功就是把失败伪装成成功。
> - **`isVip` 的真值判定：** 按上游 `String?.isTrue()`（`BookChapterList.kt:261-264` 调用：
>   `if (isVip.isTrue()) bookChapter.isVip = true`；谓词 `StringExtensions.kt:75-80`，2026-10-12
>   核对）：`null` / 全空白 / 字面量 `"null"` → 非 VIP；其余值除非**逐字**匹配
>   `(?i)^(?:false|no|not|0|0.0)$`（且用 **trim 后**的值匹配）否则算 VIP——所以
>   `true` / `1` / `是` / `yes` 都是 VIP，`false` / `no` / `not` / `0` / `0.0` 不是。
>   两处需要照抄的细节：`"null"` 的比较发生在 **trim 之前**（所以 `" null "` 反而是 VIP），
>   模式里的 `.` **未转义**（`0x0` 也匹配）——改成更「正确」的写法就成为与上游的有意差异，
>   必须先登记再改。
> - **`replaceRegex` 是「独立替换段」规则**（上游「独立使用相当于 `all##正则##替换`」）：
>   在**拼接后**的整章正文上应用一次（上游 `BookContent.kt:190-193`），支持矩阵 #9 的
>   `##正则##替换` 与矩阵 #25 的 `##正则##替换###`。**有意不做的：** 上游在替换前后还会
>   按行 trim 并加全角缩进（`BookContent.kt:191-194`），那是阅读端排版，不属于解析阶段，
>   本仓的正文保持解析出来的原样（否则语料回归里已有的正文会被改形）。
>   规则体带选择器时报 `parseFailed`（规则里没有可选的 DOM）；`@js:` 净化规则在沙箱里跑
>   （`result` = 拼接后的整章正文，与上游 `analyzeRule.getString(replaceRegex, contentStr)` 同形），
>   其余未实现标志（`@webJs` / `{{}}` …）报 `unsupportedRule`；三种都降级为「不替换」+ warning
>   （ADR-0026 §决策 2）。

> **副文与正文页标题（2026-10-26，M25/S2，ADR-0078）：** `ruleContent` 的另外两条字段也该生效了，
> 顺序照抄上游 `BookContent.kt:144-196`（`content` → `subContent` → `title` → `replaceRegex`）：
>
> - **`subContent`（副文）。** 文本源把副文**追加**到正文（换行分隔，与分页拼接同形）；**音频源**不并进
>   正文，而是作为 `ChapterContent.lyric`（上游写成章节变量 `lyric`）交回调用方。规则值是 `http(s)` 开头
>   的地址时，先取那一页的**正文原文**（上游 `AnalyzeUrl(...).body`）；那一页取不到只记 warning、
>   副文为空，**不**判整章失败——正文仍然可用。
> - **`title`（正文页章节名）。** 正文读完后在**第一页**的 scope 上求值；非空即改名，并把值里**最后一个**
>   media URL 当作 `reviewImg`（上游 `AppPattern.imgRegex`）。只剩一张图时标题回落到目录里的名字。
>   与上游的一处小差异：标题里残留的 HTML 标签会被剔掉（`@html` 取出来的 `<div id=…>` 或半截
>   `<img src="` 显然不是章节名）。
> - **落地形状。** 正文阶段返回 `ChapterContent`（正文 + 标题 + reviewImg + 歌词），缓存也按整个结果存：
>   只有正文的章节仍以**纯文本**缓存（旧形状、无迁移），带标题/歌词时才写成一行带版本号的 JSON。
>   阅读器端口目前只取 `.body`，所以**正文页改名与歌词还没有显示在界面上**（登记在
>   `engine-parity.md`）。

> **目录字段族（2026-10-26，M25/S2，ADR-0078）：** 六条语义，逐条对齐上游
> `BookChapterList.kt`（行号见 `engine-parity.md` 3.2）：
>
> - **无名条目丢掉。** 名字读不出来（规则未命中 / 被拒）的条目不是章节（上游
>   `if (title.isNotEmpty)`），整条跳过——这与 `isVip` / `wordCount` 这类**可选字段**的
>   「降级为空」不同：名字是条目存在的条件。阶段本身不会因此失败，只是目录变短。
> - **`isPay` / `isVolume` / `isVip` 共用 `isTrue()`**（见下一条的谓词）。`isPay` 目前只解析、
>   不参与阅读器的锁定判定（锁定仍看 `isVip`）。
> - **卷标题的占位地址。** `isVolume` 为真的条目若没有 URL，地址取「标题 + 序号」（上游
>   `title + index`，无分隔符）；普通章节仍回落到目录页地址（ADR-0069 G8）。
> - **去重按 `(名字, URL)`、保序**（上游 `LinkedHashSet`）：分页目录里同一章出现两次只留第一次。
> - **`formatJs` 一条脚本跑完整份目录。** 每次迭代重绑 `index`（1-based）/ `chapter` /
>   `title`，`gInt` **跨章保留**；返回非空字符串才替换标题，返回空/抛错都保留原标题（上游
>   `runCatching(...).onFailure`）。整个目录是**一个 JS job**，所以它同样吃 §6 的超时与配额。
> - **`preUpdateJs` 在第一个请求之前跑，失败即失败。** 上游 `runPreUpdateJs(...).getOrThrow()`
>   会中断整次目录更新；本仓连请求都不发（`FetchToc` 在 `walk` 之前执行）。

> **「下一页 == 下一章」提前停止（2026-10-28，M27 第二轮日志）。** 上游 `BookContent.kt:90-96`
> 在翻页遍历里比较「下一页地址」与 `nextChapterUrl`，相同就停。本仓的 `walk` 现在也做这个比较
> （两边都按当前页绝对化）；校验阶段按上游 `BookSourceCheckRepository.kt:222-230` 把目录的
> **第 2 章**作为 `nextChapterUrl` 传进正文请求（卷标题不参与）。没有这一条，站点把「下一章」
> 写进 `nextContentUrl` 的源会被整本连读，直到翻页上限（一轮日志里 14 个源）。

> **正文缓存（2026-10-14，`docs/dev/roadmap.md` 5.2）：** 一章的**成品正文**（分页已拼好、`replaceRegex` 已跑过）
> 存进与 charset 缓存同一张 `cache_entries`，键复用 `CacheDao` 的稳定键（`ruleField` 固定为
> `content`、`page` 固定为 1，键含**书源 ID**，所以两个书源发布同一章节 URL 也不会串味）；
> TTL 的唯一出处是 `lib/features/book_source/domain/content_cache.dart` 的 `chapterCacheTtl`
> （**3 天**：非在架书读一次三天内不再请求，站点改过的章节三天内回来）。**在架的书不走 TTL**：
> 装配根的正文端口按书架行判定，写入时带 `persistent`（过期时间写哨兵 `DateTime.utc(9999)`），
> 一直留到用户在详情页/缓存管理页清掉这本书的缓存（ADR-0097 §决策 1）。
> **只缓存成功**：失败路径在写入之前就返回，一章的失败不会被永久粘住；
> **失败面在适配器（`CacheDaoContentCache`）里被吸收**，端口因此是 total——丢一条缓存只值一次请求，
> 绝不把章节变成失败（C-ERR-1、ADR-0033）。过期条目在**读**时即未命中，物理清理归 `docs/dev/roadmap.md` 5.7。
> 命中时 `FetchContent` 连书源限速都不进预算，因为这次操作一个请求都不发。

### 4.3 URL 规则的后缀 `,{…}`（M12，ADR-0047 §决策 1）

真实语料里 **50/128** 条源的 `searchUrl`（以及部分 `exploreUrl` 条目 / `tocUrl`）不是一个地址，而是
「地址 + 请求选项」：

```
https://a.test/modules/article/search.php,{ "method": "POST", "body": "searchkey={{key}}" }
https://a.test/modules/article/search.php?searchkey={{key}}&page={{page}},{"charset":"gbk"}
```

| 字段 | 语义 | 本仓 |
|---|---|---|
| `method` | `GET` / `POST`（`HEAD` 等本仓没有消费方） | ✅ `POST` 发 body；其余按 `GET` 发并记 `method:<名字>` |
| `body` | POST 载荷，可含 `{{…}}` | ✅ 是**规则**：URL / 表单里 `{{key}}` 按 `charset` 百分号编码，**JSON / XML 载荷里原样** |
| `charset` | 该请求的编码 | ✅ 双向：请求侧编码 `{{key}}`，响应侧作为 §5 的**最高优先级声明** |
| `headers` | 该请求额外 header（对象，或**字符串形式的对象**） | ✅ 合并到书源 `header` **之上** |
| `webView` | 用真实 WebView 渲染页面（`webView: true`）；**GET 与 POST + body 都支持**（POST 的表单由 WebView 自己提交，见下方约定），平台无 WebView2 / 取页失败回落普通 HTTP（ADR-0061 §决策 4、ADR-0062 §决策 1） | ✅ 走 `WebPageFetcher` 端口 |
| `webViewDelayTime` | `onLoadStop` 之后再等这么多毫秒才取 HTML（上限 30 s），给站点自己的脚本时间（ADR-0068 §决策 6） | ✅ M21a |
| `webJs` | 在渲染后的页面里执行脚本，返回字符串即 body | ✅ M21a（同时是 `ContentRule.webJs` 的实现） |
| `bodyJs` | 对**普通 HTTP** 响应体执行脚本，返回字符串即 body（渲染路径用 `webJs`）；先于 `sourceRegex` | ✅ M21a |
| `overrideUrlRegex` | 命中则把该 URL 当结果页，停止加载 | ✅ M21a |
| `retry` | 这一条请求的重试次数（规则侧上限 3） | ✅ M21a |
| `readTimeout` | 这一条请求的响应超时（上限 120 s） | ✅ M21a |
| `origin` / `type` / `js` / `dnsIp` / `proxy` / `callTimeout` / `HEAD` / `encodedForm` | 本仓没有对应实现 | ❌ **裁决不做**（ADR-0068 2026-10-24 增补）。**2026-10-28 改判：** 这些选项不再「忽略后照发」，而是**在取值处 `unsupportedRule` 失败**（`rulePath=unsupported:url-options:<名字>`）——丢掉 `js` 会改写地址，忽略只会把错误推到更远的网络层 |

约定：

- 切点是 `,\s*(?=\{)` **且**后面必须是「以 `}` 收尾的平衡对象」（上游 `AnalyzeUrl.paramPattern`）；
  `?q={{key}}`、地址里的普通逗号都不算后缀。
- 后缀是**宽松 JSON**：单引号、裸键、尾逗号、值里嵌 `{{…}}` 都是真实写法。
- 读不懂的后缀是 `unsupported:url-options` 的显式失败——**绝不**把 `,{…}` 当 URL 发出去
  （那是真实语料里 50 条源 404 的来源）。

**地址本身的三条方言（M25/S4，`AnalyzeUrl.kt:157-213`、`:295-300`）：** 后缀之前的那段地址不只是
模板，它依次经过三步，顺序与上游 `initUrl` 一致（JS 段 → `{{…}}` → 页码列表）：

| 写法 | 语义 | 例 |
|---|---|---|
| **JS 段链** `@js:` / `<js>` | 规则是「字面段 + 脚本段」的链：脚本拿到当前值作 `result`，返回值成为新值；**字面段替换**当前值，但先把其中的 `@result` 换成它。整条规则就是一个 `@js:` 时，地址就是脚本的返回值 | `@js:'https://a.test/s?q=' + key` |
| **页码列表** `<1,2,3>` | 按**请求的页码**取第 n 个，超出取末项 | `https://a.test/list/&lt;1,2,3&gt;.html` |
| **GET query 全量编码** | 声明了 `charset` 时，**整条 query** 按该编码百分号转义（空格是 `%20`，不是 `+`）；已经编码过的 query 原样保留 | `https://a.test/s?q=剑来,{"charset":"gbk"}` → `q=%BD%A3%C0%B4` |

三条要知道的事：① `@js:` 是**贪婪**的（吞到规则尾部），所以链中想再写字面段要用 `<js>…</js>`；
② 字面段是**替换**而不是拼接，只在 `@result` 处保留前一个值（上游 `it.replace("@result", result)`）；
③ `charset: "escape"` 是上游另一套编码方言（空格与保留字符的细节不同），本仓**没建模**：地址原样
发出，`{{key}}` 仍走表单编码。

### 4.1b 搜索页就是详情页（`bookUrlPattern`，M25/S2）

上游的搜索阶段有两条「当成详情页读」的路径（`BookList.kt:62-84`、`:100-110`），本仓两条都实现：

1. **`bookUrlPattern` 全匹配最终响应地址**：搜索请求被重定向进了详情页（单书站、或搜索直接跳书），
   这时不再读列表规则，而是用 `ruleBookInfo` 把这一页读成**一条**搜索结果（书名、作者、封面、简介…），
   地址就是响应地址本身。
2. **没有 `bookUrlPattern` 且列表为空**：`bookList` 一条都没命中时先按详情页再读一次；详情页也读不出
   书名，就返回**空结果**（不是 `parseFailed`）。

因此三件事与从前不同，改动都是对齐上游：①「搜索页没有结果条目」不再是阶段失败（书源校验那边仍把它
判成「搜索失效」，因为校验要的是「这条源还能不能搜」，见 `roadmap.md` 5.10）；②`bookUrlPattern` 是
**全匹配**（Kotlin `String.matches`），写错的正则只记 warning 并按普通列表继续；③详情页读出来的那一条
结果用的是 `ruleBookInfo`，所以 `ruleSearch` 里即使写了 `bookUrl` 也不参与这条路径。

> 待办：`bookUrlPattern` 命中后「列表规则完全跳过」意味着列表字段（`lastChapter` 等）只来自
> `ruleBookInfo`；这与上游一致，但如果某源的详情规则缺字段，搜索结果会比列表路径稀。真实语料出现时
> 再评估是否补「先按列表读、再回落详情」。

### 4.2 发现页（`exploreUrl` 与 `ruleExplore`）

本节是发现页的**唯一出处**（决策理由与四条登记差异见 **ADR-0035**；字段分期归 §2）。

**分类来源（`exploreUrl`）** —— 两种形态，按前缀判定、互斥：

| 形态 | 写法 | 语义 |
|---|---|---|
| 分类串 | `玄幻::https://a.test/list/{{page}}.html&&都市::https://b.test/...` | `&&` 或换行分隔（上游正则 `(&&\|\n)+`）；条目 `标题::URL`。**空标题**的条目报 `unsupportedRule` 并记录（**URL 为空是分组标题**，保留成不可点标签，ADR-0069 G11），其余条目照常 |
| 整字段 JS | `@js:…` 或 `<js>…</js>`（大小写不敏感） | `<js>` 形态**必须**以 `</js>` 收尾，否则该字段 `parseFailed`；返回值认 **JSON 数组**（元素含 `title`，可选 `url`）**或**上面的分隔串 |

- **整字段 JS 的绑定：** `baseUrl` = **书源 URL**、`source`、`java.*`（与 `@put:` / `@get:` 同一份变量表，ADR-0034，`sourceId` = 书源 URL）；**不绑 `key`**（字段里写 `key` 即 `js:error`），`page` 固定为 `1`，**无 `infoMap`**（命中即 `js:error`，不静默给 undefined）。
- **失败面：** 脚本异常或返回值不可解析 → 该字段 `parseFailed` + 日志（上游把错误做成一个 `ERROR:…` 分类展示，属登记差异）。
- **分类类型：** M1 只支持 `type` 缺省或 `url`；表单型分类（`text` / `button` / `toggle` / `select` 及 `chars` / `default` / `action` / `style`）**不在 M1**，该分类报 `unsupportedRule` 并记录（§11）。

**请求渲染：** 条目 URL 与 `searchUrl` 共用 `renderUrl`（C-SRC-5）；`{{page}}` / `{{baseUrl}}` 与「URL 内其他 `{{…}}` 只允许 JS、规则头按名报 `unsupportedRule`」的边界**归 §4 / 矩阵 #18，本节不另立**。发现页**不绑 `key`**——M1 没有「按关键词发现」入口；将来加入口时按 ADR-0034 §决策 3 扩展。

**一次请求一页：** 页号由调用方给（与 `{{page}}` 同口径），**不自动批量翻页**，因此**不占** §9 的自动队列页数上限；单页失败只影响该分类（§9）。

**结果解析（`ruleExplore`）：** `ruleExplore` 缺失或 `bookList` 为空 → **整条回落 `searchRule`**（**不是**逐字段回落），记账字段同样整条来自胜出的一方；唯一实现点是 `ExploreBooks` UseCase（ADR-0035 §决策 2）。列表字段的语义与分期见 §2。

> **状态与实现边界（2026-10-13，M1-b4a 已落地）：** `exploreUrl` 两种形态、条目解析与回落都在
> `domain/explore_categories.dart`（纯函数）+ `domain/usecases/fetch_explore_categories.dart`
> （整字段 JS 经引擎的 `RuleEngine.evaluateJs`，绑定同 ADR-0035 §决策 4）与
> `domain/usecases/explore_books.dart`。四处需要写下来的边界：
>
> - **没有 `exploreUrl`（或全空白）的书源答空列表、不是失败**：那不是错误书源，而是没有发现页；
>   分类 UI 的空态就是它。只有**声明了却读不出来**的 `exploreUrl` 才是 `parseFailed`。
>   （本节此前未规定这一条，属规格缺口，已在 `docs/dev/roadmap.md` §3.7 登记待确认。）
> - **分类条目 URL 按 §4 解析成绝对地址**（基准 = 书源 URL，ADR-0035 §决策 4 的 `baseUrl`）：
>   条目写 `/list/{{page}}.html` 是常态；相对 `searchUrl` 走同一条规则（此前的隐性缺口）。
> - **`<js>` 未以 `</js>` 收尾** → 该字段 `parseFailed`，`rulePath` 标 `exploreUrl:js-not-closed`，
>   **不跑脚本**（登记差异 ①）。
> - **被拒条目**（空标题 / 缺 URL / 无 `::` / 表单型）逐个记一条 warning，含书源 ID、
>   `field=exploreUrl`、`kind=unsupportedRule` 与原因，其余条目照常（C-SRC-4）。

---

## 5. 编码

- 必须使用 `betto_charset_detector` 检测（C-NET-3），检测顺序：
  **URL 规则声明的 `charset`（§4.3）** → HTTP `Content-Type` → HTML `<meta charset>` → 字节嗅探 → 回退 UTF-8。
  前两步是**权威声明**：只要有声明就必须用它，嗅探仅用于两者都缺失的页面。
  URL 规则（书源作者）的声明排在最前，因为站点"声明 utf-8、实际发 GBK"是常态，而作者已经写明了；
  它走 §5 的**已声明车道**（宽容 + warning），不是嗅探车道。
- 本节的缓存只讲**编码检测**；**正文缓存**复用同一张表与同一种键形状，其键与 TTL 归 §4.1。
- 检测结果必须缓存到「书源 ID + URL」维度，避免重复嗅探（**已落地：Phase 3.9**）：
  缓存的是**嗅探车道的结果**，键复用 `CacheDao` 的稳定键（`ruleField` 固定为 `charset`、`page` 固定，
  使同书源同 URL 的两个阶段共享一条；C-NET-6 的键形状不变），TTL 是
  `core/network/charset_cache.dart` 的 `defaultCharsetCacheTtl`（唯一出处）；
  **声明车道不进缓存**：`Content-Type` / `<meta>` 每次都能自己读到，而且声明永远优先于缓存标签
  （ADR-0031 的两条车道不因缓存而变）。缓存不可用（读 / 写失败）或无书源 ID 时只是一次
  **重新嗅探**，不得让请求失败（C-ERR-1）——**失败面在适配器（`CacheDaoCharsetCache`）里被吸收**，
  该端口的契约因此是 **total**（读返回 `null`、写 no-op、绝不抛）：这样 `core/network` 的请求路径
  不持有任何异常边界，C-ERR-2 的「`on Exception` 只允许在 `presentation/` 的 Notifier」边界不被触碰，
  `http_client` 也不需要认识 drift。
- **解码失败的判定按车道区分（ADR-0031，2026-10-11 生效）：**
  - **已声明车道**（HTTP `Content-Type` 的 `charset`、`<meta charset>`）：按**声明出的编码族**宽容
    解码（非法字节 → U+FFFD）并记一条 warning（含书源 ID、URL 摘要、字段路径；不得含正文 /
    Cookie / Token，C-ERR-8 / C-SEC-4）。理由：声明是权威，宽容只处理「声明正确、个别字节损坏」；
  - **嗅探车道与未知标签回退**：保持严格，解码失败仍返回 `ParseFailure(encodingFailed)`。
    理由：猜测 + 宽容会把「猜错编码」伪装成成功（乱码进正文），比响亮失败更糟（C-SRC-4）。
  - **禁止「一律 UTF-8 宽容解码」**：宽容必须仍走声明出的编码族；也不得把未知标签或嗅探结果
    兜到 UTF-8 宽容路径。宽容结果中的非法字节必须是 U+FFFD，且**不丢字节**（不得错位）。
  - 解码在每次响应上只发生一次，故**一个页面至多一条 warning**。
  - 本车道区分**不**新增 `ParseFailureKind`（§7 仍是 9 个 kind 的唯一出处）。

### 5.1 可解码的编码集与已知缺口（实测 2026-10-11）

检测得到的是 IANA 标签，解码由 `charset` 把标签变成 `Encoding`（`tech-stack.md` §5）。
标签空间比解码器空间大，**未支持的标签会回落到 UTF-8**，通常接着以
`encodingFailed` 失败（安全，但功能缺失）：

| 标签 | 结果 |
|---|---|
| `utf-8`、`utf-16le/be`、`utf-32le/be` | ✅ |
| `gbk`、`gb2312`、`gb18030`、`cp936` | ✅（四者共用 GBK 解码器） |
| `windows-1252`、`iso-8859-1/2/15`、`latin1` | ✅ |
| `shift-jis`、`euc-jp`、`euc-kr`、`us-ascii` | ✅ |
| `big5`、`big5-hkscs`、`cp950`、`csbig5` | ✅ **已声明车道可解码**（`enough_convert` 的 `Big5Codec`，ADR-0048）；**检测仍不认识 Big5**：无声明时不会自动猜成 Big5。`big5-hkscs` 的扩展区 → U+FFFD（部分支持） |
| `euc-cn`、`sjis`、`windows-31j`、`iso-2022-jp`、`koi8-r` | ❌ 回落 UTF-8 → 通常 `encodingFailed` |

**Big5 系：解码已补齐，检测仍缺（2026-10-21，ADR-0048）。** `charset 2.0.1` 未注册任何 Big5 编解码器，
因此新增 `enough_convert`（MPL-2.0，纯 Dart、零依赖）的 `Big5Codec` 补解码。现在：

- `Content-Type` / `<meta>` / **URL 规则（§4.3）** 声明 `big5` / `big5-hkscs` / `cp950` / `csbig5`
  → 按 Big5 解码（已声明车道，坏字节容错为 U+FFFD + warning）；
- **没有声明时仍然不猜**：`betto_charset_detector 0.1.0` 的候选表里没有 Big5，
  所以页面会按嗅探结果解（通常 `encodingFailed`）。所谓「缺口闭合」只到解码这一半；
- HKSCS 扩展区不在码表内，解成 U+FFFD，属**部分支持**。

**其它已知限制：** `gb18030` 按 GBK 解码，四字节扩展区字符会失败，属 M0 已知限制。
本表不因 ADR-0031（声明车道的宽容解码）而改变：宽容**不**扩大可解码的标签集，Big5 系仍然既不能
检测也不能解码；若将来发现某编码族没有宽容入口（见 ADR-0031 §背景），必须登记到本表。

> **宽容入口的实测登记（2026-10-12，G2b spot-check + ADR-0031 复审更正）：** 声明车道的宽容
> **只对上表里 `utf-8` 与 `gbk` 两个族实际可达**。两类原因必须分开记，它们不是同一件事：
>
> - **不可达（依赖行为所致）**：`shift-jis` / `euc-jp` 的**严格**解码在字节不完整时抛的是
>   `RangeError`（`Error`）而不是 `FormatException`（`charset 2.0.1`，`shift_jis.dart:26`），
>   宽容分支根本到不了，而且该异常会越过 `ParseResult` 契约逃到调用方 —— 按 ADR-0022 不得捕获
>   `Error`，故登记为待排期缺口（`docs/dev/roadmap.md` §3.7）；`euc-kr` 的解码器丢弃非法字节而不是失败，
>   没有可宽容的失败点。
> - **刻意排除（本仓策略）**：`us-ascii` / `utf-16` / `utf-32` 有宽容入口但**不用**——
>   声明了它们却解不开，说明**声明本身错了**，宽容只会把整页变成垃圾（ADR-0031 §决策 1 的
>   「声明是权威」前提不成立）。该策略的出处是本节，代码里只允许回链（ADR-0013 §3）。
>
> 两个现象都是**实测**，不是推断。

**嗅探的样本下限：** 字节嗅探只看前 8 KB；样本极短时（几个字节）可能误判为
`shift-jis` 等其他 CJK 编码，因此**不得**跳过前两步去信任嗅探结果。

---

## 6. JS 桥接白名单与配额

JS 规则运行在独立 Isolate 中，**只能**访问以下绑定（C-SRC-3）：

> **引擎已选定（ADR-0015）：** 下表绑定已在 `flutter_qjs_next 1.5.2` 上实测可行，
> 含后台 Isolate 中的回调桥。配额均真实生效：`QuickJsRuntime2(timeout: 5000)` 中断死循环、
> `memoryLimit: 32 * 1024 * 1024` 阻止超额分配；调用方仍须持有硬预算并 `Isolate.kill` 兜底。
>
> **载荷必须是合法 JSON：** 桥接层用 `jsonDecode` 解析 `sendMessage` 的第二个参数，
> 传裸字符串（如 `'ping'`）会抛 `FormatException`；必须写 `JSON.stringify(value)`。
> 详见 `tool/spike/README.md` §4。

| 绑定 | 形态 | 说明 | 分期 |
|---|---|---|---|
| `baseUrl` | `String` | 当前页 URL（原版同名变量） | M0 |
| `result` | `String?` \| `List` \| 响应对象 | 当前页 responseBody（原版同名变量） | M0 |
| `result`（**仅 `loginCheckJs`**） | 响应对象 | `body` 属性 + `url()` / `code()` / `headers()` / `header(name)` / `cookie()` / `contentType()` / `isSuccessful()` / `String(result)`——上游 `StrResponse` 的形状。拦截器的返回值决定页面（见下方「`loginCheckJs` 的返回值」） | M21a |
| `page` | `int` | 当前页码 | M0 |
| `source` | 只读对象 | **白名单字段**（M25/S5a）：`name` / `url` / `group`（本仓名）+ 上游名 `key` / `bookSourceUrl` / `bookSourceName` / `bookSourceComment` / `header` / `loginUrl`，其余不可见（`jsLib` 只在宿主侧） | M0 / M25/S5a |
| `book` | 对象（字段 + 方法） | 字段 `name` / `author` / `bookUrl` / `tocUrl` / `intro` / `kind`；阶段不知道时为 `null`。方法：`putVariable(k,v)` / `getVariable(k)`（= `java.put` / `java.get` 的规则变量表）、`setType` / `getType` / `setReverseToc` / `getReverseToc`（job 内可读回，**不影响宿主**）、`type` 字段。ADR-0061 §决策 5、ADR-0062 §决策 2 | M17 / M24 |
| `http.get(url, options)` | `String` | 经 `core/network/HttpClient` 代理，受超时与重试策略约束；`{response:true}` 改为返回整个响应对象 | M0 / M21a |
| `http.post(url, options)` | `String` | 同上 | M0 / M21a |
| `parse.getString(rule, doc)` | `String` | 复用规则引擎，可递归 | M0 |
| `parse.getElements(rule, doc)` | `List` | 同上 | M0 |
| `java.put(key, value)` / `java.get(key)` | `void` / `String` | 规则变量，与 `@put:` / `@get:` 是同一份（ADR-0034）；**仅 JS 内可用** | M1 |
| `java.ajax(url[, headers])` | `String` | **同步**返回正文（上游写法）。未命中本 job 的取页缓存时抛哨兵，worker 取页后**从头重跑**；失败抛错，规则自己的 `try` / `catch` 可用（ADR-0076 §决策 1，语义见下方「同步族」） | M24 |
| `java.post(url, body, headers)` | 响应对象 | **同步**返回响应对象（与 `loginCheckJs` 的 `result` 同形：`body` 属性 + `url()` / `code()` / `header(name)` …），规则靠它读 `Location` | M24 |
| `java.head(url)` | 响应对象 | 同上，动词是 `HEAD`（`HttpClient.head`），正文为空 | M24 |
| `java.getCookie(url[, key])` | `String?` | 读 Cookie 宗；带 `key` 时给该 cookie 的值（没有则 `null`），不带时给整条 `Cookie` 头（没有则 `''`） | M24 |
| `cookie.getCookie(url[, key])` / `cookie.setCookie(url, value)` / `cookie.removeCookie(url[, key])` | `String?` / `void` / `void` | 与 `java.getCookie` 同一通道的上游另一种拼写；`setCookie` 可传一对也可传整条 `a=1; b=2`（逐对落宗）。**`removeCookie` 上游只绑了一个参数**（`CookieStore.kt:79`：删「这个 URL 会发的整份 Cookie」，真实源写 `cookie.removeCookie(source.getKey())`）；本仓额外接受第二个参数表示按名删除（「空值 + `Max-Age=0`」），两种都可用 | M24 / M27 |
| `java.setContent(html)` | `void` | 把本 job 的页级 scope 换成这份 HTML：随后的 `java.getString*` / `parse.*` 读新页面（`result` 绑定不变） | M24 |
| `java.toast(msg)` / `java.longToast(msg)` | `void` | 转发到装配根绑定的 `UserMessages`（snack bar），同一 job 内同句只贴一次，同时记 info 日志 | M24 |
| `source.getVariable()` / `setVariable(v)` / `putVariable(v)` | `String` / `void` | **整份变量**，无参（上游 `BaseSource.kt:283-295`）：源拿它当自己的小仓库（语料里 54 处读、41 处写，`setVariable(JSON.stringify(...))` + `getVariable()` 是主流写法）。存在 `source_variables` 的**无名条目**里（与 `put`/`get` 同一张表），写 `null` / 不传即删除；与 `java.get` / `put` 的规则变量**不是**同一张表。**M25/S5a 改正**：S3b 曾做成 `getVariable(key)` 的键值形状（语料命中 0） | M24 / M25/S5a |
| `source.put(k, v)` / `source.get(k)` | `String` / `String` | **按名键值**（上游 `v_<url>_<name>`）：`put` 把值原样答回去（真实源拿返回值拼 URL），`get` 未写过答空串 | M25/S5a |
| `source.getKey()` / `source.getTag()` | `String` | 源身份：`getKey()` = `bookSourceUrl`（= `source.url`），`getTag()` = `bookSourceName`（= `source.name`）；纯读取，不过通道 | M25/S3b |
| `source.getLoginHeader()` | `String?` | 登录头 JSON（上游存在 `CacheManager` 的 `loginHeader_<url>`）；本仓存 `book_sources.login_header` 列，随 job 下传。**没有值时是 `null`**（`getVariable` 才是空串） | M25/S3b |
| `source.getLoginHeaderMap()` | 对象 \| `null` | 登录头的 map 形态（上游 `GSON.fromJsonObject`）：**Java `Map` 的读法都可用**（`get` / `put` / `remove` / `containsKey` / `size` / `isEmpty`，方法不可枚举，`JSON.stringify` 只看数据），没有登录头或值不是 JSON 对象时答 `null` | M25/S5a |
| `source.removeLoginHeader()` | `void` | **登出**：删登录头，并清掉这个源 URL 会发的 Cookie（上游 `CookieStore.removeCookie(getKey())`）。规则自己能清、不需要 UI | M25/S5a |
| `source.getLoginInfoMap()` / `getLoginInfo()` | 对象 / `String` | 登录表单收集的值（ADR-0072 §决策 3）的**快照**：`Map` 的读法同 `getLoginHeaderMap()`；没有值时答空表（`getLoginInfo()` 答 `"{}"`）。只有登录自己的 job 里读得到（`roadmap.md` §3.7 的登记差异） | M22-a |
| `source.putLoginInfo(json)` / `removeLoginInfo()` | `bool` / `void` | **写登录信息**（M25/S5a）：只收 JSON 文本，收下就 `true`；解析不出对象时答 `false`（上游照样存，读时退回空表）。写入随 job 结束写穿 `book_sources.login_info`（按 URL），同一 job 内 `getLoginInfoMap()` 立刻读到新值 | M25/S5a |
| `source.putLoginHeader(header)` | `void` | 写入登录头并**立即写穿**：同一 job 内读回新值，job 结束后下一个阶段的请求自动带上它（§2 的请求头合并），其中的 `Cookie` 同时并进 Cookie 宗 | M25/S3b |
| `src` | `String?` | **当前页正文**（上游 `AnalyzeRule.evalJS` 绑的 `content`）：整页规则与元素级规则读到同一份；没有页面的 job（URL 规则、`header` 规则）是 `null` | M25/S3b |
| `chapter` | 对象 \| `null` | 正在读的这一章：`title` / `url` / `isVip` / `isPay` / `isVolume` / `updateTime` + `getVariable(k)` / `putVariable(k,v)`（与 `book` 一样落**规则变量表**，差异见下）。搜索 / 详情 / 目录阶段是 `null`；`tocRule.formatJs` 的循环里逐章重绑 | M25/S3b |
| `nextChapterUrl` | `String?` | 目录里这一章**后面**那条地址；阅读器还没加载目录时是 `null` | M25/S3b |
| `fromBookInfo` | `bool` | 这一串规则是不是从**详情阶段**跑起来的（上游 `isFromBookInfo`）；别处恒为 `false` | M25/S3b |
| `infoMap` | 可变对象 | 每源**一张小表**（上游 `InfoMap`，缓存键 `infoMap_<url>`）：直接写属性即可，`save()` / `saveNow()` / `get()` / `set(v)` 都在，值在本会话内跨规则可见。差异：**不落盘**（与 `cache.*` 同一裁决） | M25/S3b |
| `java.connect(url[, header])` | 响应对象 | 与 `ajax` 同一条同步通道，但**答响应对象**，且**失败也是答案**（上游 `runCatching` 后把错误正文塞进响应）。差异：失败正文是可读的 kind 名（`connect failed (…)`），不是 Java 堆栈 | M25/S3b |
| `java.ajaxAll(urlList[, skipRateLimit])` | 响应对象数组 | 并发取多页，**任一页失败整次调用抛错**（上游 `mapAsync` 不吞异常）。差异：`skipRateLimit` 收下但**不绕过**单源预算（§8） | M25/S3b |
| `java.openUrl(url[, mimeType])` | `void` | 单向事件：宿主弹**确认弹窗**，用户同意后才交给系统浏览器。地址超过 64 K 字符即拒绝（上游同一道门） | M25/S3b |
| `java.startBrowser(url, title[, html])` | `void` | 打开**可见 WebView**让用户过人机验证；不等结果（ADR-0068 §决策 5） | M21a |
| `java.startBrowserAwait(url, title[, refetchAfterSuccess[, html]])` | `Promise<{url, body}>` | 同上但等用户按「完成」，成功后按需用新 cookie 重取；**本仓返回 Promise，规则里要 `await`**（上游是同步，差异见注记）。同一个 `op+url` 在一个 job 里只问一次：重放的那一趟直接拿到上次的答案（ADR-0076 §决策 4） | M21a / M24 |
| `java.getVerificationCode(imageUrl)` | `Promise<String>` | 图片验证码对话框，返回用户输入的字符串；**需 `await`**。答案同样按 `op+url` 记忆，重放不重复弹窗 | M21a / M24 |
| `java.webView(url[, js])` / `webViewGetString(url[, js])` | `Promise<String>` | 隐藏 WebView 渲染（可执行 `js`），结果是 body | M21a |
| `java.queryTTF(data)` | 句柄对象 | 字体反解（见下方注记）：`data` 认 **base64**（含 `data:…;base64,` 前缀与换行）与 **url**；url 走字节门并返回 Promise，规则要 `await` | M21a |
| `java.queryBase64TTF(data)` | 句柄对象 | 同上的 base64 专用形态（上游已弃用，真实语料仍在用） | M21a |
| `java.replaceFont(text, errorFont, correctFont[, start, end])` | `String` | 把混淆字换回真字；`start`/`end` 限定码位区间，第 4 参是布尔时按「缓存开关」忽略 | M21a |
| `java.timeFormat(timestamp)` | `String` | `yyyy/MM/dd HH:mm` | M1 |
| `key` | `String` | 搜索关键词，**只在 URL 规则的 JS 里**存在（ADR-0034 §决策 3） | M1 |
| `log.debug/info/warn/error(msg)` | `void` | 转发到 `core/logging`，自动附加 `rulePath` | M0 |
| `crypto.md5/sha1/base64Encode/base64Decode` | `String` | 纯计算 | M0 |

**`loginCheckJs`（响应拦截器，M21a）：** 源声明了非空的 `loginCheckJs` 时，**每一次取页成功后**
都会在页面 scope 上运行它，`rulePath = loginCheckJs`，`result` 就是上表的响应对象。返回值语义
（上游 `res = analyzeUrl.evalJS(checkJs, res) as StrResponse`，ADR-0068 2026-10-24 增补）：

| 返回值 | 本仓行为 |
|---|---|
| `null` / `undefined`（含只做判断不返回的写法） | 沿用本次响应 |
| 带 `body` 字符串的对象（沙箱响应对象本身，或 `java.startBrowserAwait(...)` 的 `{url, body}`） | 用它的 `body`（和 `url`）重建页面，后续规则读新页面 |
| 裸字符串 | 只替换正文（宽容方言；上游会报「did not return StrResponse」） |
| 其余（布尔 / 数字 / 数组 …） | 源声明了 `loginUrl` / `loginUi` → `loginRequired`（UI 显示「去登录」）；否则 `parseFailed` |
| 脚本抛错 / 超时 / 用户取消验证 | 原样上抛（`js:error` / `js:timeout` / `cancelled` / `unsupportedRule`） |

三条登记差异：① 只对 **2xx** 响应运行（非 2xx 在请求层已是失败）；② `result.body()`（方法形态）
不支持——上游是 `body` 属性，命中会显式报 `result.body is not a function`；③
`java.getStrResponse()` / `java.initUrl()` / `java.getHeaderMap()`（只在登录检查 JS 里有效的
`AnalyzeUrl` 方法）仍具名拒绝。

**字体反解（M21a，ADR-0068 §决策 9）：** 站点把正文写成私有区码位（如 ``），再用一套
`cmap` 被重映射的字体把它们画成真字。三个 `java.*` 成员按上表使用，典型写法：

```js
var errorFont = java.queryBase64TTF(String(result).match(/ttf;base64,([^)]+)/)[1]);
var correctFont = await java.queryTTF('https://a.test/font.woff2.ttf');   // url 要 await
java.replaceFont(result, errorFont, correctFont);
```

四条必须知道的事：

1. **字体对象是不透明句柄**（`{__ttf: true, id}`）：字体不进脚本，所以不要索引它；查询来的东西
   原样交回 `replaceFont` 即可。句柄随 job 失效（脚本存在 `globalThis` 里跨 job 用会拿到
   `java.replaceFont failed`，而不是别人的字体）。
2. **先按字形名对，再按字形 id 兜底。** 子集化会把字形 id 重排，但 `post` 表里的 `uniXXXX`
   名字还在——上游也是这么做的。`post` 索引 < 258 的标准 Macintosh 名本仓不内置（CJK 混淆字体
   用的都是自定义名），这些字形退回按 id 对。
3. **`queryTTF(url)` 返回 Promise**：网络一律异步（§6 的总规矩）。`queryBase64TTF` 与
   `replaceFont` 同步返回。
4. **`java.getFontGlyph` 不存在**：ADR-0068 早期登记里提到过它，但上游 master 的
   `JsExtensions.kt` 没有这个成员（只有 `queryTTF` / `queryBase64TTF` / `replaceFont`），
   所以本仓也不提供。

**`java.*` 兼容面（ADR-0037；本节是它的唯一出处）：**

| `java.*` 成员 | 形态与语义 | 状态 |
|---|---|---|
| `put(key, value)` / `get(key)` | 规则变量，与 `@put:` / `@get:` 同一份（ADR-0034） | ✅ 已落地 |
| `timeFormat(ms)` | `yyyy/MM/dd HH:mm`、本地时区、worker 内同步（不限额） | ✅ 已落地（M1-b1） |
| `md5Encode(str)` | = 本表的 `crypto.md5`（UTF-8 字节的十六进制 MD5；上游 `MD5Utils.kt:13-15`） | ✅ 已落地（M1-b1b） |
| `md5Encode16(str)` | 32 位 MD5 的第 9..24 位字符（上游 `MD5Utils.md5Encode16`） | ✅ M25/S3a |
| `base64DecodeToByteArray(str[, flags])` / `hexDecodeToByteArray(hex)` | 答 `byte[]`（沙箱里是 `Uint8Array`）；base64 按上游 hutool 的宽容规则解（空白、`-_`、缺填充都收），空白输入答 `null`；hex 必须偶数位且只含 `0-9a-fA-F` | ✅ M25/S3a |
| `hexEncodeToString(str)` / `hexDecodeToString(hex)` | UTF-8 字节与十六进制互转（小写出口） | ✅ M25/S3a |
| `strToBytes(str[, charset])` / `bytesToStr(bytes[, charset])` | 字符串与字节数组按声明字符集互转：未知标签与坏字节都退 UTF-8（坏序列换 U+FFFD），不抛错 | ✅ M25/S3a |
| `digestHex(data, algorithm)` / `digestBase64Str(data, algorithm)` | 摘要，算法认 `MD5` / `SHA-1` / `SHA-224` / `SHA-256` / `SHA-384` / `SHA-512`（`-` 可省、大小写不敏感），出口 hex 或 `NO_WRAP` base64 | ✅ M25/S3a |
| `HMacHex(data, algorithm, key)` / `HMacBase64(data, algorithm, key)` | HMAC，算法名照抄 Java 拼写（`HmacSHA256` / `HMAC-SHA1` / `HmacMD5`），`key` 取 UTF-8 字节 | ✅ M25/S3a |
| `createSymmetricCrypto(transformation[, key[, iv]])` | 不透明句柄（`{__symmetric: true, id}`），九个方法：`encrypt` / `encryptBase64` / `encryptHex` / `encryptStr` / `decrypt` / `decryptStr` / `decryptHex` / `decryptBase64` / `setIv` | ✅ M25/S3a |
| `aes*` / `des*` / `tripleDES*`（上游 `@Deprecated` 一族） | 按「组一个密码器 + 调一个方法」实现，参数顺序逐个照抄上游（含 `*ArgsBase64Str` 那组的 key/iv 不对称） | ✅ M25/S3a |
| `randomUUID()` | 标准 v4 UUID（8-4-4-4-12），`Random.secure()` | ✅ M25/S3b |
| `timeFormatUTC(time, format, sh)` | 固定 `sh` 小时偏移的 `SimpleDateFormat`：`y`/`M`/`d`/`H`/`h`/`m`/`s`/`S` + `'…'` 字面量；未知字母原样输出 | ✅ M25/S3b |
| `toNumChapter(str)` | 把 `第…章` 里的中文数字换成阿拉伯数字（`第一百二十三章` → `第123章`），认不出就原样返回 | ✅ M25/S3b |
| `toURL(url[, baseUrl])` | `{host, origin, pathname, searchParams}`；`searchParams` 按 `URLDecoder` 语义解码（`+` → 空格） | ✅ M25/S3b |
| `htmlFormat(str)` | 上游 `HtmlFormatter.formatKeepImg`：标签 → 段落、只留 `<img src>`（含 `,{…}` 选项）、统一段首缩进 | ✅ M25/S3b |
| `t2s(str)` / `s2t(str)` | 繁简互转，最长匹配；码表见下方注记 | ✅ M25/S3b |
| `getWebViewUA()` | 随 job 下发的 UA 常量（与请求默认 UA 同一出处） | ✅ M25/S3b |
| `androidId()` | 本仓自己生成并持久化的安装 id（v4 UUID，`main()` 在第一帧之前 hydrate）；宿主没 hydrate 时答空串（**不是** Android ID，见注记） | ✅ M25/S3b |
| `cache.put/get/getInt/getLong/getDouble/putMemory/getFromMemory/delete/deleteMemory` | **内存 LRU**（容量 + 单值长度上限，随 worker 存亡）；上游是「内存 + 持久表」两层 | ✅ M25/S3b（差异见注记） |
| `base64Encode(str)` / `base64Decode(str)` | = `crypto.base64Encode` / `crypto.base64Decode`；前者对齐上游 flags = 2（`Base64.NO_WRAP`），非法输入抛错 | ✅ 已落地（M1-b1b） |
| `encodeURI(str)` | **Java `URLEncoder.encode(str, "UTF-8")`**：空格 → `+`，保留 `A-Za-z0-9` 与 `-_.*`，其余 UTF-8 字节 `%XX` 大写——**不是** JS 的 `encodeURI`（上游 `JsExtensions.kt:683-689`） | ✅ 已落地（M1-b1b） |
| `encodeURI(str, charset)` | 同上，但按**声明的字符集**取字节（真实语料：`java.encodeURI(key, "GBK")`，ADR-0069 G1）；未知标签退 UTF-8（上游抛错返回 `""`） | ✅ M21a（ADR-0069） |
| `log(msg)` | = `log.info(msg)`（自动附 `rulePath`；上游 `JsExtensions.kt:1128-1132`） | ✅ 已落地（M1-b1b） |
| `getString(rule)` / `getStringList(rule)` / `getElement(rule)` / `getElements(rule)` | **对当前 scope 求值**，两种形态：① 首参是字符串字面量、且内层规则不带 `@js:` / `{{` / `@put:` / `@get:` / `<js>` 时，由**引擎在脚本执行前内联**（同步语义，覆盖语料 377/379 个字面量嵌套调用）；② 其余走宿主调用，形态是 **Promise**（等价 `parse.getString(rule, 当前 scope)` 等）——在表达式内当字符串用会显式 `js:error`，不会静默给错值。**`getStringList` 求的是值**（含提取段，`@css:.box img@src` 回 URL 列表、元素串化），`getElements` 才给元素文档（`outerHtml` / JSON 值），见 ADR-0069 G14 | ✅ 已落地（M1-b1b；语义细化 M21a） |
| `getString(rule, false)` | 接受（`false` = 不 unescape，正是本仓行为）；`(rule, true)` 与三参形态**具名拒绝** | ✅ 已落地（M1-b1b） |
| 列表返回值 | JS `Array`；沙箱另装 `Array.prototype.toArray()`（返回 `this`），配上游 Java `List.toArray()` 习惯用法（语料 38 处） | ✅ 已落地（M1-b1b） |
| 多参重载（`base64Encode(str, flags)` / `base64Decode(str, charset)` / `encodeURI` 两参 …） | 具名拒绝：本仓没有 flags / charset 语义，猜一个只会静默给不同结果 | 拒绝 |
| `ajax(url[, headers])` / `post(url, body, headers)` / `head(url)` / `getCookie(url[, key])` / `setContent(html)` / `toast(msg)` / `longToast(msg)` | 同步族与提示族；语义见上方绑定表与「同步族」注记 | ✅ M24（ADR-0076） |
| 其余成员 | 见 §11 的具名拒绝清单（抛错存根，Rhino 互操作类用抛错 Proxy） | M2 |

**同步族（M24，ADR-0076 §决策 1）：** 上游的 Rhino 可以阻塞线程直到页面回来，所以 `java.ajax` 是**同步**的；
本仓的 QuickJS 在独立 isolate 里，宿主的回答只能是 Future，因此用「**取页缓存 + 从头重跑**」仿真：

1. 脚本命中一个本 job 还没取过的同步调用 → worker 抛哨兵，记下 `{op, url, body, key}`；
2. 桥取一次页（或读一次 Cookie 宗），答案连同失败一起记进缓存，然后脚本**从第一行重跑**；
3. 重跑时同一个调用同步拿到缓存里的值（失败则抛错，规则自己的 `try` / `catch` 照常工作）。

规则作者必须知道四件事：

- **整条规则会重跑 n 次**（n = 不同同步调用的个数）。`java.put` / `source.setVariable` 这类写入每趟重做，
  幂等；**非幂等副作用（外部计数、发消息）会被重复执行**，这是这条路线明写的代价。
- **pass 上限 16**：不同同步调用（含 `java.post` / `java.head` / Cookie 三个动词）超过 16 个时该字段失败，
  `rulePath` 带 `js:replay`——意思是「这条规则重放不了」，不是超时。
- **取页的时间不算脚本预算**：同步取页期间硬预算暂停、等掉的时间从 `elapsedMs` 扣掉，且每趟重跑
  重新拥有一次调用额度（额度的单位是「一趟」，不是「一个 job」）。
- **验证类只问一次**：`getVerificationCode` / `startBrowserAwait` / `startBrowser` 按 `op+url` 记答案，
  重放的那趟直接答上次的结果，不会再弹一次窗（它们的形态仍是 Promise，规则要 `await`）。

> **`java.setContent` 的边界：** 它只换**同一 job 内后续** `java.getString*` / `parse.*` 读的页级 scope；
> `result` 绑定与已经算出的值不变，也不影响 job 之外的阶段。首参是字符串字面量的 `java.getString`
> 会被引擎在 job 之前内联（见上表），因此那一路看不到 `setContent`。

> **规则求值族的时机（登记差异）：** ①在脚本执行前求值，②在脚本执行到那一行时求值。首参是字面量时
> 走①，所以那一路读不到 `java.setContent` 换掉的页面（§6「`java.setContent` 的边界」）；两条路径**共用
> 同一实现点**，同一 (规则, scope) 的结果必然一致。URL 规则里**没有**页面 scope，该族命中即按
> `js:parse-scope` 同族拒绝。

**书源自带的库脚本（`jsLib`，M25/S1，ADR-0078 §切片 S1）：** 上游把 `jsLib` 当**每个脚本的原型作用域**
（`SharedJsScope.kt:23-60`、`AnalyzeRule.kt:848`），所以源可以只写 `getSign(url)` 这样的调用。本仓的做法：

1. 引擎在造 job **之前**把 `jsLib` 解析成可运行的 JS（`JsLibStore`）：纯 JS 原样用；**JSON 对象**形态只取
   `http(s)://` 开头的值逐条下载，按对象序拼接（非 URL 值忽略，与上游的 `isAbsUrl()` 判定一致）。
2. worker 把这份文本与规则**放在同一个函数作用域里**跑（先 `eval(lib)`，再 `eval(rule)`），因此库里的
   `var` / `function` 对规则可见，而两者都不会漏到 `globalThis`（上游用 `preventExtensions` 达到同一效果）。
3. 解析失败（下载不通）就是**这条规则**的失败，`rulePath` 带 `js:lib`；库自身抛错同样是 `js:lib`，
   与规则自己的 `js:error` 分开，便于判断「换库」还是「改规则」。
4. 缓存按 `jsLib` 原文、上限 16 条（与上游 `LruCache` 同数），失败不缓存；同一个源的一页里二十个
   `@js:` 字段只解析一次。

三条必须知道的差异：① 库顶层的 `let` / `const` 规则**看不见**（它们属于那次 `eval` 的词法环境，本仓用
`var` / `function` 才有跨 eval 的可见性；上游 Rhino 是 ES5，本来也不认 `let`）；② 缓存只在内存里，
重启后重新解析（上游把它落到磁盘 `ACache`）；③ `source.jsLib` **不在** `source` 绑定里（那个对象仍只有
`name` / `url` / `group`，防信息外泄），需要库内容的规则请直接依赖库函数。

**字节与密钥族（M25/S3a，ADR-0078 §切片 S3a）：** 上游这一族靠 Rhino 直接拿到 Java `byte[]` 与活的
`SymmetricCryptoAndroid` 对象，本仓用两个形状兑现：

1. **`byte[]` = JS `Uint8Array`。** 语料对它的用法是 `length` / `Array.from(bytes)` / `slice(8, -16)`
   （阅文系的解密链），三种都成立；它过隔离体边界时是一整块 typed array，不是「JSON 数字数组」。
   差异：把字节数组**直接当返回值**时，`JSON.stringify` 看到的是对象而不是数组，所以规则要落库/拼字符串
   时先转（`hexEncodeToString` / `bytesToStr` / `encryptBase64`）。
2. **`SymmetricCrypto` = 不透明句柄**（`{__symmetric: true, id}`）：密码器本体留在宿主，每次方法调用只走
   一个小信封。句柄**随 job 失效**（与字体句柄同一套契约，`_fonts` / `_ciphers` 都在 job 开始时清空），
   脚本把句柄存进 `globalThis` 跨 job 用会拿到 `unknown symmetric crypto handle`，而不是别人的密码器。

**transformation 与密钥的规范化照抄上游 `SymmetricCryptoAndroid`：**

- 不带 `/` 的写法按 `/<算法>/ECB/PKCS5Padding` 补全（所以 `AES` = `AES/ECB/PKCS5Padding`）。
- 密钥可以是字符串（取 UTF-8 字节）或字节数组；DES 超过 8 字节截前 8，DESede 超过 24 字节截前 24；
  `key` 缺省时用随机密钥（`KeyGenerator` 语义：规则只能在同一段脚本里加密再解密）。
- **支持面：AES / DES / DESede × ECB / CBC × PKCS5Padding / PKCS7Padding / NoPadding。**
  CFB / OFB / CTR / GCM、非对称（`createAsymmetricCrypto`）与签名（`createSign`）**不在支持面**内，
  命中即抛可读错误（触发条件：真实语料出现且能给出复现源，见 §11）。
- 单 DES 由 `DESede(K1=K2=K3)` 兑现（pointycastle 只带三倍引擎），与 Java 单 DES **逐字节相同**；
  `NoPadding` 要求字节数正好是块大小的非零整数倍（Java 抛 `IllegalBlockSizeException`，本仓同样失败，
  不悄悄补零）。
- `decrypt(String)` 自己猜编码：全 hex 且偶数位按 hex，否则按 base64（上游 `SymmetricCryptoAndroid.kt:80-90`）；
  `decryptHex` / `decryptBase64` 则强制那一种。

三条**有意差异**：① `aesEncodeToString` 上游实现是 `decryptStr`（历史 bug），本仓按名字的意图**加密**——
依赖这个 bug 的源本来也解不出正文；② `base64DecodeToByteArray(str, flags)` 接受 `flags` 但**不按位分支**
（上游两个重载最终都走 hutool 的宽容解码器，行为一致）；③ 上游的 `strToBytes/bytesToStr` 没有
`@JavascriptInterface` 注解、只靠 Rhino 的公开方法可见性拿到，本仓照样绑定，但只做「未知标签退 UTF-8」
这一档容错。

> 这些调用**纯计算**，在 worker 的同一 isolate 内完成：不联网、不进 `http.*` / `parse.*` 的调用额度，
> 也不受单源并发/限速影响。

**纯计算与工具族（M25/S3b，ADR-0078 §切片 S3b）：** 这一族的共同点是**在 worker 内同步完成**，
不联网、不进 `http.*` / `parse.*` 的调用额度。四条必须知道的差异：

1. **`t2s` / `s2t` 的码表不是上游那一份。** 上游走 `quick-chinese-transfer`，它的 pom 没有
   `<licenses>`、仓库也没有 LICENSE 文件，按 C-DEP-7 不能搬；本仓用 **OpenCC（Apache-2.0）** 的
   `TSCharacters/TSPhrases`（繁→简）与 `STCharacters/STPhrases`（简→繁）生成 `assets/zh/*.txt`
   （来源、生成规则与哈希见 `assets/zh/README.md`）。所以上游 `fixT2sDict()` 里那份「不该转换」的
   港台词表（`雪梨` / `鳳梨` / `魔戒` …）本仓没有，这类词按 OpenCC 的默认结果走。码表随 worker 的
   bootstrap 进来、**首次用到才解析**（简→繁表 842 KB）。
2. **`cache.*` 只在内存里**（容量 256 条、单值 64 K 字符、`saveTime` 以秒计的 TTL 照上游语义）。
   上游的 `Cache` 是持久表，重启后还能读到 token；本仓重启即丢。这是有意差异（M25/S3b 裁决），
   触发条件是「有源依赖跨会话缓存且能复现」。
3. **`toURL().origin` 按意图实现**：上游那一行把整个 URL 又插进了 `host:` 与端口之间
   （`"${protocol}://$host:${mUrl}:${mUrl.port}"`，`JsURL.kt:22-25`），带端口的源会拿到
   `https://a.test:https://a.test/p:8443` 这种值。本仓答 `scheme://host[:port]`。
4. **`androidId()` 不是 Android ID**：上游取 `Settings.Secure.ANDROID_ID`；本仓没有这个标识，改在首次
   启动时生成一个 **v4 UUID** 存进轻量开关（`InstallId`），重启不变、卸载才换。宿主没 hydrate 过时答
   空串而不是 `undefined`。差异：格式不是 16 位十六进制，**依赖 Android 格式做解析的规则不适用**；
   只要「一个稳定 id」的规则照常工作。

**登录头（M25/S3b，上游 `BaseSource.getLoginHeader` / `putLoginHeader`）：** 登录脚本换来的 token 写在
这里，之后**每个阶段的请求都自动带上**：`headersOf` 把它合并**在源自己的 `header` 之上**（上游
`getHeaderMap(userAgent, hasLoginHeader = true)` 的同一顺序），`@js:` 规则的 `http.*` 也走同一份
map。四条要知道的：

1. **键是源 URL**，不是行：上游的缓存键是 `loginHeader_<bookSourceUrl>`，本仓也按 URL 读写，因此两条
   同 URL 的导入共享同一个登录头。
2. **`Cookie` 会被并进 Cookie 宗**（上游 `CookieStore.replaceCookie`）：真正发 `Cookie` 的是宗，
   只存头不并宗的话下一次请求会被宗里的旧 Cookie 盖掉。
3. **值的形状是「JSON 对象文本」**，本仓照上游不校验：解析不出来时只记 warning 并跳过合并
   （坏值不该让请求失败），但 `putLoginHeader` 只收字符串。
4. **一条与上游不同的地方**：规则内调用 `source.login()` **具名拒绝**——登录脚本由登录页跑
   （`SignIn`，同一段 `loginUrl` 脚本），规则里重入 worker 会死锁。`source.removeLoginHeader()` **M25/S5a
   起已绑定**：删登录头 + 清这个源 URL 会发的 Cookie（上游 `CookieStore.removeCookie(getKey())`），
   所以语料里那些 `clearLogin()` / `gx()` 按钮写法能跑。

**阶段上下文绑定（M25/S3b，`src` / `chapter` / `nextChapterUrl` / `fromBookInfo` / `infoMap`）：**
这五条都是**阶段事实**，由造 job 的那一层填，规则只读。四条要知道的：

1. **`chapter` 的变量是规则变量。** 上游把 `chapter.putVariable` 写进章自己的 map；本仓与 `book` 同口径
   落规则变量表（`java.get` / `java.put` 的同一张），差异与 `book` 的那条一起登记。
2. **`infoMap` 只在会话里。** 上游的值落在 `CacheManager`（`infoMap_<url>`，可选 `saveTime`），重启后还在；
   本仓按 `cache.*` 的同一裁决只做内存（容量按源 LRU 32 个），`save()` / `saveNow()` 保留为空操作，
   免得规则报 `not a function`。触发条件：出现「探索 token 要跨启动保留」的真实源。
3. **`speakText` / `speakSpeed` 不绑定。** 它们只由上游的 **HttpTTS 源**提供（另一张源表 + 自己的一套
   朗读规则），本仓只有系统 TTS，没有那条链路 → 规则里读它们会得到 `ReferenceError` 而不是一个恒为空的
   值（有意差异，触发 = 引入 HttpTTS 朗读引擎）。
4. **`src` 是 job 开始时的正文。** `java.setContent(html)` 之后同一个 job 里的 `src` 不变（它已经是
   快照），下一页/下一条规则才看到新正文——上游每次 `evalJS` 重新绑 `content`，效果相同。

**`source` 对象（M25/S5a）：** 上游把**整个源实体**绑成 `source`（`BaseSource.evalJS` 的
`bindings["source"] = this`），所以任何公开字段都读得到。本仓不那样做（会把 `payload` / 行 id / 宿主
字段一起漏出去），改成**白名单字段**（表里那一行）+ 方法面。五条要知道的：

1. **字段是白名单，不是实体。** `key`（= `bookSourceUrl`）、`bookSourceUrl`、`bookSourceName`、
   `bookSourceComment`、`header`、`loginUrl`；本仓自己的 `name` / `url` / `group` 保留（同一批值的旧名）。
   `jsLib` **仍不外泄**（库脚本要读自己的文本就是循环依赖）。
2. **`header` 的两种形态不同源**：规则形态（`@js:` / `<js>`）是**声明原文**——真实源靠前缀判断要不要
   自己求值；JSON 形态是**解析后的表重新序列化**，所以空白与键序不是作者写的那份（唯一的相关差异，
   `JSON.parse(source.header)` 与字符串前缀判断都照常成立）。
3. **`bookSourceComment` 不单独建模**（留在 `extra`，§2 的未建模清单）：五个源拿它当脚本库
   （`eval(String(source.bookSourceComment))`），所以这里给的就是声明的原文，读不到才答 `null`。
4. **两套变量不是一回事**：`put(k, v)` / `get(k)` 是**按名键值**（上游 `v_<url>_<name>`），
   `getVariable()` / `setVariable(v)` / `putVariable(v)` 是**整份字符串**（上游 `sourceVariable_<url>`）。
   本仓两者共用 `source_variables` 表——整份变量落在**无名条目**里，好处是只有一套写穿路径。
   `put` 答回写入的值（真实源拿返回值拼 URL），`get` 未写过答空串。
5. **登录信息（`login_info`）可写。** `putLoginInfo(json)` / `removeLoginInfo()` 在**同一个 job 内**立刻
   可见（读的也是同一份槽位），job 结束时由桥写穿 `book_sources.login_info`（按 URL，同登录头）。
   只收字符串：解析不出对象就答 `false`，不把读不回来的文本写进库（上游会存）。

**`Packages.*` 最小垫片（M25/S5d，ADR-0081）：** 上游把 Rhino 的 Java 包入口原样交给脚本，语料里有一批
「一行就能等价实现」的写法。本仓按**白名单**兑现它们，白名单外的成员仍然具名拒绝（错误里带完整包路径）。
术语与边界：

1. **只做数据/编码/集合，不做对象模型。** 白名单是：`java.lang.String`（`new String(bytes,'UTF-8')`
   解码、`String(x).getBytes('UTF-8')` 编码）、`java.lang.System.currentTimeMillis`、
   `java.lang.Thread.sleep`（**空操作**：沙箱里没有线程，也不会为一个 `sleep` 让出预算）、
   `java.util.UUID.randomUUID().toString()`、`java.util.Arrays`（`copyOfRange` / `copyOf` / `toString`）、
   `java.util.HashMap` / `LinkedHashMap`（`Map` 读法同 §6 的登录头 map）/ `java.util.ArrayList`
   （数组 + 不可枚举的 `add` / `size`）、`android.util.Base64`（`encodeToString` / `decode`，
   `NO_WRAP` 等常量照有）、`android.text.TextUtils.isEmpty`、hutool 的 `DigestUtil.md5` / `md5Hex` 与
   `cn.hutool.core.codec.Base64`（`encode` / `decode` / `decodeStr`）、
   `io.legado.app.help.http.StrResponse(url, body)`（与 `loginCheckJs` 的 `result` 同形，脚本把它
   `return` 出去就替换页面）。
2. **`javax.crypto` / `java.io` 流 / `java.net.URL` / `okhttp3` / `org.jsoup` / `JavaImporter` 不在白名单里。**
   它们要的是真实 Java 对象（密码器、流、HTTP 客户端、DOM），本仓的等价能力在 `java.*` 与 `crypto.*`
   上（`createSymmetricCrypto` / `java.ajax` / `parse.*`），因此维持具名拒绝：错误里给出**到第一个未知段**
   的路径（`Packages.javax`、`Packages.java.util.TreeMap`），`new JavaImporter(…)` 报
   `JavaImporter is not supported`。
3. **`java` 不是包。** 上游 `java` 绑定是 `JsExtensions` 实例，`java.lang.*` 在上游也不存在；本仓同样只在
   `Packages.*` 下提供白名单，`java.lang` / `java.util` … 这 8 个名字仍是抛错 Proxy（§11 的名单）。

**禁止暴露：** 文件系统、进程、环境变量、Socket、定时器、原生绑定、
`eval` 之外任意代码加载、`source` 的完整实体（只给白名单字段，S5a）。

> **JS 侧形态（本表是唯一出处；ADR-0029 §决策 3，2026-10-11 生效）：** 本表「形态」列描述的是**值类型**；
> 调用能否同步取值另有一层，判定标准是「该绑定是否需要在别处执行」：
>
> - **立即返回值（同步）**：`java.put` / `java.get` / `source.getVariable` / `setVariable` / `putVariable` /
>   `put` / `get` / `getKey` / `getTag` / `getLoginHeader` / `putLoginHeader` / `getLoginHeaderMap` /
>   `removeLoginHeader` / `getLoginInfo` / `getLoginInfoMap` / `putLoginInfo` / `removeLoginInfo`、`log.*`、
>   `crypto.*`、`java.timeFormat`，以及**重放层**里的 `java.ajax` / `java.post` / `java.head` / `java.getCookie` /
>   `cookie.*`（ADR-0076 §决策 1：它们值上同步，背后是「未命中则抛哨兵 → 取页 → 从头重跑」）。
>   前提是它们要么只在运行时所在 isolate 内完成（变量存 Dart 侧、按 `sourceId` 键控，见 ADR-0030 §决策 4），
>   要么由重放层兑现「值上同步」；
> - **返回 Promise（规则**必须** `await`）**：`http.get` / `http.post`（唯一实现是 `core/network/HttpClient`，
>   C-NET-1）、`parse.getString` / `parse.getElements`（引擎与 scope 不在该 isolate）、验证族与 `java.webView*`。
>   仅凭 3.7 真实语料证据 + 新 ADR 才可追加（ADR-0029 §决策 4）；重放层就是那条新 ADR。
>
> **`parse.*` 的 scope 边界（ADR-0029 §决策 5）：** 3.3 只承诺**页级 scope**（worker 侧用页面 body 重建）；
> 元素级 scope 命中时报 `unsupportedRule` / `parseFailed`，`rulePath` 用 `js:parse-scope`。
>
> **排队、超时与隔离（ADR-0030，本表不复述数值）：** 单常驻 worker、单复用运行时、FIFO 串行；
> 并发预算归请求层；跨书源共用 `globalThis` 属**已登记偏离**；触发条件与重开路径见 ADR-0030 §决策 5。

**配额（必须实现）：**

| 项 | 默认值 |
|---|---|
| 单次 JS 墙钟超时 | 5 秒 |
| 单次 JS 内存上限 | 32 MB |
| 单条规则内 JS 调用次数 | ≤ 20 |
| 单条 `log.*` 消息的字符上限 | 2 000（超出截断并附截断标记） |

超时或异常 → `ParseFailure(parseFailed)`，`rulePath` 中标注 `js:timeout` 或 `js:error`。

> - **值规则上的终段 `@js:` 已可用（2026-10-12，3.4 part 2）。** `@js:` 贪婪吞掉本条规则剩余
>   部分（上游 `AppPattern.JS_PATTERN` 的 `@js:([\w\W]*)`），所以 JS 里的 `&&` / `||` 不会被读成
>   连接符；`result` 的形态按上游：`getString` 语义（单值字段）给**字符串**，`getStringList`
>   语义（多值字段，如 `nextTocUrl`）给**列表**，列表返回值也保持列表（§4.1 的 URL 数组靠它）；
>   `##` 替换在脚本**之后**应用（上游同一 `SourceRule` 的 `replaceRegex` 也是最后跑）。
> - **列表规则的 JS 边界（M12 落定）：** 整条规则就是 JS（裸 `@js:` 开头）或规则体内出现
>   `<js>…</js>` 时走**分段链**，脚本返回的数组逐项成为条目（上游 `getElements` 的 `Mode.Js`
>   分支，`AnalyzeRule.kt:439`）；**只有尾部 `@js:`**（`class.list@tag.li@js:result`）仍报
>   `unsupported:@js:list`——上游把这种形态当「选择器段 + JS 段」的链，本仓尚未打通，去向见
>   `docs/dev/engine-parity.md` S4。`exploreUrl` 整字段的 `<js>` 另见 §4.2。
> - **独立 `@js:` 的 `result`：** 整页 scope 给 responseBody；**元素 scope**（逐项字段，如
>   `searchRule.name`）给它自己的 `outerHtml`——沙箱里没有 DOM 句柄可交（ADR-0029 §决策 5），
>   但规则总得看见它所属的那一项；JSON 条目 scope 给该条目的 JSON 文本。
> - **单值字段的 `result` 是「全部匹配用换行拼接后的字符串」**（上游 `AnalyzeRule.getString`
>   → `joinToString("
")`，ADR-0069 G9）：所以 `result.split("
")` / `result.replace(...)`
>   这类写法成立。列表规则的 `result` 仍是列表（§4.1 的 URL 数组靠它）。
>
> **JS 绑定的操作面（2026-10-12，3.4 落地；上表是白名单，本段是每一项的行为）：**
>
> - **`http.get(url, options)` / `http.post(url, options)` 是 Promise**（ADR-0029 §决策 3），
>   唯一实现是 `core/network/HttpClient`（C-NET-1），因此超时 / 重试 / 编码 / 明文策略与页面
>   抓取完全同一套。请求带上书源自带的 `header`（C-NET-4，规则自己的同名键优先），并以**书源
>   URL** 作为并发预算键，所以它花的仍是 §8 那份预算。
> - **规则想 `await` 就必须把整段包成 `(async function () { … })()`。** 沙箱执行一条规则是
>   `__runRule(script)` → **同步** `eval(script)`（`core/js/quickjs_worker.dart`），顶层 `await`
>   在那里是**语法错误**（`await is only valid in async functions`，错误落在该字段、耗时 0–1 ms，
>   一个请求都不会发）。`http.*` / `parse.*` / `java.startBrowserAwait` / `java.getVerificationCode`
>   都要这个包装才用得了。
> - **`<js>…</js>` 的链式求值（矩阵 #31）：** 脚本段之后的段读到的是**脚本的产出**——
>   选择器段在「脚本返回的那份 HTML」上跑（值规则与列表规则同口径，与上游
>   `AnalyzeRule.getString` 把上一段的值当新 `content` 一致）；字符串长得不像标记时仍留在原
>   页面上，所以 `<js>java.put(…)</js>https://…/{{result}}.html` 这类拼接不受影响。这是
>   「先过盾取回真实页面、再读正文」的写法能工作的前提。
> - **`options` 只认 `headers`、`response` 与（POST 的）`body`**，其余键（如 `charset` / `timeout` / `retry` /
>   `webView`）让**该次调用抛错**：策略由 `HttpPolicy` 拥有，而 `webView` 本仓没有，悄悄忽略
>   它会把「未渲染的页面」当成答案（§1 的不兼容清单）。
> - **`options.response: true` 返回响应对象**（`body` 属性 + `url()` / `code()` / `headers()` /
>   `header(name)` / `cookie()` / `contentType()` / `isSuccessful()`），与 `loginCheckJs` 看到的
>   `result` **同一个形状**（ADR-0068 增补）。`url()` 是**跟随重定向之后**的地址，与页面
>   `baseUrl` 同源（`core/network/http_response.dart`）：站点用 `302` + 相对 `Location` 交接会话时
>   （ASP 搜索的 `?token`），规则只能从这里拿到真正该重发的地址，正文里没有它。
> - **传输失败只拒绝这次的 Promise**（message 是 `ParseFailureKind` 名，如 `networkTimeout`）：
>   规则可以自己 `catch` 后改走镜像；规则没 catch 时该 job 按 §7 报 `js:error`。
>   **已登记的取舍：** 可重试性（`isRetryable`）不随它上抛——脚本可能吞掉它，把「传输失败」
>   归给字段就是猜，唯一出处仍是 §7。
> - **`parse.getString(rule, doc)` / `parse.getElements(rule, doc)` 是 Promise**，由**规则引擎**
>   求值（ADR-0029 §决策 5 的页级 scope）：嵌套规则在宿主 isolate 上跑，worker 不需要重建 scope。
>   `getString` = 首个值（无匹配时 `''`，与上游 `getString` 同形）；`getElements` = 每个匹配
>   ——DOM 匹配给 `outerHtml`、JSON 匹配给值本身（**无 DOM 句柄**，所以上游「`getElements` 再
>   `parse.getString(rule, element)`」的写法会在 `doc` 这一步被拒，见下）。
> - **`parse.*` 的边界都报 `unsupportedRule` 且带字段路径：** `js:parse-scope` = `doc` 不是本 job
>   的页 body（元素 scope / JSON 条目 / 脚本自己拼的片段，只有页级 scope 被承诺）；
>   `js:parse-recursion` = 嵌套规则自己又要 `@js:`（单 worker 正在跑发起它的那个 job，
>   ADR-0030 §决策 1/3，嵌套 evaluate 只会排在自己的队后面）；而 `parse.getElements` 的嵌套
>   `@js:` 落在列表规则的柜口上，报 `unsupported:@js:list`（与顶层列表规则同口径）。三者都是
>   **整个 job 的失败**，不被脚本吞成空值。
> - **额度**（上表 20 次/规则）由**桥**按 job 计数，已含 `log.*`：数的是**跨出 worker 的调用**
>   （`log.*` / `http.*` / `parse.*`）；`crypto.*` 与 `java.*` 在 worker 内完成，不进这个计数。超限使该 job
>   失败，`rulePath` 标 `js:quota`，并且之后的调用只被拒绝（不再花钱）。
> - **`java.put(key, value)` / `java.get(key)` 与 `@put:` / `@get:` 是同一份变量表（ADR-0034，矩阵 #16/#17）：**
>   表在**宿主 isolate** 里按**书源 URL** 键控；每个 job 带一份该源的**快照**进 worker，`java.*` 在 worker 内
>   **同步**读写这份快照，job 结束时整份表随结果回到宿主、由桥 merge 回去——所以「表不在 worker 里」
>   与「`java.*` 是同步」同时成立。`java.put(key, null)` 是**清掉**该变量（不是写成空串）；
>   没写过的键 `java.get` 给空串（上游 `AnalyzeRule.get` 同形），`java.put` 不给返回值
>   （上游返回写入的值，属已登记差异）。变量的**生命周期**随 Provider 作用域、不落盘：
>   上游持久化在 book / source 上（`BaseSource.kt:283-295`），本仓在 Phase 5 之前没有 Book 实体，
>   故登记为有意差异（ADR-0034 §决策 2）。
> - **`key` 只绑在 URL 规则的 job 上**（ADR-0034 §决策 3）：其余 job 送 `null`，前奏删掉该全局名，
>   所以字段规则里写 `{{key}}` 是 `js:error`，不会静默拿到空串。
> - **`java.timeFormat(timestamp)` 的入参、格式与时区（2026-10-13 取证，上表只记形态与 pattern）：**
>   入参是**毫秒时间戳**（JS `number` 或可转成数字的字符串，无法转换即 `js:error`）；输出固定
>   `yyyy/MM/dd HH:mm`、**设备本地时区**、不补零以外的任何本地化（上游
>   `JsExtensions.kt:678` + `AppConst.kt:40` 的 `FastDateFormat.getInstance("yyyy/MM/dd HH:mm")`，
>   `FastDateFormat` 默认取 JVM 默认时区）。同为 worker 内同步、**不计**本表的调用额度。
>   **状态（M1-b1 已落地）：** 实现是 `core/js/js_bindings.dart` 的 `formatJsTimestamp` +
>   纯格式化 `formatTimestamp`；设备侧由 `integration_test/js_bridge_test.dart` 的两条探针盯住
>   （Windows 已实测，Android 那次跑受构建环境网络阻塞，登记在 `docs/dev/roadmap.md` §3.7）。
>   **两个入参边界（实现可见，归本表）：** ① 小数按**向零截断**（等价于上一次 Java `(long)`
>   对 JS 数字的转换；毫秒时间戳本不该带小数，所以这个选择不会遮蔽错误值）；
>   ② 超出 Dart `DateTime` 精度范围的入参（`|ms| > 8.64e15`，即 ±1 亿天）**在转换前就判失败**
>   —— `DateTime.fromMillisecondsSinceEpoch` 对超范围值报 `RangeError`（属 `Error`，
>   ADR-0022 / C-ERR-2 不允许本层捕获），所以只能提前挡；结果是该次调用失败（`ok:false` →
>   `js:error`），不是崩溃也不是钳位。
>   `timeFormatUTC(time, format, sh)`（同族，带时区偏移与自定义 pattern）**不在 M1**，
>   登记去向见 `docs/dev/roadmap.md` §3.7。
> - **致命与可吞的区别：** `http.*` 的传输失败只拒绝那次调用；`parse.*` 的边界与额度是**判决**
>   ——判决先记下、等脚本停下来的那条结果回来时才交给调用方（脚本还在跑时不能把 worker 交给下一个
>   job：同一运行时上跑两份求值会共享 `globalThis` 与作业队列），硬预算仍是「脚本永远不停」的兜底。
>
> **3.3 落地状态与两处边界（2026-10-12，随 `docs/dev/roadmap.md` 3.3 落地）：**
>
> - **本阶段落了什么：** 常驻 worker isolate + 单复用运行时的桥（`core/js/`）：引擎级 5 秒中断与
>   32MB 堆上限由构造参数传入；同步绑定 `log.*`（转发到 `core/logging`，自动附字段路径）与
>   `crypto.md5` / `sha1` / `base64Encode` / `base64Decode` 已可用。单 worker + FIFO 排队，
>   超限**等待**而不报 busy（ADR-0030 §决策 1/3）；引擎中断失效时由硬预算 `Isolate.kill` 兜底，
>   并在下一个 job 重建 worker。
> - **`rulePath` 的标注形态：** 失败把标注**附在字段路径后**——`<字段路径>:js:timeout` /
>   `:js:error`（例 `searchRule.name:js:timeout`），这样 C-SRC-8 的「可定位」与本表的「标注」
>   两个要求同时成立。**例外：** 取消（桥 / 作用域已释放，或调用方主动取消）只带**裸字段路径**、
>   不带标记——取消不是脚本错误，触发条件归 §7。
> - **沙箱的禁令是按 §6 执行且可实测的（2026-10-12，3.3 复核 F1）：** 运行时以「什么都不装」
>   构造（`JsWebApis.none()`：无 `console`、无定时器，plain ECMAScript），并且**每个 job 前
>   重跑一次沙箱预备**——删掉 §6 禁止的名字（`setTimeout` / `setInterval` / `clearTimeout` /
>   `clearInterval` / `queueMicrotask` / `console` / `atob` / `btoa` / `structuredClone` /
>   `performance` / `require` / `process` / `XMLHttpRequest` / `fetch` 等）并重装白名单绑定。
>   重跑是必要的：`Object.freeze(crypto)` 冻的是对象、不是 `globalThis` 上的属性名，规则写
>   `globalThis.crypto = …` 会把篡改留给**下一个 job（可能是另一个书源）**。集成探针逐名断言
>   这些名字是 `undefined`，验证重绑后下一个 job 仍能拿到真绑定，并确认硬化沙箱没有打掉引擎
>   自己的 Promise 作业队列（3.4 的 Promise 绑定靠它）。
> - **`log.*` 的宿主侧上界（3.3 复核 F2）：** 单条消息截断到上表的 2 000 字符并留可见标记，
>   所以 `log.debug(result)` 不会把 200KB 正文写进日志；本条数**计入**「单条规则内 JS 调用次数」
>   额度（已随 3.4 的额度实现落地，见上）。
> - ~~**未落的部分归 3.4：** Promise 形态的 `http.*` / `parse.*`、`parse.*` 的页级 scope 边界
>   （`js:parse-scope`）与「单条规则内 JS 调用次数 ≤ 20」（含 `log.*` 计数）~~ → ✅ **均已落地
>   （3.4，见上）**。
> - **`log.*` 的 C-SEC-4 边界：** 转发的是**规则作者自己写的**文本，只经 `AppLogger` 的
>   `redactMessage`（能掩 URL / 凭据，**认不出正文**）。上界挡住体量，但「不得把页面正文交给
>   `log.*`」仍是书源作者的义务，宿主侧无法代为净化。

---

## 7. 失败语义

> 本表定义的是**触发条件**；「ARB 文案键名规则」（`failure<PascalCaseKind>`）的
> 唯一出处是 `docs/dev/naming.md` §8，本表只列出具体键值。
> 「可重试」列由 `ParseFailureKind.isRetryable` 实现，改动任一侧都必须同步另一侧。

| `ParseFailureKind` | 触发条件 | ARB 文案键 | 可重试 |
|---|---|---|---|
| `networkTimeout` | 连接/读取超时 | `failureNetworkTimeout` | 是 |
| `networkFailed` | DNS/连接失败、5xx | `failureNetworkFailed` | 是 |
| `networkForbidden` | 403 | `failureNetworkForbidden` | 否 |
| `notFound` | 404 | `failureNotFound` | 否 |
| `encodingFailed` | 编码检测或解码失败 | `failureEncodingFailed` | 否 |
| `parseFailed` | 规则无匹配、JS 异常或超时、规则模板无法展开（未闭合的 `{{…}}` / `@get:{…}`、展开深度超限） | `failureParseFailed` | 否 |
| `unsupportedRule` | 命中 M2 或未实现语法 | `failureUnsupportedRule` | 否 |
| `invalidBookSource` | 导入 JSON 缺必填字段或结构非法 | `failureInvalidBookSource` | 否 |
| `cancelled` | 用户主动取消，或**桥 / 作用域已释放**（job 被丢弃而未运行；`rulePath` 只带裸字段路径，§6） | 无（静默） | — |

**关键判定：**

- 「规则无匹配」与「成功但结果为空」必须区分：
  - 顶层 `bookList` / `chapterList` / `content` **无匹配** → `parseFailed`。
  - 顶层匹配成功但集合为空 → **成功**，返回空列表（搜索无结果属正常业务）。
- 失败必须携带 `rulePath`（C-SRC-8），格式 `<字段名>` 或 `<字段名>.<子字段>`，
  例如 `searchRule.bookList`、`tocRule.chapterUrl`、`contentRule.content`；
  命中未实现语法时用 `unsupported:<语法名>`，例如 `unsupported:@webJs`、`unsupported:xpath:ancestor::`。
- 失败对象**禁止**携带用户可见文案（C-ERR-7）。

---

> **2026-10-11 裁决（ADR-0026；实现与 §3.1 的 3.2 同批落地）：** 「命中未实现语法」分两类——
> **顶层规则**（`bookList` / `chapterList` / `content`）被拒仍**整次失败**；**非顶层字段**被拒时
> 该字段**置空 + warning**（含 `rulePath` 与书源 ID，C-ERR-8 / C-SRC-8），结果照常返回。
> C-SRC-4 的「禁止静默忽略」由「显式降级 + 记录」满足（§9 的健康度统计是同一模式）。
> **已随 3.2 落地（2026-10-11）：** 唯一实现点是 `PageFetchService` —— `field()`（非顶层字段）
> 把 `unsupportedRule` **与 `parseFailed`** 都降级为「置空 + warning（含 `rulePath`、失败 kind
> 与书源 ID）」，`list()` / `content()`（顶层）继续整次失败。两类同口径的理由见 ADR-0026 §决策 2
> 的复审修订注记：畸形规则若上抛，调用方只取 `dataOrNull`，会既不上报也不记录地变成 `null`。

## 8. 并发与限速

| 项 | 值 | 分期 |
|---|---|---|
| 同一书源默认并发上限 | 3 | M0 |
| `concurrentRate` 覆盖 | `n/m` = 每 `m` **毫秒**内最多 `n` 次；单个整数 `x` = 每 `x` 毫秒 1 次；`"0"` / 空 = 不限；非法（非整数、`n <= 0`、`m <= 0`、`x <= 0`）→ 忽略该声明 + 一条 warning（回退默认并发）。与上行的「同一书源默认并发上限」**两门同时生效**，超限排队 | M1 |
| 章节正文批量下载 | 必须串行或有限并发，禁止对单一域名无限并发 | M0 |
| 缓存键 | `书源 ID + 规则字段 + URL + 页码` 的稳定哈希，必须带 TTL（C-NET-6） | M0 |

> **实现点与排队语义（2026-10-12，随 `docs/dev/roadmap.md` 3.8 落地）：** 预算在**请求层唯一实现**——
> `DioHttpClient` 每次真正上线的请求都经 `RequestLimiter`，键 = `sourceId`（书源 URL），无书源
> 上下文时回退到 URL 主机，因此「章节正文批量下载」（Phase 5）只要走 `HttpClient` 就自动受限；
> 章节正文的分页本身是**串行**的（`FetchContent` 逐页取）。超限的调用**排队等待**而不失败
> （C-SRC-9 要求可并发调用，「busy」不是可接受的答复），按调用顺序（FIFO）接班；调用抛异常也
> 会释放槽位。`JsBridge` 契约**不含**容量参数（ADR-0030 §决策 2）；`concurrentRate`（M1）
> 将把书源自己的声明读进同一预算。
>
> **两处边界（2026-10-12 架构师审查登记）：**
>
> - **同一个主机可能有两份预算。** 带书源上下文的调用按 `sourceId` 分桶，无书源上下文时按 URL
>   主机分桶，两者互不影响（今天所有页面抓取都带 `sourceId`，主机桶只服务将来的无上下文调用）。
> - **JS 桥的 `http.*`（3.4）与页面抓取共用同一书源预算。** 实现时**不得**在已经持有该预算
>   槽位的调用内部再发起同一书源的请求，否则预算会被自身耗尽而永久排队（预算只有 3 个）。
>   —— **已落地（3.4）：** 规则里的 `http.*` 由桥转发到同一个 `HttpClient` 实例，预算键就是
>   规则 job 的 `source.url`（同 §6）；上面的禁忌针对的是「持有槽位时再嵌套发起」，与桥无关
>   （页面抓取的槽位在规则求值之前已释放）。
>
> **`concurrentRate` 的语法与合成规则（2026-10-13，M1-b0 裁决，理由与备选见 ADR-0036）：**
> **语法与毫秒单位以上表为唯一出处**；上游依据是 `ConcurrentRateLimiter.kt:17-46`（`n/m` 解析）、
> `:52-70`（`0` / 空 = 不限）、`:86`（原文注释「次数/毫秒」）、`:88-108`（超限 `delay` 重试），
> 应用点是所有出网请求（`HttpHelper.kt:164` / `AnalyzeUrl.kt:121` / `JsExtensions.kt:512/538/569`）。
> 本仓的合成规则：
>
> - **两门互不替代**：请求要**同时**通过速率门（`n/m` 滑窗）与并发门（默认 3）；量纲不同，不得用
>   「取更严格的一条」这种没有定义的说法代替。
> - **顺序固定为先取速率许可、再占并发槽位**：反过来会让等待中的请求白占并发槽位，
>   3 个槽位被等待者占满即整源停摆。
> - **超限排队、不报 busy**（C-SRC-9）；异常也释放槽位（与上文的并发门同一实现）。
> - **速率门与并发门共用同一个实现点**（`DioHttpClient` 的 `RequestLimiter`，速率状态与并发槽位同键；
>   该实现点归上文，本节不另立）：脚本的 `http.*` 与页面抓取自动共用同一份限速，**不得**为速率
>   另开第二个实现点，也不得把速率参数提到 `HttpPolicy` / `JsBridge` 契约里（ADR-0030 §决策 2 的口径不变）。
> - **默认不限速**：只有书源声明了 `concurrentRate` 才启用速率门；`HttpPolicy` 不新增默认速率字段。
> - **触发条件：** 真实语料若证明作者把 `n/m` 当「次数/秒」，按 ADR-0036 §决策 8 出新 ADR，
>   不得就地改单位；M1-b2 的验收包含「语料里 `concurrentRate` 取值分布 + 单位判断记录」。
>
> **实现（2026-10-13，M1-b2 已落地）：** 两把门都在 `RequestLimiter` 里（ADR-0036 §决策 5）：
> `applyRate(key, rate)` 登记一个源的速率声明，`run()` 先取速率许可、再占并发槽位；
> 声明文本的解析与非法声明的 warning 在 `DioHttpClient.applySourceRate`（唯一实现点），
> 四个 UseCase 在第一个请求之前把书源的声明交给它（键 = 书源 URL，所以脚本的 `http.*` 自动共用）。
>
> - **速率门是滑窗**（最近 `n` 个许可都必须老于 `m` 毫秒），这正是上表「每 `m` 毫秒内最多 `n` 次」的
>   严格读法。**与上游的差异（登记）：** 上游在窗口过期后**重置**一个固定窗口
>   （`ConcurrentRateLimiter.kt:88-108`），允许 `n` 个请求坐在一个窗口末尾、另 `n` 个坐在下一个窗口开头；
>   本仓宁可严一点。
> - **解析的一处宽容（登记）：** `n/m` 与单个 `x` 两侧的空白被忽略；上游对原始子串调 `toInt()`，
>   `"10 / 5"` 在那里抛异常并保留旧记录，本仓直接判为非法（忽略 + warning）。
> - **单位判定结论：** 全量合集统计（3/3907 条声明、均为 1000–3000 的单整数 → 读成毫秒才合理）
>   支持毫秒口径，ADR-0036 §决策 8 的重开条件**未满足**；数字、A/B 回归与复跑命令见
>   `tool/spot_check/README.md`（M1-b2 一节）。
> - **接线是一处 funnel（b2 复核补充，2026-10-13）：** 声明由 `PageFetchService.applySourceRate(source)`
>   转给请求层，四个 UseCase 在**首个请求之前**调用它；`RequestLimiter.applyRate` 对相同声明**幂等**
>   （不重置窗口），所以重复调用无副作用。反过来，**漏调不会报错**：该源只是不被限速——因此新增
>   任何读源操作时必须补这一行，且每个 UseCase 都要有一条「把源声明交给客户端」的接线测试。
>   `HttpClient.applySourceRate(sourceId, 声明原文)` 是**唯一入口**（语法解析与非法声明的 warning 都
>   留在请求层，因为它才是花预算的那一层），不得在别处再实现一份速率门或把速率参数搬进
>   `HttpPolicy` / `JsBridge`（ADR-0036 §决策 5）。

---

## 9. 错误恢复

| 场景 | 行为 |
|---|---|
| 单章正文失败 | 该章标记失败，不中断整本书的目录展示 |
| 目录缺页 | 按 `nextTocUrl` 翻页，上限 **500 页**后停止并记录 warning（正文分页共用同一上限，见 §4.1）。这个上限只是失控保护：上游不设固定值（靠 `nextTocUrl` 收敛 + 去重），2026-10-30 真机日志里 50 页让多本长书缺了尾部章节（`DECISIONS.md` #85） |
| 发现页单页失败 | 只影响该分类：该分类报错 + 记录，其余分类与其余页面照常（发现页不进自动翻页队列，§4.2） |
| 章节正文分页失败 | 该章**整次失败**，不返回被截断的正文（§4.1） |
| 规则失效（0 结果） | 记录到书源健康度统计，UI 提示「规则可能已失效」 |
| 书源整站改版 | 不做自动适配；由用户更新书源 |

---

## 10. 测试基线与回归

| 项 | 要求 |
|---|---|
| 固定语料 | `test/fixtures/book_sources/*.json`（书源）+ `test/fixtures/html/*.html`（HTML 页面）+ `test/fixtures/json/*.json`（JSON 响应页）。页面**优先真实抓取**；站点已不可达或需固定会话参数时允许**按该书源的真实规则构造**，但必须在 `test/fixtures/**/README.md` 标注来源与构造依据。抓取页面仍是 §3 矩阵「已确认」与 Phase 3.7 真实回归的目标 |
| 语法单测 | §3 矩阵中每个 **M0** 语法至少 1 条单测；M1 语法在实现时同步补 |
| 前缀大小写 | `@css:`/`@CSS:`、`@json:`/`@Json:`、`@js:`/`@JS:` 各 1 条 |
| 失败单测 | §7 表中每个 `ParseFailureKind` 至少 1 条单测 |
| 链路测试 | 至少 2 个书源完成「搜索 → 详情 → 目录 → 正文」离线回放（已达成 **G2a 离线回放**：1 个 HTML 默认规则源 + 1 个 JSON 接口源；其中 JSON 源的 2 条 URL 规则按 `test/fixtures/json/README.md` 改写，因此**不**等于真实站点回放——只有真实抓取页面 / 真实链路才能把 §3 矩阵的状态列改为「已确认」，归 `docs/dev/roadmap.md` §3.4 的 3.7） |
| M2 拒绝测试 | `:正则` 与 `@webJs` 各 1 条，断言返回 `unsupportedRule`（XPath 已支持，其**未实现子集**的拒绝由 `matrix #21` 那组用例覆盖） |
| 真实书源验证 | 每个 M0/M1 语法行需在 PR 中附验证记录，并把状态列改为「已确认」 |
| 网络隔离 | 单元测试禁止真实联网；`HttpClient` 必须可注入替身（C-NET-8） |

真实书源验证记录格式（写入 PR 描述）：

```
语法：#11 &&
书源：<name> (<url host>)
链路：搜索 → 目录 → 正文
结论：已确认 / 行为差异：<描述> → 已更新矩阵
```

> **#14 列表形态 / #31 `<js>` / §4.3 URL 后缀的当前证据（2026-10-21，ADR-0047）：**
> 语料 `4dc410d1.json`（128 条公开合集，`tool/spot_check/batch_probe.dart` 全量复跑）+
> 单源 spot-check（`--plain-http`）。逐条记录：
>
> | 语法 / 字段 | 书源 | 链路 | 结论 |
> |---|---|---|---|
> | `#31 <js>` + `header` 规则（§4.3 之外的 A2） | 阅友小说（`sma.yueyouxs.com`） | 搜索 → 详情 → 目录 → 正文 | 已确认（search=5 / toc=57 / content=676，`sha256=d7e97e3157580991`）；该源在改造前**导入即失败** |
> | `#14` 列表 JS + §4.3 `charset` | 飞卢小说💰（`b.faloo.com`，`searchUrl` 带 `{"charset":"gbk"}`） | 搜索 → 详情 → 目录 → 正文 | 已确认（search=28 / toc=1087 / content=1156，`sha256=d208052977d3039c`）；目录页数由 291 变为 1087，证明 GBK 链路真的被解开 |
> | `$.[*]` 方言（§3 的 #13 变体） | 有声听书网 | 搜索 | 由 `parseFailed` 变为真命中（2 条） |
>
> 未覆盖的部分（`@webJs` / `sourceRegex`）保持「不支持」，不受本轮影响；XPath 自 M25/S5b 起支持（§3 注记）。

> **#13（`@json:` / 裸 `$.`）的当前证据（2026-10-11）：**
> 语法 `#13 @json:`；书源 示例书源（JSON 规则，真实导出结构，已脱敏，
> `test/fixtures/book_sources/legado_json_source.json`）；链路 搜索 → 详情 → 目录 → 正文
> （**离线回放**，`chain_givenJsonSourceAndCorpusPages_replaysEveryStage`）。
> **结论：离线回放已达（属 ADR-0024 的 G2a）；矩阵状态仍为「待验证」**——按 ADR-0024 §决策 2，
> 只有**真实抓取页面 / 真实链路（G2b）**才能把状态改为「已确认」，该语料的页面是按真实规则
> 构造的（唯一偏离：2 条 URL 规则因 M0 缺 #16–#19 而改写，见 `test/fixtures/json/README.md`）。
> 状态改「已确认」统一由 **3.7** 处理（与 #12 同一口径）。

> **G2b 验证入口与记录（2026-10-12 落地）：** `tool/spot_check/` —— 驱动生产链路的可复现 harness
> 与实测记录（站点、命令、四段结果、派生 `@css:` 等价验证）。它**不进 CI**，与 `tool/spike/` 同一模式。

---

## 11. 明确不支持（M2）

命中以下任一语法必须在导入或解析时明确拒绝并给出可读提示，不得假装成功：

- `:` 正则规则在**值规则位置**（它只作用于书籍列表与目录列表；条目上的非 `$N` 模板同样具名拒绝，
  见 §3 的 `:正则` 注记）
- **XPath 里本仓没实现的那部分**（M25/S5b，语义与支持面见 §3 的 XPath 注记）：`ancestor` /
  `ancestor-or-self` / `following` / `preceding` / `namespace` 轴、`node()` / `comment()` 节点测试、
  `@*`、以及 `count()` / `normalize-space()` / `concat()` 这类函数——命中即 `unsupported:xpath:<语法>`
- 原生登录表单的**后续交互**：`java.upLoginData`（脚本动态改表单）仍未实现；`loginUi` 的
text / password / button / select / toggle + `action` JS、`source.getLoginInfo()` / `getLoginInfoMap()` /
`putLoginInfo` / `removeLoginInfo`（M22-a 读、M25/S5a 写，ADR-0072 §决策 3）与
`source.putLoginHeader` / `getLoginHeader` / `getLoginHeaderMap` / `removeLoginHeader`（M25/S3b + S5a，
含请求头合并、Cookie 合并与登出清 Cookie）**已实现**。两条仍与上游不同：① 登录**信息**（`loginInfo`）
只喂给登录自己的脚本 job，页面请求的 job 里还读不到（登记在 `roadmap.md` §3.7）；② 规则内
`source.login()` **具名拒绝**（登录走登录页）——登出已有入口，不再拒绝
- 图片字节解密 `ruleContent.imageDecode`（非空即显式 `unsupportedRule`，ADR-0069 G5）
- **`java.*` 的具名拒绝族（ADR-0037 §决策 5；形态与实现档位见 §6 的兼容面表）：**
  其中 `get` / `put` 不在拒绝族里——§6 把 `java.get(key)` / `java.put(key, value)` 定义为**规则变量**
  读写（ADR-0034），名字被占用，上游那套同步返回 body 的 `get(url)` 因此仍无可用拼写。
  **仍拒绝的：** `webViewGetElements`（本仓没有元素列表形态的渲染接口）、`downloadFile` / `cacheFile` /
  `importScript`（沙箱禁忌或需要平台能力）——命中即抛**可读错误**，不得落到
  `undefined is not a function`。多参重载（`base64Encode(str, flags)` / `base64Decode(str, charset)`）
  同样具名拒绝：本仓没有 flags / charset 语义。
  **这份名单是机器的对照面（S7 门禁 G1）：** 下面两个代码块必须与
  `lib/core/js/quickjs_worker.dart` 的 `__javaRejectedNames` / `__javaInteropNames` **逐字一致**，
  由 `test/docs/book_source_doc_test.dart` 校验——改任何一边都会让门禁失败（ADR-0012）。

```text
downloadFile
cacheFile
importScript
createAsymmetricCrypto
createSign
```
  **已随 M25/S3b 落地、不再拒绝：** `java.connect` / `java.ajaxAll` / `java.openUrl` / `java.androidId`，
  以及阶段上下文绑定 `src` / `chapter` / `nextChapterUrl` / `fromBookInfo` / `infoMap`（语义见 §6）。
  **M25/S3b 登记的两条有意差异：** `speakText` / `speakSpeed` 只由上游的 **HttpTTS 源**提供，本仓没有那条
  链路，所以**不绑定**（触发 = 引入 HttpTTS 朗读引擎）；`java.androidId()` 答的是本仓自己生成并持久化的
  UUID，而不是 Android 的 16 位十六进制 id。
  **已随 M24 落地、不再拒绝：** `java.ajax` / `java.post` / `java.head` / `java.getCookie` / `java.setContent` /
  `java.toast` / `java.longToast` / `cookie.*` / `source.getVariable`（语义见 §6）。
  **已随 M25/S5a 落地、不再拒绝：** `source` 的白名单字段（`key` / `bookSourceUrl` / `bookSourceName` /
  `bookSourceComment` / `header` / `loginUrl`）、`source.put` / `get`、`getLoginHeaderMap` /
  `removeLoginHeader`、`putLoginInfo` / `removeLoginInfo`（语义见 §6「`source` 对象」）。
  **已随 M25/S3a 落地、不再拒绝：** `java.md5Encode16` / `base64DecodeToByteArray` / `hexDecodeToByteArray` /
  `hexEncodeToString` / `hexDecodeToString` / `strToBytes` / `bytesToStr` / `digestHex` / `digestBase64Str` /
  `HMacHex` / `HMacBase64` / `createSymmetricCrypto` / `aes*` / `des*` / `tripleDES*`（语义见 §6
  「字节与密钥族」）。
  **密钥族的边界（S3a 登记）：** 只支持 AES / DES / DESede × ECB / CBC × PKCS5/PKCS7/NoPadding；
  CFB / OFB / CTR / GCM 这类模式与非对称（`createAsymmetricCrypto`）、签名（`createSign`）**仍是具名拒绝**
  （前两者在上面的拒绝族里，模式不匹配则报 `unsupported mode`）。重新评审的触发条件：真实语料出现
  该 transformation 且有能复现的源。
- Rhino Java 互操作（`Packages.*` 与下列 `java.*` 包，命中**抛错 Proxy**，报可读原因）：

```text
lang
security
util
net
io
nio
math
text
```
  **M25/S5d 之后的口径（ADR-0081）：** 上面的 8 个名字仍然是抛错 Proxy（本仓 `java` 是扩展面、不是包），
  但 Rhino 真正的包入口 `Packages.*` 有了**最小垫片**：白名单成员（`java.lang.String`、`java.util.*`、
  `android.util.Base64`、hutool 的 `DigestUtil` / `Base64`、`…http.StrResponse` 等）可用，白名单外的名字
  抛 `Packages.<包.类.成员> is not supported`；`new JavaImporter(…)` 同样具名拒绝。清单与边界见 §6。
