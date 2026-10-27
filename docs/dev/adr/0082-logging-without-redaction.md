# ADR-0082 日志：不脱敏、落文件（三平台）、运行时级别与 Dart 侧崩溃栈

- **状态：** Accepted（2026-10-27，用户裁决：① release 也不脱敏，开源软件不必过度设计；
  ② 日志按天轮转、保留 7 天 / 总 20 MB；③ 崩溃只做 Dart 侧；④ 搜索关键词也原样记录）
- **日期：** 2026-10-27
- **关联：** ADR-0006（日志门面）、C-SEC-4、C-ERR-8、`docs/dev/tech-stack.md` §7、
  `docs/dev/testing.md` §2、ADR-0080 / ADR-0081（同一套「白名单 + 显式拒绝」的取舍风格）

## 背景

三条现实把原来的日志设计顶到了墙上：

1. **排障要靠原始日志。** 原门面把所有消息与异常都过一遍脱敏：URL、关键词被掩、异常只剩
   `<Type: 长度 + 摘要>`。用它定位「这个源为什么搜不出结果」几乎不可能——真正的错误文本
   （`HttpException` 的地址、QuickJS 的报错、Dio 的 `status`）全被摘要掉了。
2. **没有文件，就没有事后证据。** 移动端闪退后 `flutter logs` 也没了；用户能给的只有一句
   「搜索时闪退」。没有落盘日志，开发者拿不到任何现场。
3. **级别只能在构建期定。** `--dart-define=LOG_LEVEL=` 要求重新打包才能开 `debug`，而
   「用户遇到问题 → 打开 debug → 复现 → 导出日志」是这类阅读 App 最常用的排障闭环。

## 决策

### 决策 1 日志不再脱敏（release 同样）

`AppLogger` 把消息与异常**原样**写出；异常统一成 `<类型: 原文>`（`describeError`），便于按类型 grep。
`core/logging/redaction.dart`（掩码、URL 掩码、关键词摘要）整份删除，`redactUrl` / `redactMessage` /
`redactHeaders` / `describeKeyword` / `describePayload` 一并消失。

**仍然保留的纪律（不是掩码，而是「不记录」）：** 请求头（`Cookie` / `Authorization`）与页面正文
从未交给日志——它们对定位规则没有帮助，而正文会把日志文件撑爆。这条写进 C-SEC-4 的新措辞。

### 决策 2 落文件：按天轮转，保留 7 天 / 总 20 MB

`core/logging/log_file.dart`：目录来自 `getApplicationSupportDirectory()/logs`（三平台同一套），
文件名 `app-YYYY-MM-DD.log`，启动与跨天各切一份；`prune()` 先删 7 天以前的，再按「最旧优先」删到
总数 ≤ 20 MB，**当天那份永远留着**。写是追加且串行排队（`flush()` 等队列），崩溃行同步写
（`appendSync`）。写失败只丢那一行：日志不能成为应用失败的原因。

### 决策 3 级别是运行时选择

`AppLogger.level` 可在运行时改（`setLevel`，门面自己判级别，`logger` 侧设为 `Level.all` 不再静默丢）；
设置页新增「日志等级」下拉（`AppSettings.logLevel` 持久化），改完**立即**作用于下一行日志。

### 决策 4 崩溃栈只做 Dart 侧

`core/logging/crash_handlers.dart` 接三扇门：`FlutterError.onError`、`PlatformDispatcher.onError`、
`Isolate.current.addErrorListener`（JS worker 的未捕获错误从这里冒出来）。每条记录以 `CRASH` 开头并
带上完整栈，同步落盘后仍然转发给原来的 handler（控制台/上游照旧）。原生崩溃（NDK / SIGSEGV）不做：
那需要原生插件 + 上传通道，是另一个决策。

### 决策 5 关键词进日志

搜索关键词原样记录：搜索失败最常见的原因是站点按关键词重定向，看不到它就是少一半线索。

## 后果

- **好的方面：** 拿到一台设备就能给出可读的现场（`app-2026-10-27.log`）；`adb pull` / Finder 直接取；
  设置页能切级别、能清空、能复制目录；崩溃栈不再只活在控制台。搜索期的内存问题也因此**可诊断**
  （下一刀加计数与 RSS 采样）。
- **代价：** 日志里会有 URL、关键词与源站地址（开源项目的取舍，用户已裁决）；**不是**凭据与正文。
  闪退后的用户仍要手动取文件，没有自动上传通道（触发 = 需要远程排障时再谈）。
- **未做（登记）：** 原生崩溃捕获、日志压缩、按源过滤日志。日志**分享**已由 ADR-0083 补上
  （日志页的「分享全部」与单文件分享）；目录仍留在应用私有区，分享是出口而不是移动文件。

## 被否的备选

- **维持脱敏 + 只加文件：** 文件里也全是 `***` 与摘要，等于把排障难题换个地方放。
- **只在 debug 不脱敏：** 用户手上的永远是 release 包；只在 debug 放开等于「能复现的人看不到」。
- **按大小轮转 / 单文件：** 用户选了按天：日期文件名本身就是最直观的时间轴，出问题时「昨天的日志」
  是一个可执行的指令。
- **接 `sentry_flutter` / Crashlytics：** 需要账号、上传通道与隐私声明，且与「自托管、开源」的定位不符；
  当前目标只是「开发者能拿到栈」。

## 实现注记（2026-10-27 落地）

- 新文件：`log_file.dart`（轮转/保留/清空）、`crash_handlers.dart`（三扇门）、`error_text.dart`
  （`describeError` 原文化）；`app_logger.dart` 增加 `file:`、`setLevel`、`isEnabled`。
- 删除：`redaction.dart` 与其 12 条测试；`lib/` 内 8 个文件的 `redactUrl` 调用改为原样插值。
- 装配：`main()` 在首帧前建 `LogFile`、`prune()`、覆盖 `logFileProvider`、装崩溃处理器、把
  `AppSettings.logLevel` 套到门面上。
- 设置：`AppSettings.logLevel`（`settings.logLevel`）+ 「诊断」区（等级下拉 + 日志文件页：
  文件名/大小/合计/清空/复制目录）。
- 测试：`log_file_test.dart` 12 例（按天切、`appendSync`、7 天保留、20 MB 上限、清空、忽略无关文件、
  排队写、运行时级别）、`app_logger_test.dart` 改为断言原文。
- 门禁：`dart format` 0、`flutter analyze` 0、**2657 例全过**、`check_coverage` exit 0
  （core 98.11 / domain 97.08 / data 95.69）。
- 文档同步：`constraints.md` C-SEC-4 新措辞、ADR-0006 §5 标注被本 ADR 取代、`tech-stack.md` 的
  `crypto` 用途去掉「日志脱敏」。
