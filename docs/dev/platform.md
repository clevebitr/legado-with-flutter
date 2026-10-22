# 平台适配

> 约束见 `docs/dev/constraints.md` §7（C-PLT-1..5）。
> 本文档是平台基线与降级验收标准的**唯一来源**，其他文档不得另立版本号。

---

## 1. 平台基线

| 平台 | 最低版本 | 目标版本 | 依据 |
|---|---|---|---|
| Android | **`minSdk 26`**（Android 8.0，已在 `android/app/build.gradle.kts` 显式固定） | `targetSdk 36`（= `flutter.targetSdkVersion`） | 本项目自定的最低测试面（Drift + 原生 SQLite 链路）；**不来自任何第三方包的要求**，依据与备选方案见 ADR-0018 |
| iOS | **`15.0`**（`IPHONEOS_DEPLOYMENT_TARGET`） | 跟随 Flutter 3.47 默认 | 模板生成值，已核对 |
| Windows | Windows 10 1809+；CMake ≥ 3.14 | — | Flutter 桌面基线 |

`compileSdk` 跟随 `flutter.compileSdkVersion`（当前 36）。

> **验证状态：** ✅ 已核对生成后的平台工程与构建产物（APK 的 merged manifest 原先为
> `minSdkVersion=24 / targetSdkVersion=36`，现已显式将 minSdk 改为 26），数值不再是推测值。
> 基线为何保持 26（而不是回到 Flutter 默认 24）见 ADR-0018。

### 1.1 本机工具链实测版本

| 组件 | 版本 |
|---|---|
| Flutter / Dart | 3.47.7 stable / 3.13.5 |
| Android SDK / build-tools | 37.0.0 |
| AGP / Kotlin Gradle Plugin | 9.1.0 / 2.4.0 |
| Gradle JVM | JDK 21（Temurin 21.0.12） |
| Visual Studio（Windows 构建） | Community 2022 17.11.0 |
| CMake（原生插件） | 由 Flutter 自动装入 3.22.1 |

### 1.2 Windows 桌面构建的前置条件

`flutter build windows` / `flutter run -d windows` **要求系统开启「开发者模式」**，
否则 Flutter 无法为插件创建符号链接并直接失败：

```
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

开启方式（需要管理员权限）：`设置 → 系统 → 开发者选项 → 开发人员模式`，
或执行 `start ms-settings:developers`。

> 本项目依赖多个带原生代码的插件（`drift_flutter`、`path_provider`、`shared_preferences`、
> `dynamic_color`、`cached_network_image`、`flutter_qjs_next`、`just_audio_windows`、`flutter_tts`），
> 因此该开关是 Windows 开发的**硬前提**。Android 与纯 Dart 开发（`flutter test` / `flutter analyze`）不受影响。

**M17 起新增的两个 Windows 构建前提（ADR-0054 A-0 实测）：**

| 前提 | 谁需要 | 不满足时的表现 |
|---|---|---|
| `nuget.exe` 在 `PATH` 上（本机放在 `C:/Users/<user>/tools/nuget.exe`） | `flutter_tts` 的 Windows 实现（C++/WinRT，`nuget install Microsoft.Windows.CppWinRT`） | `CMake Error at flutter_tts/windows/CMakeLists.txt: nuget.exe not found` |
| MSVC `/utf-8`（已在 `windows/CMakeLists.txt` 的 `APPLY_STANDARD_SETTINGS` 统一加） | `just_audio_windows` 的 UTF-8 源码；代码页 936 下 C4819 被 `/WX` 放大成构建失败 | `error C2220: 以下警告被视为错误` + `warning C4819` |

---

## 2. 平台抽象接口

平台差异只能通过 `lib/core/platform/` 下的接口暴露（C-PLT-1）：

| 接口 | 职责 | UI 侧用法 |
|---|---|---|
| `PlatformInfo` | 暴露 `isMobile` / `isDesktop` / `isAndroid` | 经 `core/di/platform_provider.dart` 注入，但**只允许 `core/platform/` 内的 resolver 与测试消费**；业务层不得用它分支平台（ADR-0020 §4） |
| `DynamicColorProvider` | **包装 `DynamicColorBuilder`**：`Widget resolve(Widget Function(ColorScheme? light, ColorScheme? dark) builder)`；无能力时由调用方以 `null` scheme 走种子色 fallback（ADR-0020） | 在 `lib/app.dart` 根部注入，UI 不判断平台 |
| `PredictiveBackSupport` | 提供 `PageTransitionsTheme`（支持时用预测性返回，否则回退） | 注入 `app.dart` 的 `theme` |
| `SystemUiController` | 状态栏透明、edge-to-edge 适配 | 在 `core/theme/` 统一调用 |
| `HapticsController` | 触感反馈能力探测与降级 | 组件内调用，不判断平台 |
| `LongRunningTask` | 长任务的前台标记（Android 为 `PARTIAL_WAKE_LOCK`） | 批量书源校验开始 / 结束时 `acquire` / `release`（ADR-0043 §决策 3） |
| `PlaybackNotification` | 媒体通知 / 锁屏控制（Android / iOS 由 `audio_service` 实现；Windows 返回 no-op 的 `null` 句柄） | 音频播放器在播放状态变化时 `attach` / `update` / `detach`；**UI 不判断平台**（ADR-0054 §决策 3/4） |

**契约：** 每个接口在不支持的平台返回 `null` 或 no-op，**禁止抛出异常**；
调用方必须把 `null` 当作正常分支处理，不得用 `!` 解包（C-TYPE-2）。

---

## 3. 动态取色矩阵

| 平台 | 能力 | 行为 |
|---|---|---|
| Android 12+（API 31+） | 支持 | `dynamic_color` 的 `DynamicColorBuilder` 返回系统色 |
| Android 8–11 | 不支持 | 使用应用内种子色 |
| iOS | 不支持 | 使用默认种子色（C-PLT-4） |
| Windows | 不支持 | 使用应用内种子色（C-PLT-3） |

链路：`core/platform/` 的 `DynamicColorProvider`（内部包装 `DynamicColorBuilder`）
→ `ColorScheme?` → `lib/app.dart` 交给 `core/theme/` 的 `buildReaderTheme`
→ `ColorScheme.toM3EThemeData()` → `M3ETheme`（C-UI-3、ADR-0004、ADR-0020）。
**取色真源只能是 `dynamic_color`。**

---

## 4. 预测性返回（Android）

`android/app/src/main/AndroidManifest.xml` 的 `<application>` 必须包含：

```xml
<application
    android:enableOnBackInvokedCallback="true"
    ... >
```

Flutter 侧在主题中启用：

```dart
pageTransitionsTheme: const PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
  },
),
```

- 该接线必须放在 `core/platform/` 提供的 `PageTransitionsTheme` 中，UI 不判断平台（C-PLT-2）。
- iOS 必须使用原生 `CupertinoPageTransitionsBuilder` 以保留边缘返回手势（C-PLT-4）。

---

## 5. 路径与文件系统

- 所有路径必须经 `path_provider` 获取（C-PLT-3）。
- 目录划分：

| 用途 | 位置 |
|---|---|
| 数据库 | `getApplicationSupportDirectory()/reader.db` |
| 缓存 | `getApplicationCacheDirectory()/` |
| 导入导出的书源 | 由用户显式选择路径 |

- 禁止硬编码 `C:\`、`/Users/`、`/storage/`；禁止拼接平台分隔符（使用 `path` 包）。

---

## 6. 三端验收清单

每个涉及平台行为的 PR 必须逐项确认：

**Android**

- [ ] Android 13+ 侧滑返回出现预览动画（预测性返回生效）
- [ ] Android 12+ 开启壁纸取色后主题跟随系统色变化
- [ ] Android 8–11 主题使用种子色且无崩溃
- [ ] 状态栏/导航栏在 edge-to-edge 下内容不被遮挡
- [ ] 批量书源校验运行期间 `LongRunningTask.isSupported` 为 true，退出后 wake lock 已释放（`dumpsys power` 无残留 tag）

**iOS**

- [ ] 边缘返回手势可用，且与预测性返回无冲突
- [ ] 主题使用种子色，视觉与 Android 种子色模式一致
- [ ] 无因动态取色缺失导致的 `null` 崩溃

**Windows**

- [ ] 主题使用种子色，无动态取色相关报错
- [ ] 数据文件写入 `getApplicationSupportDirectory()`，不写 `C:\` 根目录
- [ ] 鼠标悬停/键盘焦点态在 MD3E 令牌下有可见反馈
- [ ] 窗口缩放时布局按 `LayoutBuilder` 重排，无溢出

---

## 7. 降级原则

1. **能力探测优先于平台判断**：先问接口「你支持吗」，而不是问「你是哪个平台」。
2. **降级必须可见**：无法提供的能力要么给出种子色/静态转场，要么在设置页说明，禁止静默半残。
3. **不影响核心链路**：书源解析、阅读、书架在无动态取色、无预测性返回的平台上必须功能完整。
4. **新增平台**：必须新增 `core/platform/` 实现并补齐 §6 清单，不得在业务层加 `Platform.isXxx`。

---

## 8. 已知构建变通与待办

### 8.1 已写入仓库的构建变通

| 位置 | 设置 | 原因 |
|---|---|---|
| `android/gradle.properties` | `kotlin.incremental=false` | Kotlin 2.4 的增量编译缓存在 Windows 上偶发文件锁定，报 `Could not close incremental caches` 并中断构建（最近复现于 `dynamic_color` 模块）。**这是工具链问题，与任何插件无关，不要因更换插件而删除。** |

> 另一条曾经的变通 `kotlin.jvm.target.validation.mode=warning` **已删除**：它只为已移除的
> `flutter_js_plus`（固定 `kotlin 1.7.20` / `jvmTarget 1.8`，与 AGP 9 默认的 Java 11 不一致）而加。
> 删除后实测：`flutter build apk --debug` 与 `flutter build windows --debug` 均成功（ADR-0015）。

### 8.2 发布前必须处理的待办

| 项 | 说明 |
|---|---|
| `applicationId` | 当前为 Flutter 默认的 `com.example.flutter_reader`；`com.example.*` 无法上架。改动点：`android/app/build.gradle.kts` 的 `namespace` 与 `applicationId`、`ios/Runner.xcodeproj` 中的 `PRODUCT_BUNDLE_IDENTIFIER`（共 3 处配置） |
| 发布签名 | `android/app/build.gradle.kts` 的 release 构建当前复用 debug 签名 |
| Windows 开发者模式 | 见 §1.2，需在每台开发机开启（管理员） |
