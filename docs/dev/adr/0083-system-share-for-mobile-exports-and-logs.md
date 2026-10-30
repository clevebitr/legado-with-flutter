# ADR-0083 移动端导出与日志走系统分享

- **状态：** Accepted（2026-10-27，用户报障：移动端导出失效、Android 日志目录无法外部访问且没有分享）
- **日期：** 2026-10-27
- **关联：** ADR-0071（书源/规则导出）、ADR-0073（备份 zip）、ADR-0074（备份位置）、
  ADR-0082（日志落文件，本 ADR 补上它登记为「未做」的分享）、C-PLT-1、C-ERR-9、
  `docs/dev/platform.md` §2/§5

## 背景

三条事实同时成立：

1. **移动端没有保存对话框。** 导出走 `file_selector` 的 `getSaveLocation`，而该插件在
   Android / iOS 上不实现它（`docs/dev/platform.md` §2 的 `JsonFileSaver` /
   `BackupArchiveSaver` 只在桌面可用）。调用结果是「未保存」或异常，用户看不到文件。
2. **Android 私有目录外部不可达。** 日志（`getApplicationSupportDirectory()/logs`）与
   备份默认目录都在应用私有区。`adb pull` / 文件管理器都拿不到，日志页只有「复制路径」，
   而 Android 上这个路径对用户没有用。
3. **系统分享是唯一不需要权限的出口。** Android 的 `ACTION_SEND` + `FileProvider`
   可以把手里的文件交给「文件」「网盘」「邮件」等任意目标应用；iOS 的
   `UIActivityViewController` 同理。这条路径既不用 `WRITE_EXTERNAL_STORAGE`，也不用
   `MANAGE_EXTERNAL_STORAGE`。

## 决策

### 决策 1 移动端的「保存」改为系统分享

新增 `core/platform/file_sharer.dart` 端口与 `SharePlusFileSharer` 适配器；
`jsonFileSaverProvider` 与 `backupArchiveSaverProvider` 在 `isMobile` 时分别返回
`SharingJsonFileSaver` / `SharingBackupArchiveSaver`，它们把内存里的字节交给分享面板。
桌面仍走 `file_selector` 的保存对话框，行为不变。

`FileSharer` 通过 `ShareableFile` 同时接受两种来源：已经在磁盘上的文件（日志）与内存字节
（导出文档、备份 zip）。日志分享因此只把路径交给插件，不把 20 MB 目录读进内存（C-PERF-5）。

### 决策 2 日志页提供「分享全部」与「分享单个文件」

`LogFilesPage` 在分享能力可用时（`FileSharer.isSupported`）显示两个入口：

- 文件列表上方的「分享全部日志」：一次把全部日志交给分享面板（Android 的
  `ACTION_SEND_MULTIPLE`），用户可存到「文件」或发给别人；
- 每个文件行的分享按钮：只分享当天那一份，便于「只给最近一次闪退的日志」。

分享前先 `flush()` 排队中的写入，避免用户拿到的是最后几行之前的内容。
取消分享是 `ParseSuccess(false)`，静默；只有真实失败才弹一条错误提示。

### 决策 3 结果语义：取消 = false，不可知 = true

`ShareResultStatus.dismissed` 回答 `false`（等同取消）；`success` 与 `unavailable`
回答 `true`。`unavailable` 只表示平台不上报用户选了哪个目标，分享面板本身已经出现，
把它当失败会让 Android 的某些目标应用被误报成「无法导出」。

### 决策 4 依赖：`share_plus`，不写原生通道

`share_plus ^13.3.1`（BSD-3-Clause，Flutter Community 维护）同时实现 Android / iOS /
Windows 的系统分享，并自带 Android `FileProvider` 与临时缓存目录，不需要我们声明
`WRITE_EXTERNAL_STORAGE` 或手写 `MainActivity` / `AppDelegate` 通道。

不用自研 MethodChannel 的理由：Android 侧还要配 `FileProvider` + `file_paths`，
iOS 侧要用 `UIActivityViewController` 并跟随新的 scene 生命周期；两套原生代码维护成本
高于一个已经被大量应用使用的插件。Windows 的插件实现与现有 Windows 构建兼容
（CMake/C++/WinRT；`nuget.exe` 已是既有前提）。

## 后果

- **好的方面：** Android / iOS 上「导出书源」「导出规则」「另存备份」重新可用；
  日志可以一条分享动作离开私有目录；没有新增任何存储权限。
- **代价：** 移动端分享的是缓存副本或原文件的一次性 URI，用户若不选「存储到文件」，
  导出物可能在系统清理缓存后消失；日志本身仍留在私有目录，分享不会移动它。
- **平台边界：** 只有 `isMobile` 使用分享；桌面继续用保存对话框，日志页在桌面上不显示
  分享入口（`isSupported == false`，不是平台判断）。Linux 的文件分享不被 `share_plus`
  支持，本项目也不发布 Linux，因此没有额外分支。
- **未做：** 日志压缩成一个 zip、按源过滤日志、直接写入公共 Downloads（需要 MediaStore
  或 SAF 的额外实现）。触发条件 = 用户需要「一条消息发出全部日志」或应用商店要求
  「导出到下载目录」。

## 被否的备选

- **申请 `MANAGE_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`：** 与最小权限原则冲突，
  Android 11+ 的「所有文件访问」还需要商店审核；分享不需要任何权限。
- **把日志改写到公共 Downloads：** scoped storage 下要 MediaStore 或 SAF，且会改变
  ADR-0082 的「一个私有目录、三平台同一套」规则；分享已经能满足「把文件拿出去」。
- **只保留「复制路径」：** Android 上用户拿到路径也打不开；这不是可用出口。
- **自己写原生分享通道：** 见决策 4；维护两套原生实现不划算。
