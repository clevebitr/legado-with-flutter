# ADR-0064 播放页只跟随「结构状态」，位置 tick 不再重建整页

- **状态：** Accepted（2026-10-23，用户实跑 Windows 播报「日志报错」后定位）
- **日期：** 2026-10-23
- **关联：** ADR-0054 §决策 4（播放视图）、ADR-0061/0062（播放后端与 Windows 通知）、
  C-PERF-2、C-UI-7、`docs/dev/roadmap.md` §3.7

## 背景

Windows 上实测听书源时日志被两类消息刷屏：

1. `Failed to set thumbnail: 00000202111B06AC`（一次）
2. `[ERROR:flutter/shell/platform/common/accessibility_bridge.cc(114)] Failed to update
   ui::AXTree, error: Nodes left pending by the update: 551`（持续重复）

第一类来自 `audio_service_win` 的 WinRT `put_Thumbnail`：我们的
`PlaybackNotificationMetadata` **从不填 `artUri`**（书源没有可靠的本地封面文件），插件仍然尝试
设缩略图，失败后自己打日志。第二类是 Flutter Windows 嵌入层的 UIA 桥：一次语义树更新里留了
未挂接的节点（同类问题见 flutter/flutter#103808 / #193588）。

第二类与我们的代码有关的部分是可测的：`AudioReader` 在**每个引擎快照**（~5 次/秒）重发
`position`，而 `AudioReaderView.build` 直接 `ref.watch` 整个 `AudioReaderState` —— 于是 AppBar、
`Tooltip`、速度 chips、`Slider` 与两个时间标签的语义子树每秒重建五轮。语义树如此高频地整片替换，
正是 Windows 桥报「Nodes left pending」的温床；即便不是唯一原因，把「位置 tick」放大成「整页重建」
也是不该付的代价（C-PERF-2）。

## 决策

### 决策 1 页面订阅投影，不订阅整个状态

- 新增 `AudioReaderSkeleton`（record typedef）+ `audioReaderSkeleton(state)`：播放页**结构**需要的
  全部字段（有无音轨、失败 `rulePath`、加载/缓冲/播放/播完、速度、轨道数、当前轨道、时长），
  **不含 `position`**。
- 页面 `ref.watch(audioReaderProvider(book).select(audioReaderPageState))`：投影相等 ⇒ Riverpod 不
  通知 ⇒ 整页不重建。
- 位置与两个时间标签由 `_positionRow` 里一个自己的 `Consumer` 订阅 `position`（滑条 `max` 用的
  `duration` 属结构，随投影走）。
- 契约写进 `AudioReaderSkeleton` 的文档：给 `AudioReaderState` 加字段时必须判「结构 or tick」，
  tick 类字段不得进入投影。

### 决策 2 两类 Windows 日志登记为「引擎 / 插件噪声」，不由业务层吞掉

- **缩略图**：不伪造 `artUri`（拿不到可用的本地文件就不该假装有封面），也不去关闭插件的日志；
  登记在 `roadmap.md` §3.7，触发条件 = 插件提供「无封面时不尝试」的开关或我们开始缓存封面。
- **AXTree**：决策 1 直接削掉我们能控制的那一半（每秒五轮整页重建）。剩下的部分属嵌入层缺陷，
  与播放功能无关；登记同上，触发条件 = 升级 Flutter 后复现仍在，则按上游 issue 跟进。
- 不引入「`ExcludeSemantics` 包住整页」这类做法：那是把无障碍功能关掉来换日志安静（C-UI-7 的
  反面），而位置/控件本来是必须可读的。

## 后果

- 播放中的重建量从「每秒 5 次整页」降到「每秒 5 次一行（滑条 + 两个 `Text`）」；`Slider` 的
  `semanticFormatterCallback` 只在真正变化时更新。
- 回归点（`test/features/reader/presentation/widgets/audio_reader_view_test.dart`）：
  - `audioReaderSkeleton_ignoresTheTickingPosition`：位置不同的两个状态投影相等；
  - `snapshots_givenOnlyThePositionChanges_doNotNotifyThePage`：只改位置的快照**不通知**页面投影，
    但位置仍旧上屏。
  把 `position` 加回投影时这两条会红（已实测）。
- 未做：`audio_service_win` 的缩略图缺口（插件侧）；Windows UIA 桥的引擎缺陷（上游）。
  两者都记在 `docs/dev/roadmap.md` §3.7，不静默丢。
