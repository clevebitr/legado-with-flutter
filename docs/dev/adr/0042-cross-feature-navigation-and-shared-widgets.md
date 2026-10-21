# ADR-0042 跨 feature 导航走 presentation 端口；共用 Widget 上移 `core/widgets/`

- **状态：** Accepted（2026-10-21，5.4 / 5.6 落地时确立）
- **日期：** 2026-10-21
- **关联：** C-ARCH-1、C-ARCH-2、C-ARCH-6、C-UI-7、ADR-0011、ADR-0041、
  `docs/dev/roadmap.md` §3.6（5.4 / 5.6）、`docs/dev/architecture.md` §1 / §2 / §6

## 背景

ADR-0041 §决策 2 把「跨 feature 调用」收敛成一个机制：**消费方在自己的 `domain/` 声明端口，装配根绑定实现**，
端口只收发原语与消费方自己的实体。这套机制解决了数据（加书、进度、目录），但 5.4 / 5.6 撞上了它管不到的两种东西：

| 需求 | 为什么 ADR-0041 的端口装不下 |
|---|---|
| 搜索页（`book_source`）要打开书架页与设置页 | 导航需要 `BuildContext`；`domain/` 不得 import Flutter（C-ARCH-7），端口放不进去 |
| `StateMessage` / `FailureMessage` 被 `book_source`、`bookshelf`、`settings` 三个 feature 共用 | 它们原先住在 `book_source/presentation/widgets/`，第二个 feature 一来就变成 `bookshelf → book_source` 的 import（违 C-ARCH-2） |

两条都是**结构问题**而不是一次性需求：5.3 把 `ReaderRoute` 迁去 `reader` 之后，「从书架打开阅读器」会让同样的
矛盾出现在第三个方向。

## 决策

1. **跨 feature 导航走 presentation 端口。** `core/router/app_navigation.dart` 声明 `AppNavigation`
   （`openBookshelf(BuildContext)` / `openSettings(BuildContext)`）；默认实现 `UnboundAppNavigation` 记一条
   warning 并**不做任何事**（不抛，与 ADR-0041 §决策 2 的 null object 同一条理由）。
   生产绑定在装配根：`lib/app.dart` 的 `appProviderOverrides()` 把它接到
   `pushBookshelfRoute` / `pushSettingsRoute`，`lib/main.dart` 把这份 overrides 交给 `ProviderScope`。
   消费方（搜索页）因此**只 import `core/`**，不 import 任何 feature 的路由类型。
2. **导航端口不携带 feature 的事物。** 端口签名只收 `BuildContext` 与原语；将来「打开某一章」这类需求写成
   `openReader(BuildContext, String chapterUrl)`，而不是把 `reader` 的路由对象传出去 —— 否则这个端口就变成
   了第二个跨 feature 接口面，而且它的参数会把 `core/` 拖进 feature 依赖。
3. **数据仍然走 ADR-0041 的 domain 端口。** 本 ADR 只补导航与 UI 复用两块，不改变「`features/A` ⇒ `features/B`
   的 import 数为零」这条边界；`BookshelfWriter`（`book_source/domain`）与 `concurrencySettingProvider`
   （`core/di`）继续按 ADR-0041 在装配根绑定。
4. **多个 feature 共用的无业务语义 Widget 上移 `core/widgets/`。** 本批移动 `StateMessage`、
   `FailureMessage`（含 `resolveFailureMessage`，它只是 `ParseFailureKind` → ARB 的映射，不含业务判断）。
   判据与 `core/` 总判据一致：不含业务语义、不 import `features/`；一旦它开始需要 feature 实体，它就不属于这里。
5. **装配根是唯一同时 import 四个 feature 的文件。** `app.dart` 因此承担三件事：页面表（ADR-0011 三分职责的
   第二分）、端口绑定、`appProviderOverrides()`；`main.dart` 只做 `runApp` + 传 overrides。

## 后果

- 搜索页新增两个入口（书架 / 设置）；未绑定导航时点了没反应，但**有一条 warning**，不是静默的死按钮。
- 页面的 smoke test 不需要绑定导航（默认实现是 no-op + 日志）；绑定本身由 `test/app_test.dart` 与
  `test/core/router/app_navigation_test.dart` 覆盖。
- `core/widgets/` 成为新目录：`architecture.md` §1 的目录树与 §7 的落地清单同步；`C-UI-7`（可访问名称）
  对这些 Widget 的要求不变。
- ADR-0041 的端口规则**不变**，本 ADR 是它的补充而不是替代：domain 端口、presentation 端口、共用 Widget，
  三条判据分别在 `architecture.md` §2/§3 与本节落笔。
- 若将来需要深链接、带参跨 feature 导航或第三方入口，先扩展本 ADR（例如引入命名路由表），不得在每个页面里
  就地发明一套。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 让 `book_source` 直接 import `bookshelf` / `settings` 的 route 类型 | 违 C-ARCH-2；5.3 之后 `ReaderRoute` 迁去 `reader`，同类 import 会变成三个 feature 互相引用 |
| 把书架 / 设置入口放进装配根自己的导航结构（例如 root 的 `NavigationBar`） | 等于把 feature 的 UI 决策搬到装配根，且入口会随 5.9 / 5.10 继续增加；`app.dart` 会从页面表长成第二个 UI 层 |
| 每个 feature 各抄一份 `StateMessage` / `FailureMessage` | 两份相同的 UI 与 ARB 映射必然漂移（`roadmap.md` §6 #9），而且 C-UI-7 的可访问性要求要维护两遍 |
| 用 `Navigator.pushNamed` + 字符串路径直接跳转，绕过端口 | 路径常量归各 feature（ADR-0011），字符串常量散落即第二份来源；类型化参数也随之丢失 |
