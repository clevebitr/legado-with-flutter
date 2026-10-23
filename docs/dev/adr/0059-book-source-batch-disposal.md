# ADR-0059 书源批量处置：多选入口、失效源一键、分组一键

- **状态：** Accepted（2026-10-22，用户裁决四项：入口形态 / 分组形态 / 多选入口 / 失效口径）
- **日期：** 2026-10-22
- **关联：** ADR-0050 §决策 1/2（分组轴只读 payload、批量动作只作用于看得见的行）、
  ADR-0052 §决策 2/4（四态状态灯、分组管理）、ADR-0043（校验写回的失效分组）、
  `docs/dev/roadmap.md` §3.9 M15 V6

## 背景

M15 的批量操作只做了一半：能多选、能启停 / 删除 / 加分组，但**多选只能靠长按**（桌面端几乎发现不了，且
一进去就带一行），而用户真正要做的两件事都得先手点几十下：

1. **清理失效书源**：库里几百条源、跑完一轮校验后，用户要把「搜索失效 / 网站失效」的全部禁用或删掉。
   今天只能：点「有失效」筛选 → 长按一行 → 全选 → 禁用/删除。「有失效」这个筛选线本身已经是
   「要处理的那批人」，却没有任何动作挂在它上面。
2. **按分组处置**：分组管理只有「重命名 / 删除分组（只改 payload，保留书源）」。想「清掉玄幻这一组」
   或「只对这一组动批量操作」，只能到 chips 里选分组再长按全选，且分组管理对话框里看不出这两种意图的
   区别 —— 一个删标签、一个删书源，混在一起是数据事故的温床。

## 决策

### 决策 1 多选模式有独立状态与显式入口

- `bool _selecting` 与 `Set<int> _selected` 分开：`_selected.isNotEmpty` 不再是「是否在多选」的判据，
  所以工具栏的「多选」图标可以在**一条都没勾**的情况下进入模式（勾选计数从 0 开始），长按仍然
  以按下的那一行进入。
- 多选期间**行内启用开关与行菜单都禁用**：此时点行内的东西一律是「勾选」意图，一个误触就会改掉
  单条源或弹出编辑/删除菜单。
- 退出（左上角 ×）与批量动作完成后都走同一条 `_stopSelecting()`，模式与勾选一起清空。

### 决策 2 「有失效」筛选行上挂一键禁用 / 一键删除

- `BookSourceCheckFilter.failing` 选中时，筛选行尾追加 `禁用失效源` / `删除失效源` 两个按钮，作用于
  **当前可见的行**（即该筛选刚算出来的集合，含分组与搜索的收窄）：按钮下面就是将被处理的清单，
  不需要第二个入口去发现。
- 判定沿用**「有失效」筛选的同一口径**（ADR-0052 §决策 2 的 `hasCheckFailure`：最新一次结论为
  失败/降级，或列里仍带校验写回的失效分组），因此「看到的」与「删掉的」永远一致；「从未校验」不算失效。
- 禁用不弹确认（用户态、可逆），删除弹确认并写明条数；两者都是**一个事务**（ADR-0050 §决策 2），
  不会出现「删了一半」。
- 不新增工具栏图标：工具栏已有排序 / 方向 / 视图 / 多选 / 校验 / 导入六项，再加会挤掉标题。

### 决策 3 分组管理里区分「删标签」与「删书源」

`_GroupAction` 从 2 项扩到 4 项，对话框里按危险度自上而下：

| 项 | 语义 |
|---|---|
| 重命名分组 | 只改 payload 的 token（既有） |
| 删除分组 | 只把 token 从每个源上移除，**书源保留**（既有，`bookSourceGroupDeleteBody` 已写明） |
| 选中该组全部书源 | 切到该组视图 + 清掉搜索/校验筛选，再进入多选并勾上该组全部行 |
| 删除该组全部书源 | 二次确认（标题同时给分组名与条数）后连行一起删 |

- 分组动作读的是**未筛选**的 `bookSourceListProvider`：它针对「该组全部」，不该被当前的分组 /
  校验 / 搜索三个筛子左右。
- 「选中该组全部」必须先切视图：多选只作用于看得见的行（ADR-0050 §决策 2），若分组筛选停在别处或
  「有失效」把行藏了一部分，刚勾上的 id 会在下一帧被剪掉，用户看到的是「我点了但它没选中」。
- 「删除该组全部」删完后该组自然消失（没有行再带这个 token），不需要额外改写 payload。

## 后果

- 新增 l10n 键：`bookSourceListSelectMode`、`bookSourceListInvalidDisable`、`bookSourceListInvalidDelete`、
  `bookSourceListInvalidDisabled`、`bookSourceListInvalidDeleteTitle`、
  `bookSourceListGroupSelectSources`、`bookSourceListGroupDeleteSources`、
  `bookSourceListGroupDeleteSourcesTitle`（zh / en 同步）。
- 回归点（`test/features/book_source/presentation/pages/book_source_list_page_batch_test.dart`）：
  `selection_whenTheToolbarEntryIsUsed_startsEmptyAndTicksRows`、
  `selection_whenTheRowSwitchIsReached_itIsInert`、
  `failing_whenDisableIsChosen_disablesEveryListedFailure`、
  `failing_whenDeleteIsConfirmed_removesOnlyTheFailures`、
  `groups_whenSelectEverySourceIsChosen_ticksTheWholeGroup`、
  `groups_whenDeleteEverySourceIsConfirmed_deletesThatGroup`。
- 仍未做：批量动作的**撤销**（删除没有回收站）；「按分组批量禁用」没有单独按钮，走「选中该组全部 →
  禁用」两步；校验页的批量禁用不在本次范围（它只写回结论）。
