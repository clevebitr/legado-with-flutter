# ADR-0031 编码宽容只对「已声明」车道开放：声明权威 + 宽容解码 + warning，嗅探与回退车道保持严格

- **状态：** Accepted（2026-10-11 架构师裁决；用户指令「在 main 分支更新 ADR，允许宽容编码」）
- **日期：** 2026-10-11
- **关联：** C-NET-3、C-ERR-8、C-SEC-4、C-SRC-4、ADR-0006、ADR-0019、
  `docs/dev/book-source.md` §5/§5.1/§7、`docs/dev/constraints.md` C-NET-3、`PLAN.md` §3.4（G2b）

## 背景

G2b 真实站点 spot-check 撞上一个在野外很常见的情形：**页面声明了 UTF-8，但正文里有个别非法字节**
（常见的来源是站点数据库里混入 GBK 残片、被截断的多字节序列、或坏掉的控制字符）。按现口径
（`book-source.md` §5 第三条 + C-NET-3）：

> 解码失败返回 `ParseFailure(encodingFailed)`，禁止用 `utf8.decode(allowMalformed: true)` 静默吞掉。

结果是**一个字节废掉整本书的详情页**：搜索页与目录页能读，详情页整段失败。这不是安全边界，
而是把「页面 99.9% 可读」和「页面根本解不开」当成了同一件事。

但现口径的存在也有理由：`allowMalformed` 会把**猜错的编码**伪装成成功——满屏乱码进正文，
比响亮失败更糟（C-SRC-4 的同一精神）。这两件事必须分开处理，因为它们的前提不同：

| 车道 | 前提 | 宽容的后果 |
|---|---|---|
| **已声明**（HTTP `Content-Type` / `<meta charset>`） | 编码是**权威声明**，服务端说得很清楚 | 宽容只处理「声明正确、个别字节损坏」，最坏是几个 U+FFFD |
| **嗅探**（`betto_charset_detector`） | 编码是**猜测** | 宽容会把猜错变成乱码成功，把问题藏起来 |
| **未知标签回退 UTF-8** | 也是猜测（声明了但我们不认识） | 同上 |

实现层面已核实可行（2026-10-11，`charset 2.0.1` 本地 pub cache）：本仓可解码的每个编码族**都有宽容入口**——`GbkCodec(allowMalformed: true)`、`EucJPCodec(allowMalformed: true)`、
`EucKRCodec(allowInvalid: true)`、`ShiftJISCodec(allowMalformed: true)`、
`CodePage.decode(..., allowInvalid: true)`、`utf8.decode(..., allowMalformed: true)`。
因此宽容解码**不必**退化成「一律按 UTF-8 宽容」。

> **复审更正（2026-10-12，架构师审核 R3；G2b spot-check 实测推翻本段初稿的表述）：**
> 上面「每个族都有宽容入口」只说对了 **codec 层**，**不等于本仓可达**——初稿把两件事当成一件，
> 这是**本文档的错误**。实测：`shift-jis` / `euc-jp` 的**严格**解码在字节不完整时抛 `RangeError`
> （`Error`，ADR-0022 禁捕获），而本文档的宽容路径只从 `FormatException` 进入，因此**永远到不了**；
> `euc-kr` 的解码器静默丢弃非法字节，**没有可宽容的失败点**；`us-ascii` / `utf-16` / `utf-32`
> 虽有入口但本仓**刻意不用**（声明它们却解不开，说明声明本身错了）。
> **实际可宽容的只有 `utf-8` 与 `gbk`**；哪个族属于哪一类（不可达 / 刻意排除）的**唯一出处是
> `docs/dev/book-source.md` §5.1**，本文档不复述那张表。§决策 1 的「按声明出的编码族宽容解码」
> 因此应读作「按 §5.1 判定为可宽容的族」。

## 决策

1. **宽容解码只对「已声明」车道开放**：`Content-Type` 的 `charset` 参数与 HTML `<meta charset>`
   两条车道，解码时按**声明出的编码族**宽容解码（非法字节 → U+FFFD），成功返回**并记一条 warning**。
   哪些族实际可宽容（以及哪些属于不可达、哪些属于刻意排除）**以 `docs/dev/book-source.md` §5.1 为准**，
   本文档不另立清单。
2. **warning 必须可定位、可解释，且不得泄露内容**：携带书源 ID、目标 URL 摘要、字段路径
   （C-ERR-8、C-SRC-8），**禁止**包含页面正文、Cookie、Token（C-SEC-4）。措辞必须说明
   「声明编码 N，其中 M 字节非法，已按宽容模式解码」，不得写成无信息的「decode warning」。
3. **嗅探车道与未知标签回退保持严格**：解码失败仍是 `ParseFailure(encodingFailed)`（§7 不变）。
   理由见背景表：宽容只能建立在**权威声明**之上；猜测 + 宽容 = 把乱码当成功。
4. **禁止「一律 UTF-8 宽容解码」**：宽容必须仍走**声明出的编码族**；不得把未知标签、嗅探结果或
   失败一律兜到 UTF-8 宽容路径。`book-source.md` §5.1 的缺口（Big5 系既不能检测也不能解码）
   不因本 ADR 改变。
5. **检测顺序不变**：HTTP `Content-Type` → `<meta charset>` → 字节嗅探 → 回退 UTF-8（§5 的
   第一条仍是唯一出处）。本 ADR 只改**解码失败**这一段的判定，不改选择顺序。
6. **不新增 `ParseFailureKind`**：9 个 kind 与触发条件仍归 §7；宽容成功不是失败，故不产生新 kind。
7. **一个页面至多一条 warning**：解码在每次响应上只发生一次（`decodeBody` 的调用点唯一），
   实现不得让同一页的多个字段各记一条。

## 后果

- `book-source.md` §5 的第三条要改写成**按车道**表述（§5 是编码规则的唯一出处，本 ADR 不复述
  车道顺序与缓存口径）；C-NET-3 只保留「必须经检测 + 禁止假设 UTF-8」并回链 §5。
- `PLAN.md` §3.4 的 spot-check 步骤可以继续用该站点：页面按宽容模式可读，但**记录里必须写明
  「该页含非法字节」**——宽容是登记过的降级，不是「一切正常」。
- 实现方（`lib/core/network/charset_decoder.dart`）需要一条**按族的宽容路径**；各族宽容入口见
  §背景。若某族确实没有宽容入口，该族在声明车道仍以 `encodingFailed` 失败，并**必须登记到
  §5.1**，不得假装覆盖。
  > **交接项（C-DOC-1）：** 实现宽容路径时必须**同步改写**两处与旧口径一致的代码注释，否则公共 API
  > 的文档与行为不符：`lib/core/network/charset_decoder.dart` 的 `///`（现文写
  > 「must not hide it behind `allowMalformed`」）与 `lib/core/network/http_client.dart` 的解码失败
  > 分支注释（现文写「解码失败必须显式失败，禁止用 allowMalformed 静默吞掉」）。
  > 两处都要改成**分车道**表述，并指向 `book-source.md` §5。
- 新增分支意味着 `lib/core/**` 仍须 100% 行覆盖（ADR-0019、C-TEST-1），验收测试至少覆盖：
  声明 UTF-8 + 非法字节 → 成功 + warning（断言 warning 含书源 ID 与字段路径、不含正文）；
  声明 GBK + 非法字节 → 成功且其余文本正确；无声明 + 非法字节 → `encodingFailed`；
  未知标签 → 仍回退 UTF-8，且严格失败时仍 `encodingFailed`；宽容结果中的非法字节为 U+FFFD
  且**不丢字节**（不得导致文本错位）。
- 反过来的风险被明确接受：声明正确、页面**大面积**损坏时，宽容会产出一段带大量 U+FFFD 的正文。
  这比整页失败更符合阅读场景（用户至少能读到能读的部分），但**必须**由第 2 条的 warning 留下痕迹。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 维持「解码失败即 `encodingFailed`」不变（spot-check 换站点） | 把「页面 99.9% 可读」与「页面解不开」当同一件事；真实站点里个别坏字节很常见，等于把一整类站点判死，且这是**可用性**损失而非安全收益 |
| **一律**宽容（含嗅探车道） | 猜测 + 宽容 = 猜错编码时产出满屏乱码却报成功，正是 C-SRC-4 禁止的静默错误；也违反 C-NET-3「禁止假设 UTF-8」的精神 |
| 宽容但不记日志 | 变成静默降级，违反 C-SRC-4 的「显式降级 + 记录」（ADR-0026 的同一模式） |
| 只在 `utf-8` 上宽容 | 真实坏字节不只出现在 UTF-8 页；且 `charset 2.0.1` 的各族都有宽容入口（见背景），没有理由只做一族 |
| 把宽容结果也标成 `encodingFailed` 之外的「部分成功」新 kind | 需要动 §7 的 9 个 kind 集合与 ARB 文案表，收益只是措辞；宽容成功就是成功，痕迹由 warning 承担 |
