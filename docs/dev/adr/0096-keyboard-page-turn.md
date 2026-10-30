# ADR-0096 键盘翻页：桌面端方向键翻页，Android 音量键登记未做

- **状态：** Accepted（2026-10-30，M37 规格前置；补上游 `PageKeyConfig` 的「键位翻页」缺口）
- **日期：** 2026-10-30
- **关联：** ADR-0093（`ReaderPageTurn` 命令对象与自动翻页）、ADR-0087/0088（页表与跨章）、
  `docs/dev/platform.md` §2（平台差异走端口/降级）；上游 `help/config/PageKeyConfig.kt`、`ReadBookController` 的按键处理

## 背景

上游允许配置翻页键位（含音量键），桌面与 Android 都能用键翻页。本仓只有手势与三区点击，
Windows 上「按右箭头没反应」是明显的可用性缺口（这次对话的日志就是 Windows 端）。

## 决策

### 决策 1 翻页命令带上方向，两种 flow 各自镜像实现

`ReaderPageTurn` 从「只有 next」扩展成 `next()` / `previous()` + `direction` 属性
（ADR-0093 §决策 2 的命令对象不变形：仍然只有一个监听通道）。
分页 flow：`nextPage` / `previousPage`；滚动 flow：`± viewportDimension`，夹到滚动范围。

### 决策 2 键位：方向键、PageUp/PageDown、空格

用 `CallbackShortcuts` 包住阅读器的 `Scaffold`，并用 `Focus(autofocus: true)` 拿焦点：

| 键 | 动作 |
|---|---|
| → / ↓ / PageDown / Space | 翻一页（滚动模式翻一屏） |
| ← / ↑ / PageUp | 回一页（滚动模式回一屏） |

- **只用 Flutter 自己的快捷键层**，不引第三方键位库（C-DEP-1）；也不抢面板：面板是独立路由，
  键盘事件先给最内层，`TextField` 里打字不会被当成翻页。
- 按键是**手动**输入：按下即停自动翻页（ADR-0093 §决策 3.2 的同一条理由）。
- 不做「自定义键位」：上游那套配置需要一整套键位编辑器，收益不成立；触发条件 = 用户明确要求改键。

### 决策 3 Android 音量键**登记未做**

Android 的音量键不会进 Flutter 的键盘事件（系统先消费），要抓它必须走平台通道拦截
`KEYCODE_VOLUME_UP/DOWN`，并且要处理「用户其实想调音量」的冲突与无障碍语义。本仓暂不做：
Android 上已有手势、三区点击与自动翻页三条路径。触发条件 = 用户点名要音量键翻页。

## 影响

- `reader_page_turn.dart`：方向枚举 + `previous()`；两个 flow 的 `_onTurn` 按方向分支。
- `reader_page.dart`：`CallbackShortcuts` + `Focus` 包住 `Scaffold`，新增两个处理函数（先停自动翻页）。
- 测试：页面级两条（→ 翻一页、← 回一页），沿用 M34 的分页模式夹具。

## 后果

- 好处：Windows / 桌面第一次能用键盘读；与自动翻页共用同一条翻页路径，没有第二套页码。
- 代价：滚动模式下 ↓/↑ 被映射成「翻一屏」而不是「滚一行」——这与上游音量键的语义一致，但和浏览器习惯不同，
  所以只在阅读器内生效。
- 未做：音量键、自定义键位（见决策 3 与 §决策 2 末段）。
