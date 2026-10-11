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

## 语料处理规则（对后续新增语料同样适用）

按 ADR-0023 决策 2：只保留**必要条目**（不整包收录书源合集）、主机名一律改为保留域、
`bookSourceName` 改中性名、**规则串逐字保留**，并在本文件记录来源与处理方式。
