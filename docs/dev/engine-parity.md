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
| 正文 HTML 化（`formatKeepImg`：相对 `<img>` 补全、`<usehtml>` 保真） | `BookContent.kt:207-216`、`HtmlFormatter.kt:151-195` | **无**：正文原样落库，阅读端也不渲染 HTML/内联图 | | **S6** |
| 正文分页并发（多值 `nextContentUrl`，≤4） | `BookContent.kt:113-141` | 串行 | | **已知热点**（M26 R4） |
| 「下一页 == 下一章」提前停止 | `BookContent.kt:90-96` | 无（`nextChapterUrl` 自 M25/S3b 起已下发，判定只差 `walk` 里的一个比较） | | S2（低） |

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
| 发现页表单型分类（`text`/`button`/`toggle`/`select` + `chars`/`default`/`action`/`style`） | `rule/ExploreKind.kt:9-49` | 显式拒绝（ADR-0035 §决策 6） | | 有意差异（触发 = 出现只能靠筛选器的真实源） |
| 发现页 `infoMap` / 排名模块 | `AnalyzeUrl.kt:376`、`executeForRanking` | 显式拒绝 | | 有意差异（同上） |
| `init`（详情页换 scope） | `BookInfo.kt:58-64` | 已对齐（M1-b6） | | 已对齐 |

## 4. C — 规则语法（`book-source.md` §3 矩阵）

| 矩阵 / 方言 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| #20 `:正则`（列表规则正则模式，`&&` 分隔可多级，取分组） | `AnalyzeByRegex.kt`、`AnalyzeRule.kt:539-552`、`:393`、`:430` | 显式拒绝 `unsupported:':'`（`rule_engine.dart:2915`） | | **S5** |
| #21 `@xpath:` 与裸 `//` | `AnalyzeByXPath.kt`、`AnalyzeRule.kt:623-638` | 显式拒绝（`:31-38`、`:2936`） | | **S5**（需引依赖 + ADR） |
| #22 `@webJs`（规则级后台 WebView 脚本） | `AppPattern.WebJS_PATTERN`、`AnalyzeRule.kt:245/341/398/435` | 显式拒绝 `unsupported:@webjs` | | **S5**（复用 `WebPageFetcher`） |
| #30 提取段嵌套规则（`class.a@css:.b`） | `AnalyzeByJSoup.kt:200-282` | 显式拒绝 `unsupported:nested-rule`（`:2746`） | | **S5** |
| ✅ 列表规则**尾部** `@js:`（`class.list@tag.li@js:result`） | `AnalyzeRule.kt:435-440`（任一段是 JS 段即可） | **已对齐**（M25/S4）：只要列表规则**任一段**是 JS 段就走段链解释器，脚本拿到上一段的条目内容、返回值逐项成为条目。两条边界仍拒绝并留标记：**嵌套**的 `parse.getElements` 里的 `@js:` 报 `unsupported:@js:list`（再起一个 job 会排在发起它的 job 后面，ADR-0030），脚本看到的是条目**内容**（元素 `outerHtml`）而不是 jsoup 元素——`attr()` / `text()` 这类写法不成立（§6 的同一立场） | 待 M27 | 已对齐（差异见 `book-source.md` §3 #14） |
| ✅ URL 页码列表 `<1,2,3>`（按页取第 n 个，超出取末值） | `AnalyzeUrl.kt:777`、`:203-213` | **已对齐**（M25/S4）：`renderPageList` 在 `{{…}}` 之后替换，页码来自请求（`JsPageContext.page`），超出取末项 | 待 M27 | 已对齐（`book-source.md` §4.3） |
| ✅ URL 段链 `@result`（字面段引用上一段脚本产出） | `AnalyzeUrl.kt:157-176` | **已对齐**（M25/S4）：`renderUrl` 先跑 `analyzeJs` 的同一套链（字面段替换、`@result` 代入、脚本收 `result`），所以「整条规则就是一个 `@js:`」的 URL 也成立 | 待 M27 | 已对齐（`book-source.md` §4.3） |
| ✅ GET query **全量**按 `charset` 编码 | `AnalyzeUrl.kt:268-273`、`:295-300` | **已对齐**（M25/S4）：声明 `charset` 时整条 query 按该编码转义（安全集照抄 `encodeQueryParams`，空格 `%20`），已经编码过的 query 原样保留。差异：`charset: "escape"` 方言未建模（地址原样发出） | 待 M27 | 已对齐（`book-source.md` §4.3） |
| ✅ `+` 正序前缀（`bookList` / `chapterList`） | `BookList.kt:73-75`、`BookChapterList.kt:59-65` | **已对齐**（M25/S4）：先剥 `-` 再剥 `+`，两者都只是标记（`-+rule` 仍倒序） | 待 M27 | 已对齐（`book-source.md` §3 #7） |
| HTML 实体反转义（`unescape` 默认 true） | `AnalyzeRule.getString/getStringList` | 不做；`getString(rule, true)` 具名拒绝 | | 有意差异（ADR-0037 §后果） |
| `@css:` 的 jsoup 扩展伪类（`:containsOwn(a b)`、裸正则 `:matches(x)`） | jsoup `Selector` | cascadia `parseFailed`（响亮失败） | | 有意差异（矩阵 #12 注记） |
| 页面是 JSON 时规则自动进 JSON 模式 | `AnalyzeRule.SourceRule.init`（`isJSON`） | 不自动切（ADR-0047 §决策 6） | | 有意差异（实测无增益） |

## 5. D — JS 沙箱绑定面

对照 `JsExtensions.kt`（1220 行）+ `AnalyzeRule.kt:834-847` + `AnalyzeUrl.kt:365-376` + `BookChapterList.kt:145-149`。

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ✅ 密钥类 crypto：`createSymmetricCrypto` / `aes*` / `des*` / `tripleDES*` / `HMac*` / `digest*`、`base64DecodeToByteArray` / `hexDecodeToByteArray` / `hexEncodeToString` / `hexDecodeToString` / `strToBytes` / `bytesToStr` / `md5Encode16` | `JsEncodeUtils.kt:20-528`、`SymmetricCryptoAndroid.kt` | **已对齐**（M25/S3a）：`byte[]` = JS `Uint8Array`（`length` / `[i]` / `Array.from` / `slice` 都可用），`createSymmetricCrypto` = 不透明句柄（密码器本体在宿主，九个方法逐一对齐）+ 上游 `@Deprecated` 的 `aes*` / `des*` / `tripleDES*` 全族；`pointycastle` 提供 AES / DES / DESede × ECB / CBC × PKCS5/NoPadding。三条有意差异：`aesEncodeToString` 按名字的意图加密（上游实现是 `decryptStr` 的历史 bug）、`base64DecodeToByteArray` 收 `flags` 但不按位分支、模式/非对称/签名仍拒绝 | 33 源 / 91 处（本地语料 `corpus_a` 504 条 + `corpus_b` 128 条，2026-10-26 静态普查；M27 用 `batch_probe.dart` 重算） | 已对齐 |
| ✅ 全局绑定 `src` / `chapter` / `nextChapterUrl` / `fromBookInfo` / `infoMap` / `gInt`+`index`（`formatJs`） | `AnalyzeRule.kt:834-847`、`AnalyzeUrl.kt:365-376`、`BookChapterList.kt:145-149` | **已对齐**（M25/S3b）：`src` = 这一页的正文（整页与元素级规则同一份）、`chapter` = 正在读的那一章（title/url/isVip/isPay/isVolume/updateTime + get/putVariable）、`nextChapterUrl` = 目录里下一条地址、`fromBookInfo` = 详情阶段标记、`infoMap` = 每源可写小表（会话内共享）。三条有意差异：`chapter` 的变量落规则变量表（与 `book` 同口径）、`infoMap` 不落盘（同 `cache.*`）、`speakText`/`speakSpeed` 不绑定 | 待 M27 | 已对齐（差异见 `book-source.md` §6/§11） |
| ✅ `cache.*`（`CacheManager`） | `AnalyzeRule.kt:836`、`CacheManager.kt:48-140` | **已对齐（内存层）**（M25/S3b）：`put/putMemory/get/getFromMemory/getInt/getLong/getDouble/delete/deleteMemory`，容量 256 条 + 单值 64 K 字符 + 秒级 TTL，随 worker 存亡。有意差异：上游是「内存 + 持久 `Cache` 表」两层，本仓不落盘（重启即丢） | 3 处 / 2 源（其中 1 处为注释） | 已对齐（差异见 `book-source.md` §6） |
| ✅ `source.getKey` / `getTag` / `getLoginHeader` / `putLoginHeader`（+ 请求头合并与 Cookie 合并） | `BaseSource.kt:61-157`、`:102-130` | **已对齐**（M25/S3b）：`getKey()` = `bookSourceUrl`、`getTag()` = `bookSourceName`；登录头存 `book_sources.login_header`（按 URL，上游缓存键同此），随 job 下传、写过即写穿，并由 `headersOf` 压在源 `header` 之上、其中的 `Cookie` 并进 Cookie 宗。两条有意差异：规则内 `source.login()` 具名拒绝（登录由登录页的 `SignIn` 跑同一段脚本）、`source.removeLoginHeader()` 不绑定（上游未标 `@JavascriptInterface`，本仓无登出入口） | 待 M27 | 已对齐（差异见 `book-source.md` §6/§11） |
| ✅ `timeFormatUTC` / `htmlFormat` / `toNumChapter` / `randomUUID` / `toURL` / `getWebViewUA`（纯计算族） | `JsExtensions.kt:20-120`、`HtmlFormatter.kt:151-183`、`JsURL.kt` | **已对齐**（M25/S3b）：全部在 worker 内同步完成；`toURL().origin` 修掉了上游把它自己插进 `host:` 的 bug（有意差异） | `randomUUID` 5 源 / `getWebViewUA` 5 源 | 已对齐（`book-source.md` §6） |
| ✅ `t2s` / `s2t` | `JsExtensions.kt:706-713`、`ChineseUtils.kt` | **已对齐（码表不同源）**（M25/S3b）：OpenCC 的 `TSCharacters/TSPhrases` 与 `STCharacters/STPhrases` 生成 `assets/zh/*.txt`，最长匹配；上游那份 `quick-chinese-transfer` 无 LICENSE，不能搬（C-DEP-7）。差异：没有上游 `fixT2sDict()` 的排除词表 | `t2s` 5 处 / 3 源，`s2t` 0 | 已对齐（差异见 `book-source.md` §6） |
| ✅ `androidId` / `openUrl` / `ajaxAll` / `connect` | `JsExtensions.kt:136-215`、`:1152-1180` | **已对齐**（M25/S3b）：`connect` 答响应对象且**失败也是答案**（正文是可读 kind 名，非 Java 堆栈）、`ajaxAll` 并发取多页且一页失败整次抛错（`skipRateLimit` 不绕过单源预算）、`openUrl` 走确认弹窗 + `url_launcher`、`androidId` 是首启生成并持久化的 v4 UUID（非 Android 的 16 位十六进制） | `connect` 3 源、`openUrl` 3 源、`ajaxAll` 1 源、`androidId` 1 源（本地语料手工普查） | 已对齐（差异见 `book-source.md` §6） |
| ✅ 上游 master **不存在**的成员：`refreshBookUrl` / `webViewGetElements` | —— | 不提供（早期台账误登记） | 0 | 台账已改正 |
| 文件/压缩包族（`readFile` / `unzipFile` / `getZipStringContent` …）、Rhino Java 互操作（`Packages.*`） | `JsExtensions.kt:727-976` | 具名拒绝 | | 有意差异（沙箱禁忌，C-SRC-3） |
| 已对齐（对照用） | `java.ajax/post/head/getCookie/setContent/toast`、`cookie.*`、`source.getVariable`、`queryTTF`/`queryBase64TTF`/`replaceFont`、`startBrowser*`/`getVerificationCode`/`webView*`、`getString*`/`getElements`；以及**执行前注入的 `jsLib` 库作用域**（S1） | 已落地（ADR-0068 / 0076 / 0078 S1） | | 已对齐 |

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
| **S5** | 矩阵 #20/#21/#22/#30 | `rule_engine.dart`（+ 依赖） | **已由 §9 的语料普查定序**：S5a `source` 对象 → S5b XPath（43 源）→ S5c #30（22 源）→ S5d Rhino shim → S5e `:正则`（2 源） |
| **S6** | 非文本链路 + 正文 HTML 化 | `fetch_manga_pages`/新 usecase、`content_purifier`、阅读端 | S2；**按 §9 拆成 S6b（文件型 11 源）/ S6c（图片字节 2 源）**，`imageStyle` 的 left/right 与正文 HTML 化语料命中为 0，排到最后 |
| **S7**（门禁部分 ✅） | 文档与拒绝清单收敛 + 门禁 G1/G2 | 已落地：`test/docs/book_source_doc_test.dart`（G1：§11 两个名单与 `__javaRejectedNames` / `__javaInteropNames` 逐字对照；G2：矩阵每行「已确认」必须有具名用例 `matrix #N`）、§11 的名单改成机器可读的 `text` 块、Rhino 互操作包名补全到 8 个。剩余：S1–S6 收尾后按 §8 出口判据复核一遍 | S1–S4 |

## 8. 验收与出口判据

1. 本文件**无**「未建模 / 显式拒绝 / 部分」行仍未标注去向（要么进切片，要么标「有意差异 + 触发条件」）。
2. 每个切片的 PR 附**真实书源证据**（源名 + 四段计数 + 正文哈希），格式照 `book-source.md` §10。
3. 「语料命中」列已由 `tool/spot_check/batch_probe.dart` 填满（L1 = 128 条合集；L2 = 全量合集只普查）。
4. 三处文档与代码一致（`book-source.md` §2 未建模字段、§3 矩阵状态列、§11 拒绝清单），由门禁 G1/G2 兜住。
5. 性能指标 P1–P6（`#36`）达标或明确登记为「已知热点」，且不因提速放宽任何行为。

## 9. 语料曝光（M27 填，先留空表）

| 能力 | L1 源数 / 次数 | L2 源数 / 次数 | 备注 |
|---|---|---|---|
| `jsLib` | 待 M27 | 待 M27 | 本仓已支持（S1），统计待 `batch_probe.dart` 补 |
| 密钥类 crypto / 字节族 | 4 源 / 6 处（`corpus_b` 128 条） | 29 源 / 85 处（`corpus_a` 504 条） | 本仓已支持（S3a）；数字为 2026-10-26 手工静态普查，待 `batch_probe.dart` 重算 |
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

---

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
| 裸 `//` 开头（XPath 省略标志） | **43** | 155 | 显式拒绝 → **最大语法缺口，S5b** |
| 嵌套提取段（matrix #30 形状，如 `class.a@css:.b`） | **22** | 125 | 显式拒绝 → **S5c** |
| `@xpath:` 带标志 | 0 | 0 | 语料里没人这么写（都写裸 `//`），随 S5b 一起做 |
| `:正则`（matrix #20） | 2 | 2 | 低（S5e，与 #30 同批或登记） |
| `@webJs`（matrix #22） | **0** | 0 | **数据支持「不做」**：维持具名拒绝 |
| `%%` 交叉合并 | 1 | 1 | 已支持 |
| `:eq/:gt/:lt` 伪类 | 5 | 11 | 已支持（改写成 `:nth-child`） |
| 列表尾部 `@js:` / `+` 前缀 / `<1,2,3>` / `@result` | 7 / 5 / 0 / 0 | 7 / 5 / 0 / 0 | S4 已交付（后两项语料为 0，属兼容性收尾） |

### 9.3 沙箱绑定（语料里出现、本仓尚未提供）

| 成员 | 源数 | 处数 | 去向 |
|---|---|---|---|
| `source.key` | 14 | 20 | 它就是 `bookSourceUrl`（上游 `getKey()`）→ **S5a** |
| `source.bookSourceUrl` | 10 | 148 | 源对象的字段 → **S5a** |
| `source.bookSourceComment` | 5 | 27 | 同上（自定义变量说明，脚本用 `eval()` 当代码跑）→ **S5a** |
| `source.put` / `source.get` | 4 / 3 | 11 / 3 | 上游的每源持久变量，本仓已有 `source.setVariable`/`getVariable` → **S5a 做别名** |
| `source.getLoginHeaderMap` / `removeLoginHeader` / `putLoginInfo(Map)` / `removeLoginInfo` | 2 / 2 / 2+1 / 1 | 7 / 4 / 3 / 1 | 登录态的其余入口 → **S5a**（`removeLoginHeader` 现在只有「不绑定」的登记） |
| `source.header` / `source.loginUrl` / `source.bookSourceName` | 2 / 2 / 1 | 2 / 2 / 1 | 源对象字段 → **S5a** |
| Rhino 互操作：`java.lang` / `java.util` / `java.io` / `java.security` / `java.net` | **13 / 10 / 4 / 3 / 1** | 21 / 17 / 5 / 6 / 2 | 真实写法是 `new Packages.java.lang.String(bytes,'UTF-8')`、`java.util.UUID.randomUUID()`、`java.util.Arrays.copyOfRange(raw,0,16)`、`new java.util.HashMap()`（给 `java.upLoginData`）→ **S5d：需要 ADR 决定「最小 shim」还是维持具名拒绝**（多数写法有一行等价替代） |
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
| **S5a** | `source` 对象补全（`key` / `bookSourceUrl` / `bookSourceName` / `bookSourceComment` / `header` / `loginUrl`）+ `source.put`/`get` 别名 + `getLoginHeaderMap` / `removeLoginHeader` / `putLoginInfo(Map)` / `removeLoginInfo` | 约 30 个源，改动最小 | S3b（已闭环） |
| **S5b** | XPath：裸 `//` 与 `@xpath:`（新依赖 + ADR） | **43 源 / 155 处**，剩余最大语法缺口 | ADR |
| **S5c** | matrix #30 嵌套提取段 | 22 源 / 125 处 | S4（已闭环） |
| **S5d** | Rhino 互操作最小 shim（`java.lang.String` / `java.util.UUID` / `Arrays` / `HashMap`）**或**维持拒绝（ADR 裁决） | 13+10 源 | ADR |
| **S5e** | `:正则`（matrix #20） | 2 源 → 可与 S5c 同批，或登记 | — |
| **S6b** | 文件型源（`downloadUrls` + type3 链路） | 11 源 / 7 个文件源 | S2 |
| **S6c** | 图片字节通道（`imageDecode` 2 源、`coverDecodeJs` 1 源）+ 阅读端从字节渲染 | 2 源 | 字节 job |
| **不做（有数据支撑）** | `ruleReview` / `eventListener` / `customButton` / `homepageModules` / `@webJs` / `imageStyle` 的 `left`/`right` | 全部 **0 源** | — |
