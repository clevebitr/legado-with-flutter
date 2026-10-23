# ADR-0060 规则方言对齐：脚本内 `{{…}}` 展开、URL 选项先切后绝对化、音频地址形态校验

- **状态：** Accepted（2026-10-22，M17 真源抽查触发；用户指令「登记计划，然后开始修复引擎缺口」）
- **日期：** 2026-10-22
- **关联：** C-SRC-4、C-SRC-5、ADR-0026、ADR-0029、ADR-0047、ADR-0054、`docs/dev/roadmap.md` §3.7 / §3.10、`docs/dev/book-source.md` §3 / §4.3

## 背景

M17 的真源抽查（用户提供的「🔊书音M」）止于目录：章节地址里留下字面量 `movieId={{$.id}}`，站点回「章节不存在」。排查时用两个真实合集（`折黎No.0051.json` + `4dc410d1.json`，**632 条源 / 15 条音频源**）跑了生产链路，确认了与上游 `F:\Projetcs\legado-upstream` 的三处方言差异：

| # | 差异 | 上游行为 | 本仓（修复前） | 语料 |
|---|---|---|---|---|
| 1 | `@js:` / `<js>` 脚本**文本内**的 `{{…}}` / `@get:` | `AnalyzeRule.SourceRule.init` 先切段、`makeUpRule`（`AnalyzeRule.kt:666-768`）用当前条目求值并拼回完整规则，**之后**才执行 JS | 矩阵 #14「脚本里的 `{{…}}` 属于脚本」，原样交给 JS | 96/632 源（音频 4/15） |
| 2 | 章节/目录/书籍地址上的 `,{…}` 选项 | `BookChapterList.kt:236` 存规则原文；`AnalyzeUrl.kt:190-224` **先切选项**再 `getAbsoluteURL` | `FetchToc` 先 `resolveAbsoluteUrl`，`{` 被编码成 `%7B`，`fetchRule` 再也切不到选项 → 请求 `…/1,%7BwebView…%7D` → 404 | 49/632 源（音频 4/15） |
| 3 | 音频 `content` 规则的产物 | 上游直接把结果交给播放器（音频源约定为地址） | 任意 `http(s)` 值都当音轨，整页 HTML 被拼成假 URL（Windows 上会崩原生播放器） | 恋听网实证 |

JS 沙箱的 `book` 对象（`AnalyzeUrl.kt:373`，87/632 源引用）**不在本 ADR 范围内**，仍登记为未闭环。

## 决策

### 决策 1 脚本内的 `{{…}}` / `@get:` 在脚本执行前展开

对齐上游 `SourceRule.makeUpRule`：`@js:` 终段与 `<js>…</js>` 分段都先按当前 scope 求值内嵌模板（内层是规则则按规则、否则按 JS），把结果文本拼回脚本，再交给沙箱。展开产生的替换**不**改变「规则体是否进入正则模式」的判定（只影响脚本文本）。

反斜杠转义的 `\}` 不参与模板括号计数：脚本字面量 `/{{\}\}/` 不是模板，原样留给脚本（与上游 `\{\{[\w\W]*?\}\}` 的非贪婪语义一致）。

### 决策 2 规则产出的 URL 先切 `,{…}` 再绝对化

新增 `resolveUrlRule(rule, baseUrl)`：先 `parseUrlRule` 切出选项，只对 URL 部分做 `resolveAbsoluteUrl`，再把选项原文接回。用于：

- `FetchToc` 的章节地址、`FetchBookInfo` 的 `tocUrl`、搜索/发现列表的 `bookUrl`、翻页值；
- `PageFetchService.fetchRule` 在**渲染之后**再解析一次选项（`@js:` URL 规则返回「URL + 选项」是真实写法）。

`webView` 等不支持的选项仍按原裁决记为 `unsupported` + warning（不静默丢弃），但**请求的是干净 URL**，不再把选项当路径。

### 决策 3 音频地址先做形态校验

`FetchAudioTracks` 在相对地址解析**之前**校验值像不像地址：非空、≤4096 字符、不含空白与 `<>`、不以 `data:` 开头。不像地址的值跳过并记 warning；全部被跳过则整章 `parseFailed`。理由：`<js>result</js>` + webView 源的 `content` 会返回整页 HTML，解析后再判断会拼出 `https://host/<!DOCTYPE…>` 这样的假 URL，交给播放器只会在 Windows 上拖崩原生插件。

## 后果

- **好的方面：** 632 条源里 96 条的脚本模板、49 条的 URL 选项恢复上游语义；音频真源「🔊书音M」的链路从目录直接走到 `audioTracks ok(1)`（`movieId=1`），恋听网也走到音轨阶段；音频不再把 HTML 当音轨。
- **代价：** 脚本里故意写 `{{…}}` 字面量的源会像上游一样被展开（矩阵 #14 的旧行为被取代）；`resolveUrlRule` 需要在所有「规则结果当 URL」的入口使用，遗漏一处就会重新出现 `%7B`。
- **仍未闭环（roadmap §3.7）：** 沙箱 `book` 对象；`webView` 能力（无浏览器，纯 GET 只能覆盖一部分）；`just_audio_windows` 对部分远端流（书音M 的 m4a）位置停在 0、对加载失败的流会**原生崩溃**（不是 Dart 异常，端口接不住）；媒体直链的明文 HTTP 策略。
- **验证：** **1398 用例全过**（新增 14 条展开 / 选项 / 形态校验用例）；core 100% / domain 100% / data 98.53%；真源书音M `spot_check --audio` 四段 complete；632 源普查重跑（`{{}}` 源恢复、选项 404 消失）；`just_audio`/`flutter_tts`/`audio_service` 的 Windows + Android 设备级探针仍全过。
