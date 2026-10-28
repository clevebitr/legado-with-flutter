# ADR-0084 日志行格式与 Windows 控制台噪声过滤

- **状态：** Accepted（2026-10-28，用户报障：控制台被 AXTree 噪声刷屏 / 文件日志被 ANSI 盒线拆散）
- **日期：** 2026-10-28
- **关联：** ADR-0006（日志门面）、ADR-0082（不脱敏 / 落文件 / 运行时级别 / 崩溃栈）、
  `docs/dev/constraints.md` C-ERR-5、C-PERF-5；upstream [flutter/flutter#182444]

## 背景

两处噪声，都出现在真实运行里（用户贴了原始输出）：

1. **文件日志不是「一行一条记录」。** `app-YYYY-MM-DD.log` 里每条记录是 `logger` 包默认
   `PrettyPrinter` 画的盒子：`␛[38;5;12m┌────…␛[0m` / `│ 💡 app start: …` / `└────…`，一条记录
   五个物理行，而且带 ANSI 转义。后果是文件不可 grep（`grep 'app start'` 命中的是盒线里的行）、
   体积被盒线撑大（每行 ~120 个装饰字符）、把文件贴进 issue 时带着转义序列。
   它还**给每条记录补一条假栈**：`PrettyPrinter` 在 `event.stackTrace == null` 时用
   `StackTrace.current` 打 5 帧（`methodCount` 默认），于是 `INFO app start` 后面跟着
   `#0 AppLogger.info …` —— 那不是诊断，是噪声。
2. **Windows 控制台被引擎的 AXTree 报错刷屏。**
   `[ERROR:flutter/shell/platform/common/accessibility_bridge.cc(114)] Failed to update ui::AXTree,
   error: 84 will not be in the tree and is not the new root` 每帧若干条，淹没真正的日志。

## 决策

### 决策 1 日志行格式：一条记录一行，无颜色、无盒线

新增 `core/logging/log_line_printer.dart` 的 `LineLogPrinter`，并让它成为 `AppLogger` 的**默认**
打印器（`printer: printer ?? LineLogPrinter()`）。格式固定为：

```text
2026-10-28 13:04:18.943 INFO  app start: platform=windows log=… level=info
2026-10-28 13:05:02.110 ERROR content failed  error=<FormatException: bad body>
2026-10-28 13:05:02.110 ERROR CRASH platform: boom  error=<StateError: boom>
  #0      main (package:flutter_reader/main.dart:49:10)
```

四条口径：

1. `时间 级别  消息`：本地时间 `yyyy-MM-dd HH:mm:ss.SSS`（与文件名 `app-YYYY-MM-DD.log` 同一时区），
   级别定宽 5 字符（`INFO ` / `WARN ` 带尾空格）让消息列对齐。
2. **不写 ANSI 转义**：同样的行同时进控制台与文件（`_FileOutput` 既 `print` 又 `append`），
   着色只对实时看的人有价值，落盘后只会破坏 grep。
3. **消息与异常压成一行**：消息里的换行折叠为 ` | `（行内空格不动，它可能是对齐过的内容）；
   异常以 `error=<原文>` 接在同一行（ADR-0082：日志不脱敏）。
4. **栈只在真有时打**：`event.stackTrace` 为空就**不**补假栈；有则作为**缩进续行**跟在记录后面
   （`  #0 …`），所以「一条记录一行」对记录本身成立，崩溃栈仍然完整可读。崩溃记录的同步落盘按
   **整条事件**判定（头行带 `CRASH` 时后面的栈续行一起 `appendSync`），否则崩溃现场只留半条。

### 决策 2 Windows 控制台：过滤**一条**已知的引擎噪声，不动别的

那行 `Failed to update ui::AXTree` 由 Flutter 引擎的 C++ 无障碍桥打印，Dart 侧拿不到句柄，所以过滤
放在 Windows runner：`windows/runner/ax_log_filter.{h,cpp}`，在 `wWinMain` 里 `AttachConsole`
之后调用 `InstallAccessibilityLogFilter()`。

边界（刻意的，逐条写进头文件）：

1. **只丢包含 `Failed to update ui::AXTree` 的行**（子串匹配，因为前面的
   `accessibility_bridge.cc(114)` 行号随引擎版本变）；其余引擎 / 插件 / Dart 输出一条不动。
2. **只在有控制台时安装**：`_fileno(stderr) < 0` 或 `_pipe` / `_fdopen` / `_dup2` 任一步失败就
   **原样返回**，不做半吊子改动（尤其是「stderr 指向无读者的管道」那种会阻塞写日志线程的状态）。
3. **不碰语义树、不关无障碍**：这是引擎缺陷的降噪，不是把 a11y 关掉。上游状态仍是 open
   （[flutter/flutter#182444]，标签 `platform-windows` / `a: accessibility`），所以这条过滤在
   上游修好之前一直有意义，修好后可以删掉。
4. 机械上是「stderr → 管道 → 一个 detached 线程逐行转发回原 stderr（副本 fd）」，并 `setvbuf`
   成无缓冲，保证 `fgets` 拿到的是整行而不是自己写进去的半行。

## 被否的备选

| 备选 | 否决理由 |
|---|---|
| 关掉 Windows 无障碍（引擎开关 / 不响应 `WM_GETOBJECT`） | 用失去读屏支持换安静，不可接受；噪声只是日志问题 |
| 把控制台输出统一重定向到文件 | 抹掉整个控制台，`flutter run` / 调试输出一起没了 |
| 在 Dart 侧包一层 stdout 过滤器 | 那行由引擎 C++ 直接写 stderr，Dart 没有句柄；`print` 拦截也管不到 |
| 保留 `PrettyPrinter`，只把颜色关掉 | 盒线与假栈仍在：一条记录照样五个物理行、`INFO` 后面照样跟 `#0 AppLogger.info` |

## 验证（2026-10-28，本机 Windows 11）

| 验证项 | 怎么验 | 结果 |
|---|---|---|
| 文件日志是一行一条、无 ANSI / 无盒线 | 发行版实跑后看 `app-2026-10-28.log` 新增行 | 通过：`2026-10-28 13:04:18.943 INFO  app start: …`（同日早期行仍是旧构建留下的盒线，属历史内容） |
| 控制台同样是这一行 | 同一进程 stdout | 通过（与文件逐字一致） |
| 崩溃记录整条同步落盘 | `log_file_test` 的 `error_givenACrashRecord_writesTheWholeTraceSynchronously`（不 `flush` 直接读） | 通过 |
| stderr 过滤机械可用 | 临时在 `InstallAccessibilityLogFilter()` 之后向 `stderr` 打两条（一条含 `Failed to update ui::AXTree`、一条不含），构建后实跑 | 通过：普通行出现在控制台，含关键字的行被丢掉，进程不挂（管道有读者） |
| AXTree 噪声本身的可复现性 | 上游描述只在**辅助技术客户端连接**（Narrator / NVDA）时出现 | **未复现**：本机未挂读屏，无法制造该行；过滤逻辑按子串丢行，与是否真出现无关 |
| 原生改动不破坏设备级用例 | `flutter test integration_test/<每个文件> -d windows` 五个文件 | 全绿（`js_bridge` 81 例 + 其余），见 `DECISIONS.md` 同日条目 |

另外顺手修掉两条**只在设备上跑**的陈旧断言（`flutter test` 跑不到它们，因此一直没人发现）：
`source.putVariable` 是上游的 `void`（`book-source.md` §6），拼进字符串就是 `undefined`，原断言写的是 `''`；
`Packages.java.lang.String` 已被 ADR-0081 的白名单放行，原断言仍要求它被拒 —— 现在改成
`Packages.javax.crypto.Cipher`（登记为不做的那一族）。

## 后果

**正面**：日志文件是一行一条的可 grep 文本；体积显著变小（去掉盒线与假栈）；控制台里
`flutter run` / `adb logcat` 的真错误不再被 AXTree 刷屏；崩溃栈仍然完整且同步落盘。

**负面 / 风险**：runner 里多了一个原生线程与 64 KB 管道缓冲（进程退出时随进程消失）；这是
**模板外**的改动，`flutter create` 重新生成 runner 时要保留（登记在 `docs/dev/platform.md`）；
过滤依赖子串，上游改文案后会自然失效（不会误伤别的行）。

[flutter/flutter#182444]: https://github.com/flutter/flutter/issues/182444
