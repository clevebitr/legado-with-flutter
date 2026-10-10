# ADR-0003 Drift 作为主持久化方案

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-NET-7、C-NET-9、C-PERF-6、`docs/dev/tech-stack.md` §6

## 背景

`AGENT_CONSTRAINTS.md` §4 要求「使用 `Drift` / `Isar` / `Hive`，禁止直接操作 SQLite 或文件系统」，
但 `TECH_STACK.md` 的依赖清单里只有 `shared_preferences` —— 约束强制的能力在依赖层面不存在。
同时「缓存必须带 TTL」「缓存键 = 书源 ID + 参数摘要」隐式要求可查询的存储。

## 决策

1. 结构化数据（书源、章节缓存、阅读进度、正文缓存）使用 **Drift（SQLite）**。
2. SQLite 原生库由 `sqlite3_flutter_libs` 提供，保证 Android / Windows / iOS 三端一致。
3. `shared_preferences` **仅**用于轻量开关（主题模式、字号、上次同步时间）。
4. DAO 与表定义位于 `lib/core/storage/`，仓储实现位于 `lib/features/<f>/data/`。
5. 需要 TTL 的表必须显式声明 `expireAt` 列，并在查询时过滤过期行；缓存键为稳定哈希列。

## 后果

- 新增依赖：`drift`、`sqlite3_flutter_libs`（运行时），`drift_dev`（开发）。
- `build_runner` 同时承担 freezed / json_serializable / riverpod / drift 四类生成。
- 列表查询必须分页或走索引（C-PERF-6）；禁止在 UI 线程做全表扫描。
- 数据库 schema 变更必须带迁移，且迁移必须有测试。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| `Hive` | 无查询能力，TTL 与「按书源 ID + 参数」检索需自行实现索引，易退化为全表扫描 |
| `Isar` | 需额外验证 Flutter 3.47 / Dart 3.13 兼容性与 Windows 原生构建链 |
| 只用 `shared_preferences` + JSON 文件 | 与 C-NET-7「禁止直接操作文件系统」冲突，且无事务与查询能力 |
