# ADR-0065 分层 CI：门禁、平台构建与发布三件事分开

- **状态：** Accepted（2026-10-23，用户要求「分层 CI，支持构建 Windows / macOS / iOS / APK 的 release 资源」）
- **日期：** 2026-10-23
- **关联：** ADR-0013 §5（门禁命令单一出处）、ADR-0019（覆盖率门禁）、
  `docs/dev/testing.md` §7（CI 顺序）、`docs/dev/platform.md` §8.2/§8.3、
  CONTRIBUTING.md §5.4（`verify` 是 `main` 规则集要求的 status check）

> **2026-10-23 修订注记（ADR-0067）：** 本 ADR 的 §决策 1（同文件三层的 job 形态）与 §决策 4 的
> 具体实现已被 ADR-0067 取代 —— 打包与发布从 `ci.yml` 拆到 `build-artifacts.yml` + `release.yml` /
> `beta.yml` / `debug.yml` 三条独立通道，版本号也按通道区分（正式版 / beta / debug）。仍然有效的是：
> 门禁 `verify` 只在一处实现、PR 不打包、产物形态与签名局限（§决策 3）、签名材料不进 CI（§决策 5）、
> macOS 本轮不做。

## 背景

原来的 `.github/workflows/ci.yml` 只有一件事：在 `ubuntu-latest` 上跑门禁（`verify`）。
要发布时只能靠开发机手工 `flutter build ...`，产物形态与「哪些平台被验证过」都没有记录；
同时 `main` 的规则集把 `verify` 当成必需的 status check，任何改造都不能把这个名字弄丢。

用户要求的分层与四个平台的产物需要先分清代价：**macOS / iOS 的 runner 是 Linux 的 10–20 倍计费**，
一个四平台构建约 20–30 分钟，放在每个 PR 上会把合并变成排队。

## 决策

### 决策 1 三层，同名 workflow 内用 `needs` 串起来

| 层 | job | 触发 | 做什么 |
|---|---|---|---|
| L1 门禁 | `verify`（**名字不许改**，规则集按它判） | 每个 PR / push main / tag / 手动 | `AGENTS.md` §4 的全部命令 + 生成物一致性（顺序见 `testing.md` §7） |
| L2 构建 | `build-windows` / `build-android` / `build-ios` | `push` main、`v*` tag、`workflow_dispatch`；`needs: verify` | `flutter build ... --release` 并 upload-artifact |
| L3 发布 | `release` | 仅 `v*` tag；`needs:` 三个构建 | 下载三份产物，用 `gh release upload` 挂到同名 Release |

在**同一个** workflow 里做分层，而不是三个 workflow：跨 workflow 无法 `needs`，要么重复跑门禁、要么用
`workflow_run` 的间接触发。同文件里 `needs: verify` 让「门禁没过就不打包」成为结构保证。

### 决策 2 PR 上不打包

L2/L3 全部带 `if: github.event_name != 'pull_request'`。打包是**发布前**的事，PR 需要的是快反馈；
打包回归靠 main 上的 push（每次合并都打一次）与 tag 兜住。

### 决策 3 产物形态：能装、能验证，不假装能上架

| 平台 | 命令 | 产物 | 局限（已登记） |
|---|---|---|---|
| Windows | `flutter build windows --release` | `flutter-reader-<版本>-windows-x64.zip`（整个 `Release/` 目录） | 需要 VS 2022 运行库；跨机器运行前见 `platform.md` §1.2 |
| Android | `flutter build apk --release` + `flutter build appbundle --release` | `…-android.apk`（通用）+ `…-android.aab` | release 仍复用 **debug 签名**，`applicationId` 仍是 `com.example.flutter_reader` ⇒ APK 能装不能上架（§8.2） |
| iOS | `flutter build ipa --no-codesign` | `…-ios-unsigned.xcarchive.zip` | **未签名**：只能证明能编译能归档，**不能装真机、不能 TestFlight / 上架**；签名所需的密钥不进 CI（决策 5） |
| macOS | — | 本轮**不做** | 仓库没有 `macos/` 平台工程（目标平台仍是 Android / iOS / Windows）。要做 = 先 `flutter create --platforms=macos .` + 三端验收 + 插件面复核，单独立项（用户 2026-10-23 裁决先做其余三个） |

### 决策 4 发布只用 runner 自带的 `gh`，不引第三方 release action

`actions/upload-artifact` / `download-artifact` 与 `subosito/flutter-action` 是既有依赖（`ci.yml` 已用）；
Release 的上传用预装的 `gh release create` / `gh release upload --clobber`，权限限定 `contents: write`。
少一个第三方 action 就少一条供应链风险，也不需要额外的 PAT。

### 决策 5 CI 里不放任何签名材料

签名证书、描述文件、keystore 全部**不进仓库也不进 CI secrets**，直到有真实的发布需求（见 §后果）。
理由：无签名产物已能满足「每次合并都能打包」的目的；把长期有效的分发证书放进单人维护期的 CI，
收益为零、风险不小。`ios/Podfile` 同理不在仓库里 —— Flutter 在第一次 iOS 构建时按模板生成，
CI 的 `pod install` 用的是同一份模板，因此结果仍可复现。

## 后果

- 每次合并到 main 会跑三种 release 构建（约 15–25 分钟，与 `verify` 并行受限：`needs` 让它们串在门禁后）。
  想省钱就把 L2 的触发改成只在 tag/手动，这只需要改 `ci.yml` 的一个 `if:`。
- 真正上架前的清单（`platform.md` §8.2）：换 `applicationId` / bundle id、配 release keystore、
  拿 Apple Developer Program 的证书与描述文件并把它们接成 CI secrets（步骤见 §8.3）。
- 回归点：workflow 的 YAML 结构在本地用 `package:yaml` 解析校验过（job 名、`needs`、`if`、`runs-on`、
  step 数）；真正的编译验证只有 CI 能给 —— 因此首轮 tag/手动 dispatch 必须人工看一遍三个构建的日志。
- 版本号取 `pubspec.yaml` 的 `version:`（去掉 `+build`），产物名与 Release 名一致，发布后不需要手工改名。
