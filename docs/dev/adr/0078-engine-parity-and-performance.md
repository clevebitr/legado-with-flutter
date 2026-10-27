# ADR-0078 引擎目标升级：与上游行为几乎一致 + 高性能实现（允许重构）

- **状态：** Accepted（2026-10-26，用户裁决：行为对齐上游 + 高性能；允许重构引擎内核）
- **日期：** 2026-10-26
- **关联：** C-SRC-1…C-SRC-9、C-NET-7、ADR-0014（分期）、ADR-0029（异步形态）、ADR-0032（未知类型退化）、
  ADR-0037（`java.*` 兼容面）、ADR-0047 / ADR-0068 / ADR-0069 / ADR-0076（逐轮补口）、ADR-0077（测试精简）；
  台账 `docs/dev/engine-parity.md`；里程碑 `PLAN.md` M25–M27（`DECISIONS.md` #35–#37）

## 背景

ADR-0014 把引擎的验收定在「真实语料可用」：矩阵 #1–#19、#25–#31 逐条落地，M12/M21a/M24 又补齐了
`<js>` 分段链、URL 后缀选项、WebView 验证、字体反爬与同步 `java.*` 重放。结果是**大多数公开书源能跑**，
但离「与上游行为几乎一致」还有系统性距离，而且缺口分布很不均匀：

- **规则语法**只剩 4 条（`:` 正则、`@xpath:`、`@webJs`、提取段嵌套规则），而**字段层**缺了整整一族
  （`ruleContent.subContent` / `title` / `payAction` / `callBackJs`、`ruleToc.formatJs` / `isVolume` /
  `isPay` / `preUpdateJs`、`ruleBookInfo.downloadUrls` / `relatedBooks`）；
- **书源级 `jsLib` 完全未建模**：上游把它当每个脚本的 prototype scope，本仓连字段都没有 ——
  依赖库函数的源每条规则都 `js:error`，而这条缺口此前**没有任何文档登记**；
- **JS 绑定面**的密钥类 crypto（AES/DES/HMAC + 字节数组）被具名拒绝，而真实语料里大量正文解密走这条路；
- **URL 方言**有三处缺口（页码列表 `<1,2,3>`、段链 `@result`、query 全量按 charset 编码）；
- **非文本书源**（文件/视频）没有链路，图片源的 `imageDecode` 显式拒绝。

同时，引擎是纯 Dart 实现，本身有可识别的性能热点：规则文本每次求值都重新解析、每个字段重新建
`RuleScope`、目录/正文翻页串行、每条规则一个 JS job 的固定开销。既然对齐工作必然大范围触及
`rule_engine.dart` / `page_fetch_service.dart`，把「更快」与「更像」放在同一批次做，比为对齐后再推翻一次
更省。

## 决策

### 决策 1 目标：从「可用」升级为「几乎一致」，判据可复核

对齐的判据不是「我觉得像」，而是三条可核查的事实：

1. `docs/dev/engine-parity.md` 里**没有**未标注去向的「未建模 / 显式拒绝 / 部分」行；
2. 每一处与上游不同的行为，三选一登记 —— ① 修掉；② 「有意的差异 + 触发条件」；③ 「已知热点」（性能，归 M26）；
3. 语料回归（L1 = 128 条合集逐源归因，L2 = 全量合集只普查）的失败都能归因到网络 / 站点改版 / **已登记**的
   未实现能力，不存在「不知道为什么失败」。

### 决策 2 缺口清单的唯一出处是 `engine-parity.md`

`book-source.md` 只拥有**规范**（矩阵、字段映射、失败语义、JS 白名单），`roadmap.md` 只拥有**顺序与验收**，
`PLAN.md` 只拥有**里程碑状态**。缺口清单与语料命中数只写在 `engine-parity.md`，其他文档一律回链。
这与 ADR-0012 的 SSOT 一致，也避免出现本轮发现的那种「代码拒绝了、文档说支持」的漂移。

### 决策 3 允许重构引擎内核，但语义与红线不动

允许：规则编译结果缓存（`_parse` / `_check` 产物按 (规则文本, hasExtraction) 复用）、`FetchedPage` 级共享
`RuleScope`、条目批量提取复用、目录/正文翻页并发（上限沿用 `book-source.md` §8）、JS 脚本编译缓存。

不动：`ParseResult` / `ParseFailureKind` 契约、C-SRC-4（禁止静默忽略）、C-SRC-8（`rulePath` 可定位）、
JS 白名单与配额数值、书源并发与限速合成顺序、C-NET-7（不得整体读入大文件）、无 `dynamic` / `print` / `!`、
生成物不手改。**性能不得以放宽行为为代价**：行为测试与基准冲突时以行为为准 —— 先确认用例写的是上游语义，
再改实现；确实要放宽行为必须另开 ADR。

### 决策 4 性能指标先定数，再优化

P1 单章（≤200KB HTML，3 段规则）解析→提取→`replaceRegex` ≤ 40 ms；P2 千章目录 ≤ 300 ms 且近似线性；
P3 同一规则一次会话只编译一次（命中率 ≥ 95%）；P4 一页只 parse 一次；P5 JS job 固定开销 ≤ 3 ms；
P6 单章峰值增量 ≤ 8 MB、千章目录 ≤ 32 MB。基准脚本落 `tool/bench/`（不进 CI，与 `tool/spot_check/` 同模式），
每张重构 PR 附前后数字；数值只在实测后收紧，放宽需新 ADR。

### 决策 5 文档与代码的一致性由门禁兜住

新增两条用例（只加不删）：G1 把 `book-source.md` §11 的拒绝名单与 `quickjs_worker.dart` 的
`__javaRejectedNames` 对照，两侧不一致即失败；G2 矩阵「已确认」行按表驱动查漏。理由：本轮发现的
`<js>` 与列表 `@js:` 两处矛盾，都是「文档改了一半、代码改了一半」。

### 决策 6 分期：先对齐、再提速、最后以语料收口

M25（对齐，`#35`）→ M26（性能，`#36`）→ M27（语料回归与台账清零，`#37`）。切片内部允许交错
（例如 S1 `jsLib` 与 R5 JS 编译缓存天然同批），但**每片独立过全部门禁**，且 S7（文档收敛）必须最后做，
否则台账会再次与代码脱节。

## 后果

**正面**：目标可复核；缺口有唯一清单与语料数字，排序不再拍脑袋；性能与行为在同一套测试下演进；
`jsLib` / `isPay` / `subContent` 这类「静默不生效」的字段第一次被登记。

**负面 / 风险**：

- `@xpath:`（#21）与 `:正则`（#20）各要新增能力面（依赖 / 正则模式），属 ADR-0014 曾要求「先开 ADR」的两条，
  落地时按本条 ADR 的决策 1 逐个补 ADR 到 `docs/dev/adr/`，不在这里一次性批发。
- 密钥类 crypto 要用「受控句柄」重做字节族（Dart 没有 Rhino 的 `ByteArray`），这是一次跨 `core/js` 的接口改动，
  风险集中在沙箱边界；失败时退路是继续具名拒绝（已登记，不算回归）。
- 非文本书源（文件/视频）体量可能吞掉整个里程碑，按 M27 普查结果切出去另立里程碑，不在 M25 内硬塞。
- 性能重构会动 `rule_engine.dart` 的既有结构，测试精简（ADR-0077）后的表驱动用例是唯一保护网，
  因此 M26 开工前必须先把 S7 的 G2 落地。

## 被否的备选

| 备选 | 否决理由 |
|---|---|
| 维持「够用」不追对齐 | 与用户目标冲突；且 `jsLib` 这类缺口会让整源静默失效，用户无法判断是站点坏了还是引擎不支持 |
| 一次性重写引擎 | 会丢掉现有 270+ 条规则引擎用例与四段真实语料回归资产，风险不可控 |
| 逐行移植上游 Kotlin | 上游依赖 Rhino 类型系统、jsoup/jayway 方言与 Android WebView 行为，逐行移植会把 Android 依赖带进来，违反 C-PLT 与依赖白名单 |

## 实现注记（2026-10-26，S1 `jsLib` 落地）

决策 2/3/6 在切片 S1 上的落地形态（行为面归 `book-source.md` §6，台账状态归 `engine-parity.md` A1）：

1. **解析放在引擎、执行放在 worker。** worker 是 isolate 且不能取页，所以 `JsLibStore`（`core/js/js_lib.dart`）
   先在宿主侧把 `jsLib` 变成一段可运行的文本，再由 `RuleEngine` 随 job 下发（`JsJob.jsLib`）。
   这与「`parse.*` 在宿主、求值在 worker」是同一条分层。
2. **两种形态都照抄上游。** 纯 JS 原样用；JSON 对象只下载 `http(s)` 开头的值、按对象序拼接（非 URL 值忽略）。
   缓存键是 `jsLib` **原文**、上限 16（与上游 `LruCache` 同数）、失败不缓存、同键单飞——一页二十个 `@js:`
   字段只解析一次。
3. **作用域用「同一函数里的两次 eval」兑现。** QuickJS 没有 Rhino 的 prototype 链，所以 worker 的前奏多了
   `__runRuleWithLib(lib, rule)`：先 `eval(lib)` 再 `eval(rule)`，两次都在该函数的变量环境里 —— 库的
   `var` / `function` 对规则可见，又都不会漏到 `globalThis`（上游用 `preventExtensions` 达到同一效果）。
   代价是库顶层的 `let` / `const` 对规则不可见（它们属于第一次 eval 的词法环境），而 Rhino 是 ES5 本来也不认。
4. **`jsLib` 是行为字段**：进 `BookSource`、进 payload 往返、进书源指纹（库变了就是不同的源）。
5. **失败可归因。** 下载失败 → `ParseFailure(kind, rulePath: '<field>:js:lib')`；库自身抛错 → worker 在信封里
   带 `libError`，桥同样折成 `js:lib`。规则自己的错仍是 `js:error`。三者混在一起会让人以为是站点变了。
6. **不新增依赖、不动配额。** 库脚本与规则共用同一个 job 的 5 s / 32 MB / 20 调用额度（ADR-0030），
   没有为库单独开预算；重放层（ADR-0076）对它同样生效——库里的 `java.ajax` 也会触发整条 job 重跑。

验证：`test/core/js/js_lib_test.dart`（11 例：两形态、非 URL 值、坏 JSON、下载失败、无 HTTP 端口、单飞、
LRU、失败重试）、`rule_engine_test`（job 携带解析后的库 + 解析失败即规则失败且不执行 job）、
`js_bridge_lib` 相关 2 例（job 透传、`libError` → `js:lib`），以及真引擎探针 4 条（库函数可用、库抛错
归因、库里同步取页触发整条重放、无库时上一条库不泄漏）在 **Windows 与 Android 模拟器**双端全绿。

## 实现注记（2026-10-26，S2 第一半：目录字段族 + `bookUrlPattern`）

决策 1/6 在 S2 上的落地形态（行为面归 `book-source.md` §4.1 / §4.1b / §6，台账状态归
`engine-parity.md` 3.1–3.3）：

1. **`formatJs` 是「一条脚本跑 N 章、一个作用域」，所以它是一个 job。** 逐章各开一个 job 会丢掉
   `gInt` 的跨章累积（上游把 `gInt` 只初始化一次），也会把千章目录变成千次 worker 往返。worker 的
   前奏因此多了一个运行器 `__formatTitles(lib, script, chapters)`：同一函数作用域里 `for` 循环 +
   `eval`，`index` / `chapter` / `title` 每轮重绑、`gInt` 自然累积；某章抛错按 `null` 交回（保留原
   标题），与上游 `runCatching(...).onFailure` 同义。库脚本（S1）在这个作用域里同样可见。
2. **`preUpdateJs` 在 `walk` 之前跑，失败即失败**（上游 `runPreUpdateJs(...).getOrThrow()`）；本仓
   连第一个请求都不发，`FetchToc` 的两个失败分支分别对应「脚本坏了」与「页面取不到」。
3. **卷占位与无名条目**：`isVolume` 且无 URL → `title + index`（上游连分隔符都没有，照抄）；名字读不
   出来的条目整条丢弃——这同时推翻了 ADR-0026 时代「名字降级为空、条目保留」的旧行为，因为上游的
   `if (title.isNotEmpty)` 是条目**存在**的条件，而 ADR-0026 管的是**字段**可否降级。
4. **`bookUrlPattern` 复用 `ruleBookInfo` 的读取器**（`FetchBookInfo.readFromPage`），而不是在搜索侧再
   写一份字段解析：同一页、同一套规则、同一个 scope，两个阶段不可能读出不同的书。
5. **行为变化（有意）**：「搜索页一条都没命中」从 `parseFailed` 变成回落详情页 → 仍无书则**空结果**。
   上游本来如此（`BookList.kt:100-110`），但这条变化影响了书源校验的语义，所以校验侧补了
   `emptyRulePath`：空结果仍判「搜索失效」，只是 `rulePath` 指回**列表规则**而不是 `searchUrl`。
6. **不做的两件事会写在台账里**：`subContent` / `title` 的执行要 `FetchContent` 返回 `ChapterContent`
   （正文 + 副文 + 改名 + reviewImg + 音频歌词），那是 S2 的第二半；`payAction` / `callBackJs` /
   `eventListener` 需要付费解锁 UI 与读者事件面，登记为有意差异。

验证：`fetch_toc_test`（新增 8 例：isPay/wordCount、卷占位、无名丢弃、去重、formatJs 单 job、formatJs
失败、preUpdateJs 顺序、preUpdateJs 失败不发请求）、`search_books_test`（新增 4 例：pattern 命中、空
列表回落、pattern 不匹配、坏正则 warning）、真引擎探针 3 条（`index`/`gInt` 跨章、某章抛错保留原名、
formatJs 里可见 `jsLib`）在 **Windows 与 Android 模拟器**双端全绿。

## 实现注记（2026-10-26，S2 第二半：`subContent` / `title` 与 `ChapterContent`）

1. **正文阶段换返回形状，而不是再串一个端口。** `FetchContent.execute` 现在答 `ChapterContent`
   （`body` / `title` / `reviewImg` / `lyric`）：副文、正文页标题、歌词都是**同一次读取**的产物，
   分成多个返回值会让上层再读一遍页面。阅读器端口保持 `String`，装配根取 `.body` —— 阅读端要不要
   显示改名与歌词是另一件事（已登记），不该为此把两边的类型绑在一起。
2. **顺序照抄上游**：`content` → `subContent` → `title` → `replaceRegex`。`replaceRegex` 的文档语义
   是「对**拼接后**的整章正文应用」，所以副文必须先并进去；`title` 必须读**第一页**的 scope，而不是
   替换后的文本。
3. **副文是地址时取那一页的正文原文**（上游 `AnalyzeUrl(...).body`）。为此 `PageFetchService` 多了
   `plainBody`：走同一个 `fetchRule`（预算 / header / 登录拦截都在），但只回文本、不建 scope。
   取不到只记 warning —— 副文缺了正文仍然可读，这与「正文缺页整章失败」不是一回事。
4. **`reviewImg` 用「最后一个 media URL」切分**，并把标题里残留的标签剔掉。上游的
   `(.*)((?:data|https?):[\s\S]+)$` 在 `@html` 取值下会把 `<div id=…>` 甚至半个 `<img src="` 当成
   标题，那不是章节名；这处差异记进 `book-source.md` §4.1。
5. **缓存按整个结果存，但只带额外信息时才换形状**：纯正文仍写纯文本（旧形状、零迁移、调试页读到的
   还是正文），有标题/歌词时写一行带版本号的 JSON；读不懂就按正文处理（丢一个缓存条目的代价是重读）。
6. **不做的事登记在台账**：`payAction` 要付费解锁 UI、`callBackJs`/`eventListener` 要读者事件面；
   阅读端采用 `title` / `lyric` 需要阅读器与音频面板的改动，也单独登记。

验证：`fetch_content_test` 新增 9 例（文本副文追加、音频歌词、副文取页、副文页失败仍给正文、标题改名 +
reviewImg、只有图时保留目录名、`replaceRegex` 看得到副文、二次读命中仍给标题/歌词）与全量
`flutter test` 2385 例全过。

## 实现注记（2026-10-26，S3a：密钥类 crypto 与字节族）

决策 1/6 在 S3a 上的落地形态（行为面归 `book-source.md` §6「字节与密钥族」与 §11，台账状态归
`engine-parity.md` §5 D1）：

1. **`byte[]` 用 JS `Uint8Array` 表达，而不是句柄。** 语料对字节数组的实际用法是
   `Array.from(bytes).slice(8, -16)`（阅文系解密链）与 `bytes.length`，句柄会让这两种写法全部失效；
   `flutter_qjs_next` 的桥原生支持 `Uint8List ↔ Uint8Array`（`_typedDataToJs` / `jsGetArrayBuffer`），
   所以字节数组过桥是**一次 memcpy**，不是「JSON 数字数组」。代价：脚本把字节数组直接当返回值时，
   `JSON.stringify` 看到的是对象——这一条写进 `book-source.md` §6。
2. **`SymmetricCrypto` 用句柄。** 密码器是宿主侧状态（transformation + key + iv），塞进脚本既不可能
   （QuickJS 没有 Java 互操作）也没必要；沿用 `JsFontRegistry` 的契约：`{__symmetric: true, id}`、
   每个 job 清表、id 不复用。九个方法与上游 `SymmetricCryptoAndroid` 一一对应，`setIv` 返回自身。
3. **transformation / 密钥的规范化照抄 `SymmetricCryptoAndroid.normalizedKey`**：无 `/` 补
   `/ECB/PKCS5Padding`；DES > 8 截 8、DESede > 24 截 24；`key == null` 用随机密钥。**单 DES 用
   `DESede(K1=K2=K3)` 兑现**——pointycastle 4 只带三倍引擎，而三联同键在数学上就是单 DES（已用
   `openssl enc -des-cbc` 与 `-des-ede3-cbc` 两种密码器互验同一向量）。`NoPadding` 要求整块，否则按
   Java 的 `IllegalBlockSizeException` 失败，不补零。
4. **失败必须可读。** 字节/句柄族的失败原因（密钥长度、未知 transformation、NoPadding 长度、过期句柄）
   都通过 `{__error: message}` 回到 JS 并 `throw new Error(message)`；不能退化成
   `undefined is not a function`，否则调试一条加密源无从下手（ADR-0037 §决策 5 的同一立场）。
5. **通道与配额。** 新族与老的四个 `crypto.*` 动词共用 `crypto` 绑定（一个解码器、一套测试），载荷是
   **对象**而不是 JSON 字符串（字节要原样过桥）；全部在 worker 的 isolate 内完成，不联网、不计入
   `http.*` / `parse.*` 的单规则 20 次额度，也不受单源并发/限速影响。
6. **新增依赖 `pointycastle ^4.0.0`（MIT，纯 Dart）。** 这与 2026-10-25「备份不引入密码学依赖」的结论
   并不冲突：备份只需 `archive` 自带的 WinZip AES，而这里要 AES/DES/DESede × ECB/CBC × PKCS5，
   手写的正确性风险远大于一个 MIT 依赖（`NOTICE.md` §5 已记两条结论并存）。许可证复扫
   `dart run tool/scan_licenses.dart`：202 包，Risky items: none。
7. **有意差异（登记，不假装对齐）**：`aesEncodeToString` 上游实现是 `decryptStr`（历史 bug），本仓按
   名字的意图加密；`base64DecodeToByteArray(str, flags)` 收 `flags` 但不按位分支（上游两个重载最终同路）；
   CFB/OFB/CTR/GCM、非对称 `createAsymmetricCrypto`、签名 `createSign` 仍具名拒绝，重新评审的触发条件
   写在 `book-source.md` §11。

验证：`test/core/js/js_crypto_test.dart` 49 例（AES-CBC/ECB、单 DES、DESede、NoPadding、密钥截断与
随机密钥、无 IV、错误密钥长度、未知模式/填充、hex/base64 宽容解码与边界、digest/HMAC 已知向量、句柄
过期与 LRU 淘汰、setIv、字节数组与普通数组两种操作数），两个新/改文件的行覆盖率均为 100%；全量
`flutter test` **2434 例全过**，`check_coverage` exit 0（core 99.19 / domain 98.67 / data 95.65），
`build_runner build` 后生成物无漂移。真引擎探针新增 7 条（AES 句柄往返、`Uint8Array` 的
`length`/`Array.from`/`bytesToStr`、语料式的 hex 密钥解密、`jsLib` + base64 密钥解密、`@Deprecated`
的 `aes*` 族、算法名错误可读、HMAC/digest/md5Encode16）：**56 例在 Windows 与 Android 模拟器双端全绿**。

## 实现注记（2026-10-26，S3b 第一组：纯计算族 + cache.*）

用户裁决（2026-10-26）：S3b **一次做完**（不复用 S3a 的「切一半」做法），`t2s`/`s2t` 两张表都做，
`cache.*` 只做内存层。本注记记录第一组（纯计算 + cache），绑注入面与平台族见后续注记。

1. **码表是数据资产，不是依赖。** 上游走 `quick-chinese-transfer`，其 pom 无 `<licenses>`、仓库无
   LICENSE → 按 C-DEP-7 不能搬。改用 **OpenCC（Apache-2.0）** 的四个字典生成 `assets/zh/t2s.txt`
   （3 573 项 / 33 KB）与 `s2t.txt`（42 430 项 / 842 KB），生成规则、输入与输出 sha256 全在
   `assets/zh/README.md`，登记在 `NOTICE.md` §5。转换器是 40 行的最长匹配（`zh_converter.dart`），
   与上游的 trie 实现等价但更小；差异是**没有**上游 `fixT2sDict()` 的港台排除词表。
2. **资产怎么进 worker。** 后台 isolate 读不到 Flutter 资产（`rootBundle` 需要主 isolate，或根 isolate
   的 token + `BackgroundIsolateBinaryMessenger`），所以码表在 `launchQuickJsWorker` 里于主 isolate 读好、
   随 bootstrap 一次性交过去；**解析**才懒（`ZhTables.t2s(needed:)`），842 KB 的表只对真正调用
   `java.s2t` 的源付出建表成本。这一取舍避免了两件事：给每个 job 塞 1 MB、以及为读资产把 worker
   绑到 isolate token 的可用性上。
3. **`cache.*` 只做内存。** 语义照上游 `CacheManager`（容量、单值长度上限、`saveTime` 秒级 TTL、
   `putMemory/getFromMemory/deleteMemory` 与持久层的同名方法在内存层汇合），但**不落盘**：本仓没有
   `Cache` 表，也不为它升 schema。差异与触发条件写在 `book-source.md` §6。
4. **HTML 格式化是逐条语义移植**，不是「删标签」：块级标签换段落、`<img>` 换成占位符保住、其余标签
   删掉、实体归一、段首两个全角空格。两个实现细节值得记：① 拿不到 `src` 的 `<img>` **整条丢弃**
   （上游没有占位符，占位符会让它多留一个段落分隔）；② 属性值用**手写扫描器**读，因为语料的
   `src` 里就带着 `,{"headers":{…}}`，正则会在内层引号处截断。
5. **失败必须可读**：`{__error}` → `throw new Error(message)`（与 S3a 同一契约），所以
   「码表没加载」「时间戳不是数字」都能在 `js:error` 的 message 里看到，而不是 `undefined`。

验证：`test/core/js/js_helpers_test.dart` 22 例、`js_cache_test.dart` 10 例、`zh_converter_test.dart`
7 例（含 OpenCC 表的短语优先、CRLF、未知字符直通），真引擎探针新增 5 条（纯计算族一次跑完、
`java.t2s` / `java.s2t` 走真实资产、`cache` 跨 job、`getWebViewUA`）；全量门禁见下一轮提交说明。

## 实现注记（2026-10-26，S3b 第二组：`source.*` 簇与登录头）

用户裁决（2026-10-26）：本轮只做 S3b 的 `source.*` 簇；登录头落 **`book_sources.login_header` 新列**
（v13，与 v11 的 `loginInfo` 同构）；规则内 `source.login()` **具名拒绝**并登记差异。全局绑定与平台族
（`chapter`/`src`/`nextChapterUrl`/`fromBookInfo`/`infoMap`/`speakText`、`androidId`/`openUrl`/`connect`/
`ajaxAll`）留下一段。

1. **登录头由桥统一注入，而不是各调用点传参。** 上游的 `source` 绑定就是源对象本身，登录头在
   `BaseSource` 里、与哪个阶段无关；本仓若把它做成 `JsJob` 的字段，就得在 RuleEngine、`SignIn`、
   `ResolveLoginForm` 三处都记得传。改成 **桥在发 job 前把快照塞进信封**（`{'type':'evaluate', 'job':…,
   'loginHeader':…}`）后，「每个 job 都看得到」是结构保证，构造点一个都不用改——`sourceVariables` 走的是
   另一条路（引擎塞进 job），这是刻意的不对称：变量属于规则，登录头属于源。
2. **写回的时机是「规则写过」，不是「job 结束」。** `putLoginHeader` 之后登录脚本往往立刻取下一页，
   而上游写入立即生效；所以桥在结果信封里看到 `loginHeader` 键就当即写穿 store，并把其中的 `Cookie`
   并进 Cookie 宗。读不触发写：信封里没有这个键，就不会有数据库写入。
3. **`Cookie` 必须并进宗，不能只存头。** 我们的 `_CookieInterceptor` 用宗里的值盖掉请求头里的
   `Cookie`，所以只存登录头会在「宗里还有别的 cookie」时把登录 cookie 丢掉（上游 `putLoginHeader` 里
   那句 `CookieStore.replaceCookie(getKey(), cookie)` 正是为此）。`CookieManager` 因此多了一个
   `mergeCookieHeader(url, header)`：`StoredCookie` 的 `domain` 取源 URL 的 host、`path = /`、
   **不标 secure**（上游的宗没有这个属性，且源可能 https 登录、http 取章节）、空值跳过而不是当删除
   （那是 `Set-Cookie` 的语义）。
4. **按键是 URL，不是行。** `book_sources` 的身份是 `(url, fingerprint)`，而运行中的规则只有 URL；上游
   的缓存键就是 `loginHeader_<bookSourceUrl>`。所以读走「最新一条有值的行」、写走「这个 URL 的所有行」，
   同 URL 的两条导入因此不会一半登录一半没登录。备份恢复多一条按 id 写的方法（`writeLoginHeader`），
   与 `writeLoginInfo` 同形。
5. **合并顺序与粒度。** `headersOf` 里「源的 `header`（规则形态先求值）→ 登录头」，与上游
   `getHeaderMap(..., hasLoginHeader = true)` 同序；合并发生在**每个阶段取 header 表**时，不是
   每个请求 —— 同一阶段内有多个请求、且脚本中途写了登录头时，从下一个阶段起生效（登记在
   `book-source.md` §2）。
6. **规则内 `source.login()` 具名拒绝**：它要在同一个 worker 里再跑一段脚本，而 worker 正在执行当前
   job（重入会死锁）；登录页的 `SignIn` 跑的是**同一段** `loginUrl` 脚本，所以能力没有丢。
   `source.removeLoginHeader()` 不绑定（上游没标 `@JavascriptInterface`，本仓也没有登出入口）。
7. **迁移步骤两头都判。** `if (from < 13 && to >= 13)`：drift 的迁移测试以「目标版本」为参数跑到中间
   版本，只判 `from` 会把新列加进 v12 及更早的库，比对 schema 时多出一列。同批把迁移测试的目标版本
   统一到最新（`createTable` 用的是**当前**表定义，from-scratch 路径必然带最新列）。

验证：`test/core/js/source_login_header_test.dart` 15 例（store 的播种/写穿/失败降级、Cookie 提取）、
`js_bindings_test` 新增 6 例（登录头读写与错误）、`js_bridge_test` 新增 5 例（信封注入、写回、Cookie 合并、
畸形值只记 warning）、`page_fetch_service_test` 新增 3 例（合并顺序、无值、坏 JSON）、
`book_source_dao_test`/`source_login_header_dao_repository_test` 6 例（按 URL 读写、备份字段、刷新 payload
不覆盖）、`cookie_manager_test`/`persistent_cookie_manager_test` 6 例、迁移测试补 v12→v13；全量
`flutter test` **2530 例全过**，`check_coverage` exit 0（core 98.89 / domain 98.66 / data 95.68），
`build_runner build` 后生成物无漂移。真引擎探针新增 4 条（`getKey`/`getTag`、无值答 `null`、写入跨 job
并合并 Cookie、`source.login()` 落到 `js:error`）：**65 例在 Windows 与 Android 模拟器双端全绿**；
`integration_test/on_disk_database_test.dart` 6 例在 Windows 全绿（v13 建库路径）。

## 实现注记（2026-10-26，S3b 第三组：全局绑定 D2 + 平台族）

用户裁决（2026-10-26）：这一轮把 S3b 收尾——**两块都做**（D2 全局绑定 + 平台族），`java.openUrl` 引
`url_launcher` 并自己做确认弹窗，`infoMap` 一并实现；`speakText` / `speakSpeed` 只能由上游的 **HttpTTS
源**（另一张源表 + 自己的朗读规则）提供，本仓只有系统 TTS，因此**不绑定**并登记为有意差异（触发 = 引入
HttpTTS 朗读引擎）。

1. **阶段上下文只有一个模板。** `src` / `chapter` / `nextChapterUrl` / `fromBookInfo` 都是「这一阶段发生
   的事」，所以它们住在 `JsPageContext`，由 `forPage` 原样带到每一页（只换 URL / 页码 / 请求头 / 正文）。
   造 job 的两个地方（`evaluateJs`、`_runScript`）因此只多了一组 `context.*` 透传；翻页的第 2 页与第 1 页
   看到的东西一样，这是 `walk` 改调 `fetch(context: …)` 换来的。
2. **`src` 由页面自己填。** `_pageOf` 拿到解码后的正文时才建 context，所以 `src` 在整页规则、元素级规则
   与 `loginCheckJs` 上都是同一份；`java.setContent` 之后同一 job 内不变（上游每次 `evalJS` 重新绑
   `content`，等价）。
3. **`chapter` 的变量落规则变量表。** 上游 `chapter.putVariable` 写章自己的 map；本仓与 `book` 同一口径
   （`__sandboxChapter` 的 get/put 走 `java.get/put`），差异登记在 `book-source.md` §6。阅读端为此把
   `isVip` / `isPay` / `isVolume` / `updateTime` 带进了 `ReadingChapter`（它原本「只留标题与地址」是为了
   C-ARCH-2 的最小化；内容阶段的 `chapter` 绑定需要这几个值），`nextChapterUrl` 由 `readerContent` 从目录里
   取紧邻的下一条。
4. **`infoMap` 是「键是源、值是表」的内存 store。** 上游给规则的是同一个 `InfoMap` 对象（缓存键
   `infoMap_<url>`，`save()` 才落 `CacheManager`）。本仓把它做成 `SourceInfoMapStore`（按源的 LRU，32 个源）：
   桥把快照塞进信封，worker 在 job 结束时**再求值一次**把 `JSON.stringify(infoMap)` 读回来（规则可能
   await、也可能抛错，两种情况下这张表都得带回宿主），桥合并进 store。`save()` / `saveNow()` 保留为空操作
   ——本仓没有 `Cache` 表，值本来就在会话里；差异与触发条件写在 `book-source.md` §6。
5. **`connect` 吞失败、`ajaxAll` 不吞。** 这是上游的现成语义（`runCatching` vs `mapAsync`），不是我们的
   取舍：`connect` 失败时答一个 `code() == 0`、正文写着 `connect failed (field): kind` 的响应（差异：
   上游塞的是 Java 堆栈），`ajaxAll` 任一页失败即整次调用抛错。两者都走重放层，`ajaxAll` 的缓存键带整张
   地址表；`skipRateLimit` 收下但**不绕过**单源预算（C-NET-6）。
6. **`androidId` 是「首启生成 + 持久化」的 UUID。** 上游用 `Settings.Secure.ANDROID_ID`；本仓没有这个标识，
   在 `main()` 里 hydrate（与 Cookie 宗同一时点，ADR-0068 §决策 4）并写进轻量开关。桥把值补进 job 载荷
   （与登录头同理：这是主机事实，不是 job 的产物）。差异：格式不同，依赖 Android 格式的规则不适用。
7. **`openUrl` 是唯一需要新依赖的绑定。** 上游先起一个确认页再开浏览器（`JsExtensions.kt:1162-1185`）；
   本仓用 `core/platform/external_url_opener.dart` 端口 + 装配根的确认弹窗（`appNavigatorKey` 拿到
   `BuildContext`），最后一步才交给 `url_launcher`（BSD-3-Clause）。`core/` 依旧不认识 widget，`url_launcher`
   只出现在 `app.dart` 的实现里；许可证复扫 210 包 Risky none（`NOTICE.md` §5）。

验证：`test/core/js/source_info_map_test.dart` 7 例、`test/core/platform/install_id_test.dart` 6 例、
`js_sync_call_test` 新增 3 例（`connect` / `ajaxAll` 的解码与缓存键）、`js_bindings_test` 新增 4 例
（`openUrl` 信封）、`js_bridge_test` 新增 11 例（安装 id 注入、`infoMap` 快照/回写/坏值、
`connect` 成功与失败、`ajaxAll` 全成/一败、`openUrl` 两例）、`page_fetch_service_test` 新增 2 例
（`src` 与阶段上下文的传播）、`fetch_content_test`/`fetch_book_info_test` 各 1 例；全量 `flutter test`
**2565 例全过**，`check_coverage` exit 0，`build_runner` 后生成物无漂移。真引擎探针新增 5 条（阶段绑定一次
跑完、`infoMap` 跨 job、`connect`+`ajaxAll`、`openUrl` 到端口、`androidId`）：**70 例在 Windows 与 Android
模拟器双端全绿**。

## 实现注记（2026-10-26，S4：URL 方言五条 + 列表尾部 `@js:`）

用户裁决（2026-10-26）：S4 一轮做完，不拆半片。

1. **URL 规则其实是一条链（`analyzeJs`）。** 上游 `AnalyzeUrl.initUrl` 的次序是「JS 段 → `{{…}}` →
   页码列表」，`renderUrl` 现在照抄：先跑 `_expandUrlSegments`，再做原来的 `{{…}}` 展开，最后由
   `renderUrlTemplate` 收尾。链的语义是上游原样：**字面段替换**当前值并先把其中的 `@result` 换掉，脚本
   收当前值作 `result`、返回值成为新值。这顺带把「整条规则就是一个 `@js:`」的 URL（真实语料常见写法）
   补齐了——此前它会被当成字面地址发出去。**body 不做这一步**（`expandSegments: false`）：上游只对地址
   跑 `analyzeJs`。
2. **`@js:` 贪婪，链里要用 `<js>`。** `JS_PATTERN` 的 `@js:([\w\W]*)` 吞到规则尾部，所以「脚本之后再写
   字面段」只能写 `<js>…</js>`。两份测试都按这个事实写，避免把语义误解成「拼接」。
3. **页码列表在 `{{…}}` 之后。** `<1,2,3>` 按请求页码取第 n 个、超出取末项（`page < size` 的上游判据
   让「正好等于长度」也落到末项）。页码来自 `JsPageContext.page`，所以 `walk` 的第 n 页天然对得上。
4. **query 全量编码只在声明了 `charset` 时发生。** 安全集**照抄两处**而不是合并成一处：判「已编码」
   用 `NetworkUtils.notNeedEncodingQuery`，真编码用 `AnalyzeUrl.encodeQueryParams`（多 `%`、`_`、`.`、
   `-`、`~`）。空格因此是 `%20`（不是表单的 `+`）。`charset: "escape"` 是上游另一套方言，本仓没建模：
   地址原样发出并在 `book-source.md` §4.3 登记。
5. **列表规则的 JS 柜口分两层。** 顶层只在「任一段是 JS 段」时进段链解释器（`_selectAllSegments`）；
   **嵌套**的 `parse.getElements` 仍拒 `@js:`，因为段链里的脚本要再起一个 job，而 worker 正在跑发起
   这次嵌套的 job（ADR-0030 §决策 1/3）。这层差别写进了 `_jsListMarker` 的注释与 `_check` 的注释，
   测试两边都钉住——第一版只改顶层，嵌套用例直接**无限递归**（fake bridge 把 parse 请求重放给同一
   段链），说明这条边界必须显式。
6. **脚本看到的是条目内容，不是元素。** 沙箱没有 DOM 句柄，段链里的 `result` 是元素的 `outerHtml`
   字符串列表（§6 的既有口径），所以 `attr()` / `text()` 这类写法不成立；这是登录在
   `book-source.md` §3 #14 的差异，不是新缺口。

验证：`url_template_test` 新增 9 例（页码列表的页内/超界/无页、query 编码的 GBK / 空格 / 已编码 /
无 charset / `escape`）、`rule_engine_test` 新增 6 例（脚本链、脚本后的字面段、整条规则脚本、页码列表、
`+` 前缀、`-+` 仍倒序）与 1 条改写（尾部 `@js:` 现在跑段链）、`page_fetch_service_test` 新增 2 例
（GET query 全量编码、页码列表选页）；全量 `flutter test` **2584 例全过**，`check_coverage` exit 0，
`build_runner` 后生成物无漂移。真引擎探针未加新用例：S4 的五条都不需要新的沙箱绑定（链用的就是既有
`evaluateJs`），设备级 70 例照旧双端全绿。

## 实现注记（2026-10-26，S7 门禁部分：G1 / G2）

用户裁决（2026-10-26）：S4 之后先把 S7 的两条文档门禁做掉，防止后续切片把文档写成「声称支持但已经不
支持」。

1. **名单要有机器对照面。** §11 的拒绝名单此前只有人读：`__javaRejectedNames` 已经在 M25/S3b 变过一次
   （`ajaxAll` / `connect` 从拒绝族移出），§11 全靠手工同步。现在两个名单在 §11 里各有一个 ```text 代码块
   （一行一个名字），门禁读**同一份文本**——走 `quickjs_worker.dart` 里那段前置脚本的数组字面量，而不是
   另导出一个常量：门禁要看见的就是 worker 实际执行的那段文本。
2. **Rhino 互操作包名顺手补全。** 文档原来只写四个包（`lang` / `security` / `util` / `net`），代码拒的是
   八个（还有 `io` / `nio` / `math` / `text`）。门禁一上来就把这条 4 vs 8 的漂移照出来了，按代码补齐。
3. **矩阵行必须有用例名。** G2 读 §3 的 markdown 表格（按**未转义**的 `|` 切列，因为示例里就有 `\|\|`），
   取出状态以「已确认」开头的行号，再扫 `test/**/*_test.dart` 找 `matrix #N`。第一次跑出 10 行没有标记
   （#2 / #5 / #8 / #10 / #11 / #23 / #24 / #25 / #27 / #29）：它们的用例其实都在，只是名字里没写行号。
   补齐的方式是在覆盖它们的 group / test 上写一行注释，而不是重命名 10 个用例——门禁要的是「能指到用例」，
   注释紧贴那条用例就够了，重命名只会让 `git blame` 更难读。
4. **门禁没有 `lib/` 对应物。** `testing.md` §3 要求测试镜像 `lib/` 路径；这两条门禁比对的是文档与代码，
   固定放 `test/docs/`，并在 §3 记成唯一例外（ADR-0012 要的正是「文档不能只由人看」）。

验证：`test/docs/book_source_doc_test.dart` 3 例（G1 两条、G2 一条）；全量 `flutter test` 2587 例全过。
G3（基准脚本冒烟）留给 M26/M27。

## 实现注记（2026-10-27，S5a：`source` 对象补全）

用户裁决（2026-10-27，三项）：① `source.getVariable` / `setVariable` / `putVariable` **顺手改成上游的
无参形状**；② `putLoginInfo` / `removeLoginInfo` **按 URL 写穿存储**；③ `removeLoginHeader` **连 Cookie
一起清**。依据是 2026-10-27 的 334 源语料普查（`engine-parity.md` §9.3）：约 30 个源用到这一族，其中
无参 `getVariable()` 读到 54 次、单参 `setVariable(v)` 写 41 次，而本仓 S3b 当初做的键值形状**命中 0**。

1. **字段是白名单，不是实体。** 上游把整个 `BookSource` 实例绑成 `source`（`BaseSource.kt:352-360`），
   读得到任何公开字段；本仓若照抄就得把 `payload`、行 id、`jsLib` 一起交出去。`JsSourceInfo` 因此只多
   六个字段：`key` / `bookSourceUrl` / `bookSourceName` / `bookSourceComment` / `header` / `loginUrl`
   （原有的 `name` / `url` / `group` 保留，是同一批值的旧名）。`bookSourceComment` **不单独建模**：
   它在 `extra` 里（§2 的未建模清单），而语料拿它当脚本库（`eval(String(...))`），所以取原文即可。
2. **`header` 两种形态两套来源。** 规则形态（`@js:` / `<js>`）走 `headerRule`，是声明原文——真实源
   靠前缀判断要不要自己求值；JSON 形态只有解析后的 map，于是**重新序列化**。这是唯一的行为差异，
   已登记（`book-source.md` §6）：`JSON.parse(source.header)` 与前缀判断都照常成立。
3. **整份变量 = 无名条目。** 上游有两个存储：整份变量 `sourceVariable_<url>`（一个字符串）与按名键值
   `v_<url>_<name>`。本仓只有 `source_variables` 一张表，于是「整份」落在**空名条目**里——空名字就是
   「这份变量没有名字」，好处是**没有迁移、没有第二个 store、只有一条写穿路径**。`put` 答回写入的值
   （真实源拿返回值拼 URL），`get` 未写过答空串，两个都是上游语义。
4. **Java `Map` 用「对象 + 不可枚举方法」兑现。** `getLoginHeaderMap()` / `getLoginInfoMap()` 上游返回
   `java.util.Map`，语料直接 `.get("账号")`（9 个源），而 S3b 的 `getLoginInfoMap()` 曾返回普通对象。
   现在两者都过前奏的 `__javaMap`：数据键可枚举（`JSON.stringify` 看到了就是它们），`get` / `put` /
   `remove` / `containsKey` / `size` / `isEmpty` 不可枚举。**不假装是 Java 对象**：`keySet()` /
   `entrySet()` 这类没有实现，命中就是 `not a function`（§6 列的是实际给到的那一组）。
5. **登录信息只有一个写入口，没有读 store。** job 已经带着登录信息的快照（ADR-0072 §决策 3），所以
   不需要像登录头那样再 hydration 一份；`putLoginInfo` / `removeLoginInfo` 只改 job 内的槽位，job 结束时
   随结果回传，桥经 `SourceLoginInfoWriter`（core 端口）写穿 `book_sources.login_info`（按 URL，与登录头
   同形）。于是「同一个 job 内写完立刻读得到」与上游一致，而**读一次不会引发一次库写**。
   `putLoginInfo` 只收字符串：解析不出对象答 `false`（上游会照样存，读时退回空表）——把一段读不回来
   的文本写进列里只会让下一次登录页显示空表单而看不出原因。
6. **登出要连 Cookie 一起清。** 上游 `removeLoginHeader` 除了删缓存还调 `CookieStore.removeCookie(getKey())`，
   清的是这条 URL 二级域的整条记录。`CookieManager` 因此多一个 `removeCookiesFor(url)`（内存宗与持久宗
   都实现；持久宗先问内存「这条 URL 会收到哪些域」再按域删，因为存储只能按域删）。只删头不清宗的话，
   下一次请求仍然带着旧会话上去——「退出登录」会看起来没生效。
7. **老 API 的测试要跟着改。** S3b 的键值形状有自己的 6 条用例，改形状后它们被重写成「整份变量」的
   用例，而不是留一个兼容分支：语料命中 0 的键值形状没有兼容价值，留分支只会让下一个读代码的人以为
   上游是那个形状。

验证：`flutter test` **2621 例全过**（`js_bindings_test` 新增 15 例、`js_bridge_test` 新增 7 例、
`cookie_manager_test` / `persistent_cookie_manager_test` 3 例、`book_source_dao_test` 1 例、
新增 `source_login_info_dao_repository_test` 4 例、`book_source_test` 4 例）；`dart format` 0 漂移，
`flutter analyze` 0 警告，`check_coverage` exit 0（core 98.93 / domain 98.54 / data 95.68），
`build_runner build` 后生成物无漂移。真引擎探针**新增 6 条**（字段白名单、`put`/`get` 跨 job、整份变量
跨 job、`putLoginInfo` + `getLoginInfoMap().get()` 写穿、`removeLoginHeader` 清 Cookie 与清头、
`putLoginInfo` 拒坏 JSON）——**尚未在设备上跑**，`flutter test` 用的是假 worker，前奏不参与。
