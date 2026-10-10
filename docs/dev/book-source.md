# 书源规格（Legado 兼容）

> 本文档是书源解析的**唯一规格来源**：字段模型、规则语法、支持矩阵、失败语义、测试基线。
> 实现约束见 `docs/dev/constraints.md` §5（C-SRC-1..9）。
>
> **验证状态：** 本矩阵为项目采用的**目标方言**。每一行在实现前必须用真实书源回归验证
> （见 §10），验证结论回写到本表「状态」列。状态取值：`已确认` / `待验证` / `不支持`。

---

## 1. 范围

| 目标 | 说明 |
|---|---|
| 兼容 | 能直接导入 Legado 公开书源 JSON，并在不修改规则的前提下完成搜索→详情→目录→正文链路 |
| 不兼容 | 不实现 Legado 的 UI 扩展、登录脚本引擎、朗读规则、RSS 规则、订阅源 |
| 引擎 | 纯 Dart，无 Flutter 依赖（C-SRC-1）；JS 规则在独立 Isolate 执行（C-SRC-2） |

---

## 2. 书源 JSON 模型

字段名映射到 Dart 时必须转为 camelCase（`naming.md` §5）。

| Legado 字段 | Dart 字段 | 类型 | 说明 |
|---|---|---|---|
| `bookSourceName` | `name` | `String` | 必填 |
| `bookSourceUrl` | `url` | `String` | 必填，作为缓存键的一部分 |
| `bookSourceGroup` | `group` | `String?` | — |
| `bookSourceType` | `sourceType` | `BookSourceType` | 0 文本 / 1 音频 / 2 图片 / 3 文件 |
| `enabled` | `isEnabled` | `bool` | 默认 `true` |
| `header` | `headers` | `Map<String, String>?` | 原为 JSON 字符串，导入时解析 |
| `concurrentRate` | `concurrentRate` | `String?` | 并发限速，P1 |
| `searchUrl` | `searchUrl` | `String?` | 支持 `{{key}}` / `{{page}}` |
| `exploreUrl` | `exploreUrl` | `String?` | 发现页，P1 |
| `ruleSearch` | `searchRule` | `SearchRule` | 必填 |
| `ruleBookInfo` | `bookInfoRule` | `BookInfoRule?` | 缺失时详情页从搜索页继承，P1 |
| `ruleToc` | `tocRule` | `TocRule` | 必填 |
| `ruleContent` | `contentRule` | `ContentRule` | 必填 |
| `lastUpdateTime` / `respondTime` / `weight` | 同名 | `int?` | 仅用于展示与排序 |
| `customOrder` | `customOrder` | `int` | 默认 0 |
| `variableComment` | `variableComment` | `String?` | P1 |

**子规则字段：**

| 规则对象 | 字段 | 状态 |
|---|---|---|
| `SearchRule` | `bookList`、`name`、`author`、`kind`、`wordCount`、`lastChapter`、`intro`、`coverUrl`、`bookUrl` | 待验证 |
| `BookInfoRule` | `init`、`name`、`author`、`kind`、`lastChapter`、`intro`、`coverUrl`、`tocUrl`、`wordCount`、`canReName` | 待验证 |
| `TocRule` | `chapterList`、`chapterName`、`chapterUrl`、`isVip`、`updateTime`、`nextTocUrl` | 待验证 |
| `ContentRule` | `content`、`nextContentUrl`、`webJs`、`sourceRegex`、`replaceRegex`、`imageStyle` | 待验证 |

模型必须使用 `freezed` + `json_serializable`（C-SRC-7）。未知字段必须**保留而非丢弃**：
使用 `@JsonKey(includeFromJson: false)` 之外的旁路 `extra` 字段承载，以便导出时不丢信息。

---

## 3. 规则语法支持矩阵

| # | 语法 | 示例 | 优先级 | 状态 |
|---|---|---|---|---|
| 1 | 默认 CSS 选择器 | `class.book-list@tag.li` | P0 | 待验证 |
| 2 | `@css:` 前缀 | `@css:.content p` | P0 | 待验证 |
| 3 | `@json:` + JSONPath | `@json:$.data.list[*]` | P0 | 待验证 |
| 4 | `@js:` 前缀 | `@js:result.replace(/\\s/g,'')` | P0 | 待验证 |
| 5 | 属性提取 | `@href`、`@src`、`@text`、`@html`、`@ownText`、`@value`、`@任意属性名` | P0 | 待验证 |
| 6 | 索引 | `@tag.li.2`、`@tag.li!0`（倒数第 1 个） | P0 | 待验证 |
| 7 | 排除规则 | `-@tag.script`、`-tag.div` | P0 | 待验证 |
| 8 | 替换规则 | `##正则##替换`（`$1` 引用分组） | P0 | 待验证 |
| 9 | `&&` 串联 | `class.list&&tag.li@text` | P0 | 待验证 |
| 10 | `\|\|` 依次尝试 | `@css:.a\|\|@json:$.b` | P0 | 待验证 |
| 11 | 变量读写 | `@put:{key:...}`、`@get:{key}` | P1 | 待验证 |
| 12 | 章节列表翻页 | `nextTocUrl` | P0 | 待验证 |
| 13 | 正文分页 | `nextContentUrl` + `{{page}}` | P0 | 待验证 |
| 14 | `@xpath:` | `@xpath://div[@id='a']` | P2 | **不支持** |
| 15 | `:regex` 后缀规则 | — | P2 | **不支持** |
| 16 | `@webJs` 网页 JS（含 DOM 操作） | — | P1 | 待验证 |

**P0 未全部通过不得发布首个可导入书源的版本。** P2 必须返回
`ParseFailure(unsupportedRule)` 并记录 `rulePath`（C-SRC-4），禁止静默返回空结果。

### 解析顺序

```
原始规则串
  → 按 `||` 切分候选（依次尝试，首个非空即成功）
    → 每个候选按 `&&` 切分为多级
      → 每级：提取前缀（@css/@json/@js/@xpath）→ 主体
        → 属性/索引/排除修饰
          → 得到字符串或元素集合
  → 最后应用 `##` 替换链
```

`@js:` 规则接收的 `result` 为上一级结果；`@js:` 出现在链首时 `result` 为 `null`。

---

## 4. URL 模板与变量

渲染必须统一经 `renderUrlTemplate`（C-SRC-5），禁止手写拼接。

| 变量 | 适用位置 | 含义 |
|---|---|---|
| `{{key}}` | `searchUrl` | URL 编码后的搜索关键词 |
| `{{page}}` | `searchUrl`、`nextTocUrl`、`nextContentUrl` | 页码，从 1 开始 |
| `{{baseUrl}}` | 全部 | 书源 `url` 的 origin |
| `{{bookUrl}}` | 目录/正文规则 | 当前书籍详情页 URL |
| `{{chapterUrl}}` | 正文规则 | 当前章节 URL |
| `{{变量名}}` | 全部 | 由 `@put:` / `@get:` 读写（P1） |

约定：

- 关键词**必须** URL 编码，且编码一次、不重复编码。
- 相对 URL（以 `/` 或非协议开头）必须以当前页 URL 为基准解析为绝对 URL。
- 未定义的变量渲染为**空字符串**，并记录 warning 日志；不得保留 `{{...}}` 原文。

---

## 5. 编码

- 必须使用 `betto_charset_detector` 检测（C-NET-3），检测顺序：
  HTTP `Content-Type` → HTML `<meta charset>` → 字节嗅探 → 回退 UTF-8。
- 检测结果必须缓存到「书源 ID + URL」维度，避免重复嗅探。
- 解码失败返回 `ParseFailure(encodingFailed)`，禁止用 `utf8.decode(allowMalformed: true)` 静默吞掉。

---

## 6. JS 桥接白名单

JS 规则运行在独立 Isolate 中，**只能**访问以下绑定（C-SRC-3）：

| 绑定 | 形态 | 说明 |
|---|---|---|
| `baseUrl` | `String` | 书源 `url` 的 origin |
| `result` | `String?` \| `List` | 上一步结果 |
| `page` | `int` | 当前页码 |
| `source` | 只读对象 | `name`、`url`、`group` 三个字段，其余不可见 |
| `http.get(url, options)` | `String` | 经 `core/network/HttpClient` 代理，受超时与重试策略约束 |
| `http.post(url, options)` | `String` | 同上 |
| `parse.getString(rule, doc)` | `String` | 复用规则引擎，可递归 |
| `parse.getElements(rule, doc)` | `List` | 同上 |
| `log.debug/info/warn/error(msg)` | `void` | 转发到 `core/logging`，自动附加 `rulePath` |
| `crypto.md5/sha1/base64Encode/base64Decode` | `String` | 纯计算 |

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
| — | 4xx（403/404） | `failureNetworkForbidden` / `failureNotFound` | 否 |
| `encodingFailed` | 编码检测或解码失败 | `failureEncodingFailed` | 否 |
| `parseFailed` | 规则无匹配、JS 异常或超时 | `failureParseFailed` | 否 |
| `unsupportedRule` | 命中 P2 或未实现语法 | `failureUnsupportedRule` | 否 |
| `invalidBookSource` | 导入 JSON 缺必填字段或结构非法 | `failureInvalidBookSource` | 否 |
| `cancelled` | 用户主动取消 | 无（静默） | — |

**关键判定：**

- 「规则无匹配」与「成功但结果为空」必须区分：
  - 顶层 `bookList` / `chapterList` / `content` **无匹配** → `parseFailed`。
  - 顶层匹配成功但集合为空 → **成功**，返回空列表（搜索无结果属正常业务）。
- 失败必须携带 `rulePath`（C-SRC-8），格式：`<字段名>` 或 `<字段名>.<子字段>`，
  例如 `searchRule.bookList`、`tocRule.chapterUrl`、`contentRule.content`。
- 失败对象**禁止**携带用户可见文案（C-ERR-7）。

---

## 8. 并发与限速

- 同一书源的并发请求上限默认 3，可由 `concurrentRate` 覆盖（P1）。
- 章节正文批量下载必须串行或有限并发，禁止对单一域名无限并发。
- 缓存键 = `书源 ID + 规则字段 + URL + 页码` 的稳定哈希，必须带 TTL（C-NET-6）。

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
| 规则单测 | §3 表中每条 P0 语法至少 1 条单测 |
| 失败单测 | §7 表中每个 `ParseFailureKind` 至少 1 条单测 |
| 链路测试 | 至少 2 个书源完成「搜索→详情→目录→正文」全链路离线回放 |
| 真实书源验证 | 每个 P0 语法行需在 PR 中附一条真实书源验证记录，并把状态列改为「已确认」 |
| 网络隔离 | 单元测试禁止真实联网；`HttpClient` 必须可注入替身（C-NET-8） |

真实书源验证记录格式（写入 PR 描述）：

```
语法：#9 &&
书源：<name> (<url host>)
链路：搜索 → 目录 → 正文
结论：已确认 / 行为差异：<描述> → 已更新矩阵
```

---

## 11. 明确不支持

以下必须在导入或解析时明确拒绝并给出可读提示，不得假装成功：

- `@xpath:` 规则（无 Dart xpath 依赖；如需要先走 `docs/README.md` §6.5 的 ADR 流程）
- `:regex` 后缀规则
- Legado 的登录脚本、UI 脚本、朗读规则、RSS/订阅源
- 需要浏览器 DOM/BOM 的网页 JS
- 依赖 Android WebView 行为的规则

---

**文档版本：** v0.1（提案，需真实书源回归后升 v1.0） · **最后更新：** 2026-10-10
