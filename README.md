# flutter_reader

一个基于 **Flutter** 的阅读 App，采用 **Material 3 Expressive** 设计语言，
兼容 **Legado 书源规则**（纯 Dart 实现解析引擎）。

---

## 特性

| 能力 | 说明 |
|---|---|
| MD3E 设计 | 设计令牌统一由 `m3e_design` 提供，禁止硬编码颜色/尺寸 |
| 动态取色 | Android 12+ 跟随壁纸取色；Windows / iOS 使用种子色 fallback |
| 预测性返回 | Android 13+ 支持侧滑返回预览动画 |
| 多平台 | Android、Windows、iOS |
| 书源解析 | 纯 Dart 规则引擎，`@js:` 规则在独立 Isolate 中执行 |
| 本地存储 | Drift(SQLite) 存结构化数据，`shared_preferences` 存轻量开关 |
| 国际化 | 英文 / 中文，文案统一来自 ARB |

---

## 快速开始

### 环境要求

Flutter 与 Dart 的版本基线见 [`docs/dev/tech-stack.md`](docs/dev/tech-stack.md) §1。
其他工具链要求见 [`CONTRIBUTING.md`](CONTRIBUTING.md) §3.1。

### 构建与运行

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs

flutter run -d windows     # 或 -d android / -d ios
```

### 门禁命令

```bash
dart format --set-exit-if-changed .
flutter analyze
dart run custom_lint
flutter test --coverage
dart run tool/check_coverage.dart
```

完整门禁定义见 [`AGENTS.md`](AGENTS.md) §4。**注意：** `flutter analyze`
不会执行 `custom_lint` 插件规则，两者必须都跑。

---

## 文档地图

| 文档 | 内容 |
|---|---|
| [`docs/README.md`](docs/README.md) | **全部文档路径的唯一权威索引**（从这里开始） |
| [`AGENTS.md`](AGENTS.md) | AI 代理入口：工作流、门禁、文档地图 |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | 贡献流程：分支、Commit、PR、Review |
| [`docs/dev/naming.md`](docs/dev/naming.md) | 命名规范 |
| [`docs/dev/constraints.md`](docs/dev/constraints.md) | 约束条目（带稳定 ID `C-*`） |
| [`docs/dev/architecture.md`](docs/dev/architecture.md) | 目录结构、分层、DI、路由、错误契约 |
| [`docs/dev/book-source.md`](docs/dev/book-source.md) | Legado 书源规格与支持矩阵 |
| [`docs/dev/testing.md`](docs/dev/testing.md) | 测试分层、覆盖率门禁、CI |
| [`docs/dev/platform.md`](docs/dev/platform.md) | 平台基线与降级策略 |
| [`docs/dev/tech-stack.md`](docs/dev/tech-stack.md) | 依赖清单与版本基线 |
| [`docs/dev/adr/`](docs/dev/adr/README.md) | 决策记录（含未决事项） |

---

## 项目状态

| 项 | 状态 |
|---|---|
| 文档规范体系 | v2.0，已按单一来源（SSOT）重构 |
| 应用代码 | 尚未实现（当前仓库以规范与配置为主） |
| 书源规格 | v0.1 提案，尚需真实书源回归验证 |
| 覆盖率门禁 | 已可执行（`tool/check_coverage.dart`） |
| 许可证 | **待裁决**，见 [`docs/dev/adr/0007-license.md`](docs/dev/adr/0007-license.md) |

---

## 免责声明

本项目是独立的阅读客户端实现，**不提供、不托管、不传播任何书源或阅读内容**。
用户自行导入的第三方书源及其内容由用户自行承担合规责任。
本项目与 Legado 项目及其作者无隶属关系。
