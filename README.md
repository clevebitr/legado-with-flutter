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

### 环境准备（只需一次）

```bash
flutter pub get
dart run build_runner build
flutter gen-l10n
```

> 平台工程（`android/`、`ios/`、`windows/`）、`lib/main.dart` 与 `test/` 已生成并纳入
> 版本控制，**不需要**再执行 `flutter create`。
>
> **Windows 桌面开发需先开启「开发者模式」**（管理员），否则 `flutter run -d windows` 会因
> 插件符号链接失败而直接退出；原因与开启方式见 [`docs/dev/platform.md`](docs/dev/platform.md) §1.2。

### 运行

```bash
flutter run -d windows     # 或 -d android / -d ios
```

### 门禁命令

完整且唯一的门禁命令清单见 [`AGENTS.md`](AGENTS.md) §4（本文档不复述，见 ADR-0013 §5）；
执行顺序与 CI 特有步骤见 [`docs/dev/testing.md`](docs/dev/testing.md) §7。

---

## 文档入口

**全部文档路径与职责的唯一权威索引是 [`docs/README.md`](docs/README.md)**（从这里开始）。
常用入口：

| 我想… | 读 |
|---|---|
| 开始开发 / 看路线与验收 | [`docs/dev/roadmap.md`](docs/dev/roadmap.md) |
| 提 PR / 分支 / Commit | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| 查约束与命名 | [`docs/dev/constraints.md`](docs/dev/constraints.md)、[`docs/dev/naming.md`](docs/dev/naming.md) |
| 查依赖、许可证、免责声明 | [`docs/dev/tech-stack.md`](docs/dev/tech-stack.md)、[`NOTICE.md`](NOTICE.md) |
| 看决策理由 | [`docs/dev/adr/`](docs/dev/adr/README.md) |

---

## 项目状态

| 项 | 状态 |
|---|---|
| 文档规范体系 | v2.0+，已按单一来源（SSOT）与事实级归属（`docs/README.md` §2.1）重构 |
| 实现进度 | 路线与验收：[`docs/dev/roadmap.md`](docs/dev/roadmap.md) §3.1 阶段状态表；里程碑级（当前 / goal / 断点）：[`PLAN.md`](PLAN.md) |
| 书源规格 | 对标原版阅读（Legado）；语法行状态以 [`docs/dev/book-source.md`](docs/dev/book-source.md) §3 矩阵为准 |
| 覆盖率门禁 | 已可执行（`tool/check_coverage.dart`）；阈值与判定规则见 [`docs/dev/testing.md`](docs/dev/testing.md) §2 |
| 许可证 | **GNU GPL-3.0**（version 3 only），见 [`LICENSE`](LICENSE) 与 [`NOTICE.md`](NOTICE.md) |
| 依赖许可核实 | 已完成；包数与分类基线见 [`NOTICE.md`](NOTICE.md) §5 |

---

## 许可证与免责声明

本项目采用 **GNU GPL-3.0**（version 3 only）。分发本程序的任何形式（包括二进制与应用商店包）
都必须同时提供对应源代码，并保留版权与许可证声明。**版权、与上游 Legado 的关系、免责声明、
GPL 合规义务清单与第三方依赖许可清单的唯一正文在 [`NOTICE.md`](NOTICE.md)**（本文档不复述）。
