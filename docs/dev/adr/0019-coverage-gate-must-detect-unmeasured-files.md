# ADR-0019 覆盖率门禁必须检测「未出现在报告中的源文件」

- **状态：** Accepted
- **日期：** 2026-10-11
- **关联：** C-TEST-1、C-TEST-7、`docs/dev/testing.md` §2/§7、`tool/check_coverage.dart`、`PLAN.md` 铁律二、ADR-0017

## 背景

Phase 1.1 实测发现覆盖率门禁存在**静默绕过**：

1. 新增 `lib/core/error/parse_result.dart`（89 行，含 `enum` 与扩展方法）后，
   在**没有任何测试加载它**的情况下执行 `flutter test --coverage` +
   `dart run tool/check_coverage.dart`，结果为：

   ```
   core    100.00%  need >= 100%  lines 4/4  OK      # exit 0
   ```

   且 `coverage/lcov.info` 中**根本不存在** `SF:lib/core/error/parse_result.dart` 记录。

2. 原因是 lcov 只统计**运行期被加载过**的库：未被任何测试 import 的生产代码
   完全不出现在报告里，既不计入分母也不报错。
3. 这与 `PLAN.md` 铁律二的表述（「覆盖率门禁会在你新增任何 `lib/core/**` 文件的瞬间变红」）
   直接矛盾，也架空了 C-TEST-1：只要「忘记写测试」，门禁反而更容易通过。

## 决策

1. `tool/check_coverage.dart` **增加「未测量源文件」检查**：遍历
   `lib/core/**`、`lib/features/*/domain/**`、`lib/features/*/data/**` 下的
   Dart 源文件（排除生成物与 `generated/`），逐个确认其出现在覆盖率报告中；
   缺失即判失败。
2. 引入**显式 allowlist**：`tool/coverage_allowlist.txt`，每行一个仓库相对路径，
   `#` 起注释。仅允许三类文件进入 allowlist，且必须在该文件的 `#` 注释里写明原因：
   - 仅在特定平台/条件编译下可达的文件（例如 `Platform.isXxx` 分支的独立实现文件）；
   - 依赖真实设备或原生库、只能在 `integration_test` 中执行的入口文件
     （例：`lib/core/di/database_executor_provider.dart`——drift_flutter 的后台 isolate
     在 `flutter test` 里必然报 `Channel was closed`）；
   - **代码生成器的输入文件**：其中的声明只在生成期被分析、运行时不可达
     （例：`lib/core/storage/cache_entries.dart`——drift 官方在 `columns.dart` 里明确说
     列构建器的方法「not meant to be called at runtime」，`ColumnBuilder` 是空标记类）。
     此类文件必须用 `// coverage:ignore-file` 使 lcov 将其整体移除，否则仍会因
     阈值失败；其正确性必须由别的测试保证（例：drift 表结构由 `drift_schemas/`
     与 `migration_test.dart` 逐列比对）。

     > **2026-10-11 修订（「无可测量行」子情形）：** 本类还有一个子情形——**源文件里不存在
     > 可测量的行**。纯 `freezed` 声明式实体（例：
     > `lib/features/book_source/domain/entities/book.dart`）只有重定向工厂声明，方法体由
     > 生成器内联到 `*.freezed.dart`；它在运行时**是被构造的**（`book_test.dart` 就构造它），
     > 但源文件本身没有可测量的行，lcov 不收录它，于是同样命中「未测量源文件」。
     > 登记要求不变：`// coverage:ignore-file` + allowlist 行内理由 + 行为由别的测试保证。
     > 与 drift 表定义的区别只在「为什么没有可测量的行」：drift 是「运行时不可达」，
     > freezed 是「无可测量行」。Phase 3 起每新增一个纯 freezed 实体均按本子情形登记，
     > 不再逐个重新论证。
   allowlist **不得**用于「暂时没写测试」的文件；新增条目必须在 PR 描述中说明。
   （同样适用于使用了 `// coverage:ignore-file` 的手写文件：lcov 会把它整体移除，
   因而必须登记才能通过门禁。）
3. 退出码扩展为：`0` 通过 · `1` 低于阈值 · `2` 报告缺失 · **`3` 存在未测量源文件**。
   allowlist 中的文件若**出现在**报告中，同样判失败（说明 allowlist 已过期），
   避免 allowlist 永久累积。
4. 检查默认根目录为 `lib/`，可用 `--lib=` 覆盖；allowlist 可用 `--allowlist=` 覆盖，
   传空字符串表示「不使用 allowlist」，便于排查。
5. 门禁的**行为描述**只在 `docs/dev/testing.md` §2 维护；`PLAN.md` 铁律二改为
   「新增 `lib/**` 源文件必须与测试同 PR，否则门禁以退出码 3 失败」，不再声称「变红」，而是
   给出可执行的判据。

## 后果

- 「忘记写测试」从**静默通过**变为**显式失败**，C-TEST-1 从「测了就要达标」
  扩展为「必须被测到」。
- 每个新增的 `lib/core/**` 文件都必须要么有测试、要么进 allowlist 并给出理由，
  这与 `PLAN.md` 铁律二、C-TEST-4（ADR-0017）形成闭环。
- CI 需要一次额外遍历 `lib/`，成本可忽略；退出码 3 与阈值失败（1）区分开，
  使排障时能一眼看出是「没测到」还是「测了但不够」。
- 该检查是**路径级**的，不做分支级判定；分支覆盖率仍不在本项目门禁范围内
  （`testing.md` §2 只定义行覆盖率）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 只把 `PLAN.md` 铁律二改成「门禁不会报警」 | 把已知的绕过点写成文档，等于承认 C-TEST-1 只能靠自觉 |
| 用 `--coverage-ignore-files` / 白名单排除整个目录 | 粒度太粗，会把真实缺口一起排除 |
| 改用 `very_good_coverage` 等第三方门禁 | 新增依赖（C-DEP-1），且同样不解决「未测量文件」问题 |
| 用 `dart test --reporter=json` 自行统计 | 需替换 Flutter 测试链路，收益不明，风险高 |
