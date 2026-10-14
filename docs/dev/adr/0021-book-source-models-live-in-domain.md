# ADR-0021 书源模型位于 domain 实体，并携带 JSON 序列化注解

- **状态：** Accepted（2026-10-11 由架构师复审追认）
- **日期：** 2026-10-11
- **关联：** C-SRC-7、C-ARCH-1、C-ARCH-5、C-ARCH-6、C-DEP-3、`docs/dev/architecture.md` §3、
  `docs/dev/naming.md` §3/§6、`docs/dev/book-source.md` §2、ADR-0002、ADR-0019、ADR-0022

> **流程说明（不得再犯）：** 本 ADR 初版由实现者自行标为 Accepted，属流程缺陷——按
> `docs/dev/adr/README.md` 的状态定义，新例外必须先提 **Proposed**，由裁决人改为 Accepted
> 后才能落地；`CONTRIBUTING.md` §5.1 同样规定作者不能自行 Approve。架构师在 2026-10-11 的
> 复审中**追认**本决策并要求「下不为例」，故状态保持 Accepted 并保留此说明；ADR-0022 已按
> 该流程记录其裁决来源。

## 背景

Phase 2.1 落地书源模型时，三条已生效的规范互相冲突：

| 来源 | 要求 |
|---|---|
| `constraints.md` C-SRC-7 | `BookSource` 及全部子规则**必须** `freezed` + `json_serializable`；禁止手写 `fromJson` / `toJson` |
| `naming.md` §6 | `BookSource` / `SearchRule` 归在「**实体**」一行；`constraints.md` §5 给出的示例本身就是 `BookSource.fromJson` |
| `architecture.md` §3 | `domain/` **禁止包含 JSON 序列化注解**，DTO 归 `data/` |

把模型放 `domain/` 就违反 `architecture.md` §3；放 `data/` 则 `domain/` 的 `RuleEngine`
与四个 UseCase 无法消费它（C-ARCH-1 禁止 `domain` → `data` 的反向依赖）。
`docs/README.md` §6.5 规定这类冲突必须由 ADR 裁决，不得在实现中静默取舍。

同时 `book-source.md` §2 要求「未知字段必须**保留而非丢弃**，在 `extra` 中承载」，
而 json_serializable 默认忽略未识别键，需要显式设计。

## 决策

1. **书源模型位于 `lib/features/book_source/domain/entities/book_source.dart`**：
   `BookSourceType`、`BookSource`、`SearchRule`、`BookInfoRule`、`TocRule`、`ContentRule`。
2. **它们是 domain 实体**（`naming.md` §6 的「实体」），按 C-SRC-7 使用 `freezed` +
   `json_serializable`。`architecture.md` §3 的「domain 禁止 JSON 序列化注解」
   **仅对书源模型**开例外，并在该处回链本 ADR。
3. **例外不扩散**：其它领域实体（`Book` / `BookInfo` / `Chapter` 等）不得携带 JSON 注解；
   确需时必须新开 ADR。
4. **未识别键逐层保留**：每个模型带 `extra`，由生成的 `_$XFromJson` + 命名工厂
   `fromLegadoJson` 做键差集填充；`fromJson` 保持生成、不手写映射，因此不违反 C-SRC-7。
   `extra` 用 `@JsonKey(includeFromJson: false, includeToJson: false)` 排除在 JSON 之外。
5. `header` 字段的「JSON 字符串 → `Map<String, String>?`」用字段级 `JsonConverter` 完成
   （json_serializable 不读取 `JsonKey.fromJson` / `JsonKey.toJson`，见备选方案），
   仍不手写 `fromJson`。

**为什么这个例外是安全的：**

- Legado JSON 的键名就是本项目的**领域规则语言**（`RuleEngine` 直接消费规则串），
  不存在需要隔离的「外部传输格式」；
- 若拆成 `data/` DTO + `domain/` 同形实体 + Mapper，会得到两份等价模型，
  而 Phase 2 还没有导入 UI 去消费 DTO，等于生成未被生产代码使用的类（C-BAN-1）；
- `constraints.md` §5 的 C-SRC-7 示例已经是「带 `fromJson` 的书源实体」形态，
  即既有规范本身就把这条链路当作示范。

## 后果

- 审查书源模型时，JSON 注解不再算违规；`domain/` 下**其它**文件出现
  `json_serializable` 的 `fromJson` / `toJson` 仍按 `architecture.md` §3 判违规。
- **不新增依赖**：`freezed_annotation`、`json_annotation`、`freezed`、`json_serializable`
  均已在 `pubspec.yaml` 中（C-DEP-6 无需同步）。
- 覆盖门禁：`lib/features/*/domain/**` 阈值为 100%，且每个源文件都必须出现在报告中
  （ADR-0019）；模型文件必须被测试构造与解析覆盖。
- 导入以 `fromLegadoJson` 为入口，`extra` **逐层保留**未识别键（顶层 + 4 个子规则对象）。
  **导出合并尚未实现：** 生成的 `toJson` 不写回 `extra`，所以 `book-source.md` §2 的「导出时
  不丢信息」目前只兑现了一半——内存里不丢，回写合并需要导入 / 导出阶段提供
  `toLegadoJson` 之类的入口。在那之前**不得声称已可无损导出**。
- **4 个子规则的 `fromJson` 必须保留**（回应评审 F4）：它们不是预留 API，而是生成物的嵌套
  解析入口——`book_source.g.dart` 把 `ruleSearch` / `ruleToc` / `ruleContent` 写成
  `SearchRule.fromJson(...)` / `TocRule.fromJson(...)` / `ContentRule.fromJson(...)`，
  `ruleBookInfo` 写成 `BookInfoRule.fromJson(...)`。删掉任一个，freezed 就不再为该类型生成
  `fromJson`，生成物随之编译失败；它们的唯一调用者是生成物，这正是 C-SRC-7 要求的形态。
- `header` 的 `toJson` **归一化**为 Legado 的字符串形式（`jsonEncode`）：输入是对象时回写会
  变成字符串。这是刻意的——Legado 的 `header` 本身就是 JSON 字符串，对象形式只是少数分支的
  宽松接受——但它意味着「字节级原样回写」不成立；需要严格保真时由导入 / 导出阶段决定是否
  另行记录原始形态。
- **复审触发条件（例外不得永久化）：** 出现下列任一情形必须重评本 ADR——
  (1) Phase 5 的导入 UI 需要 DTO 隔离（例如导入校验 / 预览要与领域模型解耦）；
  (2) `RuleEngine` 不再直接消费规则串（例如规则先编译成中间表示）；
  (3) `data/` 出现第一个真实消费方，使同形 DTO 不再触及 C-BAN-1。
- 该 `extra` 机制只覆盖**已建模层级**：尚未建模的 `@put:` / `@get:` 变量、
  `exploreUrl` 等 M1/M2 字段同样落进 `extra`，因此不会因分期而丢失。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| `data/` 放 DTO、`domain/` 放同形实体 + Mapper | 两份等价模型 + Mapper，Phase 2 无生产消费方（C-BAN-1）；书源 JSON 就是领域规则语言，隔离不带来收益 |
| 模型放 `domain/` 但去掉 JSON 注解，解析全交给 `data/` | 直接违反 C-SRC-7；且 `data/` 仍需一份带注解的镜像模型，回到上一行的成本 |
| 手写 `fromJson` 以顺带填充 `extra` | C-SRC-7 明确禁止手写 `fromJson` / `toJson` |
| 用 `JsonKey(fromJson: ..., toJson: ...)` 解析嵌套规则与 `header` | json_serializable 只读取 `JsonKey` 的 `name` / `defaultValue` / `includeFromJson` 等字段，**不读取** `fromJson` / `toJson`（已核实 `json_key_utils.dart`）；唯一受支持的机制是 `JsonConverter` |
| 用「整类转换器」承载原始 map 来实现 `extra` | 与生成的 `fromJson` 职责重叠，且会让 C-SRC-7 要求的 `fromJson` 失去意义 |
| 现在就实现 `toLegadoJson` 合并 `extra` | 会产生一个没有生产消费方的公共 API（C-BAN-1、`PLAN.md` Phase 2「禁止做任何『以后会用到』的抽象」）；合并语义应由导入 / 导出功能按真实需求定义 |

---

## 复审注记（2026-10-14，Phase 5 的 P5-0；架构师待裁决）

**触发：** §后果 的两个条件同时命中——**(1)** 导入 UI 来了（`PLAN.md` §3.6 的 5.1）、
**(3)** `data/` 出现第一个真实消费方（5.1 的 `BookSourceRepositoryImpl` + Drift 的 `book_sources` 表）。

**结论：例外保持，不拆「DTO + 同形实体 + Mapper」。**

- 决策 3「例外不扩散」不变：其它领域实体仍不得携带 JSON 序列化注解。
- 触发条件 (3) 的本意是「同形 DTO 不再触及 C-BAN-1」，而 5.1 的做法是 **`data/` 直接消费
  `domain/` 的书源模型**（仓储把模型序列化进 `payload` 列、读回时反序列化，ADR-0040 §决策 4），
  因此根本不存在第二份同形模型——C-BAN-1 的问题没有重新出现，例外也没有扩散的必要。
- 决策 4 的 `extra` 逐层保留继续有效；**导出回写（`toLegadoJson`）仍缺**，其落点改为
  `PLAN.md` §3.6 的 5.8，并以导入时落库的原始负载列为导出源。
- **触发条件重写（本注记生效后取代 §后果 的原三条）：** (1) 导入**预览 / 校验**需要与领域模型
  解耦（例如要在不构造 `BookSource` 的前提下展示差异）；(2) `RuleEngine` 不再直接消费规则串
  （规则先编译成中间表示）；(3) 出现**第二个** consumer 需要一份与领域模型不同形的书源表示
  （例如按规则字段拆表检索）。
