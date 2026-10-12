# 离线书源语料（`test/fixtures/book_sources/`）

> 语料用途与格式见 `docs/dev/book-source.md` §10；本文件只记录**来源与脱敏**，
> 不重复任何规范。测试**禁止真实联网**（C-NET-8）。

## `legado_export_sanitized.json`

| 项 | 值 |
|---|---|
| 来源 | 公开的「阅读 / Legado」书源合集 `https://raw.githubusercontent.com/Orokapei/BookSource/main/Legado.json`（2026-10-11 取用） |
| 处理 | **裁剪**：从 11 条中取 1 条（原 `bookSourceName` 为「六零文学」）。**脱敏**：`bookSourceName` 改为中性名，`bookSourceUrl` / `bookUrlPattern` / `loginUrl` 的主机改为保留域 `example-novel.test` |
| 未改动 | 其余字段与**全部规则串逐字保留**（`@css:` / `{{}}` / `##` / 默认规则 `text`、`href`），因此它保留了真实导出文件的字段构成：27 个顶层键中 16 个当前未建模，正是 `extra` 保留机制的验证对象 |
| 用途 | Phase 2.1 验收「能用真实书源 JSON 反序列化」（`PLAN.md` 2.1）；未建模键的逐层保留断言 |

**许可证与免责：** 语料是用户侧的第三方书源**数据**（非上游代码），按 `NOTICE.md` §1 的
口径不构成本项目代码衍生；本项目不分发、不索引任何书源，此处仅为离线测试夹具，
且主机名与名称已脱敏。若上游要求移除，删除本文件并同步 `legado_export_sanitized` 的
相关断言即可（断言不依赖任何站点内容，只依赖字段构成）。

## `legado_default_rules_source.json`

| 项 | 值 |
|---|---|
| 来源 | 公开的「阅读 / Legado」书源合集 `https://raw.githubusercontent.com/safino9/SourceGo/master/book_source/all.json`（2026-10-11 取用；该合集自述 189 条） |
| 处理 | **裁剪**：取 1 条（原 `bookSourceName` 为「🥈追书网」）。**脱敏**：`bookSourceName` 改为中性名，`bookSourceUrl` / `searchUrl` 主机改为保留域 `example-novel.test`，`bookSourceComment` 置空（其内容为合集自身地址） |
| 未改动 | 其余字段与**全部规则串逐字保留**：四段规则只用默认规则语法（矩阵 #1/#2/#5/#8/#9），因此它是 `PLAN.md` §4 的 G2 语料 |
| 配套页面 | `../html/search_result.html`、`../html/book_page.html`、`../html/chapter_page.html`（**按其真实选择器构造**，原因与实测证据见 `../html/README.md`） |

## `legado_g2b_default_rules_source.json` / `legado_g2b_css_rules_source.json`

> 这一对是 **G2b（真实站点链路）的证据语料**（`PLAN.md` §3.4 步骤 3 / §3.7），
> 不是回归语料：它们指向一个**活站点**，而单元测试禁止联网（C-NET-8）。

| 项 | 值（两条相同） |
|---|---|
| 来源 | `https://legado.aoaostar.com/sources/b778fe6b.json`（公开合集，2026-08-15 同步；2026-10-12 取用） |
| 处理 | **裁剪**：从 3907 条中取 1 条（原 `bookSourceName` 为「笔趣阁③」）。**脱敏**：`bookSourceName` 改中性名，`bookSourceUrl` 与 `searchUrl` 的主机改为保留域 `example-novel.test` |
| 原主机 | `www.biquge99.cc`（**仅记录用于复跑**；JSON 内已无真实主机） |
| 未改动 | 其余字段与**全部规则串逐字保留**（含 `##` 里的反斜杠转义与 `header` 里的浏览器 UA） |
| 用途 | `legado_g2b_default_rules_source.json`：G2b 四段链路的基线书源；`legado_g2b_css_rules_source.json`：同一书源的**派生等价源**（矩阵 #12 在真实 HTML 上的证据） |
| 预期结果 | 两源在活站点上必须得到**相同**的四段计数与正文哈希（记录见 `tool/spot_check/README.md` §4） |

**复跑方式（两条命令）：**

```bash
# 1) 把保留域换回真实主机（JSON 本身不含真实主机，故这一步是显式的人工动作）
sed 's/example-novel\.test/www.biquge99.cc/g' test/fixtures/book_sources/legado_g2b_default_rules_source.json > /tmp/g2b.json
# 2) 跑生产链路（只读、低频）
dart run tool/spot_check/spot_check.dart --source=/tmp/g2b.json --keyword=剑来
```

> 哈希钉的是 **2026-10-12 当天**的站点内容；站点改版后哈希会变，那是事实而不是回归。
> 语料与记录同源（ADR-0024）：入库的两个 JSON 使「规则等价性」可在仓内逐字核对。

### 派生映射（默认规则 → 等价的 `@css:`，共 16 处，其余字段完全相同）

| 字段 | 默认规则（基线） | 派生 `@css:` |
|---|---|---|
| `ruleSearch.bookList` | `class.bookbox` | `@css:.bookbox` |
| `ruleSearch.bookUrl` | `class.bookname@tag.a@href` | `@css:.bookname a@href` |
| `ruleSearch.name` | `class.bookname@tag.a@text` | `@css:.bookname a@text` |
| `ruleSearch.author` | `class.author@text` | `@css:.author@text` |
| `ruleSearch.coverUrl` | `class.bookimg@tag.img.0@src` | `@css:.bookimg img:eq(0)@src`（同时行使矩阵 #29） |
| `ruleSearch.intro` | `class.bookinfo@p@text` | `@css:.bookinfo p@text` |
| `ruleSearch.kind` | `class.cat@text` | `@css:.cat@text` |
| `ruleSearch.lastChapter` | `class.update@tag.a@text` | `@css:.update a@text` |
| `ruleBookInfo.name` | `class.info@h1@text` | `@css:.info h1@text` |
| `ruleBookInfo.author` | `class.info@class.small@tag.span.0@text` | `@css:.info .small span:eq(0)@text` |
| `ruleBookInfo.kind` | `class.info@…span.4@text&&…span.2@text&&…span.1@text` | 同序的 `@css:.info .small span:eq(4/2/1)@text`（保留 `&&`） |
| `ruleBookInfo.coverUrl` | `class.cover@img@src` | `@css:.cover img@src` |
| `ruleBookInfo.intro` | `class.intro@text` | `@css:.intro@text` |
| `ruleBookInfo.lastChapter` | `class.info@class.small@tag.span.5@a@text` | `@css:.info .small span:eq(5) a@text` |
| `ruleToc.chapterList` | `class.listmain@tag.dd@tag.a` | `@css:.listmain dd a` |
| `ruleContent.content` | `id.content@textNodes` | `@css:#content@textNodes` |

> 每行的 `##` 替换段在两边**逐字相同**（未重写），因此两个文件的差异**只有**
> `bookSourceName` 与上表 16 处规则的写法：可以直接用
> `diff <(jq -S . legado_g2b_default_rules_source.json) <(jq -S . legado_g2b_css_rules_source.json)` 核对。

## `legado_js_rules_source.json`

> 这是 **3.7（真实书源回归）的证据语料**：矩阵 #14（`@js:`）在本文件入库前**仓内语料为 0 条**，
> 因此状态列无法翻转（ADR-0029 §后果、`PLAN.md` §3.7）。它同样指向一个**活站点**。

| 项 | 值 |
|---|---|
| 来源 | `https://legado.aoaostar.com/sources/b778fe6b.json`（公开合集，2026-08-15 同步；2026-10-12 取用，3907 条中的「📻 猫耳FM」） |
| 处理 | **裁剪**：取 1 条。**脱敏**：`bookSourceName` 改中性名、`bookSourceGroup` 改「示例分组」、`bookSourceUrl` 去掉尾随 `#` 并改保留域 `example-novel.test`、`bookSourceComment` 置空、`enabledExplore` 置 `false`（发现页是 M1） |
| 原主机 | `www.missevan.com`（仅记录用于复跑）、静态资源 `static.missevan.com` → `static.example-novel.test` |
| 逐字保留 | 四段规则串逐字（含三条 `@js:` 值规则与 `$.info.episodes.music&&$.info.episodes.episode` 的 JSON `&&`）；被改的只有脚本字面量里的那两个主机 |
| 配套页面 | `../json/maoer_search.json`、`../json/maoer_toc.json`（**按活站点当天的响应派生**，构造依据见 `../json/README.md`） |
| 用途 | 矩阵 #14 的真实源证据（逐项 `@js:` 在 `searchRule.bookUrl` / `tocRule.chapterUrl` 上），同时行使矩阵 #13 的「路径命中列表」形态与 #11 的 JSON 分支并集 |
| 活站点记录 | `tool/spot_check/README.md` §4（四段中前三段跑通：搜索 30 / 详情 1 / 目录 34；正文段被站点的阿里云 WAF 拦住，记录里已写明归属） |

**复跑方式：**

```bash
# 1) 把保留域换回真实主机（JSON 本身不含真实主机）
sed 's/example-novel\.test/www.missevan.com/g' \
  test/fixtures/book_sources/legado_js_rules_source.json > build/maoer.json
# 2) 跑生产链路（需要真实 JS 引擎 ⇒ 设备宿主；命令与原因见 tool/spot_check/README.md §2）
SPOT_CHECK_ARGS="--source=build/maoer.json --keyword=剑来" \
  flutter run -d windows -t tool/spot_check/spot_check.dart
```

> 离线回放（不联网）由 `test/features/book_source/domain/usecases/search_books_test.dart` 的
> `chain_givenJsRulesSourceAndCorpusPages_replaysTheListStages` 钉子：搜索 30 条、目录 34 条，
> 且逐项 `@js:` 脚本拿到的 `result` 就是该项的 JSON 值。

## `legado_g2b_syntax_rules_source.json`（3.7 的语法覆盖派生源）

> 与 `@css:` 派生源同一手法：站点、页面、`searchUrl`、`header` 全部逐字相同，
> 只把规则**写法**换成等价形式，用来给矩阵 #3 / #4 / #6 / #7 / #10 / #25 / #26 / #27 / #28
> 补真实回归证据（基线源本身只用到 #1 / #2 / #5 / #8 / #9 / #11）。
> 两者在活站点上必须得到**相同**的四段计数与正文哈希（记录见 `tool/spot_check/README.md` §4b）。

### 派生映射（9 处，其余字段与基线完全相同）

| 字段 | 基线（默认规则） | 派生（行使的矩阵行） |
|---|---|---|
| `ruleSearch.name` | `class.bookname@tag.a@text##…` | `class.bookname@.0@text##…`（**#28** 索引作首规则） |
| `ruleSearch.author` | `class.author@text##作者：\|<` | `text.作者：@text##作者：\|<`（**#3** 按文本内容匹配） |
| `ruleSearch.bookUrl` | `class.bookname@tag.a@href` | `class.bookname@tag.a[0]@href`（**#26** `[]` 索引列表） |
| `ruleSearch.coverUrl` | `class.bookimg@tag.img.0@src` | `class.bookimg@children.0@children.0@src`（**#4** `children`） |
| `ruleSearch.intro` | `class.bookinfo@p@text` | `class.bookinfo@tag.p!1@text`（**#6** `!` 排除） |
| `ruleSearch.kind` | `class.cat@text##分类：` | `class.cat@text##分类：####`（**#25** `##match##replace###`） |
| `ruleSearch.lastChapter` | `class.update@tag.a@text##…` | `class.none@text\|\|class.update@tag.a@text##…`（**#10** `\|\|`） |
| `ruleBookInfo.name` | `class.info@h1@text##…` | `-class.info@h1@text##…`（**#7** 前导 `-`） |
| `ruleBookInfo.lastChapter` | `class.info@class.small@tag.span.5@a@text##…` | `…@a@text%%class.none@text##…`（**#27** `%%`） |

> 可以用 `diff <(jq -S . legado_g2b_default_rules_source.json) <(jq -S . legado_g2b_syntax_rules_source.json)`
> 核对：两者只在上表 9 处规则与 `bookSourceName` 上不同。

## 语料处理规则（对后续新增语料同样适用）

按 ADR-0023 决策 2：只保留**必要条目**（不整包收录书源合集）、主机名一律改为保留域、
`bookSourceName` 改中性名、**规则串逐字保留**，并在本文件记录来源与处理方式。
