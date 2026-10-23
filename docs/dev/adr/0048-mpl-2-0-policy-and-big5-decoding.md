# ADR-0048 许可政策：MPL-2.0 进入允许族，且只按白名单放行（`enough_convert` 提供 Big5 解码）

- **状态：** Accepted（2026-10-21，M12 规格前置；用户裁决「改 C-DEP-7 允许 MPL，引 `enough_convert`」）
- **日期：** 2026-10-21
- **关联：** C-DEP-1、C-DEP-7、C-NET-3、ADR-0022、ADR-0031、ADR-0047 §决策 8、
  `NOTICE.md` §5 / §6、`docs/dev/book-source.md` §5 / §5.1、`docs/dev/tech-stack.md` §5、`tool/scan_licenses.dart`

## 背景

`book-source.md` §5.1 把 **Big5 / Big5-HKSCS 既不能检测也不能解码** 登记为已知缺口：本仓的检测器
（`betto_charset_detector 0.1.0`）候选表里没有 Big5，解码器（`charset 2.0.1`）也没注册任何 Big5 编码。
真实语料里繁体站点存在，缺口的后果是整条源 `encodingFailed`。

补解码有两条路：

1. **自己写码表**：把 Unicode Consortium 的 `BIG5.TXT` 生成成 Dart 表（约 1.3 万条映射 + HKSCS 扩展）。
   数据许可宽松、不碰项目政策，但仓库体积（数百 KB 生成物）与维护成本都要自己扛。
2. **引依赖**：`enough_convert 1.7.1` —— 纯 Dart、**零依赖**、Dart 3.11+、覆盖 ISO 8859 / Windows / DOS /
   **GBK / Big5** / KOI8，`Big5Codec` 还带 `allowInvalid` 宽容开关（正好对上 ADR-0031 的两条车道）。
   代价是它是 **MPL-2.0**，而本仓的自定规则把 MPL 与 GPL 一起列进了「禁止引入」。

用户据此裁决走路线 2，并授权修改项目自己的许可政策。**政策变更本身比依赖更需要记录**，所以有本 ADR。

## 决策

### 决策 1 MPL-2.0 与 GPL-3.0 兼容，允许引入

- MPL-2.0 是 FSF 认定的自由许可，且与 GPLv3 **兼容**：MPL-2.0 §3.3 的 "Secondary License" 机制明确允许
  把 MPL 代码并入更大的 GPL 作品（本仓对外是 `GPL-3.0`）。因此「本仓是 GPL-3.0」这一事实不构成障碍。
- 与 GPL-2.0-only 的区别要写清楚：**GPL-2.0-only 仍然禁止**（与 GPL-3.0 不兼容），这次只放出 MPL。
- MPL 是**文件级** copyleft：我们把 `enough_convert` **原样**当 pub 依赖使用（不修改、不复制进 `lib/`），
  所以它的源码义务由 pub 包自身满足；`NOTICE.md` §5 记录它 + 版权声明即可，无需在仓库内附加 MPL 文本
  （原文随包分发在 pub cache / 锁文件解析得到）。

### 决策 2 放行是**白名单**，不是把 MPL 加进宽松族

`tool/scan_licenses.dart` 的改动是：

- `_forbiddenFamilies` 从 `{GPL, MPL, UNKNOWN}` 变成 `{GPL, UNKNOWN}`；
- 新增 `_mplAllowList = {'enough_convert'}`；
- 分类到 MPL 但**不在**白名单里的包仍然进 `risky items` 并让脚本退出码非 0。

也就是说：政策从「MPL 一律禁止」改成「MPL 只能按 ADR 白名单引入」，而不是「MPL 等同 MIT」。
下一个 MPL 依赖必须再写一次 ADR 并加进白名单——这正是白名单存在的意义。

### 决策 3 只补**解码**，不补**检测**

- `charset_decoder.dart` 新增 `_encodingOf(label)`：先问 `charset`，再问 Big5 家族
  （`big5` / `big5-hkscs` / `cp950` / `csbig5` → `Big5Codec`）。严格车道与宽容车道共用这一个入口，
  所以两条车道不会对「哪些标签可解码」产生分歧。
- 宽容车道新增 `Big5Codec(allowInvalid: true)`：已声明车道的坏字节 → U+FFFD + warning（与 GBK 同形）。
- **检测能力没有变化**：`betto_charset_detector` 仍不认识 Big5，`Content-Type` / `<meta>` / URL 规则
  都不声明时，页面不会被「自动猜成 Big5」。单测 `decodeBody_givenAnUndeclaredBig5ByteStream_doesNotGuessBig5`
  钉住这一点，免得把「补了码表」误读成「缺口全闭」。
- **Big5-HKSCS 是部分支持**：HKSCS 扩展区不在码表里，解成 U+FFFD。`book-source.md` §5.1 的表格按此改写。

### 决策 4 顺带确认：`shift-jis` / `euc-jp` 的 `RangeError` 不在本轮

`enough_convert` 不含日文码表，`charset` 的两个日文解码器在遇到孤立前导字节时抛 `RangeError`
（`Error`，ADR-0022 禁止捕获）。本轮**不**改用 `enough_convert` 的日文路径（它没有），
也**不**引入字节预校验层：语料里 0 条日文源，收益无法验证。登记保持原样（`book-source.md` §5.1）。

## 影响

- `pubspec.yaml` 新增 `enough_convert: ^1.7.1`（**新增依赖 → C-DEP-1**：纯 Dart、零传递依赖、
  `sdk: >=3.11.0`，与 `pubspec.yaml` 的 `^3.13.0` 兼容）。
- `tool/scan_licenses.dart`：白名单机制（见决策 2）。
- `lib/core/network/charset_decoder.dart`：`_encodingOf` + Big5 宽容分支。
- `NOTICE.md` §5 / §6：基线由 165 包 / BSD-3 104 / MIT 37 / Apache 10 / BSD-2 6 / SDK 8
  变为 **166 包 + MPL 1（`enough_convert`）**；§6 的分类步骤补「MPL 白名单」一步。
- `docs/dev/constraints.md` C-DEP-7 与 `docs/dev/tech-stack.md` §5 的许可表同步。

## 证据

- `dart run tool/scan_licenses.dart` → `Risky items: none.`，计数 104 / 37 / 10 / 6 / 1 / SDK 8 = 166。
- 字节级语料：`天` 的 Big5 字节是 `[0xA4, 0xD1]`（用 `Big5Codec().encode('天')` 反算确认）；
  `decodeBody(_big5Tian, contentType: 'text/html; charset=big5')` → `天`；
  `charset=big5-hkscs` + 扩展区字节 → 常用字解出、扩展区 U+FFFD；
  无声明时**不**解成 `天`（检测仍不认识 Big5）。

## 后果

- 好的方面：繁体书源从「整条失败」变成「可读」；顺带拿到一个更完整的 GBK 码表
  （本仓仍用 `charset` 的 GBK，避免同一标签两套结果）。
- 代价：项目多了一个许可族例外，必须靠白名单守住；`NOTICE.md` 的每次发布前扫描多一步人工确认
  「MPL 计数是否仍只有 1」。
- 未闭环：Big5 的**检测**、Big5-HKSCS 扩展区、日文 `RangeError`（见决策 4 与 `roadmap.md` §3.7）。
