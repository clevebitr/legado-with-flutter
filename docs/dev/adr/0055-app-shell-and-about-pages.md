# ADR-0055 应用外壳与关于/法律声明页（M18）

- **状态：** Accepted（2026-10-22，用户裁决「开始补齐 UI」；范围见 `docs/dev/ui-gap.md` U1–U3）
- **日期：** 2026-10-22
- **关联：** C-UI-1、C-UI-5、C-UI-7、C-UI-9、C-ARCH-2、C-ARCH-6、ADR-0011、ADR-0042、
  `docs/dev/roadmap.md` §3.11、`docs/dev/architecture.md` §1/§6

## 背景

本仓的落地页是**搜索页**，书架 / 发现 / 设置只能从搜索页的工具栏互相 push；返回键要一层层退，
四个 feature 没有一个稳定的「家」。同时：
- 没有「我的」聚合入口，书源管理藏在搜索页工具栏，设置只有四项；
- C-UI-9 要求的「关于 → 法律声明」页还不存在（5.9 的 GPL 门禁项）。

上游用 `ui/main/MainScreen.kt` + `AppNavigationBar` 提供底部导航，`ui/main/my/MyScreen.kt` 作为
入口聚合页。本 ADR 只定 M18 的形态，不做首页统计、RSS、主题配置（见 `ui-gap.md` P2）。

## 决策

### 决策 1 外壳在**组合根**（`lib/app_shell.dart`），「我的/关于/法律声明」在 `features/shell/`

- 外壳必须组合四个 feature 的页面（书架 / 发现 / 搜索 / 我的），而 `features/A` 不得 import
  `features/B` 的内部文件（C-ARCH-2）。因此 `AppShell` 放在**根级** `lib/app_shell.dart`：
  与 `app.dart` 同属组合根，是项目里唯一允许同时认识多个 feature 页面的位置。
- `features/shell/` 只放**不组合别人页面**的三页（我的 / 关于 / 法律声明），目录只要
  `presentation/`（`pages/` + `shell_route.dart`），没有 `data/`/`domain/`。
  这是 `architecture.md` §1 的**具名例外**：判据是「不持久化、不解析、不 import 其他 feature」。
- 「我的」页的跳转只走 `AppNavigation` 端口（ADR-0042）：新增 `openBookSources` / `openAbout`
  两个方法，绑定仍在 `app.dart`；`shell` 因此不 import `book_source` / `settings`。
- 不放进 `core/widgets/`：`core/` 不得 import `features/`（C-ARCH-2），而外壳必须认识页面。

### 决策 2 四个 tab，`IndexedStack` 保活，每个 tab 保留自己的 Scaffold

- tab：**书架 / 发现 / 搜索 / 我的**；默认停在**书架**（阅读 App 的「家」）。
- `IndexedStack` 让四个页面同时存活：切 tab 不丢搜索进度、不重拉书架；代价是首帧就构建四页
  （四页都是懒加载列表 + provider，成本可接受）。
- 每个 tab 页面保留自己的 `Scaffold`/`AppBar`：外壳只提供底栏，不重写四个页面；嵌套 `Scaffold`
  在 Flutter 里是合法且常见的形态，底栏只在最外层。
- **不**引入每 tab 独立 Navigator：push 一律走根 Navigator（ADR-0011），返回键从任意详情/阅读页
  直接回到当前 tab。per-tab 栈等真有「tab 内多级后退」需求时再写 ADR。
- tab 索引不持久化：启动默认书架。上游的「默认首页」设置排到 M21 的主题配置一起做。

### 决策 3 「我的」只做入口聚合，不放业务逻辑

- 条目：**书源管理**（`BookSourceListRoute`）、**设置**（`SettingsRoute`）、**关于**（`AboutRoute`）。
- 每行动作只调用既有 `push…Route`（ADR-0042 的 presentation 端口），页面本身不读写仓储。
- 缓存清理留在设置页（5.7①），不在这里复制第二个入口（避免「两个清空缓存」）。

### 决策 4 关于页：版本常量 + 许可全文 + 源码地址

- `features/shell/presentation/app_info.dart` 持有 `appName` / `version` / `repositoryUrl`
  三个常量；`version` 必须与 `pubspec.yaml` 同步，**由单测读 `pubspec.yaml` 比对**（不引入
  `package_info_plus` 这类平台依赖）。
- GPL-3.0 全文作为 **asset** 打包（`assets/legal/gpl-3.0.txt`，来源是根 `LICENSE`），
  法律声明页用 `rootBundle` 读取；asset 读取失败显示可重试的失败文案，不空白。
- 源代码地址用**可选中的文本 + 复制按钮**给出，不引入 `url_launcher`（C-DEP-1：一个新依赖要
  过评审，而「看得到、抄得走」已满足 GPL-3.0 §6 的入口要求）。
- 法律声明页必须包含 C-UI-9 的六个键：`legalNoticesTitle`、`legalNoticesCopyright`、
  `legalNoticesNoWarranty`、`legalNoticesViewLicense`、`legalNoticesCorrespondingSource`、
  `legalNoticesProhibitedUse`（键名唯一出处是 `constraints.md` C-UI-9）。

### 决策 5 路由与落地页

- `app.dart` 的页面表新增 `AboutRoute`、`LegalNoticesRoute`；**未知路由的回落从搜索页改为外壳**
  （落地页就是外壳，回落到搜索会让返回栈多一层）。
- `AppRouter.homePath` 不变，`MaterialApp.initialRoute` 不变；变化只在 `_pageFor` 的默认分支。
- 旧测试（`test/app_test.dart`、`integration_test/app_boot_test.dart`）里「落地页是搜索页」的断言
  同步改为「落地页是外壳，且默认 tab 是书架」。

## 影响

- 新增 `features/shell/presentation/`：`pages/app_shell.dart`、`pages/my_page.dart`、
  `pages/about_page.dart`、`pages/legal_notices_page.dart`、`app_info.dart`、`shell_route.dart`。
- `lib/app.dart`：落地页与两个新路由；`assets:` 增加 `assets/legal/`；ARB 双语新增导航/我的/关于/
  法律声明文案。
- 测试：外壳 tab 切换与状态保活、我的页三条目可达、关于页版本（与 `pubspec.yaml` 比对）与
  法律声明六键存在、许可 asset 可读；`app_test` / `app_boot_test` 的落地页断言更新。

## 后果

- 好的方面：四个功能有了稳定的「家」，返回栈不再从搜索页层层退；C-UI-9 门禁闭环；后续 M19/M20/M21
  的新页面直接挂到「我的」。
- 代价：首帧构建四个 tab（可接受）；版本常量需要手工同步（单测兜底）。
- 未做：默认首页可配置、tab 顺序/图标定制、首页统计dashboard、每 tab 独立返回栈、RSS/AI —— 均按
  `ui-gap.md` 的 P2 或 §5 登记，不在 M18。
