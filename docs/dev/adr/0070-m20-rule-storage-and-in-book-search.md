# ADR-0070 M20：规则存储（单表 + kind）与书内搜索（顺序预取、可停止）

- **状态：** Accepted（2026-10-24，用户裁决三项：规则用 Drift 单表 + kind 列、搜索顺序预取 + 可停止、
  M20 先定规格再拆）
- **日期：** 2026-10-24
- **关联：** `docs/dev/ui-gap.md` §4 M20（U6 / U11）、ADR-0003（Drift 主库）、ADR-0056（迁移可重入）、
  ADR-0066（v7 的教训）、C-ARCH-5、C-SRC-2、C-NET-2、`docs/dev/book-source.md` §2/§8

## 背景

`ui-gap.md` 的 M20 有两块：**书内全文搜索**（U6）与**规则管理 UI**（U11：替换净化 / 目录规则 /
字典规则 / 高亮标签）。两件事各自缺一个规格：

1. 规则存哪里、长什么样？上游是四张表（`ReplaceRule` / `TxtTocRule` / `DictRule` / `HighlightRule`），
   字段各不相同。
2. 搜索怎么取正文、怎么停？阅读链路是**逐章取页 + 单源速率门 + 单源预算**，不能像上游那样
   「全本并发拉一遍」。

## 决策 1 规则用**一张** Drift 表 + `kind` 列，kind 专属字段放 JSON payload

```sql
CREATE TABLE rules (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  kind        TEXT    NOT NULL,          -- 'replace' | 'toc' | 'dict' | 'highlight'
  name        TEXT    NOT NULL,          -- 展示名（净化规则的名字、字典名、标签名…）
  payload     TEXT    NOT NULL,          -- kind 专属字段的 JSON（见下）
  is_enabled  INTEGER NOT NULL DEFAULT 1,
  is_built_in INTEGER NOT NULL DEFAULT 0, -- 随应用内置的规则（可禁用、可编辑，删除即「恢复默认」）
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL
);
CREATE INDEX rules_kind_order ON rules (kind, sort_order);
```

**为什么不是四张表**：四类规则的 **CRUD、排序、启停、导入导出** 完全同形，逐类建表要把同一套
DAO / 列表页 / 编辑页抄四遍；而 kind 专属字段的**差异**只影响「编辑哪一个表单」，把它放进 JSON
就不会为了加一个字段而改 schema、写迁移、补 schema dump。

**payload 的形状（本 ADR 是唯一出处）：**

| kind | payload 字段 | 对应上游 |
|---|---|---|
| `replace` | `pattern`（正则或字面量）、`replacement`、`isRegex`（bool）、`timeoutMs`（int，可省） | `ReplaceRule` |
| `toc` | `rule`（目录规则文本）、`serialNumber`（int，可省） | `TxtTocRule` |
| `dict` | `urlRule`、`showRule`、`ruleGroupType`（可省） | `DictRule` |
| `highlight` | `pattern`（正则）、`colorHex`（`#AARRGGBB`，可省）、`group`（可省） | `HighlightRule` / `TagGroupRule` |

payload 里**未知键必须保留**（与书源 `extra` 同一立场，ADR-0021）：上游的规则可以整段导出/导入，
丢掉不认识的键会让「导入一次再导出」变成有损操作。**读不懂 payload 的行不能静默丢弃**：列表里
显示为「规则损坏」，并允许删除/编辑（否则用户既看不到也修不了）。

## 决策 2 书内搜索：**顺序预取 + 可停止**，命中带章节与偏移

- 起点是**当前章**，然后按目录顺序向后预取（并发上限 2，受 `HttpPolicy` 与单源速率门约束）。
  不做「全本并发」：一个 2000 章的源会瞬间发出上千个请求，违反 C-NET-2 与 §8 的速率门。
- 搜索在**正文文本**上跑（与该章渲染用的是同一份正文：`FetchContent` + 缓存 + `replaceRegex`），
  所以命中位置与阅读器里看到的文字一致，点击即可跳到那一句。
- **可停止**：调用方持有一个 `SearchSession`（= 一个 `cancel()` + 一个 `Stream<…>`）。
  `cancel()` 之后**不再发起新请求**，在途请求的结果直接丢弃；已经取到的正文**停留在缓存里**
  （那是正常阅读也会用到的，不算副作用）。
- 命中条目携带 `(chapterIndex, chapterTitle, chapterUrl, offsetInText, excerpt)`。
  `offsetInText` 是**正文文本内的字符偏移**（与阅读器渲染前的文本同口径），不是已排版页面的偏移。
- 单源预算：整次搜索用一个 `SourceBudget`（聚合搜索同一件东西，ADR-0049 §决策 3），
  预算耗尽即停止并报告「已搜到第 N 章」。

## 决策 3 M20 的**接线范围**（避免「UI 是装饰」）

| 规则 | M20 是否影响阅读 | 说明 |
|---|---|---|
| `replace`（净化） | **是**：正文读取后、写入缓存前，按 `sort_order` 依次应用启用的规则 | 与 `ruleContent.replaceRegex` 同一位置，`replaceRegex` 先跑（源自己的规则优先） |
| `highlight` | **否**（M20 只存不渲染）：高亮需要正文富文本渲染，属阅读器版式 | 列表/编辑/启停可跑；渲染登记 |
| `dict` | **否**：字典是选词查询，M20 没有选词入口 | 同上 |
| `toc` | **否**：`txt_toc_rule` 是本地 txt 导入用的目录识别规则，本仓还没有本地导入 | 同上（与 M21b 的本地导入耦合） |

即：M20 的验收是「四类规则都能列表 + 编辑 + 启停」，**只有净化规则**承诺影响阅读结果；
其余三类的执行接线在各自的前置能力到位时再做（字典要选词、高亮要富文本、目录规则要本地导入）。

## 决策 4 迁移与默认数据

- schema v8 → **v9**：只加 `rules` 表与索引，沿用 ADR-0056 的可重入写法（建表前查 `sqlite_master`）。
- 默认规则（内置净化规则）**不在迁移里插入**：迁移必须只做结构变更；内置规则由仓储在
  「表为空且从未初始化过」时一次性写入，并打上 `is_built_in = 1`。用户删掉其中一条后不再补回
  （`is_built_in` 只表示来源，不代表「受保护不能删」）。

## 后果

- 好的方面：四类规则共用一套 DAO / 列表 / 编辑 / 启停；加字段不改 schema；净化规则从「没有」
  变成「读正文时就生效」。
- 代价：payload 是 JSON，按字段查询（例如「哪些规则的 pattern 命中某个词」）要全表读后在内存里筛；
  规则数量在几十到几百条量级，可接受。另外 JSON 里的类型要自己校验，读坏的行必须显式标坏。
- 未做：字典/高亮/目录规则的执行接线、规则导入导出 UI、搜索的跨书聚合，均登记在
  `docs/dev/roadmap.md` §3.7。
