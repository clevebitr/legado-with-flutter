# 书源规格（对标原版阅读 / Legado）

> 本文档是书源解析的**唯一规格来源**：字段模型、规则语法矩阵、实现分期、失败语义、测试基线。
> 实现约束见 `docs/dev/constraints.md` §5（C-SRC-1..9）；
> 功能范围与分期见 §3.1 与 ADR-0014。
>
> **对标原则：** 支持矩阵逐条对标**原版阅读（Legado）**公开规则说明，
> 不做方言扩展、不自造语法。每条语法的「状态」一律从 `待验证` 起步，
> 只能由**真实书源回归记录**（§11）改为 `已确认`。

---

## 1. 范围

| 目标 | 说明 |
|---|---|
| 兼容 | 直接导入原版阅读的书源 JSON，在不修改规则的前提下完成搜索 → 详情 → 目录 → 正文 |
| 不兼容 | 不实现登录脚本与登录 UI、RSS/订阅源、朗读规则、需要浏览器 DOM 的网页 JS |
| 引擎 | 纯 Dart，无 Flutter 依赖（C-SRC-1）；JS 规则在独立 Isolate 执行（C-SRC-2） |
| 分期 | M0 为「首个可导入版本」的必达范围，见 §3.1 |

---

## 2. 书源 JSON 模型

字段名映射到 Dart 时必须转为 camelCase（`naming.md` §5）。

| 原版字段 | Dart 字段 | 类型 | 分期 | 说明 |
|---|---|---|---|---|
| `bookSourceName` | `name` | `String` | M0 | 必填 |
| `bookSourceUrl` | `url` | `String` | M0 | 必填，参与缓存键 |
| `bookSourceGroup` | `group` | `String?` | M0 | — |
| `bookSourceType` | `sourceType` | `BookSourceType` | M0 | 0 文本 / 1 音频 / 2 图片 / 3 文件 |
| `enabled` | `isEnabled` | `bool` | M0 | 默认 `true` |
| `header` | `headers` | `Map<String, String>?` | M0 | 原为 JSON 字符串，导入时解析 |
| `searchUrl` | `searchUrl` | `String?` | M0 | 支持 `{{key}}` / `{{page}}` |
| `exploreUrl` | `exploreUrl` | `String?` | **M1** | 发现页 |
| `ruleSearch` | `searchRule` | `SearchRule` | M0 | 必填 |
| `ruleBookInfo` | `bookInfoRule` | `BookInfoRule?` | M0 | 缺失时从搜索页继承 |
| `ruleToc` | `tocRule` | `TocRule` | M0 | 必填 |
| `ruleContent` | `contentRule` | `ContentRule` | M0 | 必填 |
| `concurrentRate` | `concurrentRate` | `String?` | **M1** | 并发限速 |
| `variableComment` | `variableComment` | `String?` | **M1** | 书源变量说明 |
| `loginUrl` / `loginUi` / `loginCheckJs` | — | — | **M2** | 登录相关，暂不实现 |
| `lastUpdateTime` / `respondTime` / `weight` / `customOrder` | 同名 | `int?` | M0 | 仅用于展示与排序 |

**子规则字段**（原版字段名 → Dart，全部 camelCase）：

| 规则对象 | 字段 | 分期 |
|---|---|---|
| `SearchRule` | `bookList`、`name`、`author`、`kind`、`wordCount`、`lastChapter`、`intro`、`coverUrl`、`bookUrl` | M0 |
| `BookInfoRule` | `init`、`name`、`author`、`kind`、`lastChapter`、`intro`、`coverUrl`、`tocUrl`、`wordCount`、`canReName` | M0（`canReName` 为 M1） |
| `TocRule` | `chapterList`、`chapterName`、`chapterUrl`、`isVip`、`updateTime`、`nextTocUrl` | M0 |
| `ContentRule` | `content`、`nextContentUrl`、`replaceRegex` | M0 |
| `ContentRule` | `webJs`、`sourceRegex`、`imageStyle` | **M2** |

模型必须使用 `freezed` + `json_serializable`（C-SRC-7）。未知字段必须**保留而非丢弃**：
在 `extra` 中承载，以便导出时不丢信息。

---

## 3. 规则语法支持矩阵（对标原版阅读）

> 「原版适用字段」列取自原版规则说明（原版说明中标注「仅书籍列表和目录列表」的语法
> 才限定字段，其余为**所有字段**可用）。

| # | 语法 | 原版示例 | 原版适用字段 | 分期 | 状态 |
|---|---|---|---|---|---|
| 1 | 默认规则：`类型.名称.位置` | `class.odd.0@tag.a.0@text` | 所有字段 | M0 | 待验证 |
| 2 | 类型 `class` / `id` / `tag` | `id.content@text` | 所有字段 | M0 | 待验证 |
| 3 | 类型 `text`（按文本内容匹配） | `text.最新章节` | 所有字段 | M0 | 待验证 |
| 4 | 类型 `children`（取全部子标签，忽略第二、三段） | `class.list@children` | 所有字段 | M0 | 待验证 |
| 5 | 位置：正索引与负索引（`-1` 为倒数第一） | `tag.li.-1@text` | 所有字段 | M0 | 待验证 |
| 6 | `!` 位置排除（序号用 `:` 分隔，支持负数） | `tag.li!0:1@text` | 所有字段 | M0 | 待验证 |
| 7 | 列表首字符 `-` 使结果**倒置** | `-class.odd@tag.a@href` | 所有字段 | M0 | 待验证 |
| 8 | 提取内容：`text` / `textNodes` / `ownText` / `html` / `all` / `href` / `src`（及其他 HTML 属性名） | `tag.a@href` | 所有字段 | M0 | 待验证 |
| 9 | 正则替换 `##正则##替换内容`（替换为空时可省略第二个 `##`） | `tag.p@text##全文阅读` | 所有字段 | M0 | 待验证 |
| 10 | `\|\|` 依次尝试，首个非空即成功 | `class.odd.0@tag.a.0@text\|\|tag.dd.0@tag.h1@text` | 所有字段 | M0 | 待验证 |
| 11 | `&&` 串联多级 | `class.list&&tag.li@text` | 所有字段 | M0 | 待验证 |
| 12 | `@css:` 标准 CSS 选择器 | `@css:.book-list li@text` | 所有字段 | M0 | 待验证 |
| 13 | `@json:` JSONPath（以 `$.` 开头时可省略标志） | `@json:$.data.list[*].name` | 所有字段 | M0 | 待验证 |
| 14 | `@js:` JavaScript | `@js:result.replace(/\\s/g,'')` | 所有字段 | **M0（受阻）** | 引擎待选型 |
| 15 | `@@` 默认规则标志（在 `{{}}` 内使用时必填） | `@@class.odd.0@text` | 所有字段 | M1 | 待验证 |
| 16 | `@put:{key:rule}` / `@get:{key}`（**仅限 js 以外**的规则；`@put` 内 JSONPath 不加引号，其他规则加引号） | `@put:{bid:"//*[@bid-data]/@bid-data"}` | 所有字段 | M1 | 待验证 |
| 17 | `java.put(key,value)` / `java.get(key)`（**仅限 js 内**，js 中不能使用 `@get`） | — | 所有字段 | M1 | 待验证 |
| 18 | `{{}}` 内嵌规则 / JS（搜索 URL 与发现 URL 内**只能**用 JS；其他位置默认 JS，用其他规则必须带标志头 `@@` / `//` 或 `@xpath:` / `$.` 或 `@json:` / `@css:`） | `{{result.match(...)}}` | 所有字段 | M1 | 待验证 |
| 19 | `{}`（阅读 2.0 遗留规则，**只能**用 JSONPath，应尽量避免） | `{$.data.name}` | 所有字段 | M1 | 待验证 |
| 20 | `:正则规则`（不可省略标志；**仅书籍列表与目录列表**） | 待按原版实现确认 | 仅书籍列表、目录列表 | **M2** | 待验证 |
| 21 | `@xpath:` XPath（以 `//` 开头时可省略标志） | `@xpath://div[@id='a']/text()` | 所有字段 | **M2** | 不支持 |
| 22 | `@webJs` 网页 JS | — | 正文规则 | **M2** | 不支持 |
| 23 | `sourceRegex` 源码正则 | — | 正文规则 | **M2** | 不支持 |
| 24 | 字体反爬字形映射 | — | 正文替换规则 | **M2** | 不支持 |

**大小写处理：** 原版文档同时出现 `@css:` / `@CSS:`、`@json:` / `@Json:` 等写法。
本项目按**前缀大小写不敏感**实现，并为每种前缀补一条测试（状态：待验证）。

### 3.1 实现分期（对齐 ADR-0014）

| 阶段 | 范围 | 完成判定 |
|---|---|---|
| **M0** | 矩阵 #1–#14；搜索 / 详情 / 目录 / 正文四段完整字段；`nextTocUrl`；`nextContentUrl`；`{{key}}`、`{{page}}`、`{{baseUrl}}` | 至少 2 个真实书源完成「搜索 → 详情 → 目录 → 正文」离线回放 |
| **M1** | 矩阵 #15–#19；`exploreUrl` 发现页；`canReName`；`isVip`；`java.timeFormat`；`concurrentRate` | 每条语法至少 1 条真实书源验证记录 |
| **M2 / 暂不实现** | 矩阵 #20–#24；登录脚本与登录 UI；RSS / 订阅源；朗读规则 | 命中时返回 `ParseFailure(unsupportedRule)` |

**M0 未全部通过前，不得发布「支持导入书源」的版本。**
命中 M2 或任何未实现语法时，禁止静默返回空结果（C-SRC-4）。

### 3.2 解析顺序

```
原始规则串
  → 按 `||` 切分候选（依次尝试，首个非空即成功）
    → 每个候选按 `&&` 切分为多级
      → 每级：识别前缀标志（@@ / @css: / @json: / @js: / @xpath: / 默认）
        → 按 `@` 分段：类型段（可多段） → 提取段
        → 应用位置、负索引、`!` 排除、首字符 `-` 倒置
        → 取出内容（text / textNodes / ownText / html / all / 属性）
  → 最后按顺序应用所有 `##` 替换
```

### 3.3 默认规则的段结构（原版语义）

| 段 | 说明 |
|---|---|
| 第 1 段 | 类型：`class` / `id` / `tag` / `text` / `children` 等；`children` 取全部子标签，**忽略第 2、3 段** |
| 第 2 段 | 名称；`text` 类型时表示「文本内容的一部分」 |
| 第 3 段 | 位置：正索引从 0 开始，负数取倒序；不加位置表示取全部 |
| 末段 | 提取内容：`text` / `textNodes` / `ownText` / `html` / `all` / `href` / `src` 等，或 HTML 属性名 |

---

## 4. URL 模板与变量

渲染必须统一经 `renderUrlTemplate`（C-SRC-5），禁止手写拼接。

| 变量 | 适用位置 | 含义 | 分期 |
|---|---|---|---|
| `{{key}}` | `searchUrl` | URL 编码后的搜索关键词 | M0 |
| `{{page}}` | `searchUrl`、`nextTocUrl`、`nextContentUrl` | 页码，从 1 开始 | M0 |
| `{{baseUrl}}` | 全部 | 当前页 URL（JS 中同名变量） | M0 |
| `{{}}` 内嵌规则/JS | 其他字段 | 默认按 JS 求值，见矩阵 #18 | M1 |
| `{{变量名}}` | 全部 | `@put:` / `@get:` 读写的变量 | M1 |

约定：

- 关键词**必须** URL 编码，且只编码一次、不重复编码。
- 相对 URL（以 `/` 或非协议开头）必须以当前页 URL 为基准解析为绝对 URL。
- 未定义的变量渲染为**空字符串**并记录 warning；不得保留 `{{...}}` 原文。
- 在**搜索 URL 与发现 URL** 中，`{{}}` 内只允许 JS；解析器必须拒绝在其中写非 JS 规则。

### 4.1 目录与正文的特殊规则

| 规则 | 原版语义 | 分期 |
|---|---|---|
| `chapterList` | 结果列表；**首字符 `-` 使列表反序** | M0 |
| `chapterName` / `chapterUrl` | 章节名与章节 URL（相对路径需转绝对） | M0 |
| `isVip` | 结果为 `null` / `false` / `0` / `""` 时视为**非 VIP** | M0 |
| `updateTime` | 可调用 `java.timeFormat(timestamp)` 转为 `yyyy/MM/dd HH:mm` | M1 |
| `nextTocUrl` | 支持**单个 URL** 或 **URL 数组**；JS 返回 `[]` / `null` / `""` 时停止加载下一页 | M0 |
| `content` | 正文内容；可含多个 `##` 替换 | M0 |
| `nextContentUrl` | 正文分页；返回空即停止 | M0 |
| `replaceRegex` | 正文的批量替换规则 | M0 |
| `canReName` | 允许重命名书籍 | M1 |

---

## 5. 编码

- 必须使用 `betto_charset_detector` 检测（C-NET-3），检测顺序：
  HTTP `Content-Type` → HTML `<meta charset>` → 字节嗅探 → 回退 UTF-8。
- 检测结果必须缓存到「书源 ID + URL」维度，避免重复嗅探。
- 解码失败返回 `ParseFailure(encodingFailed)`，
  禁止用 `utf8.decode(allowMalformed: true)` 静默吞掉。

---

## 6. JS 桥接白名单与配额

JS 规则运行在独立 Isolate 中，**只能**访问以下绑定（C-SRC-3）：

> ⚠️ **引擎未定：** 下表所列绑定已在 `flutter_js_plus` 上实测可行（含后台 Isolate 中的回调桥），
> 但该库本身不可用，引擎选型待裁决（ADR-0008 已标为部分失效）。见 `tool/spike/README.md`。
> 另：**5 秒超时必须由调用方用 `Isolate.kill` 实现**（引擎 `timeout` 参数实测无效），
> **32 MB 内存上限不可实现**，需在 ADR 中记录降级方式。

| 绑定 | 形态 | 说明 | 分期 |
|---|---|---|---|
| `baseUrl` | `String` | 当前页 URL（原版同名变量） | M0 |
| `result` | `String?` \| `List` | 当前页 responseBody（原版同名变量） | M0 |
| `page` | `int` | 当前页码 | M0 |
| `source` | 只读对象 | 仅 `name`、`url`、`group`，其余不可见 | M0 |
| `http.get(url, options)` | `String` | 经 `core/network/HttpClient` 代理，受超时与重试策略约束 | M0 |
| `http.post(url, options)` | `String` | 同上 | M0 |
| `parse.getString(rule, doc)` | `String` | 复用规则引擎，可递归 | M0 |
| `parse.getElements(rule, doc)` | `List` | 同上 | M0 |
| `java.put(key, value)` / `java.get(key)` | `void` / `Object?` | 与原版一致：**仅 JS 内可用** | M1 |
| `java.timeFormat(timestamp)` | `String` | `yyyy/MM/dd HH:mm` | M1 |
| `log.debug/info/warn/error(msg)` | `void` | 转发到 `core/logging`，自动附加 `rulePath` | M0 |
| `crypto.md5/sha1/base64Encode/base64Decode` | `String` | 纯计算 | M0 |

**禁止暴露：** 文件系统、进程、环境变量、Socket、定时器、原生绑定、
`eval` 之外任意代码加载、`source` 的完整对象（防信息外泄）。

**配额（必须实现）：**

| 项 | 默认值 |
|---|---|
| 单次 JS 墙钟超时 | 5 秒 |
| 单次 JS 内存上限 | 32 MB |
| 单条规则内 JS 调用次数 | ≤ 20 |

超时或异常 → `ParseFailure(parseFailed)`，`rulePath` 中标注 `js:timeout` 或 `js:error`。

---

## 7. 失败语义

| `ParseFailureKind` | 触发条件 | ARB 文案键 | 可重试 |
|---|---|---|---|
| `networkTimeout` | 连接/读取超时 | `failureNetworkTimeout` | 是 |
| `networkFailed` | DNS/连接失败、5xx | `failureNetworkFailed` | 是 |
| `networkForbidden` | 403 | `failureNetworkForbidden` | 否 |
| `notFound` | 404 | `failureNotFound` | 否 |
| `encodingFailed` | 编码检测或解码失败 | `failureEncodingFailed` | 否 |
| `parseFailed` | 规则无匹配、JS 异常或超时 | `failureParseFailed` | 否 |
| `unsupportedRule` | 命中 M2 或未实现语法 | `failureUnsupportedRule` | 否 |
| `invalidBookSource` | 导入 JSON 缺必填字段或结构非法 | `failureInvalidBookSource` | 否 |
| `cancelled` | 用户主动取消 | 无（静默） | — |

**关键判定：**

- 「规则无匹配」与「成功但结果为空」必须区分：
  - 顶层 `bookList` / `chapterList` / `content` **无匹配** → `parseFailed`。
  - 顶层匹配成功但集合为空 → **成功**，返回空列表（搜索无结果属正常业务）。
- 失败必须携带 `rulePath`（C-SRC-8），格式 `<字段名>` 或 `<字段名>.<子字段>`，
  例如 `searchRule.bookList`、`tocRule.chapterUrl`、`contentRule.content`；
  命中未实现语法时用 `unsupported:<语法名>`，例如 `unsupported:@xpath:`。
- 失败对象**禁止**携带用户可见文案（C-ERR-7）。

---

## 8. 并发与限速

| 项 | 值 | 分期 |
|---|---|---|
| 同一书源默认并发上限 | 3 | M0 |
| `concurrentRate` 覆盖 | 按书源声明解析 | M1 |
| 章节正文批量下载 | 必须串行或有限并发，禁止对单一域名无限并发 | M0 |
| 缓存键 | `书源 ID + 规则字段 + URL + 页码` 的稳定哈希，必须带 TTL（C-NET-6） | M0 |

---

## 9. 错误恢复

| 场景 | 行为 |
|---|---|
| 单章正文失败 | 该章标记失败，不中断整本书的目录展示 |
| 目录缺页 | 按 `nextTocUrl` 翻页，最多 50 页后停止并记录 warning |
| 规则失效（0 结果） | 记录到书源健康度统计，UI 提示「规则可能已失效」 |
| 书源整站改版 | 不做自动适配；由用户更新书源 |

---

## 10. 测试基线与回归

| 项 | 要求 |
|---|---|
| 固定语料 | `test/fixtures/book_sources/*.json`（书源）+ `test/fixtures/html/*.html`（已抓取页面） |
| 语法单测 | §3 矩阵中每个 **M0** 语法至少 1 条单测；M1 语法在实现时同步补 |
| 前缀大小写 | `@css:`/`@CSS:`、`@json:`/`@Json:`、`@js:`/`@JS:` 各 1 条 |
| 失败单测 | §7 表中每个 `ParseFailureKind` 至少 1 条单测 |
| 链路测试 | 至少 2 个书源完成「搜索 → 详情 → 目录 → 正文」离线回放 |
| M2 拒绝测试 | `@xpath:` 与 `:` 正则规则各 1 条，断言返回 `unsupportedRule` |
| 真实书源验证 | 每个 M0/M1 语法行需在 PR 中附验证记录，并把状态列改为「已确认」 |
| 网络隔离 | 单元测试禁止真实联网；`HttpClient` 必须可注入替身（C-NET-8） |

真实书源验证记录格式（写入 PR 描述）：

```
语法：#11 &&
书源：<name> (<url host>)
链路：搜索 → 目录 → 正文
结论：已确认 / 行为差异：<描述> → 已更新矩阵
```

---

## 11. 明确不支持（M2）

命中以下任一语法必须在导入或解析时明确拒绝并给出可读提示，不得假装成功：

- `@xpath:` XPath 规则（需要引入 XPath 依赖，须先开 ADR）
- `:` 正则规则（仅书籍列表与目录列表）
- `webJs`、`sourceRegex`、字体反爬字形映射
- 原版的登录脚本、登录 UI、登录检查 JS
- RSS / 订阅源、朗读规则
- 需要浏览器 DOM/BOM 的网页 JS、依赖 Android WebView 行为的规则

---

**文档版本：** v1.0（对标原版阅读；语法行状态仍为待验证，需真实书源回归后逐行确认）
**最后更新：** 2026-10-10
