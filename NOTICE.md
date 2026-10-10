# NOTICE

## 1. 版权

```
flutter_reader — Flutter 阅读 App
Copyright (C) 2026 Clevebitr

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

完整许可证文本见仓库根目录 [`LICENSE`](./LICENSE)（GNU GPL-3.0，非“或更高版本”）。

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

---

## 5. 第三方依赖许可

**硬性规则（C-DEP-7）：** 所有直接依赖必须与 GPL-3.0 兼容。
宽松许可（MIT / BSD-2 / BSD-3 / Apache-2.0）可用；
**GPL-2.0-only、无许可证、专有许可一律禁止引入**（GPL-2.0-only 与 GPL-3.0 不兼容）。

| 依赖 | 许可证 | 核实状态 |
|---|---|---|
| `m3e_design` | MIT | 已核实 |
| `dynamic_color` | Apache-2.0 | 已核实 |
| `cascadia` | BSD-3-Clause | 已核实 |
| `flutter_js_plus` | MIT | 已核实 |
| `betto_charset_detector` | Apache-2.0 | 已核实 |
| `flutter_riverpod` / `riverpod_annotation` / `riverpod_generator` / `riverpod_lint` | MIT | 待核实 |
| `html` | BSD-3-Clause | 待核实 |
| `json_path` | MIT | 待核实 |
| `dio` | MIT | 待核实 |
| `drift` / `drift_dev` / `drift_flutter` | MIT | 待核实 |
| `cached_network_image` | MIT | 待核实 |
| `shared_preferences` / `path_provider` | BSD-3-Clause | 待核实 |
| `logger` | MIT | 待核实 |
| `freezed` / `freezed_annotation` / `json_serializable` / `json_annotation` / `build_runner` | MIT | 待核实 |
| `flutter_lints` | BSD-3-Clause | 待核实 |
| `mocktail` | MIT | 待核实 |

**核实方法（有 Flutter SDK 的环境执行）：**

```bash
flutter pub deps --json > /tmp/deps.json
# 逐个核对 pub.dev 上的 license 字段，或使用许可证扫描工具；
# 任何非宽松许可都必须先开 ADR 再决定是否引入。
```

核实完成后，把上表「待核实」改为「已核实」，并追加传递依赖中出现的新许可类型。

---

**最后更新：** 2026-10-10
