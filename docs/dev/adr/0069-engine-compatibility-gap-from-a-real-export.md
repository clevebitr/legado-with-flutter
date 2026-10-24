# ADR-0069 用一份真实导出定位引擎与上游的语法差距（G1–G9）

- **状态：** Accepted（2026-10-24，用户裁决「把 G1–G5 + G7 + G8 全做完，G6 登记」）
- **日期：** 2026-10-24
- **关联：** ADR-0068（M21a 引擎兼容面）、ADR-0060（规则方言对齐）、ADR-0032（未知语法降级）、
  C-SRC-3、C-SRC-4、C-SRC-8、`docs/dev/book-source.md` §2/§4.3/§6/§11、`docs/dev/roadmap.md` §3.7

## 背景

用户给了一份「**在上游可用、在本仓不可用**」的导出（5 条 `bookSourceType: 2` 的图片源），
并指出本机有一份上游参考实现（`legado-upstream`）。本 ADR 把「哪条规则、什么构造、上游怎么
实现、本仓怎么落」逐条记录下来，避免以后再靠猜。

取证方法（可复现）：把那 5 条源逐条 `BookSource.fromLegadoJson` 导入，再把每个规则字段送进
`RuleEngine.extractFirst` / `extractAll` / `selectAll` 与 `renderUrl`，只区分「**语法被拒**」
（`unsupportedRule`）与「只是没命中」；每条结论都在上游源码里对到了实现点。

## 缺口清单（G1–G9）

| # | 缺口 | 命中本批哪条源 | 上游实现点 | 本轮处置 |
|---|---|---|---|---|
| **G1** | `java.encodeURI(str, charset)` 两参形态被拒（本仓只认一参 UTF-8） | 📷🔞美女图片网（`searchUrl` 用 GBK 编关键词） | `JsExtensions.kt:691-698`（`URLEncoder.encode(str, enc)`） | **已修**：`charsetBytes` 落到 `core/text/`，`java.encodeURI(str[, charset])` 两参 |
| **G2** | **URL 规则**里的 `{{非 JS 规则}}`（`{{$.x}}`）被拒 | 本批 5 条**都没有**踩到（`chapterUrl` 是值规则，本仓已支持） | `AnalyzeUrl` 用 `AnalyzeRule` 求值 `{{…}}` | **只登记**：真实影响面未取证，登记在 roadmap §3.7 |
| **G3** | 任意段末尾 `.N` 索引不识别（`#image_div img.0` 被当类选择器） | 📷🔞小姐姐写真（`coverUrl`） | `AnalyzeByJSoup.ElementsSingle`（`.`/`!` 都是索引） | **已修**：degraded 段末尾 `.N` / `.-N` 走同一套索引解析 |
| **G4** | 封面 / 图片地址上的 `,{…}` 选项被当正文（`c.jpg,{"headers":…}`） | 📷🔞美女图片网（`coverUrl`） | URL 选项（`AnalyzeUrl`） | **已修**：漫画页把选项并进请求头；封面地址裁掉选项 + warning |
| **G5** | `imageStyle` / `imageDecode` 未建模（落进 `extra`） | 📷🔞美图网（`imageStyle: full`、`imageDecode: ""`） | `ContentRule.kt:20-21` | **已修**：两字段建模；`imageDecode` 非空 → 显式 `unsupportedRule`；`imageStyle` 打通到阅读器（`single` 生效，对齐分支登记） |
| **G6** | `java.post/get/ajax` **同步**返回响应对象（`.body()`） | 📷🔞小姐姐写真（`content`） | `JsExtensions.kt:556-...`（Jsoup `Connection.Response`） | **只登记**：架构性差异（沙箱阻塞不了宿主），见下方「登记差异」 |
| **G7** | Java `List.size` 属性 | 📷🔞美女图片网（正文 JS 遍历 `java.getStringList(...)`） | Rhino 把 Kotlin `List` 映射成 JS 数组 + `size` | **已修**：prelude 给 `Array.prototype` 加 `size` getter（与既有 `toArray()` 垫片同族） |
| **G8** | 目录项 `chapterUrl` 为空时**跳过**该章 | 📷🔞美图网（单章图片书，`chapterUrl` 为空） | `BookChapterList.kt:246-258`（回落 `baseUrl`） | **已修**：回落到目录页地址 + warning |
| **G9** | 列表规则 `$.data[*].image` + 换行 `@js:` 的 `result` 形状待核对 | 🎨武芊漫画（`content`） | `AnalyzeRule.getStringList` 逐步求值 | **只登记**：需要该站真实响应体才能定论，触发 = 拿到响应样本 |

## 修完之后的语义（本 ADR 的唯一出处）

- **`java.encodeURI(str[, charset])`**：charset 缺失 / 空 / 未知都退到 UTF-8（上游未知标签抛错
  返回 `""`，本仓退 UTF-8 更有用）。空格一律 `+`，安全字符集与上游 `URLEncoder` 相同。
- **段末尾 `.N`**：只有「纯数字（可带负号）」才当索引；`div.item` / `.result-item` 仍是 CSS。
  `!N` 仍是排除，`.N` 是只取该位（与 `[N]` 同义，矩阵 #28）。
- **图片地址的 `,{…}`**：漫画页把 `headers` 并进该章的图片请求头（章节内通常同一套），地址本身
  只留 URL；封面地址**裁掉**选项并记 warning——封面加载器还带不了 header（登记在 §3.7）。
- **`imageDecode`**：非空即 `unsupportedRule`（`rulePath = contentRule.imageDecode`）。静默降级
  会把一堆加密字节当图片摆给用户，那是更坏的失败（ADR-0026 的「显式降级」口径）。
- **`imageStyle`**：`single` = 一图一屏（`BoxFit.contain` + 视口高），`full`/`centered` =
  整宽顺排；`left`/`right` 的对齐分支**未实现**（登记）。
- **目录项没有 URL**：回落到目录页地址，不再丢弃该章。

## 登记差异（不做，附重开条件）

| 项 | 为什么不做 | 重开触发条件 |
|---|---|---|
| **G6** `java.post/get/ajax/head/ajaxAll` 同步响应对象 | 沙箱（QuickJS 独立 isolate）不能阻塞等宿主：同步 HTTP 在本仓不可能实现。规则必须改成 `await http.post(...)`（ADR-0068 决策 5 的同一立场） | 出现「**只能**用同步响应对象、改写不了」的真实源；届时评估「预取 + 注入」而不是阻塞 |
| **G2** URL 规则里的 `{{$.x}}` / `{{class.x@text}}` | 本批 5 条源的实际路径（值规则）已支持；URL 规则里的非 JS 内层规则要先把 **scope** 传进 `renderUrl`，影响面未取证 | 语料统计显示有源在 `nextContentUrl` / `tocUrl` / `searchUrl` 里写非 JS 内层规则 |
| **G9** 列表 JSONPath + `@js:` 的 `result` 形状 | 需要🎨武芊漫画的真实响应体才能确认上游给的是列表还是字符串；猜一个会静默换错 | 拿到该站响应样本（或同类图片源） |
| 封面 / 图片的 **per-URL header** | 漫画页已并进请求头；**封面**加载器（`CoverImage`）还不带 header，需要把 header 一路存进书架 | 出现「封面必须带 Referer 才出图」的可复现源 |
| `imageStyle` 的 `left` / `right` / 居中分支 | 需要版式决策（自然尺寸 + 对齐），与本轮「先修兼容性」无关 | 图片源使用者反馈版式 |

## 影响

- `lib/core/text/charset_encoding.dart`（新）：`charsetBytes` 成为「文本按声明编码取字节」的唯一实现，
  `url_template` 的关键词编码与 `java.encodeURI` 共用它。
- `lib/core/js/quickjs_worker.dart`：`Array.prototype.size` getter、`java.encodeURI` 两参。
- `lib/core/js/js_bindings.dart`：`encodeUri` 请求携带 `charset`。
- `lib/features/book_source/domain/rule_engine/rule_engine.dart`：degraded 段的 `.N` 索引。
- `lib/features/book_source/domain/entities/book_source.dart`：`ContentRule.imageStyle` / `imageDecode`。
- `lib/features/book_source/domain/entities/manga_pages.dart` + `usecases/fetch_manga_pages.dart`：
  图片地址选项 → 请求头；`imageDecode` 拒绝；`imageStyle` 透传。
- `lib/features/reader/domain/entities/reading_page.dart` + `manga_reader_page.dart`：`MangaImageStyle`。
- `lib/features/book_source/domain/usecases/fetch_toc.dart`：空 `chapterUrl` 回落。
- `lib/features/book_source/domain/book_list_fields.dart` / `usecases/fetch_book_info.dart`：封面裁选项。
- `lib/features/book_source/domain/url_rule.dart`：`stripUnreadableUrlOptions` 更名 `stripUrlOptions`
  （同一个「切掉 `,{…}`」现在有两个正当用途）。
- 测试：`core/text/charset_encoding_test.dart`、`js_bindings_test.dart`（charset）、
  `rule_engine_test.dart`（dot index）、`fetch_manga_pages_test.dart`（选项/解码/版式）、
  `fetch_toc_test.dart`（回落）、`fetch_book_info_test.dart` / `search_books_test.dart`（封面）、
  `check_book_source_test.dart`（空搜索的另一条路径）、`manga_reader_page_test.dart`（`single`）、
  设备级 `js_bridge_test.dart`（`list.size`）。

## 后果

- 好的方面：4 条图片源的**语法级**拦路石（G1/G3/G4/G5/G7/G8）全部拆掉；`imageDecode` 与
  `imageStyle` 从「静默忽略」变成「显式支持或显式拒绝」。
- 代价：`java.encodeURI` 的未知 charset、封面选项被裁掉都会记 warning，但不会让整条源失败。
- 未做：G2 / G6 / G9 / 封面的 per-URL header / `imageStyle` 的对齐分支，全部登记在
  `docs/dev/roadmap.md` §3.7，并带上重开触发条件。

---

## 2026-10-24 增补：真实日志取证（G9 关闭 + 三个新缺口 G10–G12）

用户在设备上跑那 5 条源，日志给出了四类信号，逐条对到根因：

| 日志信号 | 根因 | 处置 |
|---|---|---|
| `JS rule failed: field=contentRule.content error=<String: 14 chars>` | 14 字符正是 `not a function`：`$.data[*].image` + `@js:result.split("\n")` 里，漫画链路用 `extractAll` 读，`result` 被绑成 **List**，`split` 不存在 | **G9 已修** |
| `Explore category rejected: … missing url (title=══ 推荐 ══)` | 真实 `exploreUrl` 脚本用「只有标题、没有地址」的条目做**分组标题**，上游保留成 `ExploreKind(title, "")`，本仓按坏条目丢了 | **G11 已修** |
| `Request failed for rule=ruleToc/ruleBookInfo/exploreUrl … <DioException: N chars, sha256=…>` | 两层：① 默认 UA 是 `flutter_reader`，一批站点在规则跑之前就 403；② 日志把 dio 异常脱敏成 `sha256`，看不到状态码，403 与超时长得一样 | **G10 已修**、日志可诊断性修好 |

### G9（关闭）：`ruleContent.content` 是**单值**读取，多匹配要用 `\n` 拼接

上游 `BookContent.kt:234` 对所有书型都调 `analyzeRule.getString(contentRule.content, unescape=false)`，
而 `AnalyzeRule.getString` 对多匹配是 `joinToString("\n")`。所以 `$.data[*].image` 后面接
`@js:result.split("\n")` 时，脚本拿到的是**字符串**。

本仓的漫画链路走的是「列表」读取（`extractAll`）——那是 ADR-0053 为「一条规则产出多张图」选的
形状，代价是与上游的单值语义不一致。修法：

- `RuleEngine.extractJoined`（= 上游 `getString`）：跑同一套管线，返回**全部匹配用 `\n` 拼接**的
  字符串；脚本段的 `result` 也改成拼接后的字符串（原来是 `values.first`，即「只给第一个匹配」）。
- `FetchMangaPages` 改用 `_pages.joined(...)`，再把结果按行切开（每行再走 `,{…}` 选项与 `<img>`
  解析）。`class.page@tag.img@src` 这类「列表规则」在拼好之后仍是 N 个地址，行为不变。

**这条改动同时把「单值字段的 `result`」对齐到上游**：`extractFirst` 的**返回值**仍是首个匹配
（matrix #8 的既有口径），但交给脚本的 `result` 现在是拼好的字符串。真实语料里
`result.split(...)` / `result.replace(...)` 的写法从此成立。

### G10（关闭）：默认 UA 对齐上游（桌面 Chrome）

上游 `FeatureSettingsRepositories.kt:157-162` 的默认 UA 是桌面 Chrome；
`AnalyzeUrl.getUserAgent()` 让源自己的 `header` 优先。本仓原来发 `flutter_reader`，一批站点
（这次的 `xiaojiejie.me`、`m.ku1373.cc`）在规则跑之前就 403。现在
`HttpPolicy.defaultUserAgent` 是同一形态的桌面 Chrome UA，源的 `header` 仍然覆盖它（C-NET-4）。

### G11（关闭）：`exploreUrl` 的**分组标题**（`url` 为空）必须保留

上游 `BookSourceExtensions.exploreKinds()` 把 JSON 数组直接映射成 `ExploreKind(title, url)`，
**不校验 url 非空**；语料就用「只有标题」的条目给 chip 分组。本仓原来按 `missing url` 丢弃，
于是 `══ 推荐 ══` 这些标题消失（日志里那串 warning 就是它）。现在：

- `ExploreCategory.url` 可空，`url == null` = 分组标题；`parseExploreString` / JSON 两条路径都保留；
- 发现页把标题画成**不可点的标签**，`openCategory` 遇到 `url == null` 直接返回（不发请求、
  不改状态）；`ExploreBooks` 防御性返回空列表。

### G12（关闭）：HTTP 失败日志必须能看出「为什么」

`DioHttpClient` 原来把 `describeError(error)` 记成 `<DioException: N chars, sha256=…>`——脱敏对
正文是对的，对**状态码**是灾难：403 / 超时 / DNS 在日志里完全一样。现在失败行带
`type=<DioExceptionType> status=<code>`，URL 仍走 `redactUrl`（关键词不外泄）。

### 仍未做（不变）

G2（URL 规则里的非 JS `{{…}}`）、G6（同步 `java.post` 响应对象）、封面的 per-URL header、
`imageStyle` 的 `left`/`right`/居中分支——触发条件见上文表格。
