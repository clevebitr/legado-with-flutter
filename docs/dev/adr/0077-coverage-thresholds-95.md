# ADR-0077 覆盖率阈值：`core` / `domain` 由 100% 下调到 95%

- **状态：** Accepted（2026-10-25，用户裁决：下调到 95% + 写 ADR，`data` 层维持 ≥80%）
- **日期：** 2026-10-25
- **关联：** C-TEST-1、C-TEST-2、C-TEST-3、`docs/dev/testing.md` §2/§8、`tool/check_coverage.dart`、ADR-0019、ADR-0017

## 背景

`core` / `domain` 的 100% 行覆盖率门禁已经**饱和**：门禁运行结果显示
`core 100.00% 2643/2643`、`domain 100.00% 4636/4636`，说明「每一行都必须被执行」
成了硬约束。它带来的实际后果：

1. **为覆盖率而写的测试**：`copyWith` / `==` / `hashCode` / 纯 getter / DI 装配这类
   没有行为可言的代码，各自占一个 `test`；`test/features/rules/domain/usecases/import_replace_rules_test.dart`
   甚至要注释说明「故意不用 `const`，否则常量构造被折叠、那两行没有执行点，域层 100% 门禁会失败」
   （`test/core/platform/secret_store_test.dart`、`test/core/network/request_limiter_test.dart`
   有同类注释）。这类测试断言的是「这一行跑过了」，不是「行为正确」。
2. **测试规模失控**：`test/` 有 232 个文件、2367 个用例、51.5k 手写行，与 60.7k 手写生产行
   之比接近 0.85:1；`flutter test` 时长与维护成本都随之上涨。
3. **单点改动的连带成本**：一个纯 plumbing 方法改名会牵动一堆「覆盖该行」的用例，
   修改者无法判断哪些用例真的在守行为。

`data` 层不受此问题支配：它是 95.65%，阀值 80%，本就有余量。

## 决策

1. `tool/check_coverage.dart` 默认阈值改为 **`core` 95%、`domain` 95%、`data` 80%**
   （唯一实现处），`docs/dev/testing.md` §2 同步。
2. 空出的 5% 只用于**删除无行为可言的用例**（plumbing / `copyWith` / equality /
   DI 装配 / 为凑执行点而造的构造方式），**不得**用于「新功能先不写测试」：
   ADR-0019 的**「未测量源文件」判定不变**，新增生产文件仍必须有测试加载它。
3. 阈值仍然「可上调、不可下调」：再降需另一份 ADR（同 `docs/dev/testing.md` §2 现有规则）。
   `docs/dev/testing.md` §8 的「禁止为了门禁通过而降低阈值」保留，但措辞改为回链本 ADR，
   区分「按 ADR 调整策略」与「临时闸门降阈值」。
4. 本次同时执行测试整理（同批 PR）：合并同页面拆分的 Widget 测试文件、
   把同构用例改成表驱动、把 4 个 use case 重复的失败路径收敛成 `test/support/` 的共享契约 harness。
   整理**不改变** C-TEST-2（每个页面至少一个 smoke）与 C-TEST-3（`方法名_场景_预期结果`）。

## 后果

- 正向：可以只剩下「有行为」的测试；估算可减 8–12k 行测试代码与 ~300 个用例，
  同时保留 100% 行为守护的类（请求限制器、规则引擎矩阵、缓存 TTL 等）。
- 负向：`core` / `domain` 可能留有 5% 未被执行的行。缓解：本 ADR 已有三条约束
  （新文件必须被加载、阈值只能升、每次下调需新 ADR），且 `data` 80% 的宽松阀值早在 ADR-0019
  里就被证明足以拦住「写了不给测」。
- 本 ADR 不触及 `integration_test/`（不进 CI，见 ADR-0017 §决策 5）。
