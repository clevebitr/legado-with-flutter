# 约束规则

> 本文档是**约束主题的唯一来源**（命名规范见 `docs/dev/naming.md`）。
> 每条约束带稳定 ID `C-<组>-<序号>`，ID 规则见 `docs/README.md` §5。
> 冲突裁决记录在 `docs/dev/adr/`。
>
> 本文档末尾的 **§15 自查清单** 与 **§16 AI 提示词模板** 是全项目**唯一**的副本，
> 其他文档只允许链接到此处。

判定原则：每条约束都必须**可判定**、**可被 lint 或 review 验证**。
凡不能判定的表述视为缺陷，应改写或删除。

---

## 1. 架构与分层

| ID | 约束 |
|---|---|
| C-ARCH-1 | 依赖方向必须为 `presentation` → `domain` → `data`；禁止反向依赖。`presentation` 不得 import `data` 层任何文件。 |
| C-ARCH-2 | 跨 feature 的通用能力放入 `core/`；禁止 feature 之间直接 import 对方内部文件。 |
| C-ARCH-3 | 依赖注入统一使用 Riverpod Provider；**禁止引入 `get_it`**（见 ADR-0005）。禁止在 UI 中直接 `new` Service / Repository。 |
| C-ARCH-4 | 每个 `UseCase` 只做一件事，类名为「动词 + 名词」，对外方法固定为 `execute()`。 |
| C-ARCH-5 | `domain/entities/` 下的类型必须不可变：使用 `freezed`，或 `final` 字段 + `copyWith`。 |
| C-ARCH-6 | 新增文件前必须先按 `docs/dev/architecture.md` 确定归属的 feature 与层，禁止把业务代码丢进 `core/`。 |
| C-ARCH-7 | `domain/` 不得依赖 Flutter（禁止 import `package:flutter/*`）与任何平台 API。 |

---

## 2. 状态管理

| ID | 约束 |
|---|---|
| C-STATE-1 | 唯一状态管理方案为 **Riverpod**；禁止 Bloc / GetX / `package:provider` / `mobx`。禁止混用（见 ADR-0001）。 |
| C-STATE-2 | 所有 Provider 必须**由 `@riverpod` 代码生成**；禁止手写 `Provider` / `Notifier` / `AsyncNotifier`（由 `riverpod_lint` 的 `avoid_manual_providers_as_generated_provider_dependency` 强制）。 |
| C-STATE-3 | Notifier 命名 `XxxNotifier`，文件 `xxx_notifier.dart`，位置 `presentation/notifiers/`。`XxxViewModel` 命名已废弃（见 ADR-0001）。 |
| C-STATE-4 | 业务逻辑只能存在于 Notifier / UseCase 中；Widget 只负责渲染与派发事件。 |
| C-STATE-5 | `setState` 仅允许用于纯局部 UI 状态（展开/折叠/动画控制器），禁止管理跨组件状态。 |
| C-STATE-6 | Notifier 对外暴露状态必须为不可变对象；禁止暴露可变集合或 Controller 实例（`avoid_public_notifier_properties`）。 |

```dart
// ✅ 正确：@riverpod 代码生成 + 不可变状态
@riverpod
class BookSourceList extends _$BookSourceList {
  @override
  Future<List<BookSource>> build() async =>
      ref.watch(bookSourceRepositoryProvider).getAll();

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

## 3. 错误处理与异步

| ID | 约束 |
|---|---|
| C-ERR-1 | 可能失败的操作（网络、解析、IO）必须返回 `ParseResult<T>`；禁止把异常抛到 UI 层。 |
| C-ERR-2 | 禁止裸 `catch`；必须 `on <具体异常类型>`，并转换为 `ParseFailure`。由 lint `avoid_catches_without_on_clauses` 强制。**边界补充（放宽点的依据见 ADR-0002 的 2026-10-11 修订注记）：** 只有 `presentation/` 的 Notifier 兜底允许 `on Exception`（不给更具体的类型），且必须立即转为失败状态并记录日志，不得吞掉；`domain/` 的引擎与 UseCase 仍必须捕获具体类型；`Error` 在任何位置都不得捕获（ADR-0022）。**扩展规则：** 本边界只覆盖 `presentation/` 的 Notifier；将来 `data/` 层若也需兜底，必须新增 ADR，不得就地放宽。**已批准的例外（唯一一处）：** `CacheDaoCharsetCache._absorb` 可在具名 catch 后追加 `on Exception`，吸收 drift **未导出**的 `ConnectionClosedException`（端口契约为 total）——理由、约束与日落条件见 **ADR-0033**；其他位置照抄即违规。 |
| C-ERR-3 | 禁止空 catch 块；异常必须被处理或向上传递。 |
| C-ERR-4 | 跨 `await` 使用 `BuildContext` 前必须检查 `mounted`（`use_build_context_synchronously`）。 |
| C-ERR-5 | 禁止 `print()`；统一使用 `core/logging` 暴露的 Logger（`logger` 包封装，见 ADR-0006）。 |
| C-ERR-6 | 所有 `Future` 必须被 `await`、`.then`、或 `unawaited()` 显式处理（`unawaited_futures`）。 |
| C-ERR-7 | `ParseFailure` 必须携带 `ParseFailureKind` 与结构化参数；**禁止在失败对象中存放用户可见中文文案**，文案由 UI 层经 l10n 映射。 |
| C-ERR-8 | 失败日志必须包含书源 ID 与目标 URL/参数摘要；**禁止**记录页面正文、Cookie 与 Token。 |
| C-ERR-9 | 未支持的能力禁止留 `// TODO` 空实现；必须返回 `ParseFailure(ParseFailureKind.unsupportedRule)` 或在评审中明确拒绝该需求。 |

```dart
// ✅ 正确
Future<ParseResult<BookInfo>> fetchBookInfo(String url) async {
  try {
    final response = await _httpClient.get(url);
    return ParseSuccess(_parseBookInfo(response.body));
  } on TimeoutException catch (error, stackTrace) {
    _logger.warning('Book info timed out: $url', error, stackTrace);
    return const ParseFailure(
      kind: ParseFailureKind.networkTimeout,
      rulePath: r'$.bookInfoRule',
    );
  } on FormatException catch (error, stackTrace) {
    _logger.error('Book info parse failed: $url', error, stackTrace);
    return const ParseFailure(kind: ParseFailureKind.parseFailed);
  }
}
```

契约定义见 `docs/dev/architecture.md` §5。

---

## 4. 网络与数据层

| ID | 约束 |
|---|---|
| C-NET-1 | 所有网络请求必须经 `core/network/HttpClient`；feature 中禁止直接 import `dio` 或 `http`。 |
| C-NET-2 | 默认超时 15 秒且可配置；重试策略必须显式声明次数上限，禁止无限重试。 |
| C-NET-3 | 编码必须经 `betto_charset_detector` 检测；禁止假设 UTF-8。可解码的标签集与已知缺口见 `docs/dev/book-source.md` §5.1；**解码失败的判定与「已声明车道」的宽容边界见 §5（ADR-0031）**，本组不复述车道与 warning 规则。 |
| C-NET-4 | User-Agent 必须可配置，默认使用项目标识。 |
| C-NET-5 | Cookie 由统一 `CookieManager` 管理；禁止业务层手动拼接 Cookie 头。 |
| C-NET-6 | 缓存必须设置 TTL；缓存键必须为「书源 ID + 参数摘要」的稳定哈希；禁止无限缓存。 |
| C-NET-7 | 持久化统一经 `core/storage/` 的仓储实现（Drift 或 `shared_preferences`）；禁止在业务层直接操作文件系统或拼 SQL。 |
| C-NET-8 | 仓储必须定义在 `domain/`、实现在 `data/`，以便用 mock 单测。 |
| C-NET-9 | 存储分工固定：结构化数据（书源、章节、阅读进度、缓存）用 Drift；轻量开关（主题模式、字号）用 `shared_preferences`（见 ADR-0003）。 |

---

## 5. 书源解析

> 规则类型支持矩阵、`{{}}` 模板语法、替换/过滤规则与失败语义的完整规格见
> `docs/dev/book-source.md`。本节只放不可协商的约束。

| ID | 约束 |
|---|---|
| C-SRC-1 | 解析引擎必须为纯 Dart，且无 Flutter / UI 依赖（受 C-ARCH-7 约束）。 |
| C-SRC-2 | JS 规则必须在**独立 Isolate** 中执行，禁止阻塞 UI 线程（ADR-0015）。超时、内存上限与调用次数配额见 `docs/dev/book-source.md` §6（本文档不复述数值）；`Isolate.kill(priority: immediate)` 必须保留为硬预算兜底。 |
| C-SRC-3 | JS 桥接只暴露 `book-source.md` 声明的白名单 API；禁止暴露文件系统、进程、网络与原生日志。 |
| C-SRC-4 | 不支持的规则类型必须返回 `ParseFailure(unsupportedRule)` 并记录日志；**禁止静默忽略**。顶层规则（`bookList` / `chapterList` / `content`）被拒时必须整次失败；非顶层字段被拒时的降级语义（置空 + warning）见 **ADR-0026**；**类型未知不等于不支持**（退化为原始 CSS，见 **ADR-0032**）；发现页的分类条目与 `ruleExplore` → `ruleSearch` 的**整条回落**见 **ADR-0035**。 |
| C-SRC-5 | URL 模板必须统一经渲染入口（`PageFetchService.renderUrl`；同步部分仍是 `renderUrlTemplate`）渲染；禁止手写字符串拼接。`{{…}}` 的求值边界（搜索 / 发现 URL 内只允许 JS）见 `docs/dev/book-source.md` §4 / §4.2。 |
| C-SRC-6 | CSS 选择器统一 `cascadia`；JSONPath 统一 `json_path`；禁止自研选择器或手写 JSON 遍历。 |
| C-SRC-7 | `BookSource` 及全部子规则必须使用 `freezed` + `json_serializable`；禁止手写 `fromJson` / `toJson`。模型位于 `domain/entities/`，该层归属的例外见 ADR-0021。 |
| C-SRC-8 | 失败必须可定位到规则路径：`ParseFailure.rulePath` 必填，供 UI 与日志定位失效规则。 |
| C-SRC-9 | 同一书源的解析不得共享可变全局状态；`RuleEngine` 必须可并发调用且线程安全。规则变量（`@put:` / `@get:` / `java.*`）按书源键控的存储与快照语义见 ADR-0034；书源限速（`concurrentRate`）与并发预算的「速率门 → 并发门」合成见 ADR-0036（数值归 `book-source.md` §8）。 |

> 书源模型的**字段映射与分期**归 `docs/dev/book-source.md` §2，类型命名归 `docs/dev/naming.md` §3，
> 本组不复述；`freezed` + `json_serializable` 的写法示例见 `docs/dev/architecture.md` §3 的例外一。

---

## 6. 主题与 UI

> 设计令牌的**唯一来源**是 `m3e_design` 的 `M3ETheme`。
> 以下 API 已按 `m3e_design` 0.2.1 核实（见 ADR-0004）。

| ID | 约束 |
|---|---|
| C-UI-1 | 颜色、排版、形状、间距、动效令牌一律取自 `context.m3e`（或 `Theme.of(context).m3e`）；禁止硬编码 `Color(0xFF...)`、`EdgeInsets.all(16)`、字号与圆角。**唯一例外**：`lib/core/theme/app_theme.dart` 中的种子色常量 `defaultSeedColor` —— 它是生成令牌的输入，不是令牌本身。 |
| C-UI-2 | `M3ETheme` 的安装必须经 `withM3ETheme(...)` 或 `ColorScheme.toM3EThemeData()`；取值用 `Theme.of(context).m3e`（非空，自带 fallback）。**禁止** `Theme.of(context).extension<M3ETheme>()!` 这类强制解包。 |
| C-UI-3 | 动态取色必须经 `dynamic_color` 的 `DynamicColorBuilder` 获取 `ColorScheme`，再交给 `m3e_design` 的和声工具协调；Windows / iOS 必须提供种子色 fallback（见 ADR-0004）。 |
| C-UI-4 | 预测性返回必须启用 `PredictiveBackPageTransitionsBuilder`，并按 `docs/dev/platform.md` 配置 `AndroidManifest.xml`。 |
| C-UI-5 | 所有用户可见字符串必须来自 `AppLocalizations`（`nullable-getter: false`，取值不需要 `!`）；禁止硬编码中英文字符串。 |
| C-UI-6 | 响应式布局必须使用 `LayoutBuilder` / `MediaQuery`；禁止固定宽高与非流式约束。 |
| C-UI-7 | 所有交互组件必须提供**可访问名称**，不得只靠图标传达含义；Material 派生语义即满足（`IconButton` 的 `tooltip`、`ListTile` 的标题/副标题文本、`TextField` 的 `hintText` 等），显式 `Semantics` 包装不是硬性要求（保障方式见 `docs/dev/tech-stack.md` §12）；图片必须提供 `semanticLabel`。 |
| C-UI-8 | 禁止在 `build` 中构造可常量化对象（`TextStyle`、`BoxDecoration`、`EdgeInsets`）；主题相关对象必须来自令牌。 |
| C-UI-9 | 必须提供「关于 → 法律声明」页面，显示版权、无担保声明、**禁止侵权用途声明（见 ADR-0023）**、GPL-3.0 全文查看入口与源代码获取入口（GPL-3.0 §0/§5d/§6）。文案键：`legalNoticesTitle`、`legalNoticesCopyright`、`legalNoticesNoWarranty`、`legalNoticesViewLicense`、`legalNoticesCorrespondingSource`、`legalNoticesProhibitedUse`。 |

> `M3ETheme` 的完整 API 清单（含 `M3ESpacing` 六阶数值与 `typography.base` 要求）与
> 正确 / 禁止写法示例见 `docs/dev/tech-stack.md` §3.1，本组不复述。

---

## 7. 平台适配

> 平台基线与降级验收标准见 `docs/dev/platform.md`。

| ID | 约束 |
|---|---|
| C-PLT-1 | 平台差异代码只能放在 `core/platform/`，并通过抽象接口注入；禁止在业务层散落 `Platform.isXxx`。 |
| C-PLT-2 | Android 动态取色与预测性返回必须经抽象接口调用；UI 不直接判断平台（`DynamicColorProvider` 的接口形态与注入点见 ADR-0020）。 |
| C-PLT-3 | Windows 必须提供无动态取色的 fallback 主题；路径统一使用 `path_provider`，禁止硬编码 `C:\`。 |
| C-PLT-4 | iOS 遵循 Human Interface Guidelines；返回手势使用原生导航；动态取色不可用时使用默认种子色。 |
| C-PLT-5 | `minSdk` / `targetSdk` / 最低 Windows 版本等基线以 `docs/dev/platform.md` 为准，不得在文档其他位置另立数值。 |

---

## 8. 测试与质量

> 测试分层、Golden 策略与 CI 流水线的完整规格见 `docs/dev/testing.md`。

| ID | 约束 |
|---|---|
| C-TEST-1 | 覆盖率门禁（各层阈值唯一定义在 `docs/dev/testing.md` §2，由 `tool/check_coverage.dart` 强制执行）。 |
| C-TEST-2 | 所有页面级 Widget 至少一个 smoke test。 |
| C-TEST-3 | 测试命名格式：`方法名_场景_预期结果`，例如 `searchBooks_whenNetworkFails_returnsParseFailure`。 |
| C-TEST-4 | 测试文件的位置（镜像 `lib/` 相对路径、`integration_test/` 例外）与命名见 `docs/dev/testing.md` §3（ADR-0017）；`lib/**` 下禁止出现 `*_test.dart`，文件名固定 `*_test.dart`。 |
| C-TEST-5 | 禁止 `skip: true` 合入 `main`，除非关联 issue 且在 PR 描述中说明。 |
| C-TEST-6 | Golden 测试使用 Flutter 内置 `matchesGoldenFile`；**禁止使用已停止维护的 `golden_toolkit`**（见 ADR-0009）。 |
| C-TEST-7 | CI 必须依次通过 `AGENTS.md` §4 的全部命令；缺任一命令视为未通过。 |

---

## 9. 依赖与代码生成

| ID | 约束 |
|---|---|
| C-DEP-1 | 新增依赖必须经评审；禁止引入体积过大或维护不活跃的包。 |
| C-DEP-2 | 版本必须使用 `^` 或精确版本；**禁止 `any`**。 |
| C-DEP-3 | 代码生成工具固定为 `freezed`、`json_serializable`、`riverpod_generator`、`drift_dev`。 |
| C-DEP-4 | 生成命令固定为 `dart run build_runner build`（`--delete-conflicting-outputs` 已在 `build_runner 2.16.2` 中移除并被忽略，见 ADR-0013 §6）。 |
| C-DEP-5 | 生成文件（`*.g.dart`、`*.freezed.dart`、`*.gr.dart`）禁止手改；冲突必须重新生成。 |
| C-DEP-6 | `pubspec.yaml` 是依赖的唯一来源；`docs/dev/tech-stack.md` 的说明表必须与其同步，禁止只在其中一处新增依赖。 |
| C-DEP-7 | 新增依赖必须与 GPL-3.0 兼容：宽松许可（MIT / BSD-2 / BSD-3 / Apache-2.0）可用；**MPL-2.0 只按 `tool/scan_licenses.dart` 的白名单放行**（每加一个都要 ADR，ADR-0048 是第一个）；**禁止引入 GPL-2.0-only、无许可证或专有许可的依赖**。核实结果记入 `NOTICE.md` §5。 |

---

## 10. 安全

| ID | 约束 |
|---|---|
| C-SEC-1 | 禁止硬编码 API Key、Token、密码；必须经安全存储或 `--dart-define` 注入。 |
| C-SEC-2 | 所有网络请求必须使用 HTTPS；明文 HTTP 仅在用户显式允许时可用，且必须隔离为独立设置项。 |
| C-SEC-3 | 书源 JS 必须在沙箱中执行，仅暴露白名单 API（C-SRC-3）。 |
| C-SEC-4 | 日志与崩溃上报禁止包含 Cookie、Token、请求头与页面正文。 |
| C-SEC-5 | 导入外部书源 JSON 必须校验结构并限制文件体积；禁止一次性读入超大文件。 |

---

## 11. 性能

| ID | 约束 |
|---|---|
| C-PERF-1 | 禁止在 `build` 中执行重计算。 |
| C-PERF-2 | 长列表必须使用 `ListView.builder` / `SliverList` 懒加载。 |
| C-PERF-3 | 网络图片必须使用 `cached_network_image`。 |
| C-PERF-4 | 预计超过 16ms 的纯计算必须放入 `Isolate` 或 `compute`。 |
| C-PERF-5 | 大文件必须流式解析；禁止一次性加载进内存（受 `C-SEC-5` 约束）。 |
| C-PERF-6 | Drift 查询不得在 UI 线程做无索引全表扫描；列表查询必须分页或带索引。 |

---

## 12. 类型与空安全

| ID | 约束 |
|---|---|
| C-TYPE-1 | 禁止 `dynamic`，必须使用具体类型或 `Object?`；唯一例外是与 JS 引擎交互的桥接边界，且必须在边界处立即收窄类型。 |
| C-TYPE-2 | 禁止 `!` 强制解包；使用 `??`、模式匹配、局部变量提升或显式 null 检查。 |
| C-TYPE-3 | 类型可由上下文明确时禁止使用 `var`（局部变量除外）。 |
| C-TYPE-4 | 值不变时优先 `final` / `const`。 |
| C-TYPE-5 | 集合与 API 返回类型必须显式声明；禁止依赖 `strict-inference` 之外的隐式推断。 |

---

## 13. 注释与文档

| ID | 约束 |
|---|---|
| C-DOC-1 | 所有公共 API 必须包含英文 `///` 文档注释，以单句摘要开头、句号结尾。 |
| C-DOC-2 | 复杂逻辑必须写中文 `//` 注释解释「为什么」。 |
| C-DOC-3 | 引用其他符号必须使用 `[]`。 |
| C-DOC-4 | 禁止提交注释掉的死代码；禁止无理由的 `// ignore:` 豁免。 |

---

## 14. 额外禁令（红线汇总）

| ID | 禁令 |
|---|---|
| C-BAN-1 | 生成未使用的类、方法、变量、import。 |
| C-BAN-2 | 生成 `// TODO` 空实现或占位代码。 |
| C-BAN-3 | 手动修改 `*.g.dart`、`*.freezed.dart`、`*.gr.dart`。 |
| C-BAN-4 | 引入 `pubspec.yaml` 中未声明的依赖。 |
| C-BAN-5 | 在 `presentation` 层直接 import `data` 层。 |
| C-BAN-6 | 使用 `print()` 代替日志。 |
| C-BAN-7 | 使用 `dynamic`（JS 桥接边界除外）。 |
| C-BAN-8 | 使用 `!` 强制解包。 |
| C-BAN-9 | 跨 `await` 使用 `BuildContext` 不检查 `mounted`。 |
| C-BAN-10 | 硬编码颜色、尺寸、用户可见字符串。 |
| C-BAN-11 | 硬编码 API Key、Token。 |
| C-BAN-12 | 使用明文 HTTP（除非用户显式允许）。 |
| C-BAN-13 | 在 `build` 中执行重计算。 |
| C-BAN-14 | 一次性把大文件加载到内存。 |
| C-BAN-15 | 忽略 `flutter analyze` 警告（含 `analysis_options.yaml` 顶层 `plugins:` 中 riverpod_lint 的规则）。 |

---

## 15. AI 自查清单（全项目唯一副本）

生成或修改代码后，必须逐项确认；任何一项未满足，必须先修正再输出。

- [ ] 已阅读 `AGENTS.md`、`docs/dev/naming.md`、`docs/dev/constraints.md` 及任务相关专题文档？
- [ ] 文件 / 目录 / 类 / 方法 / 变量命名符合 `naming.md`（含 ARB key 与 ADR 文件名）？
- [ ] 遵循分层架构，无反向依赖，未在 `presentation` import `data`（C-ARCH-1）？
- [ ] 通用能力放入 `core/`，未跨 feature import 内部文件（C-ARCH-2）？
- [ ] 状态管理为 Riverpod 且 Provider 全部由 `@riverpod` 生成（C-STATE-1/2）？
- [ ] 失败路径返回 `ParseResult`，未裸 `catch`，未吞异常（C-ERR-1/2/3）？
- [ ] 未使用 `print`；日志未泄露 Cookie / Token / 正文（C-ERR-5、C-SEC-4）？
- [ ] 跨 `await` 使用 `context` 前检查了 `mounted`（C-ERR-4）？
- [ ] 网络请求经 `core/network/HttpClient`，未直接 import `dio`/`http`（C-NET-1）？
- [ ] 编码经 `betto_charset_detector` 检测；缓存带 TTL 与稳定缓存键（C-NET-3/6）？
- [ ] 书源解析纯 Dart；JS 在独立 Isolate；不支持规则返回 `unsupportedRule`（C-SRC-1/2/4）？
- [ ] 主题令牌取自 `Theme.of(context).m3e`，无硬编码颜色/尺寸/字符串（C-UI-1/5）？
- [ ] 平台差异代码位于 `core/platform/`，UI 未直接判断平台（C-PLT-1）？
- [ ] 有对应的单元测试 / Widget 测试，覆盖率满足 C-TEST-1（含「`lib/**` 下不得出现未测量源文件」，ADR-0019）？
- [ ] 使用 `freezed` / `json_serializable`，未手改生成文件（C-DEP-3/5）？
- [ ] 无硬编码密钥、无明文 HTTP、无性能陷阱（C-SEC-1/2、C-PERF-1..5）？
- [ ] 无未使用代码、无 TODO 占位、未修改生成文件（C-BAN-1/2/3）？
- [ ] 公共 API 的 `///` 宣称的行为与实现一致（必填字段、规则未匹配时的回退值、「跳过条目」还是「整次失败」）？
- [ ] 已通过 `AGENTS.md` §4 的全部门禁命令（`flutter analyze` 已包含 analyzer 插件规则）？
- [ ] 若偏离了某条约束，已在 PR 描述中说明原因并获得用户确认？

---

## 16. AI 提示词模板（全项目唯一副本）

```
请严格遵循项目根目录 AGENTS.md，以及 docs/dev/naming.md、docs/dev/constraints.md。
若任务涉及专题，追加阅读：docs/dev/architecture.md、docs/dev/book-source.md、
docs/dev/testing.md、docs/dev/platform.md、docs/dev/tech-stack.md。

生成代码时：
- 分层：presentation → domain → data，禁止反向依赖。
- 状态管理：Riverpod 唯一；Provider 必须用 @riverpod 代码生成；Notifier 命名 XxxNotifier。
- 错误处理：返回 ParseResult<T>；禁止裸 catch；禁止 print；跨 await 检查 mounted。
- 网络：通过 core/network/HttpClient；禁止直接使用 dio/http；编码用 betto_charset_detector。
- 书源：纯 Dart 解析；JS 在独立 Isolate；使用 cascadia、json_path。
- 主题：令牌取自 Theme.of(context).m3e（m3e_design）；禁止硬编码颜色/尺寸/字符串。
- 平台：差异代码只放 core/platform/，经抽象接口注入；Windows/iOS 提供 fallback。
- 持久化：结构化数据用 Drift，轻量开关用 shared_preferences。
- 测试：覆盖率门禁见 docs/dev/testing.md §2；Golden 用内置 matchesGoldenFile。
- 依赖：使用 freezed + json_serializable；生成文件不手改；新依赖必须 GPL-3.0 兼容。
- 安全：禁止硬编码密钥；强制 HTTPS；JS 沙箱。
- 性能：重计算放入 Isolate；列表懒加载。

**禁止：** 未使用代码、TODO 占位、dynamic、! 强制解包、硬编码字符串/颜色、
未声明的依赖。

必须通过：AGENTS.md §4 声明的全部门禁命令（清单唯一出处；本文档不复述）。
```
