# 内置规则种子（assets/rules/）

这两个文件随包发布，在 `rules` 表**第一次为空时**被播种成 `is_built_in = 1` 的行
（`docs/dev/roadmap.md` M20，ADR-0070 §决策 4 与「增补 §5」）。

| 文件 | 来源 | 内容 |
|---|---|---|
| `txt_toc_rule.json` | 上游 `app/src/main/assets/defaultData/txtTocRule.json` | 27 条目录规则（`txt_toc_rule`），字段 `chapterRule` / `volumeRule` / `example` / `serialNumber` / `enable` |
| `dict_rule.json` | 上游 `app/src/main/assets/defaultData/dictRules.json` | 2 条字典规则（百度汉语 / 海词英文），字段 `urlRule` / `showRule` / `enabled` / `sortNumber` |

- **来源版本：** `legado-upstream` 提交 `49c31c97`。
- **许可：** 上游与本仓同为 GPL-3.0，直接移植不需要新的许可证白名单（C-DEP-7 约束的是**依赖**）。
- **净化 / 高亮不播种：** 上游 `defaultData/` 里没有默认净化规则或高亮规则，本仓也不发明——
  凭空写一条净化会把用户的正文改掉且无从解释（ADR-0070 增补 §5）。
- **更新方式：** 从上游重新拷贝这两个文件后跑一遍规则测试；`payload` 的字段映射在
  `lib/features/rules/data/rule_seed_loader_impl.dart`，不认识的键会原样留在 payload 的
  `extra` 里（ADR-0021 的同一立场）。
