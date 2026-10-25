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
- 默认规则**不在迁移里插入**：迁移必须只做结构变更；内置规则由仓储在
  「表为空且从未初始化过」时一次性写入，并打上 `is_built_in = 1`。用户删掉其中一条后不再补回
  （`is_built_in` 只表示来源，不代表「受保护不能删」）。
- **播种哪些内置规则**（2026-10-24 修正本节，见文末增补 §5）：照上游资产 `txtTocRule.json` /
  `dictRules.json`，**只有目录规则与字典规则**；净化与高亮**不播种**。原文写的「内置净化规则」
  与上游事实不符，已撤销。

## 后果

- 好的方面：四类规则共用一套 DAO / 列表 / 编辑 / 启停；加字段不改 schema；净化规则从「没有」
  变成「读正文时就生效」。
- 代价：payload 是 JSON，按字段查询（例如「哪些规则的 pattern 命中某个词」）要全表读后在内存里筛；
  规则数量在几十到几百条量级，可接受。另外 JSON 里的类型要自己校验，读坏的行必须显式标坏。
- 未做：字典/高亮/目录规则的执行接线、规则导入导出 UI、搜索的跨书聚合，均登记在
  `docs/dev/roadmap.md` §3.7。

## 增补（2026-10-24，M20-b 开工前的四项裁决）

§决策 1–3 不变（表结构 / payload 形状 / 搜索语义 / 接线范围均已实现或已定稿）。以下四项是
开工时暴露、必须由用户裁决的空白，裁决结果取代对应原文：

### §5 播种哪些内置规则：只播目录与字典，净化不播

本文 §决策 4 原文写「内置净化规则」，但上游 `app/src/main/assets/defaultData/` 里**没有**
默认净化规则：随包数据只有 `txtTocRule.json`（目录规则 8 条）与 `dictRules.json`（百度汉语 /
海词英文两条），净化与高亮在上游一律由用户自建。凭空发明净化规则会把用户的正文改掉且无从解释
（「这条规则哪来的？」），所以：

| kind | 是否播种 | 来源 |
|---|---|---|
| `toc` | **是** | 上游 `txtTocRule.json` 原样移植（`serialNumber` → `sortOrder`） |
| `dict` | **是** | 上游 `dictRules.json` 原样移植 |
| `replace` | **否** | 无上游默认数据；首次打开列表为空是正确状态 |
| `highlight` | **否** | 同上 |

种子文件的许可：两者都是上游项目（GPL-3.0）自己的数据资产，与本仓同许可，不需要新增白名单
（C-DEP-7 只约束**依赖**）；随包位置与 `assets/legal/` 一致，在 `pubspec.yaml` 的 `assets:` 登记。

### §6 规则管理是一个**新 feature**（`lib/features/rules/`）

按 `architecture.md` §1 的判据，四类规则既不属于书源（`dict` / `highlight` / `toc` 与书源无关），
也不属于设置（它们是内容语义，且数据源是 Drift 而不是 `shared_preferences`），因此新建
`features/rules/`（`data/` + `domain/` + `presentation/` + `di.dart`），目录一并登记到
`architecture.md` §1 的 feature 列表。

跨 feature 的两件事**只走 ADR-0041 的端口机制**，`rules` 不被 `book_source` / `reader` import：

| 需求 | 端口在哪 | 谁绑定 |
|---|---|---|
| 正文净化要读启用的 `replace` 规则 | `book_source/domain/` 定义端口，默认实现返回空表 + warning | 装配根 `app.dart` 的 `appProviderOverrides()` |
| 规则变更后作废已缓存正文 | 同上（端口同时暴露「规则版本」，见 §7） | 同上 |

### §7 净化位置不变，但**规则一变就作废旧正文**

净化仍在「`replaceRegex` 之后、写缓存前」（§决策 3），所以缓存里存的是成品正文。这样做的代价是
「改规则对已缓存章节不生效」，用户调好一条净化后看不出变化。裁决：**保持写入位置，改为在规则
变更时作废正文缓存**。

- 触发条件：`replace` 规则的**新增 / 编辑 / 删除 / 启停 / 排序**任一项成功写入。
- 作废范围：**整张缓存表**（`CacheDao.deleteAll()`，经 `ContentCache.clearAll()`）。原计划是「只删
  `ruleField = content` 的条目」，**实际做不了**：`cache_entries` 的主键是
  `sha256(书源 ID, ruleField, URL, 页码)`，没有 `rule_field` 列，按字段删要么加列 + v10 迁移，要么扫全表
  重算摘要——两条都不如「整表清空 + 字符集重新探测一次」划算。代价只是书源信息 / 目录要重下一次。
- 不做「只删受影响的章节」：规则是全局表达式，命中面无法先验确定，按「全清缓存」处理最省且
  不会留下错的一章。
- 因此 `reading_progress` / 书签的字符偏移可能与新正文不再逐字对应（净化改变长度）；这与 5.3 登记
  「进度是比例估算」同一量级，不另开机制。

**净化规则本身的已知差异（本轮登记，不做）：**

| 项 | 为什么不做 | 重开触发条件 |
|---|---|---|
| `replacement` 以 `@js:` 开头（上游逐匹配跑脚本） | 要把沙箱搬进正文净化路径，并且每个匹配一次 `JsJob`，成本与 `js:quota` 语义都要重新裁决 | 语料或用户反馈出现「必须用脚本改写匹配文本」的真实规则；届时按 `replaceRegex` 的 `@js:` 通道复用 |
| 正则超时（上游 `timeoutMillisecond`，默认 3000，超时禁用该规则） | Dart 的 `RegExp` 没有超时 API，只能整段丢进 isolate + 强制 kill | 出现「用户写的正则把正文净化卡死」的实例；现阶段用上游 `isValid()` 的两条静态拦截（语法错、以未转义 `|` 结尾） |
| 上游的逐行 trim（`ContentProcessor.getContent` 先 `lines().trim()`） | `PageFetchService.replaceContent` 已经裁定这是阅读器排版的事、不在解析层做 | 读者反馈「正文空行 / 行首空格很多」且不属于源本身的问题 |

### §8 G6 维持登记不做（2026-10-24 复核）

用户复核了 ADR-0069「登记差异」里的 G6（同步 `java.post/get/ajax` 响应对象）：**维持登记**，不做
确定性重放。理由：该缺口本轮只有 `📷🔞小姐姐写真` 一条源命中，重放会改 job 执行语义
（脚本多次运行、`java.put` / `log` 重复、`js:quota` 计数重定义），属独立一轮设计与验收；
真要做时的触发条件仍是 ADR-0069 的那一条（出现只能靠同步响应对象、改写不了的真实源）。

## 影响（增补）

- `lib/features/rules/`（新）：`domain/entities/rule.dart`（四类 payload 类型化 + 坏 payload 标记）、
  `domain/repositories/rule_repository.dart`、`data/rule_repository_impl.dart`、
  `data/rule_seed_loader.dart`（读 `assets/rules/*.json`）、`di.dart`。
- `assets/rules/txt_toc_rule.json` / `assets/rules/dict_rule.json`（新）：来自上游的种子数据。
- `lib/features/book_source/domain/purge_rules_port.dart`（新）：消费方端口 + null object。
- `lib/features/book_source/domain/usecases/fetch_content.dart`：`replaceRegex` 之后、写缓存前按
  `sortOrder` 应用启用的净化规则。
- `lib/features/book_source/domain/content_cache.dart` + `data/cache_dao_content_cache.dart` +
  `lib/core/storage/cache_dao.dart`：新增「清空缓存」能力（C-ARCH 无新增，见 §7 的修正）。
- `lib/features/book_source/domain/content_purifier.dart`（新）：净化规则的执行点与降级策略。
- `lib/app.dart`：`appProviderOverrides()` 绑定两个端口（`_PurgeRuleSource` / `_ChapterBodyInvalidator`）。
