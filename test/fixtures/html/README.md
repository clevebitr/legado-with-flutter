# 离线页面语料（`test/fixtures/html/`）

> 语料用途与格式见 `docs/dev/book-source.md` §10；测试**禁止真实联网**（C-NET-8）。
> 本文件记录**来源与构造方式**，不重复任何规范。

## 这三个页面是"按真实书源的选择器构造"的，不是抓取的

配对的书源是 `../book_sources/legado_default_rules_source.json`（真实导出，已脱敏）。
页面本身**按该书的真实选择器构造**，而不是从站点抓取——原因如下（2026-10-11 实测）：

| 步骤 | 结果 |
|---|---|
| 抽样书源总量 | 242 条（SourceGo `all.json` 189 + namofree 51 + 其他 2） |
| 其中"仅默认规则"（矩阵 #1/#2/#5/#8/#9，四段规则全部如此） | **20 条（8%）** |
| 这 20 条的站点存活（HTTP 200） | **4 条** |
| 这 4 条里搜索路径仍然有效 | **0 条**——分别返回 404、重定向到首页、或选择器零匹配（2021 年的规则对今天的站点已失效） |
| 12253 条的大合集 | release 资源已 404，无法取得 |

**结论：** 当前不存在"站点存活且默认规则仍匹配"的真实书源，因此无法抓取到与规则相符的真实页面。
故采取最接近的可行形态：**书源 JSON 真实**（字段构成、规则串逐字保留），**页面按其真实选择器构造**。
`docs/dev/roadmap.md` §4 的 G2 因此可达成；若将来找到存活的默认规则书源，替换 `*.html` 即可，测试无需改动。

## 文件

| 文件 | 对应阶段 | 对应的真实规则（节选） |
|---|---|---|
| `search_result.html` | 搜索 | `class.result-item`（bookList）、`class.result-item-title.0@tag.a.0@text`（name）、`class.result-game-item-info-tag.0@tag.span.1@text`（author） |
| `book_page.html` | 详情 + 目录 | `class.box_con.0@id.info@tag.h1.0@text`（name）、`id.list@tag.dd`（chapterList）、`tag.a.0@href`（chapterUrl） |
| `chapter_page.html` | 正文 | `id.content@textNodes`（content） |

**不含任何真实作品内容：** 页面里的书名、作者、章节名与正文均为占位文本，只为满足选择器而存在。
这同时满足 ADR-0023 决策 2 的口径——仓库内不引入真实站点的页面内容。
