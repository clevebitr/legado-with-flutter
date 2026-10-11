# ADR-0011 路由使用内置 `Navigator`，暂不引入 `go_router`

- **状态：** Accepted
- **日期：** 2026-10-10
- **关联：** C-DEP-1、C-UI-4、`docs/dev/architecture.md` §6、`docs/dev/platform.md` §4

## 背景

审计发现原文档完全没有涉及导航方案，而依赖清单中也没有任何路由包。
项目需要多平台（Android / iOS / Windows）+ 预测性返回，同时 C-DEP-1 要求
新增依赖必须经评审 —— 原文档中没有关于路由的既有决策可供继承。

## 决策

1. 使用 Flutter 内置 `Navigator` + `onGenerateRoute`；路由职责**三分**：机制（`RouteSettings`
   → 页面、唯一 push 入口）在 `lib/core/router/`，页面表（哪条类型化路由构建哪个页面）在装配根
   `lib/app.dart`，类型化参数与其路径在各 feature 的 `presentation/`。

   > **2026-10-11 修订（架构师裁决 R1）：** 本项原文是「路由表集中在 `lib/core/router/`」，
   > 该措辞已废止。原因是 C-ARCH-2：`core/` **不得 import `features/`**，而类型化路由参数携带的
   > 正是 feature 实体（`Book` / `Chapter`），因此页面表只能放在装配根，`app.dart` 的职责本就
   > 包含「路由装配」。**不放宽 C-ARCH-2**（不让 `core/router/` import feature 页面）：它是分层
   > 唯一的地基，为一张表松掉它等于让后续所有阶段的分层检查作废。
   > `architecture.md` §6 已同步；本 ADR §决策 4「路由表是唯一的路由来源」不变——页面仍只经
   > `AppRouter.push` 推送类型化路由，不自己 `Navigator.push` 硬编码下一跳。
2. 路由参数必须是类型化的 `freezed` 对象，禁止传递裸 `Map<String, Object?>`。
3. 预测性返回通过 `PageTransitionsTheme` 接线（`docs/dev/platform.md` §4），
   不依赖任何第三方路由库的能力。
4. 若后续需要深链接（deep link）、嵌套路由或声明式路由恢复，
   **必须先写 ADR 评估 `go_router`**，再修改 `pubspec.yaml`。

## 后果

- 零新增依赖，符合 C-DEP-1。
- 深链接能力当前需要自行实现（Android intent-filter / iOS universal link 解析后手动入栈），
  这部分工作量在需要时通过新 ADR 决策。
- 路由表是唯一的路由来源，页面不得在自己的 `build` 中调用 `Navigator.push` 硬编码下一跳。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 引入 `go_router` | 未经评审的新依赖；当前需求（单栈推送 + 类型化参数）内置方案已足够 |
| 引入 `auto_route` | 需额外代码生成器，且与 build_runner 链路叠加，收益不明确 |
| 各页面自行 `Navigator.push` | 路由分散，无法集中维护返回行为与预测性返回配置 |
