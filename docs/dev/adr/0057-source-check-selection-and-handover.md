# ADR-0057 校验的参测源由「筛选 + 勾选」决定，并可跨页交接

- **状态：** Accepted（2026-10-22，用户报障：多选后无法测试、无法只测某一分组）
- **日期：** 2026-10-22
- **关联：** ADR-0043（校验机制）、ADR-0046 §决策 1/2（范围与类型筛选）、ADR-0050 §决策 2
  （批量动作一个事务、只作用于看得见的行）、ADR-0011（typed route）、
  `docs/dev/roadmap.md` §3.8 / §5.10

## 背景

书源列表与校验页之间有两条用户路径是断的，两处都是**参测源**的信息丢了：

1. **多选后无法测试**。列表页的多选工具栏有启用 / 禁用 / 分组 / 删除，没有「测试」；
   校验页自己在跑完一轮后，`_effectiveSelection` 优先返回 `state.entries`（上一轮的结论行），
   于是勾选被忽略、勾选框也只出现在「上一轮没跑过」的行上 —— 第二轮永远只能重跑同一批。
2. **不能只测某一分组**。校验页的分组 / 类型 chips 只过滤**列表**，开始校验时
   `_selection == null` 就回落到「全库」；列表页工具栏的校验入口也不带当前分组。
   于是一个 500 条的库选好分组再点开始，跑的是 500 条。
   而 `docs/dev/roadmap.md` §3.8 的 M11 交付物写的是「校验 / 调试按『分组 + 类型』筛选**选源**」，
   实现只做到了「筛列表」—— 这是实现偏离已裁决规格，不是新需求。

## 决策

### 决策 1 「参测源」只有一条公式：可见行 ∩ 勾选

- 分组 / 类型 chips 是**默认选择**：用户没有自己的勾选时，参测源 = 当前筛选留下的全部行。
  这样「只看某分组」与「只校验该分组」是同一个动作，§3.8 的规格才真正落地。
- 用户勾了之后，参测源 = **可见行 ∩ 勾选**：与列表页批量动作「只作用于仍然看得见的行」同一条
  规则（ADR-0050 §决策 2）。被筛选隐藏的勾选**不清除**（用户的意图留着），只是暂时不参与。
- 换分组 / 换类型 = 换问题，勾选回到默认（`_selection = null`）。否则上一组的勾选与新筛选求交
  成空集，「至少选择一条书源」会变成每次换筛选后的固定体验。
- 「全选」写成「回到默认」（`_selection = null`），而不是写死一份 id：换筛选后它仍然是当前
  可见的全选。

### 决策 2 勾选不再派生自上一轮的 `entries`

`state.entries` 是**上一轮的结论**，不是「用户这次要跑什么」。结论行必须同时保留勾选框
（结论进副标题、状态灯进 `secondary`），否则跑完一轮页面就变成只读报告，用户只能退出重进。

### 决策 3 跨页交接走 typed route，primitive 只交「目标」

`BookSourceRoute.checkSources({Set<int>? sourceIds, String? group})`：

- 列表页**多选工具栏**交出 `sourceIds`（勾选的行）；
- 列表页**工具栏**交出 `group`（当前分组筛选，未筛选时为 `null`）；
- 校验页把它们当**起点**：`sourceIds` 进初始勾选，`group` 预选分组 chip；两者都可继续编辑。
  带目标进来时类型筛选的默认值改为「全类型」—— 否则用户点名的图片 / 音频源会被类型默认值
  （文本，ADR-0046 §决策 2）筛成不可见，「测选中的源」变成「一条也不选」。

不把选择塞进 keepAlive 的 Provider：那会让「上次点了什么」跨页面存活，`_selection` 的
生命周期与页面一致才是它唯一的语义（C-STATE-5）。

### 决策 4 多选工具栏改为横向滚动

加第五个按钮后，`Row(spaceAround)` 在窄屏上会把删除挤出可视区（M15 已踩过这条）。
工具栏改成 `SingleChildScrollView(horizontal)` + 自然宽度按钮：宽屏照旧一行排开，窄屏可滑。

## 后果

- 校验页的「`已完成 / 总数`」在未跑时显示**将要跑的条数**（不再是可见行数），分组筛选的效果
  在按开始之前就能看到。
- 新增 l10n 键 `bookSourceListBatchCheck`（zh「校验」/ en「Check selected」）。
- 回归点（`test/features/book_source/presentation/pages/`）：
  `start_whenAGroupIsPicked_checksOnlyThatGroup`、
  `selection_whenARunFinished_canCheckADifferentSet`、
  `build_givenInitialSourceIds_ticksOnlyThem`、
  `selection_whenCheckIsChosen_handsTheTickedRowsOver`、
  `toolbar_whenAGroupIsFiltered_handsTheGroupOver`。
- 仍未做：校验的**阶段开关与超时**仍不持久化（`roadmap.md` §7 已登记）；校验页**没有**按
  「指定源范围」持久化（那属于搜索范围 `SearchScope` 的概念，校验页只做一次性交接）。
