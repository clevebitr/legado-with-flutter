# ADR-0018 Android 平台基线：保留 `minSdk 26`，并重建其依据

- **状态：** Accepted
- **日期：** 2026-10-11
- **关联：** C-PLT-5、`docs/dev/platform.md` §1、ADR-0013 §3、ADR-0015、`android/app/build.gradle.kts`

## 背景

`platform.md` §1 与 `android/app/build.gradle.kts` 的注释把 `minSdk 26` 的依据写成
「`flutter_js_plus` 要求 Android 8+，而 Flutter 3.47 的默认值为 24」。

ADR-0015 已用 `flutter_qjs_next 1.5.2` 取代 `flutter_js_plus`。实测该引擎的
`android/build.gradle` 为 **`minSdk = 21`**，其 `pubspec.yaml` 声明的平台为
Android/iOS/macOS/Linux/Windows。也就是说：

- 原文引用的**依据已经不存在**；
- 继续照抄会得到一个「事实错误但没人会发现」的基线理由；
- 而 `minSdk` 是 C-PLT-5 明令「不得在文档其他位置另立数值」的基线，
  改动它属于规范变更（ADR-0013 §4）。

## 决策

1. **保留 `minSdk 26`（Android 8.0），不因更换引擎而下调。**
2. 依据改写为三条**可验证**的自身理由，不再引用任何第三方包的要求：
   - 本项目自 ADR-0003 起以 Drift + `drift_flutter` 提供原生 SQLite（传递引入
     `sqlite3_flutter_libs`），Android 8.0 是本项目愿意承担的最低测试面；
   - Android 8.0 以下的设备占比与维护成本不成比例，而**降低基线只需一个新 ADR，提高基线是破坏性变更**，
     因此基线宁高不低；
   - `dynamic_color`、`path_provider`、`shared_preferences`、`cached_network_image`
     的当前版本在 API 26 上均为已验证组合（`flutter build apk --debug` 通过）。
3. `platform.md` §1 的「依据」列、§1.1/§1.2 的验证状态、以及
   `android/app/build.gradle.kts` 的注释同步改写；
   注释中不得再出现任何**已被移除**的依赖名。
4. `targetSdk`（跟随 `flutter.targetSdkVersion`，当前 36）与 iOS `15.0` 的数值不变；
   ADR-0013 §3 中过期的复述值按 §5 一并修正。
5. 若将来要下调到 21/24，必须新开 ADR，并在同一次改动中重跑 Android 构建验证。

## 后果

- 「构建变通」「平台基线」与「被移除的引擎」三者彻底解耦：
  以后更换 JS 引擎不再需要复核 `minSdk`。
- `CHANGELOG.md` 中「minSdk pinned to 26 because of `flutter_js_plus`」的表述改为
  指向本 ADR（该条目仍在 `[Unreleased]`，属当前版本的记录，允许修正）。
- 因为是**保留**而非提升基线，本次变更对已装机用户与产物无任何影响。

## 备选方案

| 方案 | 否决原因 |
|---|---|
| 下调到 Flutter 默认 24 | 基线变更需重跑三端验收（`platform.md` §6），而收益只是「覆盖 Android 7 设备」；且会立刻产生一份需要重新评估的测试面 |
| 下调到引擎要求的 21 | 需额外验证 `drift_flutter` / `dynamic_color` 在 API 21–25 的行为，成本远大于收益 |
| 只删掉「flutter_js_plus 要求」这半句，不给新依据 | 会留下一条无理由的基线，违反 C-PLT-5 的可判定原则（「凡不能判定的表述视为缺陷」） |
