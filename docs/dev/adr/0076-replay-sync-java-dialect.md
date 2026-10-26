# ADR-0076 上游“同步 `java.*` 方言”的重放式兼容层

- **状态：** Accepted（2026-10-25，用户裁决：全量重放式路线；同时先交付一份可用的改写版源）
- **日期：** 2026-10-25
- **关联：** C-SRC-2、C-SRC-3、C-SRC-4、ADR-0037 §决策 5、ADR-0068 §决策 5、
  ADR-0069 G6、`docs/dev/book-source.md` §6/§11

## 背景

一个真实书源（`来看文学`，`https://m.laikan9.com`）在导入后连搜索都发不出去。取证结论：**缺的不是
“人机验证”，而是上游整套同步 `java.*` 方言**。该源在 `searchUrl` 的第一行就调 `java.ajax(...)`，
本仓按名拒绝（ADR-0037 §决策 5），于是搜索在弹出验证码之前就结束。它用到的能力：

| 需要 | 本仓现状 |
|---|---|
| `java.ajax(url)` 同步返回正文 | ❌ 具名拒绝（沙箱回调只能是 Promise） |
| `java.post(url, body, headers).header("Location")` | ❌ 具名拒绝 |
| `java.getCookie(url, key)` / `cookie.getCookie/setCookie/removeCookie` | ❌ 具名拒绝 / 无 `cookie` 全局 |
| `java.setContent(html)` | ❌ 具名拒绝 |
| `source.getVariable()` / `setVariable(v)` | ❌ 沙箱 `source` 无此方法 |
| `java.longToast` / `java.toast` | ❌ 具名拒绝 |
| `java.getVerificationCode(img)` 的**同步**取值 | ⚠️ 有，但返回 Promise，上游写法不 `await` |

**根因是架构级的：** JS 在独立 isolate 里跑，宿主回答只能是 Future（`quickjs_worker.dart` 的
`_callHost`），而 Dart 没有同步 TLS，所以「阻塞 JS 线程等一次 HTTPS」不可实现。

### 该站点的验证链路（2026-10-25 实测，纯 HTTP 可复现）

```
GET  /                     -> act(16 hex) + submit(GBK)
POST /sscc/                -> 302, Location: ?<16 hex>            （同一关键词稳定）
GET  /sscc/?<16 hex>       -> 壳页面 "<title>" + c2="…" + <script src="/nnxswnn/<n>.js">
GET  <src>                 -> 站点挑战 JS（自定义 MD5）
eval(js 的 function…()}); ajax(c2) -> /8fa64cf70ef8d455/<hash>10414709/
GET  <该路径>              -> "ok" + Set-Cookie（下盾）
GET  /sscc/?<16 hex>       -> 图片验证码表单（actyzm / yzm / button / /member/getcode.asp）
GET  /member/getcode.asp   -> BMP 验证码 + Set-Cookie g3jy9sqo0ws
POST /sscc/?<16 hex>       -> 搜索结果（含 /lk/ 链接）
```

**两个已验证的实现约束：**

1. 表单必须 POST 回**带 token 的地址**（`/sscc/?<16 hex>`）。POST 到 `/sscc/` 能过验证码，但搜索
   上下文丢失（返回“零结果”页）。所以规则必须能看到 302 的目标地址 ⇒ 需要响应元信息。
2. 壳页面的挑战 JS 只用到 `eval` + 一次 `GET` 就能算完（`navigator`/XHR 那段我们不需要执行），
   因此**纯 HTTP 即可过盾**，不必依赖 WebView。

## 决策

### 决策 1 重放式同步仿真（用户裁决的路线）

在 worker 内把同步 `java.*` 实现成「取页缓存 + 从头重跑」：

- 脚本命中未缓存的同步调用 → 抛哨兵（带 `{op, url}`）→ worker 向桥要一次取页 → 缓存 → **从脚本开头
  重跑**；重跑时该调用同步返回缓存值。
- 副作用幂等：`java.put` 的变量表按 pass 重置、成功 pass 才提交；cookie / `source.setVariable` 写是
  幂等的，按 pass 执行；`java.toast/longToast` 去重。
- pass 上限（如 16）与「等人的时间不计入预算」沿用 ADR-0068 §决策 5 的口径；超限报 `js:error`。
- `java.getVerificationCode` / `java.startBrowserAwait` 用**答案记忆**（按 `op+url`）保证只弹一次窗，
  重跑时同步返回上次的答案。
- 要补齐的绑定：`java.ajax` / `java.post` / `java.head` / `java.getCookie` / `java.setContent`、
  `cookie.getCookie/setCookie/removeCookie`、`source.getVariable/setVariable/putVariable`、
  `java.toast/longToast`（后三者与重放无关，是独立缺口）。

### 决策 2 响应元信息进引擎（已落地，本 ADR 的前置）

- `HttpResponse.url` = **跟随重定向之后**的地址；页面 `baseUrl`、`FetchedPage.url`、
  `loginCheckJs` 的 `url()` 一律用它（与上游 `StrResponse` 同义）。
- `http.get/post(url, {response: true})` 返回**响应对象**（`body` 属性 + `url()` / `code()` /
  `headers()` / `header(name)` / `cookie()` / `contentType()` / `isSuccessful()`），与
  `loginCheckJs` 看到的 `result` 同一形状。
- 理由：这不是为某一条源开的洞——「页面地址是它最终被读到的地址」对**每一条**源都成立，而
  「规则要重发刚收到的地址」是 302 交接类站点的通用需求。

### 决策 3 立即交付：一条改写版源

同步方言落地前，先把该源改写成 `await http.*` 方言（用决策 2 的能力），作为可导入的
`来看文学(兼容版).json`；`java.ajax` 之类仍按名拒绝，差异继续登记在 §11。

## 后果

- 好的方面：一旦重放层落地，上游绝大多数源（`java.ajax` 是上游最常用的绑定）无需改写即可跑；
  决策 2 已独立修掉「重定向后 baseUrl 仍是旧地址」这一类 bug。
- 代价：重放对**非幂等**规则不友好（每次 pass 都会重跑副作用），必须靠 pass 上限兜底；规则作者
  看到的错误信息要能指出「重放超限」。
- 未做（本 ADR 不含）：`java.refreshBookUrl`、`java.importScript`、`java.cacheFile`、`java.downloadFile`、
  Rhino Java 互操作。

## 实现注记（2026-10-26，M24 落地）

决策 1–4 全部落地。落地时定死的细节（行为面归 `docs/dev/book-source.md` §6，这里只记「为什么这么定」）：

1. **哨兵与重跑放在 worker，答案缓存在 worker**（`lib/core/js/js_sync_call.dart` 的 `JsSyncCache`）：
   `java.*` 的同步调用先问缓存，命中就当场答复；未命中时 worker 记下 `{op, url, body, key}` 并回一个
   失败信封（脚本抛错、停下），`evaluate` 在脚本结束后取一次页、把**答案或失败**都写进缓存，然后
   `while` 重跑整条脚本。哨兵走**状态**而不是只走异常：规则自己的 `try/catch` 即使吞掉它，worker
   仍然知道这一趟作废，结果不会错。
2. **失败也缓存**：否则一条 `try { java.ajax(a) } catch { java.ajax(a) }` 会在同一趟里无限重放。
   缓存的失败在下一趟以抛错形式交给脚本——这正是上游「Java 抛异常、规则可以换镜像」的语义。
3. **pass 上限 16 是 worker 的常量**（`defaultJsMaxReplayPasses`），超限时 worker 在结果信封里带
   `replayLimit: true`，桥把它翻成 `rulePath` 上的 `js:replay`（`js:timeout` 会误导排查方向）。
4. **每趟重跑重新计「每规则调用额度」，同步取页期间暂停硬预算**：额度数的是 CPU 侧往返，预算是
   给 CPU 的（与 ADR-0068 §决策 5 对人机验证的口径一致）。等掉的时间从 `elapsedMs` 扣掉，
   否则 8 次取页就能把 5 秒预算用光。
5. **Cookie 三个动词与 `java.getCookie` 也走同步通道**：值上同步才有「set 之后立刻 get 得到」的
   顺序保证，而顺序是这条链路的全部意义。`cookie.getCookie(url)` 不带名字时答整条 `Cookie` 头，
   与上游 `CookieManager.getCookie` 一致。
6. **验证族不做「同步化」，改做答案记忆**：它们本来就是 Promise（ADR-0068 §决策 5），重放时按
   `op+url` 直接答上次的答案即可满足「只弹一次窗」。`await` 一个已缓存的值与 `await` 一个新值对
   规则无差别，所以没必要为此改形态。
7. **每源变量落 Drift 新表 `source_variables`（v12）**，而不是塞进 `book_sources` 的 payload：
   payload 是「导入时逐字节保真」的那份 JSON（5.8 导出保真的依据），运行期写入放进去就会污染
   导出。表以 `(source_url, name)` 为主键，删除书源不清理（登记在 `roadmap.md` §3.7）。
8. **`java.setContent` 只换同一 job 内后续规则读的页级 scope**：`parse.*` 请求带上覆盖后的正文，
   引擎据此重建一个 `DomScope`（同 baseUrl / 同页码 / 同 source）。字面量首参的 `java.getString`
   仍走引擎内联（ADR-0037 §决策 3①），登记为差异。
9. **`java.toast/longToast` 走 core 端口 `UserMessages`**，装配根绑成 snack bar；同一 job 内按文本
   去重（重放会把同一行再走一遍）。端口是一次性的，规则永远不等它。
