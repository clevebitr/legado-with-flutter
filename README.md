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

### 首次初始化

仓库当前**只包含规范与配置**，尚无平台工程目录，因此必须先脚手架：

```bash
# 1) 生成 Android / iOS / Windows 平台工程与 app 骨架
#    已存在的文件不会被覆盖（仍在第 2 步核实）
flutter create --platforms=android,ios,windows .

# 2) 确认配置文件未被模板覆盖（应当无任何 diff）
git diff --stat -- pubspec.yaml analysis_options.yaml l10n.yaml .gitignore

# 3) 安装依赖并生成代码
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 4) 生成国际化代码（引用 AppLocalizations 前必须执行）
flutter gen-l10n
```

> 第 2 步如果出现 diff，跑 `git checkout -- pubspec.yaml analysis_options.yaml l10n.yaml .gitignore` 恢复。
>
> `flutter create` 还会写入模板 `lib/main.dart` 与 `test/widget_test.dart`：
前者需替换为真实入口，后者需删除或替换，否则本地与 CI 测试会失败。

### 运行

```bash
flutter run -d windows     # 或 -d android / -d ios
```

### 门禁命令

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart
```

完整门禁定义见 [`AGENTS.md`](AGENTS.md) §4。`riverpod_lint` 插件规则由
`flutter analyze` 执行（`analysis_options.yaml` 的 `analyzer.plugins`）。

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
| 书源规格 | v1.0，对标原版阅读（Legado）；语法行状态待真实书源回归逐行确认 |
| 覆盖率门禁 | 已可执行（`tool/check_coverage.dart`） |
| 许可证 | **GNU GPL-3.0**，见 [`LICENSE`](LICENSE) 与 [`NOTICE.md`](NOTICE.md) |
| 依赖许可核实 | 部分依赖仍为「待核实」，见 [`NOTICE.md`](NOTICE.md) §5 |

---

## 许可证

本项目采用 **GNU GPL-3.0**（version 3 only）。完整文本见 [`LICENSE`](LICENSE)。

分发本程序的任何形式（包括二进制与应用商店包）都必须同时提供对应源代码，
并保留版权与许可证声明；应用内「关于 → 法律声明」提供许可证全文入口。
详见 [`NOTICE.md`](NOTICE.md) §4 的合规义务清单。

---

## 免责声明

本项目是独立的阅读客户端实现，**不提供、不托管、不传播、不索引任何书源或阅读内容**。
用户自行导入的第三方书源及其内容由用户自行承担合规责任。
本项目不绕过任何付费、登录或版权保护机制。
本项目与 Legado 项目及其作者**无隶属关系**，也未经其背书。

软件按“现状”提供，**不提供任何担保**（GPL-3.0 §15、§16）。
