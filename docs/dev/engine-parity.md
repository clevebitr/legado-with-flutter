# 引擎对齐台账：与上游 `legado` 的差距清单

> 本文件是「本仓解析引擎 ⇄ 上游 Legado 引擎」差距的**唯一清单**，用途与 `ui-gap.md` 相同：
> 排里程碑、记状态、写去向。它**不是规范** —— 规则语义归 `book-source.md`，失败语义归其 §7，
> 覆盖对象归 `roadmap.md`，裁决理由归 `docs/dev/adr/`。
>
> 对照基线：`F:\Projetcs\legado-upstream`（`app/src/main/java/io/legado/app/`，2026-10-26 快照）。
> 本仓基线：`lib/features/book_source/domain/rule_engine/` + `lib/core/js/` + `lib/features/book_source/domain/`。
>
> 里程碑：**M25**（对齐行为，`#35`）→ **M26**（高性能重构，`#36`）→ **M27**（语料回归与台账清零，`#37`）。

---

## 1. 怎么用这份清单

| 列 | 含义 |
|---|---|
| **上游证据** | 能一眼核对的 `文件:行号`；没有行号的项不得进表 |
| **本仓现状** | `未建模`（字段只在 `extra`）/ `显式拒绝`（`unsupportedRule`）/ `部分`（有语义缺口）/ `已对齐` |
| **语料命中** | `tool/spot_check/batch_probe.dart` 的静态普查（源数 / 出现次数），**M27 填**；空 = 尚未普查 |
| **去向** | `S1`–`S7` 切片 / `有意差异`（须带触发条件）/ `已知热点`（性能，归 M26） |

范围分界（ADR-0078 §决策 2）：**与上游 Legado 的行为差距只写在这里**；`roadmap.md` §3.7 保留其余
跨 feature 的未闭环节点，引擎项在那里只留回链。

三条硬规则：

1. **不允许「未建模却声称支持」**：`book-source.md` §2/§3/§11 与代码必须逐条一致（出口判据见 §4）。
2. **不允许静默**：命中未实现能力的字段必须是「字段置空 + warning」或「显式 `unsupportedRule`」
   （C-SRC-4 / ADR-0026），不得当成解析成功。
3. **未知字段不丢**：所有未建模字段一律留在 `extra` 并随导入/导出往返（ADR-0071）；台账的
   「未建模」只表示**不生效**，不表示丢失。

---

## 2. A — 书源级字段

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ✅ `jsLib`（源内 JS 库，作为每个脚本的 prototype scope） | `BaseSource.kt:335-339`、`AnalyzeRule.kt:848`、`SharedJsScope.kt:23-60` | **已对齐**（M25/S1）：字段建模为 `BookSource.jsLib`；`JsLibStore` 解析（纯 JS 直通 / JSON 对象里的 http(s) 值逐条下载按序拼接，缓存 16 条、失败不缓存）→ worker 在同一函数作用域里先跑库再跑规则；库失败与规则失败分开（`js:lib`）。三条有意差异：库顶 `let`/`const` 规则不可见（Rhino ES5 同样不认）、缓存只在内存、`source.jsLib` 不在 `source` 绑定里 | 待 M27 | 已对齐（`book-source.md` §6） |
| ⚠ `coverDecodeJs`（封面二次解密） | `ImageUtils.kt:66-69` | 未建模 | **1 源**（§9.1） | **S6c**（与 `imageDecode` 共用字节通道） |
| ⚠ `ruleReview`（段评九字段） | `rule/ReviewRule.kt:9-20` | 未建模 | **0 源**（§9.1） | 不做（要 UI；语料命中 0，触发 = 出现依赖段评的源） |
| ✅ `bookUrlPattern`（搜索 URL 命中即按详情页解析；`bookList` 为空时回落详情页） | `BookList.kt:62-84`、`:100-110` | **已对齐**（M25/S2）：最终 URL 与 pattern 全匹配即用 `ruleBookInfo` 读成一条结果；无 pattern 且列表为空（或列表规则一条未命中）时同样回落详情页；坏正则只记 warning | 待 M27 | 已对齐（`book-source.md` §4） |
| ⚠ `eventListener` / `callBackJs` / `customButton` / `homepageModules` | `BookSource.kt:104-112`、`SourceCallBack.kt:54/94/117` | 未建模（`callBackJs` 见 B4） | **0 源**（§9.1） | 不做（要 UI/事件面；语料命中 0，触发 = 出现依赖它们的源） |
| `enabledExplore` | `BookSource.kt:52` | `extra`，发现页仍会尝试 | | 有意差异（未提供单源发现开关 UI） |
| `enabledCookieJar`（单源 CookieJar） | `BaseSource.kt:56-58` | 无按源语义（Cookie 按域共享） | | 有意差异（ADR-0072 §决策 2） |
| `speakText` / `speakSpeed`（HttpTTS 源的朗读参数） | `AnalyzeUrl.kt:83`、`:371-372`、`HttpReadAloudService.kt:612-630` | **不绑定**：只由上游的 HttpTTS 源表提供，本仓只有系统 TTS，没有那条链路 | | 有意差异（触发 = 引入 HttpTTS 朗读引擎） |
| `bookSourceComment` / `customOrder` / `weight` / `respondTime` / `lastUpdateTime` | `BookSource.kt:70-80` | 部分（排序字段已有，注释未建模） | | 不影响解析，低优先 |

## 3. B — 阶段字段与流程

### 3.1 `ruleContent`

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ✅ `subContent`（副文；音频源写成章节变量 `lyric`） | `BookContent.kt:144-163` | **已对齐**（M25/S2）：文本源追加到正文、音频源作为 `ChapterContent.lyric` 交回调用方；值是 http(s) 地址时先取那一页正文（取不到只记 warning、不判章失败） | 待 M27 | 已对齐（`book-source.md` §4.1） |
| ✅ `title`（正文反取章节名 + `reviewImg`） | `BookContent.kt:165-190` | **已对齐（解析）**（M25/S2）：正文页标题与 `reviewImg` 进 `ChapterContent`；值里的标签会剔掉（上游会把 `<div id=…>` 当下标，属小差异）。**阅读端尚未采用**这个改名（端口仍只要正文） | 待 M27 | 解析已对齐；阅读端采用归后续 |
| ⚠ `payAction`（付费章节解锁动作） | `ReadBookViewModel.kt:2623`、`MangaReaderActionRepository.kt:237` | **已建模、不执行**：本仓没有付费内容 UI，执行它也没有落点 | | 有意差异（触发 = 加入付费章节解锁 UI） |
| ⚠ `callBackJs`（事件回调） | `SourceCallBack.kt:54/94/117` | **已建模、不执行**：`ContentRule.callBackJs` + `BookSource.eventListener` 都进导出往返，事件面不存在 | | 有意差异（触发 = 阅读器事件回调需求） |
| `imageDecode`（图片字节解密） | `ContentRule.kt:21` | 显式拒绝（`fetch_manga_pages.dart:30-41`） | **2 源** | **S6c**（要「返回字节的 job」+ 解密图落盘 + 阅读端从字节渲染） |
| `imageStyle`（`full`/`single`/`left`/`right`/居中） | `ContentRule.kt:20` | **够用**：`full` / `single` / 默认三分支；`left` / `right` 未实现（ADR-0069 G5） | **49 源声明，取值只有 `FULL`/`0`/`full`/`Full`**（§9.1） | 维持（`left`/`right` 语料命中 0） |
| 正文 HTML → 纯文本（本仓**有意**与上游不同） | `BookContent.kt:207-216`、`HtmlFormatter.kt:151-195`（上游保留 HTML，由富文本视图渲染） | **已做**（2026-10-27）：`content` 的每个匹配都参与（上游 `getString` 的换行拼接），并在 `replaceRegex` 之前把 HTML 转成纯文本（块级标签→换行、行内剥掉、script/style 丢弃、实体解码、图片丢弃）。阅读端是纯文本，所以这是必要差异 | **83 / 249 条 `content` 规则产出 HTML**（2026-10-27 语料） | 有意差异（触发 = 阅读端支持富文本并需要内联图时改成上游口径） |
| 正文分页并发（多值 `nextContentUrl`，≤4） | `BookContent.kt:113-141` | 串行 | | **已知热点**（M26 R4） |
| ✅ 「下一页 == 下一章」提前停止 | `BookContent.kt:90-96`、`BookSourceCheckRepository.kt:222-230` | **已对齐**（M27 第二轮）：`walk` 比较下一页与 `nextChapterUrl`（两边绝对化）；校验阶段把目录第 2 章传下去 | 14 源跑满旧 50 页上限（本机 254 源）；上限已抬到 500（`DECISIONS.md` #85） | 已对齐（`book-source.md` §4.1 注记） |

### 3.2 `ruleToc`

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ✅ `formatJs`（统一重写章节名，绑 `index`/`chapter`/`title`/`gInt`） | `BookChapterList.kt:141-163` | **已对齐**（M25/S2）：一次 job 跑完整份目录，`index` 逐章重绑、`gInt` 跨章累积；脚本抛错只保留该章原标题 | 待 M27 | 已对齐（`book-source.md` §6） |
| ✅ `isVolume`（分卷标记；卷标题无 url 时用标题占位） | `BookChapterList.kt:240-259` | **已对齐**（M25/S2）：`Chapter.isVolume`，无 URL 的卷用「标题+序号」占位；无名条目整条丢弃 | 待 M27 | 已对齐（`book-source.md` §4.1） |
| ✅ `isPay`（已购标记，与 `isVip` 共同决定「锁定」） | `BookChapterList.kt:229-268`、`TocScreen.kt:894` | **已对齐（解析）**（M25/S2）：`Chapter.isPay` 按上游 `isTrue()` 判定；阅读器的锁定 UI 仍只看 `isVip` | 待 M27 | 解析已对齐；锁定 UI 归后续 |
| ✅ `preUpdateJs`（更新检查前置脚本，可中止） | `WebBook.kt:305-313` | **已对齐**（M25/S2）：`FetchToc` 在第一个请求前执行，失败即整段目录失败（不发请求） | 待 M27 | 已对齐（`book-source.md` §6） |
| ✅ 目录去重（`LinkedHashSet`）与元数据保留（`wordCount`/`variable`/`reviewImg`） | `BookChapterList.kt:120-140`、`:275-295` | **已对齐（去重 + 字段）**（M25/S2）：按 `(名字, URL)` 去重保序；`Chapter` 增加 `wordCount` / `variable` / `reviewImg` / `isPay` / `isVolume`。上游的「跨刷新保留旧元数据」依赖章节入库，本仓目录不落库 | 待 M27 | 去重已对齐；跨刷新保留归「目录不落库」登记 |
| 目录翻页并发（多值 `nextTocUrl`） | `BookChapterList.kt:100-118` | 串行 | | **已知热点**（M26 R4） |

### 3.3 `ruleBookInfo` / 列表阶段

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ⚠ `downloadUrls`（文件型源，`bookSourceType=3`） | `BookInfo.kt:171-180` | **未建模** → 文件型源完全不可用 | **11 源**（type3 共 7 个源） | **S6b** |
| ⚠ `relatedBooks`（详情页相关推荐模块） | `BookInfoViewModel.kt:2009` | 未建模 | | S6 之后（要 UI） |
| `tocHtml` 复用（`tocUrl == baseUrl` 时省一次请求） | `BookInfo.kt:167-170` | 无 | | 已知热点（M26） |
| 列表条目缺 `bookUrl` 时**回落当前页** | `BookList.kt:282`（`bookUrl.isEmpty() -> baseUrl`） | 跳过该条目 + warning（`book_list_fields.dart`） | 1 源 / 11 条（本机 23uswx，均是无链接的推荐块） | 有意差异（回落会造出一批指向分类页的垃圾书；触发 = 出现依赖它的单书站） |
| 发现页表单型分类（`text`/`button`/`toggle`/`select` + `chars`/`default`/`action`/`style`） | `rule/ExploreKind.kt:9-49` | 显式拒绝（ADR-0035 §决策 6） | | 有意差异（触发 = 出现只能靠筛选器的真实源） |
| 发现页 `infoMap` / 排名模块 | `AnalyzeUrl.kt:376`、`executeForRanking` | 显式拒绝 | | 有意差异（同上） |
| `init`（详情页换 scope） | `BookInfo.kt:58-64` | 已对齐（M1-b6） | | 已对齐 |

## 4. C — 规则语法（`book-source.md` §3 矩阵）

| 矩阵 / 方言 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| #20 `:正则`（列表规则正则模式，`&&` 分隔可多级，取分组） | `AnalyzeByRegex.kt`、`AnalyzeRule.kt:539-552`、`:393`、`:430` | **已对齐**（M25/S5e）：`&&` 是正则链、每条匹配一个条目（全部组）、条目字段用 `$1`/`$2`/`$0` 模板取组值（可带 `##` 替换）；值规则位置具名拒绝 `unsupported::`、条目上的非模板规则 `unsupported:regex:item`、对着 JSON 跑 `parseFailed` | 2 源 / 2 处（目录列表） | 已对齐（差异见 `book-source.md` §3 的 `:正则` 注记） |
| #21 `@xpath:` 与裸 `//` | `AnalyzeByXPath.kt`、`AnalyzeRule.kt:623-638` | **已对齐（自研子集）**（M25/S5b，ADR-0080）：`rule_engine/xpath_rule.dart` 的解析器 + 求值器（路径 / `*` / 标签 / `text()` / `@attr`、谓词、`|` 并集、七个轴）。四条有意差异：只认 `//` 与 `@xpath:`（上游连 `/` 开头都算 XPath）、`ancestor` 等 4 个轴与 `count()` 等函数具名拒绝、`text()` 只答直接文本子节点（与 XPath 1.0 一致）、列表规则选中文本时 `parseFailed` | **43 源 / 155 处**（2026-10-27，工具口径）：其中 24 处在 `bookSourceComment` 的脚本注释里、31 处在 URL 字段（`coverUrl` 15 等），真正落在四段规则字段的是 100 处 / 21 源——**这三处都是本仓会求值的规则文本**，S5b 一并覆盖 | 已对齐（差异见 `book-source.md` §3 注记/§11） |
| #22 `@webJs`（规则级后台 WebView 脚本） | `AppPattern.WebJS_PATTERN`、`AnalyzeRule.kt:245/341/398/435` | 显式拒绝 `unsupported:@webjs` | | **S5**（复用 `WebPageFetcher`） |
| #30 提取段嵌套规则（`class.a@css:.b`） | `AnalyzeByJSoup.kt:200-282` | 显式拒绝 `unsupported:nested-rule`（`:2746`）。**复核后维持拒绝**：语料真命中 **0 源 / 0 处**（原 22/125 是普查探测器误报，见 §9.2） | 0 | 有意差异（触发 = 出现依赖它的真实源） |
| ✅ 列表规则**尾部** `@js:`（`class.list@tag.li@js:result`） | `AnalyzeRule.kt:435-440`（任一段是 JS 段即可） | **已对齐**（M25/S4）：只要列表规则**任一段**是 JS 段就走段链解释器，脚本拿到上一段的条目内容、返回值逐项成为条目。两条边界仍拒绝并留标记：**嵌套**的 `parse.getElements` 里的 `@js:` 报 `unsupported:@js:list`（再起一个 job 会排在发起它的 job 后面，ADR-0030），脚本看到的是条目**内容**（元素 `outerHtml`）而不是 jsoup 元素——`attr()` / `text()` 这类写法不成立（§6 的同一立场） | 待 M27 | 已对齐（差异见 `book-source.md` §3 #14） |
| ✅ URL 页码列表 `<1,2,3>`（按页取第 n 个，超出取末值） | `AnalyzeUrl.kt:777`、`:203-213` | **已对齐**（M25/S4）：`renderPageList` 在 `{{…}}` 之后替换，页码来自请求（`JsPageContext.page`），超出取末项 | 待 M27 | 已对齐（`book-source.md` §4.3） |
| ✅ URL 段链 `@result`（字面段引用上一段脚本产出） | `AnalyzeUrl.kt:157-176` | **已对齐**（M25/S4）：`renderUrl` 先跑 `analyzeJs` 的同一套链（字面段替换、`@result` 代入、脚本收 `result`），所以「整条规则就是一个 `@js:`」的 URL 也成立 | 待 M27 | 已对齐（`book-source.md` §4.3） |
| ✅ GET query **全量**按 `charset` 编码 | `AnalyzeUrl.kt:268-273`、`:295-300` | **已对齐**（M25/S4）：声明 `charset` 时整条 query 按该编码转义（安全集照抄 `encodeQueryParams`，空格 `%20`），已经编码过的 query 原样保留。差异：`charset: "escape"` 方言未建模（地址原样发出） | 待 M27 | 已对齐（`book-source.md` §4.3） |
| ✅ `+` 正序前缀（`bookList` / `chapterList`） | `BookList.kt:73-75`、`BookChapterList.kt:59-65` | **已对齐**（M25/S4）：先剥 `-` 再剥 `+`，两者都只是标记（`-+rule` 仍倒序） | 待 M27 | 已对齐（`book-source.md` §3 #7） |
| HTML 实体反转义（`unescape` 默认 true） | `AnalyzeRule.getString/getStringList` | 不做；`getString(rule, true)` 具名拒绝 | | 有意差异（ADR-0037 §后果） |
| `@css:` 的 jsoup 扩展伪类（`:containsOwn(a b)`、裸正则 `:matches(x)`） | jsoup `Selector` | cascadia `parseFailed`（响亮失败） | | 有意差异（矩阵 #12 注记） |
| ✅ 默认规则里的**属性选择器**（`[attr]` / `[attr=v]` / `meta[...]`） | `AnalyzeByJSoup.kt:406-440`（`findIndexSet` 解析不出索引就 `break`，整段留给 jsoup） | **已对齐**（M27，矩阵 #32）：`[` 后首个非空格字符是字母 / `_` 时整段交给 cascadia；数字 / `-` / `!` / 空串仍走索引列表 | **10 源 / 31 处**（本机 54 源，2026-10-28） | 已对齐 |
| ✅ 位置列表 `.N:M[:N]`（`.` 筛选 + `:` 分隔序号） | `AnalyzeByJSoup.kt:280-288`、`:406` | **已对齐**（M27，矩阵 #33）：`.N:M` 进与 `!N:M` 同一个索引读取器，顺序按写法保留 | **10 源 / 15 处**（本机 54 源） | 已对齐 |
| ✅ JSON 条目上的裸键（map 直接取成员） | `AnalyzeRule.kt:331`（`else if (result is LinkedTreeMap<*, *>) result[rule]`） | **已对齐**（M27，矩阵 #13 注记）：JsonScope + Map + 无选择器 → `map[key]`，值按 #13 的形状返回；列表 / 标量条目仍 `parseFailed` | 1 源（520diandu，日志 511 条降级） | 已对齐 |
| ✅ `\|\|` 的空候选（`A\|\|##replace`） | `AnalyzeByJSoup.getString`（空规则 `temp.isNullOrEmpty()` 跳过）、`AnalyzeRule.kt:339` | **已对齐**（M27，矩阵 #10 注记）：空候选 / 空分支不产出值，`##` 属于整条规则；整条规则都空仍 `parseFailed` | 1 源 / 2 字段（天地中文） | 已对齐 |
| `\|\|` 的某个候选**解析失败**时结束整条规则 | 上游没有「解析失败」这一态（失败降级成空串，继续试下一个） | 部分：C-SRC-4 的响亮失败 | — | 有意差异（触发 = 真实源只能靠后备分支救活） |
| jsoup 的 `[attr~=regex]`（正则**子串**匹配） | jsoup `Evaluator.AttributeWithValueMatching`（`Pattern.matcher(...).find()`） | 按 CSS `~=` 读（空白分隔的整词），因此解析成功但不匹配（`_quoteAttributeValues` 会先加引号） | 3 源 / 3 处（`[property~=category|status|tags]` 一类，仅 `kind`） | 有意差异（要做需在 cascadia 外挂正则后置过滤器；触发 = 出现依赖 `~=` 的非展示字段） |
| 已实现类型名后跟属性选择器，如 `tag.li[x]` | jsoup `getElementsByTag("li[x]")` → 静默无匹配 | 显式 `parseFailed` | 0 源 | 有意差异（比上游更严，C-SRC-4） |
| 页面是 JSON 时规则**整体**自动进 JSON 模式 | `AnalyzeRule.SourceRule.init`（`isJSON`） | 不自动切（ADR-0047 §决策 6）；**条目**上的裸键已按上行对齐 | | 有意差异（页面级自动切实测无增益；条目级是真缺口，已修） |
| ✅ 行首装饰性 `@`（`RuleAnalyzer.trim()` 在切段前剥掉） | `RuleAnalyzer.kt:15-22`、`AnalyzeRule.kt:208-210` | **已对齐**（M27 第二轮）：单个 `@` 在切段前剥掉（标志头由 `_flagOf` 补回） | **8 源**（本机 254 源） | 已对齐（`book-source.md` §3 注记） |
| ✅ 只有替换段的字段规则（替换对象是 scope 内容） | `AnalyzeRule.getString`（`result` 仍是 content） | **已对齐**（M27 第二轮）：`##pattern##replace###` 在页面 body / 条目 HTML / JSON 文本上替换；不命中给空串 | **10+ 源** | 已对齐（`book-source.md` §3 注记） |
| ✅ 脚本列表条目的 JSON 字符串（`String?.isJson()`） | `StringExtensions.kt:47-55`、`AnalyzeRule.setContent` | **已对齐**（M27 第二轮）：`{…}` / `[…]` 解码成 JSON scope，其余当 HTML 片段 | 1 源（福书网，872 次） | 已对齐（`book-source.md` §3 #14 注记） |
| `result` 元素句柄（`Element` / `Elements` 的 `.attr` / `.text` / `.select`） | jsoup `Element` | **部分**（M27 第二轮）：**字面量参数**的链由宿主就地求值再内联（13 个方法）；变量参数 / 未覆盖方法不内联（脚本照旧响亮失败）；整页 `result` 仍是正文文本 | 964 次 `not a function`（本机 254 源） | 有意差异（触发 = 出现非字面量参数或未覆盖方法的真源） |
| 未建模的 URL 选项（`origin` / `js` / `dnsIp` …） | `UrlOption` | **显式失败**（M27 第二轮改判）：`unsupportedRule` + `rulePath=unsupported:url-options:<名字>`，不再忽略后照发 | 3 处（`searchUrl` / `ruleBookInfo`） | 有意差异（C-SRC-4 的响亮失败；`book-source.md` §4.3） |

## 5. D — JS 沙箱绑定面

对照 `JsExtensions.kt`（1220 行）+ `AnalyzeRule.kt:834-847` + `AnalyzeUrl.kt:365-376` + `BookChapterList.kt:145-149`。

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ✅ 密钥类 crypto：`createSymmetricCrypto` / `aes*` / `des*` / `tripleDES*` / `HMac*` / `digest*`、`base64DecodeToByteArray` / `hexDecodeToByteArray` / `hexEncodeToString` / `hexDecodeToString` / `strToBytes` / `bytesToStr` / `md5Encode16` | `JsEncodeUtils.kt:20-528`、`SymmetricCryptoAndroid.kt` | **已对齐**（M25/S3a）：`byte[]` = JS `Uint8Array`（`length` / `[i]` / `Array.from` / `slice` 都可用），`createSymmetricCrypto` = 不透明句柄（密码器本体在宿主，九个方法逐一对齐）+ 上游 `@Deprecated` 的 `aes*` / `des*` / `tripleDES*` 全族；`pointycastle` 提供 AES / DES / DESede × ECB / CBC × PKCS5/NoPadding。三条有意差异：`aesEncodeToString` 按名字的意图加密（上游实现是 `decryptStr` 的历史 bug）、`base64DecodeToByteArray` 收 `flags` 但不按位分支、模式/非对称/签名仍拒绝 | 33 源 / 91 处（本地语料 `corpus_a` 504 条 + `corpus_b` 128 条，2026-10-26 静态普查；M27 用 `batch_probe.dart` 重算） | 已对齐 |
| ✅ 全局绑定 `src` / `chapter` / `nextChapterUrl` / `fromBookInfo` / `infoMap` / `gInt`+`index`（`formatJs`） | `AnalyzeRule.kt:834-847`、`AnalyzeUrl.kt:365-376`、`BookChapterList.kt:145-149` | **已对齐**（M25/S3b）：`src` = 这一页的正文（整页与元素级规则同一份）、`chapter` = 正在读的那一章（title/url/isVip/isPay/isVolume/updateTime + get/putVariable）、`nextChapterUrl` = 目录里下一条地址、`fromBookInfo` = 详情阶段标记、`infoMap` = 每源可写小表（会话内共享）。三条有意差异：`chapter` 的变量落规则变量表（与 `book` 同口径）、`infoMap` 不落盘（同 `cache.*`）、`speakText`/`speakSpeed` 不绑定 | 待 M27 | 已对齐（差异见 `book-source.md` §6/§11） |
| ✅ `cache.*`（`CacheManager`） | `AnalyzeRule.kt:836`、`CacheManager.kt:48-140` | **已对齐（内存层）**（M25/S3b）：`put/putMemory/get/getFromMemory/getInt/getLong/getDouble/delete/deleteMemory`，容量 256 条 + 单值 64 K 字符 + 秒级 TTL，随 worker 存亡。有意差异：上游是「内存 + 持久 `Cache` 表」两层，本仓不落盘（重启即丢） | 3 处 / 2 源（其中 1 处为注释） | 已对齐（差异见 `book-source.md` §6） |
| ✅ `source.getKey` / `getTag` / `getLoginHeader` / `putLoginHeader` / `getLoginHeaderMap` / `removeLoginHeader`（+ 请求头合并与 Cookie 合并 + 登出清 Cookie） | `BaseSource.kt:61-157`、`:102-130` | **已对齐**（M25/S3b + S5a）：`getKey()` = `bookSourceUrl`、`getTag()` = `bookSourceName`；登录头存 `book_sources.login_header`（按 URL，上游缓存键同此），随 job 下传、写过即写穿，并由 `headersOf` 压在源 `header` 之上、其中的 `Cookie` 并进 Cookie 宗；`getLoginHeaderMap()` 答上游的 Java-`Map` 形状（普通对象 + 不可枚举的 `get/put/remove/containsKey/size/isEmpty`）；`removeLoginHeader()` 删登录头**并**清该源 URL 会发的 Cookie（上游 `CookieStore.removeCookie(getKey())`）。一条有意差异：规则内 `source.login()` 具名拒绝（登录由登录页的 `SignIn` 跑同一段脚本） | `getLoginHeaderMap` 2 源 / 7 处、`removeLoginHeader` 2 源 / 4 处、`getLoginHeader`/`putLoginHeader` 6 源 | 已对齐（差异见 `book-source.md` §6/§11） |
| ✅ `source` 对象的字段与其余成员：`key` / `bookSourceUrl` / `bookSourceName` / `bookSourceComment` / `header` / `loginUrl`、`put`/`get`、`getVariable`/`setVariable`/`putVariable`、`getLoginInfo*` / `putLoginInfo` / `removeLoginInfo` | `BaseSource.kt:283-320`（变量与 `put/get`）、`:172-243`（登录信息）、`BookSource.kt:30-95`（字段） | **已对齐**（M25/S5a）：上游把**整个源实体**绑成 `source`，本仓换成**白名单字段**（其余不外泄，`jsLib` 仍只在宿主侧）；`put(k,v)` 答回写入的值、`get(k)` 未写过答空串；`getVariable()` / `setVariable(v)` / `putVariable(v)` 是上游的**无参整份变量**形状（存在 `source_variables` 的无名条目里，与 `put/get` 同一张表）；`putLoginInfo(json)` / `removeLoginInfo()` 只在规则写过时把登录信息写穿 `book_sources.login_info`（按 URL）。两条有意差异：JSON 形态的 `header` 按解析后的表重新序列化（原文的空白与键序不保留）、`putLoginInfo` 只收字符串并对解析不出的 JSON 答 `false`（上游照样存，读时再退回空表） | `source.key` 14 源、`bookSourceUrl` 10 源 / 148 处、`bookSourceComment` 5 源、`put`/`get` 4/3 源、`getVariable` 无参 54 处、`setVariable` 41 处、`getLoginInfoMap` 9 源、`putLoginInfo`/`removeLoginInfo` 3/1 源（2026-10-27 语料） | 已对齐（差异见 `book-source.md` §6） |
| ✅ `timeFormatUTC` / `htmlFormat` / `toNumChapter` / `randomUUID` / `toURL` / `getWebViewUA`（纯计算族） | `JsExtensions.kt:20-120`、`HtmlFormatter.kt:151-183`、`JsURL.kt` | **已对齐**（M25/S3b）：全部在 worker 内同步完成；`toURL().origin` 修掉了上游把它自己插进 `host:` 的 bug（有意差异） | `randomUUID` 5 源 / `getWebViewUA` 5 源 | 已对齐（`book-source.md` §6） |
| ✅ `t2s` / `s2t` | `JsExtensions.kt:706-713`、`ChineseUtils.kt` | **已对齐（码表不同源）**（M25/S3b）：OpenCC 的 `TSCharacters/TSPhrases` 与 `STCharacters/STPhrases` 生成 `assets/zh/*.txt`，最长匹配；上游那份 `quick-chinese-transfer` 无 LICENSE，不能搬（C-DEP-7）。差异：没有上游 `fixT2sDict()` 的排除词表 | `t2s` 5 处 / 3 源，`s2t` 0 | 已对齐（差异见 `book-source.md` §6） |
| ✅ `androidId` / `openUrl` / `ajaxAll` / `connect` | `JsExtensions.kt:136-215`、`:1152-1180` | **已对齐**（M25/S3b）：`connect` 答响应对象且**失败也是答案**（正文是可读 kind 名，非 Java 堆栈）、`ajaxAll` 并发取多页且一页失败整次抛错（`skipRateLimit` 不绕过单源预算）、`openUrl` 走确认弹窗 + `url_launcher`、`androidId` 是首启生成并持久化的 v4 UUID（非 Android 的 16 位十六进制） | `connect` 3 源、`openUrl` 3 源、`ajaxAll` 1 源、`androidId` 1 源（本地语料手工普查） | 已对齐（差异见 `book-source.md` §6） |
| ✅ 上游 master **不存在**的成员：`refreshBookUrl` / `webViewGetElements` | —— | 不提供（早期台账误登记） | 0 | 台账已改正 |
| 文件/压缩包族（`readFile` / `unzipFile` / `getZipStringContent` …） | `JsExtensions.kt:727-976` | 具名拒绝 | | 有意差异（沙箱禁忌，C-SRC-3） |
| Rhino Java 互操作（`Packages.*` / `JavaImporter`） | `JsExtensions.kt`、Rhino 的包入口 | **部分对齐**（M25/S5d，ADR-0081）：白名单垫片 = `java.lang.String` / `System.currentTimeMillis` / `Thread.sleep`（**空操作**）、`java.util.UUID` / `Arrays` / `HashMap` / `LinkedHashMap` / `ArrayList`、`android.util.Base64` / `TextUtils.isEmpty`、hutool `DigestUtil.md5(md5Hex)` / `Base64`、`io.legado.app.help.http.StrResponse`。白名单外的成员具名拒绝（带完整包路径），`JavaImporter` 亦然；`javax.crypto` / `java.io` 流 / `java.net.URL` / `okhttp3` / `org.jsoup` 不做（要真实 Java 对象，本仓等价能力在 `java.*` / `crypto.*`） | 19 源用 `Packages.*`；其中 **6 源只需白名单**、13 源要 `javax.crypto` 或流/网络类 | 有意差异（触发 = 出现只差 `javax.crypto` 一个能力的真实源） |
| 已对齐（对照用） | `java.ajax/post/head/getCookie/setContent/toast`、`cookie.*`、`queryTTF`/`queryBase64TTF`/`replaceFont`、`startBrowser*`/`getVerificationCode`/`webView*`、`getString*`/`getElements`；以及**执行前注入的 `jsLib` 库作用域**（S1） | 已落地（ADR-0068 / 0076 / 0078 S1） | | 已对齐 |
| ✅ `cookie.removeCookie(url)` 单参 | `CookieStore.kt:79`（绑定的是 `CookieStore`，只有一个参数：删该 URL 会发的整份 Cookie） | **已对齐**（M27）：无 `key` 删整份（`removeCookiesFor`），带 `key` 按名删（本仓扩展的 `CookieManager` 拼写） | 1 源（八零电子书） | 已对齐（`book-source.md` §6） |
| `java.getElements` 的元素句柄（`.text()` / `.attr()` / `.size()`） | `AnalyzeByJSoup` 的 `Elements`（Java 对象） | 只给元素文档（`outerHtml` 字符串 / JSON 值）；列表尾部 `@js:` 与 `parse.getElements` 的同一立场已登记，但 `java.getElements` 的内联快路径没单列 | 1 源（次元小说，file 型源本身受 S6b 阻） | 有意差异（要真 DOM 句柄；触发 = 语料 ≥3 源） |
| 响应对象的 `.raw()` / `.raw().request().url()` | `StrResponse.raw`（OkHttp 对象） | 未建模；等价能力是 `url()` / `code()` / `header()` | 1 源（趣书网吧的 e-search 重定向） | 有意差异（触发 = 出现只差 `.raw()` 的源） |
| `@put` 的值规则失败时**写空串并继续** | `AnalyzeRule.kt:455-458`（`put(key, getString(value))`，失败就是空串） | 整个字段 `parseFailed`（`_storePutEntries` 上抛） | 0 源（本机除已修的裸键外无） | 有意差异（C-SRC-4 的响亮失败；触发 = 出现靠容错才能跑的真源） |

## 6. E — 非文本书源

| 类型 | 上游 | 本仓现状 | 去向 |
|---|---|---|---|
| 文本（0） | 完整四段 | 已对齐 | — |
| 音频（1） | `content` 取地址，`subContent` 作歌词 | `content` 取地址；`subContent` 已解析成 `ChapterContent.lyric`，**播放器 UI 暂不展示** | 歌词展示归后续（有意差异） |
| 图片（2） | `content` 取图片列表 + `imageDecode` + `imageStyle` 全分支 | 有 `fetch_manga_pages`，`imageDecode` 拒绝、`imageStyle` 部分 | **S6** |
| 文件（3） | `ruleBookInfo.downloadUrls` + 批量下载 | 无 | **S6** |
| 视频（4） | 有视频播放链路 | 无 | **S6** |

---

## 7. 切片（顺序即依赖顺序）

| 片 | 内容 | 主要落点 | 依赖 |
|---|---|---|---|
| **S1** ✅ | `jsLib` | `core/js/js_lib.dart`（解析 + 缓存）、`BookSource.jsLib`、worker 前奏 `__runRuleWithLib`、`RuleEngine._jsLibOf` | — |
| **S2** ✅ | 阶段字段族 + `bookUrlPattern` + 目录去重/元数据 | 已落地（两半）：`TocRule`（`formatJs`/`isVolume`/`isPay`/`wordCount`/`preUpdateJs`）、`Chapter` 元数据、`FetchToc` 去重与卷占位、`bookUrlPattern` 详情页回落、`FetchContent` 返回 `ChapterContent`（正文 + 副文/歌词 + 正文页标题 + reviewImg）。有意差异：`payAction`/`callBackJs` 需要 UI；阅读端尚未采用 `title`/`lyric` | S1（已闭环） |
| **S3a** ✅ | 密钥类 crypto + 字节族 | 已落地：`core/js/js_crypto.dart`（hex/base64/字节编解码、`digest*` / `HMac*` / `md5Encode16`、AES / DES / DESede × ECB / CBC × PKCS5/NoPadding 与句柄表）、`quickjs_worker.dart` 前奏（`Uint8Array` 字节面 + `aes*` / `des*` / `tripleDES*` 别名）、`pointycastle ^4.0.0`。有意差异：`aesEncodeToString` 按意图加密、`base64DecodeToByteArray` 收 `flags` 不按位分支、CFB/OFB/CTR/GCM 与非对称/签名仍拒（`book-source.md` §11） | `pointycastle`（新依赖） |
| **S3b**（第一组 ✅） | 纯计算族 + `cache.*` | 已落地：`core/js/js_helpers.dart`（uuid/timeFormatUTC/toNumChapter/toURL/htmlFormat/t2s/s2t）、`core/js/zh_converter.dart` + `zh_tables.dart` + `assets/zh/*.txt`（OpenCC 码表）、`core/js/js_cache.dart`（内存 LRU）、前奏绑定 + 真引擎探针 5 条 | S3a（已闭环） |
| **S3b**（第二组 ✅） | `source.*` 簇（源身份 + 登录头） | 已落地：`core/js/source_login_header.dart`（仓库 + 内存 store）、`book_sources.login_header`（v13）、`PageFetchService.headersOf` 的登录头合并、`CookieManager.mergeCookieHeader`、前奏 `source.getKey/getTag/getLoginHeader/putLoginHeader` + `source.login()` 具名拒绝、真引擎探针 4 条 | S3b 第一组（已闭环） |
| **S3b**（第三组 ✅） | 全局绑定（D2）+ 平台族 | 已落地：`JsPageContext` 的 `src` / `chapter` / `nextChapterUrl` / `fromBookInfo` 与 `forPage` 传播、`SourceInfoMapStore`（`infoMap`）、`core/platform/install_id.dart`（`androidId`）、`js_sync_call` 的 `connect` / `ajaxAll`、`core/platform/external_url_opener.dart` + `url_launcher`（`openUrl`）、真引擎探针 5 条 | S3b 第二组（已闭环） |
| **S4** ✅ | URL 方言五条 + 列表尾部 `@js:` | 已落地：`url_template.dart` 的 `renderPageList` / `encodeUrlQuery`（安全集照抄上游两处）、`rule_engine.dart` 的 `_expandUrlSegments`（`@result` 链）与 `+` 前缀、列表规则「任一段是 JS」走段链、`page_fetch_service.dart` 的 GET query 全量编码 | — |
| **S5a** ✅ | `source` 对象补全（字段 + `put`/`get` + 变量 blob 形状 + 登录头 map / 登出 + 登录信息写） | 已落地：`JsSourceInfo` 白名单字段、前奏 `__javaMap` 与 `source.*` 全族、`source_variables` 的无名条目承载整份变量、`SourceLoginInfoWriter` + `book_sources.login_info` 按 URL 写穿、`CookieManager.removeCookiesFor` | 语料 §9.3（约 30 源） |
| **S5** ✅（#22 除外） | 矩阵 #20/#22 | `rule_engine.dart` | S5a/S5b/S5d/S5e 已交付；S5c #30 复核后 0 源 → 登记不做；只剩 #22 `@webJs`（语料 0 源，维持具名拒绝） |
| **S6** | 非文本链路 + 正文 HTML 化 | `fetch_manga_pages`/新 usecase、`content_purifier`、阅读端 | S2；**按 §9 拆成 S6b（文件型 11 源）/ S6c（图片字节 2 源）**，`imageStyle` 的 left/right 与正文 HTML 化语料命中为 0，排到最后 |
| **S7**（门禁部分 ✅） | 文档与拒绝清单收敛 + 门禁 G1/G2 | 已落地：`test/docs/book_source_doc_test.dart`（G1：§11 两个名单与 `__javaRejectedNames` / `__javaInteropNames` 逐字对照；G2：矩阵每行「已确认」必须有具名用例 `matrix #N`）、§11 的名单改成机器可读的 `text` 块、Rhino 互操作包名补全到 8 个。剩余：S1–S6 收尾后按 §8 出口判据复核一遍 | S1–S4 |
| **M27 日志取证片** ✅ | 真实日志（54 源全量校验）暴露的 6 项缺口：矩阵 #32 属性选择器、#33 位置列表、JSON 条目裸键、URL 段链 `key`、`cookie.removeCookie(url)` 单参、`\|\|` 空候选 | `rule_engine.dart`（`_isAttributeSelector` / `_dotIndexList` / `_domValues` / `_candidatesOf` / `_expandUrlSegments`）、`quickjs_worker_bridge._removeCookie`、三个测试文件 | — （决策见 `DECISIONS.md` #63） |

## 8. 验收与出口判据

1. 本文件**无**「未建模 / 显式拒绝 / 部分」行仍未标注去向（要么进切片，要么标「有意差异 + 触发条件」）。
2. 每个切片的 PR 附**真实书源证据**（源名 + 四段计数 + 正文哈希），格式照 `book-source.md` §10。
3. 「语料命中」列已由 `tool/spot_check/batch_probe.dart` 填满（L1 = 128 条合集；L2 = 全量合集只普查）。
4. 三处文档与代码一致（`book-source.md` §2 未建模字段、§3 矩阵状态列、§11 拒绝清单），由门禁 G1/G2 兜住。
5. 性能指标 P1–P6（`#36`）达标或明确登记为「已知热点」，且不因提速放宽任何行为 —— 阈值与口径
   归 ADR-0078 决策 4，改前/改后的数字见 §11 与 `tool/bench/README.md`。

## 9. 语料普查（2026-10-27，决定 S5/S6 的排序）

工具：`tool/spot_check/corpus_census.dart`（静态、不联网、`dart run` 即可，口径见 `tool/spot_check/README.md` §8）。

```bash
dart run tool/spot_check/corpus_census.dart \
  --source="<bookSource (1).json>" --source="<bookSource.json>"
```

**语料**：两份真实导出合并去重后 **334 个源**——type0 文本 280 / type2 图片 35 / type1 音频 7 /
type3 文件 7 / type4 视频 5。下表「源数」= 用到该项的不同书源数，「处数」= 原始出现次数。

### 9.1 书源级字段（缺口候选）

| 字段 | 源数 | 结论 |
|---|---|---|
| `ruleContent.imageStyle` | 49 | **不是缺口**：取值只有 `FULL`（26）/ `0`（20）/ `full`（2）/ `Full`（1）——全是「最大宽度」或默认；本仓 `full` / `single` / 默认已覆盖。`left` / `right` 的语料命中 = 0 |
| `ruleBookInfo.downloadUrls` | 11 | 文件型源（type3 共 7 个）完全不可用 → **S6b** |
| `ruleContent.title` | 11 | 解析已对齐（S2），**阅读端未采用** → 后续 UI 切片 |
| `ruleContent.imageDecode` | 2 | **S6c**（要「返回字节的 job」+ 解密图落盘 + 阅读端从字节渲染） |
| `coverDecodeJs` | 1 | 低（同 S6c 的字节通道，做则顺带） |
| `ruleContent.payAction` | 1 | 登记差异（无付费 UI） |
| `ruleReview` / `eventListener` / `customButton` / `homepageModules` | **0** | **数据支持「不做」**：维持具名登记，不再排期 |

已实现并被语料用到的字段（说明前几刀选得对）：`bookUrlPattern` 52、`jsLib` 19、`loginUi` 19、
`ruleToc.isVolume` 14、`loginCheckJs` 10、`ruleToc.isPay` 6、`ruleToc.preUpdateJs` 2。

### 9.2 规则语法（缺口候选）

| 语法 | 源数 | 处数 | 现状 / 去向 |
|---|---|---|---|
| 裸 `//` 开头（XPath 省略标志） | **43** | 155 | ✅ **S5b 已落地**（自研子集，ADR-0080）。构成：四段规则字段 100 处 / 21 源 + URL 字段 31 处（`coverUrl` / `nextTocUrl` / `bookUrl` 等，它们同样按规则求值）+ `bookSourceComment` 里的脚本注释 24 处 |
| 嵌套提取段（matrix #30 形状，如 `class.a@css:.b`） | **0** | 0 | **S5c 复核后取消**：原 22/125 是探测器误报（`text.split('@').skip(1)` 把「首段是 `@css:`/`@json:` 的规则」「`{{…}}` 里的内联规则」「`+`/`-` + `@css:`」都算成了段链），改成括号感知切段 + 首段非空（去掉 `+`/`-`/`@@`）后归零 → **登记不做**（触发 = 出现依赖它的真实源） |
| `@xpath:` 带标志 | 0 | 0 | 语料里没人这么写（都写裸 `//`）；✅ S5b 一并支持 |
| `:正则`（matrix #20） | 2 | 2 | ✅ **S5e 已落地**：正则链（`&&` 在正则里是链）+ 每条匹配一个条目 + 条目字段的 `$N` 模板；值规则位置与条目上的非模板规则具名拒绝 |
| `@webJs`（matrix #22） | **0** | 0 | **数据支持「不做」**：维持具名拒绝 |
| `%%` 交叉合并 | 1 | 1 | 已支持 |
| `:eq/:gt/:lt` 伪类 | 5 | 11 | 已支持（改写成 `:nth-child`） |
| 列表尾部 `@js:` / `+` 前缀 / `<1,2,3>` / `@result` | 7 / 5 / 0 / 0 | 7 / 5 / 0 / 0 | S4 已交付（后两项语料为 0，属兼容性收尾） |
| 属性选择器 `[attr]` / `[attr=v]`（matrix #32） | **10** | 31 | ✅ M27 已落地（本机 54 源的静态普查；日志里 4 个详情页因此全空）。之前的普查探测器不认这种形态，与 `.N:M` 一起漏网 |
| 位置列表 `.N:M[:N]`（matrix #33） | **10** | 15 | ✅ M27 已落地（本机 54 源；日志里 3 个源的 `kind` / `wordCount` 因此置空） |
| JSON 条目上的裸键（如 `$.pic@put:{img:pic}` 的 `pic`） | **1** | 1 | ✅ M27 已落地（520diandu；日志 511 条降级 + 511 章回落目录页）。台账原先把「JSON 自动模式」整体记为无增益，现改为「页面级无意差异，条目级已对齐」 |
| `@put` 值规则失败 → 空串继续（上游 `AnalyzeRule.kt:455-458`） | 0 | 0 | 维持响亮失败（有意差异，见 §5） |

### 9.3 沙箱绑定（语料里出现、本仓尚未提供）

| 成员 | 源数 | 处数 | 去向 |
|---|---|---|---|
| `source.key` | 14 | 20 | 它就是 `bookSourceUrl`（上游 `getKey()`）→ ✅ **S5a** |
| `source.bookSourceUrl` | 10 | 148 | 源对象的字段 → ✅ **S5a** |
| `source.bookSourceComment` | 5 | 27 | 同上（自定义变量说明，脚本用 `eval()` 当代码跑）→ ✅ **S5a** |
| `source.put` / `source.get` | 4 / 3 | 11 / 3 | 上游的**按名键值**存储（`v_<url>_<name>`），与 `getVariable` 的整份变量不是同一份 → ✅ **S5a** |
| `source.getLoginHeaderMap` / `removeLoginHeader` / `putLoginInfo(Map)` / `removeLoginInfo` | 2 / 2 / 2+1 / 1 | 7 / 4 / 3 / 1 | 登录态的其余入口 → ✅ **S5a**（`removeLoginHeader` 连 Cookie 一起清；`putLoginInfo` 只收字符串，语料里都是 `JSON.stringify(...)`） |
| `source.header` / `source.loginUrl` / `source.bookSourceName` | 2 / 2 / 1 | 2 / 2 / 1 | 源对象字段 → ✅ **S5a** |
| `source.getVariable()` **无参** / `setVariable(整份)` | 7 / 6 | **54 / 41** | 上游是**整份字符串**，本仓 S3b 曾做成键值式（语料命中 0）→ ✅ **S5a 改正**：整份变量落 `source_variables` 的无名条目 |
| Rhino 互操作：`java.lang` / `java.util` / `java.io` / `java.security` / `java.net` | **13 / 10 / 4 / 3 / 1** | 21 / 17 / 5 / 6 / 2 | ✅ **S5d 最小垫片已落地**（ADR-0081）：`Packages.java.lang.String`、`java.util.UUID` / `Arrays` / `HashMap` / `ArrayList`、`android.util.Base64`、hutool `DigestUtil`、`…http.StrResponse` 可用；**19 源**用 `Packages.*`，其中 6 源只差白名单、13 源还要 `javax.crypto`（`Cipher` / `SecretKeySpec` / `IvParameterSpec` / `Mac`）或流 / `okhttp3` / `org.jsoup` → 后者登记差异（触发 = 出现只差 `javax.crypto` 的源） |
| `java.refreshExplore` / `refreshTocUrl` / `searchBook` | 4 / 2 / 2 | 18 / 2 / 2 | 引擎/UI 动作，不是数据面 → 登记差异（触发 = 需要脚本触发刷新） |
| `java.upLoginData` | 3 | 4 | 登录表单的动态改造 → 登记差异（ADR-0072） |
| `java.getStrResponse` / `initUrl` / `url` / `headerMap` | 1 / 1 / 1 / 1 | 2 / 1 / 1 / 1 | 只在 `loginCheckJs` 里有效的 `AnalyzeUrl` 成员 → 登记差异 |
| `java.open` | 1 | 1 | 需要平台能力 → 登记差异 |
| `java.readTxtFile` | 1 | 1 | 沙箱禁忌（C-SRC-3） |
| `cache.getFile` / `putFile` | 1 | 1 | 文件缓存 → 登记差异（触发 = 有源依赖跨会话文件缓存） |

`java.*` 的其余成员（`ajax` 60 源、`getString` 45、`toast` 28、`md5Encode` 24、`log` 23、
`createSymmetricCrypto` 13、`connect` 9、`putLoginHeader` 6、`ajaxAll` 1、`openUrl` 1 …）**都已有实现**：
这份普查同时验证了 S3a/S3b 的选点（`connect` 9 源、`source.getLoginHeader*` 8 源都真实存在）。

### 9.4 由此定下的切片顺序（取代 §7 的旧排序）

| 片 | 内容 | 语料依据 | 依赖 |
|---|---|---|---|
| **S5a** ✅ | `source` 对象补全（`key` / `bookSourceUrl` / `bookSourceName` / `bookSourceComment` / `header` / `loginUrl`）+ `source.put`/`get` + `getVariable`/`setVariable` 的**上游无参形状** + `getLoginHeaderMap` / `removeLoginHeader`（含清 Cookie）/ `putLoginInfo` / `removeLoginInfo` | 约 30 个源；**已落地**（ADR-0078 S5a 实现注记） | S3b（已闭环） |
| **S5b** ✅ | XPath：裸 `//` 与 `@xpath:`（**自研子集，无新依赖**，见 ADR-0080） | 21 源 / 131 处（复核后的真实数字） | ADR-0080（已闭环） |
| **S5c** ❌（复核取消） | matrix #30 嵌套提取段 | **0 源 / 0 处**（原 22/125 是探测器误报，见 §9.2） | 登记为有意差异，不进切片 |
| **S5d** ✅ | Rhino 互操作最小 shim（`java.lang.String` / `java.util.UUID` / `Arrays` / `HashMap` / `ArrayList` / `android.util.Base64` / hutool / `StrResponse`），其余具名拒绝（ADR-0081） | 19 源用 `Packages.*`，6 源只需白名单、13 源另需 `javax.crypto` 等（登记差异） | ADR-0081（已闭环） |
| **S5e** ✅ | `:正则`（matrix #20）：正则链 + `$N` 条目模板（值规则位置具名拒绝） | 2 源 / 2 处（目录列表） | — |
| **S6b** | 文件型源（`downloadUrls` + type3 链路） | 11 源 / 7 个文件源 | S2 |
| **S6c** | 图片字节通道（`imageDecode` 2 源、`coverDecodeJs` 1 源）+ 阅读端从字节渲染 | 2 源 | 字节 job |
| **不做（有数据支撑）** | `ruleReview` / `eventListener` / `customButton` / `homepageModules` / `@webJs` / `imageStyle` 的 `left`/`right` | 全部 **0 源** | — |

## 10. 语料曝光（M27 填，先留空表）

§9 已经给出**静态**普查（每个源声明了什么）；这一张表要的是**运行时**曝光（`batch_probe.dart` 在
真设备上跑真实链路时，每个绑定/字段被真正执行到多少次），两者的口径不同，不要互相替代。

| 能力 | L1 源数 / 次数 | L2 源数 / 次数 | 备注 |
|---|---|---|---|
| `jsLib` | 待 M27 | 待 M27 | 本仓已支持（S1），统计待 `batch_probe.dart` 补 |
| 密钥类 crypto / 字节族 | 待 M27 | 待 M27 | 本仓已支持（S3a）；静态源数见 §9.3 |
| `subContent` / `title` | | | |
| `isVolume` / `isPay` / `formatJs` / `preUpdateJs` | | | |
| `bookUrlPattern` | | | |
| `@xpath:` / 裸 `//` | | | |
| `:正则` | | | |
| `@webjs` | | | |
| URL `<1,2,3>` / `@result` | | | |

复现命令（`tool/spot_check/README.md` §2）：

```bash
SPOT_CHECK_ARGS="--list=<collection.json>" flutter run -d windows -t tool/spot_check/spot_check.dart
```

## 11. 性能基准（`tool/bench/`，M26）

指标定义与阈值：ADR-0078 决策 4（本表不裁定，只记数字）。口径、夹具、复现命令与「P4/P5/P6 怎么接」
的唯一出处是 `tool/bench/README.md`。**门槛 = 改前/改后同一命令的差值**（2026-10-28 裁决：阈值维持初值）。

**改前基线（2026-10-28，Windows 11 / Flutter 3.47.7 / `--release` / 单章 199.7 KB / 目录 1000 章）**

| 指标 | 口径 | 目标 | 改前 p50 | 改后 p50（R1） | 差值 |
|---|---|---|---|---|---|
| **P1** | 解析 → 提取 → `replaceRegex`（不含网络） | ≤ 40 ms | **6.31 ms** | **6.17 ms** | −2.2%（预期内：一章只求值一次同一条规则） |
| **P2** | 千章目录，CSS 列表形态（解析 → 列表 → 2 字段 × 1000） | ≤ 300 ms | **17.76 ms** | **12.76 ms** | **−28%**（条目字段 −39%） |
| P2 | 千章目录，`:正则` 列表形态 | — | 10.71 ms | 9.69 ms | −9.5% |
| P2 | 线性度（每章 µs：250 / 500 / 1000 / 2000 章） | 近似线性 | 16.6 / 17.0 / 17.8 / 18.6 | 11.9 / 12.2 / 12.9 / 13.7 | 保持线性，斜率下降 |
| **P3** | 同一规则文本反复求值（CSS / JSONPath / 正则链） | ≥ 95% | **0.0%**（lookups 600 = compilations 600） | **99.7%**（lookups 1200 / compilations 4） | ✅ 达标（R1 已落地） |
| P4 | 一页 parse 次数 | 1 次/页 | 未测（缺计数器） | 未测 | R2 |
| **P5** | JS job 固定开销（空脚本往返） | ≤ 3 ms | 未测 | **2.83–3.03 ms p50 / 3.17–3.62 p95**（n=10/20 两次） | 已量：**压在阈值上**，分段归 R5 |
| P5 | 嵌套调用内联覆盖率 | ≥ 95% | 未测 | 字面量写法 **100%**（1/1）／带变量写法 0%（设计如此） | 语料侧数字由 `tool/spot_check` 的 `nested:` 行取（M27/L1） |
| **P6** | 单章 / 千章常驻增量（RSS） | ≤ 8 MB / ≤ 32 MB | 未测 | 首次 **1.06 / 1.55 MB**；后续中位 0.88 / 0.46；最大 3.13 / 7.09 | 桌面达标；Android 真机待 `integration_test` |

两条要注意的读数：

- **P1 的时间大头是「提取」**（3.59 / 6.31 = 57%，比 HTML 解析的 2.60 ms 还多），P2 的大头是 1000 条
  条目字段（12.19 / 17.76 = 69%）——R2（共享 `RuleScope`）与 R3（批量提取）动的是这两块。
- **P3 已经达标（R1）**：`_parse` / `_check` 的结果按 `(规则文本, hasExtraction, field)` 复用
  （LRU 256 / 512），观测点仍是 `RuleEngine.compileStats` 与 `_parseForEvaluation` 这个接缝；
  单测 `compileStats_givenRepeatedEvaluation_compilesTheRuleOnce` 钉住「一次会话只编译一次」。
- **P2 剩下的空间不在规则解析里**：条目字段的 −39% 是缓存买到的，剩下的成本是**选择器求值**
  本身（R3 的批量提取才动得到）。
- **P5 是唯一压在阈值上的指标**：空脚本 job 往返 p50 2.83–3.03 ms（目标 ≤3 ms）。分段量过
  （`tool/bench/README.md` §5.4）：消息底座 0.04 ms、宿主 ≈0、结果信封 +0.37 ms/32 KB、
  **剩下 ~2.8 ms 是「每 job 重跑 52 KB 沙箱前奏」的源码解析**（体积灵敏度 94 µs/KB）。
  ⇒ R5 的靶子不是「缓存规则脚本编译结果」（真实规则几百字节，<0.05 ms），而是「沙箱源码一次编译」。
- **P6 有量级余量，但「后续中位」不为 0**（0.46–0.88 MB/次）：10 轮 RSS 采样 + 没有 GC 钩子只够下
  「不像是大块泄漏」的结论，真机与按轮采样归 `integration_test`。
