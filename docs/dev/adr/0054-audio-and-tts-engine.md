# ADR-0054 听书与音频：音频书源播放 + 系统 TTS 朗读

- **状态：** Accepted（2026-10-22，用户裁决里程碑 M17：**音频源播放与 TTS 朗读两者都要**；
  参考 `F:\Projetcs\legado-upstream` 的 `ui/book/audio/*` 与 `ui/book/readaloud/*`）
- **日期：** 2026-10-22
- **关联：** C-DEP-1、C-DEP-7、C-PLT-1、C-UI-1、C-UI-5、C-UI-7、C-ERR-1、ADR-0003、ADR-0041、
  ADR-0044、ADR-0052、`docs/dev/roadmap.md` §3.10（M17）、`NOTICE.md` §5

## 背景

`BookSourceType.audio`（`bookSourceType = 1`）与「听书」在本仓都还没有链路：

- 音频书源的正文规则返回的是**音频地址**（或含 `src` 的结构），现有 `ContentRule` 解析成文本后
  被阅读器当纯文本渲染，等于不可用；
- 听书（把文本正文读出来）没有任何实现，上游由 `readaloud/` 一整套（系统 TTS / 云 TTS / 缓存 /
  定时 / 投屏）承担。

## 决策

### 决策 1 两条独立链路，共用「章节上下文」而不共用播放器

| 能力 | 触发条件 | 输入 | 输出 |
|---|---|---|---|
| 音频书源播放 | 当前书源 `sourceType = audio` | 章节音频地址（`ruleContent` 列表语义） | 播放器（进度 / 倍速 / 上一章下一章） |
| TTS 朗读 | 用户在文本阅读器里点「朗读」 | 当前章节**文本正文** | 系统 TTS（语速 / 音色 / 连续章节） |

- 两者都放在 `features/reader/`：它们消费的是同一条「当前章节 + 目录 + 进度」上下文
  （ADR-0044 §决策 2 的三条端口），新造 feature 只会让端口重来一遍（C-ARCH-2 的反面）。
- 播放器与 TTS 各自一个 `@riverpod` Notifier，互不依赖：朗读文本时不需要音频播放器，
  反之亦然。共享的只有「当前章 / 下一章」的推进函数。

### 决策 2 音频地址解析复用正文规则，但产物是地址列表

- 新增 `domain/entities/audio_track.dart`（地址 + 可选时长/标题/headers）与
  `domain/usecases/fetch_audio_tracks.dart`。
- 规则求值与漫画同一条路线（ADR-0053 §决策 2）：一项 = 一轨；相对地址按章节页地址解析；
  空列表按 `ParseFailureKind.parseFailed` 整章失败，不显示「0:00 / 0:00」的空播放器（C-SRC-4）。
- 只支持直链音频（`http(s)://` 末尾是音频或返回音频 MIME）。**2026-10-23 修订（ADR-0062 §决策 3）：地址层不再按形状区分 HLS**——`.m3u8` 交给播放器，Android/iOS 实测可播，Windows 受随包 libmpv 限制不可播；原文「HLS 不在本轮」的判据（当时未做探针）已被该决策取代。以下为原文：
  需要额外播放器能力与真源证据，登记为未闭环（§3.7）。

### 决策 3 依赖：播放与 TTS 各一个插件，后台能力按平台降级

| 用途 | 包 | 许可 | 平台 | 用途边界 |
|---|---|---|---|---|
| 音频播放 | `just_audio` + Windows 实现 `just_audio_windows` | MIT（扫描确认后写 `NOTICE.md` §5） | Android / iOS / Windows | 只做播放，不含媒体通知 |
| 后台 / 通知 | `audio_service` | MIT | Android / iOS（**无 Windows**；2026-10-23 起 Windows 由 `audio_service_win` 补上 SMTC，见 ADR-0062 §决策 4） | Android 前台服务 + 媒体通知、锁屏控制 |
| 朗读 | `flutter_tts` | MIT | Android / iOS / Windows | 系统 TTS；音色取系统列表 |

- **Windows 降级（C-PLT-1）**：播放照常（`just_audio_windows`），但没有媒体通知/锁屏控制 ——
  `PlaybackNotification` 端口在 Windows 上是 no-op，UI 不判断平台（`Platform.isXxx` 只允许出现在
  `core/platform/`）。
- **TTS 后台**：Android 用 `flutter_tts` 的 `awaitSpeakCompletion` + 前台服务；
  Windows 在窗口最小化时继续朗读（系统 TTS 进程独立），不做额外服务。
- **依赖写入时机**：M17 的第 0 步先跑 `flutter pub add` 前的**三端可编译探针**
  （`tool/spike/audio_probe`：各插件最小调用 + 双端设备级实跑），过不了就换候选
  （`media_kit` 系列）并先改本 ADR；**核实完成前不写 `pubspec.yaml`**（C-DEP-1、C-DEP-7）。
- 许可证扫描：三个包都必须在 `tool/scan_licenses.dart` 的允许族内，并把结果写进 `NOTICE.md` §5。

### 决策 4 播放器的最小面

- 播放 / 暂停、进度条与 seek、倍速（0.5–2.0）、上一章 / 下一章、播放失败重试。
- 播放进度写 `reading_progress`（章节 + 毫秒偏移），与文本阅读同一张表、同一回落口径；
  音频与文本的进度互不覆盖：偏移列按模式解释（文本是比例估算，音频是毫秒）。
- 息屏 / 切后台在 Android 继续播放，由 `audio_service` 的 `AudioHandler` 承担；
  iOS 走 `AVAudioSession.playback` 类别；Windows 不承诺后台。
- 定时停止（sleep timer）**不在本轮**：上游有 `ReadAloudTimerSheet`，但无用户需求证据，登记 §3.7。

### 决策 5 TTS 朗读的最小面

- 起读点 = 当前章节正文开头（本轮不做「从当前滚动位置起读」的字符锚点，原因同 ADR-0044 §决策 4：
  精确锚点需要版本化的锚点模型）。
- 语速 / 音高 / 系统音色、暂停 / 继续 / 停止、读完自动进入下一章、朗读进度在正文里高亮当前句
  **不做**（需要句级切分与锚点，登记未闭环）。
- 朗读中退出阅读器：可配置「继续朗读 / 停止」，默认停止（避免用户找不到声音来源）。

## 影响

- `features/reader/`：`fetch_audio_tracks` / `fetch_manga_pages` 之外新增两条播放器 Notifier、
  一个 `core/platform/playback_notification.dart` 端口 + 三端实现。
- `pubspec.yaml` 增三到四个依赖（含 Windows 实现），`NOTICE.md` §5 与 `tech-stack.md` §1 同步。
- 阅读器 UI：按 `sourceType` 分派（文本 / 图片 / 音频）与控制条；ARB 双语新增播放器与朗读文案。
- 测试：解析单测（列表 / 相对地址 / 空 / 失败）、Notifier 单测（播放状态、章节切换、进度写读）、
  Widget 测试（无真实音频：注入 `FakeAudioPlayer` 端口）、双端设备级实跑（真实音频 URL 离线不测）。

## 后果

- 好的方面：音频源与听书从「打开就是纯文本」变成可用；两条链路互不牵连，任一条失败不影响另一条。
- 代价：三端插件接线与平台配置（Android `POST_NOTIFICATIONS`、前台服务类型 `mediaPlayback`、
  iOS 后台音频能力）是本次最重的原生工作；Windows 无媒体通知是**有意降级**。
- 未闭环（登记 §3.7）：云 TTS（ADR-0063 Proposed）、语音缓存、定时停止、投屏、Windows 后台播放。
  **2026-10-23 更新（ADR-0062）：** 句级高亮已落地；HLS 在 Android/iOS 可播、Windows 受随包 libmpv 限制；
  Windows 媒体通知已接入（无时间轴）。

## 落地注记（2026-10-22，M17 交付）

- **依赖与探针**：`just_audio 0.10.6` / `just_audio_windows 0.2.3` / `audio_service 0.18.19` /
  `flutter_tts 4.2.5`（全部 MIT；`NOTICE.md` §5 基线 176 包 / Risky none）。探针在一次性工程里跑通
  Windows + Android 构建后，才写入 `pubspec.yaml`；本机另需 `nuget.exe`（flutter_tts 的 C++/WinRT）
  与 MSVC `/utf-8`（just_audio_windows 的 UTF-8 源码 + `/WX`），已写入 `platform.md` §1.2。
- **A-1 的实体只有 `url` + `headers`**：Legado 的 `ruleContent` 没有供时长 / 标题的字段，章节标题已由
  目录提供，时长由播放器解码后回报——ADR 正文里的「可选时长 / 标题」没有可消费来源，故不建死字段。
- **播放器 / TTS 的失败复用 `ParseFailureKind`**（`parseFailed` / `unsupportedRule`），但 UI 用专用
  文案（`readerAudioFailed` / `readerTtsFailed`）而不是 `FailureMessage`：播放失败不是书源解析失败，
  共用一个按 kind 翻译的文案会把「音轨打不开」说成「规则失效」。
- **`audio_service` 懒初始化**：`AudioService.init` 在第一次 `attach` 时调用（进程内单例），而不是在
  `main()`；Windows 走 `NoopPlaybackNotification`（`null` 句柄）。Android 13+ 的
  `POST_NOTIFICATIONS` 由 `MainActivity` 的专用 MethodChannel 请求，结果不阻塞播放。
- **通知只推不连续点**：`PlaybackState.updatePosition` 只在播放 / 暂停 / 缓冲 / 片尾 / seek 时更新，
  位置由系统按 `speed` 投影，避免每秒五次刷通知。
- **进度列按模式解释**：音频写 `reading_progress.charOffset` 的**毫秒**值（与文本的比例估算共用一列，
  这是 ADR §决策 4 的原意）；`ReaderSession` 换章会把偏移清零，音频只在首次装载时 seek。
- **真源抽查未通过（记「已实现未验证」）**：用户提供的「🔊书音M」`chapterUrl` 是 `@js:` 字符串，里面
  嵌了 `{{$.id}}`，并引用上游 `book` 对象；本仓的矩阵 #14 规定脚本里的 `{{…}}` 属于脚本、沙箱只暴露
  `bookName` / `chapterTitle`，因此目录地址里留下字面量 `movieId={{$.id}}`，站点回「章节不存在」。
  两条缺口登记在 `roadmap.md` §3.7；**播放器本身**已由 `integration_test/audio_playback_test.dart`
  在 Windows / Android 用本地 WAV 实播验证。真源还暴露并修掉了一个引擎 bug：JSON 条目上的 `@js:`
  字段丢失页面 `baseUrl`（`_jsContextOf(JsonScope)`），已补单测。

> **2026-10-22 补记（ADR-0060）：** 真源解析阻塞已修复——脚本内 `{{…}}` 展开、URL 选项先切后绝对化、音频地址形态校验之后，书音M 跑到 `audioTracks ok(1)`；剩余 `book` 绑定、`webView`、远端流播放与明文媒体策略仍按 §后果 / `roadmap.md` §3.7 未闭环。

