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

## 语料处理规则（对后续新增语料同样适用）

按 ADR-0023 决策 2：只保留**必要条目**（不整包收录书源合集）、主机名一律改为保留域、
`bookSourceName` 改中性名、**规则串逐字保留**，并在本文件记录来源与处理方式。
