# ADR-0056 播放后端、明文 HTTP 与 WebView：media_kit、独立开关、headless WebView

- **状态：** Accepted（2026-10-22，M17 真源复测触发；用户裁决三项：接真 WebView / 换 media_kit（LGPL）/ 明文 HTTP 独立开关）
- **日期：** 2026-10-22
- **关联：** C-DEP-7、C-PLT-1、C-SEC-2、C-SRC-3、ADR-0029、ADR-0047、ADR-0054、ADR-0055、`docs/dev/roadmap.md` §3.7

## 背景

ADR-0055 修完解析方言后，真源「🔊书音M」的链路已到 `audioTracks ok(1)`，但仍有三件事挡住「真的能听」：

1. Windows 的 `just_audio_windows` 对这条 m4a 位置停在 0，对另一条流在 `setUrl` 加载失败时**原生崩溃**（Dart 端口接不住）；
2. 音频直链是 `http://`，Android 默认拒绝明文，C-SEC-2 要求「用户显式允许」的独立设置；
3. 49/632 源使用 `,{webView:…}`，纯 GET 只能覆盖一部分（页面要靠 JS 渲染）。

另：87/632 源读取 `book.*`，沙箱只有 `bookName` / `chapterTitle`（ADR-0055 的 P2）。

## 决策

### 决策 1 Windows 播放改用 media_kit（mpv）

- `core/platform/playback_backend.dart` 暴露 `usesMediaKitPlayback`（`Platform.isWindows`，C-PLT-1 唯一允许的平台判断处）；`reader/di.dart` 据此在 `MediaKitPlaybackEngine` 与 `JustAudioPlaybackEngine` 之间选择。Android / iOS 继续 `just_audio`。
- `MediaKitPlaybackEngine` 在首次构造时 `MediaKit.ensureInitialized()`；`open(Media(url, httpHeaders), play: false)`，位置 / 时长 / 播放 / 完成 / 缓冲 / 错误全部映射到现有 `AudioPlaybackSnapshot`。
- 6 秒看门狗：`play()` 后位置仍为 0 且仍在「播放中」→ 发 `reader.audioPlayer` 失败快照，UI 可重试，不再静默卡在 0:00。
- 实测：同一 m4a 直链（书音M）media_kit 在 Windows 上 `position=0.109s`、`duration=32:34`，不再崩溃。

### 决策 2 许可：libmpv 二进制按 LGPL-2.1+ 白名单放行

- `media_kit` 与 `media_kit_libs_windows_audio` 的**包**许可证是 MIT；Windows 构建从 media-kit 的 libmpv 构建下载的 **libmpv / FFmpeg 二进制**是 LGPL-2.1+（动态链接）。
- C-DEP-7 增加一条白名单：**LGPL-2.1+ 仅允许用于 `media_kit_libs_windows_audio` 随包的动态库**；`tool/scan_licenses.dart` 仍按包 LICENSE 扫描（不误报），`NOTICE.md` §5 手工登记该二进制与「动态链接、可替换」义务。其他 LGPL 依赖仍禁止。

### 决策 3 明文 HTTP：一个开关，两条车道共用

- `AppSettings.allowPlainHttp`（默认 `false`，独立设置项）+ 设置页开关；`plainHttpSettingProvider` 由装配根从设置注入。
- 页面请求：`HttpPolicy.allowPlainHttp` 读取同一值（此前这个策略位没有任何 UI 入口）。
- 媒体：`AudioReader` 在装载音轨前检查 `http://`，关闭时返回 `reader.audioPlainHttp` 专用失败；开启才交给播放器。
- Android：`<application android:usesCleartextTraffic="true">`（cleartext 只能整包开关），真正的闸门是应用层；同时补上 release 清单缺失的 `INTERNET` 权限。iOS 由 ATS 的默认规则约束，WebView 与播放器只在用户开启后使用 http。

### 决策 4 WebView：headless WebView 端口，而不是无浏览器降级

- `core/platform/web_page_fetcher.dart` 定义端口（`WebPageFetcher` / `FetchedWebPage`）；`InAppWebViewPageFetcher` 用 `flutter_inappwebview` 的 `HeadlessInAppWebView` 每次请求创建一个，`onLoadStop` 后等 400 ms 让页面脚本跑完，再 `getHtml()`；20 秒超时。
- `PageFetchService.fetchRule` 在 `webView` 选项、GET、无 body、端口可用时走 WebView；失败或平台不支持（端口 `isSupported == false`）**回落普通 GET** 并 warning。POST/body 的 `webView` 仍回落（WebView 无法携带表单体）。
  **2026-10-23 修订（ADR-0057 §决策 1）：** POST/body 的 `webView` 不再回落——端口增加 `method`/`body`，由 `URLRequest` 真的把表单交给页面；只有「平台没有 WebView」与「WebView 取页失败」两种情形回落普通 HTTP。
- `webPageFetcherProvider` 默认 `UnsupportedWebPageFetcher`（宿主测试与无 WebView2 的平台走 HTTP），装配根绑定真实现。
- Android / iOS / Windows 都由 `flutter_inappwebview` 覆盖（Windows 需要 WebView2 运行时，`platform.md` §1.2 登记）；集成用例 `integration_test/web_view_test.dart` 在本地 HTML 上验证 JS 已执行。

### 决策 5 沙箱 `book` 对象（ADR-0055 P2）

- `JsBookInfo{name, author, bookUrl, tocUrl, intro, kind}`；`JsPageContext.book` → `JsJob.book` → worker 的 `book` 绑定；没有上下文的阶段绑定 `null`（源的 `typeof book` 守卫照旧）。
- 目录阶段由 `FetchToc` 填 `tocUrl = 目录地址`、`bookUrl` 由阅读器端口透传；正文 / 音频阶段由 `ChapterRequest` 的 `bookUrl` / `tocUrl` / `author` / `kind` / `intro` 填。
  **2026-10-23 修订（ADR-0057 §决策 2）：** 可变方法已落地——`putVariable`/`getVariable` 走规则变量表，`setType`/`setReverseToc` 在 job 内可读回但不影响宿主（语义缺失已登记）。

## 后果

- 好的方面：Windows 上真实 m4a 可播、加载失败不再原生崩溃；明文媒体变成显式开关；`webView` 源有真渲染路径；`book.*` 源拿到目录 / 书名 / 作者上下文。
- 代价：Windows 包体增加 libmpv 与 WebView2 插件；`flutter_inappwebview` 的 Windows 构建首次约 2.5 分钟；WebView 必须在 UI isolate 运行（当前所有取页都从 UI 触发，符合）。
- 仍未闭环（2026-10-23 更新，ADR-0057）：Windows HLS（随包 libmpv 无 HLS demuxer）、云 TTS（ADR-0058 Proposed）、Windows SMTC 无时间轴/seek。原列的四项里，`webView` POST/body、`book` 方法与 Windows 通知已落地，句级高亮随 M24 落地。
- 验证：全量门禁 + 真源（书音M：`audioTracks ok` + media_kit 实际推进；WebView 集成用例 Windows 通过）；MediaKit 适配器与 WebView 实现按 ADR-0019 第二类豁免覆盖率，由 `integration_test/audio_playback_test.dart` / `web_view_test.dart` 覆盖。
