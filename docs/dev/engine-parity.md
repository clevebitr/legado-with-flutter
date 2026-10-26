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
| ⚠ `jsLib`（源内 JS 库，作为每个脚本的 prototype scope） | `BaseSource.kt:335-339`、`AnalyzeRule.kt:848`、`SharedJsScope.kt:23-60` | **未建模**（`BookSource` 无字段，`extra`），引擎不执行 → 依赖库函数的源每条规则 `js:error` | | **S1** |
| ⚠ `coverDecodeJs`（封面二次解密） | `ImageUtils.kt:66-69` | 未建模 | | S1 之后按需（M27 普查决定） |
| ⚠ `ruleReview`（段评九字段） | `rule/ReviewRule.kt:9-20` | 未建模 | | M27 后另立里程碑（要 UI） |
| ⚠ `bookUrlPattern`（搜索 URL 命中即按详情页解析；`bookList` 为空时回落详情页） | `BookList.kt:62-84`、`:100-110` | 未建模 → 单书站搜不到东西 | | **S2** |
| ⚠ `eventListener` / `callBackJs` / `customButton` / `homepageModules` | `BookSource.kt:104-112`、`SourceCallBack.kt:54/94/117` | 未建模（`callBackJs` 见 B4） | | S2 / 后续 |
| `enabledExplore` | `BookSource.kt:52` | `extra`，发现页仍会尝试 | | 有意差异（未提供单源发现开关 UI） |
| `enabledCookieJar`（单源 CookieJar） | `BaseSource.kt:56-58` | 无按源语义（Cookie 按域共享） | | 有意差异（ADR-0072 §决策 2） |
| `bookSourceComment` / `customOrder` / `weight` / `respondTime` / `lastUpdateTime` | `BookSource.kt:70-80` | 部分（排序字段已有，注释未建模） | | 不影响解析，低优先 |

## 3. B — 阶段字段与流程

### 3.1 `ruleContent`

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ⚠ `subContent`（副文；音频源写成章节变量 `lyric`） | `BookContent.kt:144-163` | **未建模** | | **S2** |
| ⚠ `title`（正文反取章节名 + `reviewImg`） | `BookContent.kt:165-190` | **未建模** | | **S2** |
| ⚠ `payAction`（付费章节解锁动作） | `ReadBookViewModel.kt:2623`、`MangaReaderActionRepository.kt:237` | **未建模**（配 `isPay` 缺失，VIP 付费章节无法解锁） | | **S2** |
| ⚠ `callBackJs`（事件回调） | `SourceCallBack.kt:54/94/117` | **未建模** | | S2（UI 侧另算） |
| `imageDecode`（图片字节解密） | `ContentRule.kt:21` | 显式拒绝（`fetch_manga_pages.dart:30-41`） | | **S6** |
| `imageStyle`（`full`/`single`/`left`/`right`/居中） | `ContentRule.kt:20` | 部分（只 `full`/`single`，ADR-0069 G5） | | **S6** |
| 正文 HTML 化（`formatKeepImg`：相对 `<img>` 补全、`<usehtml>` 保真） | `BookContent.kt:207-216`、`HtmlFormatter.kt:151-195` | **无**：正文原样落库，阅读端也不渲染 HTML/内联图 | | **S6** |
| 正文分页并发（多值 `nextContentUrl`，≤4） | `BookContent.kt:113-141` | 串行 | | **已知热点**（M26 R4） |
| 「下一页 == 下一章」提前停止 | `BookContent.kt:90-96` | 无 | | S2（低） |

### 3.2 `ruleToc`

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ⚠ `formatJs`（统一重写章节名，绑 `index`/`chapter`/`title`/`gInt`） | `BookChapterList.kt:141-163` | **未建模** | | **S2** |
| ⚠ `isVolume`（分卷标记；卷标题无 url 时用标题占位） | `BookChapterList.kt:240-259` | **未建模** → 卷标题被当普通章节 | | **S2** |
| ⚠ `isPay`（已购标记，与 `isVip` 共同决定「锁定」） | `BookChapterList.kt:229-268`、`TocScreen.kt:894` | **未建模**（`Chapter` 只有 `isVip`） | | **S2** |
| ⚠ `preUpdateJs`（更新检查前置脚本，可中止） | `WebBook.kt:305-313` | **未建模** | | **S2** |
| 目录去重（`LinkedHashSet`）与元数据保留（`wordCount`/`variable`/`reviewImg`） | `BookChapterList.kt:120-140`、`:275-295` | 不去重、不保留 | | **S2** |
| 目录翻页并发（多值 `nextTocUrl`） | `BookChapterList.kt:100-118` | 串行 | | **已知热点**（M26 R4） |

### 3.3 `ruleBookInfo` / 列表阶段

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ⚠ `downloadUrls`（文件型源，`bookSourceType=3`） | `BookInfo.kt:171-180` | **未建模** → 文件型源完全不可用 | | **S6** |
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
| ⚠ 列表规则**尾部** `@js:`（`class.list@tag.li@js:result`） | `AnalyzeRule.kt:439`（任一段是 JS 段即可） | **部分**：只支持「整条规则 = JS」与 `<js>` 分段链；尾部形态报 `unsupported:@js:list`（`:2658-2665`，测试 `rule_engine_test.dart:3256`） | | **S4** |
| ⚠ URL 页码列表 `<1,2,3>`（按页取第 n 个，超出取末值） | `AnalyzeUrl.kt:777`、`:203-213` | 无实现 | | **S4** |
| ⚠ URL 段链 `@result`（字面段引用上一段脚本产出） | `AnalyzeUrl.kt:157-176` | 无实现（规则体内用 `{{result}}`） | | **S4** |
| ⚠ GET query **全量**按 `charset` 编码 | `AnalyzeUrl.kt:268-273`、`:295-300` | 只编码 `{{key}}`（`url_template.dart`） | | **S4** |
| ⚠ `+` 正序前缀（`bookList` / `chapterList`） | `BookList.kt:73-75`、`BookChapterList.kt:43-45` | 只剥 `-`（`:2562-2564`）→ `parseFailed` | | **S4** |
| HTML 实体反转义（`unescape` 默认 true） | `AnalyzeRule.getString/getStringList` | 不做；`getString(rule, true)` 具名拒绝 | | 有意差异（ADR-0037 §后果） |
| `@css:` 的 jsoup 扩展伪类（`:containsOwn(a b)`、裸正则 `:matches(x)`） | jsoup `Selector` | cascadia `parseFailed`（响亮失败） | | 有意差异（矩阵 #12 注记） |
| 页面是 JSON 时规则自动进 JSON 模式 | `AnalyzeRule.SourceRule.init`（`isJSON`） | 不自动切（ADR-0047 §决策 6） | | 有意差异（实测无增益） |

## 5. D — JS 沙箱绑定面

对照 `JsExtensions.kt`（1220 行）+ `AnalyzeRule.kt:834-847` + `AnalyzeUrl.kt:365-376` + `BookChapterList.kt:145-149`。

| 能力 | 上游证据 | 本仓现状 | 语料命中 | 去向 |
|---|---|---|---|---|
| ⚠ 密钥类 crypto：`createSymmetricCrypto` / `aes*` / `des*` / `HMac*`、`base64DecodeToByteArray` / `hexDecodeToByteArray` / `hexEncodeToString` / `md5Encode16` | `JsExtensions.kt:586-666`、`:1216+`（`SymmetricCrypto`） | 全部具名拒绝（`quickjs_worker.dart` 的 `__javaRejectedNames`） | | **S3**（字节族需「受控句柄」设计） |
| ⚠ 全局绑定 `chapter` / `src` / `nextChapterUrl` / `fromBookInfo` / `infoMap` / `speakText` / `gInt`+`index`（`formatJs`） | `AnalyzeRule.kt:834-847`、`AnalyzeUrl.kt:365-376`、`BookChapterList.kt:145-149` | 只有 `baseUrl`/`result`/`page`/`source`/`book`/`key` | | **S3** |
| ⚠ `cache.*`（`CacheManager`） | `AnalyzeRule.kt:836` | 无 | | **S3** |
| ⚠ `source.getKey` / `getTag` / `getLoginHeader` / `putLoginHeader` / `login()` | `BaseSource.kt:80-140` | 部分（有 `name/url/group`、`getVariable`、`getLoginInfo*`） | | **S3** |
| `java.timeFormatUTC` / `htmlFormat` / `t2s` / `s2t` / `toNumChapter` / `refreshBookUrl` / `randomUUID` / `androidId` / `openUrl` / `getWebViewUA` / `toURL` / `webViewGetElements` / `ajaxAll` / `connect` | `JsExtensions.kt` 各节 | 具名拒绝 | | 按普查逐个决定（`timeFormatUTC`/`htmlFormat`/`t2s`/`s2t` 纯计算，优先） |
| 文件/压缩包族（`readFile` / `unzipFile` / `getZipStringContent` …）、Rhino Java 互操作（`Packages.*`） | `JsExtensions.kt:727-976` | 具名拒绝 | | 有意差异（沙箱禁忌，C-SRC-3） |
| 已对齐（对照用） | `java.ajax/post/head/getCookie/setContent/toast`、`cookie.*`、`source.getVariable`、`queryTTF`/`queryBase64TTF`/`replaceFont`、`startBrowser*`/`getVerificationCode`/`webView*`、`getString*`/`getElements` | 已落地（ADR-0068 / 0076） | | 已对齐 |

## 6. E — 非文本书源

| 类型 | 上游 | 本仓现状 | 去向 |
|---|---|---|---|
| 文本（0） | 完整四段 | 已对齐 | — |
| 音频（1） | `content` 取地址，`subContent` 作歌词 | 有 `fetch_audio_tracks`，**无歌词** | **S2** |
| 图片（2） | `content` 取图片列表 + `imageDecode` + `imageStyle` 全分支 | 有 `fetch_manga_pages`，`imageDecode` 拒绝、`imageStyle` 部分 | **S6** |
| 文件（3） | `ruleBookInfo.downloadUrls` + 批量下载 | 无 | **S6** |
| 视频（4） | 有视频播放链路 | 无 | **S6** |

---

## 7. 切片（顺序即依赖顺序）

| 片 | 内容 | 主要落点 | 依赖 |
|---|---|---|---|
| **S1** | `jsLib` | `core/js/*`（job 前跑库脚本 + 按 `sourceId`+hash 缓存）、`BookSource` 字段 | — |
| **S2** | 阶段字段族 + `bookUrlPattern` + 目录去重/元数据 | `BookSource`/`Chapter` 模型、`FetchContent`/`FetchToc`/`FetchBookInfo` | S1（同属字段建模，可并行） |
| **S3** | 密钥类 crypto + 绑注入面 | `core/js/js_bindings.dart`、`quickjs_worker.dart` | 语料普查（优先级） |
| **S4** | URL 方言五条 + 列表尾部 `@js:` | `url_rule.dart`、`rule_engine.dart` | — |
| **S5** | 矩阵 #20/#21/#22/#30 | `rule_engine.dart`（+ 依赖） | M27 普查定序 |
| **S6** | 非文本链路 + 正文 HTML 化 | `fetch_manga_pages`/新 usecase、`content_purifier`、阅读端 | S2 |
| **S7** | 文档与拒绝清单收敛 + 门禁 G1/G2 | `book-source.md` §2/§3/§11、`test/` | S1–S6 |

## 8. 验收与出口判据

1. 本文件**无**「未建模 / 显式拒绝 / 部分」行仍未标注去向（要么进切片，要么标「有意差异 + 触发条件」）。
2. 每个切片的 PR 附**真实书源证据**（源名 + 四段计数 + 正文哈希），格式照 `book-source.md` §10。
3. 「语料命中」列已由 `tool/spot_check/batch_probe.dart` 填满（L1 = 128 条合集；L2 = 全量合集只普查）。
4. 三处文档与代码一致（`book-source.md` §2 未建模字段、§3 矩阵状态列、§11 拒绝清单），由门禁 G1/G2 兜住。
5. 性能指标 P1–P6（`#36`）达标或明确登记为「已知热点」，且不因提速放宽任何行为。

## 9. 语料曝光（M27 填，先留空表）

| 能力 | L1 源数 / 次数 | L2 源数 / 次数 | 备注 |
|---|---|---|---|
| `jsLib` | | | |
| 密钥类 crypto | | | |
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
