# ADR-0086 阅读舒适度与状态栏：常亮、护眼、状态行

- **状态：** Accepted（2026-10-28，用户裁决：按上游阅读面缺口清单先做 1–7，不做 AI）
- **日期：** 2026-10-28
- **关联：** ADR-0044（阅读会话）、ADR-0051 §决策 1（沉浸式）、ADR-0075 §决策 2（亮度只做页内遮罩）、
  `docs/dev/constraints.md` C-UI-1/5/7、C-PLT-1/2、C-PERF-1；上游 `~/repos/legado-with-MD3`

## 背景

对照上游阅读面清点出 16 条缺口（`docs/dev/roadmap.md` §3.7 与本次清点）。用户裁决先做前 7 条，
本 ADR 记录它们的决策；后续决策按实现顺序追加，一次只加一条。

本仓此前的阅读器只有：沉浸式菜单、目录、书签、换源、书内搜索、阅读记录、排版六轴、四种底色、
亮度遮罩。上游还有一批「读久了才知道缺」的能力，前三条最直观：

1. 上游按住窗口的 `FLAG_KEEP_SCREEN_ON`（`ReadBookController.kt:335/466`），本仓没有 → 读几分钟就息屏；
2. 上游有护眼（色温 2596–5500 K 的滤镜，`EyeProtection.kt` + `EyeProtectionConfigSheet.kt`），
   本仓只有亮度遮罩（只会压暗，不会变暖）；
3. 上游可配置页眉/页脚（`BgTextConfigSheet.kt`），本仓沉浸式把时间与电量一起藏了，读的时候看不到。

## 决策

### 决策 1 常亮走平台端口，默认开启，离开阅读器交还

新增 `core/platform/screen_awake.dart`：`ScreenAwake` 端口（`isSupported` + `setAwake({bool awake})`），
Android 侧由 `MainActivity` 切窗口的 `FLAG_KEEP_SCREEN_ON`，其他平台是 no-op（`UnsupportedScreenAwake`）。

- **默认开**：阅读本来就是「很久不碰屏幕」，默认关等于默认给错体验；设置里可以关。
- **打开即要、离开即还**：`initState` 后按设置申请，`dispose` 里释放（幂等）；设置改动通过
  `listenManual(..., fireImmediately: true)` 跟随 —— 用 `listenManual` 是因为 flutter_riverpod 3 的
  组件级 `ref.listen` 没有 `fireImmediately`，而首值必须也生效。
- **不申请权限**：`FLAG_KEEP_SCREEN_ON` 是窗口标志，不是 `WAKE_LOCK`（那是批量校验用的
  `core/platform/long_running_task.dart`，两者互不复用）。

### 决策 2 护眼是一条**颜色矩阵**，纯函数，只作用正文

`reader_style.dart` 新增 `readerEyeProtectionMatrix(int strength)`（0–100，0 = 关）与包装
`readerEyeProtectionFilter(...)`。红通道保持、绿通道略降、蓝通道压得最多，并各带一点负偏移：
方向与上游的色温一致，实现只有一个矩阵（不搬上游的二次拟合）。

- **只作用在正文**：亮度遮罩与状态栏本身就是「看得清」的手段，再被压暖就自相矛盾。
- **不动系统亮度**：与 ADR-0075 §决策 2 同一条边界（遮罩只压暗/压暖，不改屏幕）。
- **成分拆开**给测试：`ColorFilter` 不暴露矩阵数字，所以映射单独是一个纯函数。

### 决策 6 状态行：一行、常驻、不吃手势

新增 `ReaderStatusBar`：左 = 章节名（净化后标题），中 = 「第 x/y 章 · 本章 z%」，右 = 时间 + 电量。

- **常驻**：它替代被沉浸式藏起来的系统状态栏，所以不跟着 chrome 一起隐藏；设置里可关。
- **不吃手势**：整行 `IgnorePointer`，三区点击照旧穿过（ADR-0051 §决策 1）。
- **页面级遮罩之上**：状态行在亮度遮罩与护眼滤镜之外，任何设置下都可读。
- **电量走端口**：新增 `core/platform/battery_level.dart`（`BatteryLevel.read()`，Android 读
  `BatteryManager.BATTERY_PROPERTY_CAPACITY`）。读不到就**不画**，不写假数字（C-UI-7）。
- **时间可注入**：`Clock` 端口（C-TEST：被测逻辑里不出现 `DateTime.now()`），30 秒刷新一次。

### 决策 7 章头 + 正文缺省时的「标题 + 正在加载」，槽位按章节下标派生

滚动模式把相邻章拼成一份文档后，读者分不出「这一章从哪开始」——上游的正文里本来就带章标题。
所以每个槽位都先印该章标题（`titleMedium`，颜色取正文前景色，最多两行、超出省略），正文还没
到手时标题下方是一个「正在加载」方块（失败时换成重试按钮）。高度按「标题 + 正文（或方块）」量：
偏移、锚点比例与结构补偿都按这两段分别计算，锚点的字符比例只量正文。

- **为什么标题要先出来**：读者滑到章界时要能看出「下一章是什么、还在加载」，而不是撞上一段空白
  或一个没有归属的转圈。上游的阅读视图同样先有章标题、再出正文。
- **同一份标题只出现一次**：状态行不再印章节名（§决策 6 修订），章名只属于正文里的章头。
- **正文按章节下标传，不按 URL**：抓下来的目录里两章指向同一个地址是常见形状；按 URL 归并会把
  它们压成一份正文，读者看到的就是同一章打印了两遍。
- **槽位是派生的，不是累积的**：`ReaderChapterSlots.of` 每次从会话章算出 `anchor-1 / anchor /
  anchor+1` 三段，流程不再自己维护「已渲染窗口」。ADR-0085 里那套窗口（保留 + 几何门槛 + 顶部补章）
  因此全部删除：它要靠三组互相独立的闸门保持一致，任何一组判错就是重复或跳字。
- **上一章的槽位只在锚点章自己撑得满一屏时才有**：这是章节自身的属性（不随滚动位置变化），
  否则短章会把上一章顶到视口顶上，而可滚动范围不足以补偿。
- 分页模式同样受益：正文未到的那一章占一页（标题 + 正在加载），翻过去就是它，到了原地换成正文。

## 后果

- 新增两个 `core/platform` 端口与两个 Riverpod provider（`screenAwakeProvider` / `batteryLevelProvider`），
  `MainActivity` 多两个通道（`flutter_reader/screen_awake`、`flutter_reader/battery`）；
- `ReaderSettings` 多三轴：`keepScreenAwake`（默认 true）、`eyeProtection`（0–100，默认 0）、
  `showReaderStatus`（默认 true），存 `shared_preferences`（`reader.keepScreenAwake` /
  `reader.eyeProtection` / `reader.showReaderStatus`），读回时钳制；
- 新增 ARB 键 `readerEyeProtection` / `readerKeepAwake` / `readerStatusLine` / `readerBatteryLevel`（en + zh）；
- 阅读器页正文多一层可选 `ColorFiltered`，底部多一条常驻状态行；
- 状态栏默认显示 → 阅读器页面测试里「章节标题只出现在 chrome 里」的假设不再成立，改为断言 `AppBar` 本身。

## 修订

- **2026-10-28（用户报障后）**：§决策 6 的状态行去掉章节名（正文里的章头已经印了，重复出现在两处），
  §决策 7 改写为「章头 + 标题下的加载块」，流程的窗口模型改为按章节下标派生的槽位（`ReaderChapterSlots`）。
  触发：真机上滚动模式出现「正文重复」「标题出现两次」「下一章没加载时没有标题」。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 常亮用 `WAKE_LOCK` | 那是「长任务不许被挂起」的语义（`long_running_task.dart`），屏幕该息还是息；窗口标志才是「别熄屏」 |
| 护眼做整屏 `ColoredBox` 蒙一层黄 | 会连带压掉状态栏与遮罩，而且只是「加黄」不是「降蓝」；矩阵才与上游同向 |
| 状态行跟着 chrome 一起显示/隐藏 | 那等于没解决「沉浸式看不到时间和电量」，读者得先点一下才看得到 |
| 电量用 `battery_plus` 依赖 | 一个只读百分比的能力换一个包（含三端原生插件），C-DEP-1 不划算；通道十几行就够 |
| 状态行做完整的上游页眉/页脚配置（每项开关、对齐、字体） | 先给一条能读的行；配置面等真的有人要再说（登记在 §后果） |
