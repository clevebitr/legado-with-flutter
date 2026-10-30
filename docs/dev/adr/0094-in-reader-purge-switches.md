# ADR-0094 阅读内净化开关：一个端口、一张面板、一次重读

- **状态：** Accepted（2026-10-30，M35 规格前置；起因：与上游阅读面逐项对照时登记的缺口）
- **日期：** 2026-10-30
- **关联：** ADR-0070（净化规则与正文链路）、ADR-0071（规则存储与导入导出）、ADR-0033（缓存失败豁免）、
  ADR-0042 §决策 2（跨 feature 只用端口）；`constraints.md` C-ARCH-2、C-STATE-*、C-UI-5/7；
  上游 `ui/book/read/ReadBookContract.kt` 的 `ChangeReplaceRule` / `SetReplaceRuleEnabled`

## 背景

净化规则（替换净化）在本仓是**全局设置**：规则列表在「我的 → 替换净化」里维护，`ContentPurifier`
在取正文时按启用规则跑。上游在阅读菜单里还有一层「**阅读中临时启停**」——读某本书时发现某个规则把
正文吃掉了，或者想看未经净化的原文，不用退出阅读器去改全局规则。

## 决策

### 决策 1 阅读器声明端口，装配根把它绑到「规则表 + 本书缓存」

`reader/domain/repositories/purge_rule_switches.dart`：

```dart
final class PurgeRuleSwitch { final int id; final String pattern; final String? replacement; final bool isEnabled; }

abstract interface class PurgeRuleSwitches {
  Future<List<PurgeRuleSwitch>> list();
  Future<void> setEnabled({required int id, required bool enabled, required String sourceUrl, required String bookUrl});
}
```

- 未绑定时是 `UnboundPurgeRuleSwitches`（空列表 + warning），与其它端口同一习惯（ADR-0041 §决策 2）。
- 装配根（`app.dart`）把它接到 `rules` 的 `RuleRepository`（`ofKind(replace)` / `setEnabled`）**并**在写入后
  `contentCache.clearForBook(sourceUrl, bookUrl)`：已缓存的成品正文是按旧规则净化过的，不清就会
  「开关点了没反应」。只清这本书、不清全库——阅读中的改动不该让别的书重新下载。
- **不做**：排序、新建、删除、编辑规则内容。阅读器里只回答「这条规则现在生效吗」，其余动作留在规则管理页
  （上游也一样，菜单里只给开关）。

### 决策 2 生效方式：切换后让正文 provider 重读

面板每次切换都 `await` 端口，然后 `ref.invalidate(readerContentProvider)`（整个家族）：当前章与相邻预取章
都会按新规则重新取一次，用户眼前的那一页在下一次 build 就变了。不再写第二套「就地重排」路径——
ADR-0089 已经保证「目录/正文更新不挪动读者」，重读是安全的。

### 决策 3 入口在工具条，面板是一个 sheet

工具条新增一个按钮（`Icons.auto_fix_high`，tooltip「净化规则」），打开 `ReaderPurgeSheet`：
一行说明（「改动会重读本书已缓存的正文」）+ 每行一条规则（`pattern → replacement`，右侧开关）。
空列表有明确空态；端口失败给重试。工具条在 M34 已经改成可横向滚动，第 10 个按钮不会挤爆窄屏。

## 影响

- 新增 `reader/domain/repositories/purge_rule_switches.dart`、`reader/presentation/widgets/reader_purge_sheet.dart`、
  `reader/di.dart` 的默认（unbound）provider、`app.dart` 的绑定。
- `reader_page` 工具条多一个按钮；`readerContentProvider` 在切换后被 invalidate。
- 测试：端口替身 + 面板 Widget（列表、切换回调、空态）、阅读页「点按钮开面板」。

## 后果

- 好处：读的时候发现规则坏了能立刻关掉，原文就在眼前；不用离开阅读器、不用改全局配置再回来。
- 代价：每次切换会让当前书已缓存的正文重下一次（一章一次请求，可接受）；面板是**当前书**的视角，
  规则本身仍是全局的——关掉一条会影响这本书之外的阅读，这是上游同款语义，面板的说明行写清楚。
- 不做：按书的规则覆盖（per-book rules）、规则编辑、规则排序。
