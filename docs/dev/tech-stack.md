# 技术栈与工具链

> 依赖的**唯一来源**是根目录 `pubspec.yaml`；本文档只提供「为什么选它、关联哪条约束、
> 平台支持情况」的说明（C-DEP-6）。本文档不复制 `pubspec.yaml` 与
> `analysis_options.yaml` 的正文。

---

## 1. 版本策略

| 项 | 结论 | 依据 |
|---|---|---|
| Flutter | `3.47.0`（`environment: flutter: ^3.47.0`） | 本文档为版本基线的唯一来源 |
| Dart SDK | `^3.13.0` | 随 Flutter 3.47 附带 |
| 依赖版本写法 | `^` 或精确版本，**禁止 `any`** | C-DEP-2 |
| 锁文件 | 提交 `pubspec.lock`；升级依赖必须单独 PR | 可复现构建 |

**版本号必须同步的三处**（改任一处必须同时改另外两处）：

| 位置 | 形式 |
|---|---|
| 本节（权威定义） | `3.47.0` / `^3.13.0` |
| `pubspec.yaml` 的 `environment:` | `sdk: ^3.13.0`、`flutter: ^3.47.0` |
| `.github/workflows/ci.yml` 的 `flutter-version` | `'3.47.0'` |

> **验证状态：** 本文档编写环境**没有 Flutter/Dart SDK**，因此
> `pubspec.yaml` 中的版本约束**未经 `flutter pub get` 解析验证**。
> 首次在装有 Flutter 的机器上执行 `flutter pub get` 后，必须把实际解析结果与
> 本表比对并回写；解析失败时以 `pubspec.yaml` 为准修正（见 ADR-0010）。

---

## 2. 运行时依赖

| 依赖 | 版本 | 用途 | 关联约束 |
|---|---|---|---|
| `flutter` | SDK | 框架 | — |
| `flutter_localizations` | SDK | 本地化运行时 | C-UI-5 |

## 3. UI 与主题

| 依赖 | 版本 | 用途 | 关联约束 |
|---|---|---|---|
| `m3e_design` | `^0.2.0` | Material 3 Expressive 设计令牌：`M3ETheme` ThemeExtension（colors / typography / shapes / spacing / motion） | C-UI-1、C-UI-2 |
| `dynamic_color` | `^2.1.0` | Android 壁纸种子色取色（`DynamicColorBuilder`） | C-UI-3、C-PLT-2 |

**已核实的 `m3e_design` 0.2.1 API**（ADR-0004）：

```dart
// 安装：两种等价方式
final theme = ColorScheme.fromSeed(seedColor: seed).toM3EThemeData();
final theme2 = withM3ETheme(ThemeData(colorScheme: scheme));

// 读取：ThemeData 扩展，非空（debug 下 assert，release 下回退默认值）
final M3ETheme tokens = Theme.of(context).m3e;
tokens.colors;      // M3EColors：surface / onSurface / container 层级 / primary / secondary / tertiary / outline / inverse
tokens.typography;  // M3ETypography：headline / title / label / body，含 emphasized 变体
tokens.shapes;      // M3EShapes：round / square 家族与按尺寸分类的圆角
tokens.spacing;     // M3ESpacing：xs → xl 间距阶梯
tokens.motion;      // M3EMotion：时长与缓动
```

- **禁止** `Theme.of(context).extension<M3ETheme>()!`（无用且违反 C-TYPE-2）。
- `M3ESpacing` / `M3ETypography` 具体成员名以 IDE 补全为准；
  首次接入时把实际成员名回写到 `docs/dev/constraints.md` §6 示例。
- 动态取色链路：`DynamicColorBuilder` → `ColorScheme` → `toM3EThemeData()`；
  Windows / iOS 走种子色 fallback（C-PLT-3、C-PLT-4）。

## 4. 状态管理

| 依赖 | 版本 | 用途 | 关联约束 |
|---|---|---|---|
| `flutter_riverpod` | `^3.4.3` | 唯一状态管理方案 | C-STATE-1 |
| `riverpod_annotation` | `^3.0.0` | `@riverpod` 注解 | C-STATE-2 |
| `riverpod_generator`（dev） | `^3.0.0` | Provider 代码生成 | C-STATE-2 |
| `riverpod_lint`（dev） | `^3.0.0` | 禁止手写 Provider 等规则 | C-STATE-2 |

## 5. 书源解析引擎

| 依赖 | 版本 | 用途 | 平台支持 | 关联约束 |
|---|---|---|---|---|
| `html` | `^0.15.6` | HTML DOM | 全平台 | C-SRC-1 |
| `cascadia` | `^0.8.0` | CSS 选择器（唯一） | 全平台 | C-SRC-6 |
| `json_path` | `^0.9.0` | JSONPath（唯一） | 全平台 | C-SRC-6 |
| `flutter_js_plus` | `^0.0.4` | JS 引擎（FFI：Android/Linux/Windows 走 QuickJS，iOS/macOS 走 JavaScriptCore） | Android/iOS/Windows | C-SRC-2、C-SRC-3 |
| `betto_charset_detector` | `^1.0.0` | 字符编码检测（唯一） | 全平台 | C-NET-3 |

> `flutter_js_plus` 通过 dart-ffi 运行，因此可在独立 Isolate 中执行（C-SRC-2）。
> **约束：** 不得在后台 Isolate 中使用依赖 platform channel 的回调桥（如
> `JavascriptRuntime.onMessage`）；需要双向通信时必须使用
> `BackgroundIsolateBinaryMessenger`，并为其补一条 `book-source.md` 的测试用例。

## 6. 网络与持久化

| 依赖 | 版本 | 用途 | 关联约束 |
|---|---|---|---|
| `dio` | `^5.7.0` | HTTP 客户端（仅允许在 `core/network/` 内使用） | C-NET-1 |
| `cached_network_image` | `^3.4.1` | 图片缓存 | C-PERF-3 |
| `drift` | `^2.20.0` | 结构化数据主库（SQLite） | C-NET-7、C-NET-9 |
| `sqlite3_flutter_libs` | `^0.5.0` | 各平台 SQLite 原生库（Windows/Android 必需） | C-NET-9 |
| `shared_preferences` | `^2.5.3` | 仅轻量开关（主题模式、字号） | C-NET-9 |
| `path_provider` | `^2.1.5` | 跨平台路径（唯一来源） | C-PLT-3 |

## 7. 观测

| 依赖 | 版本 | 用途 | 关联约束 |
|---|---|---|---|
| `logger` | `^2.0.0` | 日志实现；业务侧只允许通过 `core/logging` 使用 | C-ERR-5、C-SEC-4 |

## 8. 代码生成

| 依赖 | 版本 | 用途 | 关联约束 |
|---|---|---|---|
| `freezed_annotation` / `freezed` | `^3.1.0` / `^3.2.5` | 不可变数据类与密封类 | C-DEP-3 |
| `json_annotation` / `json_serializable` | `^4.9.0` / `^6.12.0` | JSON 序列化 | C-DEP-3 |
| `build_runner` | `^2.15.0` | 生成器运行器 | C-DEP-4 |
| `drift_dev` | `^2.20.0` | Drift 表与 DAO 生成 | C-DEP-3 |

## 9. 开发与测试

| 依赖 | 版本 | 用途 | 关联约束 |
|---|---|---|---|
| `flutter_lints` | `^6.0.0` | 基础 lint 规则集 | — |
| `custom_lint` | `^0.7.0` | 自定义 lint 运行器 | C-BAN-15 |
| `mocktail` | `^1.0.4` | Mock 测试 | C-TEST-1 |

## 10. 已移除与明确禁止的依赖

| 依赖 | 状态 | 原因 |
|---|---|---|
| `golden_toolkit` | **已移除** | 已停止维护；改用 Flutter 内置 `matchesGoldenFile`（ADR-0009） |
| `material_you_dynamic_theme` | **禁止引入** | 与 `dynamic_color` + `m3e_design` 职责重叠，会出现两个取色真源（ADR-0004） |
| `get_it` | **禁止引入** | 与 Riverpod 职责重叠（ADR-0005） |
| `flutter_qjs` | **禁止引入** | 与 `flutter_js_plus` 重复；引擎只允许一个（ADR-0008） |
| `Isar` / `Hive` | **未采用** | 持久化方案已定为 Drift（ADR-0003） |
| `bloc` / `flutter_bloc` / `get` / `provider` | **禁止引入** | 状态管理唯一方案为 Riverpod（C-STATE-1） |

---

## 11. 国际化配置

| 文件 | 作用 |
|---|---|
| `l10n.yaml` | 生成配置：`arb-dir: lib/l10n`，模板 `app_en.arb`，输出 `lib/l10n/generated/app_localizations.dart`，`nullable-getter: false` |
| `lib/l10n/app_en.arb` | 英文模板，新增字符串的**唯一入口**，必须带 `@key.description` |
| `lib/l10n/app_zh.arb` | 中文翻译 |

流程：

1. 先在 `app_en.arb` 添加键与描述，再在 `app_zh.arb` 补中文；两者必须在同一个 PR 内完成（C-UI-5）。
2. 生成：`flutter gen-l10n`（构建时也会自动执行，`pubspec.yaml` 已设 `generate: true`）。
3. key 命名规则见 `docs/dev/naming.md` §8。
4. 生成物位于 `lib/l10n/generated/`，已在 `analysis_options.yaml` 中排除，**禁止手改**（C-DEP-5）。

> `intl` 由 `flutter_localizations` 传递提供。仅当 ARB 使用 `type: date` / `type: number`
> 占位符时才需要显式声明 `intl`，此时必须与 `flutter_localizations` 的约束保持一致。

---

## 12. lint 规则与约束 ID 的映射

| lint 规则 | 强制级别 | 约束 ID |
|---|---|---|
| `camel_case_types` / `camel_case_extensions` / `file_names` / `library_names` | error | `naming.md` §2/§3 |
| `non_constant_identifier_names` / `constant_identifier_names` | error | `naming.md` §5 |
| `always_declare_return_types` | error | `naming.md` §4 |
| `public_member_api_docs` / `slash_for_doc_comments` / `comment_references` / `prefer_doc_comments` | warning | C-DOC-1、C-DOC-3 |
| `avoid_catches_without_on_clauses` / `avoid_catching_errors` / `only_throw_errors` | error | C-ERR-2、C-ERR-3 |
| `unawaited_futures` | error | C-ERR-6 |
| `use_build_context_synchronously` | error | C-ERR-4、C-BAN-9 |
| `avoid_print` | error | C-ERR-5、C-BAN-6 |
| `avoid_dynamic_calls` / `avoid_annotating_with_dynamic` | warning | C-TYPE-1、C-BAN-7 |
| `avoid_relative_lib_imports` / `always_use_package_imports` | — | C-ARCH-1 |
| `directives_ordering` | warning | `naming.md` §1 导入顺序 |
| `unused_element` / `unused_local_variable` / `unused_import` | — | C-BAN-1 |
| `prefer_final_locals` / `prefer_final_fields` | warning | C-TYPE-4 |
| `prefer_const_constructors` / `prefer_const_declarations` / `prefer_const_constructors_in_immutables` | — | C-PERF-1、C-TYPE-4 |
| `avoid_slow_async_io` / `avoid_web_libraries_in_flutter` | — | C-PERF-5、C-SEC-2 |
| `avoid_expanded_in_flex` / `use_key_in_widget_constructors` / `sort_child_properties_last` | — | `constraints.md` §6 |
| `riverpod_lint` 全部规则 | — | C-STATE-2、C-STATE-6 |

**当前无法 lint、只能人工 + 测试保障的约束**（必须写进 PR 自查）：

| 约束 | 保障方式 |
|---|---|
| C-UI-1 禁止硬编码颜色/尺寸 | Code review + Golden 测试 |
| C-UI-5 禁止硬编码用户可见字符串 | Code review；ARB 是唯一文案来源 |
| C-PLT-1 禁止 UI 直接判断平台 | Code review（`grep 'Platform.is'` 排除 `core/platform/`） |
| C-ERR-1 必须返回 `ParseResult` | 单元测试 + Code review |
| C-ARCH-1 禁止反向依赖 | Code review；可后续用自定义 lint 补强 |

**刻意未启用的规则：**

| 规则 | 原因 |
|---|---|
| `avoid_non_null_assertion` | 不是 Dart 官方核心 lint（属 DCM / `fd_lints` 等第三方）；写入 `linter.rules` 会产生 "invalid rule" 警告。禁止 `!` 由 C-TYPE-2 + review 保障（ADR-0010） |
| `require_trailing_commas` | 与 Dart ≥3.7 的 tall-style 格式化冲突，`dart format` 会与之互相拉扯（ADR-0010） |

---

## 13. 新增依赖的流程

1. 确认 `pubspec.yaml` 中不存在等价依赖，且 `docs/dev/tech-stack.md` §10 未禁止。
2. 评估维护活跃度、体积、平台支持（Android/iOS/Windows 三端）。
3. 更新 `pubspec.yaml`，并在同一 PR 内更新本文档 §2–§9 的对应行。
4. 若该依赖改变了架构决定，必须先写 ADR 再改依赖（`docs/README.md` §6.5）。
5. 运行门禁：`flutter pub get` → `dart run build_runner build --delete-conflicting-outputs`
   → `AGENTS.md` §4 全部命令。

---

**文档版本：** v2.0 · **最后更新：** 2026-10-10
