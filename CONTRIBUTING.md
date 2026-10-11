# CONTRIBUTING.md

感谢你愿意为这个 Flutter 阅读 App 项目做出贡献！

本文档**只描述贡献流程**。命名规范、架构约束、状态管理、错误处理、网络与书源解析、
UI 与平台适配、测试、安全、性能等详细规范，已拆分至 `docs/dev/`。
**请勿在本文档中查找规范细节**，直接跳转到 §6 的入口表。

> **AI 编码代理注意：** 生成或修改代码前必须先阅读 [`AGENTS.md`](./AGENTS.md)，
> 并按其中的文档地图读取任务相关规范。

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

按顺序阅读：

1. [`AGENTS.md`](./AGENTS.md) —— AI 代理入口、工作流、合并门禁、文档地图
2. [`docs/README.md`](./docs/README.md) —— 全部文档路径的**唯一权威**索引
3. [`docs/dev/constraints.md`](./docs/dev/constraints.md) —— 约束条目（带稳定 ID）

### 1.3 决策记录

任何与既有规范冲突的改动，都必须先在 [`docs/dev/adr/`](./docs/dev/adr/README.md) 新增一条 ADR，
再修改代码或规范。已生效的决策不允许在 PR 中静默推翻。

---

## 2. 报告问题

### 2.1 Bug 报告

请使用 [`.github/ISSUE_TEMPLATE/bug_report.yml`](./.github/ISSUE_TEMPLATE/bug_report.yml)，并提供：

- 清晰的标题与描述
- 复现步骤
- 预期行为与实际行为
- 环境信息（平台、版本、设备）
- 相关日志或截图

### 2.2 功能请求

请使用 [`.github/ISSUE_TEMPLATE/feature_request.yml`](./.github/ISSUE_TEMPLATE/feature_request.yml)，说明：

- 功能描述与使用场景
- 期望的 API 或 UI 行为
- 是否愿意自行实现

### 2.3 安全漏洞

**禁止**在公开 Issue 中披露安全漏洞。请通过仓库 **Security → Report a vulnerability**
（GitHub Security Advisory）私密报告，维护者会在确认后与你协作修复与披露。

涉及书源 JS 沙箱逃逸、凭据泄露、明文传输的问题优先级最高。

---

## 3. 开发环境设置

### 3.1 环境要求

Flutter / Dart 的**版本基线以 [`docs/dev/tech-stack.md`](./docs/dev/tech-stack.md) §1 为准**，
本文档不复述具体版本号（见 ADR-0013）。此外需要：

- Android Studio 或 VS Code（含 Dart / Flutter 插件）
- Xcode（仅 macOS，用于 iOS 构建）
- Visual Studio 2022（含「使用 C++ 的桌面开发」工作负载，用于 Windows 构建）

### 3.2 初始化

```bash
git clone <repo-url>
cd <repo-dir>

flutter pub get
dart run build_runner build
flutter gen-l10n
```

> 平台工程目录与 `lib/main.dart` 已在版本控制中，不需要 `flutter create`。
> **Windows 桌面开发需先开启「开发者模式」**（管理员），否则 `flutter run -d windows`
> 会因插件符号链接失败而直接退出，见 `docs/dev/platform.md` §1.2。
> 首个 PR 必须包含至少一个真实测试，CI 才会变绿，见 `docs/dev/testing.md` §2。

### 3.3 运行检查

门禁命令以 [`AGENTS.md`](./AGENTS.md) §4 为准。
`riverpod_lint` 插件规则由 `flutter analyze` 执行（`analysis_options.yaml` 顶层 `plugins:`，ADR-0010），
不需要额外的 lint 运行器。

---

## 4. 分支与 Commit 规范

### 4.1 分支策略

采用 **Feature Branching**，禁止直接向 `main` 推送代码。

| 分支类型 | 命名格式 | 示例 |
|---|---|---|
| 功能 | `feat/短描述` | `feat/book-source-parser` |
| 修复 | `fix/短描述` | `fix/encoding-detection` |
| 文档 | `docs/短描述` | `docs/contributing-guide` |
| 重构 | `refactor/短描述` | `refactor/theme-system` |

分支从 `main` 创建，PR 合并后立即删除。

> **多写入者约定（2026-10-11 补，起因见回执 B1）：** 同一工作树内**禁止**在未声明的情况下
> 切换分支或刷新 HEAD（`git switch` / `git checkout` / `git pull` / `git reset`）——它会从其他
> 写入者脚下换走 HEAD，使其提交落到错误分支（本仓已发生过一次：2.2 的提交落在 `main` 上）。
> 需要并行开发时，每位写入者使用**独立的 `git worktree` 或独立 clone**；确需在同一工作树内
> 切换时，必须先声明并确认无人正在提交。

### 4.2 Commit 规范

所有 Commit 必须使用 **Conventional Commits**：

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

Commit message 使用**英文**（见 [`docs/README.md`](./docs/README.md) §7）。

```text
feat: implement css selector parsing for book sources
fix: resolve utf-8 bom detection failure on windows
refactor: extract network layer into separate service
```

---

## 5. Pull Request 流程

### 5.1 PR 创建规则

| 规则 | 要求 |
|---|---|
| 标题 | Conventional Commits 格式 |
| 大小 | 理想情况 **< 400 行**变更；大型功能拆分 |
| 聚焦性 | 每个 PR 只做一件事；重构与功能分开 |
| 关联 Issue | 使用 `Closes #123` |
| 门禁 | 请求 Review 前必须通过 `AGENTS.md` §4 全部命令 |
| ADR | 若改变了既有决策，必须附带新增的 ADR |
| Reviewer | **存在第二名维护者时**至少指定 1 名 Reviewer；作者不能自行 Approve 或 Merge（单人维护期见 §5.4 的适用条件） |

### 5.2 PR 描述模板

使用 [`.github/PULL_REQUEST_TEMPLATE.md`](./.github/PULL_REQUEST_TEMPLATE.md)。

### 5.3 合并策略

统一使用 **Squash and Merge**。

### 5.4 Reviewer 要求

| 维度 | 要求 |
|---|---|
| 批准条件 | **存在第二名维护者时**，至少 1 名其他成员 Approve；单人维护期不适用（见下方适用条件） |
| PR 作者 | 不能自行 Approve 或 Merge |
| Review 语气 | 建设性、具体、解释原因、提供替代方案 |
| 关注优先级 | 正确性 > 可维护性 > 性能 > 风格 |

Reviewer 必须检查 PR 是否满足自查清单
（[`docs/dev/constraints.md`](./docs/dev/constraints.md) §15），
而不是只依赖 CI 结果。

> **「他人 Approve」的适用条件（2026-10-11）：** §5.1 / §5.4 的「至少 1 名其他成员 Approve」
> 以**存在第二名维护者**为前提，它是条件规则而不是绝对要求。GitHub 禁止自我批准，单人维护期
> 若强制要求 1 个批准，会让**每一个 PR 永久无法合并**。因此 `main` 的保护规则集当前把
> `required_approving_review_count` 设为 `0`；其余各项（必须走 PR、CI `verify` 必须通过且分支
> 须与 `main` 同步、只允许 Squash、禁止强推与删除、无 bypass 名单——**包括仓库所有者本人**）
> 一律照常生效。
>
> **触发条件（不得省略）：** 一旦有第二名维护者取得 write 权限，**必须立即**把该值改为 `1`，
> 否则本节形同虚设。改动方式：`gh api repos/<owner>/<repo>/rulesets` 取 `main` 规则集的 `id`，
> GET 该规则集后把 `pull_request.parameters.required_approving_review_count` 改为 `1` 再 PUT 回去
> （该接口为整体替换），或在仓库 Settings → Rules 中编辑。

---

## 6. 代码规范入口

| 主题 | 文档 |
|---|---|
| 入口、工作流、门禁 | [`AGENTS.md`](./AGENTS.md) |
| 全部文档路径索引 | [`docs/README.md`](./docs/README.md) |
| 命名规范 | [`docs/dev/naming.md`](./docs/dev/naming.md) |
| 架构、状态、错误、网络、书源、UI、平台、测试、安全、性能 | [`docs/dev/constraints.md`](./docs/dev/constraints.md) |
| 目录结构与分层 | [`docs/dev/architecture.md`](./docs/dev/architecture.md) |
| 书源规格 | [`docs/dev/book-source.md`](./docs/dev/book-source.md) |
| 测试与 CI | [`docs/dev/testing.md`](./docs/dev/testing.md) |
| 平台基线 | [`docs/dev/platform.md`](./docs/dev/platform.md) |
| 依赖与版本 | [`docs/dev/tech-stack.md`](./docs/dev/tech-stack.md) |
| 决策记录 | [`docs/dev/adr/`](./docs/dev/adr/README.md) |
| 静态分析规则 | [`analysis_options.yaml`](./analysis_options.yaml) |

---

## 7. 文档与国际化

### 7.1 文档更新

- 任何 API 变更必须同步更新 `docs/dev/` 下的相关文档。
- 新增文档必须先在 [`docs/README.md`](./docs/README.md) 索引中登记。
- 修改规范结论必须新增或更新 ADR。
- 破坏性变更必须记录在 [`CHANGELOG.md`](./CHANGELOG.md)。

### 7.2 语言约定

| 场景 | 语言 |
|---|---|
| 文档注释 `///` | 英文 |
| 普通注释 `//` | 中文 |
| Commit message | 英文 |
| PR 描述 | 中文优先，关键术语保留英文 |
| CHANGELOG | 英文 |

### 7.3 国际化

- 所有用户可见字符串必须放入 `lib/l10n/` 的 ARB 文件。
- 先在 `app_en.arb` 添加键与 `@key.description`，再补 `app_zh.arb`；
  两者必须在同一个 PR 内完成。
- 键名规则见 [`docs/dev/naming.md`](./docs/dev/naming.md) §8；
  生成配置见 [`docs/dev/tech-stack.md`](./docs/dev/tech-stack.md) §11。

---

## 8. 许可证

本项目采用 **GNU GPL-3.0**（version 3 only），完整文本见 [`LICENSE`](./LICENSE)。

- 版权、与上游 Legado 的关系声明、免责声明与 **GPL 合规义务清单**见 [`NOTICE.md`](./NOTICE.md)。
- **贡献即同意**在相同许可证下发布你的贡献。
- 提交 PR 时若新增依赖，必须确认其许可与 GPL-3.0 兼容
  （见 `docs/dev/constraints.md` C-DEP-7），并把结论写入 `NOTICE.md` §5。
- 分发（含应用商店）必须同时提供对应源代码；不得附加额外限制条款。

### 免责声明

本项目是独立的阅读客户端实现，**不提供、不托管、不传播、不索引任何书源或阅读内容**。
用户自行导入的第三方书源及其内容由用户自行承担合规责任。
本项目与 Legado 项目及其作者无隶属关系。

---

**感谢你的贡献！** 如有疑问，请通过 GitHub Issue 联系维护者。
