# 测试与质量

> 约束见 `docs/dev/constraints.md` §8（C-TEST-1..7）。
> 本文档定义测试分层、覆盖率门禁的**可执行实现**与 CI 流水线。

---

## 1. 测试分层

| 层 | 目标 | 范围 | 是否联网 |
|---|---|---|---|
| 单元测试 | `core/`、`domain/` | 纯函数、UseCase、规则引擎、Mapper | 否 |
| Widget 测试 | `presentation/` | 页面 smoke、交互、Semantics | 否 |
| Golden 测试 | 关键 UI 组件 | MD3E 令牌一致性 | 否 |
| 集成回放测试 | 书源全链路 | 搜索→详情→目录→正文（离线语料） | 否 |

**所有测试禁止真实联网**；`HttpClient` 与时间源必须可注入替身（C-NET-8、C-DEP-3）。

---

## 2. 覆盖率门禁

门禁由 `tool/check_coverage.dart` 执行，从 lcov 报告按**架构层**统计：

| 层 | 匹配路径 | 阈值 |
|---|---|---|
| `core` | `lib/core/**` | **100%** |
| `domain` | `lib/features/*/domain/**` | **100%** |
| `data` | `lib/features/*/data/**` | **≥80%** |

生成物（`*.g.dart`、`*.freezed.dart`、`*.gr.dart`、`**/generated/**`）不计入门禁。

```bash
flutter test --coverage
dart run tool/check_coverage.dart                  # 默认读取 coverage/lcov.info
dart run tool/check_coverage.dart --file=coverage/lcov.info --data=85
```

退出码：`0` 通过 · `1` 未达阈值 · `2` 报告缺失。

阈值可通过 `--core=`、`--domain=`、`--data=` 临时上调，**禁止下调**；
确需下调必须写 ADR。

---

## 3. 测试命名

- 文件名：与被测文件同目录，`*_test.dart`（C-TEST-4）。
- 测试名：`方法名_场景_预期结果`（C-TEST-3）。

```dart
test('searchBooks_whenNetworkFails_returnsParseFailure', () { /* ... */ });
test('parseHtml_givenExcludedRule_dropsMatchingNodes', () { /* ... */ });
```

- 一个 `test` 只断言一个行为；`group` 名称使用被测类型名。
- 禁止在测试中 `sleep`；时间相关逻辑必须注入时钟（`Clock` 抽象）。
- 禁止 `skip: true` 合入 `main`（C-TEST-5）。

---

## 4. 替身策略

| 依赖 | 替身方式 |
|---|---|
| `HttpClient` | 手写 Fake 返回固定 `HttpResponse`；禁止 mock `dio` 内部实现 |
| 文件/数据库 | Drift 内存数据库（`NativeDatabase.memory()`）+ `shared_preferences` 的 mock 初始值 |
| 时钟 | 注入 `Clock` 接口；禁止 `DateTime.now()` 直接出现在被测逻辑中 |
| Logger | 注入内存收集器，断言日志内容与级别 |
| Riverpod Provider | `ProviderScope(overrides: [provider.overrideWithValue(fake)])` |
| JS 引擎 | 单元测试用假 `JsBridge`；真实引擎只在集成回放测试中使用 |

`mocktail` 只用于验证「是否被调用」的边界场景；能用 Fake 的地方禁止用 Mock
（Mock 会让测试耦合实现细节）。

---

## 5. Golden 测试

- 使用 Flutter 内置 `matchesGoldenFile`；**禁止 `golden_toolkit`**（已停止维护，ADR-0009）。
- 基线文件目录：`test/golden/<feature>/<widget_name>.png`。
- 每个 Golden 测试必须固定以下条件，否则视为不稳定测试：

```dart
tester.view.physicalSize = const Size(1080, 1920);
tester.view.devicePixelRatio = 1.0;
addTearDown(tester.view.reset);

await tester.pumpWidget(
  ProviderScope(
    overrides: <Override>[
      dynamicColorProvider.overrideWithValue(null), // 固定种子色，禁用动态取色
    ],
    child: MaterialApp(
      theme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)).toM3EThemeData(),
      home: const BookSourceListPage(),
    ),
  ),
);
await tester.pumpAndSettle();
```

- 禁止在 Golden 中使用动画/网络图片/随机数据。
- 更新基线必须单独 PR，并在描述中说明视觉变更原因。

---

## 6. 书源与 Isolate 测试

| 场景 | 做法 |
|---|---|
| 规则引擎 | 纯 Dart 单元测试，语料见 `docs/dev/book-source.md` §10 |
| JS 桥接 | 单测用假 `JsBridge`；真实 `flutter_js_plus` 走 `integration_test`，标记 `@Tags(['js'])` |
| Isolate 超时 | 用可注入的 `timeout` 参数把超时压到毫秒级，禁止依赖真实 5 秒等待 |
| 大文件流 | 用生成器构造分块输入，断言内存不随文件大小线性增长 |

---

## 7. CI 流水线

`.github/workflows/ci.yml` 必须依次执行（顺序不可调整，先快后慢）：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code -- '**/*.g.dart' '**/*.freezed.dart' '**/*.gr.dart'
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart
```

要点：

- **生成物一致性检查**（第 3 步）保证 `*.g.dart` / `*.freezed.dart` 与源码同步，
  防止手改或忘记重新生成（C-DEP-5）。
- `riverpod_lint` 自 3.1.9 起改用 `analysis_server_plugin`，经
  `analysis_options.yaml` 的 `analyzer.plugins` 安装并**由 `flutter analyze` 执行**，
  不再需要 `custom_lint`（ADR-0010）。
- Golden 测试在 CI 中必须固定平台（`runs-on: ubuntu-latest`），
  禁止在有字体差异的多个平台上跑同一套基线。

---

## 8. 禁止事项

- 使用 `golden_toolkit`（已停止维护）。
- 在测试中真实联网或依赖外部站点可用性。
- 用 `pump(Duration)` 代替 `pumpAndSettle` 来规避动画问题。
- 为了让门禁通过而降低阈值或删除断言。
- 把生成物加入 `.gitignore` 之外的白名单以绕过一致性检查。

---

**文档版本：** v2.0 · **最后更新：** 2026-10-10
