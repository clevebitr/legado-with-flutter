# G2b spot-check：真实站点链路验证

> 本文档是 **G2b（真实链路）的证据记录与复现说明**，对应 `PLAN.md` §3.4 步骤 3（「3.2 之后、
> 3.3 之前」）与 §3.7 的登记表。它**不复述**任何规范：规则语义归 `docs/dev/book-source.md`，
> 失败语义归该文档 §7，裁决归 `docs/dev/adr/`。
>
> 它**不是测试**：`docs/dev/testing.md` §1 禁止测试联网，因此这里是 `tool/` 入口，
> 不被 `flutter test` 发现、不进 CI（与 `tool/spike/` 同一模式）。

---

## 1. 为什么需要它

3.2 把矩阵 #12（`@css:`）建完时，它只被离线语料验证过：语料是**按真实选择器构造**的 HTML
（`test/fixtures/html/README.md`）。构造的页面无法证明「cascadia 对真实页面的语义与 jsoup 一致」，
而这正是 `@css:` 的全部价值所在。G2b 的要求就是：**取存活站点，跑一遍
搜索 → 详情 → 目录 → 正文**。

## 2. 怎么跑

```bash
# 把一个真实书源 JSON（单条或整个合集）跑完四段链路
dart run tool/spot_check/spot_check.dart --source=<file.json> --keyword=剑来
# 合集里按名字挑一条，并输出可供记录粘贴的 JSON
dart run tool/spot_check/spot_check.dart --source=<collection.json> --name=笔趣阁 --json
# 列出合集里本仓当前能求值的源（选源依据，见 §3）
dart run tool/spot_check/spot_check.dart --list=<collection.json>
```

链路是**生产链路**：UseCase → `renderUrlTemplate` → `core/network/HttpClient` → `RuleEngine`，
书源自身的 `header` 字段也会真正进请求（`book-source.md` §2 的 M0 字段）。任何一段失败都会打印
`ParseFailureKind` 与把链路打断的 `rulePath`；进程退出码 0 表示四段都有产出。

**证据形态：** stdout 里只出现**截断样本（≤60 字符）与全文 sha256**，不落盘页面正文。

## 3. 选源（可复现）

| 项 | 值 |
|---|---|
| 合集 A | `https://raw.githubusercontent.com/Orokapei/BookSource/main/Legado.json`（11 条） |
| 合集 B | `https://raw.githubusercontent.com/safino9/SourceGo/master/book_source/all.json`（189 条） |
| 合集 C | `https://legado.aoaostar.com/sources/b778fe6b.json`（3907 条，最近同步 2026-08-15） |
| 筛选 | `--list` 的判据：`searchUrl` 是 HTTPS GET 且含 `{{key}}`、四段规则非空、不含任何后续阶段的标志（`@js:` / `@xpath:` / `@put:` / `@get:` / `@@` / `<js>` / `{{}}` 内嵌 / 裸 `{…}` / `:正则`） |
| 结果 | 合集 C 中 **270/3907** 条属于 M0；取其中 `lastUpdateTime` 最新的 80 条做一次只读探测 |
| 探测 | 80 条各 1 次 GET（浏览器 UA，≤12 s）；**40 条返回 200**，其中 13 条搜索页含真实结果链接 |

> 只读、低频：每个候选 1 次请求，链路本体每站 ≤4 次（搜索 / 详情 / 目录 / 正文各 1）。
> 不登录、不批量爬取、不落盘页面。

## 4. 结果（2026-10-12，Windows 11 / Flutter 3.47.7）

**跑通完整四段链路（G2b 达成）：**

```
语法：全部默认规则（矩阵 #1 / #2 / #5 / #8 / #9）
书源：笔趣阁③ (https://www.biquge99.cc)          # 合集 C 第 42 条
链路：搜索 → 详情 → 目录 → 正文
结果：
  search   ok  count=2     剑来 https://www.biquge99.cc/book/1869698028/
  bookInfo ok  剑来 | author=烽火戏诸侯 | toc=https://www.biquge99.cc/book/1869698028/
  toc      ok  count=1310  第一章 惊蛰 https://www.biquge99.cc/book/1869698028/986558553.html
  content  ok  3031 字符  sha256=6578ef3efc456856
结论：已确认（该站的规则串是真实导出的原文，未做任何改写）
```

**矩阵 #12（`@css:`）在真实 HTML 上的证据：** 同一站点、同一批页面，把上一条书源的默认规则**逐条改写为等价的 `@css:` 写法**（`class.bookbox` → `@css:.bookbox`、`id.content@textNodes` →
`@css:#content@textNodes`、`class.bookimg@tag.img.0@src` → `@css:.bookimg img:eq(0)@src` 等，
后者同时行使矩阵 #29），重跑得到**同样的四段计数**，且正文 **sha256 完全相同**
（`6578ef3efc456856`）。⇒ cascadia 对本仓 `@css:` 求值路径在真实页面上与默认规则等价。

> 为什么是派生源：合集里唯一两条用 `@css:` 的源，其站点一条已停放（`m.kayege.info` 返回
> Coming Soon），另一条被 Cloudflare 拦截（`99csw.com`）；见 §5 的「源失效」发现。
> 派生的只有规则**写法**，站点、页面、`searchUrl`、`header` 都是原样。

**ADR-0031 宽容解码的 warning 实测（同一次运行，stderr）：**

```text
Declared charset utf-8 carried illegal bytes; 1 malformed byte replacement(s) inserted: rule=ruleBookInfo source=https://www.biquge99.cc url=https://www.biquge99.cc/book/1869698028/
```

被宽容的就是下面表中「声明 UTF-8 但含 1 个非法字节」的那个书页：warning 携带**声明的编码、替换数量、
字段路径与书源 ID**，不含正文（C-ERR-8 / C-SEC-4），且每条响应只记一条（同页被两个阶段各取一次，
即两条响应、两条 warning）。

**未跑通但已定位的站点（同一批 13 条，用于说明失败归属）：**

| 现象 | 站点 | 归属 | 处理 |
|---|---|---|---|
| 书页声明 UTF-8 但含 1 个非法字节（131 368 B 中偏移 130 893 处 `0x8b`）→ 整段 `encodingFailed` | `biquge99.cc` 等 3 条同站源 | 本仓口径 | **ADR-0031**：声明车道宽容解码 + 一条带「声明的编码 + 替换数 + 书源 ID」的 warning（已实现，该站因此跑通）；记录里已按该 ADR 要求写明「该页含非法字节」 |
| `.searchresult` / `li` / `dd` 等未知类型 → 搜索段即失败 | `ihuaben.com` / `zhulang.com` 等 9 条 | 本仓口径 | **ADR-0032**：未知类型退化为原始 CSS（已实现，`ihuaben.com` 随后搜索段拿到 30 条真实结果） |
| 声明 `shift-jis` / `euc-jp` 且字节不完整 → 依赖抛 `RangeError`（`Error`）逃出 `ParseResult` 契约；`euc-kr` 则静默丢弃非法字节 | — | 依赖缺陷 + `Error` 不得捕获（ADR-0022） | 登记为已知缺口，见 §6（宽容映射因此只含 `utf-8` / `gbk`，见 `book-source.md` §5.1） |
| 搜索参数改版（源写 `wd=`，站点现在用 `qd=`）、目录结构改版 | `dushu.com` / `linovel.net` | **源失效**，非本仓缺陷 | 记录即可；矩阵状态列仍由 3.7 的真实回归决定 |

## 5. 本次 spot-check 顺带发现并修掉的缺陷

| 缺陷 | 证据 | 处理 |
|---|---|---|
| `BookSource.headers`（`header`，M0 字段）从未进入任何请求 | `PageFetchService.fetch` 未传 `headers`；`zwdu.com` 用项目默认 UA 直接连接失败、浏览器 UA 200 | 已修：UseCase 传 `source.headers`，`FakeHttpClient` 记录请求头，`fetch_content_test.dart` 断言 |
| 解码 warning 无法定位到书源 | ADR-0031 §决策 2 要求携带书源 ID，而 `HttpClient.get` 此前没有这个参数（C-ERR-8 的既有缺口） | 已修：`HttpClient.get` / `PageFetchService.fetch` 增加 `sourceId`，4 个 UseCase 传 `source.url`，测试断言它到位 |

## 6. 未闭环（已登记，见 `PLAN.md` §3.7）

- 矩阵 #14（`@js:`）在仓内语料中出现 **0** 次，需先补样才能按 §10 改「已确认」。
- `shift-jis` / `euc-jp` 的字节不完整会让 `charset 2.0.1` 抛 `RangeError`（`Error`），
  该异常会越过 `ParseResult` 契约（C-ERR-1）逃到调用方；按 ADR-0022 不得捕获 `Error`，
  因此需要换依赖或加一层隔离；`euc-kr` 的解码器则静默丢弃非法字节（无宽容入口）。
  两者因此**不在** ADR-0031 的宽容映射里（只有 `utf-8` / `gbk` 实测符合「U+FFFD + 不丢字节」）。
- 矩阵各行的状态列仍是「待验证」：本次是一条站点的四段链路 + 一条派生 `@css:` 等价验证，
  状态列的翻转归 **3.7**（需要 2 个书源的全链路离线回放 + 真实回归记录）。
