# 0079 — 单一 `dev` 工作树与集成分支

| 项 | 值 |
|---|---|
| 状态 | Accepted（2026-10-26，用户指令：整理工作树、重订开发标准） |
| 影响范围 | `CONTRIBUTING.md` §4.1、`AGENTS.md` §3、`.github/workflows/ci.yml`、所有本地 checkout |
| 关联 | ADR-0013（门禁唯一出处）、ADR-0065（分层 CI）、ADR-0067（发布通道） |

## 背景

本仓库是单仓多 checkout 的用法：主克隆 `legado-with-flutter`（`main`）+ 三个 `git worktree`
（`feat/p5-1-book-source-entry`、`feat/m17-audio`、`feat/ui-m15-m18`）。到 2026-10-26 已经出现三种
实际危害：

1. **提交位置歧义**：同一份功能在三个 checkout 里各有版本，问「代码提交到哪个 worktree」得不到唯一
   答案。`legado-p5` 里积了 106 个已跟踪改动 + 31 个未跟踪文件（ADR-0047~0051、`url_rule.dart`、
   `source_budget.dart`、`batch_probe.dart` 等的旧快照），与集成分支上的版本**不同**，既没提交也没人
   清理——这正是「多 checkout」会自然长出来的债。
2. **分支语义错位**：远端只有 `main` / `feat/ui-m15-m18` / `feat/p5-1-book-source-entry`，没有一条
   「日常集成」分支。集成实际发生在 `feat/ui-m15-m18` 上，而 `main` 停在三个月前的发布点；
   `ci.yml` 的 push 门禁又只监听 `main`，于是集成分支上的提交**从来没有**被 L1 门禁跑过。
3. **工具重复**：每个 worktree 各有一套 `.dart_tool` / `build` / Gradle 缓存，`pub get` 与
   `build_runner` 会互相争用同一个 pub cache（`test-environment.md` §6 记过同类问题）。

## 决策

1. **集成分支 `dev`。** 由当时的 `feat/ui-m15-m18` 最新提交建立；日常开发一律提交到 `dev`。
   `main` 只接受**从 `dev` 开的 PR** 合并，不直接推送（发布线仍以 tag 为源头，ADR-0065/0067 不变）。
2. **每台机器只有一个 checkout**：主克隆（`.git` 就在里面）就是它，check out `dev`；不再保留
   `feat/*` 的长期 checkout。本机执行时把主克隆切到 `dev`、三个 linked worktree 全部移除
   （脏的那份先归档），并把目录名改为 `legado-p5-dev`（见下方 §本机现状）。
3. **不再 `git worktree add`。** 需要评审的改动用短命分支（`feat/*` 等）在 dev 工作树内切，切前声明；
   需要完全隔离时用**临时 clone**，用完即删。两者都不改变「唯一长命 checkout 是 dev 工作树」。
4. **CI 的 L1 门禁在 `dev` 与 `main` 的 push 上都要跑**（`ci.yml` 的 `push.branches`），PR 门禁本来
   就是全量 `pull_request`，不受影响。发布通道（`release.yml` tag / `beta.yml` 手动 /
   `debug.yml` main push）**不改**。
5. **分支命名仍按 `CONTRIBUTING.md` §4.1 的 `feat/` `fix/` `docs/` `refactor/`**，但基线从 `dev`，
   合并回 `dev` 后立即删除。

## 后果

- **远端只剩 `main` 与 `dev`**：`feat/ui-m15-m18`、`feat/p5-1-book-source-entry` 已删除，本地同名分支
  与 `feat/m17-audio`、`feat/source-mgmt-manga-audio` 一并删除。删之前逐个核对过「相对 `dev` 的独有
  提交数 = 0」，所以没有任何一次提交因此不可达；`feat/*` 从此是短命分支，合并回 `dev` 后立即删。
- `legado-p5` 的未提交快照在被删前导出到仓库外 `F:/Projetcs/_archive/`（patch + 未跟踪文件归档），
  既保住可追溯性，又不让它们继续污染工作树。
- 「统一工作树」在远端等价于「统一分支」：远端没有 worktree 概念，别人 clone 后同样只留一个
  checkout、check out `dev`。
- 代价：不能再用两个 checkout 并行跑不同分支的 `flutter test`。需要时按决策 3 开临时 clone，或在
  dev 工作树内串行。

## 本机现状（2026-10-26，执行记录）

| 项 | 状态 |
|---|---|
| 分支 | `dev` 已建立（起点 `feat/ui-m15-m18` 的 `96fa2f5`）、已推送并跟踪 `origin/dev`；`main` 的历史没动，本地 `main` 已快进到 `origin/main` |
| 唯一 checkout | 主克隆 `F:/Projetcs/legado-with-flutter`，已切到 `dev`；`legado-p5-audio` / `legado-p5` 已移除，`legado-p5-mgmt` 待移除 |
| 脏快照 | `legado-p5` 的 137 处改动已归档到 `F:/Projetcs/_archive/2026-10-26-legado-p5/`（`dirty-tracked-and-untracked.patch` 747 KB + `status.txt`） |
| 目录改名 | **未完成**：`legado-with-flutter` 被 VS Code 等进程占用，`mv`/`move` 报「拒绝访问」；关闭占用它的程序后执行 `move F:\Projetcs\legado-with-flutter F:\Projetcs\legado-p5-dev` |
| 待移除的 worktree | 本文档写作时 `legado-p5-mgmt`（本会话的工作目录）仍被持有，需在会话结束后执行 `git -C <主克隆> worktree remove --force F:\Projetcs\legado-p5-mgmt`，再 `git worktree prune` |
| 分支清理 | 远端已只剩 `main` + `dev`；本地只剩 `dev`（当前 checkout）+ `main`（跟 `origin/main`）。四个 `feat/*` 分支全部删除，删前逐个确认「相对 `dev` 独有提交 = 0」 |
| `main` 与 `dev` 的关系 | 两条线共享 `55964cf`；`main` 上有两次 squash 合并（`#45` 三条发布通道、`#47` M19–M23 重建），`dev` 上有 95 次细化提交。**下次发布必须走 `dev` → `main` 的 PR**，不能强推 |

> 这两条是**一次性收尾**，不是常规流程：平时开发只需要「在主克隆里、在 `dev` 上」这两件事。

## 被否的备选

| 备选 | 否决原因 |
|---|---|
| 继续多 worktree，只在文档里写清「哪个是集成」 | 歧义正是文档解决不了的：四个 checkout 都会漂，脏改动无人认领（本轮清理时已实证） |
| 把 `feat/ui-m15-m18` 重命名为 `dev` 并删远端旧名 | 会让远端分支消失、断开已有 PR 的 head，其他人本地追踪失效；新建 `dev` 达到同样目标且可回退 |
| 让 `main` 兼任集成分支 | 发布线会被日常提交污染，tag 与发布通道的判据（ADR-0067）全部失效 |
| 用 `git worktree add` 给每个短命分支开 checkout | 正是本 ADR 要消灭的用法；短命分支在 dev 工作树内切就够了 |
