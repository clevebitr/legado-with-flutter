# NOTICE

## 1. 版权

```
flutter_reader — Flutter 阅读 App
Copyright (C) 2026 Clevebitr

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

完整许可证文本见仓库根目录 [`LICENSE`](./LICENSE)（GNU GPL-3.0，version 3 only）。

> **声明措辞说明（勿“补回”）：** 上一段**刻意省略**了 GPL 附录 “How to Apply” 模板里的
> “or (at your option) any later version” 子句，因为本项目采用 **version 3 only**，
> 不接受 “or later” 授权（裁决见 [`docs/dev/adr/0007-license.md`](docs/dev/adr/0007-license.md)）。
> 本节与官方附录模板的**唯一**差异就是这一处；若将来要改为 “or later”，属于放宽条款，
> 必须先新增 ADR 并同步本节、`LICENSE` 与 `README.md`/`CONTRIBUTING.md` 的表述。

> **已校验：** `LICENSE` 与官方文本 `https://www.gnu.org/licenses/gpl-3.0.txt`
> 逐字节一致（35149 字节，`diff` 零差异，2026-10-10）。
>
> 版权持有人名称 `Clevebitr` 取自仓库既有文档的维护者字段与 git 提交身份，
> 若需要改为组织名或实名，请在 ADR-0007 中更新并同步修改本节与 `LICENSE` 的
> “How to Apply”示例。

---

## 2. 与上游 Legado 项目的关系

本项目的**书源规则方言**（字段命名、规则语法）以 [Legado（阅读）](https://github.com/gedoor/legado)
公开的规则说明为兼容目标，但：

- 本项目是**独立的 Flutter / Dart 实现**，与 Legado 项目及其作者**无隶属关系**，也**未获得其背书**。
- 对规则方言的兼容性描述属于**接口与数据格式的互操作性**，不构成对上游源代码的复制。
- 若将来引入任何来自 Legado 的代码移植，必须先在 `docs/dev/adr/` 新增 ADR
  说明许可兼容性，并保留上游版权声明。

Legado 上游项目采用 GPL-3.0 许可。本项目采用同一许可，双方在许可层面相互兼容。

> **上游现状（2026-10-11 核实，详见 ADR-0023）：** 上游仓库已**清空**——默认分支只剩一份
> 停止侵权公告，项目内容已删除。据官方通报（上海市闵行区检察院提起公诉，2026 年 1 月判决），
> 该软件的两名开发者因**侵犯著作权罪**分别被判处有期徒刑二年、一年九个月，各并处罚金，
> 追缴违法所得；认定形态为「用户导入『书源』文件后经**深度链接**无需跳转即可在 App 内
> 直接阅读」，涉近 4000 部作品、非法获利 100 余万元。
>
> 本项目仍以该方言作为**互操作性兼容目标**并沿用其字段命名（ADR-0023 决策 1），但
> **用途限制与免责见 §3**。

---

## 3. 免责声明

1. 本项目是**阅读客户端实现**，**不提供、不托管、不传播、不索引任何书源或阅读内容**。
2. 用户自行导入的第三方书源及其内容，由**用户自行承担**全部合规责任。
3. 本项目不绕过任何付费、登录或版权保护机制；作者不鼓励也不支持使用本项目侵犯他人权益。
4. 软件按“现状”提供，**不提供任何担保**，详见 `LICENSE` §15、§16。
5. **禁止将本项目用于任何侵犯著作权的用途**，包括但不限于：通过「书源」文件与深度链接
   抓取、聚合、缓存或传播未经授权的内容，以及以打赏、广告、引流等方式从中获利。
   实施上述行为者**自行承担全部法律责任**，与本项目作者及贡献者无关。
6. **风险提示：** 同类上游项目已因上述形态被以侵犯著作权罪追究刑事责任（见 §2 的上游现状）。
   本项目**只提供解析引擎与客户端**，不附带任何书源，也不为任何第三方书源的合法性背书。

---

## 4. GPL-3.0 合规义务（分发时必须履行）

| 义务 | 依据 | 本项目做法 |
|---|---|---|
| 随每个副本提供许可证全文 | §4 | 仓库包含 `LICENSE`；应用内提供许可证查看入口（C-UI-9） |
| 分发目标代码时提供 Corresponding Source | §6 | 发布渠道必须同时给出对应版本的源码地址 |
| 交互界面显示 Appropriate Legal Notices | §0、§5d | 「关于 → 法律声明」页面显示版权、无担保声明与许可证入口（C-UI-9） |
| 修改版本标注修改与日期 | §5a | 发布版本必须在 `CHANGELOG.md` 记录改动 |
| 不得附加进一步限制 | §10 | 不得对衍生分发增加额外限制条款 |

> **发布前检查：** 任何打 tag / 上传应用商店的流程都必须确认上述五项，并记录检查人。
> 另需在发布时对**二进制产物**再做一次许可证扫描（`flutter build` 会把原生库、
> Flutter 引擎与 Dart AOT 产物打包进 APK/EXE，本节的源码级扫描不覆盖它们）。

---

## 5. 第三方依赖许可（已核实）

**硬性规则（C-DEP-7）：** 所有直接依赖必须与 GPL-3.0 兼容。
宽松许可（MIT / BSD-2 / BSD-3 / Apache-2.0）可用；
**GPL-2.0-only、无许可证、专有许可一律禁止引入**（GPL-2.0-only 与 GPL-3.0 不兼容）。

**MPL-2.0：只按白名单放行（2026-10-21，ADR-0048）。** MPL-2.0 与 GPL-3.0 兼容（FSF 认定；
MPL-2.0 §3.3 的 Secondary License 允许并入 GPL 作品），但它仍是**文件级 copyleft**，所以政策不是
「MPL 等同 MIT」而是「每一个 MPL 依赖都要一次 ADR + 一个 `tool/scan_licenses.dart` 白名单条目」。
当前白名单只有一个：`enough_convert`（纯 Dart、零依赖，提供 `charset` 缺失的 Big5 码表）。

**核实结果（2026-10-11，新增 `integration_test` 后重扫）：** 对 `pubspec.lock` 中全部 **156 个包**
逐个读取其 `LICENSE` / `COPYING` 文件并分类，结果：

| 许可证 | 数量 |
|---|---|
| BSD-3-Clause | 104 |
| MIT | 37 |
| Apache-2.0 | 10 |
| BSD-2-Clause | 6 |
| **MPL-2.0（白名单：`enough_convert`，ADR-0048）** | **1** |
| Flutter SDK 自带（`source: sdk`，未在 pub cache 中） | 8 |
| **GPL / LGPL / AGPL / 无许可证 / 未识别** | **0** |

> **2026-10-11 增量（搭建设备级测试环境）：** 为支持 Windows / Android 的
> `integration_test`，`dev_dependencies` 新增 SDK 包 `integration_test`（BSD-3-Clause，
> 同 `flutter_test`），并带入 5 个传递依赖：`flutter_driver`、
> `fuchsia_remote_debug_protocol`（均为 `source: sdk`）、`process`、`sync_http`（BSD-3-Clause）、
> `webdriver`（Apache-2.0）。因此基线由 150 包 / BSD-3 93 / Apache 9 / SDK 5
> 变为 **156 包 / BSD-3 95 / Apache 10 / SDK 8**。
> 同时 `tool/scan_licenses.dart` 改为按 `pubspec.lock` 的 `source: sdk` 识别 SDK 包
> （原先按硬编码包名名单，会把这两个新 SDK 包误报为「无许可证文件」）。

> **2026-10-14 增量（书源文件导入）：** `dependencies` 新增 `file_selector ^1.1.0`
> （Flutter 团队维护的联邦插件，**BSD-3-Clause**），带入 9 个传递依赖：
> `file_selector_android` / `_ios` / `_linux` / `_macos` / `_windows`（均 BSD-3-Clause）、
> `file_selector_platform_interface`、`cross_file`、`plugin_platform_interface`、`flutter_web_plugins`
> （后四个均 BSD-3-Clause）。因此基线由 **156 包 / BSD-3 95 / MIT 37 / Apache 10 / BSD-2 6 / SDK 8**
> 变为 **165 包 / BSD-3 104 / MIT 37 / Apache 10 / BSD-2 6 / SDK 8**（`dart run tool/scan_licenses.dart`
> 复算，Risky items: none）。风险判定不变：**GPL / LGPL / AGPL / MPL / 无许可证 / 未识别 = 0**。

> **2026-10-21 增量（Big5 解码，M12）：** `dependencies` 新增 `enough_convert ^1.7.1`
> （**MPL-2.0**，纯 Dart、零传递依赖，`sdk: >=3.11.0`），它的 `Big5Codec` 补上 `charset` 缺失的
> Big5 码表（ADR-0048）。基线由 **165 包 / BSD-3 104 / MIT 37 / Apache 10 / BSD-2 6 / SDK 8**
> 变为 **166 包 + MPL 1**。这是本项目**第一个也是唯一一个** MPL 依赖，靠
> `tool/scan_licenses.dart` 的 `_mplAllowList` 守住：MPL 计数一旦大于白名单条目数，扫描退出码非 0。

> **本次修正了什么：** 旧结果（BSD-2 = 98 / BSD-3 = 1）是因为 §6 的分类特征串写成了
> `3. Neither the name`。Dart 官方包把 BSD 第三条写成**项目符号** `* Neither the name`，
> 带序号的形式只能匹配到 `cascadia` 一个包，其余 93 个 BSD-3 全被误归为 BSD-2。
> 分类本身不影响 C-DEP-7 的结论（两者都是宽松许可），但清单必须准确。
> 现由 `tool/scan_licenses.dart` 可重复执行，不再依赖肉眼判断。

**2026-10-22 增量（听书与音频，M17/ADR-0054）：** `dependencies` 新增 `just_audio ^0.10.6`、
`just_audio_windows ^0.2.3`、`audio_service ^0.18.19`、`flutter_tts ^4.2.5`，全部 **MIT**，并带入
10 个传递依赖（`audio_session` 等，均 MIT / BSD）。`dart run tool/scan_licenses.dart` 复算：
**176 包 / BSD-3 105 / MIT 46 / Apache 10 / BSD-2 6 / MPL 1 / SDK 8，Risky items: none**。
GPL / LGPL / AGPL / 无许可证 / 未识别仍为 0；MPL 白名单仍只有 `enough_convert`。

**2026-10-23 增量（听书二期，ADR-0062）：** `dependencies` 新增 `audio_service_win ^0.0.3`
（Windows 的 SMTC 平台实现，**MIT**）。`dart run tool/scan_licenses.dart` 复算：
**193 包 / BSD-3 105 / MIT 55 / Apache 18 / BSD-2 6 / MPL 1 / SDK 8，Risky items: none**。
GPL / LGPL / AGPL / 无许可证 / 未识别仍为 0；MPL 白名单仍只有 `enough_convert`。
**评估后未采用：** `smtc_windows`（同样 MIT，但走 flutter_rust_bridge，构建需要 Rust 工具链，
且要另起一套通知端口实现）；`audio_service_win` 复用已有 `audio_service` 接线，代价更小。

**2026-10-25 增量（备份与恢复，M22-b/ADR-0073）：** `dependencies` 新增 `archive ^4.5.2`
（Brendan Duncan，**MIT**，纯 Dart；传递依赖 `path`、`posix` 均宽松许可）。它此前已经是
`build_runner` 的 **dev 传递依赖**，这次只是把它提升为运行时直接依赖，所以包总数与分类计数
**不变**：`dart run tool/scan_licenses.dart` 复算仍为
**193 包 / BSD-3 105 / MIT 55 / Apache 18 / BSD-2 6 / MPL 1 / SDK 8，Risky items: none**。
GPL / LGPL / AGPL / 无许可证 / 未识别仍为 0；MPL 白名单仍只有 `enough_convert`。
**评估后未采用：** `flutter_archive`（把 zip 推给各平台原生实现，与「纯 Dart 优先、
Windows/Android 行为一致」相反，且多一层原生库许可审查）。

**2026-10-22 增量（播放后端与 WebView，ADR-0061）：** `dependencies` 新增
`media_kit ^1.2.6`（MIT）、`media_kit_libs_windows_audio ^1.0.9`（包 LICENSE 为 MIT；
Windows 构建随包的 **libmpv / FFmpeg 动态库为 LGPL-2.1+**，见下方手工登记）、
`flutter_inappwebview ^6.1.5`（Apache-2.0）。`dart run tool/scan_licenses.dart` 复算：
**192 包 / BSD-3 105 / MIT 54 / Apache 18 / BSD-2 6 / MPL 1 / SDK 8，Risky items: none**。
GPL / AGPL / 无许可证 / 未识别仍为 0；MPL 白名单仍只有 `enough_convert`。

> **手工登记（扫描脚本看不到二进制许可证）：** `media_kit_libs_windows_audio` 在 Windows
> 构建时下载并随包分发 **libmpv / FFmpeg 的 LGPL-2.1+ 动态库**（media-kit 的 audio-only
> 构建）。它们与 GPL-3.0 兼容（FSF 认定，动态链接），本项目只允许这一处 LGPL（ADR-0061
> §决策 2）；用户可用同版本动态库替换，符合 LGPL-2.1 §6 的可替换要求。

**直接依赖明细：**

| 依赖 | 版本 | 许可证 |
|---|---|---|
| `m3e_design` | 0.2.1 | MIT |
| `dynamic_color` | 1.9.0 | Apache-2.0 |
| `flutter_riverpod` | 3.4.3 | MIT |
| `riverpod_annotation` | 4.0.7 | MIT |
| `html` | 0.15.7 | MIT |
| `cascadia` | 0.8.0 | BSD-3-Clause |
| `json_path` | 0.9.0 | MIT |
| `flutter_qjs_next` | 1.5.2 | MIT |
| `betto_charset_detector` | 0.1.0 | Apache-2.0 |
| `dio` | 5.11.1 | MIT |
| `cached_network_image` | 3.4.1 | MIT |
| `drift` | 2.35.2 | MIT |
| `drift_flutter` | 0.3.1 | MIT |
| `shared_preferences` | 2.5.6 | BSD-3-Clause |
| `path_provider` | 2.1.6 | BSD-3-Clause |
| `logger` | 2.8.0 | MIT |
| `crypto` | 3.0.7 | BSD-3-Clause |
| `charset` | 2.0.1 | Apache-2.0 |
| `archive` | 4.5.2 | MIT |
| `freezed_annotation` | 3.1.0 | MIT |
| `json_annotation` | 4.12.0 | BSD-3-Clause |
| `flutter_lints`（dev） | 6.0.0 | BSD-3-Clause |
| `riverpod_lint`（dev） | 3.1.9 | MIT |
| `build_runner`（dev） | 2.16.2 | BSD-3-Clause |
| `freezed`（dev） | 4.0.2 | MIT |
| `json_serializable`（dev） | 6.14.1 | BSD-3-Clause |
| `riverpod_generator`（dev） | 4.0.9 | MIT |
| `drift_dev`（dev） | 2.35.1 | MIT |
| `just_audio` | 0.10.6 | MIT |
| `just_audio_windows` | 0.2.3 | MIT |
| `audio_service` | 0.18.19 | MIT |
| `audio_service_win` | 0.0.3 | MIT |
| `flutter_tts` | 4.2.5 | MIT |
| `media_kit` | 1.2.6 | MIT |
| `media_kit_libs_windows_audio` | 1.0.9 | MIT（随包 libmpv / FFmpeg 动态库：LGPL-2.1+，手工登记） |
| `flutter_inappwebview` | 6.1.5 | Apache-2.0 |
| `mocktail`（dev） | 1.0.5 | MIT |
| `flutter` / `flutter_localizations` / `flutter_test` / `integration_test`（SDK） | 3.47.7 | BSD-3-Clause（Flutter SDK） |

---

## 6. 如何重新执行许可证扫描

扫描只依赖本地 pub cache，不需要联网。**必须跑脚本，不要凭肉眼判断**：
2026-10-11 的复扫证明，一个写错的特征串就能把 93 个包归错类（见第 3 步）。

```bash
dart run tool/scan_licenses.dart            # 打印各许可证计数与风险项
dart run tool/scan_licenses.dart --list     # 额外逐包打印分类，便于与 §5 基线逐行核对
```

该脚本等价于以下步骤，人工复核时按此执行：

1. 从 `pubspec.lock` 取出全部包名与版本；`source: sdk`（Flutter SDK 自带，如 `flutter`、
   `flutter_test`、`integration_test`、`flutter_driver`）的条目只计数、不读许可证文件；
2. 逐个读取包目录下的 `LICENSE*` / `COPYING*`（pub cache 路径依次探测 `PUB_CACHE`、
   `%LOCALAPPDATA%\Pub\Cache`、`~/.pub-cache`）；**同一文件内的多段许可证以第一段为准**
   ——包自身的许可证在前，随后才是随包分发的第三方声明
   （例：`sqlcipher_flutter_libs` 第一段是 MIT，其后才是 OpenSSL 的 Apache-2.0）；
3. 按特征串分类：
   - MIT：`Permission is hereby granted`
   - Apache-2.0：`Apache License` + `Version 2.0`
   - BSD-3-Clause：`Redistribution and use in source and binary forms` + **`Neither the name`**
   - BSD-2-Clause：含 BSD 特征串但**不含** `Neither the name`
   - GPL 系：`GNU ...`；MPL 系：`Mozilla Public License`

   > **禁止把 `3. Neither the name` 当作特征串。** Dart 官方包把 BSD 第三条写成项目符号
   > `* Neither the name`；用带序号的形式只能匹配到极少数包。2026-10-11 实测：101 个包含
   > BSD 特征串，其中 95 个含第三条（仅 `cascadia` 用带序号写法），6 个不含（`sqflite*` 系列）。
4. **计数校验：** 各许可证数量之和必须等于 `pubspec.lock` 的包数（当前 95 + 37 + 10 + 6 = 148，
   加 8 个 Flutter SDK 自带包 = 156）。重扫后与 §5 的基线**逐项 diff**：有差异时先判断是
   “新增/升级依赖”还是“分类规则变了”，后者必须先修规则再回写基线。
5. 出现 GPL 系 / 无许可证文件 / 无法识别任一情况时，**先开 ADR 再决定**是否引入；
   MPL 系先查 `tool/scan_licenses.dart` 的 `_mplAllowList`：不在名单里就是风险项（退出码非 0），
   加入名单必须同时写 ADR（首例 ADR-0048）并更新本节基线。

**触发时机：** 新增依赖、升级依赖、以及**每次发布前**（发布时还需覆盖二进制产物）。

---

**最后更新：** 2026-10-21
