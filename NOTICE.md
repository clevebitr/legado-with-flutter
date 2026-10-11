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

---

## 3. 免责声明

1. 本项目是**阅读客户端实现**，**不提供、不托管、不传播、不索引任何书源或阅读内容**。
2. 用户自行导入的第三方书源及其内容，由**用户自行承担**全部合规责任。
3. 本项目不绕过任何付费、登录或版权保护机制；作者不鼓励也不支持使用本项目侵犯他人权益。
4. 软件按“现状”提供，**不提供任何担保**，详见 `LICENSE` §15、§16。

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

**核实结果（2026-10-11，修正分类规则后重扫）：** 对 `pubspec.lock` 中全部 **150 个包**逐个读取其
`LICENSE` / `COPYING` 文件并分类，结果：

| 许可证 | 数量 |
|---|---|
| BSD-3-Clause | 93 |
| MIT | 37 |
| Apache-2.0 | 9 |
| BSD-2-Clause | 6 |
| Flutter SDK 自带（未在 pub cache 中） | 5 |
| **GPL / LGPL / AGPL / MPL / 无许可证 / 未识别** | **0** |

> **本次修正了什么：** 旧结果（BSD-2 = 98 / BSD-3 = 1）是因为 §6 的分类特征串写成了
> `3. Neither the name`。Dart 官方包把 BSD 第三条写成**项目符号** `* Neither the name`，
> 带序号的形式只能匹配到 `cascadia` 一个包，其余 93 个 BSD-3 全被误归为 BSD-2。
> 分类本身不影响 C-DEP-7 的结论（两者都是宽松许可），但清单必须准确。
> 现由 `tool/scan_licenses.dart` 可重复执行，不再依赖肉眼判断。

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
| `freezed_annotation` | 3.1.0 | MIT |
| `json_annotation` | 4.12.0 | BSD-3-Clause |
| `flutter_lints`（dev） | 6.0.0 | BSD-3-Clause |
| `riverpod_lint`（dev） | 3.1.9 | MIT |
| `build_runner`（dev） | 2.16.2 | BSD-3-Clause |
| `freezed`（dev） | 4.0.2 | MIT |
| `json_serializable`（dev） | 6.14.1 | BSD-3-Clause |
| `riverpod_generator`（dev） | 4.0.9 | MIT |
| `drift_dev`（dev） | 2.35.1 | MIT |
| `mocktail`（dev） | 1.0.5 | MIT |
| `flutter` / `flutter_localizations` / `flutter_test`（SDK） | 3.47.7 | BSD-3-Clause（Flutter SDK） |

---

## 6. 如何重新执行许可证扫描

扫描只依赖本地 pub cache，不需要联网。**必须跑脚本，不要凭肉眼判断**：
2026-10-11 的复扫证明，一个写错的特征串就能把 93 个包归错类（见第 3 步）。

```bash
dart run tool/scan_licenses.dart            # 打印各许可证计数与风险项
dart run tool/scan_licenses.dart --list     # 额外逐包打印分类，便于与 §5 基线逐行核对
```

该脚本等价于以下步骤，人工复核时按此执行：

1. 从 `pubspec.lock` 取出全部包名与版本；
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
   > `* Neither the name`；用带序号的形式只能匹配到极少数包。2026-10-11 实测：99 个包含
   > BSD 特征串，其中 93 个含第三条（仅 `cascadia` 用带序号写法），6 个不含（`sqflite*` 系列）。
4. **计数校验：** 各许可证数量之和必须等于 `pubspec.lock` 的包数（当前 93 + 37 + 9 + 6 = 145，
   加 5 个 Flutter SDK 自带包 = 150）。重扫后与 §5 的基线**逐项 diff**：有差异时先判断是
   “新增/升级依赖”还是“分类规则变了”，后者必须先修规则再回写基线。
5. 出现 GPL 系 / MPL / 无许可证文件 / 无法识别任一情况时，**先开 ADR 再决定**是否引入。

**触发时机：** 新增依赖、升级依赖、以及**每次发布前**（发布时还需覆盖二进制产物）。

---

**最后更新：** 2026-10-11
