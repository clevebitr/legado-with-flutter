# CONTRIBUTING.md

感谢你愿意为这个 Flutter 阅读 App 项目做出贡献！

本文档**只描述贡献流程**。命名规范、代码风格、注释风格、架构约束、状态管理、错误处理、网络与书源解析规则、UI 与平台适配、测试、安全、性能等详细规范，已拆分至以下文档。请在贡献前务必阅读：

| 文档 | 内容 |
|---|---|
| [AGENT.md](./AGENT.md) | AI 代理入口、核心约束速查、AI 自查清单 |
| [docs/NAMING_CONVENTIONS.md](./docs/NAMING_CONVENTIONS.md) | 文件、类、方法、变量、API 命名规范 |
| [docs/ADDITIONAL_CONSTRAINTS.md](./docs/ADDITIONAL_CONSTRAINTS.md) | 架构、状态、错误、网络、书源、UI、平台、测试、安全、性能约束 |
| [analysis_options.yaml](./analysis_options.yaml) | 静态分析与 lint 规则 |

> **AI 编码代理注意：** 生成或修改代码前，必须先阅读 [AGENT.md](./AGENT.md)，并严格遵循上述文档中的规范。

---

## 目录

1. [开始之前](#1-开始之前)
2. [报告问题](#2-报告问题)
3. [开发环境设置](#3-开发环境设置)
4. [分支与 Commit 规范](#4-分支与-commit-规范)
5. [Pull Request 流程](#5-pull-request-流程)
6. [代码规范入口](#6-代码规范入口)
7. [文档与国际化](#7-文档与国际化)
8. [许可证](#8-许可证)

---

## 1. 开始之前

### 1.1 行为准则

- 尊重所有贡献者，保持友善、专业的沟通。
- 建设性地提出意见，解释原因并提供替代方案。
- 禁止任何形式的歧视、骚扰或攻击性言论。

### 1.2 必读文档

请按顺序阅读：

1. [AGENT.md](./AGENT.md)
2. [docs/NAMING_CONVENTIONS.md](./docs/NAMING_CONVENTIONS.md)
3. [docs/ADDITIONAL_CONSTRAINTS.md](./docs/ADDITIONAL_CONSTRAINTS.md)

---

## 2. 报告问题

### 2.1 Bug 报告

请使用 [.github/ISSUE_TEMPLATE/bug_report.yml](./.github/ISSUE_TEMPLATE/bug_report.yml)，并提供：

- 清晰的标题与描述
- 复现步骤
- 预期行为与实际行为
- 环境信息（平台、版本、设备）
- 相关日志或截图

### 2.2 功能请求

请使用 [.github/ISSUE_TEMPLATE/feature_request.yml](./.github/ISSUE_TEMPLATE/feature_request.yml)，说明：

- 功能描述与使用场景
- 期望的 API 或 UI 行为
- 是否愿意自行实现

### 2.3 安全漏洞

**禁止**在公开 Issue 中披露安全漏洞。请发送邮件至项目维护者邮箱（见 [README.md](./README.md)），我们将尽快处理。

---

## 3. 开发环境设置

### 3.1 环境要求

| 工具 | 版本 |
|---|---|
| Flutter | 最新稳定版 |
| Dart | 随 Flutter 附带 |
| Android Studio / VS Code | 最新版 |
| Xcode（macOS） | 最新版 |

### 3.2 初始化

```bash
# 克隆仓库
git clone https://github.com/your-org/your-repo.git
cd your-repo

# 安装依赖
flutter pub get

# 生成代码（freezed / json_serializable / riverpod_generator）
dart run build_runner build --delete-conflicting-outputs
```

### 3.3 运行检查

```bash
flutter analyze                          # 静态分析，必须零警告
dart format --set-exit-if-changed .      # 格式检查
flutter test                             # 运行测试
```

---

## 4. 分支与 Commit 规范

### 4.1 分支策略

采用 **Feature Branching** 模式，禁止直接向 `main` 推送代码。

| 分支类型 | 命名格式 | 示例 |
|---|---|---|
| 功能分支 | `feat/短描述` | `feat/book-source-parser` |
| 修复分支 | `fix/短描述` | `fix/encoding-detection` |
| 文档分支 | `docs/短描述` | `docs/contributing-guide` |
| 重构分支 | `refactor/短描述` | `refactor/theme-system` |

分支从 `main` 创建，PR 合并后立即删除。

### 4.2 Commit 规范

所有 Commit 必须使用 **Conventional Commits** 格式：

```
type: 简短描述（现在时，小写开头，不加句号）
```

允许的 `type`：

| type | 用途 |
|---|---|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档更新 |
| `refactor` | 代码重构（不改变功能） |
| `test` | 测试相关 |
| `chore` | 构建/工具链维护 |
| `perf` | 性能优化 |

**示例：**

```
feat: implement CSS selector parsing for book sources
fix: resolve UTF-8 BOM detection failure on Windows
refactor: extract network layer into separate service
```

---

## 5. Pull Request 流程

### 5.1 PR 创建规则

| 规则 | 要求 |
|---|---|
| **PR 标题** | 必须使用 Conventional Commits 格式 |
| **PR 大小** | 理想情况下 **< 400 行**变更；大型功能拆分为多个 PR |
| **聚焦性** | 每个 PR **只做一件事**；重构与功能分开提交 |
| **关联 Issue** | 使用 `Closes #123` 关联 |
| **CI 通过** | 请求 Review 前所有检查必须通过（lint、test、build） |
| **指定 Reviewer** | 必须请求至少 1 名特定 Reviewer；不能自行 Approve 或 Merge |

### 5.2 PR 描述模板

请使用 [.github/PULL_REQUEST_TEMPLATE.md](./.github/PULL_REQUEST_TEMPLATE.md)。

### 5.3 合并策略

统一使用 **Squash and Merge**，将 PR 中的多个 Commit 压缩为一个干净的 Commit 合入 `main`。

### 5.4 Reviewer 要求

| 维度 | 要求 |
|---|---|
| **批准条件** | 至少 1 名其他成员 Approve |
| **PR 作者** | 不能自行 Approve 或 Merge |
| **Review 语气** | 建设性、具体、解释原因、提供替代方案 |
| **关注优先级** | 正确性 > 可维护性 > 性能 |

---

## 6. 代码规范入口

本项目所有代码必须遵循以下文档。**请勿在本文档中查找命名或架构细节，直接跳转至对应文档。**

| 主题 | 文档 |
|---|---|
| 命名规范（文件、类、方法、变量、API） | [docs/NAMING_CONVENTIONS.md](./docs/NAMING_CONVENTIONS.md) |
| 架构、状态管理、错误处理、网络、书源解析、UI、平台适配、测试、安全、性能 | [docs/ADDITIONAL_CONSTRAINTS.md](./docs/ADDITIONAL_CONSTRAINTS.md) |
| AI 代理工作流程、核心约束速查、AI 自查清单 | [AGENT.md](./AGENT.md) |
| 静态分析与 lint 规则 | [analysis_options.yaml](./analysis_options.yaml) |

提交前必须运行：

```bash
flutter analyze
dart format --set-exit-if-changed .
flutter test
```

---

## 7. 文档与国际化

### 7.1 文档更新

- 任何 API 变更必须同步更新 `docs/` 下的相关文档。
- 新增功能必须提供使用示例。
- 破坏性变更必须在 [CHANGELOG.md](./CHANGELOG.md) 中记录。

### 7.2 语言约定

| 场景 | 语言 |
|---|---|
| 文档注释（`///`） | 英文 |
| 普通注释（`//`） | 中文 |
| Commit Message | 英文 |
| PR 描述 | 中英均可（优先中文，关键术语用英文） |
| CHANGELOG | 英文 |

### 7.3 国际化

- 所有用户可见字符串必须放入 `l10n/` 的 ARB 文件。
- 禁止在代码中硬编码中英文字符串。
- 新增字符串必须同时提供 `zh` 和 `en` 翻译。

---

## 8. 许可证

本项目采用 [MIT License](./LICENSE)。贡献代码即表示你同意在相同许可证下发布你的贡献。

---

**感谢你的贡献！**  
如有任何疑问，请通过 GitHub Issue 或 Telegram 群组联系维护者。