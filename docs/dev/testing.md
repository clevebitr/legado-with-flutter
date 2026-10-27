# 测试与质量

> 约束见 `docs/dev/constraints.md` §8（C-TEST-1..7）。
> 本文档定义测试分层、覆盖率门禁的**可执行实现**与 CI 流水线。
> 本机（Windows）如何把测试跑起来（一键脚本、Windows/Android 设备级用例、模拟器排错）见
> `docs/dev/test-environment.md`。

---

## 1. 测试分层

| 层 | 目标 | 范围 | 是否联网 |
|---|---|---|---|
| 单元测试 | `core/`、`domain/` | 纯函数、UseCase、规则引擎、Mapper | 否 |
| Widget 测试 | `presentation/` | 页面 smoke、交互、Semantics | 否 |
| Golden 测试 | 关键 UI 组件 | MD3E 令牌一致性 | 否 |
| 集成回放测试 | 书源全链路 | 搜索→详情→目录→正文（离线语料） | 否 |
| 设备级集成测试 | 真实引擎 / 平台通道 / 原生 SQLite | `integration_test/`（Windows 桌面、Android 模拟器） | 否 |

**设备级用例的执行时点**（**切片级双端各一次**、阶段出口双端全量，以及环境阻塞的降级路径与重开条件）归 `docs/dev/test-environment.md` §1/§3，决策理由见 **ADR-0039**；本节不复述。

设备级集成测试**不进 CI**（§7 的命令清单与 `AGENTS.md` §4 不变）；要把它接入 CI 需另开 PR/ADR
（ADR-0017 §决策 5：需要 Android SDK/模拟器，iOS 还需 macOS）。

**所有测试禁止真实联网**；`HttpClient` 与时间源必须可注入替身（C-NET-8、C-DEP-3）。

---

## 2. 覆盖率门禁

门禁由 `tool/check_coverage.dart` 执行，从 lcov 报告按**架构层**统计：

| 层 | 匹配路径 | 阈值 |
|---|---|---|
| `core` | `lib/core/**` | **95%** |
| `domain` | `lib/features/*/domain/**` | **95%** |
| `data` | `lib/features/*/data/**` | **≥80%** |

生成物（`*.g.dart`、`*.freezed.dart`、`*.gr.dart`、`**/generated/**`）不计入门禁。

> 阈值从 100% 降到 95% 的理由见 **ADR-0077**：100% 已经饱和成「为覆盖率而写测试」
> （plumbing / `copyWith` / DI 装配 / 为凑执行点而造的构造方式），空出的 5% 只能用来
> 删掉**无行为可言**的用例，不得用于「新功能先不写测试」——《未测量源文件》判定不变。

门禁有两类判定，**任何一类失败即整体失败**（ADR-0019）：

1. **阈值**：上表中每层累计行覆盖率不得低于阈值。
2. **未测量源文件**：`lib/core/**`、`lib/features/*/domain/**`、`lib/features/*/data/**` 下的
   每个源文件都必须出现在报告中。lcov 只统计**运行期被加载过**的库，因此
   「新增了生产代码但没写测试」不会拉低百分比，而是直接命中本项。
   确需豁免的文件（仅特定平台可达、只能跑在 `integration_test` 的入口，或代码生成器的
   输入文件如 drift 表定义、以及纯 `freezed` 实体这类**源文件无可测量行**的声明式输入）
   逐行写入 `tool/coverage_allowlist.txt` 并在行内注释原因；
   代码生成器输入类的文件还必须加 `// coverage:ignore-file`（否则仍会因阈值失败），
   其正确性由别的测试保证。子情形的完整定义与 2026-10-11 修订见 ADR-0019 §2。
   allowlist **不得**用于「暂时没写测试」，且条目若**出现在**报告中同样判失败。
   手写文件若使用 `// coverage:ignore-file`，会被 lcov 从报告中整体移除，
   因此同样需要在 allowlist 中登记并说明原因。

```bash
flutter test --coverage
dart run tool/check_coverage.dart                  # 默认读取 coverage/lcov.info + tool/coverage_allowlist.txt
dart run tool/check_coverage.dart --file=coverage/lcov.info --data=85
dart run tool/check_coverage.dart --allowlist=    # 不使用 allowlist（排查用）
```

退出码：`0` 通过 · `1` 未达阈值 · `2` 报告缺失 · `3` 存在未测量源文件（或 allowlist 已过期）。

阈值可通过 `--core=`、`--domain=`、`--data=` 临时上调，**禁止下调**；
确需下调必须写 ADR。

---

## 3. 测试命名

- 文件名：`*_test.dart`。单元 / Widget / 回放测试放在 `test/` 下并**镜像被测文件的 `lib/`
  相对路径**（C-TEST-4、ADR-0017）：`lib/core/error/parse_result.dart` →
  `test/core/error/parse_result_test.dart`；**设备级集成测试**放在 `integration_test/` 下平铺，
  不镜像 `lib/`（ADR-0017 §决策 5、`docs/dev/test-environment.md`）。
  `lib/**` 下禁止出现 `*_test.dart`。
- **唯一例外：文档漂移门禁**（`test/docs/book_source_doc_test.dart`）。它们比对的是
  `docs/dev/book-source.md` 与代码/用例，没有 `lib/` 对应物，所以固定放在 `test/docs/`。两条门禁
  （M27 的 G1/G2，ADR-0078 §切片 S7）：
  - **G1**：§11 的两个 `text` 代码块必须与 `quickjs_worker.dart` 的 `__javaRejectedNames` /
    `__javaInteropNames` 逐字一致——改实现必须改文档，反之亦然；
  - **G2**：§3 矩阵里状态为「已确认」的每一行都必须有具名用例（测试文件里出现 `matrix #N`），
    行号不变而用例被删时这里先红。
- 测试名：`方法名_场景_预期结果`（C-TEST-3）。

```dart
test('searchBooks_whenNetworkFails_returnsParseFailure', () { /* ... */ });
test('parseHtml_givenExcludedRule_dropsMatchingNodes', () { /* ... */ });
```

- 一个 `test` 只断言一个行为；`group` 名称使用被测类型名。
- **同构用例写成表驱动**（ADR-0077 §决策 4）：当只有输入/期望值不同（同一个方法的多行平台、多个 provider
  的同一形状、多个失败种类走同一条路径）时，写一个 `test` + 循环，并使用 `reason:` 标出当前行。
  用例名仍按 `方法名_场景_预期结果` 写，只是场景描述的是**规则**而不是单行数据，
  例如 `dialogPorts_givenAShippedPlatform_useTheRealDialogOrKeyStore`。
  链路上确实分叉的行为不要塞进表驱动（那样断言的就不是同一件事了）。
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

**共享替身与测试装置放 `test/support/`**：替身命名 `fake_<subject>.dart`（例如
`fake_platform_info.dart`），共享装置（语料加载、provider 装配等 harness）按内容命名
（例如 `offline_corpus.dart`）；该目录只放这两类，不放测试用例（测试文件仍按 §3 镜像到 `test/` 下）。

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
      platformDynamicColorProvider.overrideWithValue(null), // 固定种子色，禁用动态取色
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
| JS 桥接 | 单测用假 `JsBridge`；真实引擎探针位于 `tool/spike/`（需先构建原生库后手动运行，见 `tool/spike/README.md`、ADR-0015），**不进入** `flutter test` 的默认发现路径 |
| Isolate 超时 | 用可注入的 `timeout` 参数把超时压到毫秒级，禁止依赖真实 5 秒等待 |
| 大文件流 | 用生成器构造分块输入，断言内存不随文件大小线性增长 |

---

## 7. CI 流水线

`.github/workflows/ci.yml` 必须依次执行（顺序不可调整，先快后慢）。
**命令本体不在本节重复：唯一出处为 `AGENTS.md` §4**（ADR-0013 §5）。
本节只定义顺序与 CI 特有项：

| 顺序 | 步骤 | 备注 |
|---|---|---|
| 1 | `flutter pub get` | CI 特有（本地常驻） |
| 2 | 生成代码（C-DEP-4） | 必须先于一致性检查与静态分析 |
| 3 | 生成物一致性检查 | 保证 `*.g.dart` / `*.freezed.dart` 与源码同步，防手改或忘生成（C-DEP-5） |
| 4 | `dart format --set-exit-if-changed .` | 快，先跑 |
| 5 | `flutter analyze` | 含 riverpod_lint 插件规则（安装位置见 `docs/dev/tech-stack.md` §12） |
| 6 | `flutter test --coverage` | 覆盖率报告是第 7 步的输入 |
| 7 | `dart run tool/check_coverage.dart` | 阈值 + 未测量源文件（§2、ADR-0019） |


### 7.1 分层与三条发布通道

`.github/workflows/` 现在是「一个门禁 + 一个可复用构建 + 三条通道」（判据见 ADR-0065、ADR-0067）：

| 文件 | 角色 | 触发 |
|---|---|---|
| `ci.yml` | **L1 门禁**：上面的 1–7 步，job 名 `verify`（`main` 规则集的 status check，不许改名） | PR、push main、push `v*` tag、手动 |
| `build-artifacts.yml` | **可复用构建**（`workflow_call`）：Windows / Android / iOS | 只被三条通道调用 |
| `release.yml` | **正式版**：tag 必须等于 `v<pubspec 版本>` → 等门禁绿 → 构建 → 正式 Release | push `v*` tag、手动（给 tag） |
| `beta.yml` | **beta**：等门禁绿 → 构建 → 预发布 Release | 仅手动 dispatch（可选 ref 与说明） |
| `debug.yml` | **debug**：等门禁绿 → 构建 → 预发布 Release | push main、手动 |

跨 workflow 的「先门禁后打包」由 `.github/actions/wait-for-verify` 轮询该 commit 的 `ci.yml` 运行实现
（`needs` 跨不了 workflow）；门禁命令本身仍只在 `ci.yml` 里写一次。

### 7.2 版本号与产物名

版本号组合只有一处实现：`.github/actions/version`（ADR-0067 §决策 2）。

| 通道 | 版本号 | 产物名 |
|---|---|---|
| 正式版 | `0.1.0`（= `pubspec.yaml`，tag 必须 `v0.1.0`） | `flutter-reader-0.1.0-…` |
| beta | `0.1.0-beta.<sha7>` | `flutter-reader-0.1.0-beta.a1b2c3d-…` |
| debug | `0.1.0-debug.<sha7>.<UTC yyyyMMddHHmm>` | `flutter-reader-0.1.0-debug.a1b2c3d.202610231540-…` |

每个版本出四个文件：`-windows-x64.zip`、`-android.apk`、`-android.aab`、`-ios-unsigned.xcarchive.zip`。
`--build-number` 用工作流运行号；**iOS 的 `build-name` 只用数字版本**（`CFBundleShortVersionString`
不允许后缀），通道信息走 `--dart-define=APP_VERSION` 与文件名。产物局限与 iOS 签名步骤见
`docs/dev/platform.md` §8.3。

---

## 8. 禁止事项

- 使用 `golden_toolkit`（已停止维护）。
- 在测试中真实联网或依赖外部站点可用性。
- 用 `pump(Duration)` 代替 `pumpAndSettle` 来规避动画问题。
- 为了让门禁通过而降低阈值或删除断言（阈值只能按 ADR-0077 的规则调整：
  只能上调，下调必须另写 ADR，不得在一个 PR 里「顺手」改）。
- 把生成物加入 `.gitignore` 之外的白名单以绕过一致性检查。
