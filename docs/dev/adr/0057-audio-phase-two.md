# ADR-0057 听书二期：WebView 表单、`book` 方法面、HLS 现状、Windows SMTC、句级高亮

- **状态：** Accepted（2026-10-23，M24 用户指令；范围见 `DECISIONS.md` 2026-10-23「听书二期（M24）范围」）
- **日期：** 2026-10-23
- **关联：** C-PLT-1、C-SRC-3、C-SEC-4、C-DEP-7、ADR-0019、ADR-0054、ADR-0056、`docs/dev/book-source.md` §4.3 / §6、`docs/dev/roadmap.md` §3.7 / §3.10

## 背景

ADR-0056 落地后留下五处「已实现未验证 / 未实现」：`webView` 的 POST/body 形态、沙箱 `book`
的可变方法、HLS 是否可播、Windows 没有媒体通知、TTS 只有整块朗读没有句级高亮。M24 逐项处理，
本 ADR 记录每项的裁决与证据。

## 决策

### 决策 1 `webView` 支持 POST / body

- 端口 `core/platform/web_page_fetcher.dart` 增加 `WebPageRequestMethod` 与 `method` / `body`
  参数；`InAppWebViewPageFetcher` 把它们交给 `URLRequest(method:, body:)`（body 以 UTF-8 字节）。
- `PageFetchService.fetchRule` 不再把「POST 或带 body」排除在 `webView` 之外：表单型站点的结果页
  只在提交后存在，先 GET 一次再渲染拿到的永远是空结果页。body 的渲染（含 `{{key}}` 的百分号编码
  / JSON 原样）保持在同一条路径上，规则没声明 `Content-Type` 时按载荷形状补
  `application/x-www-form-urlencoded` / `application/json` / `application/xml`。
- WebView 失败仍**回落普通 HTTP**（POST 时走 `HttpClient.post`），平台没有 WebView 时同样回落；
  `isSupported == false` 是唯一的降级条件。

### 决策 2 沙箱 `book` 的方法面

- `book` 不再是 `Object.freeze` 的纯数据对象：prelude 的 `__sandboxBook(data)` 复制字段并挂上方法，
  每个 job 重建，所以规则自己的写入不会漏给下一份规则。
- `putVariable(key, value)` / `getVariable(key)` = `java.put` / `java.get` 的**同一张变量表**。这不是
  偷懒：上游 `AnalyzeUrl.javaPut/javaGet` 写读的正是 `chapter / book / ruleData` 的 variableMap
  （`AnalyzeUrl.kt:386-406`），而本仓只有一份规则变量（ADR-0034）。
- `setType` / `getType` / `setReverseToc` / `getReverseToc` 在本 job 内可读回，但**不影响宿主**：
  本仓没有 Book 实体上的 `type` / `reverseToc` 状态，章节顺序与媒体类型由 UseCase 决定。
  语义缺失显式登记（下文「后果」），不做静默假设。
- 其余 `Book` 成员（`getRealAuthor`、`downloadUrls`、`durChapterIndex` 等）仍按 §6 的边界报错，
  不因为方法面存在就假装实现。

### 决策 3 HLS：Android/iOS 可播，Windows 不可播（有证据）

- 解析层本就接受 `http(s)` 直链，`_isMediaUrl` 不按扩展名过滤，所以 `.m3u8` 从来不被地址规则挡住。
- **实测（2026-10-23）**：`integration_test/audio_playback_test.dart` 的 `hlsProbe` 用公开播放列表
  `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`（以及 Apple `bipbop` 变体）验证：
  - **Android（emulator-5554，just_audio/ExoPlayer）：位置正常推进，通过。**
  - **Windows（media_kit/libmpv，`media_kit_libs_windows_audio 1.0.9`）：加载成功但播放失败，
    探针不通过。** 随包 `libmpv-2.dll`（2023-09-24 构建）的字符串里**没有 HLS demuxer**
    （`applehttp` / `Apple HTTP Live Streaming` 均 0 次命中），即这套 audio-only 的 FFmpeg
    没编进 HLS 解复用器；同一探针对 https 直链 mp3 正常，排除网络与 TLS。
- 结论：`m3u8` 一律交给播放器，**平台能力差异由播放器承担**；Windows 的失败在既有 6 秒停滞
  看门狗下表现为可重试的失败提示，不会静默停在 0:00。撤销 ADR-0054「HLS 不支持」的**全局**
  登记，改为「Windows 受随包 libmpv 限制」这一定点登记。
- 触发条件（满足其一即可把 Windows 的 HLS 转为支持）：换用含 HLS demuxer 的 libmpv 构建，
  或在 Dart 侧加一层播放列表跟随（解析 m3u8 → 逐段播放）。

### 决策 4 Windows 媒体通知：接入 `audio_service_win`（WinRT SMTC）

- `dependencies` 增加 `audio_service_win ^0.0.3`（MIT）。它实现 `audio_service` 的
  `AudioServicePlatform`，用 WinRT `SystemMediaTransportControls` 显示曲目、播放/暂停，并把
  播放/暂停/上一首/下一首按钮回调给 `audio_service` 的 handler。`createPlaybackNotification`
  因此把 Windows 也交给 `AudioServicePlaybackNotification`，端口与调用方零改动。
- **实测（2026-10-23，Windows 10 26300）**：`notification_whenOnThisPlatform_attachesOrStaysSilent`
  在 Windows 上 `attach` 返回句柄，`update`（媒体项 + 播放状态）与 `detach` 均成功。
- **已知能力缺口（本 ADR 登记，不隐藏）**：`audio_service_win 0.0.3` 没有时间轴 / 位置 / seek
  支持（`SetStateRequest` 的位置被忽略，插件也不发 seek 按钮），所以 Windows 的通知不显示进度，
  通知上的 seek 不会到达播放器。播放器页内的 seek 不受影响。
- 评估过但未采用的替代：`smtc_windows`（MIT，Flutter 侧完整 SMTC 能力，但走
  `flutter_rust_bridge`，构建需要 Rust 工具链，且要新写一套 `PlaybackNotification` 实现）。
  触发条件：`audio_service_win` 长期不补时间轴，或 Windows 播放体验成为发布阻塞项时改用它。

### 决策 5 TTS 句级高亮：按段朗读 + 进度映射到排版后的正文

- `splitSpeechText` 之上新增 `splitSpeechSegments`（每块带源文本 `[start, end)`）与
  `speechSentenceAt(text, offset)`（偏移 → 所在句子的范围，句子不跨段落）。
- 读声用的正文改成与阅读页**同一份** `readerBodyText(data, settings)`：否则段首缩进与段距会把
  高亮位置推偏。分块仍按 800 字符上限与句/子句边界切，听起来与以前一致（缩进与空行本来就被 trim）。
- `SpeechSnapshot` 增加 `spokenRange`（引擎在当前这段里的偏移，Android/iOS 由
  `flutter_tts` 的 `setProgressHandler` 提供）；notifier 把它换算成正文偏移，取所在句子，
  通过**独立的** `readerTtsHighlighter`（keepAlive，值为 `null` 表示没有在读）发布。
  阅读页只 watch 这个 provider，所以不开听书时不会拉起系统语音引擎。
- 高亮只换颜色（`primaryContainer` / `onPrimaryContainer`），字号与字重保持与原样式一致：
  分页模式的页界是用同一份 `TextStyle` 量出来的，改字重会在读者眼皮底下重排页面。
- 分页模式把高亮范围裁进当前页；没有高亮时仍渲染普通 `Text`（样式留在 widget 上，排版测试可读）。
- **平台差异**：没有进度回调的平台（当前是 Windows 的 `flutter_tts`）高亮覆盖整块（≤800 字），
  不会消失；这是能力差异，不是缺陷，登记在此。

## 后果

- 好的方面：49/632 源里的 POST 型 `webView` 恢复上游语义；87/632 源的 `book.*` 方法调用不再
  `undefined is not a function`；Windows 有系统媒体控制；朗读能看见读到哪一句。
- 代价：Windows 通知没有进度/seek；Windows 仍不能播 HLS；`book.setReverseToc` / `setType`
  只是可调用、无宿主效果。
- 仍未闭环：Windows HLS（决策 3 的触发条件）、`audio_service_win` 的时间轴（决策 4）、
  云 TTS（ADR-0058，Proposed）。
- 验证：`docs/dev/testing.md` 的全量门禁 + 设备级 `integration_test/web_view_test.dart`（POST）、
  `integration_test/js_bridge_test.dart`（`book` 方法）、
  `integration_test/audio_playback_test.dart`（SMTC、HLS 探针）。
