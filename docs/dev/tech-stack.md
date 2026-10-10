# 技术栈与工具链

> 依赖的**唯一来源**是根目录 `pubspec.yaml`；本文档只说明「为什么选它、对应哪条约束、
> 平台支持与许可证」（C-DEP-6）。本文档不复制 `pubspec.yaml` 与
> `analysis_options.yaml` 的正文。
>
> 版本已对标 pub.dev 现状核实（2026-10-10），下表版本与 `pubspec.yaml` 一致。

---

## 1. 版本策略

| 项 | 结论 |
|---|---|
| Flutter | `3.47.0`（`environment: flutter: ^3.47.0`） |
| Dart SDK | `^3.13.0`（随 Flutter 3.47 附带） |
| 依赖版本写法 | `^` 或精确版本，**禁止 `any`**（C-DEP-2） |
| 锁文件 | 提交 `pubspec.lock`；升级依赖必须单独 PR |
| 许可证 | 必须 GPL-3.0 兼容（C-DEP-7）；清单见 `NOTICE.md` §5 |
| lint 规则名基准 | 以 Dart **3.13.3** 的官方清单为准（`https://dart.dev/tools/linter-rules/all`）。`analysis_options.yaml` 中全部规则名已与该清单逐一机器比对通过 |

**版本号必须同步的四处**（改任一处必须同时改其余三处）：

| 位置 | 形式 |
|---|---|
| 本节（权威定义） | `3.47.0` / `^3.13.0` |
| `pubspec.yaml` 的 `environment:` | `sdk: ^3.13.0`、`flutter: ^3.47.0` |
| `.github/workflows/ci.yml` 的 `flutter-version` | `'3.47.0'` |
| `docs/dev/platform.md` §1 的平台基线 | 与上述版本对应 |

### 已知可升级但**故意未升**的依赖

| 依赖 | 当前 | 最新 | 原因 |
|---|---|---|---|
| `freezed` / `freezed_annotation` | `3.x` | `4.0.2` | 跨大版本迁移需要独立 PR + ADR；`^3.2.5` 不会自动跳到 4.x |

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
| `dynamic_color` | `^2.1.0` | Android 壁纸种子色取色（`DynamicColorBuilder`） | Apache-2.0 | C-UI-3、C-PLT-2 |

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
| 读取 | `Theme.of(context).m3e`（`ThemeData` 扩展；debug 下 assert，release 下回退默认值） |
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
| `riverpod_annotation` | `^3.0.0` | `@riverpod` 注解 | MIT | C-STATE-2 |
| `riverpod_generator`（dev） | `^3.0.0` | Provider 代码生成 | MIT | C-STATE-2 |
| `riverpod_lint`（dev） | `^3.1.9` | 禁止手写 Provider 等规则 | MIT | C-STATE-2 |

> Riverpod 3 的统一引用类型是 `Ref`（不再有 `XxxRef`）。

## 5. 书源解析引擎

| 依赖 | 版本 | 用途 | 平台支持 | 许可证 | 关联约束 |
|---|---|---|---|---|---|
| `html` | `^0.15.6` | HTML DOM | 全平台 | BSD-3-Clause | C-SRC-1 |
| `cascadia` | `^0.8.0` | CSS 选择器（唯一） | 全平台 | BSD-3-Clause | C-SRC-6 |
| `json_path` | `^0.9.0` | JSONPath（唯一） | 全平台 | MIT | C-SRC-6 |
| `flutter_js_plus` | `^0.0.4` | JS 引擎（FFI：Android/Linux/Windows 走 QuickJS，iOS/macOS 走 JavaScriptCore） | Android/iOS/Windows | MIT | C-SRC-2、C-SRC-3 |
| `betto_charset_detector` | `^0.1.0` | 字符编码检测（唯一，纯 Dart） | 全平台 | Apache-2.0 | C-NET-3 |

> **`betto_charset_detector` 的当前版本是 `0.1.0`**（尚未发布 1.x）。
> 早期文档写作 `^1.0.0` 会导致解析失败。
>
> `flutter_js_plus` 通过 dart-ffi 运行，因此可在独立 Isolate 中执行（C-SRC-2）。
> **约束：** 不得在后台 Isolate 中使用依赖 platform channel 的回调桥
> （如 `JavascriptRuntime.onMessage`）；需要双向通信时必须使用
> `BackgroundIsolateBinaryMessenger`，并补 `book-source.md` 的测试用例。

## 6. 网络与持久化

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `dio` | `^5.7.0` | HTTP 客户端（仅允许在 `core/network/` 内使用） | MIT | C-NET-1 |
| `cached_network_image` | `^3.4.1` | 图片缓存 | MIT | C-PERF-3 |
| `drift` | `^2.35.2` | 结构化数据主库（SQLite） | MIT | C-NET-7、C-NET-9 |
| `drift_flutter` | `^0.3.1` | 各平台原生 SQLite 与数据库路径 | MIT | C-NET-9 |
| `shared_preferences` | `^2.5.3` | 仅轻量开关（主题模式、字号） | BSD-3-Clause | C-NET-9 |
| `path_provider` | `^2.1.6` | 跨平台路径（唯一来源） | BSD-3-Clause | C-PLT-3 |

> **禁止使用 `sqlite3_flutter_libs`**：上游已标记 EOL（`0.6.0+eol`），
> 在新版 Android 工具链上不再正确打包原生库，会在启动时抛
> `DriftRemoteException: dlopen failed: libsqlite3.so not found`。
> 官方替代方案是 `drift_flutter`（见 ADR-0003）。

## 7. 观测

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `logger` | `^2.8.0` | 日志实现；业务侧只允许通过 `core/logging` 使用 | MIT | C-ERR-5、C-SEC-4 |

## 8. 代码生成

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `freezed_annotation` / `freezed` | `^3.1.0` / `^3.2.5` | 不可变数据类与密封类 | MIT | C-DEP-3 |
| `json_annotation` / `json_serializable` | `^4.9.0` / `^6.14.1` | JSON 序列化 | MIT | C-DEP-3 |
| `build_runner` | `^2.16.2` | 生成器运行器 | MIT | C-DEP-4 |
| `drift_dev` | `^2.35.2` | Drift 表与 DAO 生成 | MIT | C-DEP-3 |

## 9. 开发与测试

| 依赖 | 版本 | 用途 | 许可证 | 关联约束 |
|---|---|---|---|---|
| `flutter_lints` | `^6.0.0` | 基础 lint 规则集 | BSD-3-Clause | — |
| `mocktail` | `^1.0.5` | Mock 测试 | MIT | C-TEST-1 |

## 10. 已移除与明确禁止的依赖

| 依赖 | 状态 | 原因 |
|---|---|---|
| `sqlite3_flutter_libs` | **移除（EOL）** | 上游 `0.6.0+eol`，改用 `drift_flutter`（ADR-0003） |
| `custom_lint` | **移除** | `riverpod_lint` 自 3.1.9 起改用 `analysis_server_plugin`，不再需要它（ADR-0010） |
| `golden_toolkit` | **移除** | 已停止维护；改用 Flutter 内置 `matchesGoldenFile`（ADR-0009） |
| `material_you_dynamic_theme` | **禁止引入** | 与 `dynamic_color` + `m3e_design` 职责重叠，会出现两个取色真源（ADR-0004） |
| `get_it` | **禁止引入** | 与 Riverpod 职责重叠（ADR-0005） |
| `flutter_qjs` | **禁止引入** | 与 `flutter_js_plus` 重复；引擎只允许一个（ADR-0008） |
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

**执行方式：** `riverpod_lint ≥3.1.9` 通过 `analysis_options.yaml` 的
`analyzer.plugins` 安装，由 `flutter analyze` 执行（ADR-0010）。
项目**不再使用 `custom_lint`**。

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
