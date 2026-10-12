# JSON 响应语料（`test/fixtures/json/`）

> 语料用途与格式见 `docs/dev/book-source.md` §10；测试**禁止真实联网**（C-NET-8）。
> 本文件记录**来源与构造方式**，不重复任何规范。

## 为什么需要这份语料

§10 要求「至少 2 个书源完成搜索 → 详情 → 目录 → 正文的离线回放」。第二个书源必须是
**JSON 接口源**：矩阵 #13（`@json:` / 裸 `$.`）在 HTML 页面上根本没有用武之地——
规则读的是响应体，而 HTML 语料（`../html/`）的响应体是 HTML。

## 语料是"按真实 JSON 书源的真实规则构造"的

配对的书源是 `../book_sources/legado_json_source.json`（真实导出，已脱敏）。
与 `../html/` 同一形态：**书源 JSON 真实、响应页按其真实规则构造**，页面不是抓取的——
真实接口需要固定会话参数（`session_id` / `udid`），且按 ADR-0023 决策 2，仓库内不引入
真实站点的内容。

## 文件

| 文件 | 对应阶段 | 应答的真实规则（逐字，见配对书源） |
|---|---|---|
| `search.json` | 搜索 | `bookList` `@json:$.all_book_items[*]\|\|@json:$.guess_like_items[*]`、`name` `@json:$.name`、`author` `@json:$.author`、`kind` `@json:$.classes`、`coverUrl` `@json:$.imgUrl`、`lastChapter` `@json:$.lastChapterName` |
| `book.json` | 详情 + 目录（该书的 `tocUrl` 回落到书籍页本身） | `intro` `@json:$.coverInfo.desc`（**嵌套路径**）、`chapterList` `@json:$.volumes[*].chapters[*]\|\|$.chapters[*]`（注意第二个候选是**裸** `$.` 形式）、`chapterName` `@json:$.chapter_name` |
| `content.json` | 正文 | `content` `@json:$.content`（含转义 `\n`，用于确认 JSON 字符串里的换行会解成真正的换行） |
| `maoer_search.json` | 搜索 | `bookList` `$.info.Datas`（**路径命中一个列表**）、`name` `$.name`、`author` `$.author`、`kind` `$.type_name`、`intro` `$.abstract`、`lastChapter` `$.newest`、`coverUrl` `$.cover` |
| `maoer_toc.json` | 详情 + 目录（该书的 `tocUrl` 回落到书籍页本身） | `name` `$.info.drama.name`、`coverUrl` `$.info.drama.cover`、`chapterList` `$.info.episodes.music&&$.info.episodes.episode`（**第一支为空数组**，并集取第二支的 34 条，矩阵 #11 的 JSON 分支形态）、`chapterName` `$.name` |

## `maoer_*.json`（3.7 的 `@js:` 语料的配套页）

| 项 | 值 |
|---|---|
| 来源 | **真实抓取**（2026-10-12，浏览器 UA，各 1 次只读 GET）：`https://www.missevan.com/dramaapi/search?s=剑来&p=1`、`https://www.missevan.com/dramaapi/getdrama?drama_id=59005` |
| 派生处理 | 只保留规则读到的字段与外层结构（`info.Datas[*]`、`info.drama`、`info.episodes.{music,episode}[*]`）；**所有可读文本换成占位符**（`示例作品N` / `示例章节N` / `示例简介N` / 空作者）、所有主机改保留域（`www.missevan.com` → `example-novel.test`，`static.maoercdn.com` / `static.missevan.com` → `static.example-novel.test`）；**数值与数组长度逐字保留**（30 条搜索结果、34 条章节、`music: []`），因此回放计数与活站点当天一致 |
| 为何派生 | ADR-0023 决策 2 与 `../book_sources/README.md` 的口径：仓库内不引入真实站点的内容（API 响应含书名、简介、封面地址）；结构、键名与计数保留，所以规则仍然逐字回放 |
| 配对书源 | `../book_sources/legado_js_rules_source.json` |
| 正文段 | **无配套页**：`contentRule.content` 要取的 `sound/getsound` 接口被阿里云 WAF 拦住（返回挑战页 HTML，非 JSON），活站点上该段报 `parseFailed`，归属是站点防护而不是本仓（记录见 `tool/spot_check/README.md` §4） |

`search.json` 故意同时给出 `all_book_items` 与 `guess_like_items`：`||` 取**首个非空**候选，
所以回放测试可以断言「只有 1 条结果、且来自第一个候选」。

## `legado_json_source.json`

| 项 | 值 |
|---|---|
| 来源 | 公开的「阅读 / Legado」书源合集 `https://raw.githubusercontent.com/safino9/SourceGo/master/book_source/all.json`（2026-10-11 取用；该合集自述 189 条） |
| 处理 | **裁剪**：从 189 条中取 1 条（原 `bookSourceName` 为「🎉宜搜小说」）。**脱敏**：`bookSourceName` 改为中性名，`bookSourceUrl` / `searchUrl` 的主机改为保留域 `example-novel.test` 且 `http:` 改 `https:`，`bookSourceComment`（指向合集自身）置空，`exploreUrl`（发现页，M1）置空并置 `enabledExplore: false` |
| 逐字保留 | `ruleSearch` 的 `name` / `author` / `kind` / `coverUrl` / `lastChapter` / `bookList`、`ruleBookInfo.intro`、`ruleToc` 的 `chapterList` / `chapterName`、`ruleContent.content`、以及 `searchUrl` 的整条查询串 |
| **改写（2 条，见下）** | `ruleSearch.bookUrl`、`ruleToc.chapterUrl` |

### 唯一偏离「规则串逐字保留」的地方

这两条 URL 规则在原文里是 **M1** 的「`@json:` + `{}` / `{{}}` JSONPath 变量」写法
（矩阵 #18 / #19；并带 `@put:` / `@get:`，矩阵 #16 / #17）：

```text
ruleSearch.bookUrl = @json:https://api.easou.com/api/bookapp/bookSummary.m?nid={$.nid}&gid={$.gid}&…@put:{gid:$.gid}
ruleToc.chapterUrl  = @json:https://api.easou.com/api/bookapp/chargeChapter.m?…&nid={{$.nid}}&sort={{$.sort}}&…&chapter_name={{$.chapter_name}}
```

M0 的 `renderUrlTemplate` 只认 `{{key}}` / `{{page}}` / `{{baseUrl}}`，所以逐字保留时
**整条链路在第一次取书址时就会断**：书址无值 → 命中被跳过 → 搜索阶段返回空列表。
两条规则因此改写为等价的纯 JSONPath，并由语料页直接给出 URL：

```text
ruleSearch.bookUrl = @json:$.bookUrl
ruleToc.chapterUrl  = @json:$.chapterUrl
```

**请以本段为界**：除这两条之外，其余规则串逐字来自真实导出。

## 扫描结论（2026-10-11，新增语料前实测）

为找到「逐字保留即可跑通」的 JSON 书源，扫描了 211 条公开真实书源：

| 项 | 数值 |
|---|---|
| 扫描总量 | 211（SourceGo `all.json` 189 + `Orokapei/BookSource` 11 + `jiwangyihao/source-j-legado` 11） |
| 使用 `@json:` 的书源 | **2**（「宜搜小说」与「有兔阅读」，均为 JSON 接口源） |
| 其中 URL 规则也是 M0 可求值的 | **0**——两条都用 `http://…{$.field}` / `{{$.field}}` 的 M1 模板 |
| 因此 M0 逐字保留可跑通四段的 JSON 书源 | **不存在** |

结论：JSON 源在野外用 M1 的 URL 模板拼地址，所以第二个链路书源必然要做上面那 2 条改写；
这也说明 #18 / #19 的优先级值得在 3.3 之后单独评估（本文件不做裁决）。

**许可证与免责：** 同 `../book_sources/README.md`——语料是用户侧的第三方书源**数据**，
按 `NOTICE.md` §1 的口径不构成本项目代码衍生；页面内容全为占位文本，仓库内不含任何真实站点内容。
