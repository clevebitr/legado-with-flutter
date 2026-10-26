# ADR-0067 三条发布通道：正式版 / beta / debug，各自独立的 workflow

- **状态：** Accepted（2026-10-23，用户要求「拆成三个任务 + 各自的版本号方案」）
- **日期：** 2026-10-23
- **关联：** ADR-0065（分层 CI 的初版，本 ADR 修订其 §决策 1/4）、ADR-0013 §5（门禁命令单一出处）、
  ADR-0019、`docs/dev/testing.md` §7、`docs/dev/platform.md` §8.3、CONTRIBUTING.md §5.4

## 背景

ADR-0065 把「门禁 + 三平台构建 + Release」塞进了同一个 `ci.yml`，用 `if:` 区分 PR 与 main/tag。
用户后续要的是**三条彼此独立的发布通道**，而且各自的**版本号规则不同**：

- 正式版：就是 `pubspec.yaml` 里的版本，tag 与它一致；
- beta：在一批 debug 迭代之后定格，版本号带提交哈希；
- debug：每次迭代都出，版本号还要带时间，用来区分「同一提交的重跑」。

一个文件里用 `if` 拼三种语义会让「谁在什么时候发什么版本」变得不可读，也无法让某条通道单独重跑。

## 决策

### 决策 1 一个门禁 + 一个可复用构建 + 三条通道，各自一个文件

| 文件 | 角色 | 触发 |
|---|---|---|
| `ci.yml` | **L1 门禁**（`verify`，规则集要求的 status check，名字不许改） | PR、push main、push `v*` tag、手动 |
| `build-artifacts.yml` | **可复用构建**（`workflow_call`）：Windows / Android / iOS 三平台，`channel` 与 `version` 由调用方给 | 只被下面三条调用 |
| `release.yml` | **正式版**：tag ↔ `pubspec` 版本强校验 → 等门禁绿 → 构建 → 正式 Release（`--prerelease=false`） | push `v*` tag、手动（给 tag） |
| `beta.yml` | **beta**：等门禁绿 → 构建 → **预发布** Release（tag `v<版本>-beta.<sha7>`） | 仅手动 dispatch（可指定 ref 与说明） |
| `debug.yml` | **debug**：等门禁绿 → 构建 → **预发布** Release（tag `v<版本>-debug.<sha7>.<时间>`） | push main、手动 |

- **跨 workflow 的「先门禁后打包」**：GitHub 的 `needs` 不能跨 workflow，`workflow_run` 又要求触发者
  在默认分支上、且手动 dispatch 不产生它。因此三条通道都跑一个 composite action
  `.github/actions/wait-for-verify`：轮询该 commit 的 `ci.yml` 运行直到 `verify` 成功（上限 40 分钟），
  失败即中止。**打包用例只在门禁绿之后才开始**，而门禁命令仍只有 `ci.yml` 一处实现。
- 版本号组合也只有一处实现：`.github/actions/version`（composite action）。

### 决策 2 版本号规则

| 通道 | `<version>` | 例子 | 用途 |
|---|---|---|---|
| 正式版 | `pubspec.yaml` 的 `version:`（去 `+build`）且 **tag 必须等于 `v<version>`** | `v0.1.0` / `0.1.0` | 对外发布；版本号与内容强一致 |
| beta | `<manifest>-beta.<sha7>` | `0.1.0-beta.a1b2c3d` | 一批迭代的验收点；同一提交重复打是同一个版本号 |
| debug | `<manifest>-debug.<sha7>.<yyyyMMddHHmm>` | `0.1.0-debug.a1b2c3d.202610231540` | 每次迭代；时间戳区分同一提交的重跑 |

- `--build-number` 统一用 `github.run_number`（单调递增的整数，Android 要求整数、iOS 用它做
  `CFBundleVersion`）。
- **iOS 的 `CFBundleShortVersionString` 只能是点分数字**：所以 iOS 构建拿 `manifest` 当 `--build-name`，
  通道信息只进 `--dart-define=APP_VERSION`（关于页显示）与产物文件名。Android 的 `versionName`、
  Windows 无版本资源，都可以直接带后缀。
- 产物名统一为 `flutter-reader-<version>-{windows-x64.zip, android.apk, android.aab,
  ios-unsigned.xcarchive.zip}`，Release 名与 tag 同名。
- 关于页的版本来自 `--dart-define=APP_VERSION`，默认值仍是 `pubspec` 的版本
  (`app_info.dart`)，所以本地运行与测试看到的行为不变。

### 决策 3 beta 与 debug 永远是 pre-release，且不进商店

两条通道都 `gh release create --prerelease`：APK 是 debug 签名、iOS 归档未签名（ADR-0065 §决策 3），
所以它们的定位是「可安装的迭代产物」。上架前的签名/包名清单仍在 `docs/dev/platform.md` §8.2。

### 决策 4 debug 走每次 main 前进，beta 与正式版走人工

- debug：`main` 每次 push 都发（代价是每次合并多一轮三平台构建，约 15–25 分钟；不想付就把它改成只在
  手动 dispatch 时跑 —— 只需删掉 `push:` 触发器）。
- beta：只在人判断「这批迭代可以验收」时手动触发，可以指定已验收的提交。
- 正式版：tag 驱动，tag 与版本不一致直接失败。

## 后果

- `ci.yml` 回到「只有门禁」的单一职责；发布相关的 187 行从它移出。
- 新增两个 composite action（`version`、`wait-for-verify`）与一个可复用 workflow。
- 首次验证只能靠真实触发：合并到 `main` 后 `debug.yml` 自动开跑，它的 `gate` 先等到该提交的
  `ci.yml` 绿；第一轮暴露了 Windows 侧的工具链问题（`windows-latest` 已是 VS 2026，MSVC 14.5x 把
  `<experimental/coroutine>` 的弃用升级成硬错误，`just_audio_windows` 因此编译失败），修法与登记见
  `docs/dev/platform.md` §8.1。
- 已知限制：`wait-for-verify` 依赖 `gh run list --commit`（tag push 与分支 push 都能查到）；
  若组织的 Actions 保留期清掉了旧运行，重新跑一次 `ci.yml` 即可。
