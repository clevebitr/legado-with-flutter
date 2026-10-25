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

### §9 规则管理 UI 的形态（M20-c 落地时确定）

- **一条 kind 一页**：`RulesRoute.list(kind)` → `RulesListPage`，四类共用同一页与同一套操作
  （启停开关 / 拖动排序 / 删除 / 点击进表单）；kind 只影响标题与行摘要，所以不会出现「四份会各自漂移的列表」。
- **表单按 kind 分支，字段之外的东西一律保留**：`RuleEditPage` 只呈现当前 kind 拥有的字段，
  保存时把 `timeoutMs`（净化）与 payload 的 `extra`（四类都可能有）原样写回——这正是 §决策 1
  「未知键必须保留」在 UI 上的落地方式。
- **入口在「我的」**：`AppNavigation` 增加四个方法（`openReplaceRules` / `openTocRules` /
  `openDictRules` / `openHighlightRules`）。四个方法而不是一个带 kind 参数的方法：端口只收发原语
  （ADR-0042），字符串 kind 会把一个 switch 搬进每个实现。
- **排序会改净化结果**：`RuleRepository.reorder` 把整类重新编号为 `0..n-1`，并对 `replace`
  触发一次正文缓存作废（与 §7 同一理由）。
- **表单的两条前置校验**（超前于执行期降级，执行期仍按 `ContentPurifier` 的规则跳过）：
  正则表达式必须能编译、高亮颜色必须是 `#RRGGBB` / `#AARRGGBB`。名字与各 kind 的必填表达式不能为空。
- **坏 payload 可修**：表单显示「这条规则存的内容读不懂」+ 原文，用户填好一份合法内容保存即替换它
  ——与 §决策 1「允许删除 / 编辑」一致，而不是把它藏掉。

### §10 书内搜索的落点（M20-d 实现时确定）

§决策 2 的语义不变（当前章起顺序预取、并发 2、可停、命中带章节与偏移），实现落点如下：

- **用例在 `reader`**：`SearchInBook` 只依赖 `ChapterContentProvider`（阅读器已有的端口），
  所以「发请求」这件事仍然全在 `book_source`，速率门与 `HttpPolicy` 原样生效（礼貌性这件事本来就归 `book_source`，`book-source.md` §8）。
- **预算自己量，不借 `SourceBudget`**：后者属 `book_source/domain`，跨 feature 不能 import
  （C-ARCH-2）。这里用注入的 `Clock` + 一个 `Duration budget`（默认 **2 分钟**，与聚合搜索 60 s、
  校验 180 s 同一量级），用完即以 `budgetSpent` 停下，已找到的命中仍然是真的。
- **窗口式顺序预取**：每窗最多 `concurrency`（2）章，`Future.wait` 之后按章序产出命中。
  不是滑动窗口——慢的一章会拖住它的同伴，换来的是顺序与「最多 2 个在飞」这两件事一眼可验。
- **`cancel()` 停新请求、丢弃在途结果**：先发出去的请求照样 await，但结果不再进列表；
  它们取的正文留在正文缓存里（正常阅读也会写进去，不算副作用）。开关放在**下一个微任务**上，
  所以 `execute` 之后立刻 `cancel()` 一个请求都不会发出。
- **命中粒度按上游**：一次匹配一条命中（上游 `SearchContentRepository` 同样逐条给结果），
  但**每章最多 20 条**——一章重复 100 次同一个词不是 100 个目的地。`excerpt` 保留匹配两侧各 40
  字符并把换行压成空格；`offsetInText` 用 `RegExp(caseSensitive: false)` 在**原串**上求位置，
  不用 `toLowerCase` 双串比较（后者在 `İ` 这类字符上会改长度、把偏移整体挪位）。
- **读不出来的章节不吞掉**：计入 `failedChapters`，跑完时 UI 明确说「有 N 章读取失败」，
  而不是让「没搜到」和「没读到」长得一样。
- **UI 是一个 sheet**（`ReaderSearchSheet`，入口在阅读器 AppBar 的搜索按钮）：点命中时把
  `hit.offsetInText` 当 `charOffset` 交给 session，与书签跳转同一套机制（ADR-0066 §决策 7），
  因此落在那一句而不是章首。关掉 sheet 即 dispose notifier → 取消搜索。

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
- `lib/app.dart`：`appProviderOverrides()` 绑定两个端口（`_PurgeRuleSource` / `_ChapterBodyInvalidator`）；
  页面表登记 `RulesRoute` 的两条路由。
- `lib/features/rules/presentation/`（M20-c）：`rules_route.dart`、`rules_strings.dart`、
  `notifiers/rules_list_notifier.dart`（kind 家族，写后重载）、`pages/rules_list_page.dart`、
  `pages/rule_edit_page.dart`。
- `lib/core/router/app_navigation.dart` + `lib/features/shell/.../my_page.dart`：「我的」的四个规则入口。
- `lib/core/storage/rule_dao.dart`：`byId` / `updateSortOrder`。
- `lib/features/reader/domain/usecases/search_in_book.dart` + `domain/entities/book_search.dart`（M20-d）：
  `SearchInBook`、`BookSearchSession`、`BookSearchHit` / `BookSearchProgress` / `BookSearchStop`。
- `lib/features/reader/presentation/notifiers/book_search_notifier.dart` +
  `presentation/widgets/reader_search_sheet.dart` + `pages/reader_page.dart`（AppBar 入口与
  `charOffset` 跳章）。
