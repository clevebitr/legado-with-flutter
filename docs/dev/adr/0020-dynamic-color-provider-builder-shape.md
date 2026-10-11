# ADR-0020 动态取色接口以 builder 包装形态提供，并在根部注入

- **状态：** Accepted
- **日期：** 2026-10-11
- **关联：** C-PLT-1、C-PLT-2、C-UI-3、C-TYPE-2、ADR-0004、`docs/dev/platform.md` §2/§3、`docs/dev/testing.md` §5

## 背景

`platform.md` §2 初版把平台抽象接口的契约写成两条：

| 接口 | 初版措辞 |
|---|---|
| `DynamicColorProvider` | 「返回系统动态取色 `ColorScheme?`，不支持时返回 `null`」；UI 侧用法「注入 `core/theme/`」 |
| `PlatformInfo` | UI 侧用法「只允许在 `core/platform/` 内使用」 |

P1.3 落地时发现第一条**无法照字面实现**：`dynamic_color 1.9.0` 只通过
`DynamicColorBuilder`（一个 widget + `builder(ColorScheme? light, ColorScheme? dark)`
回调）暴露系统取色，没有任何同步 API 能直接拿到 `ColorScheme?`。

于是出现三种可能：

1. 接口返回 `Future<ColorScheme?>`，在根部用 `FutureBuilder` 承接；
2. 在 `lib/app.dart` 里直接使用 `DynamicColorBuilder`（放弃抽象）；
3. 接口本身**包装 builder**：`Widget resolve(Widget Function(ColorScheme?, ColorScheme?) builder)`。

同时 `PlatformInfo` 的实际接线是 `core/di/platform_provider.dart` 里的可注入 Provider，
任何层都能 `ref.watch`，与 §2 的「只允许在 `core/platform/` 内使用」字面冲突。

按 `docs/dev/adr/README.md` 规则 3，改动 `docs/dev/` 规范的既有结论必须由 ADR 裁决。

## 决策

1. **接口形态采用方案 3（builder 包装）**：

   ```dart
   abstract interface class DynamicColorProvider {
     Widget resolve(Widget Function(ColorScheme? light, ColorScheme? dark) builder);
   }
   ```

   理由：`dynamic_color` 的取色本就是**异步到达**的（首次平台通道返回前为空），
   builder 形态把「还没有值」表达成 `null` 参数而不是「还没有结果」，因此**不需要**
   `FutureBuilder`，也就没有主题首帧用种子色再跳到系统色的闪烁。

2. **注入点是 `lib/app.dart`**，不是 `core/theme/`：`MaterialApp` 的 `theme` /
   `darkTheme` 只能在其装配处一次性确定，`core/theme/` 只负责把拿到的
   `ColorScheme` 转成 `M3ETheme`（`buildReaderTheme`）。`app.dart` 因此不判断平台、
   也不 import `dynamic_color`（C-PLT-1、C-PLT-2）。

3. **无能力的平台返回 `null` provider**：`resolveDynamicColorProvider(PlatformInfo)`
   是唯一一处「哪个平台有取色能力」的判断，Windows / iOS 直接得到 `null`，
   调用方走种子色 fallback（C-PLT-3、C-PLT-4、`platform.md` §3）；
   Android 得到 `SystemDynamicColorProvider`，在 Android 12 以下由
   `DynamicColorBuilder` 自行回传 `null`，因此**不需要版本号判断**。

4. **`PlatformInfo` 保持「可注入但只供 `core/platform/` 与测试消费」**：
   它是 `core/di/platform_provider.dart` 的公开 Provider（测试必须能覆盖它来模拟平台），
   但业务层不得用它分支平台——平台差异一律经能力接口暴露。
   `platform.md` §2 的措辞按此改写，而不是让实现退回到「Provider 私有」。

5. `platform.md` §2/§3 同步为本形态；`constraints.md` C-PLT-2 回链本 ADR。

## 后果

- `platform.md` §2 的 `DynamicColorProvider` 一行不再写「返回 `ColorScheme?`」，
  改写 builder 包装形态与 `null` 语义；§3 的取色链路补上「在根部交给
  `core/theme/` 的 `buildReaderTheme`」这一段。
- Golden 测试固定 fallback 的写法确定为
  `platformDynamicColorProvider.overrideWithValue(null)`（`testing.md` §5）。
- 新增平台只需改 `resolveDynamicColorProvider` 一处：有取色能力返回实现，
  没有则返回 `null`（或将来的 no-op 实现）。
- **Provider 函数命名约束：** 函数不能叫 `dynamicColor`，否则 `riverpod_generator`
  会生成与接口同名的类 `DynamicColorProvider`，产生命名冲突；现名为
  `platformDynamicColor`（生成 `platformDynamicColorProvider`）。
- 若将来 `dynamic_color` 提供同步 API，本 ADR 需要重新评估；
  在此之前不得在 `lib/app.dart` 或任何业务层直接使用 `DynamicColorBuilder`。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| `Future<ColorScheme?> resolve()` + 根部 `FutureBuilder` | 主题首帧只能用种子色、取色到达后跳变；且 golden 与 widget 测试都要处理「尚未完成的 Future」，复杂度上升 |
| 在 `lib/app.dart` 直接使用 `DynamicColorBuilder` | 违反 C-PLT-1 / C-PLT-2：UI 直接依赖平台插件并隐含平台判断；换平台或换取色库要改 UI |
| 接口保持「返回 `ColorScheme?`」，由 `core/theme/` 包一层 builder | `core/theme/` 会反向依赖 `core/platform/` 且仍需在 `app.dart` 装配 `MaterialApp`，多一层包装没有消除任何判断，只增加间接层 |
| 把 `PlatformInfo` 的 Provider 设为私有，只留能力接口 | 测试无法覆盖平台分支（`ProviderScope(overrides:)` 需要公开 Provider），会逼出「实现里为测试开分支」，违反 `architecture.md` §4 |
