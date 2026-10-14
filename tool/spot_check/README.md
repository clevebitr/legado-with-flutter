# G2b spot-check：真实站点链路验证

> 本文档是 **G2b（真实链路）的证据记录与复现说明**，对应 `PLAN.md` §3.4 步骤 3（「3.2 之后、
> 3.3 之前」）与 §3.7 的登记表。它**不复述**任何规范：规则语义归 `docs/dev/book-source.md`，
> 失败语义归该文档 §7，裁决归 `docs/dev/adr/`。
>
> 它**不是测试**：`docs/dev/testing.md` §1 禁止测试联网，因此这里是 `tool/` 入口，
> 不被 `flutter test` 发现、不进 CI（与 `tool/spike/` 同一模式）。

---

## 1. 为什么需要它

3.2 把矩阵 #12（`@css:`）建完时，它只被离线语料验证过：语料是**按真实选择器构造**的 HTML
（`test/fixtures/html/README.md`）。构造的页面无法证明「cascadia 对真实页面的语义与 jsoup 一致」，
而这正是 `@css:` 的全部价值所在。G2b 的要求就是：**取存活站点，跑一遍
搜索 → 详情 → 目录 → 正文**。

## 2. 怎么跑

> **宿主自 3.4 起必须是 Flutter 设备（或 `flutter test` 宿主），不再是 `dart run`。** 链路里的
> `@js:` 规则要真实 JS 引擎，因此 `spot_check.dart` 静态依赖 `core/js/quickjs_worker.dart`，
> 而它需要 `flutter_qjs_next` 的原生库（`tool/spike/README.md` §3 同因）。`flutter run` **不转发**
> 命令行参数给 Dart 入口，所以选项通过 `SPOT_CHECK_ARGS` 环境变量传入（多个选项用空格分隔）。

```bash
# 把一个真实书源 JSON（单条或整个合集）跑完四段链路
SPOT_CHECK_ARGS="--source=<file.json> --keyword=剑来" \
  flutter run -d windows -t tool/spot_check/spot_check.dart
# 合集里按名字挑一条，并输出可供记录粘贴的 JSON
SPOT_CHECK_ARGS="--source=<collection.json> --name=笔趣阁 --json" \
  flutter run -d windows -t tool/spot_check/spot_check.dart
# 列出合集里本仓当前能求值的源（选源依据，见 §3）
SPOT_CHECK_ARGS="--list=<collection.json>" \
  flutter run -d windows -t tool/spot_check/spot_check.dart
```

链路是**生产链路**：UseCase → `renderUrlTemplate` → `core/network/HttpClient` → `RuleEngine`，
书源自身的 `header` 字段也会真正进请求（`book-source.md` §2 的 M0 字段）。任何一段失败都会打印
`ParseFailureKind` 与把链路打断的 `rulePath`；进程退出码 0 表示四段都有产出。

**证据形态：** stdout 里只出现**截断样本（≤60 字符）与全文 sha256**，不落盘页面正文。

## 3. 选源（可复现）

| 项 | 值 |
|---|---|
| 合集 A | `https://raw.githubusercontent.com/Orokapei/BookSource/main/Legado.json`（11 条） |
| 合集 B | `https://raw.githubusercontent.com/safino9/SourceGo/master/book_source/all.json`（189 条） |
| 合集 C | `https://legado.aoaostar.com/sources/b778fe6b.json`（3907 条，最近同步 2026-08-15） |
| 筛选 | `--list` 的判据：`searchUrl` 是 HTTPS GET 且含 `{{key}}`、四段规则非空、不含**尚未实现**的标志（`@xpath:` / `webjs` / `sourceregex` / `@@` / `<js>` / `:正则` / `{"method"…}` 那类对象头）。**判据随已实现语法收放：** `@js:` 自 3.4 起不再是排除项（矩阵 #14），只在**列表规则**（`bookList` / `chapterList`）里排除；`@put:` / `@get:` 与 `{{}}` 内嵌（矩阵 #16 / #18，随 3.4 落地）不再排除。**2026-10-13 修正：** `{{…}}` 开头的规则此前仍被一个「`{` 开头就排除」的旧判据（为 `{"method":"POST"}` 写的）误伤——它把 `{{}}` 也当对象头了，与同一段注释和 `PLAN.md` §3.7 的「`{{}}` 不再排除」互相矛盾。现在只排除**单**花括号开头。搜索 URL 仍保守：只认 `{{key}}` / `{{page}}` / `{{baseUrl}}`，其余 `{…}` 一并排除 |
| 结果（2026-10-14，含 `{{…}}` 与 `@@` 两次修正后复算） | 合集 C 中 **409/3907** 条属于「本仓库今天能跑通四段」的集合（M0 + 已落地的 M1 语法）；其中 **296** 条依赖未知类型退化（ADR-0032）、**157** 条用值规则 `@js:` |
| 探测 | 80 条各 1 次 GET（浏览器 UA，≤12 s）；**40 条返回 200**，其中 13 条搜索页含真实结果链接 |

**一行复算这三个数字（含 ADR-0032 的依据）：**

> **搜索 URL 的 `{…}` 保守口径为什么保留（2026-10-13 架构师裁决）：** 它最初的理由是
> 「`{…}` 模板型 URL 规则在 M0 下无法逐字回放」，而矩阵 **#19（`{$jsonpath}`）已在 3.7 落地**——
> 按现在的语法，这类源**能跑**。收紧判据（把检查扩到 `exploreUrl` 条目 / `nextTocUrl` /
> `bookUrl` / `nextContentUrl`）会把能跑的源挡在候选之外，而放开判据又会把「搜索 URL 用裸 `{…}`」
> 的源当成可跑（那一条仍然不可回放）。因此**判据不动**：`--list` 继续只做保守筛查，
> 这类源的真实可用性由 §4 的**逐条真实回归**判定（本文件 §5/§6 记录每次选源时的逐条审查）。
> 于是 353/253/122 这组数字**保持有效**，ADR-0032 与本文件的引用无需复算。

```bash
curl -sSL -o build/ao.json https://legado.aoaostar.com/sources/b778fe6b.json
SPOT_CHECK_ARGS="--list=build/ao.json" flutter run -d windows -t tool/spot_check/spot_check.dart | tail -12
# -- 409 of 3907 sources are M0-compatible.
# -- 296 of 409 M0-compatible sources rely on the unknown-type degradation (ADR-0032).
# -- 157 of 409 M0-compatible sources use a value-rule `@js:` (matrix #14); …
# -- M1 grammar census (whole collection; G4 needs one source per row):
#     #15 @@: 319 sources (25 of them selectable today)
#     #16 @put:/@get:: 438 sources (61 of them selectable today)
#     #17 java.put/java.get: 348 sources (16 of them selectable today)
#     #18 {{…}}: 980 sources (128 of them selectable today)
#     #19 {$…}: 193 sources (23 of them selectable today)
#     #17 form: 339 sources use the **variable** form (usable as evidence), 9 only the refused synchronous-HTTP one (ADR-0037 §决策 5).
# -- rule fields that are an entirely literal URL (whole collection; PLAN §3.7): 12 sources.
```

> 打印里的 `M0-compatible` 现在指「M0 + 已落地的 M1 语法」（判据见上表筛选行）；名字没改是为了
> 让历次记录可对比。每行的第 2 列标 `degraded` 即该源依赖退化（判据与引擎一致：列表规则每个
> `@` 段都是选择器，取值规则除末段外都是选择器），第 3 列标 `js` 即该源用值规则 `@js:`。
> 合集内容会随上游同步变化，上面是 **2026-08-15 快照**下的数字。
>
> **为什么条数与 ADR-0032 §背景 的 197/137 不同：** 那两个数字是 3.4 落地前的快照（当时
> `@js:` 仍在排除列表里，含值规则 `@js:` 的源没被计入）。判据此后宽容了三次（`@put:` /
> `@get:`、`{{}}` 内嵌、以及 2026-10-13 真正放开的 `{{…}}` 规则头），所以 **266 → 353 → 384 → 409**
> 是同一份合集上的口径变化，而不是源变多了。ADR-0032 自己的结论（未知类型必须退化为 CSS）
> 不受影响。

**b7 取证（2026-10-14，JSON 条目上的 `result` 绑定）：** 同一条 `--list` 命令的末尾会打印
「JSON 条目 scope + 脚本读 `result.<成员>`」的源数与字段分布。判据与实现见 `spot_check.dart` 的
`_printJsonItemResultCensus`（JSON 列表规则 `bookList` / `chapterList` 的**兄弟字段**，以及
`init` 为 JSON 规则时的 `ruleBookInfo.*`；`@js:` 尾段与 `{{…}}` 脚本都算——两者都把当前 scope 绑成
`result`；`JSON.parse(result)` 单列，它读 JSON 文本是对的，不受绑定差异影响）。2026-08-15 快照下：

```text
-- JSON items bound to a script as `result` (b7 evidence, whole collection; PLAN §3.5): 85 sources, 98 fields.
    ruleSearch.coverUrl: 18
    ruleSearch.lastChapter: 16
    ruleToc.chapterName: 10
    ruleSearch.bookUrl: 10
    ruleToc.isVip: 9
    ruleExplore.coverUrl: 6
    ruleSearch.kind: 5
    ruleSearch.name: 5
    ruleExplore.bookUrl: 4
    ruleToc.updateTime: 3
    ruleToc.chapterUrl: 3
    ruleSearch.intro: 3
    ruleExplore.kind: 2
    ruleExplore.wordCount: 2
    ruleBookInfo.kind: 1
    ruleToc.nextTocUrl: 1
    samples: 酷我小说 (ruleSearch.kind, ruleBookInfo.kind) | 大文学无错小说网 (ruleSearch.coverUrl) | 思路客 (ruleSearch.coverUrl)
    7 fields use `JSON.parse(result)` instead (they read the JSON text correctly, so they are not affected by the binding difference).
```

> 这组数字由架构师用一份独立复刻脚本在同一份 `build/ao.json` 上复算，**源数 / 字段数 / `JSON.parse`
> 数与逐字段分布均一致**（85 / 98 / 7）。是否据这些数字改 `book-source.md` §6 的 `result` 绑定，
> 待架构师裁决（改契约须配新 ADR，见 `PLAN.md` §3.5 的 b7 行）。

**P5-0 的入库证据（2026-10-14，书源身份与重复导入）：** 同一条 `--list` 命令还会打印合集里的 URL 重复形状，
供 `PLAN.md` §3.6 5.0 的「主键 / 重复导入」裁决用（判据见 `spot_check.dart` 的
`_printBookSourceIdentityCensus`：书名 + `searchUrl` + `header` + 五个规则对象全部相等才算「同一条」，
比较前对键排序，所以重新导出导致的键序差异不会被算成差异）：

```text
-- book source identity (whole collection; PLAN §3.6 5.0): 3907 entries, 2596 distinct bookSourceUrl.
    1217 URLs appear more than once (max 3 entries): 1012 of them have every entry identical on the behaviour fields, 205 carry at least one that differs.
```

> 两种形态**都真实存在**：**1012 个 URL 下是完全等价的重复条目**（重新导出 / 多份合集的产物），
> **205 个 URL 下有多条行为不同的源**（例：`https://www.qidian.com` 的「起点中文」与「💰起点中文」）。
> 「URL 直接做主键」会丢掉后者，「URL 唯一索引 + 覆盖」会丢掉前者里的来源信息——怎么裁由架构师定，
> 本节只提供形状与计数。

> 只读、低频：每个候选 1 次请求，链路本体每站 ≤4 次（搜索 / 详情 / 目录 / 正文各 1）。
> 不登录、不批量爬取、不落盘页面。

## 4. 结果（2026-10-12，Windows 11 / Flutter 3.47.7）

> **记录里怎么标识一个源（2026-10-14 架构师补的引证规则）：** 合集 C 是**上游同步的快照**（本文件引的是 2026-08-15 那份），
> 条数会随同步漂移；而且同名同 URL 的源在合集里**可能重复出现**（`笔趣阁③`/`www.biquge99.cc` 就有 5 条，位置 64/553/619/2343/2416）。
> 所以记录的主标识是三件：**书源名 + `bookSourceUrl` + 派生文件**（`build/*.json`，它才是真正被跑的那份），
> 「合集 C 第 N 条」只作为**该次快照下的辅助定位**并在引用时写明是哪一份快照（历史记录里既有 0 基也有 1 基写法，
> 如 §4b 的「第 42 条」与 G4 记录的「第 63 条」指向同一条源——2026-10-14 复核时已确认，不再按数字互相校对）。

**跑通完整四段链路（G2b 达成）：**

```
语法：全部默认规则（矩阵 #1 / #2 / #5 / #8 / #9）
书源：笔趣阁③ (https://www.biquge99.cc)          # 合集 C 第 42 条
语料：test/fixtures/book_sources/legado_g2b_default_rules_source.json（已脱敏，主机还原后复跑）
链路：搜索 → 详情 → 目录 → 正文
结果：
  search   ok  count=2     剑来 https://www.biquge99.cc/book/1869698028/
  bookInfo ok  剑来 | author=烽火戏诸侯 | toc=https://www.biquge99.cc/book/1869698028/
  toc      ok  count=1310  第一章 惊蛰 https://www.biquge99.cc/book/1869698028/986558553.html
  content  ok  3031 字符  sha256=6578ef3efc456856
结论：已确认（该站的规则串是真实导出的原文，未做任何改写）
```

**复跑（入库后的 fixture 已逐字复现上表）：**

```bash
sed 's/example-novel\.test/www.biquge99.cc/g' \
  test/fixtures/book_sources/legado_g2b_default_rules_source.json > /tmp/g2b.json
flutter run -d windows -t tool/spot_check/spot_check.dart -- --source=/tmp/g2b.json --keyword=剑来
```

> **为什么不是 `dart run`（2026-10-13 更正）：** 本工具链需要真实 JS 引擎与 Flutter 原生资源，
> `dart run` 会在 `dart:ui` 上直接编译失败（实测 exit 254）。入口固定为
> `flutter run -d <device> -t tool/spot_check/spot_check.dart -- <参数>`。

> 哈希钉的是 **2026-10-12 当天**的站点内容（站点改版后哈希会变，那是事实而不是回归）；
> fixture 自身不含真实主机，因此需显式还原主机（见 `test/fixtures/book_sources/README.md`）。

**M1-b1（`ruleToc.updateTime` + `java.timeFormat`）的证据（2026-10-13）：**

```
语法：`java.timeFormat(timestamp)`（book-source.md §6）+ 四处 updateTime 中的 ruleToc.updateTime
书源：漫客栈 (comic.mkzhan.com)，合集 C 中的一条真实导出
链路：搜索 → 详情 → 目录（本站正文规则用 `java.getStringList`，故 content 段另见下）
结果：
  search   ok  count=1   火影忍者之新的伙伴
  bookInfo ok  火影忍者之新的伙伴 | toc=https://comic.mkzhan.com/chapter/?comic_id=213560
  toc      ok  count=5   尸魂界的不速之客 … updateTime=2023/11/15 06:13
  content  FAILED parseFailed at contentRule.content:js:error（该源正文规则用 `java.getStringList`，未实现）
结论：`java.timeFormat` 的返回值经真链路落到 `Chapter.updateTime`（本机 +08:00 下
      1700000000000 ms → 2023/11/15 06:13）。
```

> **派生说明（与本节 `@css:` 派生同口径）：** 这次只改 `ruleToc.updateTime` 一条规则
> （原值 `$.change_time@js:result==0?'':java.timeFormat(result*1000)` →
> `@js:java.timeFormat(1700000000000)`），searchUrl / header / 四段规则其余字段逐字来自真实导出。
> 原因：该站章节数据的 `change_time` 为 0 或缺失时，原规则走 `''` 分支，取不到 `java.timeFormat`
> 那一路（实测原规则下 `updateTime` 为空）。
>
> **语料里的主流写法仍未证：** 全量 3907 条里 **184** 条用 `java.timeFormat`，主流写法是
> `{{java.timeFormat(java.getString('$.x')*1000)}}`，需要 `java.getString`（未实现）——
> 阻塞与数字见 `PLAN.md` §3.7。复跑命令（派生 JSON 需自行生成）：
> `flutter run -d windows -t tool/spot_check/spot_check.dart -- --source=<derived.json> --keyword=火影`。

**M1-b2（`concurrentRate`）的证据（2026-10-13）：**

```
语法：`concurrentRate`（book-source.md §8、ADR-0036）
书源：🎨 漫客栈 (comic.mkzhan.com)，合集 C 中的一条真实导出
链路：搜索 → 详情 → 目录（content 段同 b1：该源用 java.getStringList，未实现）
结果（A：声明 1500；B：同源改成 "0"，其余逐字不变）：
  A  rate: 1500  search ok count=1 | bookInfo ok | toc ok count=5 | content FAILED | elapsed: 4.6s
  B  rate: 0     search ok count=1 | bookInfo ok | toc ok count=5 | content FAILED | elapsed: 0.6s
结论：声明 `1500`（每 1500 ms 最多 1 次）下，四次真实请求花了 4.6 s（≥ 3 个窗口 = 4.5 s），
      同一站点同一规则去掉声明只要 0.6 s ⇒ 速率门在真链路上确实生效，且不阻塞其他书源。
```

> **派生说明：** 这次**只加/改 `concurrentRate` 一个字段**（A 为 `"1500"`，B 为 `"0"`），
> searchUrl / header / 四段规则逐字来自真实导出。原因：全量 3907 条里只有 **3 条**声明了
> `concurrentRate`，且三条都跑不了原样链路（1 条站点已不可达、2 条用未实现的 URL 形态：
> `<js>` 包装与 `{...}` URL 选项）——这一事实登记在 `PLAN.md` §3.7。
> 复跑命令（派生 JSON 需自行生成）：
> `flutter run -d windows -t tool/spot_check/spot_check.dart -- --source=<derived.json> --keyword=火影`。

**同一次复算里的 `concurrentRate` 取值分布（`book-source.md` §8、ADR-0036 §决策 8）：**

```bash
curl -sSL -o build/ao.json https://legado.aoaostar.com/sources/b778fe6b.json
SPOT_CHECK_ARGS="--list=build/ao.json" flutter run -d windows -t tool/spot_check/spot_check.dart
```

```
-- 353 of 3907 sources are M0-compatible.
-- 253 of 353 M0-compatible sources rely on the unknown-type degradation (ADR-0032).
-- 122 of 353 M0-compatible sources use a value-rule `@js:` (matrix #14)…
-- concurrentRate: 3 sources declare one (3 limited, 0 no gate, 0 invalid).
    1   3000   limited
    1   2000   limited
    1   1000   limited
    intervals(ms): min=1000 median=2000 max=3000
```

> **单位判断（ADR-0036 §决策 8 要求的记录）：毫秒口径成立，重开条件未满足。**
> 三条都是**单个整数**（无 `n/m`），值落在 1000–3000：按毫秒读是「1 次 / 1–3 秒」——
> 对一个阅读 App 完全合理；按秒读则是「1 次 / 1000–3000 秒」（即 17–50 分钟一次），
> 没有作者会那样写，且会把一个本来正常的源限成不可用。⇒ **无需新 ADR**；一旦将来出现
> 把 `n/m` 当「n 次 / m 秒」的语料，按 ADR-0036 §决策 8 重开。
> 另：只有 3/3907 条声明限速，所以这个特性的影响面本身很小；三条都合法（`0 invalid`），
> 即真实语料里还没出现过 ADR-0036 §决策 2 的那种畸形声明（其行为由单测钉住）。

**M1-b1b（`java.*` 兼容面 · 语料主流写法）的证据（2026-10-13）：**

```
语法：`{{java.timeFormat(java.getString('$.x')*1000)}}`（§6 的字面量快路径 + java.* 别名族）
书源：🎨 漫客栈 (comic.mkzhan.com)，合集 C 第 1229 条的**真实导出**
链路：搜索 → 详情 → 目录 → 正文
结果（只改 `ruleToc.updateTime` 一条规则，见派生说明）：
  search   ok  count=1   火影忍者之新的伙伴 https://comic.mkzhan.com/comic/info/?comic_id=213560
  bookInfo ok  火影忍者之新的伙伴 | toc=https://comic.mkzhan.com/chapter/?comic_id=213560
  toc      ok  count=5   尸魂界的不速之客 … updateTime=2018/10/25 17:05
  content  FAILED parseFailed at contentRule.content（JSONPath 方言缺口，与本切片无关，见下）
结论：主流写法把真实章节的 `start_time=1540458357` 经 `java.getString`（宿主内联成
      `"1540458357"`）与 `java.timeFormat` 落到 `Chapter.updateTime = 2018/10/25 17:05`
      （本机 +08:00）。这同时收口了 b1 剩下的那半：「主流写法未证」。
```

> **派生说明（与本节 `@css:` / b2 派生同口径）：** 只改 `ruleToc.updateTime`：
> 原值 `$.change_time@js:result==0?'':java.timeFormat(result*1000)` →
> `{{java.timeFormat(java.getString('$.start_time')*1000)}}`。
> `searchUrl` / `header` / 四段规则其余字段逐字来自真实导出。两点理由：
> ① 该站 5 个章节的 `change_time` 全是 `"0"`，原规则自己把它挡成 `''`（b1 的派生记录已实测），
> 取不到 `java.timeFormat` 那一路；`start_time` 是**同一个章节对象里的真实 10 位秒级时间戳**，
> 能让 `java.getString` 读到一个非零值，证明取到的是真数据而不是空串乘 1000；
> ② 全量 3907 条里 `ruleToc.updateTime` 用主流写法的共 **58 条**，逐个探活后**没有一条能原样跑**：
>
> | 站点（源数） | 探活（GET 自己的 searchUrl，浏览器 UA） | 归属 |
> |---|---|---|
> | `s.lhdqsb.cn`书香之家×2 | TLS 握手失败；且 `header` 是 `<js>`（本仓无法反序列化） | 站点不可达 + 字段形态 |
> | `s.pjxhmy.com`值得阅读×4 | TLS 握手失败；`header` 同为 `<js>` | 同上 |
> | `apifans.dushimh.com`粉丝漫画 | TLS 握手失败 | 站点不可达 |
> | `www.9comic.cn`好看漫画×2 | 301 → `gcomic.net`，403 / 连接被重置 | WAF |
> | 其余 49 条 | `searchUrl` 是 POST 表单 / `<js>` / `@js:` 包装 | 本仓不支持（§3 判据已排除） |
>
> 复跑命令（派生 JSON 需自行生成）：
> `flutter run -d windows -t tool/spot_check/spot_check.dart -- --source=<derived.json> --keyword=火影 --json`。

> **为什么 content 段是 `parseFailed`（归属：JSONPath 方言，非 b1b）：** 该源正文规则是
> `java.getStringList("$.data.page[*]image").toArray().map(…)`。`java.getStringList` 的**快路径确实被调用**
> （失败发生在它求值的**内层规则**上），但 `$.data.page[*]image` 这种「`]` 后直接跟成员名」的 Legado
> JSONPath 方言被 RFC 9535 解析器（`json_path`）拒掉——同一页真实数据下
> `$.data.page[*].image` 返回 3 张图、`[*]image` 直接 `parseFailed`。已登记在 `PLAN.md` §3.7。

**M1-b5（`{{…}}` 内的 `##` · JSONPath `]name`）的真源复跑（2026-10-13）：**

```
语法：① `{{rule##a##b}}`（`##` 在模板内部，归内层规则）  ② `$.a[*]name`（`]` 后直接跟成员名）
源：均为合集 C 的真实导出 + 只改一条规则（见下）

RUN 1 = 🎨 漫客栈（只改 ruleToc.updateTime 为 `{{java.timeFormat(java.getString('$.start_time')*1000)}}`，
        其余逐字来自真实导出；它的 contentRule.content 本来就写 `$.data.page[*]image`）
  search   ok  count=1  火影忍者之新的伙伴 https://comic.mkzhan.com/comic/info/?comic_id=213560
  bookInfo ok  火影忍者之新的伙伴 | toc=https://comic.mkzhan.com/chapter/?comic_id=213560
  toc      ok  count=5  尸魂界的不速之客 … updateTime=2018/10/25 17:05
  content  ok  458 字符 sha256=30cc59e176f7ac3c   ← b1b 时这一段是 `parseFailed`
  RESULT: complete（首次四段全通）
结论（②）：`java.getStringList("$.data.page[*]image")` 的**成功路径**在真源上跑通（快路径内联 +
      `.toArray()` 垫片 + `.map(...).join()`），输出 3 个 `<img>` 标签。

RUN 2 = ●QB女生<kd♛（只改 ruleSearch.bookUrl 为 `…?bookid={{java.getString('$.docId').split('_')[1]}}`；
        原值 `…?bookid={{$.docId##.*_}}` 在 **URL** 里写规则头，按 §4 本就被拒；其余逐字不动）
  search   ok  count=18  剑来 https://bookshelf…/intro-info?bookid=3000000243
            | kind=仙侠,古典仙侠,草根崛起 已完结 updateTime=-
  bookInfo ok  | kind=分 连载中 | toc=https://…/all-chapter?bookId=
  toc      FAILED parseFailed at tocRule.chapterList（派生把 18 条都指向同一本，章节接口拿不到行）
结论（①）：`ruleSearch.kind` 的 `{{$.tag_views##\s+##,}}` 不再 `parseFailed`（b1b 当时 18/18 都
      是这个错），“ `##` 属于内层规则”已经生效：`仙侠,古典仙侠,草根崛起` 就是 `##\s+##,` 对真实
      `tag_views` 的替换结果；后半段 `已完结` 是 b1b 的 `java.getString` 快路径在同一真源上生效。
```

> **两条“为什么派生”都只改了一个字段，原因逐条写明：** RUN 1 与 b1b 的派生完全相同（只改
> `ruleToc.updateTime`），这样 content 段的差异可以完全归因于 b5 的 JSONPath 归一化；RUN 2 改
> `bookUrl` 是因为原值把规则头写在 URL 里（§4 的登记拒绝），不改就一条书都产出不了，而这条
> 运行的目的是看 **search 条目的 `kind`**（fix ① 的形状只在 `ruleSearch.kind` 里）。
> **派生源的两个字段都不是“测出来的”：** `tools/spot_check/spot_check.dart` 的 search 样本也
> 开始打印 `kind=`（与 bookInfo 样本同口径），证据才可以从 JSON 里直接取。
>
> **失败但已定位的第三方：** RUN 2 的 `tocRule.chapterList` 报 `parseFailed`，是因为派生把 18 条
> 搜索结果都指向同一本（`bookid=3000000243`），章节接口返回的 `$.rows` 为空——与本切片无关。

**G4：矩阵 M1 #15–#19 的真实源证据（2026-10-14）：**

口径：源取自合集 C（2026-08-15 快照）；样本取自 `--json` 报告，正文只出现截断样本与 sha256（§2）。
三个 fixture 由同一条命令从合集抽出、**未改任何字段**（只有 RUN 2 按下方理由改了一条）：

```bash
python -c "import json;d=json.load(open('build/ao.json',encoding='utf-8'));json.dump(d[1229],open('build/g4_mkz.json','w',encoding='utf-8'),ensure_ascii=False)"
# 同理 d[1463] -> build/g4_qb.json（#17 的派生基线）与 d[341] -> build/g4_bq4.json（#15 的尝试）
SPOT_CHECK_ARGS="--source=build/g4_mkz.json --keyword=火影 --json" flutter run -d windows -t tool/spot_check/spot_check.dart
```

```text
RUN 1（#16 · #18 · #19）源：漫客栈（合集 C 第 1229 条，http://comic.mkzhan.com）
  complete=true；search 1 / bookInfo 1 / toc 5 / content 458 字符 sha256=30cc59e176f7ac3c
  #16 @put:/@get:
      ruleSearch.name       = $.title@put:{comic_id:$.comic_id}        ← 写
      ruleToc.chapterUrl    = ...?chapter_id={{$.chapter_id}}&comic_id=@get:{comic_id}&...   ← 读
      产出样本：尸魂界的不速之客 https://comic.mkzhan.com/chapter/content/v1/?chapter_id=750783&comic_id=213560&format=1&quality=1&sign=0&type=1&uid=0
  #18 {{…}}:
      ruleToc.chapterUrl    = 同上，其中 chapter_id={{$.chapter_id}}
      产出样本：同一行 URL 的 chapter_id=750783（模板里的规则头求值）
  #19 {$…}:
      ruleSearch.bookUrl    = https://comic.mkzhan.com/comic/info/?comic_id={$.comic_id}
      产出样本：火影忍者之新的伙伴 https://comic.mkzhan.com/comic/info/?comic_id=213560
      （同源 ruleBookInfo.tocUrl 的 {$.data.comic_id} 在 toc= 一栏同步生效：...?comic_id=213560）

RUN 2（#17）源：●QB女生<kd♛（第 1463 条），只改 ruleSearch.bookUrl
  理由：原值 ...?bookid={{$.docId##.*_}} 把规则头写在 URL 里，按 §4 被拒 → 一条书都产出不了，
  字段规则（含 java.put/get）因此永远不跑；改成同义的 JS 模板
  ...?bookid={{java.getString('$.docId').split('_')[1]}}，其余逐字不动。--keyword=剑来
      ruleBookInfo.kind        = ...{{java.put('time', String(java.timeFormat(java.getString('$.lastUpdatetime')*1000))...)}}  ← 写（变量形态）
      ruleBookInfo.lastChapter = {{$.lastSerialname}} • {{java.get('time')}}      ← 读
      产出样本：bookInfo  " | author=null | toc=...?bookId= | kind=分 连载中 | lastChapter=• 1970-01-01 | ..."
  说明：1970 是因为该响应的 data.bookInfo.lastUpdatetime 没被字段规则看见（下面登记的 `init` 缺口），
  java.getString 给 '' → ''*1000 = 0 → timeFormat(0) → 源自己的 replace(/\s.*/,'') → 1970-01-01；
  **往返本身成立**（读回的就是写进去的那个格式化值）。
  形态：本行只用变量形态 java.put(key,value) / java.get(key)（两参、无 URL）；上游那个同步 HTTP 形态
  java.get(url) / java.get(url,{...}) 是 ADR-0037 §决策 5 的具名拒绝，普查里 9 条源只用了后者。

RUN 3a（#15 的基座校正）源：漫客栈（第 1229 条），只把 ruleSearch.kind 设成 @@ 规则
  （ruleSearch.kind = @@class.cat@text##分类：）。结果：`kind=` 拿不到值，日志给出
  `Rejected rule: field=searchRule.kind reason=searchRule.kind kind=parseFailed` 与
  `Field rule degraded to empty: ... field=searchRule.kind`；其余三段仍是 complete=true。
  原因：`@@` 是**默认（CSS / jsoup）规则**的 flag，而漫客栈四段页面（search / info / toc / content）
  **全是 JSON**——默认规则打在 JSON scope 上按 ADR-0032 退化成 CSS，再被 `_matchElements` 判成
  `parseFailed`（JsonScope 没有 DOM）。所以裁决里的「基座」必须换成 HTML 真源；语料分布也印证这点
  （`{{@@class…}}` 那类写法都长在 HTML 页上）。

RUN 3b（#15，证据）源：笔趣阁③（`https://www.biquge99.cc/`，本快照第 63 条 —— 即 §4b 的 G2b **HTML** 基线源同一份），
  派生文件：`build/g4b_bq_flag.json`（只给 `ruleSearch.kind` 加 `@@`；`build/g4b_bq.json` 是加 flag 前的对照），
  **只改一条字段**：`ruleSearch.kind` 从 `class.cat@text##分类：` 改成 `@@class.cat@text##分类：`
  （只加矩阵 #15 的 flag，选择器与替换段逐字不动）：
      search   ok  count=2     剑来 https://www.biquge99.cc/book/1869698028/ | kind=武侠
      bookInfo ok  剑来 | author=烽火戏诸侯 | toc=https://www.biquge99.cc/book/1869698028/
                  | kind=2026-10-07 06:23:06 | lastChapter=第83章 今日无事 | intro=大千世界，无奇不有。…
      toc      ok  count=1310  第一章 惊蛰 https://www.biquge99.cc/book/1869698028/986558553.html
      content  ok  3031 字符 sha256=6578ef3efc456856
      RESULT: complete
  结论：`@@` 被剥掉后按**默认规则**求值，产出样本就是 search 的 `kind=武侠`；派生只动了那一条，
  其余三段的计数与哈希与 §4b 的 G2b 基线**逐字相同**（toc 1310、content 3031 / `6578ef3efc456856`），
  说明这次派生没有扰动链路。

字面量 URL 的取证（PLAN §3.7 的待裁决项，同一趟用入库工具做）：
  入库工具普查：12 条源（首版正则把 {{…}} 也算进去了，已修）——
      ruleSearch.lastChapter 4 · ruleToc.chapterUrl 3 · ruleSearch.checkKeyWord 2 ·
      ruleSearch.kind 1 · ruleSearch.intro 1 · ruleExplore.intro 1
  上游行为（fork AnalyzeRule + AnalyzeByJSoup）：完全字面量 URL 没有规则头 → mode 保持 Default →
      AnalyzeByJSoup.getElementsSingle 的 else -> temp.select(beforeRule)，即**上游也把它当规则读**；
      实测 jsoup 1.16.2（fork 的版本）doc.select("https://a.test/book/1") **抛**
      Selector.SelectorParseException: unexpected token at '//a.test/book/1'。
      ⇒ 上游不会把字面量 URL 当值返回；本仓的 parseFailed 只是把同一件事显式化。
```

**b6：`ruleBookInfo.init` 的真实源证据（2026-10-14）：**

口径与 G4 RUN 2 相同（同一源、同一条 `ruleSearch.bookUrl` 派生、同一条命令、同一个关键词）：

```bash
python -c "import json;d=json.load(open('build/ao.json',encoding='utf-8'));s=d[1463];s['ruleSearch']['bookUrl']=\"https://bookshelf.html5.qq.com/qbread/api/novel/intro-info?bookid={{java.getString('$.docId').split('_')[1]}}\";json.dump(s,open('build/b6_qb.json','w',encoding='utf-8'),ensure_ascii=False)"
SPOT_CHECK_ARGS="--source=build/b6_qb.json --keyword=剑来 --json" flutter run -d windows -t tool/spot_check/spot_check.dart
```

```text
RUN 4（b6 · ruleBookInfo.init）源：●QB女生<kd♛（第 1463 条），派生与 G4 RUN 2 **逐字相同**（只改 ruleSearch.bookUrl）
  init = $.data.bookInfo（源自带，未改）
  bookInfo 样本对比（同一条命令、同一个关键词）：
    G4 RUN 2： " | author=null | toc=...?bookId= | kind=分 连载中 | lastChapter=• 1970-01-01 | ..."
    b6 本次： 剑来 | author=烽火戏诸侯 | toc=...bookId=3000000243 | kind=9.9分 玄幻 已完结
              | lastChapter=第1279章 也曾少年思无邪 • 2026-06-02
              | intro=<p>🏷️ 古典仙侠, 草根崛起, 智商在线, 三观正</p> &lrm; <p>同名动漫正在热播。"大千世界，无奇不…
              | wordCount=13059574
  即 author / name / toc / kind / lastChapter / intro / wordCount 全部从「空」变成响应里的真实值；
  lastChapter 里那个日期就是 `$.lastUpdatetime`（init 之前该字段读不到 → java.getString 给 '' → 0 → 1970-01-01）。
  toc 段仍不是 complete：`tocRule.chapterUrl` 是 POST JSON 形态（ADR-0037 §决策 5 的具名拒绝）、
  `tocRule.isVip` 报 `unsupported://`，两者与 b6 无关（G4 RUN 2 同样如此）。
```

**腾讯搜索系真实源（未做任何改写）的探活结果（2026-10-13）：** 合集 C 里活着的、用主流写法的真源是
`●QB女生<kd♛` / `南极 🐧`（`so.html5.qq.com/ajax/real_search_result`，HTTP 200 / 33 KB 真实 JSON）。
它们把 `{{java.timeFormat(java.getString('$.lastUpdatetime')*1000)}}` 写在 `ruleBookInfo.kind` 里，
**原样跑不了**，原因是两个已登记的本仓缺口（都发生在 b1b 的代码之前、与 `java.*` 无关）：
① kind 的第一个模板是 `{{$.tag_views##\s+##,}}`——**`##` 落在 `{{…}}` 内部**时，`_expandRule`
先按第一个 `##` 切开整条规则，模板因此被判成不平衡，该字段 `parseFailed`（矩阵 #18 × #9）；
② `bookUrl` 的 `…?bookid={{$.docId##.*_}}` 在 **URL** 里写规则头，按 §4 本就按名拒绝。
两条的现象与复跑细节都记在 `PLAN.md` §3.7，供架构师排期。

**矩阵 #12（`@css:`）在真实 HTML 上的证据：** 同一站点、同一批页面，把上一条书源的默认规则**逐条改写为等价的 `@css:` 写法**（`class.bookbox` → `@css:.bookbox`、`id.content@textNodes` →
`@css:#content@textNodes`、`class.bookimg@tag.img.0@src` → `@css:.bookimg img:eq(0)@src` 等，
后者同时行使矩阵 #29），得到**同样的四段计数**，且正文 **sha256 完全相同**
（`6578ef3efc456856`）。⇒ cascadia 对本仓 `@css:` 求值路径在真实页面上与默认规则等价。
派生源的**逐条映射表（16 处）与复跑命令**见 `test/fixtures/book_sources/README.md`；
入库后的派生 fixture 已逐字复现上表（`legado_g2b_css_rules_source.json`）。

> 为什么是派生源：合集里唯一两条用 `@css:` 的源，其站点一条已停放（`m.kayege.info` 返回
> Coming Soon），另一条被 Cloudflare 拦截（`99csw.com`）；见 §5 的「源失效」发现。
> 派生的只有规则**写法**，站点、页面、`searchUrl`、`header` 都是原样。

**ADR-0031 宽容解码的 warning 实测（同一次运行，stderr）：**

```text
Declared charset utf-8 carried illegal bytes; 1 malformed byte replacement(s) inserted: rule=ruleBookInfo source=https://www.biquge99.cc url=https://www.biquge99.cc/book/1869698028/
```

被宽容的就是下面表中「声明 UTF-8 但含 1 个非法字节」的那个书页：warning 携带**声明的编码、替换数量、
字段路径与书源 ID**，不含正文（C-ERR-8 / C-SEC-4），且每条响应只记一条（同页被两个阶段各取一次，
即两条响应、两条 warning）。

**未跑通但已定位的站点（同一批 13 条，用于说明失败归属）：**
| 现象 | 站点 | 归属 | 处理 |
|---|---|---|---|
| 书页声明 UTF-8 但含 1 个非法字节（131 368 B 中偏移 130 893 处 `0x8b`）→ 整段 `encodingFailed` | `biquge99.cc` 等 3 条同站源 | 本仓口径 | **ADR-0031**：声明车道宽容解码 + 一条带「声明的编码 + 替换数 + 书源 ID」的 warning（已实现，该站因此跑通）；记录里已按该 ADR 要求写明「该页含非法字节」 |
| `.searchresult` / `li` / `dd` 等未知类型 → 搜索段即失败 | `ihuaben.com` / `zhulang.com` 等 10 条 | 本仓口径 | **ADR-0032**：未知类型退化为原始 CSS（已实现，`ihuaben.com` 随后搜索段拿到 30 条真实结果） |
| 声明 `shift-jis` / `euc-jp` 且字节不完整 → 依赖抛 `RangeError`（`Error`）逃出 `ParseResult` 契约；`euc-kr` 则静默丢弃非法字节 | — | 依赖缺陷 + `Error` 不得捕获（ADR-0022） | 登记为已知缺口，见 §6（宽容映射因此只含 `utf-8` / `gbk`，见 `book-source.md` §5.1） |
| 搜索参数改版（源写 `wd=`，站点现在用 `qd=`）、目录结构改版 | `dushu.com` / `linovel.net` | **源失效**，非本仓缺陷 | 记录即可；矩阵状态列仍由 3.7 的真实回归决定 |

## 4b. 3.7 真实回归（2026-10-12）：矩阵 M0 行的状态列

3.7 要把 §3 矩阵的 M0 行由「待验证」改为「已确认」，因此需要**逐行**的真实证据。四次活站点运行：

| # | 书源 | 命令（`SPOT_CHECK_ARGS=… flutter run -d windows -t tool/spot_check/spot_check.dart`） | 结果 |
|---|---|---|---|
| 1 | 基线（`legado_g2b_default_rules_source.json`，还原主机后） | `--source=build/g2b.json --keyword=剑来 --json` | `complete=true`：搜索 2 / 详情 剑来·烽火戏诸侯 / 目录 **1310** / 正文 **3031** 字符 `sha256=6578ef3efc456856`（与 §4 当天记录**逐字相同**） |
| 2 | 派生语法覆盖源（`legado_g2b_syntax_rules_source.json`，同站同页） | `--source=build/g2b_syntax.json --keyword=剑来 --json` | 同上，**四项计数与哈希全部相同** |
| 3 | `@js:` 语料源（`legado_js_rules_source.json`，还原主机后） | `--source=build/maoer.json --keyword=剑来 --json` | 搜索 **30** / 详情 剑来 / 目录 **34**；正文段失败（站点 WAF，见下） |
| 4 | ADR-0032 退化：同站 `ihuaben.com` 等两批（§4 已记） | — | 搜索段拿到 30 条真实结果 |

**逐行结论（依据上面四次运行 + §4 的 `@css:` 派生）：**

```text
语法：#1 / #2 默认规则（class / id / tag）  书源：示例书源（G2b 真实站点）  链路：搜索 → 详情 → 目录 → 正文  结论：已确认
语法：#3 text.文本片段                     书源：同站派生源（author = text.作者：@text）     结论：已确认（四项计数与哈希与基线相同）
语法：#4 children                          书源：同站派生源（coverUrl = class.bookimg@children.0@children.0@src）  结论：已确认
语法：#5 正/负索引、#8 提取、#9 ## 替换     书源：基线源（`tag.img.0` / `tag.a@text` / `##分类：` 等）  结论：已确认
语法：#6 ! 排除（`tag.p!1`）                书源：同站派生源（intro）                        结论：已确认
语法：#7 前导 `-` 倒置                     书源：同站派生源（bookInfo.name = `-class.info@h1@text`）  结论：已确认（该字段只匹配一个元素，因此倒置是恒等变换；方向语义由单测钉住，登记在 PLAN §3.7）
语法：#10 || 依次尝试（`class.none@text||class.update@tag.a@text`）  书源：同站派生源（lastChapter）  结论：已确认
语法：#11 && 并集                         书源：基线源（bookInfo.kind 的三支 &&）+ @js: 语料源（JSON 分支的 `$.info.episodes.music&&$.info.episodes.episode`）  结论：已确认
语法：#12 @css: 与 #29 索引伪类            书源：同站派生 `@css:` 等价源（§4，16 处映射）  结论：已确认（正文哈希相同）
语法：#13 @json: / 裸 $.                 书源：JSON 语料源 + @js: 语料源（活站点 30 条搜索 / 34 条目录）  结论：已确认；回归中修掉两处保真缺口（见 §5）
语法：#14 @js: 值规则                      书源：@js: 语料源（`$.id@js:'…'+result` 逐项、`$.sound_id@js:'…'+result` 逐项）  结论：已确认（活站点：搜索段 30 条书址、目录段 34 条章节地址均由脚本产出）
语法：#25 ##match##replace###              书源：同站派生源（kind = `class.cat@text##分类：####`）  结论：已确认
语法：#26 [] 索引列表（`tag.a[0]`）          书源：同站派生源（bookUrl）                    结论：已确认
语法：#27 %% 交叉合并                      书源：同站派生源（bookInfo.lastChapter，第二支为空）  结论：已确认
语法：#28 索引作分段首规则（`.0` / `children.0`）  书源：同站派生源（name / coverUrl）          结论：已确认
```

**正文段在 @js: 语料源上失败，归属是站点防护：** `contentRule.content` 要取的
`https://www.missevan.com/sound/getsound?soundid=…` 现在返回阿里云 WAF 的挑战页（HTML，非 JSON），
所以 `$.info.sound.soundurl_64` 无值 → `parseFailed`。与该源自身的规则无关：前两段（含两条逐项 `@js:`）
在同一站点上均已跑通。

**离线可复现性：** 上面第 3 次运行的计数由
`test/features/book_source/domain/usecases/search_books_test.dart` 的
`chain_givenJsRulesSourceAndCorpusPages_replaysTheListStages` 在本地复现（搜索 30 / 目录 34）；
第 2 次运行的等价性由入库的两个 fixture 与 `test/fixtures/book_sources/README.md` 的映射表逐字核对。

## 5. 本次 spot-check 顺带发现并修掉的缺陷

| 缺陷 | 证据 | 处理 |
|---|---|---|
| `BookSource.headers`（`header`，M0 字段）从未进入任何请求 | `PageFetchService.fetch` 未传 `headers`；`zwdu.com` 用项目默认 UA 直接连接失败、浏览器 UA 200 | 已修：UseCase 传 `source.headers`，`FakeHttpClient` 记录请求头，`fetch_content_test.dart` 断言 |
| 解码 warning 无法定位到书源 | ADR-0031 §决策 2 要求携带书源 ID，而 `HttpClient.get` 此前没有这个参数（C-ERR-8 的既有缺口） | 已修：`HttpClient.get` / `PageFetchService.fetch` 增加 `sourceId`，4 个 UseCase 传 `source.url`，测试断言它到位 |
| **矩阵 #13：JSONPath 命中一个列表时本仓不展开**（列表规则当一个条目、取值规则给一段 JSON 文本） | 3.7 的真实 @js: 源：`bookList: $.info.Datas` + 逐项 `$.name` → 活站点上只剩 1 条且书名为空；修后同一运行给出 30 条 | 已修（3.7）：列表规则把命中的列表当元素列表读、取值规则逐元素展开，两处都对着上游 `AnalyzeByJSonPath.kt:137` / `:83-87`；单测与语料回放同步，记录见 §4b |
| `spot_check.dart` 自 3.4 起无法再用 `dart run` 启动（链路需要真实 JS 引擎 ⇒ 静态依赖 Flutter） | 本机实测：`dart run` 在 `flutter/foundation` 的 `dart:ui` 引用上编译失败 | 已修（3.7）：改为设备宿主运行并把选项改由 `SPOT_CHECK_ARGS` 传入（§2 已更新）；`--list` 的判据同时把 `@js:` 从排除项改为「仅列表规则 / URL 模板排除」 |

## 6. 未闭环（已登记，见 `PLAN.md` §3.7）

- `shift-jis` / `euc-jp` 的字节不完整会让 `charset 2.0.1` 抛 `RangeError`（`Error`），
  该异常会越过 `ParseResult` 契约（C-ERR-1）逃到调用方；按 ADR-0022 不得捕获 `Error`，
  因此需要换依赖或加一层隔离；`euc-kr` 的解码器则静默丢弃非法字节（无宽容入口）。
  两者因此**不在** ADR-0031 的宽容映射里（只有 `utf-8` / `gbk` 实测符合「U+FFFD + 不丢字节」）。
- 矩阵 #7 的多元素倒置：真实回归只行使了单元素倒置（恒等），方向语义由单测钉住；
  仓内语料仍无这种需求。
- `@js:` 的**列表规则**形态（`bookList` / `chapterList`）仍未实现：真实源里有这种写法
  （1096 条含 `@js:` 的源中一部分），但仓内没有入库样本可定型「JS 返回一列元素」的契约。
- `--list` 的判据不检查非搜索字段 URL 里的 `{…}`（矩阵 #19）：候选源里出现过
  `bookUrl: https://…/{$.novel_id}` 这类 M1 模板，而工具只对 `searchUrl` 查 `{`——
  **2026-10-13 架构师裁决：作为已知取舍保留，不再归 b4b 验收。** 该判据的原始前提（`{…}`
  在 3.7 之前无法回放）已不成立，但收紧它会把**能跑**的源排除、并让 353/253/122 这组数字失效；
  §3 已写明口径与理由，选源时仍按 §5 的逐条审查避开放不进规则的源。
- 绝大多数 2023 年入库的书源站点已死或加防护（本次 69 条含值规则 `@js:` 的 M0 源里
  能活的只有 API 型三条），因此「真实源回归」每次都要重新选源；命令与判据见 §3。
- **`{{…}}` 模板内部的 `##` 替换**（新发现，2026-10-13，M1-b1b 真源回归）：
  `{{$.tag_views##\s+##,}}` 这类写法会让 `_expandRule` 先按第一个 `##` 切开整条规则（那个
  `##` 在模板里面），模板因此被判成不平衡，字段 `parseFailed`。腾讯搜索系真源
  （`●QB女生<kd♛` / `南极 🐧`）的 `ruleBookInfo.kind` 第一条模板就是它，所以那两条源跑不到
  主流写法的第二条模板。矩阵 #18 × #9 的交叉，登记在 `PLAN.md` §3.7。
- **JSONPath 方言：`]` 后直接跟成员名**（新发现，2026-10-13，同一次回归）：
  `$.data.page[*]image` / `$.a[0]b` 是 Legado 接受的写法，而 RFC 9535 解析器（`json_path`）
  只认 `$.data.page[*].image`；两者在真实数据上一个 `parseFailed`、一个返回 3 张图。
  它让 b1b 的派生真源在 content 段失败（`java.getStringList` 的快路径**已被调用**，卡在内层规则），
  登记在 `PLAN.md` §3.7。
