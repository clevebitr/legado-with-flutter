# ADR-0007 许可证：GNU GPL-3.0

- **状态：** **Accepted**
- **日期：** 2026-10-10（2026-10-10 裁决并生效）
- **关联：** `LICENSE`、`NOTICE.md`、C-DEP-7、C-UI-9、`CONTRIBUTING.md` §8、`README.md`

## 背景

旧文档互相矛盾：`AGENTS.md` 写「遵循 Legado 社区规范」，`CONTRIBUTING.md` 写「MIT License」
并链接了并不存在的 `./LICENSE`。上游 **Legado 采用 GPL-3.0**。

审计曾列出三种情形：

| 情形 | 结论 |
|---|---|
| 仅复现规则方言（自行实现解析），未复制上游代码 | MIT 可用 |
| 移植或改写了上游实现代码 | 必须 GPL-3.0 |
| 仅使用用户提供的书源 JSON 数据 | 不构成代码衍生，不影响本项目许可证 |

## 决策

**裁决结果：本项目采用 GNU GPL-3.0（`GPL-3.0`，即 version 3 only，非 “or later”）。**

1. 根目录 `LICENSE` 存放 GPL-3.0 完整官方文本。
2. 根目录新增 `NOTICE.md`：版权、与上游关系声明、免责声明、GPL 合规义务清单、
   第三方依赖许可清单。
3. 新增约束 **C-DEP-7**：所有直接依赖必须与 GPL-3.0 兼容；
   禁止引入 GPL-2.0-only / 无许可证 / 专有许可的包。
4. 新增约束 **C-UI-9**：必须提供「关于 → 法律声明」页面，
   显示版权、无担保声明与许可证全文查看入口（GPL-3.0 §0 / §5d / §6）。
5. `README.md`、`CONTRIBUTING.md`、`CHANGELOG.md` 同步更新；不再出现“待裁决”。

## 后果

- **Copyleft 生效：** 任何分发（含应用商店、二进制分发包）必须同时提供
  Corresponding Source，并保留许可证与版权声明（`NOTICE.md` §4）。
- 新增依赖的许可审查成为强制流程（C-DEP-7）；`NOTICE.md` §5 维护完整核实表，
  2026-10-10 已对 `pubspec.lock` 中全部 **150 个包**完成扫描，**零风险项**
  （无 GPL 系 / MPL / 无许可证 / 未识别），并附上可重复的扫描方法（§6）。
- 若将来要从 “only” 改为 “or later”，属于放宽条款，需新增 ADR 并同步
  `LICENSE` 声明与 `NOTICE.md`。
- 「关于 → 法律声明」页面成为发布前的功能验收项，需要 ARB 文案键
  `legalNoticesTitle` / `legalNoticesCopyright` / `legalNoticesNoWarranty` /
  `legalNoticesViewLicense` / `legalNoticesCorrespondingSource`。

## 遗留事项

| 项 | 说明 |
|---|---|
| 版权持有人名称 | 现取 `Clevebitr`（来自仓库既有文档的维护者字段与 git 提交身份）；如需改为组织名或实名，须同步 `NOTICE.md` §1 与本节 |
| `LICENSE` 文本校验 | ✅ **已闭环**：与 `https://www.gnu.org/licenses/gpl-3.0.txt` 逐字节一致（35149 字节，`diff` 零差异） |
| `NOTICE.md` §1 声明措辞 | ✅ **已闭环（2026-10-11）**：该节原照抄 GPL 附录模板，含 “or (at your option) any later version”，与本 ADR 的 **version 3 only** 直接冲突；已删除该子句并加注说明。今后不得按 GPL 附录原文“补回” |
| 依赖许可核实 | ✅ **已闭环**：`pubspec.lock` 全部包已扫描完毕，零风险项（2026-10-10 为 **150** 个包；当前计数与分类基线见 `NOTICE.md` §5）。
  发布时仍需对二进制产物再做一次扫描（引擎切换后由 151 → 150，重扫记录见 `NOTICE.md` §5） |

## 备选方案

| 方案 | 否决原因 |
|---|---|
| MIT | 若存在任何上游代码移植即违规；且与上游 GPL-3.0 生态不一致 |
| GPL-3.0-or-later | 会自动授予未来 FSF 版本条款；裁决选择更可控的 “only” |
| AGPL-3.0 | 本项目不提供服务端网络交互，无必要 |
| 暂不定许可 | 分发即无许可，法律状态更差 |
