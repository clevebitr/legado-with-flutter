# ADR-0033 缓存失败吸收的唯一豁免点：`CacheDaoCharsetCache` 允许 `on Exception`（drift 不导出 `ConnectionClosedException`）

- **状态：** Accepted（2026-10-12 架构师裁决；开发组 3.9 复核 F1 的事实修正触发）
- **日期：** 2026-10-12
- **关联：** C-ERR-1、C-ERR-2、C-ERR-3、C-SEC-4、ADR-0002（2026-10-11 修订注记）、ADR-0022、
  `docs/dev/book-source.md` §5、`docs/dev/test-environment.md` §5、`PLAN.md` §3.7、
  `lib/core/network/charset_cache.dart`

## 背景

3.9（charset 检测结果缓存）把「缓存失败」的吸收放在**适配器**里（`CacheDaoCharsetCache`，3.9
复核 F1 的修法 A），按类型点名：`SqliteException`（`sqlite3 3.5.2`）与 drift 的
`DriftRemoteException` / `DriftWrappedException` / `InvalidDataException`。请求层因此不再有任何
缓存相关的 `catch`，也不需要认识 drift。

**但有一个类型点不了名（2026-10-12 核实）：** drift 2.35.2 **只导出** `DriftRemoteException`
（`lib/remote.dart:63`、`lib/isolate.dart:16`）；`ConnectionClosedException` 定义在
`src/remote/communication.dart:211`，**没有任何公开导出**。它在 `communication.dart:47` 被用来完成
**在途**请求（隔离体连接被取消时）——而本项目的数据库走后台 isolate，provider 释放时
`database.close()`，**这条路径在本仓可达**，正是 `docs/dev/test-environment.md` §5 记录过的
「Channel was closed before receiving a response」。

若它逃出适配器，异常会**穿过 `ParseResult` 契约**（C-ERR-1）从 `HttpClient.get` 抛出：
**缓存这条旁路失败，升级成页面请求抛异常**——比「多嗅探一次」严重得多，而且违反的是硬约束。

已排除的取巧写法：`on Object` + `is Exception`、`then(onError:)` / `catchError` 这类不点名的兜底，
以及把 `catch` 写回客户端——它们要么绕过 C-ERR-2 的可审计性，要么把 drift 的失败面塞进请求层
（C-ERR-2 的边界更不允许 `core/` 兜底）。

## 决策

1. **唯一豁免点：** `CacheDaoCharsetCache._absorb` 允许在四个具名 catch 之后追加一个
   `on Exception` 兜底，用于吸收 drift 未导出的 `ConnectionClosedException` 及同类的传输失败。
2. **约束（逐条可审计）：**
   - 只此一处，其他任何文件照抄即违反 C-ERR-2；
   - `Error` 一律不捕（ADR-0022 不变）；
   - 每条被吸收的失败必须落 `debug` 日志，且只带 URL 摘要与 `describeError` 摘要（C-ERR-3、C-SEC-4）；
   - `CharsetCache` 的端口契约保持 **total**（读返回 `null`、写 no-op、绝不抛），调用方不得为它兜底。
3. **日落条件（必须执行）：** 一旦 drift 导出该类型（或提供等价的可点名入口），把 `on Exception`
   换回具名 `catch`、删除本条豁免，并更新 C-ERR-2 的回链。`PLAN.md` §3.7 保留触发条件。
4. **登记：** `constraints.md` C-ERR-2 增加回链本 ADR（边界仍由 C-ERR-2 拥有，本 ADR 只解释这一处例外）；
   `book-source.md` §5 已写明「谁吸收失败、为何端口是 total」。
5. **复核触发（不得默认推广）：** 出现第二种「旁路存储」消费方，或该缓存被复用为通用缓存时，
   重新裁决豁免是否推广；推广必须另立 ADR。

## 后果

- 缓存失败在任何数据库失败模式下都不可能让页面请求抛异常（C-ERR-1 保住），也不会把 drift 的
  失败面扩散到请求层。
- 代价：适配器里存在一条**非具名** catch。它被本 ADR 固定、被测试钉住（DAO 抛普通 `Exception` 时
  读=未命中、写=正常返回，并各留一条 `debug`），并带日落条件。
- 这是**边界扩展**：按 C-ERR-2 的扩展规则，这类放宽必须由 ADR 记录——本 ADR 即该记录，
  它**不是**就地放宽（豁免范围写死在单个方法上，且带日落条件）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 等 drift 导出，先不做兜底 | 导出前，关闭隔离体的竞态会把**缓存失败**升级为**页面请求抛异常**（C-ERR-1）；本仓已实测过该症状（`test-environment.md` §5），不能留 |
| 在 `HttpClient` 里兜底 | 请求层不该认识 drift 的失败面；C-ERR-2 的边界更不允许（`core/` 不在豁免范围），且会把 3.9 复核 F1 刚修好的分层又推回去 |
| `on Object` + `is Exception`，或 `then(onError:)` / `catchError` | 绕过「必须点名类型」的可审计性，是就地放宽的变体；且后者连 lint 都拦不住，更隐蔽 |
| 把 `CacheDao.get` / `put` 改成 total | 失败面只是搬进 DAO，仍然要点名那个未导出的类型；还会让 DAO 对**所有**消费方静默吞错（超出「缓存」这一语义） |
| 关闭数据库前确保没有在途请求 | 请求由页面抓取驱动，缓存无法保证；`database.close()` 的时机不在缓存控制范围内 |

---

## 修订注记（2026-10-14，Phase 5 的 5.2）

**豁免的落点从 `CacheDaoCharsetCache._absorb` 移到共享的 `absorbCacheFailure`**
（`lib/core/storage/cache_failure_absorber.dart`）。

- **为什么：** 5.2 的正文缓存需要一个形状完全相同的适配器（`CacheDaoContentCache`），而
  C-ERR-2 只允许一个可审计的 `on Exception`。复制一份就等于第二个豁免点，所以把吸收逻辑抽成
  一个函数，两个适配器都经它——`on Exception` 因此仍然**只有一处**，`scope` 参数（`Charset cache` /
  `Chapter cache`）让日志仍然分得清是谁。
- **不变的边界：** 具名 catch 在前（`SqliteException` / `DriftRemoteException` /
  `DriftWrappedException` / `InvalidDataException`）；`Error` 仍原样向上（ADR-0022）；
  drift 导出 `ConnectionClosedException` 之后仍必须换回具名 catch 并删掉这一支。
- **验证方式不变：** 现有那份表驱动测试（`test/core/network/charset_cache_test.dart`）改走共享函数，
  `core` 覆盖率门禁仍为 100%（`absorbCacheFailure` 的每一支都被它覆盖）。
