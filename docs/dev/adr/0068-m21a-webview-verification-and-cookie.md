# ADR-0068 M21a：WebView 人机验证、Cookie 持久化与引擎兼容第一批

- **状态：** Accepted（2026-10-23，用户裁决四项：M21 拆 M21a/M21b、应用内可见 WebView、
  第一批做 A/B/C/D 四簇、Cookie 持久化到 Drift 并与 WebView 双向同步）
- **日期：** 2026-10-23
- **关联：** C-NET-1、C-NET-2、C-NET-5、C-NET-7、C-NET-9、C-ERR-1、C-ERR-2、C-ERR-7、C-SEC-2、
  C-SRC-2、C-SRC-3、C-SRC-4、C-PLT-1、ADR-0037 §决策 5（`java.*` 具名拒绝族）、
  ADR-0056（迁移可重入）、ADR-0061 §决策 4（headless WebView）、ADR-0062 §决策 1（`webView` POST）、
  `docs/dev/book-source.md` §2/§4.3/§6/§11、`docs/dev/ui-gap.md` §4 M21、`docs/dev/roadmap.md` §3.7

## 背景

M21 原本把 U8–U15（按源缓存、主题配置、阅读设置、备份恢复、本地导入、二维码、登录）捆在一个
里程碑里。用户的实际诉求是另外两件事：

1. **书源被站点拦下时能过人机验证**（Cloudflare / 5 秒盾 / 滑块 / 点选 / 图片验证码 / 登录）；
2. **更多"特殊书源"能跑**——即引擎的兼容面比上游窄。

这两件事共享一个底座（可见 WebView + Cookie），而 U8–U15 是另一类工作（数据与系统 UI）。
本 ADR 只定 M21a 的形态；M21b 沿用 `ui-gap.md` 的 U8–U15 原文，不在此重复。

### 现状（本仓 vs 上游 legado-upstream）

| 上游机制 | 落点 | 本仓 |
|---|---|---|
| `,{webView:true}`：隐藏 WebView 渲染后再取 HTML | `AnalyzeUrl.kt` + `BackstageWebView.kt` | ✅ 已有（headless，GET/POST），缺 `webViewDelayTime` / `webJs` / `overrideUrlRegex` |
| `java.startBrowser(url,title)` / `startBrowserAwait(...)`：**可见**浏览器让用户手动过验证 | `JsExtensions.kt:334-375`、`SourceVerificationHelp.kt`、`ui/browser/*` | ❌ 具名拒绝 |
| `java.getVerificationCode(imageUrl)`：图片验证码对话框 | `JsExtensions.kt:373`、`VerificationCodeActivity` | ❌ 具名拒绝 |
| 源字段 `loginUrl` / `loginUi` / `loginCheckJs` | `SourceLoginViewModel.kt`、`WebBook.kt:73` 等 | ❌ 未建模（矩阵标 M2） |
| Cookie 由 WebView 与 HTTP 客户端共用 | Android `CookieManager` 全局 | ❌ 两套互不相干；本仓 `CookieManager` 只在进程内存里 |
| `sourceRegex` / `bodyJs` / `webJs` | `AnalyzeUrl.kt:430-520` | ❌ 具名拒绝 |
| URL 选项 `retry` / `proxy` / `readTimeout` / `callTimeout` / `HEAD` / `encodedForm` | `AnalyzeUrl.kt:830-1000` | 部分（`method` POST 已有；其余按名记 unsupported） |
| 字体反爬 `queryBase64TTF` / `replaceFont` | `JsExtensions.kt` + `FontLoader.kt` | ❌ 具名拒绝 |

**关键结论：只做"可见 WebView"而不做 Cookie 共享是没用的。** 用户在 WebView 里过完验证，
后续 Dart 请求不带那套 cookie，还是会被拦。所以本 ADR 把 Cookie 持久化与双向同步列成第一块。

## 决策

### 决策 1 M21 拆成 M21a（本 ADR）与 M21b（原 U8–U15）

| 里程碑 | 范围 |
|---|---|
| **M21a** | 可见 WebView 验证 + Cookie 持久化/双向同步 + 引擎兼容 **A**（WebView 验证族）/ **B**（取页后处理）/ **C**（字体反爬）/ **D**（请求面选项） |
| **M21b** | `ui-gap.md` 的 U8–U15 原文（按源缓存、主题配置、阅读设置扩展、备份恢复、本地导入、二维码、登录表单 UI） |

E（规则方言：`:正则` / `@xpath:` / 嵌套规则 / 表单型发现分类）与 F（`downloadUrls` / `relatedBooks` /
`isVolume` / `preUpdateJs` / `formatJs`）**不在 M21a**：它们各自要引依赖或与下载功能耦合，
继续留在 `roadmap.md` §3.7 的登记表里等触发条件。

### 决策 2 验证界面 = 应用内可见 WebView 页

- 用已有的 `flutter_inappwebview`（Android 系统 WebView、Windows WebView2、iOS WKWebView），
  **不引新依赖**；平台没有 WebView 时端口 `isSupported == false`，调用方报
  `ParseFailure(unsupportedRule)` 并在 UI 上说明「请先在系统浏览器完成验证」。
- 页面只承担三件事：加载规则给的地址、让用户操作、在用户按「完成」或返回时把结果交回。
  它**不是**通用浏览器（没有地址栏、书签、下载）：那是另一个需求，登记在 `ui-gap.md` P2。
- 结果 = `(finalUrl, html)`，与 headless 的 `FetchedWebPage` 同形，方便上层复用。

### 决策 3 端口与绑定：`core/platform/source_verification.dart` + 装配根

- `domain/` 不能碰 `BuildContext`（C-ARCH-7），而弹页面必须有导航；因此能力声明在
  `core/platform/`（C-PLT-1 的位置），实现由装配根绑定到"推一个页面并等结果"的 presentation 服务。
- 未绑定实现回答 `ParseFailure(unsupportedRule)` + 一条 warning（ADR-0041 §决策 2 的习惯），
  绝不抛。
- 页面通过 `MaterialApp.navigatorKey`（root navigator）推入：验证可能发生在任何一次取页上，
  调用点手里没有 `BuildContext`。这是本仓第一次给 `MaterialApp` 加 `navigatorKey`，
  理由与用法写进 `architecture.md` §6。
- 用户取消 / 关闭页面 → `ParseFailureKind.cancelled`（既有的 kind），页面显示「已取消验证」。
- **新增一个 `ParseFailureKind.loginRequired`**（登录/验证失效）：`loginCheckJs` 判定失效时，
  上层需要把「去登录」作为可选动作展示，而不是笼统的 `parseFailed`。
  `architecture.md` §5 的 9 个 kind 因此变成 10 个，文案键 `failureLoginRequired`（C-ERR-7）。

### 决策 4 Cookie：Drift 持久化 + 与 WebView 双向同步

- 新表 `cookies`（schema v7 → **v8**）：
  `(id, domain, path, name, value, is_secure, expires_at?, created_at)`，
  唯一键 `(domain, path, name)`；过期用注入的 `Clock` 判定并在读取时跳过（缺省 = 会话 cookie）。
  迁移按 ADR-0056 可重入（新表 + 索引先问 `sqlite_master`）。
- `CookieManager` 接口**保持同步**（`HttpClient` 的拦截器在同步上下文里读它，C-NET-5 不变）：
  - `PersistentCookieManager` = 内存表（读）+ `CookieStore` 端口（异步写穿 / 批量导入）；
  - 写失败只记 warning（cookie 丢了最多重新登录，绝不能让请求失败，ADR-0033 的同一立场）；
  - `hydrate()` 在 `main()` 里 `runApp` **之前** await 一次：`main.dart` 因此从纯 `runApp` 变成
    「ensureInitialized → 建容器 → hydrate → runApp」，仍只做 bootstrap（`architecture.md` §1）。
- **双向同步**：
  - 进验证页前：把内存里匹配该 URL 的 cookie 通过插件 `CookieManager.setCookie` 注进 WebView；
  - 出验证页时：读插件 `CookieManager.getCookies(url:)`，全部导入 `PersistentCookieManager`
    （domain/path/expires 以插件给的为准），再触发一次可选的重取。
- 不做每书源隔离 cookie 域（用户裁决）：同一站点两个源共享登录态是本仓接受的语义，
  与上游 Android 的全局 cookie jar 一致。

### 决策 5 JS 面：`startBrowser*` / `getVerificationCode` / `webView*` 从"具名拒绝"转为"用户门控调用"

| 名字 | 行为 |
|---|---|
| `java.startBrowser(url, title[, html])` | 推验证页，**不等结果**（上游同义：发起后立即返回），页面关闭时结果被丢弃 |
| `java.startBrowserAwait(url, title[, refetchAfterSuccess[, html]])` | 推验证页并 `await` 结果；`refetchAfterSuccess` 默认 true = 关闭时用新 cookie **重新请求一次**，返回那次响应 |
| `java.getVerificationCode(imageUrl)` | 图片验证码对话框，返回用户输入的字符串 |
| `java.webView(url, js[, ...])` / `webViewAll` | 复用 headless 渲染 + 脚本，返回 body |

- 这些调用**绕过单规则 JS 额度与超时**（它们等的是人，不是 CPU）：桥把 `userGated` 标在调用上，
  宿主侧用独立的总超时（10 分钟）兜底，超时 → `ParseFailureKind.networkTimeout`。
  其余规则调用仍受既有额度约束（C-SRC-2 不变）。
- 白名单只有这四个入口：文件系统、进程、任意网络仍然不暴露（C-SRC-3）。
- `webView*` 的 `overrideUrlRegex` / `delayTime` 参数在 A 簇里一并支持。

### 决策 6 `webView` 选项增强（A 簇）

- `webViewDelayTime`（毫秒）：`onLoadStop` 之后再等这么久才取 HTML；上限 30 s（防呆）。
- `webJs`：在页面里执行的脚本，返回字符串即为页面 body（上游同义）；失败 → `parseFailed`。
- `overrideUrlRegex`：命中则把该 URL 当作结果地址，不再继续加载（用于「验证后跳回」的站点）。
- 全部走既有 `WebPageFetcher` 端口；headless 与可见页共用同一套设置，避免两套行为。

### 决策 7 取页后处理（B 簇）

- `ContentRule.sourceRegex`：对**原始 HTML**先做正则截取（上游 `AnalyzeUrl` 的 `sourceRegex`），
  再进规则引擎；截取不到 = `parseFailed`（不静默给空正文）。
- `bodyJs`（URL 选项）：对响应体跑 JS，返回字符串作为 body。
- `webJs`：见决策 6。
- 三者的边界都在 `book-source.md` §4.3 / §6 各自的注记里写清楚，不再另立语法。

### 决策 8 请求面选项（D 簇）

- `retry`：**显式次数上限**（C-NET-2），超过 3 次按 3 次；退避 1s/2s/4s。
- `proxy`：`http://host:port` / `socks5h://host:port`，只对该源的请求生效（Dio `HttpClientAdapter`
  级别的每请求代理；Windows/Android 同一实现）。
- `readTimeout` / `callTimeout`：毫秒，上限 120 s。
- `method: HEAD`、`encodedForm`（表单 POST）。
- `dnsIp`：**不做**，登记为差异（Dio 没有稳定的自定义 DNS 注入点，Windows 上还要额外依赖）。

### 决策 9 字体反爬（C 簇）先做依赖评估

`queryBase64TTF` / `replaceFont` / 字形映射需要 TTF 解析。第一步是**依赖与许可评估**
（候选：纯 Dart 的 TTF 解析包、或自己解析 `cmap` 表 —— 后者约 300 行）。评估结论作为本 ADR 的
增补记录写回，再决定实现形态；**未评估前不写任何"已支持"的文案**，命中仍报 `unsupportedRule`。

### 决策 10 失败语义

| 场景 | 结果 |
|---|---|
| 平台无 WebView / 端口未绑定 | `unsupportedRule`（`rulePath` 指向 `java.startBrowser` 等调用点） |
| 用户取消验证页 | `cancelled` |
| 验证等待超时（10 分钟） | `networkTimeout` |
| `loginCheckJs` 判定登录失效 | 新增 `loginRequired` |
| 重取后仍拿不到内容 | 沿用该阶段的既有失败（`parseFailed` / `notFound`） |

## 影响

- `lib/core/storage/`：`cookies.dart`（表）、`cookie_dao.dart`、`database.dart`（v8）、dump v8。
- `lib/core/network/`：`PersistentCookieManager` + `CookieStore` 端口；`HttpPolicy` 的 retry/proxy/timeout。
- `lib/core/platform/`：`source_verification.dart`（端口 + 未绑定实现）、
  可见 WebView 页与插件 cookie 读写（`file_selector` 同款：插件调用单独成文件、按 ADR-0019 第二类豁免）。
- `lib/main.dart`：`WidgetsFlutterBinding.ensureInitialized()` + 容器 + `hydrate()` + `runApp`。
- `lib/app.dart`：`navigatorKey`、`sourceVerificationProvider` 绑定。
- `features/book_source/`（引擎）：`PageFetchService`（`webViewDelayTime` / `webJs` / `overrideUrlRegex` /
  `sourceRegex` / `bodyJs` / `retry` / `proxy` / `timeout` / `HEAD` / `encodedForm`）、JS 白名单与
  `java.*` 兼容面、失败 kind 映射。
- ARB 双语：验证页、图片验证码、`failureLoginRequired`、`webView` 相关提示。
- 测试：cookie 表迁移与 DAO、`PersistentCookieManager`（hydrate / 写穿 / 过期 / WebView 导入）、
  验证页 Widget 测试、JS 门控调用、请求面选项（FakeHttpClient 断言请求参数）。

## 后果

- 好的方面：被盾拦的源第一次有了"人来过一下"的路径；登录态重启不丢；`sourceRegex` / `bodyJs` /
  `retry` / 代理这些低风险项直接抬高成功率。
- 代价：`main()` 多一步异步 bootstrap；新增一张表与一个 `ParseFailureKind`；
  验证页是 **UI 阻塞**的（用户不在场时会等到 10 分钟超时），因此只在规则显式调用时才出现。
- 未做：每书源 cookie 隔离、通用浏览器、E/F 两簇、`dnsIp`、云 TTS（ADR-0063 仍 Proposed）。

---

## 2026-10-23 落地注记：M21a 第一批的实测结果

**已落地：** v8 cookie jar（Drift + `PersistentCookieManager`，`main()` 前 hydrate）、可见
WebView 验证页 + 图片验证码页、`SourceVerification` / `WebViewCookieBridge` 端口与装配根绑定、
`appNavigatorKey`、`HttpClient.getBytes`（字节门，供验证码与将来的字体文件）、
`java.startBrowser` / `startBrowserAwait` / `getVerificationCode` / `webView` / `webViewGetString`
（用户门控：不占单规则额度、暂停硬预算、等掉的时间从 `elapsedMs` 扣除）、
`webViewDelayTime` / `webJs` / `overrideUrlRegex`、`ContentRule.webJs`、`retry` / `readTimeout`、
`ParseFailureKind.loginRequired`。

**两处必须记住的语义差异：**

1. **验证族返回 Promise。** 上游的 Rhino 能同步阻塞线程，所以 `startBrowserAwait` /
   `getVerificationCode` 在规则里是同步取值；本仓的 QuickJS 沙箱不可能停下来等宿主，因此这两个
   名字返回 Promise，规则必须 `await`。`startBrowser`（上游返回 void）没有这个差异。
   已写进 `book-source.md` §6。
2. **验证失败即整次 job 的答案。** 用户取消 → `cancelled`；平台无 WebView → `unsupportedRule`；
   `loginCheckJs`（尚未建模）将来判失效 → `loginRequired`。让脚本吞掉只会得到一个没有正文的页面，
   而 UI 需要能显示「去登录/已取消」。

**本批未做（仍登记）：**

| 项 | 原因 / 触发条件 |
|---|---|
| `ContentRule.sourceRegex`（正文前从原始 HTML 截取片段） | 需要先决定「截取后按 JSON 还是 DOM 建 scope」，且与 `nextContentUrl` 翻页组合的语义要先取证；触发 = 出现「规则本身正确但页面是壳」的真实源 |
| `proxy` / `dnsIp` / `callTimeout` / `HEAD` / `encodedForm` | 前两者要按源建 Dio 实例与自定义 DNS，收益未取证；后三者没有真实语料。仍按名记 `unsupported` |
| 字体反爬 `queryBase64TTF` / `replaceFont` / `getFontGlyph` | 评估结论：需要 TTF `cmap` 解析（约 200–300 行纯 Dart，或引一个第三方包并做许可评估）。本批**不引依赖**，命中仍报 `unsupportedRule`；作为 C 簇的下一刀 |
| `loginUrl` / `loginUi` / `loginCheckJs` 三个源字段 | 「过验证」这一半已通；「登录表单 + 失效检测」需要 UI 表单与脚本判定两件事，排在 M21a 第二刀 |
| 每书源 cookie 隔离 | 用户裁决为「持久化 + 双向同步」，不隔离（与上游 Android 的全局 jar 一致） |

---

## 2026-10-24 增补：第二刀（登录拦截器、取页后处理、字体评估、D 簇裁决）

**已落地：** `loginUrl` / `loginUi` / `loginCheckJs` 三个源字段建模（导出保真）、
`loginCheckJs` 响应拦截器 + 沙箱响应对象、书源管理行菜单的「登录 / 过验证」入口、
`ContentRule.sourceRegex`（逐页截取）、URL 选项 `bodyJs`。

### 决策 3 修正：`loginCheckJs` 是**响应拦截器**，不是 `true`/`false` 检查

本文 2026-10-23 的决策 3 把 `loginCheckJs` 写成「判定失效 → `loginRequired`」。取证后该口径**错误**：

- 上游 `AnalyzeUrl.evalJS(jsStr, result)` 把 `result` 绑成 `StrResponse`，调用方是
  `res = analyzeUrl.evalJS(checkJs, res) as StrResponse`（`WebBook` / `Rss` 同形），**脚本返回值替换响应**；
- `StrResponse` 的 `body` 是**属性**（上游自己的 JS 助手写 `getStrResponse().body`），
  `url()` / `code()` / `headers()` 是方法；
- 真实语料（yckceo 源仓库）就是这么写的：`var src = result.body; if (src 命中登录页) java.startBrowserAwait(result.url(), '登录')`。

本仓实现（`book-source.md` §6 是绑定与返回值的唯一出处）：

| 环节 | 语义 |
|---|---|
| 运行时机 | **每次取页成功后**（搜索 / 发现 / 详情 / 目录 / 正文，含 `nextContentUrl` 的每一页），`rulePath = loginCheckJs` |
| `result` | `JsResponseView`：`body` 属性 + `url()` / `code()` / `headers()` / `header(name)` / `cookie()` / `contentType()` / `isSuccessful()` / `String(result)` |
| 返回值 | `null`/`undefined` → 沿用本次响应；`{body[, url]}`（含沙箱对象与 `startBrowserAwait` 的 `{url, body}`）→ 替换页面的正文与地址；**裸字符串** → 只替换正文（宽容方言）；其余 → 见下 |
| 取不到可用响应 | 源声明了 `loginUrl` / `loginUi` → `ParseFailureKind.loginRequired`（UI 唯一可行动的答案是「去登录」）；否则 `parseFailed` |
| 脚本本身失败 | 原样上抛（`js:error` / `js:timeout` / `cancelled` / `unsupportedRule`）：拦截器是源对被拦页面的回答，吞掉它只会解析一份没人担保的正文 |

**登记差异（三条）：**

1. **只对 2xx 响应运行**：非 2xx 在 `HttpClient` 层已成 `ParseFailure`（403 → `networkForbidden`），
   拦截器看不到它们。被盾拦的源仍走 `,{webView:true}` 或 `java.startBrowser*`。
2. **`result.body()`（方法形态）不支持**：上游是 `body` 属性；Readori 文档与少量语料写成
   `result.body()`，命中会显式报 `result.body is not a function`（不是静默给空）。
3. **登录检查 JS 专属的 `java.getStrResponse()` / `java.initUrl()` / `java.getHeaderMap()` 仍具名拒绝**：
   它们要重新发起「当前这条规则」的请求，语义与 `http.get` 有重叠但没有真实语料证明必要性
   （触发 = 出现只靠这条路径才能过验证的源）。

### `loginUrl` / `loginUi`：建模 + WebView 登录入口，原生表单归 M21b

- 三字段都进 `BookSource`（原始键名），导入/导出保真；`loginUi` **只保留原文**。
- 「登录 / 过验证」是书源列表行菜单的一项（仅当源声明了 `loginUrl` / `loginUi` / `loginCheckJs` 时出现）：
  它用**同一个** `SourceVerification` 端口打开可见 WebView——`loginUrl` 是地址（URL 规则，后缀丢掉）就打开它，
  是脚本（`@js:` 定义 `login()`）或为空就打开源地址；用户关闭后 cookie 已在 v8 jar 里。
- 原生 `loginUi` 表单（text / password / button / select / toggle + `action` JS、`source.getLoginInfoMap()`、
  `java.upLoginData`）仍属 M21b 的登录 / Cookie 管理 UI（`docs/dev/ui-gap.md` U15，本文决策 1）。

### 决策 7 落地：`sourceRegex` 与 `bodyJs` 的边界

| 项 | 语义 |
|---|---|
| `ContentRule.sourceRegex` | 每次取页**成功后、建 scope 之前**对正文做正则截取；有捕获组取 group(1)，否则取整个匹配。截取后的片段就是页面：DOM 规则与 `$.` / `@json:` 都从它读，登录拦截器看到的也是它 |
| 截不到 / 正则非法 | `parseFailed`，`rulePath = contentRule.sourceRegex`（顶层规则不降级，ADR-0026 §决策 1） |
| 与 `nextContentUrl` 翻页 | **每页各自截取**：翻页规则从截取后的片段里读，下一页同样先截再解析 |
| `bodyJs`（URL 选项） | 对**普通 HTTP 响应**的正文跑脚本，`result` = 正文，返回值**必须是字符串**否则 `parseFailed(bodyJs)` |
| 两者的顺序 | `bodyJs` 先、`sourceRegex` 后：脚本拼出真实正文，再按正则切一刀 |
| `webView` 分支 | 不用 `bodyJs`（渲染路径的对应物是 `webJs`） |

### 决策 8 裁决：D 簇五项**不做**（本次定案，不再以「收益未取证」挂着）

| 项 | 结论与理由 | 重开触发条件 |
|---|---|---|
| `proxy` | 不做。要按源建独立 `Dio` 实例（连接池、重试、超时、限速全部按源复制一份），而真实语料里带 `proxy` 的源为 0 条 | 出现「只能走代理才能取页」的可复现源，且用户明确需要在应用内配代理 |
| `dnsIp` | 不做（本文决策 8 原文）。Dio 没有稳定 DNS 注入点，Windows 还要额外原生依赖 | 同上 |
| `callTimeout` | 不做。`readTimeout` 已覆盖「响应慢」的主因；`callTimeout` 只在「连接建立慢」时有别，而 `connectTimeout` 已在策略里 | 出现可复现的「连接阶段超时，读阶段正常」源 |
| `method: HEAD` | 不做。语料 0 条；`HEAD` 只用于探活，而本仓的探活是整页抓取 | 出现只回 `HEAD` 才给元数据的源 |
| `encodedForm` | 不做。表单 POST 已由 `body` + `application/x-www-form-urlencoded` 覆盖（ADR-0062 §决策 1）；`encodedForm` 的差别只是「上游用它免掉关键词二次编码」，本仓的 `encodeKeyword` 已按 `charset` 处理 | 出现「表单字段必须原样不编码」的真实源 |

以上五项命中时仍按名记 `unsupported` + warning（ADR-0032 的降级口径），行为不变；本表只把「何时重开」写死。

### 决策 9 评估结论：字体反爬**不引依赖**，实现排在第三刀

- **候选包**：`glyph_path`（纯 Dart、零依赖，含 cmap 解析，但面向「文字转路径」，许可与字形身份语义都要再核）、
  `ttf`（Dart 3 不兼容）、`dart-ttf-parser`（license 为 Other）、`flutter_ttf_parser`（license 为 Other）。
  按 C-DEP 的许可口径，前三个中的后三个**直接排除**；`glyph_path` 需要一次许可复核，而且它不提供
  「字形 ID ↔ 字符」的反查面。
- **结论：自己解析 `cmap`，不引依赖。** 只需要两张子表——format 4（BMP，segment 数组）与 format 12
  （分组），约 150–200 行纯 Dart + 用**合成字体**（测试里手工拼 sfnt 头 + cmap 表）做单测，
  不碰 `post` / `glyf` / `name`，没有许可风险，也没有平台依赖。
- **开工前要先定的唯一语义**：`java.queryBase64TTF` 返回什么。上游 `replaceFont(text, ttf1, ttf2)`
  靠**字形名**（`post` 表）对齐，本仓不解析 `post`，因此采用 `code → glyphId` 两张表、
  `replaceFont` 内部用 glyphId 反查目标字体；`getFontGlyph` 是同一张表的单点查询。
  这是与上游的**表示差异**，要在 `book-source.md` §6 写清楚，规则里不要自己索引返回对象。
- **状态**：三个名字仍报 `unsupportedRule`；触发 = M21a 第三刀（`queryBase64TTF` → `replaceFont` → `getFontGlyph`，同一刀）。
