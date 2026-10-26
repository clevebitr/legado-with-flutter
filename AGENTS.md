# AGENTS.md — AI 代理入口

> 本文件是 AI 编码代理（Claude Code、Cursor、GitHub Copilot、Codex 等）在本项目的**唯一入口**。
> 它只做三件事：**告诉你要读什么、门禁是什么、动手前必须做什么**。
> 它**不包含任何规范正文** —— 每条规范只有一份，位于 `docs/dev/`。

---

## 1. 项目定位

| 项 | 值 |
|---|---|
| 类型 | Flutter 阅读 App（Android / Windows / iOS） |
| 设计语言 | Material 3 Expressive，设计令牌统一由 `m3e_design` 提供 |
| 核心能力 | 纯 Dart 实现 Legado 书源解析，JS 规则在独立 Isolate 中执行 |
| 状态管理 | Riverpod（唯一方案，Provider 必须代码生成） |
| 本地存储 | Drift(SQLite) 为主库；`shared_preferences` 仅存轻量开关 |

---

## 2. 文档地图（完整权威索引：`docs/README.md`）

| 文档 | 何时必须读 |
|---|---|
| `docs/dev/roadmap.md` | 开始任何功能开发前：先做什么、怎么验收、何时可进下一步 |
| `PLAN.md` | 里程碑级状态（`plan` 插件维护，**不要手改**）；步骤级进度只看 `todo` |
| `docs/dev/naming.md` | 任何命名：文件、类、方法、变量、API、注释 |
| `docs/dev/constraints.md` | 生成任何代码之前，逐条对照条目 ID |
| `docs/dev/tech-stack.md` | 新增依赖、改 lint、改国际化配置时 |
| `docs/dev/architecture.md` | 新增文件、feature、Provider、路由时 |
| `docs/dev/book-source.md` | 任何书源解析、规则引擎、JS 桥接改动 |
| `docs/dev/engine-parity.md` | 改引擎前：这一项与上游差在哪、去哪个切片、是否已有意登记（ADR-0078） |
| `docs/dev/testing.md` | 写测试、改 CI、修门禁失败时 |
| `docs/dev/test-environment.md` | 在本机跑设备级测试、搭建 Windows/Android 测试环境、排查模拟器与设备问题时 |
| `docs/dev/platform.md` | 涉及 Android / iOS / Windows 差异的代码 |
| `docs/dev/adr/` | 想知道「为什么这么定」，或要推翻某个决定时 |
| `CONTRIBUTING.md` | 提 PR、分支命名、Commit、Review 流程 |

**任务模糊、或需要偏离任何一条约束时，必须向用户提问；禁止自行假设。**

---

## 3. 工作流（每次任务都走完五步）

1. **读** — 按上表读取相关文档；不确定归属时先通读 `docs/dev/constraints.md`。
2. **判** — 确定改动落在哪一层（`presentation` / `domain` / `data` / `core`），
   是否需要新依赖、新生成物、跨平台适配，是否需要新增 ADR。
3. **写** — 逐条满足 `constraints.md` 的条目；公共 API 写英文 `///` 文档注释，
   复杂逻辑写中文 `//` 注释解释「为什么」。
4. **验** — 逐项过 §4 门禁。任何一条无法满足时，说明原因并请求用户确认，
   不得静默跳过，不得降级为注释说明。
5. **交** — 输出变更文件清单、影响范围、验证方式；PR 描述使用
   `.github/PULL_REQUEST_TEMPLATE.md`。

---

## 4. 合并门禁（缺一不可）

> **本命令清单是门禁命令的唯一出处**（ADR-0013 §5）。CI 的执行顺序见
> `docs/dev/testing.md` §7；阈值定义见 `docs/dev/testing.md` §2。
> 其他文档、PR 模板、AI 提示词模板一律回链本节，不得再抄一份。

```bash
dart format --set-exit-if-changed .
flutter analyze                                            # 必须零警告（含 analyzer 插件规则）
flutter test --coverage
dart run tool/check_coverage.dart                          # 必须退出码 0（阈值 + 未测量源文件，见 testing.md §2）
dart run build_runner build                                # C-DEP-4（ADR-0013 §6）
git diff --exit-code -- '**/*.g.dart' '**/*.freezed.dart'  # 生成物与源码同步
```

> `riverpod_lint` 的安装位置、`custom_lint` 的取舍与全部 lint 规则映射见
> `docs/dev/tech-stack.md` §12（ADR-0010）；由 `flutter analyze` 执行，本项目不使用 `custom_lint`。

---

## 5. 硬性红线（违反即回退重做；细则见 `docs/dev/constraints.md` §14）

- 生成未使用的类、方法、变量、import
- 留下 `// TODO` 空实现或占位代码
- 手改 `*.g.dart`、`*.freezed.dart`、`*.gr.dart`
- 在 `presentation` 层直接 import `data` 层
- `print()`、`dynamic`（JS 桥接除外）、`!` 强制解包
- 硬编码颜色、尺寸、用户可见字符串、API Key
- 明文 HTTP；跨 `await` 使用 `context` 不检查 `mounted`
- 在 `build` 中执行重计算；一次性把大文件读进内存
- 引入与 GPL-3.0 不兼容的依赖（GPL-2.0-only / 无许可 / 专有许可）

---

## 6. 维护本文件

- 本文件由项目核心团队维护，**始终保持 ≤120 行**。
- 新增或重命名规范文档时，只更新 `docs/README.md` 与本文档 §2 地图表，
  **不得把规范正文复制进来**。
- 发现规范冲突或缺失时，向用户报告并在 `docs/dev/adr/` 记录，不得自行假设。
