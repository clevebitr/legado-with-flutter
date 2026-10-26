# `assets/zh/` — 简繁转换码表

`java.t2s` / `java.s2t`（`docs/dev/book-source.md` §6）用的两张码表。它们**不是**上游 legado 的那一份，
原因与结论见 `NOTICE.md` §5 与 ADR-0078 §实现注记 S3b。

## 1. 来源

由 **OpenCC** 的字典生成（Apache-2.0，`LICENSE` 已核实）：

| 文件 | 上游文件（`BYVoid/OpenCC`，`data/dictionary/`） |
|---|---|
| `t2s.txt`（繁 → 简） | `TSCharacters.txt` + `TSPhrases.txt` |
| `s2t.txt`（简 → 繁） | `STCharacters.txt` + `STPhrases.txt` |

OpenCC 的字典格式是 `key<TAB>候选1 候选2 …`；本仓只取**第一个候选**，短语表覆盖字表的同名键，
并丢弃 `key == value` 的同形项。输出格式是 `key=value` 一行一项，行首 `#` 为注释。

## 2. 为什么不直接用上游的表

上游走 `com.github.liuyueyi.quick-chinese-transfer:quick-transfer-core`（`ChineseUtils.kt`）。它的
**pom 没有 `<licenses>` 段、仓库也没有 LICENSE 文件**，按 C-DEP-7（无许可一律禁止引入）不能把它的
`tc/t2s.txt`、`tc/s2t.txt` 搬进本仓。OpenCC 是 Apache-2.0，可以。

代价是**与上游逐字不同**：上游 `t2s` 还额外维护了一串「不该转换」的词（`ChineseUtils.fixT2sDict()` 里的
`雪梨` / `鳳梨` / `魔戒` …），本仓没有那份排除表，这类港台词按 OpenCC 的默认结果走。差异登记在
`docs/dev/book-source.md` §6，触发条件是「有源依赖该排除表且能复现」。

## 3. 复现

```bash
# 1) 取 OpenCC 的四个字典（版本固定在提交 505b7a2 之后的 master，见下表哈希）
base=https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary
for f in TSCharacters.txt TSPhrases.txt STCharacters.txt STPhrases.txt; do curl -sL -o $f $base/$f; done

# 2) 生成（脚本见 §4 的规则；本仓不把生成器放进 CI）
```

生成时各输入的 sha256（2026-10-26 取数）：

| 输入 | sha256 |
|---|---|
| `TSCharacters.txt` | `9ff46a7d30e5765375eb13d33f2b03a34d298913caf2b120380679f33ae1642d` |
| `TSPhrases.txt` | `9a23666e95c97dbf8668b5d71ca19f09f33b4f3a3aa9e05677dab4b608cef102` |
| `STCharacters.txt` | `a0ca1601c70648cf48b33c3c6210ccbecc5c7eead4b4c3daf76587ba2c03582b` |
| `STPhrases.txt` | `f6eab5e5c6dd7640597878d3dfc6599ee1279d2bc91561eadd8e114194e2925a` |

输出：

| 文件 | 条目数 | sha256 |
|---|---|---|
| `t2s.txt` | 3573 | `a471d1b5c2ac640672d05d9d8397285ca4ffd5acb8a59bbfb7a14874925c3ff2` |
| `s2t.txt` | 42430 | `df38bcdaf257cc916c39f463fcf70de15f20f812ea5a4db37cbe36d6fcf0332d` |

## 4. 解析规则（`lib/core/js/zh_converter.dart`）

1. 跳过空行与 `#` 开头的行；`key=value` 以**第一个** `=` 切分（键里不含 `=`）。
2. 转换是**最长匹配**：在当前位置尝试尽可能长的键，命中即替换并前进，否则原样输出一个字符。
3. 表在 worker 里懒加载（第一次遇到 `t2s` / `s2t` 时才读），失败即该条规则报 `unsupported`。
