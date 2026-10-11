# ADR-0027 文档按主题重排：事实级归属矩阵与去重

- **状态：** Accepted（2026-10-11 文档审计裁决）
- **日期：** 2026-10-11
- **关联：** ADR-0012、ADR-0013、`docs/README.md` §2.1/§6、全部 `docs/dev/*.md`、
  `AGENTS.md` §2/§4、`PLAN.md`、`CONTRIBUTING.md`、`README.md`

## 背景

ADR-0012 确立了「一主题一文档」，但主题边界只落在**文档**级，没有落到**事实**级。
2026-10-11 的第二次文档审计发现：同一事实仍在多处被复述，并已再次漂移。

| 事实 | 副本数 | 已发生的漂移 |
|---|---|---|
| 测试文件镜像 `lib/` 路径 | 4（`constraints.md` C-TEST-4、`testing.md` §3、`naming.md` §2、`test-environment.md` §4） | 各副本措辞不一，新增「设备级测试」例外时需四处同改 |
| 覆盖率 allowlist / 未测量源文件 | 6+（`testing.md` §2、C-TEST-1、`PLAN.md`×3、`test-environment.md`×2、`docs/README.md`） | 三处复述退出码与豁免类别 |
| 文档地图 | 3（`docs/README.md`、`AGENTS.md` §2、`README.md`） | `README.md` 地图与「唯一权威索引」矛盾 |
| 语言约定表 | 2（`docs/README.md` §7、`CONTRIBUTING.md` §7.2） | 内容等价、表述不同 |
| 免责声明 | 3（`README.md`、`CONTRIBUTING.md` §8、`NOTICE.md`） | 三份措辞不同 |
| `m3e_design` / `M3ESpacing` 数值 | 3（ADR-0004、`constraints.md` §6、`tech-stack.md` §3.1） | 与「一个数值只有一处定义」冲突 |
| `dynamic_color` 只能 1.x | 3（`tech-stack.md` §1.1 与 §3 ×2） | 同文件内重复 |
| `failure<PascalCaseKind>` | 4（`architecture.md` §5、`naming.md` §8、`book-source.md` §7、`tech-stack.md` §11） | 键名规则出处说法不一 |
| `riverpod_lint` 顶层 `plugins:` | 6 | — |
| `--delete-conflicting-outputs` 已失效 | 3 | — |
| Windows 开发者模式 | 4（`platform.md` §1.2 为 SSOT，另 3 处内联复述） | — |
| 「文档版本 · 最后更新」footer | 12 | 除增加同步负担外无信息量，git 已是权威历史 |

最严重的一处是**自相矛盾**：`test-environment.md` §1 写「310 用例 / `domain` 643/643」、
§7 写「280 passed / `domain` 482/482」，同一文件内两个数值。

这与 ADR-0012 记录的第一次审计是同一类缺陷：**只修矛盾、不做事实级去重，漂移必然复发。**

## 决策

1. **确立事实级归属矩阵。** `docs/README.md` 新增 §2.1「事实级归属矩阵」，逐个事实指定唯一
   定义处；其余文档一律引用（`见 <path> §N`），禁止复述。
2. **`constraints.md` 回归「约束 ID 台账」。** 每条只保留**可判定的单句规则** + 回链；
   删除与专题文档重复的代码样例（`BookSource` freezed、`Container`）与数值
   （`M3ESpacing` 六阶），改为回链 `tech-stack.md` §3.1。ID 稳定规则不变（`docs/README.md` §5）。
3. **文档地图唯一。** `docs/README.md` 是路径与职责的**唯一权威**；`README.md` 只保留指向；
   `AGENTS.md` §2 是「**何时读**」的阅读时机地图（AI 入口自包含所需），二者职责不重叠。
4. **过程记录归 `CHANGELOG.md`。** `PLAN.md` 只保留：阶段目标、交付物、验收、门禁、
   陷阱、同步清单、快速索引，外加一张**阶段状态表**；Phase 1/2 的完成记录与交接表压缩进该表，
   细节以 `CHANGELOG.md` 为准。
5. **删除全项目 12 份「文档版本 · 最后更新」footer。** 版本历史由 git 提供；footer 是
   每次改动都要同步、却无人校验的纯负担。两处**不是**版本 footer 的内容保留：
   `book-source.md` 的**语法状态说明**（在文首）与 `NOTICE.md` 的许可证清单扫描基线日期
   （其重扫比对以该日期为准）。
6. **跨文档内容各自只有一份正文：** 语言约定（`docs/README.md` §7）、免责声明与 GPL 义务
   （`NOTICE.md`）为唯一正文，`README.md` / `CONTRIBUTING.md` 只回链。
7. **文件名保持不变。** 本次不合并、不重命名任何文档：路径稳定性优先于观感，且合并会造成
   大量 ADR 回链（ADR-0017 §决策 5 → `test-environment.md`、ADR-0013 → `testing.md` 等）
   失效。**若要合并/重命名文件，必须另开 ADR。**
8. **`test-environment.md` §7 实测证据去掉重复计数**，计数（用例数、覆盖行数）唯一出处为
   §1 与最近一次 CI/本地运行结果，避免同一文件内自相矛盾。

## 后果

- 修改任一事实时只需改一处；`docs/README.md` §2.1 的矩阵是 review 时的检查点。
- `PLAN.md` 显著变短，历史过程仍可在 `CHANGELOG.md` 与 git 中回溯。
- `README.md` / `CONTRIBUTING.md` 变薄，但新手入口更清晰（先读 `README.md`，细节按需跳转）。
- 不新增依赖；不改变任何 `C-*` 的判定方式；不影响 M0/M1/M2 分期与门禁。
- 本次不触碰 `CHANGELOG.md` 与既有 ADR 正文（历史记录不重写）。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 只修 `test-environment.md` 的矛盾，不做去重 | 与 ADR-0012 的第一次审计同样短视：副本仍在，漂移会复发 |
| 合并 `testing.md` + `test-environment.md`，或重命名其它文档 | 与 ADR-0012 的路径权威冲突，且使多条 ADR 的现有回链失效；收益不足以抵消风险 |
| 保留 footer，只统一为同一版本号 | footer 无信息量，统一版本号仍需每次同步，属纯维护负担 |
| 把 `PLAN.md` 历史记录搬进 `CHANGELOG.md` | 搬运历史会打乱 `CHANGELOG.md` 的 keep-a-changelog 结构；压缩为状态表并回链更稳 |
