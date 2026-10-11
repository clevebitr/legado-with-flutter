# ADR-0003 Drift 作为主持久化方案

- **状态：** Accepted
- **日期：** 2026-10-10（2026-10-10 修订原生库方案）
- **关联：** C-NET-7、C-NET-9、C-PERF-6、C-DEP-7、`docs/dev/tech-stack.md` §6

## 背景

`AGENT_CONSTRAINTS.md` §4 要求「使用 `Drift` / `Isar` / `Hive`，禁止直接操作 SQLite 或文件系统」，
但 `TECH_STACK.md` 的依赖清单里只有 `shared_preferences` —— 约束强制的能力在依赖层面不存在。
同时「缓存必须带 TTL」「缓存键 = 书源 ID + 参数摘要」隐式要求可查询的存储。

初版决策原计划**直接**依赖 `sqlite3_flutter_libs` 提供原生库。实测（`flutter pub get` +
`flutter build apk --debug`）表明正确做法是改用 **`drift_flutter`**：它自己会传递引入
`sqlite3_flutter_libs ^0.6.0+eol` 与 `sqlcipher_flutter_libs ^0.7.0+eol` 并统一管理
原生库版本。问题出在**直接**依赖 `sqlite3_flutter_libs`（尤其旧版本 `^0.5.x`）——
那会在新版 Android 工具链上丢库，启动时抛
`DriftRemoteException: dlopen failed: libsqlite3.so not found`。

## 决策

1. 结构化数据（书源、章节缓存、阅读进度、正文缓存）使用 **Drift（SQLite）**。
2. 原生库与数据库路径由 **`drift_flutter`** 提供（Drift 官方推荐的当前方案）。
3. **不直接依赖 `sqlite3_flutter_libs`**；它由 `drift_flutter` 传递引入并统一管理。
4. `shared_preferences` **仅**用于轻量开关（主题模式、字号、上次同步时间）。
5. DAO 与表定义位于 `lib/core/storage/`，仓储实现位于 `lib/features/<f>/data/`。
6. 需要 TTL 的表必须显式声明 `expireAt` 列，并在查询时过滤过期行；缓存键为稳定哈希列。

依赖组合（与 `pubspec.yaml` 同步）：

```yaml
dependencies:
  drift: ^2.35.2
  drift_flutter: ^0.3.1
  path_provider: ^2.1.6
dev_dependencies:
  drift_dev: ^2.35.1
  build_runner: ^2.16.2
```

> **2026-10-11 修订：** 初版此处误写 `drift_dev: ^2.35.2`。该版本不存在
> （`drift_dev` 落后 `drift` 本体一个补丁），唯一可行解是 `^2.35.1`，
> 硬约束见 `docs/dev/tech-stack.md` §1.1。

## 后果

- `build_runner` 同时承担 freezed / json_serializable / riverpod / drift 四类生成。
- 列表查询必须分页或走索引（C-PERF-6）；禁止在 UI 线程做全表扫描。
- 数据库 schema 变更必须带迁移，且迁移必须有测试。
- Drift 会推进到 `sqlite3` 3.x（当前 `3.7.0`），Web 端如启用需同步更新 `sqlite3.wasm`。
- 新增依赖均已核实为 MIT 许可，与项目的 GPL-3.0 兼容（C-DEP-7）。
- 已实测：锁定 `sqlite3_flutter_libs 0.6.0+eol`、`sqlite3 3.5.2`，
  `flutter build apk --debug` 构建成功（无需任何手工干预）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| `sqlite3_flutter_libs` | 上游已 EOL，新版 Android 工具链下启动失败 |
| `Hive` | 无查询能力，TTL 与「按书源 ID + 参数」检索需自行实现索引，易退化为全表扫描 |
| `Isar` | 需额外验证 Flutter 3.47 / Dart 3.13 兼容性与 Windows 原生构建链 |
| 只用 `shared_preferences` + JSON 文件 | 与 C-NET-7「禁止直接操作文件系统」冲突，且无事务与查询能力 |
