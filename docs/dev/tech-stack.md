# 技术栈与工具链

> 依赖的**唯一来源**是根目录 `pubspec.yaml`；本文档只说明「为什么选它、对应哪条约束、
> 平台支持与许可证」（C-DEP-6）。本文档不复制 `pubspec.yaml` 与
> `analysis_options.yaml` 的正文。
>
> 版本已用真实的 `flutter pub get` 解析验证（2026-10-10，Flutter 3.47.7 / Dart 3.13.5），
> 下表版本与 `pubspec.yaml` 及 `pubspec.lock` 三者一致。

---

## 1. 版本策略

| 项 | 结论 |
|---|---|
| **约束**（`pubspec.yaml` 声明） | `sdk: ^3.13.0`、`flutter: ^3.47.0` |
| **实测工具链**（本机与 CI 使用） | Flutter **3.47.7**（stable）· Dart **3.13.5** |
| 依赖版本写法 | `^` 或精确版本，**禁止 `any`**（C-DEP-2） |
| 锁文件 | 提交 `pubspec.lock`；升级依赖必须单独 PR |
| 许可证 | 必须 GPL-3.0 兼容（C-DEP-7）；清单见 `NOTICE.md` §5 |
| lint 规则名基准 | Dart **3.13.x** 官方清单（`https://dart.dev/tools/linter-rules/all`）。`analysis_options.yaml` 的 47 条规则已逐名机器比对通过 |
| 分析器插件安装位置 | **顶层 `plugins:`**，不是 `analyzer: plugins:`（后者已弃用，见 §12） |

**版本号必须同步的四处**（改任一处必须同时改其余三处）：

| 位置 | 形式 |
|---|---|
| 本节（权威定义） | `3.47.7` / `3.13.5` |
| `pubspec.yaml` 的 `environment:` | `sdk: ^3.13.0`、`flutter: ^3.47.0`（区间约束，不必随补丁号改动） |
| `.github/workflows/ci.yml` 的 `flutter-version` | `'3.47.7'` |
| `docs/dev/platform.md` §1 的平台基线 | 与上述版本对应 |

### 1.1 依赖版本的确定方式（重要）

本项目的依赖版本**不是**逐个挑选的，而是由 `pub` 求解器在满足以下**硬约束**后得出的
唯一一致解，再回填为精确约束：

| 硬约束 | 由谁决定 |
|---|---|
| `dynamic_color` 必须是 **1.x** | `m3e_design 0.2.1` 声明 `dynamic_color: ^1.8.1` |
| `riverpod_annotation` / `riverpod_generator` 必须与 `riverpod` **精确同版** | `flutter_riverpod 3.4.3` 与 `riverpod_lint 3.1.9` 都精确锁定 `riverpod: 3.4.3` |
| `freezed` 必须 ≥ **4.x** | `riverpod_lint 3.1.9` 要求 `analyzer >=13 <15`，而 `freezed 3.2.5` 要求 `analyzer <11`，二者无交集 |
| `json_annotation` 必须 **4.12.x** | `json_serializable 6.14.1` 要求 `>=4.12.0 <4.13.0` |
| `drift_dev` 只能 **2.35.1** | 该包版本落后 `drift` 本体一个补丁，`^2.35.2` 不存在 |

> 因此**不要**单独手动升降其中任何一个版本：它们互相咬合。
> 需要升级时必须整组处理，并用 `flutter pub get` + 门禁复验。

**验证状态：** ✅ 已用 `flutter pub get` 实测解析通过（151 个包），
并通过 `flutter analyze`（零问题）、`flutter test`、`flutter build apk --debug` 三项验证。

---

## 2. 运行时依赖

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `flutter` | SDK | 框架 | BSD-3-Clause | — |
| `flutter_localizations` | SDK | 本地化运行时 | BSD-3-Clause | C-UI-5 |

## 3. UI 与主题

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `m3e_design` | `^0.2.1` | MD3E 设计令牌（`M3ETheme` ThemeExtension） | MIT | C-UI-1、C-UI-2 |
| `dynamic_color` | `^1.9.0` | Android 壁纸种子色取色（`DynamicColorBuilder`） | Apache-2.0 | C-UI-3、C-PLT-2 |

> **`dynamic_color` 只能是 1.x：** `m3e_design 0.2.1` 声明 `dynamic_color: ^1.8.1`，
> 升到 2.x 会导致版本求解失败。要升级 `dynamic_color` 必须先升级 `m3e_design`。
> `DynamicColorBuilder` 内部使用 `OptionalMethodChannel` + try/catch，因此在单元测试
> 环境下不会抛异常（已验证）。

### 3.1 `m3e_design` 0.2.1 官方 API（已核实）

```dart
@immutable
class M3ETheme extends ThemeExtension<M3ETheme> {
  final M3EColors colors;
  final M3ETypography typography;
  final M3EShapes shapes;
  final M3ESpacing spacing;
  final M3EMotion motion;

  static M3ETheme defaults(ColorScheme scheme);
  // copyWith / lerp 均已实现，支持主题插值动画
}
```

| API | 说明 |
|---|---|
| 安装 | `withM3ETheme(ThemeData base, {M3ETheme? override})` 或 `ColorScheme.toM3EThemeData()` |
| 读取 | `context.m3e`（`BuildContext` 扩展，自带 fallback，**推荐**）；或 `Theme.of(context).m3e`（`ThemeData` 扩展，debug 下 assert） |
| `M3EColors` | 包装 `ColorScheme` 并补充语义色：`surface`、`onSurface`、`surfaceStrong`、`onSurfaceStrong`、`outlineStrong`、`emphasis`、`onEmphasis`、`info`、`success`、`warning`、`danger`、`primary`/`onPrimary`、`primaryContainer`/`onPrimaryContainer`、`secondary`/`onSecondary`、container 层级、`outline`、`inverse` |
| `M3ESpacing` | 六阶间距：`xs=4`、`sm=8`、`md=12`、`lg=16`、`xl=24`、`xxl=32`；`M3ESpacing.regular()` |
| `M3ETypography` | `{required TextTheme base, required M3EEmphasized emphasized}`；`M3ETypography.defaultFor(Brightness, {String? brandFontFamily, ...})` |
| 取文本样式 | **必须经 `base`**：`tokens.typography.base.titleLarge`（**不存在** `tokens.typography.titleLarge`） |
| `M3EEmphasized` | 强调变体，逐角色提供 `display` / `headline` / `title` / `label` 的 `TextStyle` |
| `M3EShapes` | `round` / `square` 家族与按尺寸分类的圆角 |
| `M3EMotion` | 时长与缓动（`M3ETheme` 会参与 `lerp`，可直接用于主题过渡） |

**禁止写法：**

```dart
// ❌ 不存在这两个成员（旧文档的错误示例）
final t = Theme.of(context).extension<M3ETheme>()!;
t.colorScheme.surface;
t.textTheme.titleLarge;

// ✅ 正确
final m3e = Theme.of(context).m3e;
m3e.colors.surface;
m3e.typography.base.titleLarge;
m3e.spacing.md;
```

- **禁止** `Theme.of(context).extension<M3ETheme>()!`（无用且违反 C-TYPE-2）。
- 动态取色链路：`DynamicColorBuilder` → `ColorScheme` → `toM3EThemeData()`；
  Windows / iOS 走种子色 fallback（C-PLT-3、C-PLT-4）。

## 4. 状态管理

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `flutter_riverpod` | `^3.4.3` | 唯一状态管理方案 | MIT | C-STATE-1 |
| `riverpod_annotation` | `^4.0.7` | `@riverpod` 注解（必须与 `riverpod` 精确同版） | MIT | C-STATE-2 |
| `riverpod_generator`（dev） | `^4.0.9` | Provider 代码生成 | MIT | C-STATE-2 |
| `riverpod_lint`（dev） | `^3.1.9` | 禁止手写 Provider 等规则 | MIT | C-STATE-2 |

> 注意版本号"错位"：`flutter_riverpod` 与 `riverpod_lint` 在 **3.x** 线，而
> `riverpod_annotation` / `riverpod_generator` 在 **4.x** 线。这不是笔误 ——
> 两者都精确锁定 `riverpod: 3.4.3`，所以只有这两组组合能共存（见 §1.1）。

> Riverpod 3 的统一引用类型是 `Ref`（不再有 `XxxRef`）。

## 5. 书源解析引擎

| 依赖 | 版本 | 用途 | 平台支持 | 许可证 | 关联约束 |
|---|---|---|---|---|---|
| `html` | `^0.15.6` | HTML DOM | 全平台 | BSD-3-Clause | C-SRC-1 |
| `cascadia` | `^0.8.0` | CSS 选择器（唯一） | 全平台 | BSD-3-Clause | C-SRC-6 |
| `json_path` | `^0.9.0` | JSONPath（唯一） | 全平台 | MIT | C-SRC-6 |
| `flutter_qjs_next` | `^1.5.2` | JS 引擎（QuickJS，构建时从 `cxx/` 源码编译） | Android/iOS/Windows/Linux/macOS | MIT | C-SRC-2、C-SRC-3 |

> **该引擎已实测选定（2026-10-10，ADR-0015）**：9 项探针全通过，无预编译库、无需打补丁；
> 引擎级 `timeout` 与 `memoryLimit` **真实生效**（ADR-0008 要求的 5s / 32MB 均可实现）。
> 原生库由正常构建产出，探针通过 `FLUTTER_QJS_NEXT_LIBRARY` 指向产物运行；
> 详见 `tool/spike/README.md`。
>
> 已废弃的 `flutter_js_plus` 的缺陷记录保留在 ADR-0008 与 `tool/spike/README.md` §2。
| `betto_charset_detector` | `^0.1.0` | 字符编码检测（唯一，纯 Dart） | 全平台 | Apache-2.0 | C-NET-3 |

> **`betto_charset_detector` 的当前版本是 `0.1.0`**（尚未发布 1.x）。
> 早期文档写作 `^1.0.0` 会导致解析失败。
>
> `flutter_js_plus` 通过 dart-ffi 运行，因此可在独立 Isolate 中执行（C-SRC-2）。
> **约束：** 不得在后台 Isolate 中使用依赖 platform channel 的回调桥
> （如 `JavascriptRuntime.onMessage`）；需要双向通信时必须使用
> `BackgroundIsolateBinaryMessenger`，并补 `book-source.md` 的测试用例。
>
> **已知构建影响：** `flutter_js_plus 0.0.4` 是 2019 年的老插件，其 Android 编译脚本
> 固定 `kotlin 1.7.20` 与 `jvmTarget 1.8`，与 AGP 9 默认的 Java 11 目标不一致，
> 会导致 `assembleDebug` 失败。变通方法见 `docs/dev/platform.md` 的「已知构建变通」。

## 6. 网络与持久化

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `dio` | `^5.7.0` | HTTP 客户端（仅允许在 `core/network/` 内使用） | MIT | C-NET-1 |
| `cached_network_image` | `^3.4.1` | 图片缓存 | MIT | C-PERF-3 |
| `drift` | `^2.35.2` | 结构化数据主库（SQLite） | MIT | C-NET-7、C-NET-9 |
| `drift_flutter` | `^0.3.1` | 各平台原生 SQLite 与数据库路径 | MIT | C-NET-9 |
| `shared_preferences` | `^2.5.3` | 仅轻量开关（主题模式、字号） | BSD-3-Clause | C-NET-9 |
| `path_provider` | `^2.1.6` | 跨平台路径（唯一来源） | BSD-3-Clause | C-PLT-3 |

> **关于 `sqlite3_flutter_libs`：** 不要**直接**声明它。
> `drift_flutter 0.3.1` 自己会传递依赖 `sqlite3_flutter_libs: ^0.6.0+eol`
> （以及 `sqlcipher_flutter_libs: ^0.7.0+eol`），由它统一管理原生库版本；
> 直接依赖旧写法（如 `^0.5.x`）才会在新版 Android 工具链上丢库、启动时报
> `DriftRemoteException: dlopen failed: libsqlite3.so not found`（ADR-0003）。
> 已实测：`flutter build apk --debug` 成功，锁文件中的传递版本为 `0.6.0+eol`。

## 7. 观测

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `logger` | `^2.8.0` | 日志实现；业务侧只允许通过 `core/logging` 使用 | MIT | C-ERR-5、C-SEC-4 |

## 8. 代码生成

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `freezed_annotation` / `freezed` | `^3.1.0` / `^4.0.2` | 不可变数据类与密封类 | MIT | C-DEP-3 |
| `json_annotation` / `json_serializable` | `^4.12.0` / `^6.14.1` | JSON 序列化 | MIT | C-DEP-3 |
| `build_runner` | `^2.16.2` | 生成器运行器 | MIT | C-DEP-4 |
| `drift_dev` | `^2.35.1` | Drift 表与 DAO 生成 | MIT | C-DEP-3 |

> `freezed` 与 `freezed_annotation` 可以不同大版本：`freezed 4.0.2` 仍依赖
> `freezed_annotation 3.1.0`。

## 9. 开发与测试

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `flutter_lints` | `^6.0.0` | 基础 lint 规则集 | BSD-3-Clause | — |
| `mocktail` | `^1.0.5` | Mock 测试 | MIT | C-TEST-1 |

## 10. 已移除与明确禁止的依赖

| 依赖 | 状态 | 原因 |
|---|---|---|
| `sqlite3_flutter_libs` | **禁止直接依赖** | 只有作为 `drift_flutter` 的传递依赖才正确（见 §6 说明、ADR-0003） |
| `drift_flutter 0.3.1` | 已采用 | 替代直接依赖 `sqlite3_flutter_libs` 的旧做法 |
| `custom_lint` | **移除** | `riverpod_lint` 自 3.1.9 起改用 `analysis_server_plugin`，不再需要它（ADR-0010） |
| `golden_toolkit` | **移除** | 已停止维护；改用 Flutter 内置 `matchesGoldenFile`（ADR-0009） |
| `material_you_dynamic_theme` | **禁止引入** | 与 `dynamic_color` + `m3e_design` 职责重叠，会出现两个取色真源（ADR-0004） |
| `get_it` | **禁止引入** | 与 Riverpod 职责重叠（ADR-0005） |
| `flutter_js_plus` | **已移除** | 在 Dart 3.13 下编译失败 + Windows CMake 目标名错误 + 缺 `jsSetMemoryLimit`（ADR-0015） |
| `flutter_qjs`（原包，非 `_next`） | **禁止引入** | SDK 约束为 `>=2.12.0-0 <3.0.0`，明确排除 Dart 3；请用其维护中的后继 `flutter_qjs_next` |
| `Isar` / `Hive` | **未采用** | 持久化方案已定为 Drift（ADR-0003） |
| `bloc` / `flutter_bloc` / `get` / `provider` | **禁止引入** | 状态管理唯一方案为 Riverpod（C-STATE-1） |
| 任何 GPL-2.0-only / 无许可 / 专有许可的包 | **禁止引入** | 与 GPL-3.0 不兼容（C-DEP-7） |

---

## 11. 国际化配置

| 文件 | 作用 |
|---|---|
| `l10n.yaml` | `arb-dir: lib/l10n`，模板 `app_en.arb`，输出 `lib/l10n/generated/app_localizations.dart`，`nullable-getter: false` |
| `lib/l10n/app_en.arb` | 英文模板，新增字符串的**唯一入口**，必须带 `@key.description` |
| `lib/l10n/app_zh.arb` | 中文翻译 |

流程：

1. 先在 `app_en.arb` 添加键与描述，再在 `app_zh.arb` 补中文；两者必须在同一个 PR 内完成（C-UI-5）。
2. 生成：`flutter gen-l10n`（构建时也会自动执行，`pubspec.yaml` 已设 `generate: true`）。
3. key 命名规则见 `docs/dev/naming.md` §8。
4. 生成物位于 `lib/l10n/generated/`，已在 `analysis_options.yaml` 中排除，**禁止手改**（C-DEP-5）。

> `intl` 由 `flutter_localizations` 传递提供。仅当 ARB 使用 `type: date` / `type: number`
> 占位符时才需要显式声明 `intl`，此时必须与 `flutter_localizations` 的约束保持一致。
>
> 失败文案键与 `ParseFailureKind` 一一对应（`failure<PascalCaseKind>`），
> 见 `docs/dev/architecture.md` §5 与 `docs/dev/book-source.md` §7。

---

## 12. lint 规则与约束 ID 的映射

**执行方式：** `riverpod_lint ≥3.1.9` 基于 `analysis_server_plugin` 实现，
必须写在 `analysis_options.yaml` 的**顶层** `plugins:` 段（**不是** `analyzer: plugins:`，
后者已弃用并会触发 `analysis_options_deprecated_plugins`），由 `flutter analyze` 执行。
项目**不使用 `custom_lint`**（ADR-0010）。

| lint 规则 | 强制级别 | 约束 ID |
|---|---|---|
| `camel_case_types` / `camel_case_extensions` / `file_names` / `library_names` | error | `naming.md` §2/§3 |
| `non_constant_identifier_names` / `constant_identifier_names` | error | `naming.md` §5 |
| `always_declare_return_types` | error | `naming.md` §4 |
| `public_member_api_docs` / `slash_for_doc_comments` / `comment_references` | warning | C-DOC-1、C-DOC-3 |
| `avoid_catches_without_on_clauses` / `avoid_catching_errors` / `only_throw_errors` | error | C-ERR-2、C-ERR-3 |
| `unawaited_futures` | error | C-ERR-6 |
| `use_build_context_synchronously` | error | C-ERR-4、C-BAN-9 |
| `avoid_print` | error | C-ERR-5、C-BAN-6 |
| `avoid_dynamic_calls` / `avoid_annotating_with_dynamic` | warning | C-TYPE-1、C-BAN-7 |
| `avoid_relative_lib_imports` / `always_use_package_imports` | — | C-ARCH-1 |
| `directives_ordering` | warning | `naming.md` §1 导入顺序 |
| `unused_element` / `unused_local_variable` / `unused_import`（**analyzer 诊断，配在 `analyzer.errors` 而非 `linter.rules`**） | error | C-BAN-1 |
| `prefer_final_locals` / `prefer_final_fields` | warning | C-TYPE-4 |
| `prefer_const_constructors` / `prefer_const_declarations` / `prefer_const_constructors_in_immutables` | — | C-PERF-1、C-TYPE-4 |
| `avoid_slow_async_io` / `avoid_web_libraries_in_flutter` | — | C-PERF-5、C-SEC-2 |
| `use_key_in_widget_constructors` / `sort_child_properties_last` | — | `constraints.md` §6 |
| `riverpod_lint` 全部规则 | — | C-STATE-2、C-STATE-6 |

**当前无法 lint、只能人工 + 测试保障的约束**（必须写进 PR 自查）：

| 约束 | 保障方式 |
|---|---|
| C-UI-1 禁止硬编码颜色/尺寸 | Code review + Golden 测试 |
| C-UI-5 禁止硬编码用户可见字符串 | Code review；ARB 是唯一文案来源 |
| C-UI-9 法律声明页面存在 | Widget 测试断言页面可达 |
| C-PLT-1 禁止 UI 直接判断平台 | Code review（`grep 'Platform.is'` 排除 `core/platform/`） |
| C-ERR-1 必须返回 `ParseResult` | 单元测试 + Code review |
| C-ARCH-1 禁止反向依赖 | Code review；可后续用自定义 lint 补强 |
| C-DEP-7 依赖许可兼容 | `NOTICE.md` §5 核实流程 |

**刻意未启用的规则：**

| 规则 | 原因 |
|---|---|
| `avoid_non_null_assertion` | 不是 Dart 官方核心 lint（属 DCM / `fd_lints` 等第三方）；写入 `linter.rules` 会产生 "invalid rule" 警告。禁止 `!` 由 C-TYPE-2 + review 保障（ADR-0010） |
| `require_trailing_commas` | 与 Dart ≥3.7 的 tall-style 格式化冲突（ADR-0010） |
| `prefer_doc_comments` | **该规则在 Dart 3.13.3 中不存在**；`///` 偏好已由 `slash_for_doc_comments` 覆盖 |
| `avoid_returning_null` | 已被 Dart 移除；`avoid_returning_null_for_void` 仍有效并已启用 |
| `avoid_expanded_in_flex` | **该规则在 Dart 3.13.3 中不存在** |

> **维护要求：** 升级 Dart SDK 后必须用同一份官方清单重新比对（§13 第 7 步），
> 不得凭记忆添加规则名。

---

## 13. 新增依赖的流程

1. 确认 `pubspec.yaml` 中不存在等价依赖，且本文档 §10 未禁止。
2. 评估维护活跃度、体积、平台支持（Android / iOS / Windows 三端）。
3. **核对许可证与 GPL-3.0 的兼容性**（C-DEP-7）；把结论写入 `NOTICE.md` §5。
4. 更新 `pubspec.yaml`，并在同一 PR 内更新本文档的对应行。
5. 若该依赖改变了架构决定，必须先写 ADR 再改依赖（`docs/README.md` §6.5）。
6. 运行门禁：`flutter pub get` → `dart run build_runner build --delete-conflicting-outputs`
   → `AGENTS.md` §4 全部命令。
7. 核对 `analysis_options.yaml` 中的规则名：逐个对照
   `https://dart.dev/tools/linter-rules/all`（当前基准 Dart 3.13.3）。
   未使用代码类的 `unused_*` 属于 analyzer 诊断，必须放在 `analyzer.errors`。

---

**文档版本：** v2.1 · **最后更新：** 2026-10-10
