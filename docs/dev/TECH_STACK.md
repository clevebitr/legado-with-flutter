# 项目技术栈与 analysis_options.yaml

以下基于项目需求（MD3E 设计、多平台支持、Dart 重写书源解析），明确所有核心依赖的具体版本，并生成与之配套的 `analysis_options.yaml`。

---

## 一、技术栈清单

### 1.1 运行时与框架

| 依赖 | 版本 | 用途 |
|---|---|---|
| **Flutter SDK** | `3.47.0` | 最新稳定版，含 Dart 3.13.0 |
| **Dart SDK** | `^3.13.0` | 随 Flutter 3.47 附带 |

### 1.2 UI 与主题

| 依赖 | 版本 | 用途 |
|---|---|---|
| **m3e_design** | `^0.2.0` | Material 3 Expressive 设计语言（tokens、ThemeExtension、motion） |
| **dynamic_color** | `^2.1.0` | Android 壁纸种子色动态取色 |

### 1.3 状态管理

| 依赖 | 版本 | 用途 |
|---|---|---|
| **flutter_riverpod** | `^3.4.3` | 统一状态管理 |
| **riverpod_annotation** | `^3.0.0` | Riverpod 代码生成注解 |
| **riverpod_generator** | `^3.0.0` | Riverpod Provider 代码生成 |

### 1.4 书源解析引擎

| 依赖 | 版本 | 用途 |
|---|---|---|
| **html** | `^0.15.6` | HTML 解析 |
| **cascadia** | `^0.8.0` | CSS 选择器（Level 3/4） |
| **json_path** | `^0.9.0` | JSONPath 查询（RFC 9535） |
| **flutter_js_plus** | `^0.0.4` | JS 引擎（Android QuickJS / iOS JavaScriptCore） |
| **betto_charset_detector** | `^1.0.0` | 字符编码检测 |

### 1.5 网络与持久化

| 依赖 | 版本 | 用途 |
|---|---|---|
| **dio** | `^5.7.0` | HTTP 客户端（通过 core/network 封装） |
| **cached_network_image** | `^3.4.1` | 图片缓存 |
| **shared_preferences** | `^2.5.3` | 轻量键值存储 |
| **path_provider** | `^2.1.5` | 跨平台路径 |

### 1.6 代码生成

| 依赖 | 版本 | 用途 |
|---|---|---|
| **freezed** | `^3.2.5` | 不可变数据类与密封类生成 |
| **freezed_annotation** | `^3.1.0` | Freezed 注解 |
| **json_serializable** | `^6.12.0` | JSON 序列化生成 |
| **json_annotation** | `^4.9.0` | JSON 注解 |
| **build_runner** | `^2.15.0` | 代码生成运行器 |

### 1.7 开发与测试

| 依赖 | 版本 | 用途 |
|---|---|---|
| **flutter_lints** | `^6.0.0` | 基础 lint 规则集 |
| **mocktail** | `^1.0.4` | Mock 测试 |
| **golden_toolkit** | `^0.15.0` | Golden 测试 |

### 1.8 完整 pubspec.yaml

```yaml
name: flutter_reader
description: Flutter 阅读 App —— MD3E 设计、多平台支持、Dart 书源解析
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.13.0
  flutter: ^3.47.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # UI 与主题
  m3e_design: ^0.2.0
  dynamic_color: ^2.1.0

  # 状态管理
  flutter_riverpod: ^3.4.3
  riverpod_annotation: ^3.0.0

  # 书源解析
  html: ^0.15.6
  cascadia: ^0.8.0
  json_path: ^0.9.0
  flutter_js_plus: ^0.0.4
  betto_charset_detector: ^1.0.0

  # 网络与持久化
  dio: ^5.7.0
  cached_network_image: ^3.4.1
  shared_preferences: ^2.5.3
  path_provider: ^2.1.5

  # 代码生成注解
  freezed_annotation: ^3.1.0
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Lint
  flutter_lints: ^6.0.0

  # 代码生成
  build_runner: ^2.15.0
  freezed: ^3.2.5
  json_serializable: ^6.12.0
  riverpod_generator: ^3.0.0

  # 测试
  mocktail: ^1.0.4
  golden_toolkit: ^0.15.0

flutter:
  uses-material-design: true
  generate: true
```


## 二、analysis_options.yaml

```yaml
# =============================================================================
# analysis_options.yaml
# 项目：Flutter 阅读 App（MD3E、多平台、Dart 书源解析）
# 规范来源：docs/NAMING_CONVENTIONS.md + docs/ADDITIONAL_CONSTRAINTS.md
# 目标：flutter analyze 零警告，强制约束 AI 生成代码
# =============================================================================

include: package:flutter_lints/flutter.yaml

analyzer:
  # ---------------------------------------------------------------------------
  # 语言特性：启用严格模式，禁止隐式 dynamic 和未检查的 null
  # ---------------------------------------------------------------------------
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

  # ---------------------------------------------------------------------------
  # 错误级别：将部分 lint 提升为 error，确保 CI 阻断
  # ---------------------------------------------------------------------------
  errors:
    # 命名规范相关（error 级别，不可忽略）
    camel_case_types: error
    camel_case_extensions: error
    library_names: error
    file_names: error
    non_constant_identifier_names: error
    constant_identifier_names: error

    # 代码质量（error 级别）
    avoid_print: error
    unawaited_futures: error
    always_declare_return_types: error
    prefer_final_locals: warning
    directives_ordering: warning

    # 注释规范
    public_member_api_docs: warning
    slash_for_doc_comments: warning
    comment_references: warning

    # 禁止行为（error 级别）
    avoid_dynamic_calls: warning
    avoid_types_as_parameter_names: warning

  # ---------------------------------------------------------------------------
  # 排除目录：不分析生成文件和平台原生代码
  # ---------------------------------------------------------------------------
  exclude:
    - build/**
    - android/**
    - ios/**
    - windows/**
    - macos/**
    - linux/**
    - web/**
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.gr.dart"
    - "**/*.mocks.dart"
    - l10n/generated/**
    - .dart_tool/**

  # ---------------------------------------------------------------------------
  # 插件配置（可选，启用 Riverpod 和 Freezed 分析插件）
  # ---------------------------------------------------------------------------
  plugins:
    riverpod_lint: ^3.0.0
    custom_lint: ^0.7.0

# =============================================================================
# Linter 规则
# =============================================================================
linter:
  rules:
    # =========================================================================
    # 1. 命名规范（对应 docs/NAMING_CONVENTIONS.md）
    # =========================================================================

    # 类型命名
    camel_case_types: true
    camel_case_extensions: true
    library_names: true
    file_names: true
    non_constant_identifier_names: true
    constant_identifier_names: true

    # 方法/函数命名
    always_declare_return_types: true
    avoid_types_as_parameter_names: true

    # 变量命名
    prefer_final_locals: true
    prefer_final_fields: true

    # =========================================================================
    # 2. 代码风格（对应 docs/ADDITIONAL_CONSTRAINTS.md §6）
    # =========================================================================

    # 字符串与格式
    prefer_single_quotes: true
    require_trailing_commas: true

    # 导入顺序（Dart SDK → Flutter SDK → 第三方 → 项目内部）
    directives_ordering: true
    depend_on_referenced_packages: true

    # 常量优化
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_const_literals_to_create_immutables: true
    prefer_const_constructors_in_immutables: true

    # 不可变性
    prefer_final_in_for_each: true
    avoid_final_parameters: false

    # =========================================================================
    # 3. 错误处理与异步（对应 docs/ADDITIONAL_CONSTRAINTS.md §3）
    # =========================================================================

    avoid_print: true
    unawaited_futures: true
    avoid_catches_without_on_clauses: true
    avoid_catching_errors: true
    only_throw_errors: true

    # =========================================================================
    # 4. 类型安全（对应 docs/ADDITIONAL_CONSTRAINTS.md §11）
    # =========================================================================

    avoid_dynamic_calls: true
    avoid_returning_null_for_void: true
    avoid_returning_null: true
    avoid_returning_this: false
    avoid_void_async: true

    # =========================================================================
    # 5. 注释与文档（对应 docs/NAMING_CONVENTIONS.md §7）
    # =========================================================================

    public_member_api_docs: true
    slash_for_doc_comments: true
    comment_references: true
    prefer_doc_comments: true

    # =========================================================================
    # 6. 架构与分层（对应 docs/ADDITIONAL_CONSTRAINTS.md §1）
    # =========================================================================

    avoid_relative_lib_imports: true
    always_use_package_imports: true

    # =========================================================================
    # 7. Flutter 特定规则（对应 docs/ADDITIONAL_CONSTRAINTS.md §6）
    # =========================================================================

    # Widget 与 BuildContext
    use_build_context_synchronously: true
    avoid_unnecessary_containers: true
    prefer_const_constructors_in_immutables: true

    # Widget 命名与结构
    sort_child_properties_last: true
    use_key_in_widget_constructors: true
    avoid_expanded_in_flex: true

    # 国际化（对应 docs/ADDITIONAL_CONSTRAINTS.md §6）
    # 所有用户可见字符串必须来自 l10n/ ARB 文件
    # 该规则由自定义 lint 或 CI 脚本保障

    # =========================================================================
    # 8. 安全与性能（对应 docs/ADDITIONAL_CONSTRAINTS.md §10）
    # =========================================================================

    avoid_slow_async_io: true
    avoid_web_libraries_in_flutter: true

    # =========================================================================
    # 9. 代码质量
    # =========================================================================

    # 避免未使用代码
    unused_element: true
    unused_local_variable: true
    unused_import: true

    # 避免冗余
    unnecessary_lambdas: true
    unnecessary_parenthesis: true
    unnecessary_brace_in_string_interps: true
    unnecessary_this: true
    unnecessary_string_escapes: true

    # 集合与迭代
    prefer_collection_literals: true
    prefer_spread_collections: true
    prefer_for_elements_to_map_fromIterable: true
    prefer_if_elements_to_conditional_expressions: true

    # 类型与泛型
    prefer_generic_function_type_aliases: true
    avoid_annotating_with_dynamic: true

    # =========================================================================
    # 10. 测试（对应 docs/ADDITIONAL_CONSTRAINTS.md §8）
    # =========================================================================

    # 测试文件命名：*_test.dart
    # 测试方法命名：方法名_场景_预期结果
    # 由人工 Review 和 CI 脚本保障

    # =========================================================================
    # 11. 禁止行为（对应 AGENT.md §7）
    # =========================================================================

    # 禁止使用 print -> 使用 logger
    avoid_print: true

    # 禁止使用 dynamic -> 使用具体类型
    avoid_dynamic_calls: true

    # 禁止强制解包 ! -> 使用 ?? 或模式匹配
    avoid_non_null_assertion: true

    # 禁止跨 await 使用 context 不检查 mounted
    use_build_context_synchronously: true

    # 禁止生成未使用的代码
    unused_element: true
    unused_local_variable: true
    unused_import: true

    # 禁止修改生成文件
    # 通过 analyzer.exclude 排除 *.g.dart 和 *.freezed.dart

# =============================================================================
# 自定义规则说明（需要配合 custom_lint 使用）
# =============================================================================
custom_lint:
  rules:
    # Riverpod 规则
    - avoid_manual_providers_as_generated_provider_dependency
    - avoid_public_notifier_properties
    - provider_dependencies
    - missing_provider_scope

    # 项目自定义规则（需实现 custom_lint 插件）
    # - avoid_hardcoded_colors      # 禁止硬编码颜色，必须使用 M3ETheme
    # - avoid_hardcoded_strings     # 禁止硬编码字符串，必须使用 l10n
    # - avoid_platform_checks_in_ui # 禁止在 UI 中直接判断 Platform
    # - prefer_parse_result         # 书源解析必须返回 ParseResult
    # - no_raw_catch                # 禁止裸 catch
```


## 三、关键规则与文档的对应关系

| `analysis_options.yaml` 规则 | 对应文档章节 | 说明 |
|---|---|---|
| `camel_case_types` 等命名规则 | `NAMING_CONVENTIONS.md` §2-5 | 强制命名规范 |
| `public_member_api_docs` | `NAMING_CONVENTIONS.md` §7 | 公共 API 必须有英文文档注释 |
| `avoid_print` | `ADDITIONAL_CONSTRAINTS.md` §11 | 禁止 `print`，必须用日志库 |
| `avoid_dynamic_calls` | `ADDITIONAL_CONSTRAINTS.md` §11 | 禁止 `dynamic`（JS 交互除外） |
| `avoid_non_null_assertion` | `ADDITIONAL_CONSTRAINTS.md` §11 | 禁止 `!` 强制解包 |
| `use_build_context_synchronously` | `ADDITIONAL_CONSTRAINTS.md` §3 | 跨 `await` 必须检查 `mounted` |
| `unawaited_futures` | `ADDITIONAL_CONSTRAINTS.md` §3 | 所有 `Future` 必须显式处理 |
| `avoid_catches_without_on_clauses` | `ADDITIONAL_CONSTRAINTS.md` §3 | 禁止裸 `catch` |
| `always_use_package_imports` | `ADDITIONAL_CONSTRAINTS.md` §1 | 禁止相对导入 |
| `directives_ordering` | `NAMING_CONVENTIONS.md` §2.5 | 导入顺序规范 |
| `prefer_const_constructors` | `ADDITIONAL_CONSTRAINTS.md` §6 | 常量优化 |
| `exclude: *.g.dart, *.freezed.dart` | `ADDITIONAL_CONSTRAINTS.md` §9 | 禁止分析/修改生成文件 |

---

**文档版本：** v1.0  
**适用项目：** Flutter 阅读 App（MD3E、多平台、Dart 书源解析）  
**最后更新：** 2026-10-10