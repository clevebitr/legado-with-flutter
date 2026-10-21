# 书源校验（5.10）执行记录：五类可判定失败

> 本文件是 `docs/dev/roadmap.md` §5.10 **验收第一条**的证据与复现说明：
> 「批量校验：≥5 条可判定的失败（搜索失败 / 目录为空 / 正文为空 / 超时 / JS 错误）
> 各有一次可复现的执行记录（真源或派生源，命令与产出）」。规则语义归 `docs/dev/book-source.md`，
> 分组词表与失败归类归 **ADR-0043**；本文件只记录「怎么复现」与「看到了什么」。
>
> 与 `tool/spot_check/README.md`（G2b 真实站点）的分工：那边证明**规则在活站点上对**，
> 这边证明**校验机制把已知的五类失败各判了一次**。两边都不联网进 CI
> （`docs/dev/testing.md` §1）。

---

## 1. 为什么用派生源

五类失败里有三类只能**故意造**：目录为空、正文为空、JS 错误若拿真源碰运气，等于把验收绑在
站点是否恰好坏掉上。因此每条记录用一份**派生源**（同一套 CSS 规则，只坏一处）配一份离线页面，
命令固定、产出固定、跨机器可重复。

派生源与离线页面的形状见
`test/features/book_source/domain/usecases/check_book_source_test.dart`
（`_source({...})` + `_searchPage` / `_bookPage` / `_tocPage` / `_contentPage`），
站点域名为 `https://check.test`，全部请求由 `FakeHttpClient` 应答（无网络）。

跑任意一条：

```bash
flutter test test/features/book_source/domain/usecases/check_book_source_test.dart \
  --plain-name "<用例名>"
```

---

## 2. 五条记录

| # | 失败 | 派生源怎么坏 | 用例（命令里的 `<用例名>`） | 产出（断言） |
|---|---|---|---|---|
| 1 | **搜索失败** | 搜索页没有 `class.result` 元素 | `execute_givenAnEmptySearch_marksTheSearchInvalid` | `status=failed`，分组 `[搜索失效]`，注释 `搜索失效`，阶段只剩 search |
| 2 | **目录为空** | 目录页有 `class.chapter` 之外的内容（`class.other`），列表规则零命中 | `execute_givenAnEmptyTableOfContents_marksTheSearchTocInvalid` | 分组 `[搜索目录失效]`，`rulePath=tocRule.chapterList`，后续正文阶段不跑 |
| 3 | **正文为空** | 正文页 `#content` 为空 | `execute_givenAnEmptyBody_marksTheSearchContentInvalid` | 分组 `[搜索正文失效]`，`failureKind=parseFailed` |
| 4 | **超时** | 单源预算设为 0 / 请求挂在半空 | `execute_givenNoBudgetLeft_timesOutBeforeRequesting`、`execute_givenARequestThatNeverAnswers_timesOut` | 分组 `[校验超时]`，`failureKind=networkTimeout`；前者一个请求都不发 |
| 5 | **JS 错误** | 正文规则写成 `id.content@js:result.trim()`，脚本抛错 | `execute_givenABrokenScript_marksTheSourceJsInvalid` | 分组 `[js失效]`，`rulePath=contentRule.content:js:error` |

补充记录（同文件）：

| 项 | 用例 | 产出 |
|---|---|---|
| 站点级失败（非空列表型） | `execute_givenAReadFailure_marksTheSiteInvalid` | 分组 `[网站失效]` |
| 发现链失败用发现侧词表 | `execute_givenTheSameBrokenTocOnBothChains_writesBothTokens` | `[搜索目录失效, 发现目录失效]` |
| 取消是 `Cancelled` 而非 `Failed` | `execute_whenCancelledBeforeTheStart_cancelsWithoutAStage` | `status=cancelled`，无分组、无请求 |
| 重新校验先清掉上次结论 | `applyCheckReport_givenASecondHealthyRun_clearsThePreviousVerdict`（`test/features/book_source/data/book_source_repository_impl_test.dart`） | 第二次通过后 `groupName` / `comment` 回到 `null`，`respondTime` 刷新 |
| 分组 / 注释 / `respondTime` 的写入 | `applyCheckReport_givenInvalidGroups_writesGroupsNoteAndRespondTime`（同上）、`writeCheckState_whenCalled_writesTheCheckColumns`（`test/core/storage/book_source_dao_test.dart`） | 三列同时写入，`payload` 不动 |
| 真机上「写进文件」 | `integration_test/on_disk_database_test.dart` 的 `bookSourceDao_givenAFileDatabase_persistsTheImportedSource` | 跨连接读回 `groupName` / `comment` / `respondTime` |
| 单源调试的三类事件 | `test/features/book_source/domain/usecases/run_source_debug_test.dart` | message / source / error 各至少一次；正文只报 `chars=`，不泄漏正文 |
| 调试页的五态 | `test/features/book_source/presentation/pages/book_source_debug_page_test.dart` | 空态 / 运行中 / 成功 / 失败 / 取消 |
| 校验页的五态 | `test/features/book_source/presentation/pages/book_source_check_page_test.dart` | 空态 / 运行中 / 成功 / 失败 / 取消 |

**最近一次执行（2026-10-21，Windows 11 / Flutter 3.47.7）：**

```
flutter test test/features/book_source/domain/usecases/check_book_source_test.dart
00:00 +23: All tests passed!

flutter test test/features/book_source/presentation/pages/book_source_check_page_test.dart
00:03 +9: All tests passed!

flutter test test/features/book_source/presentation/pages/book_source_debug_page_test.dart
00:02 +7: All tests passed!
```

---

## 3. 真源怎么复核（人工，不联网进 CI）

设备级复核走应用本身（不经 `spot_check.dart`）：桌面端或 Android 模拟器上运行 App，
进「书源列表 → 校验」，选中已导入的真源，跑一次即可。判据与产出：

1. 校验页每行给出 `通过 / 失败 / 已取消` 之一，失败的行走「失败于 `<rulePath>`」；
2. 回到书源列表查看该源的分组里出现对应「失效」词条（`搜索失效` / `搜索目录失效` / …）；
3. 再跑一次：上一次的「失效」分组与 `// Error: ` 注释**先被清掉**（ADR-0043 §后果），不会累积；
4. 超时用页面上的「单源超时」下拉改成 30s，对一条已知很慢的源复现 `校验超时`；
5. JS 失效用一条**已知脚本坏掉**的源（例如把某条 `bookInfoRule.name` 改成 `@js:throw new Error(1)`），
   校验后分组出现 `js失效`。

> 真源的选择原则、脱敏与法律边界见 `tool/spot_check/README.md` §3 与 ADR-0023；
> 本文件不复制那份清单。
