# ADR-0072 M22-a：按源缓存、Cookie 管理、loginUi 登录表单

- **状态：** Accepted（2026-10-25，用户裁决：M22 第一批 = 按源缓存 + Cookie 管理 + loginUi 表单；
  备份照上游 zip + 每表一个 JSON；新依赖按需逐个 ADR；loginUi 按上游描述渲染）
- **日期：** 2026-10-25
- **关联：** `docs/dev/ui-gap.md` §3 U8 / U15、§4 M22；ADR-0056（迁移可重入）、ADR-0068（M21a 的登录字段）、
  ADR-0034（规则变量「随 job 快照、随结果回写」）、ADR-0055、C-NET-9、C-SEC-1/4、`docs/dev/book-source.md` §2/§6/§11

## 背景

M22（M21b）一次覆盖七件事，用户裁决先做「按源缓存 + Cookie 管理 + loginUi 表单」。上游的行为是：

| 项 | 上游落点 | 上游行为 |
|---|---|---|
| 缓存管理 | `ui/book/cache/manage/BookCacheManageScreen.kt`、`BookHelp.clearCache()` / `clearCache(book)` | 缓存是**文件**，按书分目录；清理粒度是「全部」与「按书」，**没有**按源 |
| Cookie | `BookSourceEditViewModel.clearCookie()`、`BaseSource.enabledCookieJar` | 只有「编辑源时清掉这个源的 Cookie」与一个开关，**没有**列表页 |
| 登录表单 | `ui/login/SourceLogin*`、`data/entities/rule/RowUi.kt`、`BaseSource.getLoginInfo*/putLoginInfo` | `loginUi` 是 JSON 数组（可本身是 `@js:`/`<js>`），按 `type`（text/password/toggle/select/button）渲染；字段值组成 `loginInfo` map 存起来；确认时跑 `loginUrl` 里的 `login()`，`result` 绑定就是这个 map |

三件事在本仓都还没有：缓存只能按书（`cache_entries.scope_key`），Cookie 只有端口没有页面，
`loginUi` 只存不渲染（`book-source.md` §11 明确登记为「不做」）。

## 决策 1 按源缓存 = 给 `cache_entries` 加 `source_key`，升级时清空旧缓存

- 新增第 10 版：`cache_entries.source_key TEXT`（书源 ID 的 sha256，与 `cache_key`/`scope_key` 同一套摘要写法）
  + 索引 `cache_entries_source`。写入正文缓存时一并写入；读仍只按 `cache_key` 命中（列不参与键）。
- **迁移顺手清空缓存表**：旧行的 `source_key` 无法从摘要反推，留着会让「按源统计」在 12 小时 TTL 内显示
  一个偏小的数——而缓存本来是可再生数据，清空比显示错数诚实。迁移仍按 ADR-0056 的可重入写法（先查列/索引）。
- 页面（`book_source` feature，因为它同时认识书源与缓存）：「缓存管理」列出**每个书源**的缓存章数、
  可单独清理该源、可清理过期、可清空全部，并给出总量。上游没有「按源」这个粒度，这是本仓的增强
  （`roadmap.md` §3.7 早先就登记为 5.7②）。
- 不合并设置页里已有的「清空缓存」：那里是全局一键，这里是按源与过期，两个粒度各自成立。

## 决策 2 Cookie 管理页：能看能删，**不显示值**

- 上游只有「编辑源时清掉该源 Cookie」，本仓做一个列表页（`settings` feature，属系统项）：
  按域分组列出 `域 / 名称 / 过期时间`，支持删除单条、删除整域、清理过期、清空全部。
- **不显示 Cookie 的值**：那是会话凭据，列表页把它印在屏幕上没有用处，只增加肩窥与截图泄漏面（C-SEC-4 的同一立场）。
  需要排障时看「有没有这条、什么时候过期」就够了。
- 逐条删除用 `(domain, path, name)` 三元组（表上的唯一键），不是行 id：列表里的一行就是一条 Cookie 的身份。
- **每书源 Cookie 隔离**仍不做（`roadmap.md` §3.7 已登记，触发 = 出现「两个源同域但需要不同会话」的真实需求）；
  本页因此是**全局按域**视图，不是按源视图。

## 决策 3 loginUi 表单照上游渲染，登录信息按源存一份明文快照

字段形状（`RowUi`，本 ADR 是唯一出处）：

```json
[{"name":"账号","type":"text","viewName":"'账号'"},{"name":"密码","type":"password"},
 {"name":"线路","type":"select","chars":["A","B"]},{"name":"记住","type":"toggle"},
 {"name":"登录","type":"button","action":"..."}]
```

- `loginUi` 本身可以是 `@js:` / `<js>`：先跑一段脚本（前置 `loginUrl` 里的脚本），脚本产出上面那个数组。
- `viewName` 是**展示标题**：`'带引号的字面量'` 直接用，否则当脚本求值（`result` = 当前登录信息）；
  求不出来就退回 `name`。
- `type` 缺省是 `text`；`select` 用 `chars` 做选项；`toggle` 是布尔；`button` 不参与取值，
  点它时把 `action` 当脚本跑（以 `@js:` 之外的形式给出时按脚本拼在上游 `loginJs` 之后），
  或直接打开 URL（`action` 是绝对地址时）。
- **值收集**：所有非 `button` 行组成 `loginInfo` map（`name → 值`）。确认时：保存这份 map，然后执行
  `loginUrl` 定义的那段脚本 + `if (typeof login=='function'){ login.apply(this) } else { throw ... }`，
  `result` 绑定就是这份 map（与上游 `SourceLoginViewModel.confirm` 同形）。
- **存储**：新增 `login_info` 文本列（**第 11 版**；原计划并进 v10，但 v10 已提交过，改历史版本会让已经升到 v10 的库永远补不上这一列——ADR-0056 的同一教训），按源存 JSON。
  上游用 `androidId` 派生密钥 AES 加密；本仓**明文存本机数据库**，与 v8 起就明文存的 Cookie 罐同一级别，
  登记差异（触发 = 引入 `flutter_secure_storage` 或系统密钥库封装时一并改）。
- **沙箱面**：脚本通过 `source.getLoginInfo()` / `source.getLoginInfoMap()` 读这份快照。
  沙箱是独立 isolate、不能同步回调宿主，所以沿用 ADR-0034 的机制——**快照随 `JsJob` 进、写在结果里回**：
  `getLoginInfo*` 读的是本次 job 的登录信息快照，需要改登录信息时用 `java.put` 之外的既有通道（本批不做写回）。
  `source.putLoginHeader(...)` / `java.upLoginData` / 动态 `viewName` 之外的 UI 交互**登记不做**。
- 入口：书源列表行菜单里的「登录」（`loginUrl`/`loginUi` 有声明时才可点）。

## 后果

- 好的方面：手机空间有了「按源」这个可操作粒度；Cookie 终于能看能删；`loginUi` 不再是死字段，
  带原生登录表单的源第一次可用；登录信息与它的沙箱读取面沿用既有机制（快照 + 回写），没有新概念。
- 代价：v10 迁移会清空正文缓存（一次性的、可再生的）；登录信息明文存库（与 Cookie 同级，已登记）。
- 未做（登记 `roadmap.md` §3.7）：每书源 Cookie 隔离、登录信息的加密存储、`putLoginHeader`/`upLoginData`、
  自动填充与多账号切换、WebDAV 备份（M22-b）。

## 实现注记（2026-10-25 落地时补充）

- **沙箱面只覆盖登录自己的 job**：`source.getLoginInfo()` / `getLoginInfoMap()` 读的是随 job 进来的
  快照，本批只在「解析 `loginUi` / 求值 `viewName` / 跑 `login()` / 跑按钮 `action`」这几个 job 上喂了它。
  页面请求的 job（`loginCheckJs` 拦截器、字段规则）**暂时还读不到**——那要把登录信息一路传到
  `PageFetchService` 造的每个 job 上，登记在 `roadmap.md` §3.7。
- `loginUrl` 的三种形态（`@js:` / `<js>` / 裸脚本）由 `loginScriptOf` 统一判定；**裸地址**不算脚本，
  那是浏览器那条路，登录页只在源的 `loginUrl` 确实是脚本时才跑 `login()`。
- 列表行的「登录」入口分两路：源声明了 `loginUi` → 原生表单页；只有 `loginUrl` → 可见 WebView。
  表单为空（例如 `loginUi: "[]"`）时页面明说「这个书源没有声明登录表单」。
- 提交顺序照上游：**先存值再跑脚本**，所以脚本里的 `source.getLoginInfo()` 与下一次取页看到的是同一份值；
  脚本失败也保留已存的值，下一次重试不用重填。
- 按钮行的 `action` 是绝对地址时交给浏览器（沙箱的 `open` 打不开页面），否则按脚本拼在 `login()` 之后跑。
