# 架构与目录结构

> 分层约束见 `docs/dev/constraints.md` C-ARCH-1..7。
> 本文档定义**目录归属**与**跨层契约**，是判断「新文件放哪里」的唯一依据。

---

## 1. 目录结构

采用 **feature-first + 层内分层**：feature 内部再分 `data/domain/presentation`。

```
lib/
├── main.dart                     # 仅 bootstrap：runApp + ProviderScope
├── app.dart                      # MaterialApp 装配：主题、路由、l10n
├── core/                         # 无业务语义的共享能力，可被任意层依赖
│   ├── di/                       # 基础设施 Provider（数据库、HttpClient、Logger）
│   ├── error/                    # ParseResult / ParseFailureKind / ARB 键名助手
│   ├── js/                       # `@js:` 沙箱：JsBridge 契约 + 常驻 worker isolate + 已落的同步绑定（log / crypto）
│   ├── logging/                  # Logger 门面（唯一日志入口）
│   ├── network/                  # HttpClient、CookieManager、超时/重试策略与同一书源的并发预算
│   ├── platform/                 # 平台抽象接口 + 各平台实现 + fallback
│   ├── router/                   # 路由机制（RouteSettings → 页面）与唯一 push 入口；页面表见 §6
│   ├── storage/                  # Drift 数据库、DAO、键值存储封装
│   ├── theme/                    # M3ETheme 安装、动态取色接线
│   └── utils/                    # 纯函数工具（禁止 IO，禁止依赖 Flutter）
├── features/
│   └── <feature>/                # book_source / reader / bookshelf / settings ...
│       ├── data/                 # DTO(freezed) + DataSource + RepositoryImpl
│       ├── domain/               # Entity + Repository 接口 + UseCase
│       ├── presentation/         # pages / widgets / notifiers（Notifier 与该 feature 的派生 provider 同放 notifiers/）
│       └── di.dart               # 该 feature 的仓储与用例 Provider
└── l10n/                         # ARB 与生成物
```

**新增文件时的判断顺序**（对应 C-ARCH-6）：

1. 它是否含业务语义？否 → `core/`。是 → 继续。
2. 它属于哪个 feature？找不到 → 先与用户确认 feature 边界，禁止新造 feature。
3. 它是数据获取/持久化细节 → `data/`；是业务规则/实体/接口 → `domain/`；
   是展示与事件 → `presentation/`。

---

## 2. 依赖方向

```
features/<f>/presentation ──► features/<f>/domain ──► features/<f>/data
             │                        │                     │
             └────────────────────────┴─────────────────────┘
                                      ▼
                                    core/
```

- 箭头方向即允许的 import 方向（C-ARCH-1）。
- `core/` 不得 import 任何 `features/`。
- `features/A` 不得 import `features/B` 的内部文件（C-ARCH-2）；
  确有共享需求时，把共享部分上移到 `core/`，或把场景合入同一个 feature。

---

## 3. 各层职责

| 层 | 允许包含 | 禁止包含 |
|---|---|---|
| `domain/` | Entity、Value Object、Repository 接口、UseCase、领域异常、**无状态领域服务与解析构件**（判据见下方例外二） | Flutter import、`dio`、Drift、平台 API、JSON 序列化注解 |
| `data/` | DTO（freezed + json_serializable）、DataSource、`RepositoryImpl`、Mapper | Flutter Widget、`BuildContext` |
| `presentation/` | Page、Widget、`@riverpod` Notifier、ViewModel 级格式化逻辑 | 直接 import `data/`、直接调用 `dio`、写在 `build` 里的业务判断 |

DTO ↔ Entity 转换必须放在 `data/` 的 Mapper 中，禁止在 `presentation/` 做转换。

> **例外一（ADR-0021）：** 书源模型（`BookSource` 及其子规则）允许在 `domain/` 中携带
> `freezed` + `json_serializable` 注解：Legado JSON 的键名就是本项目的领域规则语言，
> `RuleEngine` 与 UseCase 直接消费它（C-SRC-7）。其它 `domain/` 类型仍禁止 JSON 序列化注解。
>
> **例外二（ADR-0025）：** `domain/` 允许**无状态领域服务与解析构件**，即
> `XxxService`（例如 `PageFetchService`：编排 `core/` 抽象与规则引擎）、`XxxEngine`
> （例如 `RuleEngine`，C-SRC-1 要求的纯 Dart 解析引擎）与纯函数模块（例如
> `url_template.dart`）。判据**逐条**为：无跨调用的可变状态（C-SRC-9）；只依赖 `core/`
> 抽象与纯 Dart 依赖；不 import Flutter / 平台 API / `data/`；不承担仓储职责（C-NET-8）。
> `lib/features/book_source/` 目前没有 `data/` 层，是该例外的直接结果，复审触发条件见
> ADR-0025 §后果。

---

## 4. 依赖注入

- 统一使用 Riverpod，Provider 全部由 `@riverpod` 生成（C-STATE-2）。
- Riverpod 3 的统一引用类型为 `Ref`（不再有 `XxxRef`）。

| 位置 | 内容 | 示例 |
|---|---|---|
| `core/di/` | 基础设施：数据库、`HttpClient`、`Logger`、时钟 | `@riverpod HttpClient httpClient(Ref ref)` |
| `features/<f>/di.dart` | 该 feature 的 DataSource / Repository / UseCase | `@riverpod BookSourceRepository bookSourceRepository(Ref ref)` |

**文件粒度：** `core/di/` 下每个主题一个文件，命名见 `docs/dev/naming.md` §2/§6（本文档不复述）；
`features/<f>/` 下继续沿用单文件 `di.dart`。两者不得混用。

```dart
// features/book_source/di.dart
@riverpod
BookSourceRepository bookSourceRepository(Ref ref) =>
    BookSourceRepositoryImpl(ref.watch(bookSourceLocalDataSourceProvider));
```

- 禁止 `ProviderScope` 之外的全局单例；禁止 `get_it`（C-ARCH-3，ADR-0005）。
- 测试通过 `ProviderScope(overrides: [...])` 注入替身，禁止在实现里为测试开分支。

---

## 5. 跨层契约：`ParseResult`

定义位置：`lib/core/error/parse_result.dart`（类型与契约）；ARB 键名助手
`lib/core/error/parse_failure_arb_key.dart`（唯一实现 `resolveFailureArbKey`）。

```dart
/// Kinds of recoverable failures produced by parsing, network and storage layers.
enum ParseFailureKind {
  networkTimeout,
  networkFailed,
  networkForbidden,
  notFound,
  encodingFailed,
  parseFailed,
  unsupportedRule,
  invalidBookSource,
  cancelled,
}

/// Result of an operation that can fail without throwing.
// 结果类型构造后不再修改，故关闭 copyWith 生成（ADR-0002 未定义该需求）。
@Freezed(copyWith: false)
sealed class ParseResult<T> with _$ParseResult<T> {
  /// Creates a successful result carrying [data].
  const factory ParseResult.success(T data) = ParseSuccess<T>;

  /// Creates a failure result.
  ///
  /// [rulePath] locates the failing rule so the UI and logs can point at it.
  const factory ParseResult.failure({
    required ParseFailureKind kind,
    required String rulePath,
    Object? cause,
    StackTrace? stackTrace,
  }) = ParseFailure<T>;
}
```

约定：

| 规则 | 说明 |
|---|---|
| 不与异常混用 | 可预期失败返回 `ParseResult`；编程错误（`ArgumentError`、断言）直接抛出（C-ERR-1） |
| 文案在 UI 层 | `ParseFailureKind` → ARB key `failure<PascalCaseKind>`，例如 `failureNetworkTimeout`（C-ERR-7）。键名规则的**规格**出处是 `docs/dev/naming.md` §8，**代码**唯一实现是 `resolveFailureArbKey`；UI 只保留「键 → 文案」的 `switch` |
| 路径必填 | `rulePath` 使用「书源字段 + 规则片段」描述，如 `searchRule.list`、`contentRule.content`（C-SRC-8） |
| 穷尽匹配 | 消费方必须 `switch` 穷尽两个分支，禁止 `is` 判断后回退到 `null` |

`ParseResult` 的扩展方法（`whenSuccess`、`dataOrNull`）放在同文件，保持 `core/error/` 自洽。

---

## 6. 路由

- 使用 Flutter 内置 `Navigator` + `onGenerateRoute`；路由职责**三分**（2026-10-11 澄清，原因见 C-ARCH-2）：

  | 部分 | 位置 |
  |---|---|
  | 机制：`RouteSettings` → 页面、唯一的 push 入口 | `core/router/`（`AppRouter`） |
  | 页面表：哪条类型化路由构建哪个页面 | 装配根 `lib/app.dart` |
  | 类型化参数与其路径 | 各 feature 的 `presentation/`（例如 `book_source_route.dart`） |

  页面表之所以不在 `core/router/`：`core/` **不得 import `features/`**（§2），而类型化路由
  参数携带的正是 feature 实体（`Book` / `Chapter`）；`app.dart` 的职责已包含「路由装配」。
- 路由参数必须为**类型化对象**（`freezed`），禁止传递裸 `Map<String, Object?>`。
- 页面间传参不得传递 Entity 之外的未序列化状态；需要跨页共享的数据放入 Notifier。
- 预测性返回接线见 `docs/dev/platform.md`（C-UI-4、C-PLT-2）。

> 不引入 `go_router` 是为避免未经评审的依赖（C-DEP-1）；若后续需要深链接与
> 嵌套路由，必须先写 ADR 再改依赖。

---

## 7. 新 feature 的落地清单

- [ ] 在 `features/` 下建立 `data/`、`domain/`、`presentation/`、`di.dart`。
- [ ] `domain/` 定义 Entity 与 Repository 接口（不可变，C-ARCH-5）。
- [ ] `data/` 实现 DTO + DataSource + RepositoryImpl，并补 Mapper。
- [ ] `presentation/` 写 `@riverpod` Notifier 与页面；文案先加 ARB。
- [ ] 在 `core/router/` 注册路由。
- [ ] 补测试（覆盖率达到 `docs/dev/testing.md` 门禁）。
- [ ] 若改变了分层或依赖方向，先写 ADR。

