# ADR-0081 M25/S5d：Rhino 互操作做**最小垫片**，不做对象模型

- **状态：** Accepted（2026-10-27，用户裁决：实现 shim）
- **日期：** 2026-10-27
- **关联：** ADR-0037 §决策 5（具名拒绝）、ADR-0078（切片 S5d）、ADR-0076（同步 `java.*` 方言）、
  ADR-0080（XPath 自研子集：同一套「白名单 + 具名拒绝」套路）、C-SRC-3（沙箱禁忌）、
  C-SRC-4（禁止静默忽略）、`docs/dev/book-source.md` §6/§11、`docs/dev/engine-parity.md` §5/§9.3

## 背景

`engine-parity.md` §9.3 把 Rhino 互操作列为 S5d，并写明「需要 ADR 决定最小 shim 还是维持具名拒绝」。
复核 334 源语料后的真实分布：

- **19 个源**用到 `Packages.*`（其余源里出现的 `java.lang` 等字样是 `java.get…` 之类，与包无关）。
- 其中 **6 个源只需要「一行就能等价实现」的成员**：`java.lang.String(bytes,'UTF-8')` 与
  `.getBytes('UTF-8')`、`System.currentTimeMillis()`、`Thread.sleep()`、`UUID.randomUUID().toString()`、
  `Arrays.copyOfRange`、`HashMap` / `ArrayList`、`android.util.Base64`、`android.text.TextUtils.isEmpty`、
  hutool 的 `DigestUtil.md5 / md5Hex` 与 `cn.hutool.core.codec.Base64`、
  `io.legado.app.help.http.StrResponse(url, body)`。
- **13 个源另有硬需求**：`javax.crypto`（`Cipher` / `SecretKeySpec` / `IvParameterSpec` / `Mac`，多写在
  `new JavaImporter(...)` + `with(importer)` 里）、`java.io` 的 `ByteArrayInputStream/OutputStream`、
  `java.net.URL` 的流、`okhttp3.OkHttpClient`、`org.jsoup.Jsoup.parse`、`android.graphics.BitmapFactory`。

## 决策

**做白名单最小垫片，其余维持具名拒绝。**

### 决策 1 白名单只放「数据 / 编码 / 集合」

`lib/core/js/quickjs_worker.dart` 的前奏里新增 `Packages` 包树（`ADR-0081` 的唯一出处就在这里）：

| 成员 | 兑现方式 | 语料来源 |
|---|---|---|
| `java.lang.String` | `new String(bytes,'UTF-8')` 解码走宿主 `bytesToStr`；`String(x).getBytes(charset)` 走 `__textBytes`；返回**装箱字符串**（`String(...)` 照常可用） | 七猫四合一、Hi歌曲、阅文 |
| `java.lang.System.currentTimeMillis` | `Date.now()` | 海棠搜书 |
| `java.lang.Thread.sleep` | **空操作**，返回 `0` | 独阅读网、书文小说 |
| `java.util.UUID.randomUUID` | 宿主 `randomUUID`，包成 `{toString()}` | 七猫四合一 |
| `java.util.Arrays` | `copyOfRange` / `copyOf` / `toString`（都答**新数组**，与 Java 一样不共享缓冲） | 七猫四合一 |
| `java.util.HashMap` / `LinkedHashMap` | 复用 `__javaMap`（登录头那张表的同一套读法） | 书旗 |
| `java.util.ArrayList` | 真数组 + **不可枚举**的 `add` / `size()` | 海棠搜书 |
| `android.util.Base64` | 脚本侧 base64 编解码（不走宿主），`NO_WRAP` 等常量照有 | 七猫四合一、Hi歌曲 |
| `android.text.TextUtils.isEmpty` | 空判 | 阅文 |
| `cn.hutool.crypto.digest.DigestUtil` | `md5`（16 字节）/ `md5Hex`（32 位 hex），复用 `java.md5Encode` 的实现 | 七猫四合一、阅文 |
| `cn.hutool.core.codec.Base64` | `encode` / `decode` / `decodeStr` | 长佩文学 |
| `io.legado.app.help.http.StrResponse` | 复用 `__sandboxStrResponse`（与 `loginCheckJs` 的 `result` 同形，脚本 `return` 出去就替换页面） | 聚合书库、点众阅读 |

### 决策 2 白名单外的名字**具名拒绝**，错误里带完整路径

每个包节点都是 Proxy：白名单成员正常取出，其余 `throw new Error('Packages.<到第一个未知段的路径> is not
supported (M25/S5d): see book-source.md §11')`。报的是**第一个**未知段（`Packages.javax`、
`Packages.java.util.TreeMap`），因为再往下猜类名只会更长而没有更多信息。这比原来的「任何 `Packages.*`
都抛一句 `Packages.* interop is not supported`」有用得多：源作者一眼看出缺的是哪个包（C-SRC-4）。

`JavaImporter` 同理：给它一个**具名错误**（原来 13 个源里有一半第一行就 `new JavaImporter(...)`，那条
脚本以前报的是 `JavaImporter is not defined`，现在是可读的原因）。

### 决策 3 `Thread.sleep` 是空操作，并登记

沙箱里没有线程，也不可能为一条 `sleep(3000)` 让出规则预算（ADR-0076 §决策 1 的预算口径）。
语料里它只出现在「提示用户之后小小停顿」的位置，跳过它不改变解析结果；如果哪天出现「靠 sleep 等第三方
异步落库」的源，这条差异就是触发条件。

### 决策 4 `java.*` 包名不动，只有 `Packages.*` 有垫片

本仓的 `java` 是**扩展面**（`JsExtensions` 的等价物），上游同样不是包——`java.lang.*` 在上游也取不到。
所以 §11 里那 8 个包名（`lang` / `security` / `util` / `net` / `io` / `nio` / `math` / `text`）**仍然全部
抛错**，门禁 G1 的名单与含义都不变；`Packages.*` 是 Rhino 真正的包入口，垫片只装在这里。

## 后果

- **好的方面：** 6 个源只差白名单即可用（七猫四合一、阅文、长佩、海棠（部分）、书旗（`HashMap` 那步）、
  Hi歌曲）；另外 13 个源从「`Packages is not defined`」变成「`Packages.javax.crypto.Cipher is not
  supported」——同一条脚本仍然失败，但**失败原因写在错误里**。没有新依赖、没有主机新端口（只有脚本侧
  的 base64/hex 小工具），不碰 SQLite 与 UI。
- **代价：** 前奏又长了约 200 行 JS；它**只能在设备上验证**（`flutter test` 的宿主 VM 加载不了 QuickJS），
  因此新增 6 条真引擎探针覆盖白名单与两条具名拒绝。`Thread.sleep` 与「`Arrays` 返回新数组」两条与 Java
  的差异已登记。
- **未做（触发条件）**：`javax.crypto` 的 `Cipher` / `SecretKeySpec` / `IvParameterSpec` / `Mac`、
  `java.io` 流、`java.net.URL`、`okhttp3`、`org.jsoup`、`BitmapFactory`、`JavaImporter`。
  触发 = 出现「只差 `javax.crypto` 一个能力」的真实源且能用现有 `createSymmetricCrypto` 等价改写；
  届时按决策 1 的白名单形式增量补，不重开选型。

## 被否的备选

- **完整 Java 对象模型（`JavaImporter` + `Cipher` + 流 + OkHttp + jsoup 全套）：** 那是把 Rhino 的
  Java 互操作在 QuickJS 里重写一遍（每个类都要有等价实现与类型转换），与「沙箱只暴露白名单」
  （C-SRC-3）正面冲突；而且 13 个源里有 11 个同时用到 `javax.crypto`，只做一个类仍然跑不通。
- **维持全量拒绝（S5d 登记不做）：** 6 个只差白名单的源会继续不可用，而这一刀的代价只有脚本侧代码；
  同时「具名拒绝带完整路径」本身也比一句 `Packages.* is not supported` 更有用。
- **把 `Packages.java.lang` 也接到 `java.lang` 上：** 上游 `java` 是扩展面，`java.lang.*` 在那边不存在，
  接上去等于自造一个上游没有的入口，且会让 §11 的 8 个包名含义变成「一半支持」。

## 实现注记（2026-10-27 落地）

- 前奏新增：`__bytesOfHex` / `__bytesToBase64` / `__base64ToBytes`（脚本侧编解码）、`__packageNode`
  （白名单 Proxy，未知名字带完整路径抛错）、`__javaLangString`、`__javaArrays`、`__javaArrayList`、
  `__javaHutoolDigest`，以及 `Packages` 包树；`JavaImporter` 抛具名错误。
- **落地前的一次性校验（Node `vm` + 桩 `sendMessage`）：** 把前奏抽成纯 JS、用 Node 的 `crypto` 桩出
  `strToBytes` / `bytesToStr` / `md5` / `randomUUID`，逐条跑白名单成员与两条具名拒绝（base64 往返、
  md5Hex、`Arrays.copyOfRange` + `String(bytes)` 往返、`TextUtils`、`UUID`/`ArrayList`/`HashMap`、
  `StrResponse`、未知段与 `JavaImporter`）。这一步抓出两个真 bug：`new` 只认对象返回值（解码必须返回
  装箱 String，否则 `new java.lang.String(bytes,'UTF-8')` 得到 `{}`）、根节点路径拼出 `Packages..javax`
  的双点。脚本是一次性的（`build/tmp`，不进仓库），因为它需要 Node 而 CI 不保证有。
- 设备探针（`integration_test/js_bridge_test.dart` 新增一组 6 条）：`java.lang.String` 编解码往返、
  `android.util.Base64` 往返、hutool `md5Hex`/`md5` + `TextUtils.isEmpty`、`UUID`/`ArrayList`/`Arrays`/
  `HashMap`/`System.currentTimeMillis` 组合、`StrResponse` 的响应形状、白名单外成员与 `JavaImporter`
  落到 `js:error`。**尚未在设备上跑**（`flutter test` 的宿主 VM 加载不了 QuickJS，前奏只能由设备验证）。
- 文档：`book-source.md` §6 新增「`Packages.*` 最小垫片」三条边界、§11 的 8 包名块后补「S5d 之后的口径」；
  `engine-parity.md` §5 拆出 Rhino 互操作行（部分对齐 + 19/6/13 的分布）、§9.3 行、§9.4 表。
