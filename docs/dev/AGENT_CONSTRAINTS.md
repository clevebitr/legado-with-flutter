# 约束规则（AI Coder 扩展版）

> 在开发命名规范基础上，本补充文档针对 **架构、状态管理、错误处理、书源解析、平台适配、测试、安全、性能** 等方面，进一步约束 AI 生成代码的行为。所有规则与命名规范同等强制。

---

## 1. 架构与分层约束

| 规则 | 说明 |
|---|---|
| **严格分层** | `presentation` → `domain` → `data`，禁止反向依赖。UI 层不得直接调用 `data` 层的 Repository 或 Service。 |
| **跨 feature 共享** | 通用能力放入 `core/`，禁止在 feature 之间直接 import 对方的内部文件。 |
| **依赖注入** | 使用 `get_it` 或 Riverpod 的 Provider 进行依赖注入，禁止在 UI 中直接 `new` 一个 Service/Repository。 |
| **用例单一职责** | 每个 `UseCase` 只做一件事，类名 `动词+名词`，方法名 `execute` 或 `call`。 |
| **实体不可变** | `domain/entities/` 下的类必须使用 `freezed` 或手动实现不可变（`final` 字段 + `copyWith`）。 |

**AI 生成代码时：**
- 若需新增功能，先判断应放在哪个 feature、哪个层，禁止随意丢在 `core/`。
- 禁止在 `presentation` 中直接出现 `http.get`、`File`、`SharedPreferences` 等底层调用。

---

## 2. 状态管理约束

| 规则 | 说明 |
|---|---|
| **统一方案** | 全项目使用 **Riverpod**（推荐）或 **Bloc**，禁止混用多种状态管理库。 |
| **ViewModel 命名** | `XxxViewModel`，文件 `xxx_viewmodel.dart`，放在 `presentation/viewmodels/`。 |
| **状态类命名** | 若使用 Bloc，状态类为 `XxxState`，事件为 `XxxEvent`；若使用 Riverpod，使用 `AsyncNotifier` / `Notifier`。 |
| **禁止在 Widget 中直接写业务逻辑** | 所有业务逻辑必须放在 ViewModel / Notifier 中，Widget 只负责渲染和触发事件。 |
| **禁止使用 `setState` 管理跨组件状态** | 仅允许用于纯 UI 局部状态（如展开/折叠）。 |

**示例：**
```dart
// ✅ 正确：Riverpod Notifier
class BookSourceViewModel extends AsyncNotifier<List<BookSource>> {
  @override
  Future<List<BookSource>> build() async {
    return ref.read(bookSourceRepositoryProvider).getAll();
  }

  Future<void> addSource(BookSource source) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(bookSourceRepositoryProvider).add(source);
      return ref.read(bookSourceRepositoryProvider).getAll();
    });
  }
}
```

---

## 3. 错误处理与异步约束

| 规则 | 说明 |
|---|---|
| **统一结果类型** | 书源解析、网络请求等可能失败的操作，必须返回 `ParseResult<T>` 或 `Result<T, E>`，禁止直接抛异常到 UI。 |
| **禁止裸 `catch`** | 禁止 `catch (e) {}` 或 `catch (e) { print(e); }`，必须记录日志并转换为 `ParseFailure`。 |
| **禁止吞异常** | 任何异常必须被处理或向上传递，禁止空 catch 块。 |
| **异步安全** | 使用 `await` 时，若跨越 `BuildContext`，必须先检查 `mounted`。 |
| **禁止未处理的 Future** | 所有 `Future` 必须被 `await`、`.then`、或 `unawaited()` 显式处理。 |

**示例：**
```dart
// ✅ 正确
Future<ParseResult<BookInfo>> fetchBookInfo(String url) async {
  try {
    final response = await _httpClient.get(url);
    return ParseSuccess(_parseBookInfo(response.body));
  } on TimeoutException catch (e, stack) {
    _logger.warning('Fetch book info timeout: $url', e, stack);
    return ParseFailure('请求超时，请稍后重试', e);
  } on FormatException catch (e, stack) {
    _logger.error('Parse book info failed: $url', e, stack);
    return ParseFailure('解析失败，书源规则可能已失效', e);
  }
}

// ❌ 禁止
try {
  final data = await fetch();
} catch (e) {
  print(e);
}
```

---

## 4. 网络与数据层约束

| 规则 | 说明 |
|---|---|
| **统一 HTTP 客户端** | 所有网络请求必须通过 `core/network/` 中的 `HttpClient` 封装，禁止在 feature 中直接使用 `http` 或 `dio` 包。 |
| **超时与重试** | 默认超时 15 秒，可配置；重试策略必须显式声明，禁止无限重试。 |
| **编码处理** | 必须使用 `betto_charset_detector` 或等效方案检测编码，禁止假设 UTF-8。 |
| **User-Agent** | 必须提供可配置的 User-Agent，默认使用项目标识。 |
| **Cookie 管理** | 使用统一的 Cookie 管理器，禁止在业务层手动拼接 Cookie。 |
| **缓存策略** | 书源结果缓存必须设置 TTL，禁止无限缓存；缓存键必须包含书源 ID + 参数。 |
| **持久化** | 使用 `Drift` / `Isar` / `Hive`，禁止直接操作 SQLite 或文件系统。 |

---

## 5. 书源解析特定约束

| 规则 | 说明 |
|---|---|
| **纯 Dart 实现** | 书源规则解析引擎必须完全使用 Dart 实现，禁止在 UI 层调用原生代码。 |
| **JS 隔离** | JavaScript 执行必须通过 `flutter_js_plus` / `flutter_qjs`，并在 **独立 Isolate** 中运行，禁止阻塞 UI 线程。 |
| **规则引擎可测试** | `RuleEngine` 必须无 UI 依赖，所有解析逻辑必须可单元测试。 |
| **规则兼容性** | 遇到不支持的规则类型，必须返回 `ParseFailure` 并记录日志，禁止静默忽略。 |
| **URL 模板渲染** | 使用 `renderUrlTemplate` 统一处理 `{{}}` 插值，禁止手动字符串拼接。 |
| **CSS 选择器** | 统一使用 `cascadia` 包，禁止使用其他 CSS 选择器库。 |
| **JSONPath** | 统一使用 `json_path` 包，禁止手写 JSON 遍历。 |
| **编码检测** | 统一使用 `betto_charset_detector`，禁止假设编码。 |
| **书源模型** | `BookSource` 及其子规则必须使用 `freezed` + `json_serializable`，禁止手写 `fromJson` / `toJson`。 |

**示例：**
```dart
@freezed
class BookSource with _$BookSource {
  const factory BookSource({
    required String name,
    required String url,
    required SearchRule searchRule,
    required BookInfoRule bookInfoRule,
    required TocRule tocRule,
    required ContentRule contentRule,
  }) = _BookSource;

  factory BookSource.fromJson(Map<String, dynamic> json) =>
      _$BookSourceFromJson(json);
}
```

---

## 6. 主题与 UI 约束

| 规则 | 说明 |
|---|---|
| **MD3E Token** | 所有颜色、字体、形状、间距必须从 `Theme.of(context).extension<M3ETheme>()` 获取，禁止硬编码 `Color(0xFF...)` 或 `EdgeInsets.all(16)`。 |
| **动态取色** | 动态取色必须通过 `material_you_dynamic_theme`，并在 Windows/iOS 提供 fallback 主题。 |
| **预测性返回** | Android 预测性返回必须启用 `PredictiveBackPageTransitionsBuilder`，并在 `AndroidManifest.xml` 中开启 `enableOnBackInvokedCallback`。 |
| **响应式布局** | 必须适配手机、平板、桌面，使用 `LayoutBuilder` 或 `MediaQuery`，禁止固定宽度。 |
| **可访问性** | 所有交互组件必须提供 `Semantics` 标签，图片必须有 `semanticLabel`。 |
| **国际化** | 所有用户可见字符串必须来自 `l10n/` 的 ARB 文件，禁止硬编码中英文。 |

**示例：**
```dart
// ✅ 正确
final theme = Theme.of(context).extension<M3ETheme>()!;
Container(
  color: theme.colorScheme.surface,
  padding: EdgeInsets.all(theme.spacing.medium),
  child: Text(
    AppLocalizations.of(context)!.bookSourceListTitle,
    style: theme.textTheme.titleLarge,
  ),
)

// ❌ 禁止
Container(
  color: Color(0xFF6750A4),
  padding: EdgeInsets.all(16),
  child: Text('书源列表'),
)
```

---

## 7. 平台适配约束

| 平台 | 约束 |
|---|---|
| **Android** | 动态取色、预测性返回必须通过抽象接口调用，禁止在 UI 中直接判断 `Platform.isAndroid`。 |
| **Windows** | 必须提供无动态取色的 fallback 主题；文件路径使用 `path_provider`，禁止硬编码 `C:\`。 |
| **iOS** | 遵循 Human Interface Guidelines，返回手势使用原生导航；动态取色不可用时使用默认种子色。 |
| **通用** | 平台特定代码必须放在 `core/platform/` 下，通过接口注入，禁止在业务层散落 `Platform.isXxx`。 |

---

## 8. 测试与质量约束

| 规则 | 说明 |
|---|---|
| **单元测试** | `core/` 和 `domain/` 必须 100% 覆盖；`data/` 至少 80%。 |
| **Widget 测试** | 所有页面级 Widget 必须有至少一个 smoke test。 |
| **测试命名** | `方法名_场景_预期结果`，例如 `searchBooks_whenNetworkFails_returnsParseFailure`。 |
| **测试文件位置** | 与被测文件同目录，文件名 `*_test.dart`。 |
| **禁止跳过测试** | 禁止 `skip: true` 提交到 main，除非有明确 issue 关联。 |
| **Golden 测试** | 关键 UI 组件建议添加 Golden 测试，确保 MD3E 主题一致性。 |
| **CI 必须通过** | `flutter analyze`、`flutter test`、`dart format --set-exit-if-changed` 全部通过。 |

---

## 9. 依赖与代码生成约束

| 规则 | 说明 |
|---|---|
| **依赖最小化** | 新增依赖必须经团队评审，禁止引入体积过大或维护不活跃的包。 |
| **固定版本** | `pubspec.yaml` 中使用 `^` 或精确版本，禁止使用 `any`。 |
| **代码生成** | 使用 `freezed`、`json_serializable`、`riverpod_generator`，生成文件（`*.g.dart`、`*.freezed.dart`）禁止手动修改。 |
| **生成命令** | 必须使用 `dart run build_runner build --delete-conflicting-outputs`。 |
| **禁止提交生成文件冲突** | 若生成文件冲突，必须重新生成，禁止手动合并。 |

---

## 10. 安全与性能约束

| 规则 | 说明 |
|---|---|
| **禁止硬编码密钥** | API Key、Token 等必须通过环境变量或安全存储，禁止写在源码中。 |
| **HTTPS** | 所有网络请求必须使用 HTTPS，除非用户显式允许 HTTP。 |
| **JS 沙箱** | 书源 JS 执行必须限制访问权限，禁止调用文件系统或网络以外的敏感 API。 |
| **性能** | 禁止在 `build` 中执行重计算；列表使用 `ListView.builder`；图片使用 `cached_network_image`。 |
| **内存** | 大文件解析必须使用流式处理，禁止一次性加载整个文件到内存。 |
| **Isolate** | 耗时超过 16ms 的计算必须放入 `Isolate` 或 `compute`。 |

---

## 11. AI 生成代码的额外禁令

| 禁令 | 说明 |
|---|---|
| **禁止生成未使用的代码** | 不允许生成未引用的类、方法、变量、import。 |
| **禁止生成 TODO 占位** | 若无法实现，必须明确说明并返回 `ParseFailure`，禁止留 `// TODO` 空实现。 |
| **禁止修改生成文件** | 不得手动编辑 `*.g.dart`、`*.freezed.dart`。 |
| **禁止引入未声明的依赖** | 生成代码前必须确认 `pubspec.yaml` 中已有该依赖。 |
| **禁止跨层调用** | 不得在 `presentation` 中直接 import `data` 层。 |
| **禁止使用 `print`** | 必须使用 `logger` 或 `debugPrint`。 |
| **禁止使用 `dynamic`** | 除非与 JS 引擎交互，必须使用具体类型或 `Object?`。 |
| **禁止强制解包 `!`** | 优先使用 `??`、模式匹配或 `late`。 |
| **禁止忽略 `BuildContext` 异步间隙** | 跨 `await` 使用 `context` 前必须检查 `mounted`。 |
| **禁止生成不通过 `flutter analyze` 的代码** | AI 必须自行确保零警告。 |

---

## 12. 更新后的 AI 检查清单

在生成任何代码后，AI 必须逐项确认：

- [ ] 文件/目录/类/方法/变量命名是否符合《命名规范》？
- [ ] 是否遵循分层架构，无跨层依赖？
- [ ] 是否使用统一的状态管理方案？
- [ ] 是否使用 `ParseResult` 或 `Result` 处理可能失败的操作？
- [ ] 是否避免了裸 `catch` 和吞异常？
- [ ] 网络请求是否通过统一 `HttpClient`？
- [ ] 书源解析是否纯 Dart、JS 是否隔离？
- [ ] 主题是否使用 MD3E Token，无硬编码？
- [ ] 是否支持多平台 fallback？
- [ ] 是否有对应单元测试 / Widget 测试？
- [ ] 是否使用了 `freezed` / `json_serializable`？
- [ ] 是否避免了硬编码密钥、HTTP、性能陷阱？
- [ ] 是否没有生成未使用代码、TODO 占位、修改生成文件？
- [ ] 是否通过 `flutter analyze` 和 `dart format`？

---

## 13. 给 AI 的完整提示词模板

> 请严格遵循项目 `docs/NAMING_CONVENTIONS.md` 和 `docs/ADDITIONAL_CONSTRAINTS.md`。生成代码时：
> - 分层：`presentation` → `domain` → `data`，禁止反向依赖。
> - 状态管理：使用 Riverpod，ViewModel 命名 `XxxViewModel`。
> - 错误处理：返回 `ParseResult<T>`，禁止裸 `catch`、禁止 `print`。
> - 网络：通过 `core/network/HttpClient`，禁止直接使用 `http`/`dio`。
> - 书源：纯 Dart 解析，JS 在 Isolate 中执行，使用 `cascadia`、`json_path`、`betto_charset_detector`。
> - 主题：从 `M3ETheme` 获取 Token，禁止硬编码颜色/尺寸。
> - 平台：Android 动态取色/预测性返回通过抽象接口，Windows/iOS 提供 fallback。
> - 测试：`core/` 和 `domain/` 必须 100% 覆盖。
> - 依赖：使用 `freezed` + `json_serializable`，生成文件不手动修改。
> - 安全：禁止硬编码密钥，强制 HTTPS，JS 沙箱。
> - 性能：重计算放入 `Isolate`，列表懒加载。
> - 禁止：未使用代码、TODO 占位、`dynamic`、`!` 强制解包、跨 `await` 使用 `context` 不检查 `mounted`。
> - 必须通过 `flutter analyze` 零警告和 `dart format`。

---

**文档版本：** v1.0  
**适用项目：** Flutter 阅读 App（MD3E、多平台、Dart 书源解析）  
**维护者：** Clevebitr  
**最后更新：** 2026-10-10