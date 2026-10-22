# ADR-0056 数据库迁移步骤必须可重入（幂等）

- **状态：** Accepted（2026-10-22，M18 后线上事故修复：用户机器上 `reader.db` 打不开）
- **日期：** 2026-10-22
- **关联：** C-NET-7、C-NET-9、ADR-0003、ADR-0052、`docs/dev/tech-stack.md` §8、
  `test/core/storage/migration_test.dart`

## 背景

用户机器上的 `reader.db` 出现这种状态：

- `PRAGMA user_version` = **5**，但库里已经有 v6 的全部对象（`source_checks` 表、
  `source_checks_source_checked` 索引、`book_sources.is_explore_enabled` 列）；
- 于是每次打开库都跑 v5 → v6 的升级步骤，第二步 `m.create(sourceChecksSourceChecked)`
  抛 `SqliteException(1): index source_checks_source_checked already exists`；
- 迁移在 `beforeOpen` 里失败 → **任何**查询都失败。前台看到的是
  「书源加载不出来」「导入失败（`DriftRemoteException`）」这类下游症状，日志里只有脱敏后的
  `<DriftRemoteException: 230 chars, sha256=…>`，看不到真正的原因。

成因有两类，都属于「版本号落后于实际结构」：

1. 开发期用**还没提交的表定义**建过库：`onCreate` 用当前表结构建库，但 `schemaVersion`
   当时还是 5，于是库被盖上 5（本次事故就是这么来的）；
2. 迁移中途被杀：drift 不把 `onUpgrade` 包在事务里（`_runMigrations` 在迁移**之后**才写
   `PRAGMA user_version`，DDL 与版本号之间没有原子性），进程在这一步被打断就留下半套对象。

drift 自己的幂等边界也不一致：`Migrator.createTable` 生成 `CREATE TABLE IF NOT EXISTS`，
而 `createIndex`（`@TableIndex` 声明的索引）和 `addColumn` 生成的都是**裸 SQL**。
只看 `from` 版本号写迁移，就继承了这两处不幂等。

## 决策

### 决策 1 升级步骤先问「对象在不在」，重复执行是空操作

`ReaderDatabase.migration` 里每个非幂等原语都套一层守卫：

- 建索引前查 `sqlite_master`（`_hasSchemaObject`）；
- 加列前查 `PRAGMA table_info(<表>)`（`_addColumnIfMissing`）；
- 建表继续用 `m.createTable`（它自带 `IF NOT EXISTS`）。

版本门（`if (from < N)`）保留：它说明「这一步属于哪个 ADR、为什么存在」，
但**不再被当作结构的事实来源** —— 结构以库里实际有什么为准。

### 决策 2 不做「迁移事务 + 版本号一并提交」

理论上可以把 `onUpgrade` 包进事务以求原子，但版本号由 drift 在迁移之后单独写，
事务挡不住「DDL 已提交、版本号没写」这一档；而决策 1 已经让这类残留状态可自愈，
新增 `BEGIN`/`COMMIT` 只会给 `beforeOpen` 引入第二套事务语义（drift 的事务嵌套规则）。
因此记录为「不做」，将来若出现**数据搬迁型**迁移（需要「全成功或全回滚」），再单独写 ADR。

### 决策 3 回归测试必须复现「版本号落后」这一档

`test/core/storage/migration_test.dart` 的
`migration_whenTheVersionIsBehindTheActualSchema_repairsTheDatabase`
用 `verifier.schemaAt(6)` 建出 v6 结构，再 `PRAGMA user_version = 5` 把版本号打回去，
然后断言升级通过、版本号落到 6、结构与 v6 逐列一致 —— 这就是用户机器上的那份库。
新增迁移步骤时照抄这条用例的构造方式即可。

## 后果

- 升级路径每次多出 1 条 `SELECT`（查索引）与每条待加列 1 条 `PRAGMA`，只在**版本变化的那一次**
  打开时执行，与「永久打不开」相比代价可忽略。
- 新增迁移步骤必须走 `_hasSchemaObject` / `_addColumnIfMissing`，直接 `m.addColumn` /
  `m.create(index)` 视为违反本 ADR（review 检查项）。
- 自查方式（设备上）：`sqlite3 reader.db 'PRAGMA user_version'` 与
  `SELECT name FROM sqlite_master` 对照，确认版本号与实际结构一致。
