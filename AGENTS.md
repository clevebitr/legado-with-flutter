# AGENT.md — AI 代理入口与规则引导

> **文件位置：** 项目根目录 `AGENT.md`  
> **用途：** 引导 AI 编码代理（如 Claude Code、Cursor、GitHub Copilot、Codex 等）在处理本项目时，首先阅读并遵循项目的全部开发规范。  
> **强制要求：** 任何 AI 代理在本项目中生成或修改代码前，必须先阅读本文件及其引用的文档。

---

## 1. 项目简介

本项目是一个基于 **Flutter** 的阅读 App，核心特性包括：

- **Material Design 3 Expressive (MD3E)** 设计风格
- **Android 底层高级 API**：预测性返回、壁纸种子色（Monet）
- **多平台支持**：Android、Windows、iOS
- **Dart 重写书源解析**：兼容 Legado 书源规则，纯 Dart 实现解析引擎
- **开源协议与免责声明**：遵循 Legado 社区规范

---

## 2. 必读文档索引

AI 代理在开始任何任务前，必须按顺序阅读以下文档：

| 序号 | 文档路径 | 内容 | 优先级 |
|---|---|---|---|
| 1 | `AGENT.md`（本文件） | AI 工作流程、核心约束速查 | 必读 |
| 2 | `docs/dev/NAMING_CONVENTIONS.md` | 命名规范（文件、类、方法、变量、API） | 必读 |
| 3 | `docs/dev/ADDITIONAL_CONSTRAINTS.md` | 补充约束（架构、状态、错误、网络、书源、UI、平台、测试、安全、性能） | 必读 |
| 4 | `CONTRIBUTING.md` | 贡献指南（PR 规则、Commit 规范、Review 要求） | 参考 |
| 5 | `analysis_options.yaml` | 静态分析与 lint 规则 | 参考 |

**如果上述文档不存在，AI 代理必须提示用户创建，并拒绝生成违反规范的代码。**

---

## 3. AI 工作流程

每次接到任务时，AI 代理必须按以下步骤执行：

### 步骤 1：阅读规范
- 确认已阅读 `AGENT.md`、`docs/dev/NAMING_CONVENTIONS.md`、`docs/dev/ADDITIONAL_CONSTRAINTS.md`。
- 若任务涉及特定模块（如书源解析、主题、平台适配），需额外阅读对应模块的设计文档（如有）。

### 步骤 2：分析任务
- 判断任务属于哪一层（`presentation` / `domain` / `data` / `core`）。
- 判断是否需要新增依赖、修改生成文件、跨平台适配。
- 若任务不明确，**必须向用户提问**，禁止猜测。

### 步骤 3：生成代码
- 严格遵循命名规范与补充约束。
- 所有公共 API 必须包含英文 `///` 文档注释。
- 复杂逻辑必须添加中文 `//` 注释解释“为什么”。
- 使用 `freezed` + `json_serializable` 生成模型。
- 网络请求必须通过 `core/network/HttpClient`。
- 书源解析必须纯 Dart，JS 在独立 Isolate 中执行。
- 主题 Token 必须从 `M3ETheme` 获取，禁止硬编码。

### 步骤 4：自查
- 生成代码后，逐项核对第 6 节「AI 自查清单」。
- 确保代码通过 `flutter analyze` 零警告、`dart format` 格式化。
- 若无法满足某条规则，必须明确说明原因并请求用户确认。

### 步骤 5：输出
- 提供完整的代码变更，包括必要的测试。
- 说明变更内容、影响范围、测试方式。
- 若涉及 PR，按 `CONTRIBUTING.md` 格式生成 PR 描述。

---

## 4. 核心约束速查

以下为最高频、最关键的约束，详细规则见对应文档。

| 类别 | 核心约束 | 来源 |
|---|---|---|
| **命名** | 类 `UpperCamelCase`，方法 `lowerCamelCase` 动词开头，变量 `lowerCamelCase` 名词，常量 `lowerCamelCase`，私有 `_` 前缀 | 命名规范 |
| **文件** | 目录/文件 `snake_case`，测试文件 `*_test.dart` | 命名规范 |
| **分层** | `presentation` → `domain` → `data`，禁止反向依赖 | 补充约束 §1 |
| **状态** | 统一 Riverpod，ViewModel 命名 `XxxViewModel` | 补充约束 §2 |
| **错误** | 返回 `ParseResult<T>`，禁止裸 `catch`、禁止 `print` | 补充约束 §3 |
| **网络** | 通过 `core/network/HttpClient`，禁止直接 `http`/`dio` | 补充约束 §4 |
| **书源** | 纯 Dart 解析，JS 在 Isolate，使用 `cascadia`/`json_path`/`betto_charset_detector` | 补充约束 §5 |
| **主题** | 从 `M3ETheme` 获取 Token，禁止硬编码颜色/尺寸 | 补充约束 §6 |
| **平台** | Android 动态取色/预测性返回通过抽象接口，Windows/iOS 提供 fallback | 补充约束 §7 |
| **测试** | `core/` 和 `domain/` 100% 覆盖，CI 必须通过 | 补充约束 §8 |
| **依赖** | 使用 `freezed` + `json_serializable`，生成文件不手动修改 | 补充约束 §9 |
| **安全** | 禁止硬编码密钥，强制 HTTPS，JS 沙箱 | 补充约束 §10 |
| **性能** | 重计算放入 `Isolate`，列表懒加载 | 补充约束 §10 |
| **禁止** | 未使用代码、TODO 占位、`dynamic`、`!` 强制解包、跨 `await` 不检查 `mounted` | 补充约束 §11 |

---

## 5. 给 AI 的提示词模板

在向 AI 代理发出指令时，可直接附加以下提示词：

```
请严格遵循项目根目录 AGENT.md 及其引用的 docs/NAMING_CONVENTIONS.md 和 docs/ADDITIONAL_CONSTRAINTS.md。

生成代码时：
- 分层：presentation → domain → data，禁止反向依赖。
- 状态管理：使用 Riverpod，ViewModel 命名 XxxViewModel。
- 错误处理：返回 ParseResult<T>，禁止裸 catch、禁止 print。
- 网络：通过 core/network/HttpClient，禁止直接使用 http/dio。
- 书源：纯 Dart 解析，JS 在 Isolate 中执行，使用 cascadia、json_path、betto_charset_detector。
- 主题：从 M3ETheme 获取 Token，禁止硬编码颜色/尺寸。
- 平台：Android 动态取色/预测性返回通过抽象接口，Windows/iOS 提供 fallback。
- 测试：core/ 和 domain/ 必须 100% 覆盖。
- 依赖：使用 freezed + json_serializable，生成文件不手动修改。
- 安全：禁止硬编码密钥，强制 HTTPS，JS 沙箱。
- 性能：重计算放入 Isolate，列表懒加载。

禁止：未使用代码、TODO 占位、dynamic、! 强制解包、跨 await 使用 context 不检查 mounted。
必须通过 flutter analyze 零警告和 dart format。
```

---

## 6. AI 自查清单

每次生成或修改代码后，AI 必须逐项确认：

- [ ] 是否已阅读 `AGENT.md`、`docs/dev/NAMING_CONVENTIONS.md`、`docs/dev/ADDITIONAL_CONSTRAINTS.md`？
- [ ] 文件/目录/类/方法/变量命名是否符合规范？
- [ ] 是否遵循分层架构，无跨层依赖？
- [ ] 是否使用统一的状态管理方案（Riverpod）？
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

**若任何一项未满足，AI 必须修正后再输出。**

---

## 7. 禁止行为清单

AI 代理在本项目中 **严格禁止** 以下行为：

| 编号 | 禁止行为 |
|---|---|
| 1 | 生成未使用的类、方法、变量、import |
| 2 | 生成 `// TODO` 空实现或占位代码 |
| 3 | 手动修改 `*.g.dart`、`*.freezed.dart` 等生成文件 |
| 4 | 引入 `pubspec.yaml` 中未声明的依赖 |
| 5 | 在 `presentation` 层直接 import `data` 层 |
| 6 | 使用 `print()` 代替日志 |
| 7 | 使用 `dynamic`（JS 交互除外） |
| 8 | 使用 `!` 强制解包 |
| 9 | 跨 `await` 使用 `BuildContext` 不检查 `mounted` |
| 10 | 硬编码颜色、尺寸、字符串 |
| 11 | 硬编码 API Key、Token |
| 12 | 使用 HTTP 明文请求（除非用户显式允许） |
| 13 | 在 `build` 中执行重计算 |
| 14 | 一次性加载大文件到内存 |
| 15 | 忽略 `flutter analyze` 警告 |

---

## 8. 文档维护

- 本文件由项目核心团队维护。
- 任何规范变更必须同步更新 `AGENT.md`、`docs/dev/NAMING_CONVENTIONS.md`、`docs/dev/ADDITIONAL_CONSTRAINTS.md`。
- AI 代理若发现规范冲突或缺失，必须向用户报告，不得自行假设。

---

**文档版本：** v1.0  
**最后更新：** 2026-10-10  
**适用项目：** Flutter 阅读 App（MD3E、多平台、Dart 书源解析）