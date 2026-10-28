# `tool/bench/`：引擎性能基准（P1–P6）

> 本文是**基准脚本的口径与实测记录**：怎么跑、每一项量的是什么、改前/改后的数字。
> 指标定义与阈值的唯一出处是 `docs/dev/adr/0078` 决策 4，**不在本文重复裁定**；
> 与上游的行为差异归 `docs/dev/book-source.md` 与 `docs/dev/engine-parity.md`。
>
> 它**不是测试**：`docs/dev/testing.md` §1 禁止测试联网、也不让基准拖慢 CI，
> 所以这里是 `tool/` 入口（与 `tool/spot_check/`、`tool/spike/` 同一模式）——不被
> `flutter test` 发现，不进 CI。

---

## 1. 为什么需要它

M25 把「与上游几乎一致」做成了可复核的事实，M26 要证明「同一行为更快」。既然允许重构引擎内核
（ADR-0078 决策 3），就必须先有**改前数字**，否则「更快」只能靠体感，也没法在 PR 里复核。

两条纪律（ADR-0078 决策 3/4）：

1. **行为与性能不互相让步**：基准数字变好不能以放宽任何行为为代价。冲突时以行为测试为准，
   做不到就登记为「已知热点」（`docs/dev/engine-parity.md` §11）而不是改阈值。
2. **数字只在实测后收紧**：阈值改动只能朝更严的方向，放宽要新 ADR。

---

## 2. 怎么跑

**标准跑法（两步，构建一次约 30 s，跑一次约 3 s）**

```bash
# 1) 用基准入口构建 release 产物（会覆盖 build/.../Release/flutter_reader.exe）
flutter build windows --release -t tool/bench/bench.dart

# 2) 直接跑产物：全套 P1/P2/P3，落一份 JSON 报告
BENCH_ARGS="--out=build/bench-baseline.json" \
  ./build/windows/x64/runner/Release/flutter_reader.exe

# 只跑一项 / 改采样次数
BENCH_ARGS="--only=p1,p3 --iterations=50 --warmup=5" \
  ./build/windows/x64/runner/Release/flutter_reader.exe
```

为什么不是 `flutter run -d windows --release`：**`--release` 下这个进程没法干净退出**。AOT + 嵌入器里
`exit()` 会卡在 VM 关闭阶段（最小复现：`main` 只做 `WidgetsFlutterBinding.ensureInitialized(); exit(0);`
也照样挂住），而 `flutter run` 收不到断开事件就会一直等下去。所以脚本收尾时**直接结束自己的进程**，
直接跑产物会立刻返回；用 `flutter run` 那条路则要手动 Ctrl-C。

> 两条连带后果：
> ① 这个进程的**退出码没有意义**（自己 kill 自己），成败只看 stdout 的表格与 `--out` 报告；
> ② 构建产物被换成了基准入口，之后要跑 App 得用默认入口重建（`flutter build windows --release`）。

仍然**不能**用 `dart run`：引擎的 `@js:` 路径与 `AppLogger` 都要 Flutter 运行时
（`flutter/foundation`、`flutter_qjs_next` 的原生库），`dart run` 在 `dart:ui` 上直接编译失败
（同因见 `tool/spot_check/README.md` §2）。

| 选项 | 含义 | 默认 |
|---|---|---|
| `--only=` | 逗号分隔的指标子集（`p1` / `p2` / `p3`） | `p1,p2,p3` |
| `--iterations=` | 每项的有效采样数（P3 实际取 ×10，它读计数器不读耗时） | `20` |
| `--warmup=` | 丢弃的前若干次（JIT / 页缓存预热） | `3` |
| `--out=` | JSON 报告路径（目录会自动创建） | 不写盘 |

两条硬性约定：

1. **必须是 `--release`**。debug 模式下同一链路慢 5–20 倍，数字没有可比性；脚本会在表头打印
   `release=true/false`，贴记录时一并贴上。改脚本本身时可以临时用 `flutter run`（debug）确认它跑通，
   但数字不能取自 debug。
2. **选项走 `BENCH_ARGS`**：桌面宿主不会把命令行参数转发给 Dart 入口，与 `SPOT_CHECK_ARGS`
   同一约定。

---

## 3. 每一项量的是什么

脚本文件：`tool/bench/bench.dart`（单文件；夹具是确定性生成，不往仓库塞 200 KB 的页面）。

| 指标 | 脚本里的项 | 口径 | 目标（ADR-0078 决策 4） |
|---|---|---|---|
| **P1** | 解析 / 提取 / `replaceRegex` / total | 单章 ≤200 KB HTML，规则 3 段（`id.content@tag.p@text`），走 `PageFetchService.content` + `htmlToText` + `replaceContent`，**不含网络** | ≤ 40 ms |
| **P2** | CSS：解析 / 列表 / 字段 ×2 / total；正则：列表 / 字段 ×2 / total | 1000 章目录，两种列表规则形态（CSS `id.list@tag.dd` 与 `:正则` 链），字段按 `FetchToc._entries` 的形状每条读两次 | ≤ 300 ms |
| **P2 线性度** | `linearity` 表 | 250 / 500 / 1000 / 2000 章同一链路，看**每章 µs** 是否同量级（O(n²) 会成倍增长） | 近似线性 |
| **P3** | `ruleCompile` 计数 | 同一批规则文本反复求值的 `compilations / lookups`；三种编译形态各一条（CSS 选择器、JSONPath、正则链） | 命中率 ≥ 95% |
| **P4** | **待接**（见 §6） | 「一页只 parse 一次」要数 `PageFetchService` 侧的解析次数 | — |
| **P5** | JS job 往返 + 内联覆盖 | 真 worker 的空脚本 job 往返（`--only=p5`）；内联覆盖用 `RuleEngine.inlineStats` 的 `inlined / (inlined + bridged)` 计数 | ≤ 3 ms；覆盖 ≥ 95% |
| **P6** | 常驻增量 | `--only=p6`：`ProcessInfo.currentRss` 前后相减（单章 / 千章目录各一轮） | 单章 ≤ 8 MB、千章目录 ≤ 32 MB |

已知的口径边界（不是缺陷，刻意留白）：

- **不含网络**：P1/P2 都不发请求。目录/正文翻页并发（R4）要用真实响应时间才看得见，
  它属于 M27 的 L1 链路，不在这里。
- **不含 JS job**：P1/P2 的规则没有 `@js:` 段，因此数字里没有 worker 往返；这正是 P5 单独成项的原因。
- **P6 没有「峰值」**：Dart 侧拿不到 GC 钩子，所以只能记 RSS 前后差值的「首次 / 后续中位 / 最大」。
  首次近似工作集，后续中位数才是「重复一次操作的净增长」（>0 才可疑）。Android 真机的内存数据
  仍按 ADR-0078 决策 4 的原文走 `integration_test` 设备级用例，本脚本给的是桌面 release 数字。
- **P2 的字段只读 2 个**（章名 + 地址）：真实 `FetchToc` 还会读 `isVip` / `isPay` / `updateTime` 等可选字段。
  条目的求值成本与条目数成正比，所以省略它们不改变线性度结论，但绝对数字会偏低。
- **P3 的「会话」是近似的**：一次 `flutter run` = 一次进程 = 一次会话；脚本在同一个引擎实例上反复
  求值同一批规则，等价于「一本书的一次会话里同一条规则被反复读到」。

---

## 4. 夹具

`tool/bench/bench.dart` 里的 `_chapterHtml()` / `_tocHtml()` 就地生成，**逐字节确定**
（没有随机数、没有时间戳），所以两台机器上的输入完全一样：

| 夹具 | 形状 | 大小 |
|---|---|---|
| 单章页 | `div#content` 下 500 个 `p.line`（每段 5 句中文）+ 脚本 / 样式 / 「本章未完」广告行 | **199.7 KB** |
| 目录页 | `div#list > dl` 下 1000 个 `dd > a[href]` | 86.9 KB |

为什么不入库真实页面：仓库不引入第三方站点内容（C-SEC-4 的精神，ADR-0023 决策 2），
而「同一条命令在任何机器上量同一份输入」比「页面长得像真的」更重要。规则文本本身取自语料里的
真实形状（正文 3 段、`id.list@tag.dd`、`:正则` 链）。

---

## 5. 数字（改前 → 改后）

### 5.1 改前基线（2026-10-28，R1 之前）

> 机器：Windows 11，Flutter 3.47.7 / Dart 3.13.5，`--release`，`--iterations=20 --warmup=3`。
> 复跑两次（`build/bench-baseline.json` / `build/bench-baseline-2.json`），p50 差异 ≤ 1.2%。

| 指标 | 项 | 目标 | n | min | **p50** | p95 | max |
|---|---|---|---|---|---|---|---|
| P1 | 解析 HTML（199.7 KB 页） | — | 20 | 2.51 | 2.60 | 2.85 | 3.12 |
| P1 | 提取（`id.content@tag.p@text`） | — | 20 | 3.40 | 3.59 | 3.69 | 3.73 |
| P1 | `replaceRegex` + `htmlToText` | — | 20 | 0.10 | 0.10 | 0.13 | 0.14 |
| P1 | **total：解析 → 提取 → `replaceRegex`** | ≤ 40 ms | 20 | 6.05 | **6.31** | 6.66 | 6.86 |
| P2 | 目录页解析（1000 章） | — | 20 | 5.01 | 5.12 | 7.27 | 7.29 |
| P2 | CSS 列表规则 | — | 20 | 0.29 | 0.32 | 0.52 | 0.66 |
| P2 | CSS 条目字段 ×2（1000 条） | — | 20 | 11.62 | 12.19 | 13.80 | 14.13 |
| P2 | **total CSS：解析 → 列表 → 字段** | ≤ 300 ms | 20 | 17.25 | **17.76** | 20.04 | 20.79 |
| P2 | 正则列表规则（`:href=…`） | — | 20 | 1.49 | 1.51 | 1.96 | 2.01 |
| P2 | 正则条目字段 ×2（1000 条） | — | 20 | 3.07 | 3.14 | 4.60 | 4.75 |
| P2 | total 正则：解析 → 列表 → 字段 | — | 20 | 9.62 | 10.71 | 12.16 | 12.40 |
| P3 | 规则编译（CSS / JSONPath / 正则链各 200 次求值） | ≥ 95% | — | lookups=600 · compilations=600 · hits=0 · **命中率 0.0%** | | | |

P2 线性度（解析 → 列表 → 字段，p50）：

| 章数 | p50 (ms) | 每章 (µs) |
|---|---|---|
| 250 | 4.16 | 16.6 |
| 500 | 8.51 | 17.0 |
| 1000 | 17.82 | 17.8 |
| 2000 | 37.23 | 18.6 |

三条读数（2026-10-28，用户裁决：**阈值维持初值，只用前后差值验收**）：

1. **P1/P2 现在就已经远在 ADR 初值之内**（6.31 ms vs 40 ms；17.76 ms vs 300 ms），所以 M26 的验收
   以「同一命令的改前/改后差值」为准，而不是「是否过线」。阈值按 ADR-0078 决策 4 保持不变。
2. **P3 = 0%**：引擎没有任何编译缓存，每次求值都重新 `_parse`（观测点是 `RuleEngine.compileStats`，
   计在 `_parseForEvaluation` 这个接缝上），这就是 R1 的靶子。
3. **P1 的时间大头是「提取」（3.59 / 6.31 = 57%）**，比 HTML 解析还多；P2 的大头是 1000 条条目字段
   （12.19 / 17.76 = 69%）。两者都是 R2（共享 scope）/ R3（批量提取）能碰的地方。

### 5.2 R1（规则编译缓存）之后（2026-10-28）

同一台机器、同一条命令、同一组参数，只多了 R1 的改动（`_parse` / `_check` 的结果按
`(规则文本, hasExtraction, field)` 复用，LRU 上限 256 / 512）。报告：`build/bench-r1.json`。

| 指标 | 项 | 改前 p50 | **改后 p50** | 差值 |
|---|---|---|---|---|
| P1 | total：解析 → 提取 → `replaceRegex` | 6.31 ms | **6.17 ms** | −2.2% |
| P1 | 提取 | 3.59 ms | 3.50 ms | −2.5% |
| P2 | CSS 条目字段 ×2（1000 条） | 12.19 ms | **7.42 ms** | **−39%** |
| P2 | total CSS | 17.76 ms | **12.76 ms** | **−28%** |
| P2 | 正则条目字段 ×2 | 3.14 ms | 3.19 ms | +1.6%（噪声内） |
| P2 | total 正则 | 10.71 ms | 9.69 ms | −9.5% |
| P2 | 线性度（2000 章的每章 µs） | 18.6 | **13.7** | −26% |
| P3 | 规则编译命中率 | 0.0% | **99.7%**（lookups 1200 / compilations 4） | **达标（≥95%）** |

怎么读这两张表：

- **P2 的收益全在「条目字段」**（−39%）：1000 条目录每条都要把同两条规则重新编译一遍，缓存把它们
  压成了各一次。这也说明 R3（批量提取）的剩余空间在**选择器求值**本身，而不在规则解析。
- **P1 几乎没动**（−2%）是预期：一章只求值一次同一条正文规则，缓存只省掉第 2..20 次迭代的解析，
  而 P1 的成本由「解析 200 KB HTML」和「从 500 个段落拼正文」决定。
- **P3 从 0% 到 99.7%**，且 `compilations` 为 4 而不是理论上的「规则数 × 2」，因为 P1/P2 已经预热了
  其中两条规则 —— 这正是「一次会话内只编译一次」的意思。

### 5.3 P5 / P6（2026-10-28，未做优化，只是首次量出来）

同一个 exe、`--release`，`BENCH_ARGS="--only=p5,p6 --iterations=40 --warmup=5"`。
P5 复跑两次（`--iterations=40` / `--iterations=80`）：

| 指标 | 项 | 目标 | 实测 |
|---|---|---|---|
| P5 | 空脚本 job 往返（n=10 / n=20） | ≤ 3 ms | p50 **3.03 / 2.83 ms**；p95 3.62 / 3.17；min 2.80–2.87 |
| P5 | 内联覆盖：字面量写法（`java.timeFormat(java.getString('$.x')*1000)`） | ≥ 95% | **1/1（100%）** |
| P5 | 内联覆盖：带变量写法（`java.getString(expr)`） | — | 0/1（0%，这是设计：首参不是字面量就无法内联） |
| P6 | 单章（199 KB HTML → 正文） | ≤ 8 MB | 首次 1.06 / 后续中位 0.88 / 最大 3.13 MB |
| P6 | 千章目录（1000 条 → 章名 + 地址） | ≤ 32 MB | 首次 1.55 / 后续中位 0.46 / 最大 7.09 MB |

三条读数：

1. **P5 就压在阈值上**（p50 2.8–3.0 ms vs ≤3 ms，p95 3.2–3.6）：这条要动的不是「有没有缓存」，
   而是「一个 job 的固定成本」——isolate 两跳消息 + 前奏（`Uint8Array` / `java.*` 绑定 + `jsLib`
   解析）+ 结果信封的 JSON 编解码。R5 的「按 `sourceId + 脚本 hash` 缓存编译结果」只省其中一段，
   要真正压下来得先分段量（留给 R5）。
2. **P5 的覆盖率取决于语料写法**：字面量写法 100% 内联、带变量写法 0%。语料里主流写法是前者
   （`{{java.timeFormat(java.getString('$.x')*1000)}}`），所以「≥90%」这个数字必须在**真实源**上量：
   `tool/spot_check` 现在会在每次运行结束时打印 `rules:` / `nested:` 两行，M27 的 L1 逐源回归顺手取。
3. **P6 有量级余量**（1.06 vs 8、1.55 vs 32），但「后续中位」不是 0（0.46–0.88 MB/次），说明每次
   操作都有一定常驻增长；10 轮样本 + 无 GC 钩子不足以判定是堆增长还是页缓存，真要查泄漏得在
   `integration_test` 里按轮采样（§6）。

### 5.4 P5 分段（2026-10-28，R5 开工前置）

`BENCH_ARGS="--only=p5 --iterations=40 --warmup=5"`，同一台机器、同一个 exe。四段都用**现成接缝**量，
不改生产代码：

| 段 | 怎么量 | p50 | 结论 |
|---|---|---|---|
| 引擎侧（假桥） | `RuleEngine.evaluateJs` + 立刻返回的桥 | **0.00 ms**（<5 µs） | 内联扫描 / 作业构造 / `jsLib` 解析的宿主成本**可以忽略** |
| 桥 + worker：空脚本 | `JsBridge.evaluate(JsJob('void 0'))` | **2.87 ms** | 固定开销全在这里 |
| 桥 + worker：+ `jsLib`（40 B） | 同一个 job 带一段小库 | 2.93 ms | 库前奏 ≈ 0 |
| 桥 + worker：+ 32 KB 结果信封 | 脚本返回 32 KB 字符串 | 3.24 ms | 结果编解码 ≈ +0.37 ms |
| 机器底座 | 裸 `Isolate` echo 往返 | **0.04 ms** | 「两跳消息」不是成本 |
| 体积灵敏度 | 追加 45 KB 脚本源码 | **7.05 ms**（+4.19） | 源码 ≈ **94 µs/KB** ⇒ 成本随「每 job 要解析的沙箱源码」走 |

**结论（这条改写了 R5 的靶子）**：P5 的 2.87 ms 不是消息、不是宿主，而是
**每个 job 重新 `eval` 的那份沙箱源码**——`quickjs_worker.dart` 的 `_evaluationSource()` 把
`_prelude`（**52 KB / 1438 行**，`java.*` / `crypto` / `cache` / `Packages` / `parse` 的一整套绑定）
拼在规则前面，`_prelude` 每个 job 都重跑一次。那是有意的（`globalThis` 共享，不重跑会让上一 job 的
重绑定漏给下一个），但代价就是 P5 的固定开销。

于是 R5 真正的动作**不是** ADR 里写的「按 `sourceId + 脚本 hash` 缓存脚本编译结果」——真实规则的脚本
只有几百字节，按 94 µs/KB 算不到 0.05 ms；动作是**让沙箱源码一次编译、每 job 只跑「状态重置 + 绑定
+ 规则」**（把 `_prelude` 里无状态的定义与有状态的重建分开），这需要逐条确认哪些 `globalThis.*` 是
每 job 必须新建的（`cache` / `java` / `source` / `infoMap` 的闭包状态），并双端实跑
`integration_test/js_bridge_test.dart`（`quickjs_worker.dart` 是 `coverage:ignore-file`，只有设备探针覆盖它）。

## 6. P4/P5/P6 怎么接（未落地）

| 指标 | 缺什么 | 接法 |
|---|---|---|
| **P4** DOM 复用 | 一个「一页 parse 了几次」的计数器 | 与 P3 同法：在 `PageFetchService` 的解析点加只读计数，脚本断言「解析次数 == 页数」。R2 落地时一起做，否则没有判据 |
| ~~**P5** JS 往返~~ | — | **已接**（§5.3）：`--only=p5`。剩下的只有「分段量」——往返里哪一段最贵（见 §5.3 第 1 条） |
| **P6** 设备内存 | Android 真机的内存数据 | 桌面 release 数字已由 `--only=p6` 给出（§5.3）；ADR-0078 决策 4 要的「真机抽一次」仍走 `integration_test`（按轮采样 RSS / 堆，绕开 Dart 没有 GC 钩子的问题） |

---

## 7. 改完之后怎么记（每张重构 PR 的硬要求）

1. 同一台机器、同一条命令、同一个 `--release`，改前/改后各跑一次（**不要**改 `--iterations`，
   否则两次不可比）。
2. PR 描述里贴两行：`p50` 与 `p95`，以及 `ruleCompile` 的 `lookups/compilations/hitRate`。
3. 性能变好但行为用例红 = 退回（ADR-0078 决策 3）；确实做不到的目标登记到
   `docs/dev/engine-parity.md` §11 的「已知热点」，不在这里悄悄放宽。
4. 达标后只更新本文 §5 的表格与 `engine-parity.md` §11 的数字，阈值改动另开 ADR。
